import '../../cadastro/dominio/aluno.dart';
import '../../cadastro/dominio/responsavel.dart';
import '../../compartilhado/dominio/horario_brasilia.dart';

/// Tipos modelados para o UC-I02; a fábrica desta entrega registra embarque.
enum TipoMovimentacao {
  embarque('EMBARQUE'),
  desembarque('DESEMBARQUE');

  const TipoMovimentacao(this.codigo);
  final String codigo;
}

/// Monta o aviso do evento, controla a leitura e identifica o destinatário.
/// RF-011, UC-I02; RN-002/RN-009 e horário original do embarque (RNF-006).
class Notificacao {
  Notificacao({
    this.id,
    required this.tipo,
    required this.responsavelId,
    required this.aluno,
    required this.mensagem,
    required DateTime dataHoraEvento,
    bool lida = false,
  })  : dataHoraEvento = dataHoraEvento.toUtc(),
        _lida = lida;

  factory Notificacao.deEmbarque(
    Responsavel destinatario,
    Aluno aluno,
    DateTime dataHoraEmbarque,
  ) =>
      Notificacao(
        tipo: TipoMovimentacao.embarque,
        responsavelId: destinatario.id,
        aluno: aluno,
        mensagem:
            '${aluno.nome} embarcou na van às ${HorarioBrasilia.formatarHoraMinuto(dataHoraEmbarque)}.',
        dataHoraEvento: dataHoraEmbarque,
      );

  final int? id;
  final TipoMovimentacao tipo;
  final int responsavelId;

  /// Associação Notificacao → Aluno do diagrama; permite consultar o nome real.
  final Aluno aluno;
  int get alunoId => aluno.id;
  final String mensagem;
  final DateTime dataHoraEvento;
  bool _lida;

  bool get lida => _lida;
  void marcarComoLida() => _lida = true;
  bool pertenceA(int responsavelId) => this.responsavelId == responsavelId;
}
