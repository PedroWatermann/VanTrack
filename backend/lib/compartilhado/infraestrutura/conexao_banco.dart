import 'package:postgres/postgres.dart';

/// `ConexaoBanco` — infraestrutura do módulo compartilhado (diagrama de classes 2/3).
///
/// Responsabilidade: manter o ÚNICO pool de conexões com o PostgreSQL do
/// Supabase e oferecer consulta e transação (`runTx`) aos repositórios Postgres.
/// O Supabase é usado só como banco: o app nunca o acessa direto (RNF-002).
///
/// Apoia o UC-S05 (Registrar Embarque) e o UC-I02 (Notificar Responsável).
///
/// Por padrão a conexão usa SSL (exigido pelo Supabase). Para um Postgres local
/// sem SSL, acrescente `?sslmode=disable` no fim da DATABASE_URL.
class ConexaoBanco {
  ConexaoBanco._(this._pool);

  final Pool<void> _pool;

  static ConexaoBanco? _instancia;

  /// Abre o pool na primeira chamada; as seguintes devolvem o MESMO pool.
  static Future<ConexaoBanco> abrir(String databaseUrl) async =>
      _instancia ??= ConexaoBanco._(Pool<void>.withUrl(databaseUrl));

  /// Executa um comando SQL com parâmetros nomeados (`@nome` ou `@nome:tipo`).
  Future<Result> executar(
    String sql, [
    Map<String, Object?> parametros = const {},
  ]) {
    return _pool.execute(Sql.named(sql), parameters: parametros);
  }

  /// Executa [acao] em uma transação: se ela lançar, tudo é desfeito.
  Future<T> emTransacao<T>(Future<T> Function(TxSession tx) acao) {
    return _pool.runTx(acao);
  }

  /// Fecha o pool (usado por comandos de linha de comando, como o reset).
  Future<void> fechar() async {
    if (identical(_instancia, this)) _instancia = null;
    await _pool.close();
  }
}
