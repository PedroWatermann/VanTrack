import 'sessao_salva.dart';

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
/// Com uma [SessaoSalva], a sessão também fica guardada no aparelho: ao abrir
/// o app de novo, mesmo sem conexão, o usuário continua logado (Bug VT-75).
///
/// Classe de apoio: não faz parte do caso de uso avaliado (UC-S05).
class Sessao {
  Sessao([this._salva]);

  /// Onde a sessão fica guardada no aparelho (nula = só na memória).
  final SessaoSalva? _salva;

  UsuarioLogado? _usuario;
  String? _token;

  /// Usuário logado (nulo se ninguém entrou ainda).
  UsuarioLogado? get usuario => _usuario;

  /// Token de acesso, enviado em todas as requisições ao servidor.
  String? get token => _token;

  /// Indica se há um usuário logado.
  bool get logado => _token != null;

  /// Registra o usuário e o token após o login e os guarda no aparelho.
  ///
  /// A sessão em memória muda na hora; só a gravação no aparelho é esperada.
  Future<void> entrar(UsuarioLogado usuario, String token) async {
    _usuario = usuario;
    _token = token;
    await _salva?.salvar(usuario, token);
  }

  /// Recupera a sessão guardada no aparelho, se houver.
  /// Devolve `true` se havia alguém logado.
  Future<bool> restaurar() async {
    final salva = await _salva?.ler();
    if (salva == null) return false;
    final (usuario, token) = salva;
    _usuario = usuario;
    _token = token;
    return true;
  }

  /// Encerra a sessão (logout), também no aparelho.
  Future<void> sair() async {
    _usuario = null;
    _token = null;
    await _salva?.apagar();
  }
}
