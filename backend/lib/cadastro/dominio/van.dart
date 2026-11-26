/// `Van` — cadastro :: domínio.
///
/// Responsabilidade: representar o veículo que realiza as rotas. A placa aparece
/// no cabeçalho da "Rota do dia" (UC-R02). O motorista ativo é dado pelo
/// `VinculoMotoristaVan` (RN-012).
class Van {
  Van({
    required this.id,
    required this.placa,
    required this.modelo,
    required this.capacidade,
  });

  final int id;
  final String placa;
  final String modelo;
  final int capacidade;
}
