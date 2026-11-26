/// `Localizacao` — value object do rota :: domínio.
///
/// Responsabilidade: par latitude/longitude, sem identidade: duas localizações
/// com os mesmos valores são iguais. Faz parte (composição) do `PontoParada` e
/// do `Embarque` (localização do toque, "quando disponível" — RF-009).
class Localizacao {
  const Localizacao({required this.latitude, required this.longitude});

  final double latitude;
  final double longitude;

  @override
  bool operator ==(Object other) =>
      other is Localizacao &&
      other.latitude == latitude &&
      other.longitude == longitude;

  @override
  int get hashCode => Object.hash(latitude, longitude);

  @override
  String toString() => 'Localizacao($latitude, $longitude)';
}
