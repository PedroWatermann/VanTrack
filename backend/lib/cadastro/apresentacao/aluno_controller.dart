import 'package:dart_frog/dart_frog.dart';

import '../../compartilhado/apresentacao/usuario_logado.dart';
import '../aplicacao/aluno_service.dart';
import '../dominio/usuario.dart';

/// `AlunoController` — cadastro :: apresentação (task VT-70).
///
/// Responsabilidade: converter `GET /alunos` em chamada ao [AlunoService] e a
/// resposta em JSON. Sem regra de negócio e sem acesso a repositório.
///
/// RN-002: a identidade vem do token (`UsuarioLogado`), nunca de parâmetro da
/// requisição, então cada família só recebe os próprios alunos. UC-I02; RF-011.
class AlunoController {
  const AlunoController(this.service);

  final AlunoService service;

  /// `GET /alunos` → `[ { "alunoId": 1, "nome": "Ana Souza" } ]`.
  /// Respostas: 200, 403 (não é responsável) e 405 (método diferente de GET).
  Future<Response> listarDoResponsavel(
    Request pedido,
    UsuarioLogado usuario,
  ) async {
    if (pedido.method != HttpMethod.get) {
      return Response(statusCode: 405, headers: {'Allow': 'GET'});
    }
    // Só responsável: o id de um motorista pode coincidir com o de um
    // responsável (tabelas diferentes).
    if (usuario.papel != Papel.responsavel) {
      return Response.json(
        statusCode: 403,
        body: {'erro': 'Somente responsáveis podem consultar os seus alunos.'},
      );
    }
    final alunos = await service.listarDoResponsavel(usuario.id);
    return Response.json(
      body: [
        for (final aluno in alunos) {'alunoId': aluno.id, 'nome': aluno.nome},
      ],
    );
  }
}
