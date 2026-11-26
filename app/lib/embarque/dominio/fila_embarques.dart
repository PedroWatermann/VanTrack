import 'registro_embarque.dart';

/// `FilaEmbarques` — embarque :: domínio (contrato).
///
/// Responsabilidade: definir o contrato da fila persistente de registros de
/// embarque pendentes para quando o aparelho está sem conexão.
/// A camada de aplicação (`ModuloEmbarqueComFila`) depende apenas deste
/// contrato, enquanto a infraestrutura o implementa em `ArmazenamentoLocal`.
///
/// RNF-006 (sincronização offline em até 5 min); RF-009.
/// UC-S05 fluxo alternativo A1; UC-R02 E1.
abstract class FilaEmbarques {
  /// Guarda um [registro] pendente na fila local.
  Future<void> guardar(RegistroEmbarque registro);

  /// Lista os registros pendentes da [rotaId], na ordem em que foram guardados.
  Future<List<RegistroEmbarque>> listar(int rotaId);

  /// Remove da fila os registros cujos identificadores estão em [registroIds].
  Future<void> remover(Set<String> registroIds);
}
