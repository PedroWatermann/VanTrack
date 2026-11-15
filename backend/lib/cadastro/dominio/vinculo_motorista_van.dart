/// `VinculoMotoristaVan` — cadastro :: domínio.
///
/// Responsabilidade: guardar o histórico de quem dirigiu cada van e dizer se o
/// vínculo está ativo e se autoriza um motorista.
/// RN-012: só o motorista ativo da van opera a rota; no máximo um vínculo ativo
/// por van (garantido também por um índice único no banco). UC-S05, RF-014.
///
/// As associações com `Motorista` e `Van` são guardadas como id (convenção da
/// seção 2.1 do 03-arquitetura.md).
class VinculoMotoristaVan {
  VinculoMotoristaVan({
    required this.id,
    required this.motoristaId,
    required this.vanId,
    required this.inicio,
    this.fim,
  });

  final int id;
  final int motoristaId;
  final int vanId;
  final DateTime inicio;

  /// Nulo enquanto o vínculo está em vigor.
  final DateTime? fim;

  /// RN-012: o vínculo está ativo quando não tem data de fim.
  bool estaAtivo() => fim == null;

  /// RN-012: autoriza só o motorista deste vínculo, e só se ele estiver ativo.
  bool autoriza(int motoristaId) =>
      estaAtivo() && this.motoristaId == motoristaId;
}
