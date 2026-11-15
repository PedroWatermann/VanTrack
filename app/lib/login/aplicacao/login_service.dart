import '../../compartilhado/api_client.dart';
import '../../compartilhado/sessao.dart';

/// Erro ao listar os usuários ou ao entrar no app.
class LoginException implements Exception {
  final String mensagem;

  const LoginException(this.mensagem);

  @override
  String toString() => mensagem;
}

/// Login simplificado: lista os usuários e entra no app com um toque.
///
/// Usa GET /usuarios e POST /login (contrato da API, seção 3 do backlog) e
/// guarda o usuário e o token de acesso na [Sessao].
///
/// Classe de apoio: o login não é o caso de uso avaliado (UC-S05), mas é ele
/// que identifica o motorista (RN-012) e o responsável (RN-002).
class LoginService {
  LoginService({required this.api, required this.sessao});

  final ApiClient api;
  final Sessao sessao;

  /// Lista os usuários disponíveis para entrar, com nome e papel.
  Future<List<UsuarioLogado>> listarUsuarios() async {
    final resposta = await api.get('/usuarios');
    if (!resposta.sucesso) {
      throw const LoginException('Não foi possível carregar os usuários.');
    }
    return [
      for (final usuario in resposta.corpo as List)
        UsuarioLogado(
          id: usuario['id'] as int,
          nome: usuario['nome'] as String,
          papel: Papel.deTexto(usuario['papel'] as String),
        ),
    ];
  }

  /// Entra no app como o usuário escolhido e guarda o token na sessão.
  Future<void> entrar(UsuarioLogado usuario) async {
    final resposta = await api.post('/login', {
      'id': usuario.id,
      'papel': usuario.papel.texto,
    });
    if (!resposta.sucesso) {
      throw const LoginException('Não foi possível entrar.');
    }
    sessao.entrar(usuario, resposta.corpo['token'] as String);
  }
}
