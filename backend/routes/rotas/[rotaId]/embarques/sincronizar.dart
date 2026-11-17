import 'package:dart_frog/dart_frog.dart';
import 'package:vantrack_backend/compartilhado/apresentacao/usuario_logado.dart';
import 'package:vantrack_backend/embarque/apresentacao/embarque_controller.dart';

/// `POST /rotas/{rotaId}/embarques/sincronizar` — UC-S05 A1, RNF-006
/// (task B-09). Só lê a requisição e chama o [EmbarqueController].
Future<Response> onRequest(RequestContext context, String rotaId) =>
    context.read<EmbarqueController>().sincronizar(
          rotaId,
          context.request,
          context.read<UsuarioLogado>(),
        );
