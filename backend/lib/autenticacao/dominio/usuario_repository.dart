import '../../cadastro/dominio/usuario.dart';

/// Consulta usuários para o login de apoio (RNF-002; UC-S05/RF-009, UC-I02/RF-011).
abstract class UsuarioRepository {
  Future<List<Usuario>> listar();
  Future<Usuario?> buscarPorIdEPapel(int id, Papel papel);
}
