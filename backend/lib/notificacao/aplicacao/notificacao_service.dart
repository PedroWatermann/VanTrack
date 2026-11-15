import '../../rota/dominio/presenca.dart';
import '../dominio/notificacao.dart';

/// `NotificacaoService` — notificacao :: aplicação (contrato).
///
/// Participante "NotificacaoService" dos diagramas de sequência UC-S05 e
/// UC-I02.
///
/// Responsabilidade: ponto do `<<include>>` UC-I02 Notificar Responsável. O
/// `EmbarqueService` avisa que houve uma movimentação do aluno, **depois** de
/// salvar o embarque, sem saber como o aviso é montado nem a quem ele vai.
/// UC-S05 passo 5; UC-I02 passos 1 a 4 e A1; RF-011; RN-002 e RN-009.
///
/// Implementações:
/// - `NotificacaoServiceVazio`: não faz nada, para o UC-S05 não esperar o
///   UC-I02 (task B-05);
/// - `NotificacaoServicePadrao`: implementação real (task C-04, Membro C).
///
/// Quem escolhe a implementação é o `routes/_middleware.dart` (composição); a
/// troca da vazia pela real é a task B-11.
abstract class NotificacaoService {
  /// Notifica os responsáveis do aluno da [presenca] sobre a movimentação
  /// [tipo] (nesta entrega, sempre [TipoMovimentacao.embarque]).
  ///
  /// A hora do aviso é a do embarque gravado na presença
  /// (`presenca.embarque!.dataHora`), não a hora atual: o embarque pode chegar
  /// por sincronização offline (RNF-006).
  ///
  /// UC-I02 A1: aluno sem responsável vinculado não gera aviso e retorna
  /// normalmente, sem erro.
  Future<void> notificarMovimentacao(
    Presenca presenca,
    TipoMovimentacao tipo,
  );
}
