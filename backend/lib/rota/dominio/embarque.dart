import 'localizacao.dart';

/// `Embarque` — rota :: domínio.
///
/// Responsabilidade: registro do embarque de um aluno com a hora do toque e a
/// localização opcional (UC-S05, RF-009). O `registroId` (UUID gerado no
/// aparelho) garante a idempotência do envio e da sincronização (RNF-006).
///
/// Faz parte da `Presenca` (composição 1 — 0..1): nasce em
/// `Presenca.registrarEmbarque` e é salvo junto com ela.
class Embarque {
  Embarque({
    required this.registroId,
    required this.dataHora,
    this.id,
    this.localizacao,
  });

  /// Nulo enquanto o embarque ainda não foi gravado no banco.
  final int? id;

  final String registroId;

  /// Momento do toque no aparelho, não o do envio.
  final DateTime dataHora;

  /// "Quando disponível": nulo se o GPS não respondeu a tempo.
  final Localizacao? localizacao;
}
