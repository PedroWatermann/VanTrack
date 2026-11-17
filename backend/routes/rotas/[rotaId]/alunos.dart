import 'package:dart_frog/dart_frog.dart';
import 'package:vantrack_backend/compartilhado/apresentacao/usuario_logado.dart';
import 'package:vantrack_backend/embarque/apresentacao/embarque_controller.dart';

/// `GET /rotas/{rotaId}/alunos` — UC-S05 passo 1, RN-010, RN-012 (task A-08).
/// Só lê a requisição e chama o [EmbarqueController].
Future<Response> onRequest(RequestContext context, String rotaId) =>
    context.read<EmbarqueController>().listarAlunos(
          rotaId,
          context.request,
          context.read<UsuarioLogado>(),
        );
