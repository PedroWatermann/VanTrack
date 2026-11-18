import 'package:dart_frog/dart_frog.dart';
import 'package:vantrack_backend/compartilhado/aplicacao/autenticacao_service.dart';
import 'package:vantrack_backend/compartilhado/apresentacao/autenticacao_controller.dart';
import 'package:vantrack_backend/compartilhado/apresentacao/autenticacao_middleware.dart';
import 'package:vantrack_backend/compartilhado/apresentacao/cors.dart';
import 'package:vantrack_backend/compartilhado/infraestrutura/ambiente.dart';
import 'package:vantrack_backend/compartilhado/infraestrutura/conexao_banco.dart';
import 'package:vantrack_backend/compartilhado/infraestrutura/sessao_repository_postgres.dart';
import 'package:vantrack_backend/cadastro/aplicacao/aluno_service.dart';
import 'package:vantrack_backend/cadastro/apresentacao/aluno_controller.dart';
import 'package:vantrack_backend/cadastro/infraestrutura/vinculo_repository_postgres.dart';
import 'package:vantrack_backend/embarque/aplicacao/embarque_service.dart';
import 'package:vantrack_backend/embarque/apresentacao/embarque_controller.dart';
import 'package:vantrack_backend/notificacao/aplicacao/notificacao_service_vazio.dart';
import 'package:vantrack_backend/notificacao/aplicacao/avisos_service.dart';
import 'package:vantrack_backend/notificacao/apresentacao/notificacao_controller.dart';
import 'package:vantrack_backend/notificacao/infraestrutura/notificacao_repository_postgres.dart';
import 'package:vantrack_backend/rota/infraestrutura/presenca_repository_postgres.dart';
import 'package:vantrack_backend/rota/infraestrutura/rota_repository_postgres.dart';

/// Middleware raiz, aplicado a TODAS as rotas.
///
/// O CORS fica por fora para responder o preflight OPTIONS antes de qualquer
/// outra verificação e para pôr os cabeçalhos até nas respostas de erro.
Handler middleware(Handler handler) {
  final repositorio = SessaoRepositoryPostgres(
    () => ConexaoBanco.abrir(lerDatabaseUrl()),
  );
  final controller = AutenticacaoController(
    AutenticacaoService(repositorio, repositorio),
  );

  // UC-S05 (B-08): composição do EmbarqueService com as implementações
  // Postgres. O pool de conexões é único (ConexaoBanco.abrir).
  // B-11 troca o NotificacaoServiceVazio pelo NotificacaoServicePadrao (C-04).
  Future<ConexaoBanco> conexao() => ConexaoBanco.abrir(lerDatabaseUrl());
  final embarqueController = EmbarqueController(
    EmbarqueService(
      rotaRepository: RotaRepositoryPostgres(conexao),
      presencaRepository: PresencaRepositoryPostgres(conexao),
      vinculoRepository: VinculoRepositoryPostgres(conexao),
      notificacaoService: const NotificacaoServiceVazio(),
    ),
  );

  final notificacaoController = NotificacaoController(
    AvisosService(NotificacaoRepositoryPostgres(conexao)),
  );

  // VT-70: alunos do responsável logado, para a tela "Avisos".
  final alunoController = AlunoController(
    AlunoService(VinculoRepositoryPostgres(conexao)),
  );

  final autenticado = handler
      .use(provider<AutenticacaoController>((_) => controller))
      .use(provider<EmbarqueController>((_) => embarqueController))
      .use(provider<NotificacaoController>((_) => notificacaoController))
      .use(provider<AlunoController>((_) => alunoController))
      .use(AutenticacaoMiddleware(repositorio).middleware());
  Future<Response> atender(RequestContext context) async {
    try {
      return await autenticado(context);
    } catch (_) {
      return Response.json(
        statusCode: 503,
        body: {
          'erro': 'Não foi possível atender à solicitação. Tente de novo.'
        },
      );
    }
  }

  return atender.use(cors()).use(requestLogger());
}
