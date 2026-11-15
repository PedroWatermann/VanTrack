/// Rota de hoje do motorista logado, como mostrada no topo da tela
/// "Rota do dia" (formato do GET /rotas/hoje).
class RotaDoDia {
  final int rotaId;

  /// "IDA" ou "VOLTA".
  final String trajeto;
  final DateTime horarioPrevisto;
  final String placa;

  const RotaDoDia({
    required this.rotaId,
    required this.trajeto,
    required this.horarioPrevisto,
    required this.placa,
  });

  factory RotaDoDia.deJson(Map<String, dynamic> json) => RotaDoDia(
        rotaId: json['rotaId'] as int,
        trajeto: json['trajeto'] as String,
        horarioPrevisto: DateTime.parse(json['horarioPrevisto'] as String),
        placa: json['placa'] as String,
      );
}
