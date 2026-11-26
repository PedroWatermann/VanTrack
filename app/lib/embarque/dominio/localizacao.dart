/// Localização (latitude e longitude) do celular no momento do embarque.
///
/// Objeto de valor do domínio, guardado dentro do [RegistroEmbarque].
class Localizacao {
  final double latitude;
  final double longitude;

  const Localizacao(this.latitude, this.longitude);
}
