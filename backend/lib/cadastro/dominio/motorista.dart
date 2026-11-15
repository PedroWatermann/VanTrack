import 'usuario.dart';

/// `Motorista` — cadastro :: domínio. Herda de [Usuario].
///
/// Responsabilidade: representar o motorista que opera a van e registra os
/// embarques (UC-S05, RF-009). Qual van ele dirige é dito pelo
/// `VinculoMotoristaVan` ativo (RN-012).
class Motorista extends Usuario {
  Motorista({
    required super.id,
    required super.nome,
    required super.login,
    required this.telefone,
    required this.cnh,
    super.senhaHash,
  });

  final String telefone;
  final String cnh;

  @override
  Papel get papel => Papel.motorista;
}
