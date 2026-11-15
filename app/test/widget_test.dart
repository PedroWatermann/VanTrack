import 'package:flutter_test/flutter_test.dart';

import 'package:app/compartilhado/api_client.dart';
import 'package:app/compartilhado/mock/dados_mock.dart';
import 'package:app/compartilhado/sessao.dart';
import 'package:app/login/aplicacao/login_service.dart';
import 'package:app/main.dart';

void main() {
  testWidgets('o app abre na tela de login', (tester) async {
    final sessao = Sessao();
    final api = ApiClient(
      sessao: sessao,
      usarMock: true,
      mock: DadosMock(atraso: Duration.zero),
    );

    await tester.pumpWidget(VanTrackApp(loginService: LoginService(api: api, sessao: sessao)));
    await tester.pumpAndSettle();

    expect(find.text('Quem está usando o app?'), findsOneWidget);
  });
}
