import '../../compartilhado/infraestrutura/conexao_banco.dart';
import '../dominio/aluno.dart';
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
  Future<List<Aluno>> buscarAlunosDoResponsavel(int responsavelId) async {
    final resultado = await (await _obterConexao()).executar(
      '''
      select a.id, a.nome, a.data_nascimento
        from aluno a
        join aluno_responsavel ar on ar.aluno_id = a.id
       -- RN-002: só os alunos vinculados a este responsável
       where ar.responsavel_id = @responsavel_id
       order by a.nome, a.id
      ''',
      {'responsavel_id': responsavelId},
    );
    return resultado.map((linha) {
      final m = linha.toColumnMap();
      return Aluno(
        id: m['id'] as int,
        nome: m['nome'] as String,
        dataNascimento: m['data_nascimento'] as DateTime,
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
    return _paraVinculo(resultado.first.toColumnMap());
  }

  @override
  Future<VinculoMotoristaVan?> buscarVinculoAtivoDoMotorista(
    int motoristaId,
  ) async {
    final resultado = await (await _obterConexao()).executar(
      '''
      select id, motorista_id, van_id, inicio, fim
        from vinculo_motorista_van
       where motorista_id = @motorista_id
         -- RN-012: ativo = sem data de fim
         and fim is null
       order by inicio desc
       limit 1
      ''',
      {'motorista_id': motoristaId},
    );
    if (resultado.isEmpty) return null;
    return _paraVinculo(resultado.first.toColumnMap());
  }

  VinculoMotoristaVan _paraVinculo(Map<String, dynamic> m) =>
      VinculoMotoristaVan(
        id: m['id'] as int,
        motoristaId: m['motorista_id'] as int,
        vanId: m['van_id'] as int,
        inicio: m['inicio'] as DateTime,
        fim: m['fim'] as DateTime?,
      );
}
