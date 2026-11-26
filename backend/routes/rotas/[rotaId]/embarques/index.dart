import 'package:dart_frog/dart_frog.dart';
import 'package:vantrack_backend/compartilhado/apresentacao/usuario_logado.dart';
import 'package:vantrack_backend/embarque/apresentacao/embarque_controller.dart';

/// `POST /rotas/{rotaId}/embarques` — UC-S05, RF-009 (task B-08).
/// Só lê a requisição e chama o [EmbarqueController].
Future<Response> onRequest(RequestContext context, String rotaId) =>
    context.read<EmbarqueController>().registrarEmbarque(
          rotaId,
          context.request,
          context.read<UsuarioLogado>(),
        );
