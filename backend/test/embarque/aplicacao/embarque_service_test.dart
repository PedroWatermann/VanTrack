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

/// Testes da task B-06 (VT-35): `EmbarqueService.registrarEmbarque` com
/// mocktail, sem banco. UC-S05 passos 2 a 5; RF-009; RN-010; RN-012.
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

  group('sucesso (201)', () {
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
  });

  group('403 — RN-012', () {
    test('motorista que não é o do vínculo ativo da van', () async {
      await expectLater(
        registrar(motoristaId: outroMotorista),
        throwsA(isA<AcessoNegadoException>()),
      );
      verifyNever(() => presencas.buscarPresenca(any(), any()));
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

  group('404', () {
    test('rota inexistente', () async {
      when(() => rotas.buscarPorId(rotaId)).thenAnswer((_) async => null);

      await expectLater(
        registrar(),
        throwsA(isA<NaoEncontradoException>()),
      );
      verifyNever(() => vinculos.buscarVinculoAtivo(any()));
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

  group('409 — RN-010', () {
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
  });

  test('se salvar falhar, ninguém é notificado', () async {
    when(() => presencas.buscarPresenca(alunoId, rotaId))
        .thenAnswer((_) async => presenca(SituacaoPresenca.confirmado));
    when(() => presencas.salvar(any())).thenThrow(StateError('banco fora'));

    await expectLater(registrar(), throwsA(isA<StateError>()));
    verifyNever(() => notificacoes.notificarMovimentacao(any(), any()));
  });
}
