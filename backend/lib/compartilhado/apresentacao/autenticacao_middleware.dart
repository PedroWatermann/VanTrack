import 'package:dart_frog/dart_frog.dart';
import 'package:uuid/validation.dart';

import '../dominio/sessao_repository.dart';
import 'usuario_logado.dart';

/// Valida o token persistido e fornece UsuarioLogado no contexto.
/// RNF-002; apoio a RN-012/RN-002 no UC-S05/RF-009 e UC-I02/RF-011.
class AutenticacaoMiddleware {
  const AutenticacaoMiddleware(this.sessoes);

  final SessaoRepository sessoes;

  Future<UsuarioLogado> identificar(String? token) async {
    if (token == null || !UuidValidation.isValidUUID(fromString: token)) {
      throw const FormatException('Token inválido');
    }
    final sessao = await sessoes.buscarPorToken(token);
    if (sessao == null || !sessao.estaValida(DateTime.now())) {
      throw const FormatException('Token inválido');
    }
    return UsuarioLogado(id: sessao.usuario.id, papel: sessao.usuario.papel);
  }

  Middleware middleware() => (handler) => (context) async {
        final caminho = context.request.uri.path;
        if (caminho == '/usuarios' ||
            caminho == '/login' ||
            (caminho == '/' && context.request.method == HttpMethod.get)) {
          return handler(context);
        }
        final cabecalho = context.request.headers['authorization'] ?? '';
        final token = RegExp(r'^Bearer\s+(\S+)$', caseSensitive: false)
            .firstMatch(cabecalho.trim())
            ?.group(1);
        final UsuarioLogado usuario;
        try {
          usuario = await identificar(token);
        } on FormatException {
          return Response.json(
              statusCode: 401, body: {'erro': 'Não autenticado'});
        }
        return handler(context.provide<UsuarioLogado>(() => usuario));
      };
}
