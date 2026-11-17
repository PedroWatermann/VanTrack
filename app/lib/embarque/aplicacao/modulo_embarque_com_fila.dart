import 'dart:async';

import 'package:uuid/uuid.dart';

import '../dominio/conectividade.dart';
import '../dominio/embarque_remoto.dart';
import '../dominio/excecoes.dart';
import '../dominio/fila_embarques.dart';
import '../dominio/localizador.dart';
import '../dominio/registro_embarque.dart';
import 'modulo_embarque.dart';

/// `ModuloEmbarqueComFila` — embarque :: aplicação.
///
/// Responsabilidade: implementar o contrato [ModuloEmbarque] com suporte ao
/// modo sem conexão (fluxo alternativo A1 do UC-S05). Captura data/hora e
/// localização (até 2 s) no momento do toque, envia imediatamente quando há
/// conexão ou guarda na [FilaEmbarques] quando offline / falha de rede
/// ([SemConexaoException]), devolvendo [StatusEnvio.pendente]. Erros de regra
/// ou acesso (403, 404, 409) viram [EmbarqueException] e nunca vão para a fila.
///
/// RN-010 (confirmação do embarque pelo motorista); RF-009; RNF-005 (um toque,
/// GPS com limite de 2 s); RNF-006 (fila offline e sincronização).
/// UC-S05 passo 2 e fluxo alternativo A1; UC-R02 passos 3 a 5 e E1.
class ModuloEmbarqueComFila implements ModuloEmbarque {
  ModuloEmbarqueComFila({
    required this.remoto,
    required this.fila,
    required this.conectividade,
    required this.localizador,
  });

  final EmbarqueRemoto remoto;
  final FilaEmbarques fila;
  final Conectividade conectividade;
  final Localizador localizador;

  /// Tempo máximo esperando a localização a cada toque (RNF-005).
  static const Duration limiteGps = Duration(seconds: 2);

  static const Uuid _uuid = Uuid();

  bool _sincronizando = false;

  /// Indica se há uma sincronização em andamento.
  bool get sincronizando => _sincronizando;

  final StreamController<EventoPendente> _eventos =
      StreamController<EventoPendente>.broadcast();

  @override
  Stream<EventoPendente> get aoMudarPendentes => _eventos.stream;

  @override
  Future<ResultadoEmbarque> registrarEmbarque(int rotaId, int alunoId) async {
    // Hora e localização capturadas no momento do toque (RF-009, RNF-006).
    final dataHora = DateTime.now();
    final registroId = _uuid.v4();
    final localizacao = await localizador.obterLocalizacao(limiteGps);

    final registro = RegistroEmbarque(
      registroId: registroId,
      rotaId: rotaId,
      alunoId: alunoId,
      dataHora: dataHora,
      localizacao: localizacao,
    );

    // Fluxo A1 (RNF-006): já sabemos que está sem conexão -> guarda na fila.
    if (!conectividade.estaOnline) {
      await fila.guardar(registro);
      return ResultadoEmbarque(
        registroId,
        alunoId,
        dataHora,
        StatusEnvio.pendente,
      );
    }

    try {
      await remoto.enviar(registro);
      conectividade.registrarSucessoDeRede();
      return ResultadoEmbarque(
        registroId,
        alunoId,
        dataHora,
        StatusEnvio.enviado,
      );
    } on SemConexaoException {
      // Fluxo A1 (RNF-006): queda de rede ou timeout no envio -> vai para a fila.
      conectividade.registrarFalhaDeRede();
      await fila.guardar(registro);
      return ResultadoEmbarque(
        registroId,
        alunoId,
        dataHora,
        StatusEnvio.pendente,
      );
    } on EnvioRecusadoException catch (erro) {
      // 403/404/409: servidor respondeu e recusou -> nunca vai para a fila.
      conectividade.registrarSucessoDeRede();
      throw EmbarqueException(erro.codigoHttp, erro.mensagem);
    }
  }

  @override
  Future<List<RegistroPendente>> listarPendentes(int rotaId) async {
    final pendentes = await fila.listar(rotaId);
    return [
      for (final r in pendentes)
        RegistroPendente(r.registroId, r.alunoId, r.dataHora),
    ];
  }

  /// Sincroniza os registros pendentes com o servidor (detalhado na E-04).
  Future<void> sincronizar() async {
    if (_sincronizando) return;
    _sincronizando = true;
    try {
      // A lógica de envio em lote, remoção e reconexão automática é expandida na E-04.
    } finally {
      _sincronizando = false;
    }
  }

  /// Libera o controlador de eventos.
  Future<void> dispose() async {
    await _eventos.close();
  }
}
