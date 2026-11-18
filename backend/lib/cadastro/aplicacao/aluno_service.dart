import '../dominio/aluno.dart';
import '../dominio/vinculo_repository.dart';

/// `AlunoService` — cadastro :: aplicação (task VT-70).
///
/// Responsabilidade: consultar os alunos vinculados a um responsável, para a
/// tela "Avisos" mostrar um card por aluno, inclusive de quem ainda não
/// embarcou ("Aguardando embarque").
///
/// RN-002 (o responsável só vê os seus alunos); UC-I02; RF-011.
/// Depende só do contrato [VinculoRepository]; testado com mocks, sem banco.
class AlunoService {
  const AlunoService(this._vinculoRepository);

  final VinculoRepository _vinculoRepository;

  /// RN-002: alunos do responsável [responsavelId], em ordem de nome.
  Future<List<Aluno>> listarDoResponsavel(int responsavelId) =>
      _vinculoRepository.buscarAlunosDoResponsavel(responsavelId);
}
