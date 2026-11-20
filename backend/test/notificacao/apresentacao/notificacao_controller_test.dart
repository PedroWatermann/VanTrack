import 'dart:convert';
import 'dart:io';

import 'package:dart_frog/dart_frog.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';
import 'package:vantrack_backend/cadastro/dominio/aluno.dart';
import 'package:vantrack_backend/cadastro/dominio/motorista.dart';
import 'package:vantrack_backend/cadastro/dominio/responsavel.dart';
import 'package:vantrack_backend/autenticacao/apresentacao/autenticacao_middleware.dart';
import 'package:vantrack_backend/autenticacao/dominio/sessao.dart';
import 'package:vantrack_backend/autenticacao/dominio/sessao_repository.dart';
import 'package:vantrack_backend/notificacao/aplicacao/avisos_service.dart';
import 'package:vantrack_backend/notificacao/apresentacao/notificacao_controller.dart';
import 'package:vantrack_backend/notificacao/dominio/notificacao.dart';
import 'package:vantrack_backend/notificacao/dominio/notificacao_repository.dart';

import '../../../routes/notificacoes/index.dart' as lista;
import '../../../routes/notificacoes/[id]/lida.dart' as lida;

class _Repositorio extends Mock implements NotificacaoRepository {}

class _Sessoes extends Mock implements SessaoRepository {}

/// VT-45: HTTP → controller → service com a autenticação real e repositórios mockados.
/// UC-I02/RF-011; RN-002: isolamento entre famílias e entre papéis com o mesmo id.
void main() {
  const tokenResponsavel = '11000000-0000-4000-8000-000000000001';
  const tokenOutraFamilia = '11000000-0000-4000-8000-000000000003';
  const tokenMotorista = '11000000-0000-4000-8000-000000000004';
  late _Repositorio repositorio;
  late _Sessoes sessoes;
  late List<Notificacao> avisos;
  late HttpServer servidor;
  late HttpClient cliente;

  Notificacao criarAviso(int id, int responsavelId) => Notificacao(
        id: id,
        tipo: TipoMovimentacao.embarque,
        responsavelId: responsavelId,
        aluno: Aluno(id: 1, nome: 'Ana Souza', dataNascimento: DateTime(2014)),
        mensagem: 'Ana Souza embarcou na van às 06:42.',
        dataHoraEvento: DateTime.parse('2026-11-16T06:42:10-03:00'),
      );

  setUpAll(() => registerFallbackValue(criarAviso(10, 1)));
  setUp(() async {
    repositorio = _Repositorio();
    sessoes = _Sessoes();
    avisos = [criarAviso(10, 1)];
    final usuarios = {
      tokenResponsavel: Responsavel(
          id: 1, nome: 'Maria', login: 'maria', telefone: '', email: ''),
      tokenOutraFamilia: Responsavel(
          id: 3, nome: 'Paula', login: 'paula', telefone: '', email: ''),
      tokenMotorista:
          Motorista(id: 1, nome: 'João', login: 'joao', telefone: '', cnh: ''),
    };
    when(() => sessoes.buscarPorToken(any())).thenAnswer((chamada) async {
      final token = chamada.positionalArguments.single as String;
      final usuario = usuarios[token];
      return usuario == null
          ? null
          : Sessao(token: token, usuario: usuario, criadaEm: DateTime.now());
    });
    when(() => repositorio.buscarDoResponsavel(any(), any()))
        .thenAnswer((chamada) async {
      final id = chamada.positionalArguments[0] as int;
      final desde = chamada.positionalArguments[1] as DateTime?;
      return avisos
          .where((a) =>
              a.pertenceA(id) &&
              (desde == null || a.dataHoraEvento.isAfter(desde)))
          .toList();
    });
    when(() => repositorio.buscarPorId(any())).thenAnswer((chamada) async {
      final encontrados =
          avisos.where((a) => a.id == chamada.positionalArguments.single);
      return encontrados.isEmpty ? null : encontrados.single;
    });
    when(() => repositorio.salvar(any())).thenAnswer((_) async {});
    final controller = NotificacaoController(AvisosService(repositorio));
    final router = Router()
      ..all('/notificacoes', lista.onRequest)
      ..all('/notificacoes/<id>/lida', lida.onRequest);
    servidor = await serve(
      router.call
          .use(provider<NotificacaoController>((_) => controller))
          .use(AutenticacaoMiddleware(sessoes).middleware()),
      InternetAddress.loopbackIPv4,
      0,
    );
    cliente = HttpClient();
  });
  tearDown(() async {
    cliente.close(force: true);
    await servidor.close(force: true);
  });

  Future<({int codigo, Object? corpo, HttpHeaders headers})> pedir(
      String metodo, String caminho,
      {String? token = tokenResponsavel, String? desde}) async {
    var uri = Uri.parse('http://127.0.0.1:${servidor.port}$caminho');
    if (desde != null) uri = uri.replace(queryParameters: {'desde': desde});
    final pedido = await cliente.openUrl(metodo, uri);
    if (token != null) pedido.headers.set('Authorization', 'Bearer $token');
    final resposta = await pedido.close();
    final texto = await utf8.decoder.bind(resposta).join();
    return (
      codigo: resposta.statusCode,
      corpo: texto.isEmpty ? null : jsonDecode(texto),
      headers: resposta.headers,
    );
  }

  test('GET devolve o contrato exato da API com a hora de Brasília', () async {
    final r = await pedir('GET', '/notificacoes');

    expect(r.codigo, 200);
    expect(r.corpo, [
      {
        'id': 10,
        'tipo': 'EMBARQUE',
        'alunoId': 1,
        'alunoNome': 'Ana Souza',
        'mensagem': 'Ana Souza embarcou na van às 06:42.',
        'dataHora': '2026-11-16T06:42:10-03:00',
        'lida': false,
      },
    ]);
    verify(() => repositorio.buscarDoResponsavel(1, null)).called(1);
  });

  test('outra família não recebe nem marca o aviso', () async {
    final lista = await pedir('GET', '/notificacoes', token: tokenOutraFamilia);
    final marca =
        await pedir('PATCH', '/notificacoes/10/lida', token: tokenOutraFamilia);

    expect(lista.codigo, 200);
    expect(lista.corpo, isEmpty);
    expect(marca.codigo, 403);
    expect(avisos.single.lida, isFalse);
    verifyNever(() => repositorio.salvar(any()));
    verify(() => repositorio.buscarDoResponsavel(3, null)).called(1);
  });

  test(
      'desde aceita fuso, exclui o limite e retorna somente eventos posteriores',
      () async {
    final antes =
        await pedir('GET', '/notificacoes', desde: '2026-11-16T11:42:09+02:00');
    final limite =
        await pedir('GET', '/notificacoes', desde: '2026-11-16T06:42:10-03:00');

    expect(antes.codigo, 200);
    expect(antes.corpo, hasLength(1));
    expect(limite.codigo, 200);
    expect(limite.corpo, isEmpty);
    verify(() => repositorio.buscarDoResponsavel(
        1, DateTime.parse('2026-11-16T09:42:10Z'))).called(1);
  });

  test('desde vazio, inválido ou sem fuso recebe 400', () async {
    for (final desde in ['', 'ontem', '2026-11-16T06:42:00']) {
      expect((await pedir('GET', '/notificacoes', desde: desde)).codigo, 400);
    }
    verifyZeroInteractions(repositorio);
  });

  test('destinatário marca o aviso e a consulta seguinte mostra lida=true',
      () async {
    final r = await pedir('PATCH', '/notificacoes/10/lida');

    expect(r.codigo, 204);
    expect(r.corpo, isNull);
    final lista = await pedir('GET', '/notificacoes');
    expect((lista.corpo! as List).single['lida'], isTrue);
    verify(() => repositorio.salvar(avisos.single)).called(1);
  });

  test('id inexistente ou inválido recebe 404', () async {
    for (final id in ['99', 'abc', '0', '-1']) {
      expect((await pedir('PATCH', '/notificacoes/$id/lida')).codigo, 404);
    }
    verifyNever(() => repositorio.salvar(any()));
  });

  test('motorista com o mesmo id do responsável recebe 403 nas duas rotas',
      () async {
    expect((await pedir('GET', '/notificacoes', token: tokenMotorista)).codigo,
        403);
    expect(
        (await pedir('PATCH', '/notificacoes/10/lida', token: tokenMotorista))
            .codigo,
        403);
    verifyZeroInteractions(repositorio);
  });

  test('token ausente, inválido ou não cadastrado recebe 401 nas duas rotas',
      () async {
    for (final token in [
      null,
      'invalido',
      '11000000-0000-4000-8000-000000000099'
    ]) {
      expect((await pedir('GET', '/notificacoes', token: token)).codigo, 401);
      expect(
          (await pedir('PATCH', '/notificacoes/10/lida', token: token)).codigo,
          401);
    }
    verifyZeroInteractions(repositorio);
  });

  test('métodos diferentes de GET e PATCH recebem 405 com Allow', () async {
    final lista = await pedir('POST', '/notificacoes');
    final marca = await pedir('GET', '/notificacoes/10/lida');

    expect(lista.codigo, 405);
    expect(lista.headers.value('allow'), 'GET');
    expect(marca.codigo, 405);
    expect(marca.headers.value('allow'), 'PATCH');
    verifyZeroInteractions(repositorio);
  });
}
