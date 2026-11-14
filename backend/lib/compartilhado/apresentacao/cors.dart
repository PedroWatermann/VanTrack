import 'package:dart_frog/dart_frog.dart';

/// Cabeçalhos CORS liberando qualquer origem (uso em desenvolvimento).
const cabecalhosCors = <String, String>{
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'GET, POST, PUT, PATCH, DELETE, OPTIONS',
  'Access-Control-Allow-Headers': 'Origin, Content-Type, Accept, Authorization',
  'Access-Control-Max-Age': '86400',
};

/// Middleware de CORS (camada de apresentação, módulo compartilhado).
///
/// Responsabilidade: permitir que o app Flutter Web, servido em outra origem,
/// chame a API. Responde o preflight `OPTIONS` direto (204, sem passar pelas
/// rotas) e acrescenta os cabeçalhos CORS em todas as outras respostas,
/// inclusive as de erro.
///
/// Requisito: RNF-004 (o app precisa funcionar também no navegador).
Middleware cors() {
  return (handler) {
    return (context) async {
      if (context.request.method == HttpMethod.options) {
        return Response(statusCode: 204, headers: cabecalhosCors);
      }
      final resposta = await handler(context);
      return resposta.copyWith(
        headers: {...resposta.headers, ...cabecalhosCors},
      );
    };
  };
}
