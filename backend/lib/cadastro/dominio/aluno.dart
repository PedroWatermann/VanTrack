/// `Aluno` — cadastro :: domínio.
///
/// Responsabilidade: representar o aluno transportado e saber se é menor de
/// idade (RN-009: aluno menor precisa de ao menos um responsável vinculado).
/// UC-S05 (é quem embarca) e UC-I02 (assunto do aviso).
class Aluno {
  Aluno({required this.id, required this.nome, required this.dataNascimento});

  final int id;
  final String nome;
  final DateTime dataNascimento;

  /// Idade mínima para ser maior de idade.
  static const maioridade = 18;

  /// RN-009: o aluno é menor de idade na data [referencia]?
  /// Considera só o dia (ano, mês e dia), sem hora.
  bool ehMenorDeIdade(DateTime referencia) {
    final aniversarioDe18 = DateTime(
      dataNascimento.year + maioridade,
      dataNascimento.month,
      dataNascimento.day,
    );
    final dia = DateTime(referencia.year, referencia.month, referencia.day);
    return dia.isBefore(aniversarioDe18);
  }
}
