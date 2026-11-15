import '../../rota/dominio/presenca.dart';
import '../dominio/notificacao.dart';
import 'notificacao_service.dart';

/// `NotificacaoServiceVazio` — notificacao :: aplicação.
///
/// Responsabilidade: implementação de [NotificacaoService] que não faz nada.
/// Permite que o UC-S05 (`EmbarqueService`) seja implementado e testado antes
/// de o UC-I02 ficar pronto (task B-05). Será trocada pelo
/// `NotificacaoServicePadrao` do Membro C na task B-11.
///
/// UC-S05 passo 5 (ponto do `<<include>>` UC-I02); RF-011.
class NotificacaoServiceVazio implements NotificacaoService {
  const NotificacaoServiceVazio();

  @override
  Future<void> notificarMovimentacao(
    Presenca presenca,
    TipoMovimentacao tipo,
  ) async {
    // Versão provisória: nenhum aviso é criado até a B-11.
  }
}
