import '../../compartilhado/aplicacao/excecoes.dart';
import '../dominio/notificacao.dart';
import '../dominio/notificacao_repository.dart';

/// Consulta e marca os avisos do responsável logado (UC-I02, RF-011).
/// RN-002: cada responsável acessa somente as suas notificações.
class AvisosService {
  const AvisosService(this.notificacaoRepository);

  final NotificacaoRepository notificacaoRepository;

  Future<List<Notificacao>> listarDoResponsavel(int responsavelId,
          [DateTime? desde]) =>
      notificacaoRepository.buscarDoResponsavel(responsavelId, desde);

  Future<void> marcarComoLida(int notificacaoId, int responsavelId) async {
    final notificacao = await notificacaoRepository.buscarPorId(notificacaoId);
    if (notificacao == null) {
      throw const NaoEncontradoException('Notificação não encontrada.');
    }
    // RN-002: valida o destinatário antes de alterar ou salvar o aviso.
    if (!notificacao.pertenceA(responsavelId)) {
      throw const AcessoNegadoException(
          'Esta notificação não pertence a você.');
    }
    notificacao.marcarComoLida();
    await notificacaoRepository.salvar(notificacao);
  }
}
