import 'package:uuid/uuid.dart';

import '../dominio/embarque_remoto.dart';
import '../dominio/excecoes.dart';
import '../dominio/localizador.dart';
import '../dominio/registro_embarque.dart';
import 'modulo_embarque.dart';

/// Implementação do [ModuloEmbarque] que só funciona com conexão.
///
/// A cada toque em "Embarcou":
/// 1. guarda o momento do toque e gera o código único do embarque (registroId);
/// 2. tenta obter a localização por no máximo 2 segundos. Se não conseguir,
///    envia sem localização: o toque nunca fica esperando o GPS (RNF-005);
/// 3. envia o embarque ao servidor e devolve [StatusEnvio.enviado].
///
/// Se o servidor recusar (403, 404 ou 409), lança [EmbarqueException] para a
/// tela mostrar a mensagem. Sem conexão, o erro [SemConexaoException] é
/// repassado: guardar na fila é papel do ModuloEmbarqueComFila (E-03).
///
/// Como nada fica pendente aqui, [listarPendentes] é sempre vazio e
/// [aoMudarPendentes] nunca emite eventos.
///
/// UC-S05 passo 2 (lado do app); UC-R02 passos 3 a 5; RF-009.
class ModuloEmbarqueOnline implements ModuloEmbarque {
  ModuloEmbarqueOnline({required this.remoto, required this.localizador});

  final EmbarqueRemoto remoto;
  final Localizador localizador;

  /// Tempo máximo esperando a localização a cada toque.
  static const Duration limiteGps = Duration(seconds: 2);

  static const Uuid _uuid = Uuid();

  @override
  Future<ResultadoEmbarque> registrarEmbarque(int rotaId, int alunoId) async {
    // Hora do toque, e não a do envio.
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

    try {
      await remoto.enviar(registro);
    } on EnvioRecusadoException catch (erro) {
      throw EmbarqueException(erro.codigoHttp, erro.mensagem);
    }
    return ResultadoEmbarque(registroId, alunoId, dataHora, StatusEnvio.enviado);
  }

  @override
  Future<List<RegistroPendente>> listarPendentes(int rotaId) async => const [];

  @override
  Stream<EventoPendente> get aoMudarPendentes => const Stream.empty();
}
