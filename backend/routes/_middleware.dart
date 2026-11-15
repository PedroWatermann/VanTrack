import 'package:dart_frog/dart_frog.dart';
import 'package:vantrack_backend/compartilhado/aplicacao/autenticacao_service.dart';
import 'package:vantrack_backend/compartilhado/apresentacao/autenticacao_controller.dart';
import 'package:vantrack_backend/compartilhado/apresentacao/autenticacao_middleware.dart';
import 'package:vantrack_backend/compartilhado/apresentacao/cors.dart';
import 'package:vantrack_backend/compartilhado/infraestrutura/ambiente.dart';
import 'package:vantrack_backend/compartilhado/infraestrutura/conexao_banco.dart';
import 'package:vantrack_backend/compartilhado/infraestrutura/sessao_repository_postgres.dart';

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
  final autenticado = handler
      .use(provider<AutenticacaoController>((_) => controller))
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
