import 'presenca.dart';

/// `EmbarqueNaoPermitidoException` — rota :: domínio.
///
/// Lançada por `Presenca.registrarEmbarque` quando a presença não está
/// CONFIRMADO (RN-010), inclusive quando o aluno já embarcou com outro
/// `registroId`. Vira HTTP 409 na apresentação.
class EmbarqueNaoPermitidoException implements Exception {
  const EmbarqueNaoPermitidoException(this.situacaoAtual);

  final SituacaoPresenca situacaoAtual;

  @override
  String toString() =>
      'EmbarqueNaoPermitidoException(situação: ${situacaoAtual.codigo})';
}

/// `EmbarqueDuplicadoException` — rota :: domínio.
///
/// Lançada por `PresencaRepository.salvar` quando o banco recusa o embarque por
/// unicidade (`registro_id` ou `presenca_id`), em corrida entre requisições.
/// O `EmbarqueService` consulta `buscarPorRegistroId` de novo para decidir entre
/// 200 (mesmo registro) e 409 (outro registro já embarcou o aluno). RNF-006.
class EmbarqueDuplicadoException implements Exception {
  const EmbarqueDuplicadoException(this.registroId);

  final String registroId;

  @override
  String toString() => 'EmbarqueDuplicadoException($registroId)';
}
