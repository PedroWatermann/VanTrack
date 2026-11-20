@Tags(['integracao'])
library;

import 'package:test/test.dart';
import 'package:vantrack_backend/cadastro/infraestrutura/vinculo_repository_postgres.dart';
import 'package:vantrack_backend/compartilhado/infraestrutura/ambiente.dart';
import 'package:vantrack_backend/compartilhado/infraestrutura/conexao_banco.dart';
import 'package:vantrack_backend/rota/dominio/presenca.dart';
import 'package:vantrack_backend/rota/dominio/rota.dart';
import 'package:vantrack_backend/rota/infraestrutura/presenca_repository_postgres.dart';
import 'package:vantrack_backend/rota/infraestrutura/rota_repository_postgres.dart';

/// Confere os repositórios Postgres contra o banco de verdade, com o seed.
///
/// Só roda se houver DATABASE_URL (backend/.env). Rode ANTES
/// `dart run bin/reset_db.dart`. Os testes só LEEM o banco.
/// Para pular: `dart test -x integracao`.
void main() {
  String? url;
  try {
    url = lerDatabaseUrl();
  } on StateError {
    url = null;
  }
  final pular = url == null ? 'sem DATABASE_URL no backend/.env' : null;

  late ConexaoBanco conexao;

  setUpAll(() async {
    if (url != null) conexao = await ConexaoBanco.abrir(url);
  });

  tearDownAll(() async {
    if (url != null) await conexao.fechar();
  });

  group('PresencaRepositoryPostgres', () {
    test('rota 1: Ana, Beatriz e Carlos na ordem; Bruno (ausente) não aparece',
        () async {
      final presencas = await PresencaRepositoryPostgres(() async => conexao)
          .buscarConfirmados(1);

      expect(presencas.map((p) => p.aluno.nome), [
        'Ana Souza',
        'Beatriz Reis',
        'Carlos Lima',
      ]);
      expect(presencas.map((p) => p.ordem), [1, 2, 3]);
      expect(presencas.first.pontoParada.endereco, 'Rua das Acácias, 100');
    }, skip: pular);

    test('buscarPresenca acha o ausente, e nulo para aluno fora da rota',
        () async {
      final repositorio = PresencaRepositoryPostgres(() async => conexao);

      final bruno = await repositorio.buscarPresenca(4, 1);
      expect(bruno?.situacao, SituacaoPresenca.ausente);
      expect(await repositorio.buscarPresenca(99, 1), isNull);
    }, skip: pular);

    test('registroId ainda não processado devolve nulo', () async {
      final presenca = await PresencaRepositoryPostgres(() async => conexao)
          .buscarPorRegistroId('00000000-0000-4000-8000-000000000000');

      expect(presenca, isNull);
    }, skip: pular);
  });

  group('RotaRepositoryPostgres', () {
    test('rota 1 com a van e o horário 06:30 de Brasília', () async {
      final rota =
          await RotaRepositoryPostgres(() async => conexao).buscarPorId(1);

      expect(rota?.van.placa, 'ABC-1D23');
      expect(rota?.trajeto, Trajeto.ida);
      final emBrasilia =
          rota!.horarioPrevisto.toUtc().subtract(const Duration(hours: 3));
      expect([emBrasilia.hour, emBrasilia.minute], [6, 30]);
    }, skip: pular);

    test('rota de hoje: o motorista 1 tem; o motorista 2 (sem vínculo) não',
        () async {
      final repositorio = RotaRepositoryPostgres(() async => conexao);
      final hoje = DateTime.now().toUtc().subtract(const Duration(hours: 3));

      expect((await repositorio.buscarDoMotorista(1, hoje))?.id, 1);
      expect(await repositorio.buscarDoMotorista(2, hoje), isNull);
    }, skip: pular);
  });

  group('VinculoRepositoryPostgres', () {
    test('vínculo ativo da van 1 autoriza o motorista 1 e não o 2 (RN-012)',
        () async {
      final vinculo = await VinculoRepositoryPostgres(() async => conexao)
          .buscarVinculoAtivo(1);

      expect(vinculo?.autoriza(1), isTrue);
      expect(vinculo?.autoriza(2), isFalse);
    }, skip: pular);

    test('vínculo ativo do motorista: o 1 tem (van 1); o 2 não (teste 7)',
        () async {
      final repositorio = VinculoRepositoryPostgres(() async => conexao);

      final doJoao = await repositorio.buscarVinculoAtivoDoMotorista(1);
      final doMarcos = await repositorio.buscarVinculoAtivoDoMotorista(2);

      expect(doJoao?.vanId, 1);
      expect(doJoao?.estaAtivo(), isTrue);
      expect(doMarcos, isNull);
    }, skip: pular);

    test('Ana tem 2 responsáveis e Carlos nenhum (RN-009, A1 do UC-I02)',
        () async {
      final repositorio = VinculoRepositoryPostgres(() async => conexao);

      expect(await repositorio.buscarResponsaveis(1), hasLength(2));
      expect(await repositorio.buscarResponsaveis(3), isEmpty);
    }, skip: pular);

    test('Maria recebe só a Ana e Fernanda só a Beatriz (RN-002, VT-70)',
        () async {
      final repositorio = VinculoRepositoryPostgres(() async => conexao);

      final daMaria = await repositorio.buscarAlunosDoResponsavel(1);
      final daFernanda = await repositorio.buscarAlunosDoResponsavel(3);

      expect(daMaria.map((a) => a.nome), ['Ana Souza']);
      expect(daFernanda.map((a) => a.nome), ['Beatriz Reis']);
      expect(await repositorio.buscarAlunosDoResponsavel(99), isEmpty);
    }, skip: pular);
  });
}
