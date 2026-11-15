import '../../cadastro/dominio/usuario.dart';

/// Identidade para RN-012/RN-002 nas rotas do UC-S05/RF-009 e UC-I02/RF-011.
class UsuarioLogado {
  const UsuarioLogado({required this.id, required this.papel});

  final int id;
  final Papel papel;
}
