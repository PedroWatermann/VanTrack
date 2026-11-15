// Reseta o banco do SEU projeto do Supabase (Membro A, task A-05):
//   1. apaga todas as tabelas do schema public;
//   2. roda supabase/migrations/*.sql em ordem de nome;
//   3. roda supabase/seed.sql.
//
// Uso (a partir da pasta backend/):
//   dart run bin/reset_db.dart
//
// Tudo roda em uma única transação: se algum arquivo falhar, nada é alterado.
//
// ATENÇÃO ao escrever arquivos .sql: o pacote postgres do Dart não aceita
// mais de um comando que devolve linhas (SELECT) no mesmo arquivo. Use
// comandos sem resultado (CREATE, INSERT, UPDATE...) ou um bloco DO $$ ... $$.
// ignore_for_file: avoid_print

import 'dart:io';

import 'package:postgres/postgres.dart';
import 'package:vantrack_backend/compartilhado/infraestrutura/ambiente.dart';
import 'package:vantrack_backend/compartilhado/infraestrutura/conexao_banco.dart';

Future<void> main() async {
  final pastaSupabase = _acharPastaSupabase();
  final migracoes = Directory('${pastaSupabase.path}/migrations')
      .listSync()
      .whereType<File>()
      .where((f) => f.path.endsWith('.sql'))
      .toList()
    ..sort((a, b) => _nome(a).compareTo(_nome(b)));
  final seed = File('${pastaSupabase.path}/seed.sql');
  if (!seed.existsSync()) _falhar('Arquivo não encontrado: ${seed.path}');

  final String url;
  try {
    url = lerDatabaseUrl();
  } on StateError catch (erro) {
    _falhar(erro.message);
  }
  print('Conectando em ${_hostDaUrl(url)}...');

  final conexao = await ConexaoBanco.abrir(url);
  var etapa = 'apagar as tabelas';
  try {
    await conexao.emTransacao((tx) async {
      final tabelas = await tx.execute(
        "select tablename from pg_tables where schemaname = 'public'",
      );
      for (final linha in tabelas) {
        final tabela = linha[0]! as String;
        print('Apagando tabela $tabela');
        await tx.execute('drop table if exists public."$tabela" cascade');
      }
      for (final arquivo in [...migracoes, seed]) {
        etapa = _nome(arquivo);
        print('Rodando $etapa');
        await tx.execute(
          arquivo.readAsStringSync(),
          // Modo simples: permite vários comandos SQL no mesmo arquivo.
          queryMode: QueryMode.simple,
        );
      }
    });
    print('Banco resetado com ${migracoes.length} migration(s) e o seed.');
  } on ServerException catch (erro) {
    _falhar('Erro do Postgres em $etapa (nada foi alterado): $erro');
  } on Object catch (erro) {
    final dica = '$erro'.contains('Future already completed')
        ? '\nProvável causa: mais de um SELECT no mesmo arquivo .sql. '
            'Junte-os em um bloco DO \$\$ ... \$\$ (ver seed.sql).'
        : '';
    _falhar('Falha em $etapa (nada foi alterado): $erro$dica');
  } finally {
    await conexao.fechar().catchError((_) {});
  }
}

/// Procura `supabase/` na pasta acima (rodando de backend/) ou na atual.
Directory _acharPastaSupabase() {
  for (final caminho in ['../supabase', 'supabase']) {
    final pasta = Directory(caminho);
    if (Directory('${pasta.path}/migrations').existsSync()) return pasta;
  }
  _falhar(
    'Pasta supabase/migrations não encontrada. Rode o comando a partir de backend/.',
  );
}

String _nome(File arquivo) => arquivo.uri.pathSegments.last;

/// Mostra só o host, nunca a senha.
String _hostDaUrl(String url) => Uri.tryParse(url)?.host ?? '(URL inválida)';

Never _falhar(String mensagem) {
  stderr.writeln(mensagem);
  exit(1);
}
