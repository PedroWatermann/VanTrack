import 'package:postgres/postgres.dart';

import '../../cadastro/dominio/aluno.dart';
import '../../compartilhado/infraestrutura/conexao_banco.dart';
import '../dominio/notificacao.dart';
import '../dominio/notificacao_repository.dart';

/// Implementa o contrato com a tabela da VT-41 e a conexão do membro A.
/// RF-011, UC-I02; consultas filtradas pelo destinatário (RN-002).
class NotificacaoRepositoryPostgres implements NotificacaoRepository {
  const NotificacaoRepositoryPostgres(this._obterConexao);

  final Future<ConexaoBanco> Function() _obterConexao;
  static const _consulta = '''
    SELECT n.id, n.tipo, n.responsavel_id, n.aluno_id, n.mensagem,
           n.data_hora_evento, n.lida, a.nome, a.data_nascimento
      FROM notificacao n
      JOIN aluno a ON a.id = n.aluno_id
  ''';

  @override
  Future<void> registrarComunicado(List<Notificacao> notificacoes) async {
    if (notificacoes.isEmpty) return;
    await (await _obterConexao()).emTransacao((tx) async {
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
    final linhas = await (await _obterConexao()).executar(
      '$_consulta WHERE n.responsavel_id = @responsavel'
      '${desde == null ? '' : ' AND n.data_hora_evento > @desde'}'
      ' ORDER BY n.data_hora_evento DESC, n.id DESC',
      {'responsavel': responsavelId, if (desde != null) 'desde': desde.toUtc()},
    );
    return [for (final linha in linhas) _deLinha(linha)];
  }

  @override
  Future<Notificacao?> buscarPorId(int id) async {
    final linhas = await (await _obterConexao()).executar(
      '$_consulta WHERE n.id = @id',
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
    await (await _obterConexao()).executar(
      'UPDATE notificacao SET lida = @lida WHERE id = @id',
      {'id': id, 'lida': notificacao.lida},
    );
  }

  Notificacao _deLinha(ResultRow linha) => Notificacao(
        id: linha[0]! as int,
        tipo: TipoMovimentacao.values
            .firstWhere((tipo) => tipo.codigo == linha[1]),
        responsavelId: linha[2]! as int,
        aluno: Aluno(
          id: linha[3]! as int,
          nome: linha[7]! as String,
          dataNascimento: linha[8]! as DateTime,
        ),
        mensagem: linha[4]! as String,
        dataHoraEvento: linha[5]! as DateTime,
        lida: linha[6]! as bool,
      );
}
