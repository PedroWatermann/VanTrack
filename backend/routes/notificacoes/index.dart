import 'package:dart_frog/dart_frog.dart';
import 'package:vantrack_backend/compartilhado/apresentacao/usuario_logado.dart';
import 'package:vantrack_backend/notificacao/apresentacao/notificacao_controller.dart';

/// GET /notificacoes?desde= — UC-I02, RF-011, RN-002 (VT-45).
Future<Response> onRequest(RequestContext context) =>
    context.read<NotificacaoController>().listar(
          context.request,
          context.read<UsuarioLogado>(),
        );
