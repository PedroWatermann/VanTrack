import 'aluno_do_responsavel.dart';
import 'aviso.dart';

/// Consulta e marca os avisos da sessão atual (UC-I02, RN-002).
abstract interface class AvisosRemoto {
  Future<List<AlunoDoResponsavel>> listarAlunos();
  Future<List<Aviso>> listarAvisos();
  Future<void> marcarComoLida(int notificacaoId);
}
