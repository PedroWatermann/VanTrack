import '../../cadastro/dominio/usuario.dart';

/// Token associado ao usuário do login de apoio (RNF-002; UC-S05/RF-009 e UC-I02/RF-011).
class Sessao {
  const Sessao({
    required this.token,
    required this.usuario,
    required this.criadaEm,
  });

  final String token;
  final Usuario usuario;
  final DateTime criadaEm;

  // A migration não define expiração; a sessão deve existir e ter criação válida.
  bool estaValida(DateTime agora) =>
      token.isNotEmpty && !criadaEm.isAfter(agora);
}
