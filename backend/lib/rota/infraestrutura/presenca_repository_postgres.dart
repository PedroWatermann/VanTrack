import 'package:postgres/postgres.dart';

import '../../cadastro/dominio/aluno.dart';
import '../../compartilhado/infraestrutura/conexao_banco.dart';
import '../dominio/embarque.dart';
import '../dominio/excecoes.dart';
import '../dominio/localizacao.dart';
import '../dominio/ponto_parada.dart';
import '../dominio/presenca.dart';
import '../dominio/presenca_repository.dart';

/// `PresencaRepositoryPostgres` — rota :: infraestrutura.
///
/// Responsabilidade: implementar o contrato [PresencaRepository] com SQL no
/// Postgres (tabelas `presenca`, `aluno`, `ponto_parada` e `embarque`).
/// UC-S05, RF-009, RN-010, RNF-006.
class PresencaRepositoryPostgres implements PresencaRepository {
  const PresencaRepositoryPostgres(this._obterConexao);

  /// Abre (ou reaproveita) o pool único da [ConexaoBanco]. Mesmo padrão do
  /// `SessaoRepositoryPostgres`, para o `routes/_middleware.dart` montar os
  /// repositórios sem `await`.
  final Future<ConexaoBanco> Function() _obterConexao;

  static const _select = '''
    select p.id, p.rota_id, p.ordem, p.situacao,
           a.id as aluno_id, a.nome as aluno_nome, a.data_nascimento,
           pp.id as ponto_id, pp.endereco,
           pp.latitude as ponto_latitude, pp.longitude as ponto_longitude,
           e.id as embarque_id, e.registro_id::text as registro_id, e.data_hora,
           e.latitude as embarque_latitude, e.longitude as embarque_longitude
      from presenca p
      join aluno a         on a.id = p.aluno_id
      join ponto_parada pp on pp.id = p.ponto_parada_id
      left join embarque e on e.presenca_id = p.id
  ''';

  @override
  Future<List<Presenca>> buscarConfirmados(int rotaId) async {
    final resultado = await (await _obterConexao()).executar(
      '''
      $_select
       where p.rota_id = @rota_id
         -- RN-010 (exceção): aluno AUSENTE não aparece na rota do dia
         and p.situacao in ('CONFIRMADO', 'EMBARCADO')
       order by p.ordem
      ''',
      {'rota_id': rotaId},
    );
    return resultado.map((l) => _paraPresenca(l.toColumnMap())).toList();
  }

  @override
  Future<Presenca?> buscarPresenca(int alunoId, int rotaId) async {
    final resultado = await (await _obterConexao()).executar(
      '$_select where p.rota_id = @rota_id and p.aluno_id = @aluno_id',
      {'rota_id': rotaId, 'aluno_id': alunoId},
    );
    if (resultado.isEmpty) return null;
    return _paraPresenca(resultado.first.toColumnMap());
  }

  @override
  Future<Presenca?> buscarPorRegistroId(String registroId) async {
    final resultado = await (await _obterConexao()).executar(
      '$_select where e.registro_id = @registro_id:uuid',
      {'registro_id': registroId},
    );
    if (resultado.isEmpty) return null;
    return _paraPresenca(resultado.first.toColumnMap());
  }

  @override
  Future<void> salvar(Presenca presenca) async {
    final embarque = presenca.embarque;
    try {
      // Situação + embarque em UMA transação: ou grava os dois, ou nenhum.
      await (await _obterConexao()).emTransacao((tx) async {
        await tx.execute(
          Sql.named('update presenca set situacao = @situacao where id = @id'),
          parameters: {'situacao': presenca.situacao.codigo, 'id': presenca.id},
        );
        if (embarque != null && embarque.id == null) {
          await tx.execute(
            Sql.named('''
              insert into embarque
                (registro_id, presenca_id, data_hora, latitude, longitude)
              values
                (@registro_id:uuid, @presenca_id:int8, @data_hora:timestamptz,
                 @latitude:float8, @longitude:float8)
            '''),
            parameters: {
              'registro_id': embarque.registroId,
              'presenca_id': presenca.id,
              'data_hora': embarque.dataHora,
              'latitude': embarque.localizacao?.latitude,
              'longitude': embarque.localizacao?.longitude,
            },
          );
        }
      });
    } on UniqueViolationException {
      // registro_id repetido ou presença já com embarque (corrida entre
      // requisições). O runTx já desfez a transação. RNF-006.
      throw EmbarqueDuplicadoException(embarque?.registroId ?? '');
    }
  }

  Presenca _paraPresenca(Map<String, dynamic> m) {
    final embarqueId = m['embarque_id'] as int?;
    final latitude = m['embarque_latitude'] as double?;
    final longitude = m['embarque_longitude'] as double?;
    return Presenca(
      id: m['id'] as int,
      rotaId: m['rota_id'] as int,
      aluno: Aluno(
        id: m['aluno_id'] as int,
        nome: m['aluno_nome'] as String,
        dataNascimento: m['data_nascimento'] as DateTime,
      ),
      pontoParada: PontoParada(
        id: m['ponto_id'] as int,
        endereco: m['endereco'] as String,
        localizacao: Localizacao(
          latitude: m['ponto_latitude'] as double,
          longitude: m['ponto_longitude'] as double,
        ),
      ),
      ordem: m['ordem'] as int,
      situacao: SituacaoPresenca.deCodigo(m['situacao'] as String),
      embarque: embarqueId == null
          ? null
          : Embarque(
              id: embarqueId,
              registroId: m['registro_id'] as String,
              dataHora: m['data_hora'] as DateTime,
              localizacao: latitude == null || longitude == null
                  ? null
                  : Localizacao(latitude: latitude, longitude: longitude),
            ),
    );
  }
}
