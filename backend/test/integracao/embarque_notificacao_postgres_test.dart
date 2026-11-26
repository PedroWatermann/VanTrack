@Tags(['integracao'])
library;

import 'package:test/test.dart';
import 'package:uuid/uuid.dart';
import 'package:vantrack_backend/cadastro/infraestrutura/vinculo_repository_postgres.dart';
import 'package:vantrack_backend/compartilhado/infraestrutura/ambiente.dart';
import 'package:vantrack_backend/compartilhado/infraestrutura/conexao_banco.dart';
import 'package:vantrack_backend/embarque/aplicacao/embarque_service.dart';
import 'package:vantrack_backend/notificacao/aplicacao/notificacao_service_padrao.dart';
import 'package:vantrack_backend/notificacao/infraestrutura/notificacao_repository_postgres.dart';
import 'package:vantrack_backend/rota/dominio/presenca.dart';
import 'package:vantrack_backend/rota/infraestrutura/presenca_repository_postgres.dart';
import 'package:vantrack_backend/rota/infraestrutura/rota_repository_postgres.dart';

/// Critério de aceite da B-11 (VT-40): o embarque, com a notificação real
/// ligada, cria as notificações dos responsáveis no banco (UC-S05 passo 5 ->
/// UC-I02; RF-011; RN-002; RN-009).
///
/// Monta o `EmbarqueService` com as mesmas peças do `routes/_middleware.dart`.
///
/// ATENÇÃO: este teste GRAVA no banco (embarca a Ana e o Carlos). Rode
/// `dart run bin/reset_db.dart` ANTES e DEPOIS. Só roda se houver
/// DATABASE_URL (backend/.env). Para pular: `dart test -x integracao`.
void main() {
  String? url;
  try {
    url = lerDatabaseUrl();
  } on StateError {
    url = null;
  }
  final pular = url == null ? 'sem DATABASE_URL no backend/.env' : null;

  // Ids do supabase/seed.sql.
  const rotaId = 1;
  const motoristaAtivo = 1;
  const ana = 1; // 2 responsáveis
  const carlos = 3; // maior de idade, sem responsável (A1 do UC-I02)

  late ConexaoBanco conexao;
  late EmbarqueService service;

  Future<int> notificacoesDoAluno(int alunoId) async {
    final resultado = await conexao.executar(
      'select count(*) from notificacao where aluno_id = @aluno_id:int8',
      {'aluno_id': alunoId},
    );
    return resultado.first.first! as int;
  }

  setUpAll(() async {
    if (url == null) return;
    conexao = await ConexaoBanco.abrir(url);
    Future<ConexaoBanco> obter() async => conexao;
    service = EmbarqueService(
      rotaRepository: RotaRepositoryPostgres(obter),
      presencaRepository: PresencaRepositoryPostgres(obter),
      vinculoRepository: VinculoRepositoryPostgres(obter),
      notificacaoService: NotificacaoServicePadrao(
        vinculoRepository: VinculoRepositoryPostgres(obter),
        notificacaoRepository: NotificacaoRepositoryPostgres(obter),
      ),
    );
  });

  tearDownAll(() async {
    if (url != null) await conexao.fechar();
  });

  test('embarcar a Ana cria 2 notificações (uma por responsável)', () async {
    final antes = await notificacoesDoAluno(ana);

    final resultado = await service.registrarEmbarque(
      rotaId: rotaId,
      alunoId: ana,
      registroId: const Uuid().v4(),
      dataHora: DateTime.now().toUtc(),
      motoristaId: motoristaAtivo,
    );

    expect(resultado.situacao, SituacaoPresenca.embarcado);
    expect(resultado.jaProcessado, isFalse);
    expect(await notificacoesDoAluno(ana), antes + 2);
  }, skip: pular);

  test('embarcar o Carlos (sem responsável) não cria notificação', () async {
    final antes = await notificacoesDoAluno(carlos);

    final resultado = await service.registrarEmbarque(
      rotaId: rotaId,
      alunoId: carlos,
      registroId: const Uuid().v4(),
      dataHora: DateTime.now().toUtc(),
      motoristaId: motoristaAtivo,
    );

    expect(resultado.situacao, SituacaoPresenca.embarcado);
    expect(await notificacoesDoAluno(carlos), antes);
  }, skip: pular);
}
