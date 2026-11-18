import '../../cadastro/dominio/vinculo_repository.dart';
import '../../rota/dominio/presenca.dart';
import '../dominio/notificacao.dart';
import '../dominio/notificacao_repository.dart';
import 'notificacao_service.dart';

/// Coordena o UC-I02: busca os responsáveis, cria os avisos e registra o comunicado.
/// RF-011; RN-002/RN-009: avisa somente os responsáveis vinculados ao aluno.
/// RNF-006: usa a hora original do embarque, inclusive na sincronização offline.
class NotificacaoServicePadrao implements NotificacaoService {
  const NotificacaoServicePadrao({
    required this.vinculoRepository,
    required this.notificacaoRepository,
  });

  final VinculoRepository vinculoRepository;
  final NotificacaoRepository notificacaoRepository;

  @override
  Future<void> notificarMovimentacao(
    Presenca presenca,
    TipoMovimentacao tipo,
  ) async {
    if (tipo != TipoMovimentacao.embarque) {
      throw UnsupportedError('Somente avisos de embarque estão disponíveis.');
    }
    final embarque = presenca.embarque;
    if (embarque == null) {
      throw StateError('É necessário registrar o embarque antes de notificar.');
    }

    // RN-002/RN-009: os destinatários vêm dos vínculos existentes do aluno.
    final responsaveis =
        await vinculoRepository.buscarResponsaveis(presenca.aluno.id);
    // UC-I02 A1: aluno sem responsável retorna normalmente, sem gravar avisos.
    if (responsaveis.isEmpty) return;

    await notificacaoRepository.registrarComunicado([
      for (final responsavel in responsaveis)
        Notificacao.deEmbarque(responsavel, presenca.aluno, embarque.dataHora),
    ]);
  }
}
