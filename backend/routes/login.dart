import 'package:dart_frog/dart_frog.dart';
import 'package:vantrack_backend/compartilhado/apresentacao/autenticacao_controller.dart';

Future<Response> onRequest(RequestContext context) =>
    context.read<AutenticacaoController>().entrar(context.request);
