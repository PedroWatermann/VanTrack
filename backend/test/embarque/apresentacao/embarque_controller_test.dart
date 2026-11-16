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
import 'package:vantrack_backend/rota/dominio/localizacao.dart';
import 'package:vantrack_backend/rota/dominio/presenca.dart';

class _Service extends Mock implements EmbarqueService {}

/// Testes da task B-08 (VT-37): `EmbarqueController` e as respostas da seção 3
/// do backlog para `POST /rotas/{rotaId}/embarques`.
void main() {
  const registroId = '2b1f0c3e-8a4d-4f6e-9c1a-7d2e5b8f0a11';
  const motorista = UsuarioLogado(id: 10, papel: Papel.motorista);
  const responsavel = UsuarioLogado(id: 10, papel: Papel.responsavel);
  final uri = Uri.parse('http://localhost/rotas/1/embarques');

  late _Service service;
  late EmbarqueController controller;

  Map<String, Object?> corpoValido() => {
        'registroId': registroId,
        'alunoId': 1,
        'dataHora': '2026-11-16T06:42:10-03:00',
        'latitude': -23.40,
        'longitude': -51.93,
      };

  Request post(Object? corpo) =>
      Request.post(uri, body: corpo is String ? corpo : jsonEncode(corpo));

  void serviceResponde(ResultadoRegistro resultado) {
    when(
      () => service.registrarEmbarque(
        rotaId: any(named: 'rotaId'),
        alunoId: any(named: 'alunoId'),
        registroId: any(named: 'registroId'),
        dataHora: any(named: 'dataHora'),
        motoristaId: any(named: 'motoristaId'),
        localizacao: any(named: 'localizacao'),
      ),
    ).thenAnswer((_) async => resultado);
  }

  void serviceLanca(Exception erro) {
    when(
      () => service.registrarEmbarque(
        rotaId: any(named: 'rotaId'),
        alunoId: any(named: 'alunoId'),
        registroId: any(named: 'registroId'),
        dataHora: any(named: 'dataHora'),
        motoristaId: any(named: 'motoristaId'),
        localizacao: any(named: 'localizacao'),
      ),
    ).thenThrow(erro);
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

  setUpAll(() {
    registerFallbackValue(DateTime(2026));
  });

  setUp(() {
    service = _Service();
    controller = EmbarqueController(service);
  });

  group('sucesso', () {
    test('201 com { alunoId, status: EMBARCADO }', () async {
      serviceResponde(
        const ResultadoRegistro(
          alunoId: 1,
          situacao: SituacaoPresenca.embarcado,
        ),
      );

      final resposta = await controller.registrarEmbarque(
        '1',
        post(corpoValido()),
        motorista,
      );

      expect(resposta.statusCode, 201);
      expect(await resposta.json(), {'alunoId': 1, 'status': 'EMBARCADO'});
    });

    test('200 com o mesmo corpo quando o registroId já foi processado',
        () async {
      serviceResponde(
        const ResultadoRegistro(
          alunoId: 1,
          situacao: SituacaoPresenca.embarcado,
          jaProcessado: true,
        ),
      );

      final resposta = await controller.registrarEmbarque(
        '1',
        post(corpoValido()),
        motorista,
      );

      expect(resposta.statusCode, 200);
      expect(await resposta.json(), {'alunoId': 1, 'status': 'EMBARCADO'});
    });

    test('repassa ao service a hora do toque, a localização e o motorista',
        () async {
      serviceResponde(
        const ResultadoRegistro(
          alunoId: 1,
          situacao: SituacaoPresenca.embarcado,
        ),
      );

      await controller.registrarEmbarque('1', post(corpoValido()), motorista);

      final chamada = verify(
        () => service.registrarEmbarque(
          rotaId: 1,
          alunoId: 1,
          registroId: registroId,
          dataHora: captureAny(named: 'dataHora'),
          motoristaId: 10,
          localizacao: captureAny(named: 'localizacao'),
        ),
      )..called(1);
      final dataHora = chamada.captured[0] as DateTime;
      expect(dataHora, DateTime.utc(2026, 11, 16, 9, 42, 10));
      expect(
        chamada.captured[1],
        const Localizacao(latitude: -23.40, longitude: -51.93),
      );
    });

    test('sem latitude e longitude, envia sem localização', () async {
      serviceResponde(
        const ResultadoRegistro(
          alunoId: 1,
          situacao: SituacaoPresenca.embarcado,
        ),
      );
      final corpo = corpoValido()
        ..remove('latitude')
        ..remove('longitude');

      final resposta =
          await controller.registrarEmbarque('1', post(corpo), motorista);

      expect(resposta.statusCode, 201);
      verify(
        () => service.registrarEmbarque(
          rotaId: 1,
          alunoId: 1,
          registroId: registroId,
          dataHora: any(named: 'dataHora'),
          motoristaId: 10,
        ),
      ).called(1);
    });
  });

  group('erros do caso de uso', () {
    test('403 quando o service nega o acesso (RN-012)', () async {
      serviceLanca(
        const AcessoNegadoException('Você não é o motorista ativo desta van.'),
      );

      final resposta = await controller.registrarEmbarque(
        '1',
        post(corpoValido()),
        motorista,
      );

      expect(resposta.statusCode, 403);
      expect(
        await resposta.json(),
        {'erro': 'Você não é o motorista ativo desta van.'},
      );
    });

    test('403 para responsável, sem chamar o service', () async {
      final resposta = await controller.registrarEmbarque(
        '1',
        post(corpoValido()),
        responsavel,
      );

      expect(resposta.statusCode, 403);
      serviceNuncaChamado();
    });

    test('404 quando a rota ou o aluno não existe', () async {
      serviceLanca(const NaoEncontradoException('Rota não encontrada.'));

      final resposta = await controller.registrarEmbarque(
        '1',
        post(corpoValido()),
        motorista,
      );

      expect(resposta.statusCode, 404);
      expect(await resposta.json(), {'erro': 'Rota não encontrada.'});
    });

    test('409 quando o aluno não está confirmado ou já embarcou (RN-010)',
        () async {
      serviceLanca(
        const EmbarqueNaoPermitidoException(SituacaoPresenca.embarcado),
      );

      final resposta = await controller.registrarEmbarque(
        '1',
        post(corpoValido()),
        motorista,
      );

      expect(resposta.statusCode, 409);
      expect((await resposta.json() as Map)['erro'], isA<String>());
    });

    test('erro inesperado sobe para o middleware raiz (503)', () async {
      serviceLanca(Exception('banco fora'));

      await expectLater(
        controller.registrarEmbarque('1', post(corpoValido()), motorista),
        throwsA(isA<Exception>()),
      );
    });
  });

  group('requisição inválida', () {
    test('405 para método diferente de POST', () async {
      final resposta = await controller.registrarEmbarque(
        '1',
        Request.get(uri),
        motorista,
      );

      expect(resposta.statusCode, 405);
      expect(resposta.headers['Allow'], 'POST');
      serviceNuncaChamado();
    });

    test('404 para rotaId que não é número', () async {
      final resposta = await controller.registrarEmbarque(
        'abc',
        post(corpoValido()),
        motorista,
      );

      expect(resposta.statusCode, 404);
      serviceNuncaChamado();
    });

    final invalidos = <String, Object?>{
      'JSON malformado': '{ registroId: ',
      'corpo que não é objeto': <Object>[],
      'registroId que não é UUID': corpoValido()..['registroId'] = 'abc',
      'alunoId que não é inteiro': corpoValido()..['alunoId'] = '1',
      'alunoId zero': corpoValido()..['alunoId'] = 0,
      'dataHora sem fuso': corpoValido()..['dataHora'] = '2026-11-16T06:42:10',
      'dataHora inválida': corpoValido()..['dataHora'] = 'ontem',
      'só a latitude': corpoValido()..remove('longitude'),
    };
    invalidos.forEach((caso, corpo) {
      test('400: $caso', () async {
        final resposta =
            await controller.registrarEmbarque('1', post(corpo), motorista);

        expect(resposta.statusCode, 400);
        serviceNuncaChamado();
      });
    });
  });
}
