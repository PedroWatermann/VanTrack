/// Aluno da rota como a tela "Rota do dia" mostra
/// (formato do GET /rotas/{rotaId}/alunos).
///
/// Só aparecem alunos com presença confirmada; ausentes não vêm na lista (RN-010).
class AlunoDaRota {
  final int alunoId;
  final String nome;

  /// Posição do aluno na ordem das paradas.
  final int ordem;
  final String endereco;
  final bool embarcado;

  const AlunoDaRota({
    required this.alunoId,
    required this.nome,
    required this.ordem,
    required this.endereco,
    required this.embarcado,
  });

  factory AlunoDaRota.deJson(Map<String, dynamic> json) => AlunoDaRota(
        alunoId: json['alunoId'] as int,
        nome: json['nome'] as String,
        ordem: json['ordem'] as int,
        endereco: (json['pontoParada'] as Map<String, dynamic>)['endereco'] as String,
        embarcado: json['status'] == 'EMBARCADO',
      );
}
