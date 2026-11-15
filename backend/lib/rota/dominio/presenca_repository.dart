import 'presenca.dart';

/// `PresencaRepository` — contrato no rota :: domínio (participante
/// "PresencaRepository" do diagrama de sequência UC-S05).
///
/// Responsabilidade: buscar e salvar presenças, gravando o embarque junto, na
/// mesma transação (não existe `EmbarqueRepository`: o embarque faz parte da
/// presença). Implementação: `PresencaRepositoryPostgres`.
/// UC-S05, RF-009, RN-010, RNF-006.
abstract class PresencaRepository {
  /// UC-S05 passo 1: presenças CONFIRMADO ou EMBARCADO da rota, na ordem da
  /// rota, com o aluno e o ponto de parada. RN-010 (exceção): ausentes não entram.
  Future<List<Presenca>> buscarConfirmados(int rotaId);

  /// Presença do aluno na rota (qualquer situação), com o embarque se houver.
  /// `null` se o aluno não tem presença nessa rota (vira 404).
  Future<Presenca?> buscarPresenca(int alunoId, int rotaId);

  /// RNF-006 (idempotência): presença cujo embarque tem este `registroId`, ou
  /// `null` se o registro ainda não foi processado.
  Future<Presenca?> buscarPorRegistroId(String registroId);

  /// Grava a situação da presença e, se ela tiver um embarque ainda não salvo,
  /// insere o embarque, tudo em UMA transação. Lança
  /// `EmbarqueDuplicadoException` se o banco recusar por unicidade.
  Future<void> salvar(Presenca presenca);
}
