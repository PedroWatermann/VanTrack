import '../../cadastro/dominio/van.dart';

/// Trajeto da rota.
enum Trajeto {
  ida('IDA'),
  volta('VOLTA');

  const Trajeto(this.codigo);

  /// Valor usado no JSON e no banco.
  final String codigo;

  static Trajeto deCodigo(String codigo) =>
      values.firstWhere((t) => t.codigo == codigo);
}

/// `Rota` — rota :: domínio.
///
/// Responsabilidade: representar o percurso do dia de uma van, montado com os
/// alunos confirmados (UC-S05 pré-condição; RN-005). A rota conhece a sua van:
/// o RN-012 precisa dela (motorista ativo) e o cabeçalho da "Rota do dia" mostra
/// a placa (UC-R02).
class Rota {
  Rota({
    required this.id,
    required this.van,
    required this.data,
    required this.trajeto,
    required this.horarioPrevisto,
    required this.situacao,
  });

  final int id;

  /// Associação navegável Rota → Van (0..* — 1).
  final Van van;

  /// Dia da rota (só a data).
  final DateTime data;

  final Trajeto trajeto;

  /// Data e hora previstas de saída (instante; mostrar em horário de Brasília).
  final DateTime horarioPrevisto;

  /// `PLANEJADA`, `ATIVA`, `CONCLUIDA` ou `CANCELADA`.
  final String situacao;
}
