import '../dominio/papel.dart';

/// Identidade para RN-012/RN-002 nas rotas do UC-S05/RF-009 e UC-I02/RF-011.
///
/// Fica no compartilhado porque os controllers de todos os módulos a recebem
/// (cadastro, embarque, notificacao); quem a cria é o `AutenticacaoMiddleware`
/// do módulo autenticacao (Bug VT-71).
class UsuarioLogado {
  const UsuarioLogado({required this.id, required this.papel});

  final int id;
  final Papel papel;
}
