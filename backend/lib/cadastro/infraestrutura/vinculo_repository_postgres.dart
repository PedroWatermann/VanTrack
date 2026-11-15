import '../../compartilhado/infraestrutura/conexao_banco.dart';
import '../dominio/responsavel.dart';
import '../dominio/vinculo_motorista_van.dart';
import '../dominio/vinculo_repository.dart';

/// `VinculoRepositoryPostgres` — cadastro :: infraestrutura.
///
/// Responsabilidade: implementar o contrato [VinculoRepository] com SQL no
/// Postgres (tabelas `aluno_responsavel`, `responsavel` e
/// `vinculo_motorista_van`). RN-002, RN-009, RN-012.
class VinculoRepositoryPostgres implements VinculoRepository {
  const VinculoRepositoryPostgres(this._obterConexao);

  /// Abre (ou reaproveita) o pool único da [ConexaoBanco]. Mesmo padrão do
  /// `SessaoRepositoryPostgres`, para o `routes/_middleware.dart` montar os
  /// repositórios sem `await`.
  final Future<ConexaoBanco> Function() _obterConexao;

  @override
  Future<List<Responsavel>> buscarResponsaveis(int alunoId) async {
    final resultado = await (await _obterConexao()).executar(
      '''
      select r.id, r.nome, r.login, r.senha_hash, r.telefone, r.email
        from responsavel r
        join aluno_responsavel ar on ar.responsavel_id = r.id
       where ar.aluno_id = @aluno_id
       order by r.id
      ''',
      {'aluno_id': alunoId},
    );
    return resultado.map((linha) {
      final m = linha.toColumnMap();
      return Responsavel(
        id: m['id'] as int,
        nome: m['nome'] as String,
        login: m['login'] as String,
        senhaHash: m['senha_hash'] as String?,
        telefone: m['telefone'] as String,
        email: m['email'] as String,
      );
    }).toList();
  }

  @override
  Future<VinculoMotoristaVan?> buscarVinculoAtivo(int vanId) async {
    final resultado = await (await _obterConexao()).executar(
      '''
      select id, motorista_id, van_id, inicio, fim
        from vinculo_motorista_van
       where van_id = @van_id
         -- RN-012: ativo = sem data de fim (só um por van, índice único)
         and fim is null
      ''',
      {'van_id': vanId},
    );
    if (resultado.isEmpty) return null;
    final m = resultado.first.toColumnMap();
    return VinculoMotoristaVan(
      id: m['id'] as int,
      motoristaId: m['motorista_id'] as int,
      vanId: m['van_id'] as int,
      inicio: m['inicio'] as DateTime,
      fim: m['fim'] as DateTime?,
    );
  }
}
