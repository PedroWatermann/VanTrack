import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';
import 'package:vantrack_backend/cadastro/dominio/aluno.dart';
import 'package:vantrack_backend/cadastro/dominio/van.dart';
import 'package:vantrack_backend/cadastro/dominio/vinculo_motorista_van.dart';
import 'package:vantrack_backend/cadastro/dominio/vinculo_repository.dart';
import 'package:vantrack_backend/compartilhado/aplicacao/excecoes.dart';
import 'package:vantrack_backend/embarque/aplicacao/embarque_service.dart';
import 'package:vantrack_backend/notificacao/aplicacao/notificacao_service.dart';
import 'package:vantrack_backend/notificacao/dominio/notificacao.dart';
import 'package:vantrack_backend/rota/dominio/excecoes.dart';
import 'package:vantrack_backend/rota/dominio/localizacao.dart';
import 'package:vantrack_backend/rota/dominio/ponto_parada.dart';
import 'package:vantrack_backend/rota/dominio/presenca.dart';
import 'package:vantrack_backend/rota/dominio/presenca_repository.dart';
import 'package:vantrack_backend/rota/dominio/rota.dart';
import 'package:vantrack_backend/rota/dominio/rota_repository.dart';

class _Rotas extends Mock implements RotaRepository {}

class _Presencas extends Mock implements PresencaRepository {}

class _Vinculos extends Mock implements VinculoRepository {}

class _Notificacoes extends Mock implements NotificacaoService {}

/// Testes unitários do `EmbarqueService.registrarEmbarque` com mocktail, sem
/// banco (tasks B-06, B-07 e B-10: VT-35, VT-36 e VT-39). Um grupo por linha da
/// tabela de respostas da seção 3 do backlog.
/// UC-S05 passos 2 a 5 e A1; RF-009; RN-010; RN-012; RNF-006.
void main() {
  const rotaId = 1;
  const vanId = 7;
  const motoristaAtivo = 10;
  const outroMotorista = 11;
  const alunoId = 1;
  const registroId = '2b1f0c3e-8a4d-4f6e-9c1a-7d2e5b8f0a11';
  final horaDoToque = DateTime.parse('2026-11-16T06:42:10-03:00');
  const localDoToque = Localizacao(latitude: -23.40, longitude: -51.93);

  final rota = Rota(
    id: rotaId,
    van: Van(id: vanId, placa: 'ABC-1D23', modelo: 'Sprinter', capacidade: 15),
    data: DateTime(2026, 11, 16),
    trajeto: Trajeto.ida,
    horarioPrevisto: DateTime.parse('2026-11-16T06:30:00-03:00'),
    situacao: 'ATIVA',
  );

  final vinculoAtivo = VinculoMotoristaVan(
    id: 1,
    motoristaId: motoristaAtivo,
    vanId: vanId,
    inicio: DateTime(2026, 1, 1),
  );

  Presenca presenca(SituacaoPresenca situacao) => Presenca(
        id: 1,
        rotaId: rotaId,
        aluno: Aluno(
          id: alunoId,
          nome: 'Ana Souza',
          dataNascimento: DateTime(2014, 3, 10),
        ),
        pontoParada: PontoParada(
          id: 1,
          endereco: 'Rua das Acácias, 100',
          localizacao:
              const Localizacao(latitude: -23.4205, longitude: -51.9331),
        ),
        ordem: 1,
        situacao: situacao,
      );

  late _Rotas rotas;
  late _Presencas presencas;
  late _Vinculos vinculos;
  late _Notificacoes notificacoes;
  late EmbarqueService service;

  setUpAll(() {
    registerFallbackValue(presenca(SituacaoPresenca.confirmado));
    registerFallbackValue(TipoMovimentacao.embarque);
  });

  setUp(() {
    rotas = _Rotas();
    presencas = _Presencas();
    vinculos = _Vinculos();
    notificacoes = _Notificacoes();
    service = EmbarqueService(
      rotaRepository: rotas,
      presencaRepository: presencas,
      vinculoRepository: vinculos,
      notificacaoService: notificacoes,
    );

    // Cenário feliz por padrão; cada teste troca só o que precisa.
    when(() => rotas.buscarPorId(rotaId)).thenAnswer((_) async => rota);
    when(() => vinculos.buscarVinculoAtivo(vanId))
        .thenAnswer((_) async => vinculoAtivo);
    when(() => presencas.buscarPorRegistroId(any()))
        .thenAnswer((_) async => null);
    when(() => presencas.salvar(any())).thenAnswer((_) async {});
    when(() => notificacoes.notificarMovimentacao(any(), any()))
        .thenAnswer((_) async {});
  });

  Future<ResultadoRegistro> registrar({
    int motoristaId = motoristaAtivo,
    Localizacao? localizacao = localDoToque,
  }) =>
      service.registrarEmbarque(
        rotaId: rotaId,
        alunoId: alunoId,
        registroId: registroId,
        dataHora: horaDoToque,
        localizacao: localizacao,
        motoristaId: motoristaId,
      );

  void nadaFoiSalvoNemNotificado() {
    verifyNever(() => presencas.salvar(any()));
    verifyNever(() => notificacoes.notificarMovimentacao(any(), any()));
  }

  // Grupos na ordem da tabela de respostas da seção 3 do backlog
  // (POST /rotas/{rotaId}/embarques): 201, 200, 403, 404 e 409.

  group('201 — embarque registrado (RF-009)', () {
    test('registra o embarque, salva e depois notifica', () async {
      final p = presenca(SituacaoPresenca.confirmado);
      when(() => presencas.buscarPresenca(alunoId, rotaId))
          .thenAnswer((_) async => p);

      final resultado = await registrar();

      expect(resultado.alunoId, alunoId);
      expect(resultado.situacao, SituacaoPresenca.embarcado);
      expect(resultado.jaProcessado, isFalse);
      verifyInOrder([
        () => presencas.salvar(p),
        () => notificacoes.notificarMovimentacao(
              p,
              TipoMovimentacao.embarque,
            ),
      ]);
    });

    test('salva a hora do toque enviada pelo aparelho e a localização',
        () async {
      final p = presenca(SituacaoPresenca.confirmado);
      when(() => presencas.buscarPresenca(alunoId, rotaId))
          .thenAnswer((_) async => p);

      await registrar();

      final salva =
          verify(() => presencas.salvar(captureAny())).captured.single
              as Presenca;
      expect(salva.situacao, SituacaoPresenca.embarcado);
      expect(salva.embarque!.registroId, registroId);
      expect(salva.embarque!.dataHora, horaDoToque);
      expect(salva.embarque!.localizacao, localDoToque);
    });

    test('registra sem localização quando o GPS não respondeu', () async {
      final p = presenca(SituacaoPresenca.confirmado);
      when(() => presencas.buscarPresenca(alunoId, rotaId))
          .thenAnswer((_) async => p);

      await registrar(localizacao: null);

      expect(p.embarque!.localizacao, isNull);
      verify(() => presencas.salvar(p)).called(1);
    });

    test('embarque offline sincronizado horas depois guarda a hora do toque',
        () async {
      // Toque às 06:42 sem sinal; o app só envia às 09:00 (RNF-006).
      final toqueOffline = DateTime.parse('2026-11-16T06:42:10-03:00');
      final p = presenca(SituacaoPresenca.confirmado);
      when(() => presencas.buscarPresenca(alunoId, rotaId))
          .thenAnswer((_) async => p);

      await service.registrarEmbarque(
        rotaId: rotaId,
        alunoId: alunoId,
        registroId: registroId,
        dataHora: toqueOffline,
        motoristaId: motoristaAtivo,
      );

      expect(p.embarque!.dataHora, toqueOffline);
      expect(
        p.embarque!.dataHora.toUtc(),
        DateTime.utc(2026, 11, 16, 9, 42, 10),
        reason: 'é a hora do aparelho, não a do servidor',
      );
    });
  });

  group('200 — registroId já processado (idempotência, RNF-006)', () {
    test('mesmo registroId duas vezes: um embarque e uma notificação',
        () async {
      final p = presenca(SituacaoPresenca.confirmado);
      Presenca? processada;
      when(() => presencas.buscarPresenca(alunoId, rotaId))
          .thenAnswer((_) async => p);
      when(() => presencas.buscarPorRegistroId(registroId))
          .thenAnswer((_) async => processada);
      when(() => presencas.salvar(any())).thenAnswer((invocacao) async {
        processada = invocacao.positionalArguments.first as Presenca;
      });

      final primeiro = await registrar();
      final segundo = await registrar();

      expect(primeiro.jaProcessado, isFalse, reason: '201');
      expect(segundo.jaProcessado, isTrue, reason: '200');
      expect(segundo.alunoId, alunoId);
      expect(segundo.situacao, SituacaoPresenca.embarcado);
      verify(() => presencas.salvar(any())).called(1);
      verify(() => notificacoes.notificarMovimentacao(any(), any()))
          .called(1);
    });

    test('o 200 devolve o mesmo corpo do 201 (alunoId e status)', () async {
      final p = presenca(SituacaoPresenca.confirmado);
      Presenca? processada;
      when(() => presencas.buscarPresenca(alunoId, rotaId))
          .thenAnswer((_) async => p);
      when(() => presencas.buscarPorRegistroId(registroId))
          .thenAnswer((_) async => processada);
      when(() => presencas.salvar(any())).thenAnswer((invocacao) async {
        processada = invocacao.positionalArguments.first as Presenca;
      });

      final r201 = await registrar();
      final r200 = await registrar();

      expect(r200.alunoId, r201.alunoId);
      expect(r200.situacao, r201.situacao);
      expect(r200.situacao.codigo, 'EMBARCADO');
    });

    test('corrida com o mesmo registroId: 200 sem notificar de novo',
        () async {
      final p = presenca(SituacaoPresenca.confirmado);
      var consultas = 0;
      when(() => presencas.buscarPresenca(alunoId, rotaId))
          .thenAnswer((_) async => p);
      // 1ª consulta: ainda não existe. 2ª (depois da recusa do banco): existe.
      when(() => presencas.buscarPorRegistroId(registroId)).thenAnswer(
        (_) async =>
            ++consultas == 1 ? null : presenca(SituacaoPresenca.embarcado),
      );
      when(() => presencas.salvar(any()))
          .thenThrow(const EmbarqueDuplicadoException(registroId));

      final resultado = await registrar();

      expect(resultado.jaProcessado, isTrue);
      expect(resultado.situacao, SituacaoPresenca.embarcado);
      verifyNever(() => notificacoes.notificarMovimentacao(any(), any()));
    });
  });

  group('403 — não é o motorista ativo da van (RN-012)', () {
    test('motorista que não é o do vínculo ativo da van', () async {
      await expectLater(
        registrar(motoristaId: outroMotorista),
        throwsA(isA<AcessoNegadoException>()),
      );
      // A ordem do diagrama de sequência: o 403 vem antes da idempotência e
      // da busca da presença.
      verifyNever(() => presencas.buscarPorRegistroId(any()));
      verifyNever(() => presencas.buscarPresenca(any(), any()));
      nadaFoiSalvoNemNotificado();
    });

    test('registro já processado não dispensa o RN-012', () async {
      when(() => presencas.buscarPorRegistroId(registroId)).thenAnswer(
        (_) async => presenca(SituacaoPresenca.embarcado),
      );

      await expectLater(
        registrar(motoristaId: outroMotorista),
        throwsA(isA<AcessoNegadoException>()),
      );
      nadaFoiSalvoNemNotificado();
    });

    test('van sem vínculo ativo', () async {
      when(() => vinculos.buscarVinculoAtivo(vanId))
          .thenAnswer((_) async => null);

      await expectLater(
        registrar(),
        throwsA(isA<AcessoNegadoException>()),
      );
      nadaFoiSalvoNemNotificado();
    });

    test('vínculo encerrado não autoriza', () async {
      when(() => vinculos.buscarVinculoAtivo(vanId)).thenAnswer(
        (_) async => VinculoMotoristaVan(
          id: 2,
          motoristaId: motoristaAtivo,
          vanId: vanId,
          inicio: DateTime(2025, 1, 1),
          fim: DateTime(2025, 12, 31),
        ),
      );

      await expectLater(
        registrar(),
        throwsA(isA<AcessoNegadoException>()),
      );
      nadaFoiSalvoNemNotificado();
    });
  });

  group('404 — rota ou aluno não existe', () {
    test('rota inexistente (antes de conferir o motorista)', () async {
      when(() => rotas.buscarPorId(rotaId)).thenAnswer((_) async => null);

      await expectLater(
        registrar(),
        throwsA(isA<NaoEncontradoException>()),
      );
      verifyNever(() => vinculos.buscarVinculoAtivo(any()));
      verifyNever(() => presencas.buscarPorRegistroId(any()));
      nadaFoiSalvoNemNotificado();
    });

    test('aluno sem presença na rota', () async {
      when(() => presencas.buscarPresenca(alunoId, rotaId))
          .thenAnswer((_) async => null);

      await expectLater(
        registrar(),
        throwsA(isA<NaoEncontradoException>()),
      );
      nadaFoiSalvoNemNotificado();
    });
  });

  group('409 — aluno não confirmado ou já embarcado (RN-010)', () {
    test('aluno AUSENTE não embarca', () async {
      when(() => presencas.buscarPresenca(alunoId, rotaId))
          .thenAnswer((_) async => presenca(SituacaoPresenca.ausente));

      await expectLater(
        registrar(),
        throwsA(isA<EmbarqueNaoPermitidoException>()),
      );
      nadaFoiSalvoNemNotificado();
    });

    test('aluno já EMBARCADO não embarca de novo', () async {
      when(() => presencas.buscarPresenca(alunoId, rotaId))
          .thenAnswer((_) async => presenca(SituacaoPresenca.embarcado));

      await expectLater(
        registrar(),
        throwsA(isA<EmbarqueNaoPermitidoException>()),
      );
      nadaFoiSalvoNemNotificado();
    });

    test('corrida com outro registroId: 409 sem notificar', () async {
      when(() => presencas.buscarPresenca(alunoId, rotaId))
          .thenAnswer((_) async => presenca(SituacaoPresenca.confirmado));
      when(() => presencas.salvar(any()))
          .thenThrow(const EmbarqueDuplicadoException(registroId));

      await expectLater(
        registrar(),
        throwsA(
          isA<EmbarqueNaoPermitidoException>().having(
            (e) => e.situacaoAtual,
            'situacaoAtual',
            SituacaoPresenca.embarcado,
          ),
        ),
      );
      verifyNever(() => notificacoes.notificarMovimentacao(any(), any()));
    });
  });

  test('se salvar falhar, ninguém é notificado', () async {
    when(() => presencas.buscarPresenca(alunoId, rotaId))
        .thenAnswer((_) async => presenca(SituacaoPresenca.confirmado));
    when(() => presencas.salvar(any())).thenThrow(StateError('banco fora'));

    await expectLater(registrar(), throwsA(isA<StateError>()));
    verifyNever(() => notificacoes.notificarMovimentacao(any(), any()));
  });
}
