/// Papel do usuário na API (diagrama de classes 1/3, cadastro :: domínio).
enum Papel {
  motorista('MOTORISTA'),
  responsavel('RESPONSAVEL');

  const Papel(this.codigo);

  /// Valor usado no JSON e no banco.
  final String codigo;

  /// Converte `"MOTORISTA"`/`"RESPONSAVEL"` no enum; `null` se for inválido.
  static Papel? deCodigo(Object? codigo) {
    for (final papel in values) {
      if (papel.codigo == codigo) return papel;
    }
    return null;
  }
}

/// `Usuario` — cadastro :: domínio (abstrata).
///
/// Responsabilidade: o que motorista e responsável têm em comum: identificação,
/// login, senha e papel. `Motorista` e `Responsavel` herdam desta classe.
///
/// O login NÃO é o caso de uso implementado neste ciclo (regra da disciplina);
/// aqui ele só serve para identificar quem faz a requisição (RN-012, RN-002).
/// Ponto 1 da seção 3 do 03-arquitetura.md.
abstract class Usuario {
  Usuario({
    required this.id,
    required this.nome,
    required this.login,
    String? senhaHash,
  }) : _senhaHash = senhaHash;

  final int id;
  final String nome;
  final String login;

  /// Nulo quando o usuário não tem senha definida (os usuários do seed entram
  /// pelo login simplificado, sem senha).
  final String? _senhaHash;

  Papel get papel;

  /// Confere a senha do usuário.
  ///
  /// Sem senha cadastrada, nunca autentica. A conferência do hash fica para a
  /// task C-02 (Membro C), que decide se o login simplificado usa senha.
  bool autenticar(String senha) {
    if (_senhaHash == null) return false;
    throw UnimplementedError(
      'Conferência de senha: decisão da task C-02 (ponto 1 do 03-arquitetura.md).',
    );
  }
}
