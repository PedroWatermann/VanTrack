import 'dart:convert';
import 'dart:io';

import 'package:dart_frog/dart_frog.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';
import 'package:uuid/validation.dart';
import 'package:vantrack_backend/cadastro/dominio/motorista.dart';
import 'package:vantrack_backend/cadastro/dominio/responsavel.dart';
import 'package:vantrack_backend/cadastro/dominio/usuario.dart';
import 'package:vantrack_backend/compartilhado/aplicacao/autenticacao_service.dart';
import 'package:vantrack_backend/compartilhado/apresentacao/autenticacao_controller.dart';
import 'package:vantrack_backend/compartilhado/apresentacao/autenticacao_middleware.dart';
import 'package:vantrack_backend/compartilhado/apresentacao/cors.dart';
import 'package:vantrack_backend/compartilhado/apresentacao/usuario_logado.dart';
import 'package:vantrack_backend/compartilhado/dominio/sessao.dart';
import 'package:vantrack_backend/compartilhado/dominio/sessao_repository.dart';
import 'package:vantrack_backend/compartilhado/dominio/usuario_repository.dart';
import '../../routes/_middleware.dart' as raiz;
import '../../routes/index.dart' as inicio;
import '../../routes/login.dart' as login;
import '../../routes/usuarios.dart' as usuarios;

class _Usuarios extends Mock implements UsuarioRepository {}

class _Sessoes extends Mock implements SessaoRepository {}

void main() {
  final lista = <Usuario>[
    Motorista(id: 1, nome: 'João', login: 'joao', telefone: '', cnh: ''),
    Responsavel(id: 1, nome: 'Maria', login: 'maria', telefone: '', email: ''),
  ];
  late _Usuarios consulta;
  late _Sessoes sessoes;
  late Map<String, Sessao> salvas;
  late HttpServer servidor;
  late HttpClient cliente;

  setUpAll(() {
    registerFallbackValue(Papel.motorista);
    registerFallbackValue(
        Sessao(token: '', usuario: lista.first, criadaEm: DateTime.now()));
  });
  setUp(() async {
    consulta = _Usuarios();
    sessoes = _Sessoes();
    salvas = {};
    when(() => consulta.listar()).thenAnswer((_) async => lista);
    when(() => consulta.buscarPorIdEPapel(any(), any()))
        .thenAnswer((chamada) async {
      final encontrados = lista.where((u) =>
          u.id == chamada.positionalArguments[0] &&
          u.papel == chamada.positionalArguments[1]);
      return encontrados.isEmpty ? null : encontrados.single;
    });
    when(() => sessoes.salvar(any())).thenAnswer((chamada) async {
      final sessao = chamada.positionalArguments.single as Sessao;
      salvas[sessao.token] = sessao;
    });
    when(() => sessoes.buscarPorToken(any())).thenAnswer(
        (chamada) async => salvas[chamada.positionalArguments.single]);
    final controller =
        AutenticacaoController(AutenticacaoService(consulta, sessoes));
    final router = Router()
      ..all('/usuarios', usuarios.onRequest)
      ..all('/login', login.onRequest)
      ..get('/protegida', (RequestContext context) {
        final u = context.read<UsuarioLogado>();
        return Response.json(body: {'id': u.id, 'papel': u.papel.codigo});
      });
    servidor = await serve(
        router.call
            .use(provider<AutenticacaoController>((_) => controller))
            .use(AutenticacaoMiddleware(sessoes).middleware())
            .use(cors()),
        InternetAddress.loopbackIPv4,
        0);
    cliente = HttpClient();
  });
  tearDown(() async {
    cliente.close(force: true);
    await servidor.close(force: true);
  });

  Future<({int codigo, Object? corpo, HttpHeaders headers})> pedir(
      String metodo, String caminho,
      {Object? corpo, String? token, String? bruto}) async {
    final pedido = await cliente.openUrl(
        metodo, Uri.parse('http://127.0.0.1:${servidor.port}$caminho'));
    if (token != null) pedido.headers.set('Authorization', token);
    if (corpo != null || bruto != null) {
      pedido.headers.contentType = ContentType.json;
      pedido.write(bruto ?? jsonEncode(corpo));
    }
    final resposta = await pedido.close();
    final texto = await utf8.decoder.bind(resposta).join();
    return (
      codigo: resposta.statusCode,
      corpo: texto.isEmpty ? null : jsonDecode(texto),
      headers: resposta.headers
    );
  }

  test('GET /usuarios é público e expõe somente id, nome e papel', () async {
    final r = await pedir('GET', '/usuarios');
    expect(r.codigo, 200);
    expect(r.corpo, [
      {'id': 1, 'nome': 'João', 'papel': 'MOTORISTA'},
      {'id': 1, 'nome': 'Maria', 'papel': 'RESPONSAVEL'},
    ]);
  });
  for (final papel in Papel.values) {
    test('login de ${papel.codigo} persiste UUID e entrega id/papel à rota',
        () async {
      final r = await pedir('POST', '/login',
          corpo: {'id': 1, 'papel': papel.codigo});
      expect(r.codigo, 200);
      final token = (r.corpo! as Map<String, dynamic>)['token'] as String;
      expect(UuidValidation.isValidUUID(fromString: token), isTrue);
      expect(salvas[token]!.usuario,
          same(lista.firstWhere((u) => u.papel == papel)));
      final protegida =
          await pedir('GET', '/protegida', token: 'Bearer $token');
      expect(protegida.codigo, 200);
      expect(protegida.corpo, {'id': 1, 'papel': papel.codigo});
    });
  }
  test('usuário inexistente recebe 401 sem criar sessão', () async {
    expect(
        (await pedir('POST', '/login',
                corpo: {'id': 999, 'papel': 'MOTORISTA'}))
            .codigo,
        401);
    expect(salvas, isEmpty);
  });
  test('corpo inválido recebe 400 sem criar sessão', () async {
    for (final corpo in <Object>[
      {},
      [],
      {'id': '1', 'papel': 'MOTORISTA'},
      {'id': 1, 'papel': 'ADMIN'}
    ]) {
      expect((await pedir('POST', '/login', corpo: corpo)).codigo, 400);
    }
    expect((await pedir('POST', '/login', bruto: '{')).codigo, 400);
    expect(salvas, isEmpty);
  });
  test('token ausente, malformado ou inexistente recebe 401 com CORS',
      () async {
    for (final token in <String?>[
      null,
      'Bearer abc',
      'Basic abc',
      'Bearer 00000000-0000-4000-8000-000000000001'
    ]) {
      final r = await pedir('GET', '/protegida', token: token);
      expect(r.codigo, 401);
      expect(r.headers.value('access-control-allow-origin'), '*');
    }
  });
  test('método incorreto recebe 405', () async {
    expect((await pedir('POST', '/usuarios')).codigo, 405);
    expect((await pedir('GET', '/login')).codigo, 405);
  });
  test(
      'middleware raiz preserva saúde e OPTIONS e exige token nas demais rotas',
      () async {
    await servidor.close(force: true);
    final router = Router()
      ..all('/', inicio.onRequest)
      ..all('/protegida', (_) => Response.json(body: {'acesso': true}));
    servidor = await serve(
        raiz.middleware(router.call), InternetAddress.loopbackIPv4, 0);
    expect((await pedir('GET', '/')).codigo, 200);
    expect((await pedir('OPTIONS', '/protegida')).codigo, 204);
    expect((await pedir('GET', '/protegida')).codigo, 401);
  });
}
