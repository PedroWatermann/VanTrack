import 'package:dotenv/dotenv.dart';

/// Lê a configuração do servidor (camada de infraestrutura, módulo compartilhado).
///
/// Responsabilidade: obter a string de conexão do Postgres (Supabase) de
/// `backend/.env` ou, se não houver arquivo, das variáveis de ambiente do sistema.
/// A senha fica fora do código e do repositório (RNF-002).
///
/// O caminho do `.env` é relativo à pasta de onde o comando é executado
/// (sempre rode a partir de `backend/`).
String lerDatabaseUrl() {
  final env = DotEnv(includePlatformEnvironment: true, quiet: true)..load();
  final url = env['DATABASE_URL'];
  if (url == null || url.trim().isEmpty) {
    throw StateError(
      'DATABASE_URL não configurada. Copie backend/.env.example para '
      'backend/.env e preencha a string de conexão do seu projeto do Supabase.',
    );
  }
  return url.trim();
}
