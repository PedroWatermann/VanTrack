/// Configurações do app que são escolhidas na hora de rodar.
///
/// Elas são passadas no comando `flutter run` com `--dart-define`. Exemplos:
///
///   flutter run -d chrome --dart-define=USE_MOCK=true
///   (roda no navegador com os dados simulados, sem precisar do servidor)
///
///   flutter run --dart-define=API_URL=http://10.0.2.2:8080
///   (roda no emulador Android conversando com o servidor do computador)
class Config {
  Config._();

  /// Endereço do servidor do VanTrack.
  /// Se ninguém informar outro, usa http://localhost:8080 (o próprio computador).
  static const String apiUrl = String.fromEnvironment(
    'API_URL',
    defaultValue: 'http://localhost:8080',
  );

  /// Liga ou desliga os dados simulados.
  /// true = o app usa os dados simulados (DadosMock) e funciona sem o servidor.
  /// false (padrão) = o app conversa com o servidor de verdade.
  static const bool useMock = bool.fromEnvironment('USE_MOCK');
}
