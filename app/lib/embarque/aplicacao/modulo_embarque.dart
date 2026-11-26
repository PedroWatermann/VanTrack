/// Contrato interno do módulo de embarque, entre a tela e o envio (D ↔ E).
///
/// A tela "Rota do dia" nunca chama a API de embarque diretamente: ela usa
/// este módulo. Há duas implementações: ModuloEmbarqueOnline (só online) e
/// ModuloEmbarqueComFila (com a fila para quando estiver sem conexão).
/// O main.dart escolhe qual usar.
///
/// O código abaixo é EXATAMENTE o da seção 3 do backlog. Não alterar sem
/// combinar com a equipe.
library;

enum StatusEnvio { enviado, pendente }

class ResultadoEmbarque {
  final String registroId; // UUID gerado no aparelho
  final int alunoId;
  final DateTime dataHora; // momento do toque
  final StatusEnvio status;
  const ResultadoEmbarque(this.registroId, this.alunoId, this.dataHora, this.status);
}

class RegistroPendente {
  final String registroId;
  final int alunoId;
  final DateTime dataHora;
  const RegistroPendente(this.registroId, this.alunoId, this.dataHora);
}

/// Avisado quando um pendente sai da fila.
class EventoPendente {
  final String registroId;
  final int alunoId;
  final bool sincronizado; // true: servidor aceitou; false: servidor rejeitou
  final int? codigoHttp;   // preenchido quando rejeitado (ex.: 409)
  const EventoPendente(this.registroId, this.alunoId, this.sincronizado, [this.codigoHttp]);
}

/// Erro da API que a tela precisa mostrar (403, 404 ou 409). Nunca vai para a fila.
class EmbarqueException implements Exception {
  final int codigoHttp;
  final String mensagem;
  const EmbarqueException(this.codigoHttp, this.mensagem);
}

/// `ModuloEmbarque` — embarque :: aplicação (contrato entre a tela e o envio).
///
/// Responsabilidade: registrar o embarque com um toque, com a hora e a
/// localização do momento do toque, e informar os registros que ainda estão
/// pendentes de sincronização.
///
/// RN-010 (embarque só de aluno com presença confirmada, confirmado pelo
/// motorista); RF-009 (registrar embarque); RNF-005 (um toque, GPS até 2 s);
/// RNF-006 (sem conexão, guarda e sincroniza em até 5 min).
/// UC-S05 passos 2 a 4 e fluxo alternativo A1; UC-R02 passos 3 a 5 e E1.
abstract class ModuloEmbarque {
  /// Captura data/hora e localização (opcional, até 2 s), gera o registroId e envia.
  /// Lança EmbarqueException em 403/404/409.
  Future<ResultadoEmbarque> registrarEmbarque(int rotaId, int alunoId);

  Future<List<RegistroPendente>> listarPendentes(int rotaId);

  Stream<EventoPendente> get aoMudarPendentes;
}
