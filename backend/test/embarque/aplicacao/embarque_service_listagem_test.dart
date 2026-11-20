import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';
import 'package:vantrack_backend/cadastro/dominio/aluno.dart';
import 'package:vantrack_backend/cadastro/dominio/van.dart';
import 'package:vantrack_backend/cadastro/dominio/vinculo_motorista_van.dart';
import 'package:vantrack_backend/cadastro/dominio/vinculo_repository.dart';
import 'package:vantrack_backend/compartilhado/aplicacao/excecoes.dart';
import 'package:vantrack_backend/embarque/aplicacao/embarque_service.dart';
import 'package:vantrack_backend/notificacao/aplicacao/notificacao_service.dart';
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

/// Testes da task A-08 (VT-31): `EmbarqueService.listarAlunosConfirmados` e
/// `buscarRotaDoDia`, com mocktail e sem banco. UC-S05 passo 1; RN-010
/// (exceção dos ausentes); RN-012.
void main() {
  const rotaId = 1;
  const vanId = 7;
  const motoristaAtivo = 1;
  const motoristaSemVinculo = 2;

  final rota = Rota(
    id: rotaId,
    van: Van(id: vanId, placa: 'ABC-1D23', modelo: 'Sprinter', capacidade: 15),
    data: DateTime(2026, 11, 16),
    trajeto: Trajeto.ida,
    horarioPrevisto: DateTime.parse('2026-11-16T06:30:00-03:00'),
    situacao: 'ATIVA',
  );

  Presenca presenca(
    int alunoId,
    String nome,
    int ordem, [
    SituacaoPresenca situacao = SituacaoPresenca.confirmado,
  ]) =>
      Presenca(
        id: alunoId,
        rotaId: rotaId,
        aluno: Aluno(id: alunoId, nome: nome, dataNascimento: DateTime(2014)),
        pontoParada: PontoParada(
          id: ordem,
          endereco: 'Rua $ordem, 100',
          localizacao: const Localizacao(latitude: -23.4, longitude: -51.9),
        ),
        ordem: ordem,
        situacao: situacao,
      );

  // Dados do seed, de propósito fora de ordem e com o ausente (Bruno).
  List<Presenca> presencasDoSeed() => [
        presenca(3, 'Carlos Lima', 3),
        presenca(4, 'Bruno Alves', 4, SituacaoPresenca.ausente),
        presenca(1, 'Ana Souza', 1, SituacaoPresenca.embarcado),
        presenca(2, 'Beatriz Reis', 2),
      ];

  late _Rotas rotas;
  late _Presencas presencas;
  late _Vinculos vinculos;
  late DateTime agora;
  late EmbarqueService service;

  setUpAll(() => registerFallbackValue(DateTime(2026)));

  setUp(() {
    rotas = _Rotas();
    presencas = _Presencas();
    vinculos = _Vinculos();
    agora = DateTime.utc(2026, 11, 16, 12);
    service = EmbarqueService(
      rotaRepository: rotas,
      presencaRepository: presencas,
      vinculoRepository: vinculos,
      notificacaoService: _Notificacoes(),
      relogio: () => agora,
    );
    when(() => rotas.buscarPorId(rotaId)).thenAnswer((_) async => rota);
    when(() => rotas.buscarPorId(99)).thenAnswer((_) async => null);
    final vinculoAtivo = VinculoMotoristaVan(
      id: 1,
      motoristaId: motoristaAtivo,
      vanId: vanId,
      inicio: DateTime(2026),
    );
    when(() => vinculos.buscarVinculoAtivo(vanId))
        .thenAnswer((_) async => vinculoAtivo);
    when(() => vinculos.buscarVinculoAtivoDoMotorista(motoristaAtivo))
        .thenAnswer((_) async => vinculoAtivo);
    when(() => vinculos.buscarVinculoAtivoDoMotorista(motoristaSemVinculo))
        .thenAnswer((_) async => null);
    when(() => presencas.buscarConfirmados(rotaId))
        .thenAnswer((_) async => presencasDoSeed());
  });

  group('listarAlunosConfirmados', () {
    test('aluno ausente não aparece (RN-010)', () async {
      final lista =
          await service.listarAlunosConfirmados(rotaId, motoristaAtivo);

      expect(lista.map((p) => p.aluno.nome), isNot(contains('Bruno Alves')));
      expect(lista, hasLength(3));
    });

    test('devolve os alunos na ordem da rota, inclusive os já embarcados',
        () async {
      final lista =
          await service.listarAlunosConfirmados(rotaId, motoristaAtivo);

      expect(lista.map((p) => p.ordem), [1, 2, 3]);
      expect(lista.map((p) => p.aluno.nome), [
        'Ana Souza',
        'Beatriz Reis',
        'Carlos Lima',
      ]);
      expect(lista.first.situacao, SituacaoPresenca.embarcado);
    });

    test('motorista sem vínculo com a van recebe 403 (RN-012)', () async {
      await expectLater(
        service.listarAlunosConfirmados(rotaId, motoristaSemVinculo),
        throwsA(isA<AcessoNegadoException>()),
      );
      verifyNever(() => presencas.buscarConfirmados(any()));
    });

    test('van sem motorista ativo recebe 403 (RN-012)', () async {
      when(() => vinculos.buscarVinculoAtivo(vanId))
          .thenAnswer((_) async => null);

      await expectLater(
        service.listarAlunosConfirmados(rotaId, motoristaAtivo),
        throwsA(isA<AcessoNegadoException>()),
      );
    });

    test('rota que não existe recebe 404', () async {
      await expectLater(
        service.listarAlunosConfirmados(99, motoristaAtivo),
        throwsA(isA<NaoEncontradoException>()),
      );
      verifyNever(() => vinculos.buscarVinculoAtivo(any()));
    });
  });

  group('buscarRotaDoDia', () {
    test('busca a rota do dia de Brasília, não do dia em UTC', () async {
      // 17/11 01:30 em UTC ainda é 16/11 22:30 em Brasília.
      agora = DateTime.utc(2026, 11, 17, 1, 30);
      when(() => rotas.buscarDoMotorista(any(), any()))
          .thenAnswer((_) async => rota);

      final encontrada = await service.buscarRotaDoDia(motoristaAtivo);

      expect(encontrada.id, rotaId);
      final dia = verify(
        () => rotas.buscarDoMotorista(motoristaAtivo, captureAny()),
      ).captured.single as DateTime;
      expect([dia.year, dia.month, dia.day], [2026, 11, 16]);
    });

    test('motorista sem vínculo ativo recebe 403 (RN-012, teste 7)', () async {
      await expectLater(
        service.buscarRotaDoDia(motoristaSemVinculo),
        throwsA(isA<AcessoNegadoException>()),
      );
      verifyNever(() => rotas.buscarDoMotorista(any(), any()));
    });

    test('motorista com vínculo, mas sem rota hoje, recebe 404', () async {
      when(() => rotas.buscarDoMotorista(any(), any()))
          .thenAnswer((_) async => null);

      await expectLater(
        service.buscarRotaDoDia(motoristaAtivo),
        throwsA(isA<NaoEncontradoException>()),
      );
    });
  });
}
