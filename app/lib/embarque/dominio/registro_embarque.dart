import 'localizacao.dart';

/// Um embarque registrado pelo motorista com um toque em "Embarcou".
///
/// Guarda tudo o que é enviado ao servidor no POST /rotas/{rotaId}/embarques
/// (seção 3 do backlog), mais o [rotaId]. É também o item guardado na fila
/// quando o app está sem conexão (fluxo A1 do UC-S05, RNF-006).
class RegistroEmbarque {
  /// Código único do embarque, gerado no celular. Evita que o mesmo embarque
  /// seja registrado duas vezes no servidor.
  final String registroId;
  final int rotaId;
  final int alunoId;

  /// Momento do toque, e não o do envio. Assim um embarque feito sem conexão
  /// guarda o horário real.
  final DateTime dataHora;

  /// Localização no momento do toque, quando disponível.
  final Localizacao? localizacao;

  /// Motorista que tocou em "Embarcou". Fica só no aparelho (não vai no corpo
  /// da requisição: o servidor identifica o motorista pelo token). Serve para
  /// a fila offline só ser sincronizada com a sessão desse motorista
  /// (Bug VT-76). Nulo em registros guardados antes dessa correção.
  final int? motoristaId;

  const RegistroEmbarque({
    required this.registroId,
    required this.rotaId,
    required this.alunoId,
    required this.dataHora,
    this.localizacao,
    this.motoristaId,
  });

  /// Corpo da requisição POST /rotas/{rotaId}/embarques.
  Map<String, dynamic> paraJson() {
    final local = localizacao;
    return {
      'registroId': registroId,
      'alunoId': alunoId,
      'dataHora': dataHora.toUtc().toIso8601String(),
      if (local != null) 'latitude': local.latitude,
      if (local != null) 'longitude': local.longitude,
    };
  }

  /// Monta o registro a partir do JSON (usado, por exemplo, ao ler a fila).
  factory RegistroEmbarque.deJson(int rotaId, Map<String, dynamic> json) {
    final latitude = json['latitude'] as num?;
    final longitude = json['longitude'] as num?;
    return RegistroEmbarque(
      registroId: json['registroId'] as String,
      rotaId: rotaId,
      alunoId: json['alunoId'] as int,
      dataHora: DateTime.parse(json['dataHora'] as String),
      localizacao: latitude != null && longitude != null
          ? Localizacao(latitude.toDouble(), longitude.toDouble())
          : null,
      motoristaId: json['motoristaId'] as int?,
    );
  }
}
