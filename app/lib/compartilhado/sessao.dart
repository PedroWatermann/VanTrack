/// Papel do usuário no app.
///
/// O texto entre parênteses é como o papel aparece nas respostas do servidor
/// ("MOTORISTA" ou "RESPONSAVEL").
enum Papel {
  motorista('MOTORISTA'),
  responsavel('RESPONSAVEL');

  const Papel(this.texto);

  /// Texto do papel usado na comunicação com o servidor.
  final String texto;

  /// Converte o texto recebido do servidor (ex.: "MOTORISTA") para o Papel do app.
  static Papel deTexto(String texto) =>
      Papel.values.firstWhere((p) => p.texto == texto);
}

/// Usuário que entrou no app pela tela de login.
class UsuarioLogado {
  final int id;
  final String nome;
  final Papel papel;

  const UsuarioLogado({required this.id, required this.nome, required this.papel});
}

/// Sessão do usuário logado: guarda quem está usando o app e o token de acesso.
///
/// Depois do login, o servidor devolve um token, que é enviado em todas as
/// requisições seguintes para identificar o usuário. Com isso, o servidor
/// garante que só o motorista ativo da van veja a rota (RN-012) e que cada
/// responsável veja apenas os avisos dos seus alunos (RN-002).
///
/// Classe de apoio: não faz parte do caso de uso avaliado (UC-S05).
class Sessao {
  UsuarioLogado? _usuario;
  String? _token;

  /// Usuário logado (nulo se ninguém entrou ainda).
  UsuarioLogado? get usuario => _usuario;

  /// Token de acesso, enviado em todas as requisições ao servidor.
  String? get token => _token;

  /// Indica se há um usuário logado.
  bool get logado => _token != null;

  /// Registra o usuário e o token após o login.
  void entrar(UsuarioLogado usuario, String token) {
    _usuario = usuario;
    _token = token;
  }

  /// Encerra a sessão (logout).
  void sair() {
    _usuario = null;
    _token = null;
  }
}
