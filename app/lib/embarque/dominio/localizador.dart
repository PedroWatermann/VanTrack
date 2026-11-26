import 'localizacao.dart';

/// Contrato para obter a localização do celular.
abstract class Localizador {
  /// Devolve a localização atual, ou nulo se ela não ficar pronta dentro do
  /// [limite] (sem permissão, GPS desligado ou demora). Nunca deixa o toque
  /// em "Embarcou" esperando mais que o limite (RNF-005).
  Future<Localizacao?> obterLocalizacao(Duration limite);
}
