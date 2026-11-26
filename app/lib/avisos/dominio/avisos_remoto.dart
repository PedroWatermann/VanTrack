import 'aluno_do_responsavel.dart';
import 'aviso.dart';

/// Consulta e marca os avisos da sessão atual (UC-I02, RN-002).
abstract interface class AvisosRemoto {
  Future<List<AlunoDoResponsavel>> listarAlunos();
  Future<List<Aviso>> listarAvisos();
  Future<void> marcarComoLida(int notificacaoId);
}

/// O servidor respondeu 401: o token guardado no aparelho não vale mais (por
/// exemplo, depois de um reset do banco). Não é falta de conexão: tentar de
/// novo não adianta; o responsável precisa sair e entrar de novo.
class SessaoExpiradaException implements Exception {
  const SessaoExpiradaException();

  @override
  String toString() => 'SessaoExpiradaException';
}
