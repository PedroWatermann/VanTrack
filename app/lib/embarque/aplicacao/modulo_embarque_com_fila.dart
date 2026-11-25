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
/// ([SemConexaoException]), devolvendo [StatusEnvio.pendente]. Sincroniza os
/// pendentes automaticamente ao reconectar, a cada 30 segundos e ao abrir o app,
/// sem execuções simultâneas, removendo da fila o que o servidor confirmou ou
/// rejeitou e notificando via [aoMudarPendentes].
///
/// A tentativa a cada 30 segundos acontece **mesmo com o app marcado como sem
/// conexão**: é ela que descobre que o servidor voltou. Na Web, uma falha de
/// rede ou um timeout marcam o app como offline, mas nenhum evento do
/// `connectivity_plus` avisa quando o servidor volta; sem essa tentativa, o app
/// ficava "sem conexão" para sempre (teste 10; Bug VT-77).
///
/// A fila é do aparelho, mas cada registro guarda o motorista que o fez. Com
/// [motoristaLogado], o módulo só lista e sincroniza os registros do motorista
/// logado, e não sincroniza nada sem motorista logado. Respostas 401 e 403 de
/// um registro não o tiram da fila: são problemas da sessão ou do vínculo, não
/// do embarque, e apagar faria o embarque se perder (Bug VT-76).
///
/// RN-010 (confirmação do embarque pelo motorista); RF-009; RNF-005 (um toque,
/// GPS com limite de 2 s); RNF-006 (fila offline e sincronização em até 5 min).
/// UC-S05 passo 2 e fluxo alternativo A1; UC-R02 passos 3 a 5 e E1.
class ModuloEmbarqueComFila implements ModuloEmbarque {
  ModuloEmbarqueComFila({
    required this.remoto,
    required this.fila,
    required this.conectividade,
    required this.localizador,
    this.motoristaLogado,
    Duration intervaloSincronizacao = const Duration(seconds: 30),
  }) {
    _inscricaoConectividade = conectividade.aoMudar.listen((online) {
      if (online) {
        sincronizar();
      }
    });
    _timerSincronizacao = Timer.periodic(
      intervaloSincronizacao,
      (_) => sincronizar(),
    );
    // RNF-006: tenta enviar pendências salvas assim que o app é aberto.
    Future.microtask(sincronizar);
  }

  final EmbarqueRemoto remoto;
  final FilaEmbarques fila;
  final Conectividade conectividade;
  final Localizador localizador;

  /// Identificador do motorista logado agora, ou nulo se não houver (ninguém
  /// logado ou um responsável). Sem esta função, a fila não é separada por
  /// motorista.
  final int? Function()? motoristaLogado;

  /// Tempo máximo esperando a localização a cada toque (RNF-005).
  static const Duration limiteGps = Duration(seconds: 2);

  static const Uuid _uuid = Uuid();

  final Set<int> _rotasConhecidas = {1};

  bool _sincronizando = false;
  bool _dispensado = false;

  /// Indica se há uma sincronização em andamento.
  bool get sincronizando => _sincronizando;

  final StreamController<EventoPendente> _eventos =
      StreamController<EventoPendente>.broadcast();

  StreamSubscription<bool>? _inscricaoConectividade;
  Timer? _timerSincronizacao;

  @override
  Stream<EventoPendente> get aoMudarPendentes => _eventos.stream;

  @override
  Future<ResultadoEmbarque> registrarEmbarque(int rotaId, int alunoId) async {
    _rotasConhecidas.add(rotaId);

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
      motoristaId: motoristaLogado?.call(),
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
    _rotasConhecidas.add(rotaId);
    final pendentes = _doMotoristaLogado(await fila.listar(rotaId));
    return [
      for (final r in pendentes)
        RegistroPendente(r.registroId, r.alunoId, r.dataHora),
    ];
  }

  /// Sincroniza os registros pendentes com o servidor em lote (RNF-006).
  ///
  /// Nunca executa duas sincronizações simultaneamente. Em falha de rede no
  /// meio do processo, mantém os registros na fila para a próxima tentativa.
  ///
  /// Tenta mesmo se [conectividade] disser que está offline: o resultado da
  /// tentativa é que atualiza o estado (Bug VT-77). Só chama o servidor se
  /// houver pendentes; com a fila vazia, não faz nada.
  Future<void> sincronizar([int? rotaId]) async {
    if (rotaId != null) {
      _rotasConhecidas.add(rotaId);
    }
    if (_sincronizando || _dispensado) return;
    // Bug VT-76: sem motorista logado não há com quem sincronizar; com o token
    // de outro usuário, o servidor recusaria (401/403).
    if (motoristaLogado != null && motoristaLogado!() == null) return;

    _sincronizando = true;
    try {
      final rotas = rotaId != null ? [rotaId] : _rotasConhecidas.toList();
      for (final rota in rotas) {
        if (_dispensado) break;

        final pendentes = _doMotoristaLogado(await fila.listar(rota));
        if (pendentes.isEmpty) continue;

        final Map<String, int> resultados;
        try {
          resultados = await remoto.sincronizar(rota, pendentes);
          conectividade.registrarSucessoDeRede();
        } on SemConexaoException {
          conectividade.registrarFalhaDeRede();
          break;
        } on EnvioRecusadoException {
          conectividade.registrarSucessoDeRede();
          break;
        }

        final paraRemover = <String>{};
        final eventosEmitidos = <EventoPendente>[];

        for (final registro in pendentes) {
          final codigo = resultados[registro.registroId];
          if (codigo == 200 || codigo == 201) {
            paraRemover.add(registro.registroId);
            eventosEmitidos.add(
              EventoPendente(registro.registroId, registro.alunoId, true),
            );
          } else if (codigo == 401 || codigo == 403) {
            // Bug VT-76: sessão inválida ou motorista sem vínculo ativo agora.
            // O embarque continua na fila; nada é apagado.
            continue;
          } else if (codigo != null && codigo >= 400 && codigo < 500) {
            paraRemover.add(registro.registroId);
            eventosEmitidos.add(
              EventoPendente(
                registro.registroId,
                registro.alunoId,
                false,
                codigo,
              ),
            );
          }
        }

        if (paraRemover.isNotEmpty) {
          await fila.remover(paraRemover);
        }
        if (!_dispensado && !_eventos.isClosed) {
          for (final evento in eventosEmitidos) {
            _eventos.add(evento);
          }
        }
      }
    } finally {
      _sincronizando = false;
    }
  }

  /// Só os registros do motorista logado (Bug VT-76). Registros antigos, sem
  /// motorista, valem para qualquer motorista: um 403 não os apaga mais.
  List<RegistroEmbarque> _doMotoristaLogado(List<RegistroEmbarque> registros) {
    final obter = motoristaLogado;
    if (obter == null) return registros;
    final motoristaId = obter();
    if (motoristaId == null) return const [];
    return [
      for (final r in registros)
        if (r.motoristaId == null || r.motoristaId == motoristaId) r,
    ];
  }

  /// Cancela o timer e a escuta de conectividade, liberando os recursos.
  Future<void> dispose() async {
    _dispensado = true;
    _timerSincronizacao?.cancel();
    await _inscricaoConectividade?.cancel();
    await _eventos.close();
  }
}
