import 'package:app/avisos/aplicacao/avisos_service.dart';
import 'package:app/avisos/apresentacao/tela_avisos.dart';
import 'package:app/avisos/infraestrutura/avisos_api.dart';
import 'package:app/compartilhado/api_client.dart';
import 'package:app/compartilhado/mock/dados_mock.dart';
import 'package:app/compartilhado/sessao.dart';
import 'package:app/embarque/aplicacao/modulo_embarque.dart';
import 'package:app/embarque/aplicacao/rota_do_dia_service.dart';
import 'package:app/embarque/infraestrutura/embarque_api.dart';
import 'package:app/login/aplicacao/login_service.dart';
import 'package:app/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:mocktail/mocktail.dart';

class _Api extends Mock implements ApiClient {}

class _ModuloEmbarque extends Mock implements ModuloEmbarque {}

void main() {
  const responsavel = UsuarioLogado(
    id: 1,
    nome: 'Maria Souza',
    papel: Papel.responsavel,
  );
  const alunos = [
    {'alunoId': 1, 'nome': 'Ana Souza'},
    {'alunoId': 2, 'nome': 'Beatriz Reis'},
  ];
  final agora = DateTime.utc(2026, 11, 16, 10);
  final pontoNaoLido = find.byWidgetPredicate(
    (widget) => widget is Icon && widget.semanticLabel == 'Não lido',
  );

  Map<String, Object> aviso({
    int id = 10,
    int alunoId = 1,
    String mensagem = 'Ana Souza embarcou na van às 06:42.',
    String dataHora = '2026-11-16T09:42:10Z',
    bool lida = false,
  }) => {
    'id': id,
    'alunoId': alunoId,
    'alunoNome': 'Ana Souza',
    'tipo': 'EMBARQUE',
    'mensagem': mensagem,
    'dataHora': dataHora,
    'lida': lida,
  };

  Future<void> abrirTela(
    WidgetTester tester, {
    List<Map<String, Object>> vinculados = alunos,
    required List<Map<String, Object>> avisos,
  }) async {
    final api = _Api();
    when(() => api.get('/alunos'))
        .thenAnswer((_) async => RespostaApi(200, vinculados));
    when(() => api.get('/notificacoes'))
        .thenAnswer((_) async => RespostaApi(200, avisos));
    await tester.pumpWidget(
      MaterialApp(
        home: EscopoAvisos(
          service: AvisosService(AvisosApi(api), agora: () => agora),
          child: const TelaAvisos(usuario: responsavel),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'dois alunos com o mesmo nome têm status distintos pelo alunoId',
    (tester) async {
      await abrirTela(
        tester,
        vinculados: const [
          {'alunoId': 1, 'nome': 'Ana Souza'},
          {'alunoId': 2, 'nome': 'Ana Souza'},
        ],
        avisos: [aviso(alunoId: 2)],
      );

      final cards = find.byType(Card);
      expect(cards, findsNWidgets(2));
      expect(
        find.descendant(
          of: cards.at(0),
          matching: find.text('Aguardando embarque'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: cards.at(1),
          matching: find.text('Na van desde 06:42'),
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets('aviso de ontem em Brasília deixa os cards e o estado vazio', (
    tester,
  ) async {
    // Mesmo dia em UTC, mas ainda eram 23:30 do dia anterior em Brasília.
    await abrirTela(
      tester,
      avisos: [
        aviso(mensagem: 'Aviso de ontem', dataHora: '2026-11-16T02:30:00Z'),
      ],
    );

    expect(find.text('Ana Souza'), findsOneWidget);
    expect(find.text('Beatriz Reis'), findsOneWidget);
    expect(find.text('Aguardando embarque'), findsNWidgets(2));
    expect(
      find.text(
        'Nenhum aviso hoje. Você será avisado quando o aluno embarcar.',
      ),
      findsOneWidget,
    );
    expect(find.text('Aviso de ontem'), findsNothing);
  });

  testWidgets('ordena os avisos e mostra o ponto só no não lido', (
    tester,
  ) async {
    await abrirTela(
      tester,
      avisos: [
        aviso(
          id: 9,
          mensagem: 'Aviso mais antigo',
          dataHora: '2026-11-16T06:33:00-03:00',
          lida: true,
        ),
        aviso(mensagem: 'Aviso mais novo'),
      ],
    );

    final novo = find.widgetWithText(ListTile, 'Aviso mais novo');
    final antigo = find.widgetWithText(ListTile, 'Aviso mais antigo');
    expect(tester.getTopLeft(novo).dy, lessThan(tester.getTopLeft(antigo).dy));
    expect(find.descendant(of: novo, matching: pontoNaoLido), findsOneWidget);
    expect(find.descendant(of: antigo, matching: pontoNaoLido), findsNothing);
    expect(find.text('Na van desde 06:42'), findsOneWidget);
  });

  testWidgets(
    'o login do responsável abre Avisos usando o mock compartilhado',
    (tester) async {
      final sessao = Sessao();
      final api = ApiClient(
        sessao: sessao,
        usarMock: true,
        mock: DadosMock(atraso: Duration.zero),
        cliente: MockClient((_) async => throw StateError('Rede no modo mock')),
      );
      await tester.pumpWidget(
        VanTrackApp(
          loginService: LoginService(api: api, sessao: sessao),
          moduloEmbarque: _ModuloEmbarque(),
          rotaDoDiaService: RotaDoDiaService(EmbarqueApi(api)),
        ),
      );
      await tester.pumpAndSettle();
      final ricardo = find.text('Ricardo Alves');
      await tester.scrollUntilVisible(ricardo, 200);
      await tester.tap(ricardo);
      await tester.pumpAndSettle();

      expect(find.text('Avisos'), findsOneWidget);
      expect(find.text('Bruno Alves'), findsOneWidget);
      expect(find.text('Aguardando embarque'), findsOneWidget);
      expect(find.text('Não foi possível carregar os avisos.'), findsNothing);
    },
  );
}
