/// Aviso recebido pelo responsável sobre um aluno vinculado (UC-I02, RF-011).
class Aviso {
  const Aviso({
    required this.id,
    required this.alunoId,
    required this.tipo,
    required this.mensagem,
    required this.dataHora,
    required this.lida,
  });

  final int id;
  final int alunoId;
  final String tipo;
  final String mensagem;
  final DateTime dataHora;
  final bool lida;

  bool get deEmbarque => tipo == 'EMBARQUE';
}

/// Componentes de data e hora em Brasília (UTC-3), para filtros e exibição.
DateTime horarioEmBrasilia(DateTime dataHora) =>
    dataHora.toUtc().subtract(const Duration(hours: 3));
