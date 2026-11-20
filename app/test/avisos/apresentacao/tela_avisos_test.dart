import 'dart:async';

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

  Future<_Api> abrirTela(
    WidgetTester tester, {
    List<Map<String, Object>> vinculados = alunos,
    required List<Map<String, Object>> avisos,
    Future<RespostaApi> Function()? consultarAvisos,
    Future<RespostaApi> Function()? marcarComoLido,
    DateTime Function()? relogio,
  }) async {
    final api = _Api();
    when(() => api.get('/alunos'))
        .thenAnswer((_) async => RespostaApi(200, vinculados));
    when(() => api.get('/notificacoes')).thenAnswer(
      (_) async => consultarAvisos == null
          ? RespostaApi(200, avisos)
          : await consultarAvisos(),
    );
    when(() => api.patch(any())).thenAnswer(
      (_) async => marcarComoLido == null
          ? const RespostaApi(204)
          : await marcarComoLido(),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: EscopoAvisos(
          service: AvisosService(AvisosApi(api), agora: relogio ?? () => agora),
          child: const TelaAvisos(usuario: responsavel),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return api;
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
    final api = await abrirTela(
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
    verifyNever(() => api.patch(any()));
  });

  testWidgets('ordena os avisos e mostra o ponto só no não lido', (
    tester,
  ) async {
    final leitura = Completer<RespostaApi>();
    final api = await abrirTela(
      tester,
      marcarComoLido: () => leitura.future,
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
    verify(() => api.patch('/notificacoes/10/lida')).called(1);
    verifyNever(() => api.patch('/notificacoes/9/lida'));

    leitura.complete(const RespostaApi(204));
    await tester.pumpAndSettle();
    expect(find.descendant(of: novo, matching: pontoNaoLido), findsNothing);
  });

  testWidgets('mantém os avisos offline e atualiza ao recuperar a conexão', (
    tester,
  ) async {
    var hora = agora;
    var offline = false;
    var respostas = [aviso(mensagem: 'Aviso já exibido')];
    final api = await abrirTela(
      tester,
      avisos: const [],
      relogio: () => hora,
      consultarAvisos: () async {
        if (offline) throw TimeoutException('Sem conexão');
        return RespostaApi(200, respostas);
      },
    );

    Future<void> avancar(int segundos) async {
      final tempo = Duration(seconds: segundos);
      hora = hora.add(tempo);
      await tester.pump(tempo);
      await tester.pumpAndSettle();
    }

    expect(find.text('Atualizado há 0 s'), findsOneWidget);
    verify(() => api.get('/notificacoes')).called(1);

    offline = true;
    await avancar(9);
    expect(find.text('Atualizado há 9 s'), findsOneWidget);
    verifyNever(() => api.get('/notificacoes'));

    await avancar(1);
    expect(
      find.text(
        'Sem conexão. Os avisos podem estar desatualizados. Última atualização às 07:00.',
      ),
      findsOneWidget,
    );
    expect(find.text('Aviso já exibido'), findsOneWidget);
    expect(find.text('Na van desde 06:42'), findsOneWidget);
    verify(() => api.get('/notificacoes')).called(1);

    offline = false;
    respostas = [
      ...respostas,
      aviso(
        id: 11,
        alunoId: 2,
        mensagem: 'Novo aviso',
        dataHora: '2026-11-16T07:00:12-03:00',
      ),
    ];
    await avancar(10);
    expect(find.textContaining('Sem conexão.'), findsNothing);
    expect(find.text('Atualizado há 0 s'), findsOneWidget);
    expect(find.text('Novo aviso'), findsOneWidget);
    expect(find.text('Na van desde 07:00'), findsOneWidget);
    verify(() => api.get('/notificacoes')).called(1);
    verify(() => api.patch('/notificacoes/10/lida')).called(1);
    verify(() => api.patch('/notificacoes/11/lida')).called(1);

    await tester.pumpWidget(const SizedBox.shrink());
    await avancar(20);
    verifyNever(() => api.get('/notificacoes'));
  });

  testWidgets(
    'PATCH que falha preserva o ponto e é repetido no próximo ciclo',
    (tester) async {
      var tentativas = 0;
      final api = await abrirTela(
        tester,
        avisos: [aviso()],
        marcarComoLido: () async => RespostaApi(++tentativas == 1 ? 503 : 204),
      );
      expect(pontoNaoLido, findsOneWidget);

      await tester.pump(const Duration(seconds: 10));
      await tester.pumpAndSettle();
      expect(pontoNaoLido, findsNothing);
      verify(() => api.patch('/notificacoes/10/lida')).called(2);
    },
  );

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
