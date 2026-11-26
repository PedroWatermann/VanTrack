import 'package:dart_frog/dart_frog.dart';

import '../../cadastro/dominio/usuario.dart';
import '../aplicacao/autenticacao_service.dart';

/// Converte HTTP/JSON em chamadas do login, sem acessar repositórios.
/// RNF-002; apoio ao UC-S05/RF-009 e UC-I02/RF-011.
class AutenticacaoController {
  const AutenticacaoController(this.service);

  final AutenticacaoService service;

  Future<Response> listarUsuarios(HttpMethod metodo) async {
    if (metodo != HttpMethod.get) {
      return Response(statusCode: 405, headers: {'Allow': 'GET'});
    }
    final usuarios = await service.listarUsuarios();
    return Response.json(body: [
      for (final usuario in usuarios)
        {'id': usuario.id, 'nome': usuario.nome, 'papel': usuario.papel.codigo},
    ]);
  }

  Future<Response> entrar(Request pedido) async {
    if (pedido.method != HttpMethod.post) {
      return Response(statusCode: 405, headers: {'Allow': 'POST'});
    }
    final Object? corpo;
    try {
      corpo = await pedido.json();
    } on FormatException {
      return _invalido();
    }
    if (corpo is! Map<String, dynamic>) return _invalido();
    final id = corpo['id'];
    final papel = Papel.deCodigo(corpo['papel']);
    if (id is! int || id <= 0 || papel == null) return _invalido();

    final sessao = await service.entrar(id, papel);
    return sessao == null
        ? Response.json(
            statusCode: 401, body: {'erro': 'Usuário não encontrado'})
        : Response.json(body: {'token': sessao.token});
  }

  Response _invalido() => Response.json(
        statusCode: 400,
        body: {
          'erro':
              'Informe id inteiro positivo e papel MOTORISTA ou RESPONSAVEL.'
        },
      );
}
