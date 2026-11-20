import '../../compartilhado/dominio/papel.dart';

// O enum Papel mora no compartilhado (Bug VT-71); quem importa este arquivo
// continua enxergando o Papel por este export.
export '../../compartilhado/dominio/papel.dart';

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
