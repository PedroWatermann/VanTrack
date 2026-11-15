import 'responsavel.dart';
import 'vinculo_motorista_van.dart';

/// `VinculoRepository` — contrato no cadastro :: domínio.
///
/// Responsabilidade: consultar os vínculos aluno–responsável e motorista–van.
/// Implementação: `VinculoRepositoryPostgres` (cadastro :: infraestrutura).
/// Usado pelo `EmbarqueService` (UC-S05, RN-012) e pelo `NotificacaoServicePadrao`
/// (UC-I02, RN-002, RN-009).
abstract class VinculoRepository {
  /// RN-002, RN-009: responsáveis vinculados ao aluno. Lista vazia quando o
  /// aluno não tem responsável (A1 do UC-I02).
  Future<List<Responsavel>> buscarResponsaveis(int alunoId);

  /// RN-012: vínculo ativo da van, ou `null` se a van está sem motorista.
  Future<VinculoMotoristaVan?> buscarVinculoAtivo(int vanId);
}
