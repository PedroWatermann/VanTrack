import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../dominio/conectividade.dart';
import '../dominio/excecoes.dart';

/// `MonitorConectividade` — embarque :: infraestrutura.
///
/// Responsabilidade: detectar a conectividade do aparelho com
/// `connectivity_plus` (incluindo modo avião no Android) e tratar timeout de
/// 5 segundos ou erro de rede nas chamadas como offline (essencial na Web),
/// expondo o estado em um [ValueNotifier] para a `FaixaSemConexao`.
///
/// RNF-006 (sincronização offline em até 5 min); RNF-003 (faixa "Sem conexão").
/// UC-S05 fluxo alternativo A1; UC-R02 E1.
class MonitorConectividade implements Conectividade {
  MonitorConectividade({
    Connectivity? connectivity,
    bool inicialOnline = true,
  })  : _connectivity = connectivity ?? Connectivity(),
        online = ValueNotifier<bool>(inicialOnline) {
    _inscricao =
        _connectivity.onConnectivityChanged.listen(_aoMudarConectividade);
  }

  /// Tempo limite de 5 segundos para considerar uma chamada sem resposta como offline.
  static const Duration tempoLimite = Duration(seconds: 5);

  final Connectivity _connectivity;

  /// Notificador observado pela interface (`FaixaSemConexao`) para exibir ou
  /// ocultar a faixa âmbar quando o sinal cai ou volta (RNF-003).
  final ValueNotifier<bool> online;

  final StreamController<bool> _controlador =
      StreamController<bool>.broadcast();

  StreamSubscription<List<ConnectivityResult>>? _inscricao;

  @override
  bool get estaOnline => online.value;

  @override
  Stream<bool> get aoMudar => _controlador.stream;

  /// Consulta ativamente o estado atual no `connectivity_plus` e atualiza [online].
  Future<bool> verificarConectividade() async {
    final resultados = await _connectivity.checkConnectivity();
    _aoMudarConectividade(resultados);
    return estaOnline;
  }

  @override
  void registrarFalhaDeRede() => _atualizar(false);

  @override
  void registrarSucessoDeRede() => _atualizar(true);

  /// Executa uma [chamada] de rede com limite de [limite] (padrão 5 s).
  ///
  /// Se ocorrer timeout de 5 s, [SemConexaoException] ou erro de cliente HTTP
  /// (comum na Web quando não há internet), marca como offline em [online] e
  /// lança [SemConexaoException].
  Future<T> monitorarChamada<T>(
    Future<T> Function() chamada, {
    Duration limite = tempoLimite,
  }) async {
    try {
      final resultado = await chamada().timeout(limite);
      registrarSucessoDeRede();
      return resultado;
    } on EnvioRecusadoException {
      // O servidor respondeu (403/404/409): há conexão.
      registrarSucessoDeRede();
      rethrow;
    } on SemConexaoException {
      registrarFalhaDeRede();
      rethrow;
    } on TimeoutException {
      registrarFalhaDeRede();
      throw const SemConexaoException();
    } on http.ClientException {
      registrarFalhaDeRede();
      throw const SemConexaoException();
    }
  }

  void _aoMudarConectividade(List<ConnectivityResult> resultados) {
    final temConexao = resultados.isNotEmpty &&
        !resultados.every((r) => r == ConnectivityResult.none);
    _atualizar(temConexao);
  }

  void _atualizar(bool novoEstado) {
    if (online.value == novoEstado) return;
    online.value = novoEstado;
    if (!_controlador.isClosed) {
      _controlador.add(novoEstado);
    }
  }

  /// Cancela a escuta de conectividade e libera os recursos.
  Future<void> dispose() async {
    await _inscricao?.cancel();
    await _controlador.close();
    online.dispose();
  }
}
