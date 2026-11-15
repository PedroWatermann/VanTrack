import 'notificacao.dart';

/// Contrato de persistência e consulta dos avisos, sem dependência de SQL.
/// RF-011, UC-I02; consulta restrita ao destinatário (RN-002).
abstract class NotificacaoRepository {
  Future<void> registrarComunicado(List<Notificacao> notificacoes);
  Future<List<Notificacao>> buscarDoResponsavel(int responsavelId,
      [DateTime? desde]);
  Future<Notificacao?> buscarPorId(int id);
  Future<void> salvar(Notificacao notificacao);
}
