import 'package:postgres/postgres.dart';

import '../../compartilhado/infraestrutura/conexao_banco.dart';
import '../dominio/notificacao.dart';
import '../dominio/notificacao_repository.dart';

/// Implementa o contrato com a tabela da VT-41 e a conexão do membro A.
/// RF-011, UC-I02; consultas filtradas pelo destinatário (RN-002).
class NotificacaoRepositoryPostgres implements NotificacaoRepository {
  const NotificacaoRepositoryPostgres(this.conexao);

  final ConexaoBanco conexao;
  static const _colunas =
      'id, tipo, responsavel_id, aluno_id, mensagem, data_hora_evento, lida';

  @override
  Future<void> registrarComunicado(List<Notificacao> notificacoes) async {
    if (notificacoes.isEmpty) return;
    await conexao.emTransacao((tx) async {
      for (final notificacao in notificacoes) {
        await tx.execute(Sql.named('''
          INSERT INTO notificacao
            (tipo, responsavel_id, aluno_id, mensagem, data_hora_evento, lida)
          VALUES (@tipo, @responsavel, @aluno, @mensagem, @dataHora, @lida)
        '''), parameters: {
          'tipo': notificacao.tipo.codigo,
          'responsavel': notificacao.responsavelId,
          'aluno': notificacao.alunoId,
          'mensagem': notificacao.mensagem,
          'dataHora': notificacao.dataHoraEvento,
          'lida': notificacao.lida,
        });
      }
    });
  }

  @override
  Future<List<Notificacao>> buscarDoResponsavel(int responsavelId,
      [DateTime? desde]) async {
    final linhas = await conexao.executar(
      'SELECT $_colunas FROM notificacao WHERE responsavel_id = @responsavel'
      '${desde == null ? '' : ' AND data_hora_evento > @desde'}'
      ' ORDER BY data_hora_evento DESC, id DESC',
      {'responsavel': responsavelId, if (desde != null) 'desde': desde.toUtc()},
    );
    return [for (final linha in linhas) _deLinha(linha)];
  }

  @override
  Future<Notificacao?> buscarPorId(int id) async {
    final linhas = await conexao.executar(
      'SELECT $_colunas FROM notificacao WHERE id = @id',
      {'id': id},
    );
    return linhas.isEmpty ? null : _deLinha(linhas.first);
  }

  @override
  Future<void> salvar(Notificacao notificacao) async {
    final id = notificacao.id;
    if (id == null)
      throw ArgumentError('A notificação precisa estar persistida.');
    // Só a leitura é mutável; preserva o destinatário e os dados originais do evento.
    await conexao.executar(
      'UPDATE notificacao SET lida = @lida WHERE id = @id',
      {'id': id, 'lida': notificacao.lida},
    );
  }

  Notificacao _deLinha(ResultRow linha) => Notificacao(
        id: linha[0]! as int,
        tipo: TipoMovimentacao.values
            .firstWhere((tipo) => tipo.codigo == linha[1]),
        responsavelId: linha[2]! as int,
        alunoId: linha[3]! as int,
        mensagem: linha[4]! as String,
        dataHoraEvento: linha[5]! as DateTime,
        lida: linha[6]! as bool,
      );
}
