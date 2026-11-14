import 'package:dart_frog/dart_frog.dart';
import 'package:vantrack_backend/compartilhado/apresentacao/cors.dart';

/// Middleware raiz, aplicado a TODAS as rotas.
///
/// O CORS fica por fora para responder o preflight OPTIONS antes de qualquer
/// outra verificação e para pôr os cabeçalhos até nas respostas de erro.
Handler middleware(Handler handler) {
  return handler.use(cors()).use(requestLogger());
}
