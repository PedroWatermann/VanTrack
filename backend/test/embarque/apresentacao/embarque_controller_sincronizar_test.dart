import 'dart:convert';

import 'package:dart_frog/dart_frog.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';
import 'package:vantrack_backend/cadastro/dominio/usuario.dart';
import 'package:vantrack_backend/compartilhado/aplicacao/excecoes.dart';
import 'package:vantrack_backend/compartilhado/apresentacao/usuario_logado.dart';
import 'package:vantrack_backend/embarque/aplicacao/embarque_service.dart';
import 'package:vantrack_backend/embarque/apresentacao/embarque_controller.dart';
import 'package:vantrack_backend/rota/dominio/excecoes.dart';
import 'package:vantrack_backend/rota/dominio/presenca.dart';

class _Service extends Mock implements EmbarqueService {}

/// Testes da task B-09 (VT-38): `POST /rotas/{rotaId}/embarques/sincronizar`.
/// UC-S05 A1; RNF-006. O formato da resposta é o que o app do Membro E lê
/// (`{ resultados: [ { registroId, codigo } ] }`).
void main() {
  const motorista = UsuarioLogado(id: 10, papel: Papel.motorista);
  const responsavel = UsuarioLogado(id: 10, papel: Papel.responsavel);
  final uri = Uri.parse('http://localhost/rotas/1/embarques/sincronizar');

  // Um registroId por situação do lote.
  const aceito = '11111111-1111-4111-8111-111111111111';
  const repetido = '22222222-2222-4222-8222-222222222222';
  const conflito = '33333333-3333-4333-8333-333333333333';
  const quebra = '44444444-4444-4444-8444-444444444444';
  const depoisDoErro = '55555555-5555-4555-8555-555555555555';

  late _Service service;
  late EmbarqueController controller;

  Map<String, Object?> registro(String registroId, {int alunoId = 1}) => {
        'registroId': registroId,
        'alunoId': alunoId,
        // Formato que o app envia: UTC com "Z".
        'dataHora': '2026-11-16T09:42:10.000Z',
      };

  Request post(Object? corpo) =>
      Request.post(uri, body: corpo is String ? corpo : jsonEncode(corpo));

  Future<List<Object?>> resultadosDe(Response resposta) async =>
      (await resposta.json() as Map<String, dynamic>)['resultados']
          as List<Object?>;

  void quandoRegistrar(
      String registroId, Future<ResultadoRegistro> Function() resposta) {
    when(
      () => service.registrarEmbarque(
        rotaId: any(named: 'rotaId'),
        alunoId: any(named: 'alunoId'),
        registroId: registroId,
        dataHora: any(named: 'dataHora'),
        motoristaId: any(named: 'motoristaId'),
        localizacao: any(named: 'localizacao'),
      ),
    ).thenAnswer((_) => resposta());
  }

  void serviceNuncaChamado() => verifyNever(
        () => service.registrarEmbarque(
          rotaId: any(named: 'rotaId'),
          alunoId: any(named: 'alunoId'),
          registroId: any(named: 'registroId'),
          dataHora: any(named: 'dataHora'),
          motoristaId: any(named: 'motoristaId'),
          localizacao: any(named: 'localizacao'),
        ),
      );

  const embarcado = ResultadoRegistro(
    alunoId: 1,
    situacao: SituacaoPresenca.embarcado,
  );

  setUpAll(() {
    registerFallbackValue(DateTime(2026));
  });

  setUp(() {
    service = _Service();
    controller = EmbarqueController(service);
  });

  test('lote misto: cada registro recebe o seu código, na ordem do envio',
      () async {
    quandoRegistrar(aceito, () async => embarcado);
    quandoRegistrar(
      repetido,
      () async => const ResultadoRegistro(
        alunoId: 2,
        situacao: SituacaoPresenca.embarcado,
        jaProcessado: true,
      ),
    );
    quandoRegistrar(
      conflito,
      () async =>
          throw const EmbarqueNaoPermitidoException(SituacaoPresenca.ausente),
    );
    quandoRegistrar(quebra, () async => throw StateError('banco fora'));
    quandoRegistrar(depoisDoErro, () async => embarcado);

    final resposta = await controller.sincronizar(
      '1',
      post({
        'registros': [
          registro(aceito),
          registro(repetido, alunoId: 2),
          registro(conflito, alunoId: 4),
          {'registroId': 'sem-formato-de-uuid', 'alunoId': 3},
          registro(quebra, alunoId: 3),
          registro(depoisDoErro, alunoId: 3),
        ],
      }),
      motorista,
    );

    expect(resposta.statusCode, 200);
    expect(await resultadosDe(resposta), [
      {'registroId': aceito, 'codigo': 201},
      {'registroId': repetido, 'codigo': 200},
      {'registroId': conflito, 'codigo': 409},
      {'registroId': 'sem-formato-de-uuid', 'codigo': 400},
      {'registroId': quebra, 'codigo': 503},
      {'registroId': depoisDoErro, 'codigo': 201},
    ]);
  });

  test('403 e 404 do service viram o código do próprio registro', () async {
    quandoRegistrar(
      aceito,
      () async => throw const AcessoNegadoException('Não é o motorista.'),
    );
    quandoRegistrar(
      repetido,
      () async => throw const NaoEncontradoException('Aluno fora da rota.'),
    );

    final resposta = await controller.sincronizar(
      '1',
      post({
        'registros': [registro(aceito), registro(repetido)],
      }),
      motorista,
    );

    expect(await resultadosDe(resposta), [
      {'registroId': aceito, 'codigo': 403},
      {'registroId': repetido, 'codigo': 404},
    ]);
  });

  test('usa o mesmo EmbarqueService, com a rota da URL e o motorista logado',
      () async {
    quandoRegistrar(aceito, () async => embarcado);

    await controller.sincronizar(
      '1',
      post({
        'registros': [registro(aceito)],
      }),
      motorista,
    );

    final dataHora = verify(
      () => service.registrarEmbarque(
        rotaId: 1,
        alunoId: 1,
        registroId: aceito,
        dataHora: captureAny(named: 'dataHora'),
        motoristaId: 10,
      ),
    ).captured.single as DateTime;
    expect(dataHora, DateTime.utc(2026, 11, 16, 9, 42, 10));
  });

  test('lista vazia: 200 com resultados vazios', () async {
    final resposta = await controller.sincronizar(
      '1',
      post({'registros': <Object>[]}),
      motorista,
    );

    expect(resposta.statusCode, 200);
    expect(await resultadosDe(resposta), isEmpty);
    serviceNuncaChamado();
  });

  group('lote recusado inteiro', () {
    test('405 para método diferente de POST', () async {
      final resposta = await controller.sincronizar(
        '1',
        Request.get(uri),
        motorista,
      );

      expect(resposta.statusCode, 405);
      expect(resposta.headers['Allow'], 'POST');
    });

    test('403 para responsável', () async {
      final resposta = await controller.sincronizar(
        '1',
        post({
          'registros': [registro(aceito)],
        }),
        responsavel,
      );

      expect(resposta.statusCode, 403);
      serviceNuncaChamado();
    });

    test('404 para rotaId que não é número', () async {
      final resposta = await controller.sincronizar(
        'abc',
        post({'registros': <Object>[]}),
        motorista,
      );

      expect(resposta.statusCode, 404);
    });

    for (final (caso, corpo) in [
      ('JSON malformado', '{ registros: '),
      ('corpo sem a lista registros', <String, Object>{}),
      ('registros que não é lista', {'registros': 'x'}),
    ]) {
      test('400: $caso', () async {
        final resposta =
            await controller.sincronizar('1', post(corpo), motorista);

        expect(resposta.statusCode, 400);
        serviceNuncaChamado();
      });
    }
  });
}
