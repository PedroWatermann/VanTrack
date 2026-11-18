import 'package:dart_frog/dart_frog.dart';
import 'package:vantrack_backend/cadastro/apresentacao/aluno_controller.dart';
import 'package:vantrack_backend/compartilhado/apresentacao/usuario_logado.dart';

/// `GET /alunos` — alunos vinculados ao responsável logado (task VT-70; RN-002,
/// UC-I02). Só lê a requisição e chama o [AlunoController].
Future<Response> onRequest(RequestContext context) =>
    context.read<AlunoController>().listarDoResponsavel(
          context.request,
          context.read<UsuarioLogado>(),
        );
