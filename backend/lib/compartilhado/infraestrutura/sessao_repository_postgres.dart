import 'package:postgres/postgres.dart';

import '../../cadastro/dominio/motorista.dart';
import '../../cadastro/dominio/responsavel.dart';
import '../../cadastro/dominio/usuario.dart';
import '../dominio/sessao.dart';
import '../dominio/sessao_repository.dart';
import '../dominio/usuario_repository.dart';
import 'conexao_banco.dart';

/// SQL dos usuários e sessões do login, usando a base e as entidades do membro A.
/// RNF-002; apoio ao UC-S05/RF-009 e UC-I02/RF-011.
class SessaoRepositoryPostgres implements SessaoRepository, UsuarioRepository {
  const SessaoRepositoryPostgres(this.obterConexao);

  final Future<ConexaoBanco> Function() obterConexao;

  @override
  Future<List<Usuario>> listar() async {
    final banco = await obterConexao();
    final linhas = await banco.executar("""
      SELECT id, nome, login, telefone, cnh AS detalhe, 'MOTORISTA' AS papel FROM motorista
      UNION ALL
      SELECT id, nome, login, telefone, email AS detalhe, 'RESPONSAVEL' AS papel FROM responsavel
      ORDER BY papel, id
    """);
    return [
      for (final linha in linhas) _usuario(linha, Papel.deCodigo(linha[5])!)
    ];
  }

  @override
  Future<Usuario?> buscarPorIdEPapel(int id, Papel papel) async {
    final banco = await obterConexao();
    // Identificadores vêm somente do enum; o id recebido é parametrizado.
    final motorista = papel == Papel.motorista;
    final tabela = motorista ? 'motorista' : 'responsavel';
    final detalhe = motorista ? 'cnh' : 'email';
    final linhas = await banco.executar(
      'SELECT id, nome, login, telefone, $detalhe FROM $tabela WHERE id = @id',
      {'id': id},
    );
    return linhas.isEmpty ? null : _usuario(linhas.first, papel);
  }

  @override
  Future<Sessao?> buscarPorToken(String token) async {
    final banco = await obterConexao();
    final linhas = await banco.executar('''
      SELECT token::text, criada_em, COALESCE(motorista_id, responsavel_id), papel
      FROM sessao WHERE token = CAST(@token AS uuid)
    ''', {'token': token});
    if (linhas.isEmpty) return null;
    final linha = linhas.first;
    final usuario =
        await buscarPorIdEPapel(linha[2]! as int, Papel.deCodigo(linha[3])!);
    if (usuario == null) return null;
    return Sessao(
        token: linha[0]! as String,
        criadaEm: linha[1]! as DateTime,
        usuario: usuario);
  }

  @override
  Future<void> salvar(Sessao sessao) async {
    final banco = await obterConexao();
    final usuario = sessao.usuario;
    await banco.executar('''
      INSERT INTO sessao (token, papel, motorista_id, responsavel_id, criada_em)
      VALUES (CAST(@token AS uuid), @papel, @motorista, @responsavel, @criadaEm)
    ''', {
      'token': sessao.token,
      'papel': usuario.papel.codigo,
      'motorista': usuario.papel == Papel.motorista ? usuario.id : null,
      'responsavel': usuario.papel == Papel.responsavel ? usuario.id : null,
      'criadaEm': sessao.criadaEm,
    });
  }

  Usuario _usuario(ResultRow linha, Papel papel) => papel == Papel.motorista
      ? Motorista(
          id: linha[0]! as int,
          nome: linha[1]! as String,
          login: linha[2]! as String,
          telefone: linha[3]! as String,
          cnh: linha[4]! as String)
      : Responsavel(
          id: linha[0]! as int,
          nome: linha[1]! as String,
          login: linha[2]! as String,
          telefone: linha[3]! as String,
          email: linha[4]! as String);
}
