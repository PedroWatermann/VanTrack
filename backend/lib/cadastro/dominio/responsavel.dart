import 'usuario.dart';

/// `Responsavel` — cadastro :: domínio. Herda de [Usuario].
///
/// Responsabilidade: representar quem acompanha o aluno e recebe os avisos de
/// embarque (UC-I02, RF-011). Só vê os alunos vinculados a ele (RN-002).
/// RN-009: aluno menor tem pelo menos um responsável; o maior pode ter nenhum.
class Responsavel extends Usuario {
  Responsavel({
    required super.id,
    required super.nome,
    required super.login,
    required this.telefone,
    required this.email,
    super.senhaHash,
  });

  final String telefone;
  final String email;

  @override
  Papel get papel => Papel.responsavel;
}
