import 'package:geolocator/geolocator.dart';

import '../dominio/localizacao.dart';
import '../dominio/localizador.dart';

/// Implementação do [Localizador] com o pacote geolocator (Android e Web).
///
/// Se a localização estiver desligada, sem permissão ou demorar mais que o
/// limite, devolve nulo e o embarque é enviado sem localização (RNF-005).
class LocalizadorGeolocator implements Localizador {
  @override
  Future<Localizacao?> obterLocalizacao(Duration limite) async {
    try {
      return await _obter().timeout(limite, onTimeout: () => null);
    } catch (_) {
      return null;
    }
  }

  Future<Localizacao?> _obter() async {
    if (!await Geolocator.isLocationServiceEnabled()) return null;

    var permissao = await Geolocator.checkPermission();
    if (permissao == LocationPermission.denied) {
      permissao = await Geolocator.requestPermission();
    }
    if (permissao == LocationPermission.denied ||
        permissao == LocationPermission.deniedForever) {
      return null;
    }

    final posicao = await Geolocator.getCurrentPosition();
    return Localizacao(posicao.latitude, posicao.longitude);
  }
}
