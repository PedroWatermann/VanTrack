import 'package:dart_frog/dart_frog.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';
import 'package:vantrack_backend/compartilhado/apresentacao/cors.dart';

class _MockRequestContext extends Mock implements RequestContext {}

void main() {
  late bool rotaFoiChamada;
  late Handler handler;

  setUp(() {
    rotaFoiChamada = false;
    handler = cors()((_) {
      rotaFoiChamada = true;
      return Response.json(statusCode: 401, body: {'erro': 'x'});
    });
  });

  RequestContext contexto(Request request) {
    final context = _MockRequestContext();
    when(() => context.request).thenReturn(request);
    return context;
  }

  final url = Uri.parse('http://localhost/rotas/1/alunos');

  test('preflight OPTIONS responde 204 sem chamar a rota', () async {
    final resposta = await handler(contexto(Request('OPTIONS', url)));

    expect(resposta.statusCode, 204);
    expect(resposta.headers['Access-Control-Allow-Origin'], '*');
    expect(
      resposta.headers['Access-Control-Allow-Headers'],
      contains('Authorization'),
    );
    expect(rotaFoiChamada, isFalse);
  });

  test('respostas normais (inclusive de erro) recebem os cabeçalhos', () async {
    final resposta = await handler(contexto(Request.get(url)));

    expect(resposta.statusCode, 401);
    expect(resposta.headers['Access-Control-Allow-Origin'], '*');
    expect(rotaFoiChamada, isTrue);
  });
}
