import 'aluno_da_rota.dart';
import 'registro_embarque.dart';
import 'rota_do_dia.dart';

/// Contrato de comunicação do módulo de embarque com o servidor.
///
/// A camada de aplicação depende só deste contrato; a implementação real fica
/// na infraestrutura (`EmbarqueApi`). Assim os testes podem usar uma versão
/// falsa, sem servidor.
///
/// Todas as operações lançam [EnvioRecusadoException] quando o servidor recusa
/// e [SemConexaoException] quando não há conexão.
abstract class EmbarqueRemoto {
  /// Rota de hoje do motorista logado (GET /rotas/hoje).
  Future<RotaDoDia> buscarRotaDoDia();

  /// Alunos confirmados na rota, na ordem das paradas (GET /rotas/{rotaId}/alunos).
  Future<List<AlunoDaRota>> listarAlunos(int rotaId);

  /// Envia um embarque (POST /rotas/{rotaId}/embarques).
  Future<void> enviar(RegistroEmbarque registro);

  /// Envia vários embarques de uma vez (POST /rotas/{rotaId}/embarques/sincronizar).
  /// Devolve o código de resposta de cada registro, pelo registroId.
  Future<Map<String, int>> sincronizar(int rotaId, List<RegistroEmbarque> registros);
}
