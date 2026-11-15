import '../../cadastro/dominio/van.dart';
import '../../compartilhado/infraestrutura/conexao_banco.dart';
import '../dominio/rota.dart';
import '../dominio/rota_repository.dart';

/// `RotaRepositoryPostgres` — rota :: infraestrutura.
///
/// Responsabilidade: implementar o contrato [RotaRepository] com SQL no
/// Postgres (tabelas `rota`, `van` e `vinculo_motorista_van`). RN-012, UC-S05,
/// UC-R02.
class RotaRepositoryPostgres implements RotaRepository {
  const RotaRepositoryPostgres(this._obterConexao);

  /// Abre (ou reaproveita) o pool único da [ConexaoBanco]. Mesmo padrão do
  /// `SessaoRepositoryPostgres`, para o `routes/_middleware.dart` montar os
  /// repositórios sem `await`.
  final Future<ConexaoBanco> Function() _obterConexao;

  // horario_previsto é a hora local de Brasília no dia da rota: data + hora,
  // interpretadas em America/Sao_Paulo, viram um instante (timestamptz).
  static const _select = '''
    select r.id, r.data, r.trajeto, r.situacao,
           (r.data + r.horario_previsto) at time zone 'America/Sao_Paulo'
             as horario_previsto,
           v.id as van_id, v.placa, v.modelo, v.capacidade
      from rota r
      join van v on v.id = r.van_id
  ''';

  @override
  Future<Rota?> buscarPorId(int rotaId) async {
    final resultado = await (await _obterConexao()).executar(
      '$_select where r.id = @id',
      {'id': rotaId},
    );
    if (resultado.isEmpty) return null;
    return _paraRota(resultado.first.toColumnMap());
  }

  @override
  Future<Rota?> buscarDoMotorista(int motoristaId, DateTime data) async {
    final resultado = await (await _obterConexao()).executar(
      '''
      $_select
      -- RN-012: a van em que o motorista tem vínculo ativo
      join vinculo_motorista_van vm on vm.van_id = r.van_id and vm.fim is null
     where vm.motorista_id = @motorista_id
       and r.data = cast(@data as date)
     order by r.horario_previsto
     limit 1
      ''',
      {'motorista_id': motoristaId, 'data': _somenteDia(data)},
    );
    if (resultado.isEmpty) return null;
    return _paraRota(resultado.first.toColumnMap());
  }

  /// `AAAA-MM-DD` com os campos da própria data (sem conversão de fuso).
  static String _somenteDia(DateTime data) =>
      '${data.year.toString().padLeft(4, '0')}-'
      '${data.month.toString().padLeft(2, '0')}-'
      '${data.day.toString().padLeft(2, '0')}';

  Rota _paraRota(Map<String, dynamic> m) => Rota(
        id: m['id'] as int,
        van: Van(
          id: m['van_id'] as int,
          placa: m['placa'] as String,
          modelo: m['modelo'] as String,
          capacidade: m['capacidade'] as int,
        ),
        data: m['data'] as DateTime,
        trajeto: Trajeto.deCodigo(m['trajeto'] as String),
        horarioPrevisto: m['horario_previsto'] as DateTime,
        situacao: m['situacao'] as String,
      );
}
