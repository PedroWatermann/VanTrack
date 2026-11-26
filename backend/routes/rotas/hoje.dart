import 'package:dart_frog/dart_frog.dart';
import 'package:vantrack_backend/compartilhado/apresentacao/usuario_logado.dart';
import 'package:vantrack_backend/embarque/apresentacao/embarque_controller.dart';

/// `GET /rotas/hoje` — rota de hoje do motorista logado (task A-08; pontos 8 e
/// 9 do 03-arquitetura.md). Só lê a requisição e chama o [EmbarqueController].
Future<Response> onRequest(RequestContext context) =>
    context.read<EmbarqueController>().buscarRotaDoDia(
          context.request,
          context.read<UsuarioLogado>(),
        );
