import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:app/compartilhado/api_client.dart';
import 'package:app/compartilhado/mock/dados_mock.dart';
import 'package:app/compartilhado/sessao.dart';
import 'package:app/login/aplicacao/login_service.dart';
import 'package:app/login/apresentacao/tela_login.dart';

void main() {
  late Sessao sessao;

  /// Monta a tela de login. As telas de destino são simples, só para o teste
  /// saber para onde o app foi.
  Future<void> abrirTelaLogin(WidgetTester tester, ApiClient api) async {
    await tester.pumpWidget(MaterialApp(
      home: TelaLogin(
        loginService: LoginService(api: api, sessao: sessao),
        telaDoMotorista: (u) => Scaffold(body: Text('Rota do dia de ${u.nome}')),
        telaDoResponsavel: (u) => Scaffold(body: Text('Avisos de ${u.nome}')),
      ),
    ));
    await tester.pumpAndSettle();
  }

  ApiClient apiSimulada() => ApiClient(
        sessao: sessao,
        usarMock: true,
        mock: DadosMock(atraso: Duration.zero),
      );

  setUp(() => sessao = Sessao());

  testWidgets('lista os usuários com nome e papel', (tester) async {
    await abrirTelaLogin(tester, apiSimulada());

    expect(find.text('João Pereira'), findsOneWidget);
    expect(find.text('Maria Souza'), findsOneWidget);
    expect(find.text('Motorista'), findsNWidgets(2));
  });

  testWidgets('motorista entra e vai para a Rota do dia', (tester) async {
    await abrirTelaLogin(tester, apiSimulada());

    await tester.tap(find.text('João Pereira'));
    await tester.pumpAndSettle();

    expect(find.text('Rota do dia de João Pereira'), findsOneWidget);
    expect(sessao.logado, isTrue);
    expect(sessao.usuario?.papel, Papel.motorista);
  });

  testWidgets('responsável entra e vai para Avisos', (tester) async {
    await abrirTelaLogin(tester, apiSimulada());

    await tester.tap(find.text('Maria Souza'));
    await tester.pumpAndSettle();

    expect(find.text('Avisos de Maria Souza'), findsOneWidget);
    expect(sessao.usuario?.papel, Papel.responsavel);
  });

  testWidgets('mostra mensagem de erro quando o servidor falha', (tester) async {
    final servidorComErro = MockClient((_) async => http.Response('', 500));
    final api = ApiClient(sessao: sessao, usarMock: false, cliente: servidorComErro);

    await abrirTelaLogin(tester, api);

    expect(find.text('Não foi possível carregar os usuários. Tente de novo.'), findsOneWidget);
    expect(find.text('Tentar de novo'), findsOneWidget);
  });
}
