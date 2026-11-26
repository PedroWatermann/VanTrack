import 'localizacao.dart';

/// `PontoParada` — rota :: domínio.
///
/// Responsabilidade: local onde o aluno embarca na rota (UC-S05, UC-R02).
class PontoParada {
  PontoParada({
    required this.id,
    required this.endereco,
    required this.localizacao,
  });

  final int id;
  final String endereco;

  /// Composição: a localização só existe como parte do ponto.
  final Localizacao localizacao;
}
