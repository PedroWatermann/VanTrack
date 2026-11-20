import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:app/compartilhado/cores.dart';
import 'package:app/embarque/aplicacao/modulo_embarque.dart';
import 'package:app/embarque/aplicacao/rota_do_dia_service.dart';
import 'package:app/embarque/apresentacao/tela_rota_do_dia.dart';
import 'package:app/embarque/dominio/aluno_da_rota.dart';
import 'package:app/embarque/dominio/embarque_remoto.dart';
import 'package:app/embarque/dominio/registro_embarque.dart';
import 'package:app/embarque/dominio/rota_do_dia.dart';

// Testes de widget da tela "Rota do dia" com um ModuloEmbarque falso.
// Critérios de aceite da D-08: tocar "Embarcou" move o aluno para "Na van" e
// destaca a próxima parada; status pendente mostra o ícone âmbar.
//
// UC-R02 passos 3 a 5; RF-009; RNF-005; RNF-006.

/// Servidor falso com a rota de hoje: Ana, Beatriz e Carlos, nessa ordem.
class _RemotoFalso implements EmbarqueRemoto {
  @override
  Future<RotaDoDia> buscarRotaDoDia() async => RotaDoDia(
        rotaId: 1,
        trajeto: 'IDA',
        horarioPrevisto: DateTime.parse('2026-11-20T06:30:00-03:00'),
        placa: 'ABC-1D23',
      );

  @override
  Future<List<AlunoDaRota>> listarAlunos(int rotaId) async => const [
        AlunoDaRota(alunoId: 1, nome: 'Ana Souza', ordem: 1, endereco: 'Rua das Acácias, 100', embarcado: false),
        AlunoDaRota(alunoId: 2, nome: 'Beatriz Reis', ordem: 2, endereco: 'Avenida Brasil, 1500', embarcado: false),
        AlunoDaRota(alunoId: 3, nome: 'Carlos Lima', ordem: 3, endereco: 'Rua das Flores, 210', embarcado: false),
      ];

  @override
  Future<void> enviar(RegistroEmbarque registro) async {}

  @override
  Future<Map<String, int>> sincronizar(int rotaId, List<RegistroEmbarque> registros) async => {};
}

/// ModuloEmbarque falso: devolve sempre o [status] escolhido pelo teste.
class _ModuloFalso implements ModuloEmbarque {
  _ModuloFalso(this.status);

  final StatusEnvio status;

  @override
  Future<ResultadoEmbarque> registrarEmbarque(int rotaId, int alunoId) async =>
      ResultadoEmbarque('reg-$alunoId', alunoId, DateTime.parse('2026-11-20T06:42:00-03:00'), status);

  @override
  Future<List<RegistroPendente>> listarPendentes(int rotaId) async => const [];

  @override
  Stream<EventoPendente> get aoMudarPendentes => const Stream.empty();
}

void main() {
  /// Abre a tela numa área alta, para todas as partes caberem sem rolar.
  Future<void> abrirTela(WidgetTester tester, StatusEnvio status) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MaterialApp(
      home: TelaRotaDoDia(
        modulo: _ModuloFalso(status),
        rotaDoDiaService: RotaDoDiaService(_RemotoFalso()),
      ),
    ));
    await tester.pumpAndSettle();
  }

  /// Nome do aluno que está no cartão em destaque ("Próxima parada").
  String alunoEmDestaque(WidgetTester tester) {
    final cartao = find.ancestor(of: find.text('EMBARCOU'), matching: find.byType(Card));
    final nomes = tester
        .widgetList<Text>(find.descendant(of: cartao, matching: find.byType(Text)))
        .map((t) => t.data)
        .whereType<String>();
    return nomes.firstWhere((n) => n.contains(' '));
  }

  /// Indica se o texto aparece abaixo do título da seção "Na van".
  bool abaixoDeNaVan(WidgetTester tester, String texto) {
    final titulo = find.textContaining('NA VAN');
    return tester.getTopLeft(find.text(texto)).dy > tester.getTopLeft(titulo).dy;
  }

  testWidgets('tocar "Embarcou" move o aluno para Na van e destaca a próxima parada',
      (tester) async {
    await abrirTela(tester, StatusEnvio.enviado);
    expect(alunoEmDestaque(tester), 'Ana Souza');

    await tester.tap(find.text('EMBARCOU'));
    await tester.pumpAndSettle();

    expect(abaixoDeNaVan(tester, 'Ana Souza'), isTrue);
    expect(find.text('NA VAN (1)'), findsOneWidget);
    expect(alunoEmDestaque(tester), 'Beatriz Reis');
    final check = tester.widget<Icon>(find.byIcon(Icons.check_circle));
    expect(check.color, CoresApp.verde);
    expect(find.text('Embarcou às 06:42'), findsOneWidget);
  });

  testWidgets('a próxima parada avança a cada toque até todos embarcarem', (tester) async {
    await abrirTela(tester, StatusEnvio.enviado);

    await tester.tap(find.text('EMBARCOU'));
    await tester.pumpAndSettle();
    expect(alunoEmDestaque(tester), 'Beatriz Reis');

    await tester.tap(find.text('EMBARCOU'));
    await tester.pumpAndSettle();
    expect(alunoEmDestaque(tester), 'Carlos Lima');

    await tester.tap(find.text('EMBARCOU'));
    await tester.pumpAndSettle();
    expect(find.text('EMBARCOU'), findsNothing);
    expect(find.text('Todos os alunos embarcaram'), findsOneWidget);
    expect(find.text('3 de 3 na van'), findsOneWidget);
  });

  testWidgets('status pendente mostra o ícone âmbar e o texto de sincronização', (tester) async {
    await abrirTela(tester, StatusEnvio.pendente);

    await tester.tap(find.text('EMBARCOU'));
    await tester.pumpAndSettle();

    final icone = tester.widget<Icon>(find.byIcon(Icons.cloud_off));
    expect(icone.color, CoresApp.ambar);
    final texto = tester.widget<Text>(find.text('Pendente de sincronização'));
    expect(texto.style?.color, CoresApp.ambar);
    expect(find.byIcon(Icons.check_circle), findsNothing);
    // Mesmo pendente, o aluno está na van e a próxima parada avança.
    expect(abaixoDeNaVan(tester, 'Ana Souza'), isTrue);
    expect(alunoEmDestaque(tester), 'Beatriz Reis');
  });
}
