import 'package:dart_frog/dart_frog.dart';
import 'package:vantrack_backend/compartilhado/apresentacao/usuario_logado.dart';
import 'package:vantrack_backend/notificacao/apresentacao/notificacao_controller.dart';

/// PATCH /notificacoes/{id}/lida — UC-I02, RF-011, RN-002 (VT-45).
Future<Response> onRequest(RequestContext context, String id) =>
    context.read<NotificacaoController>().marcarComoLida(
          id,
          context.request,
          context.read<UsuarioLogado>(),
        );
