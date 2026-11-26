import 'package:dart_frog/dart_frog.dart';

/// `GET /` — verifica se o servidor está no ar (não acessa o banco).
Response onRequest(RequestContext context) {
  return Response.json(body: {'status': 'ok', 'servico': 'VanTrack API'});
}
