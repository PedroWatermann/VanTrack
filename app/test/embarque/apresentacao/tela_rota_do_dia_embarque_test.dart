import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:app/embarque/aplicacao/modulo_embarque.dart';
import 'package:app/embarque/aplicacao/rota_do_dia_service.dart';
import 'package:app/embarque/apresentacao/tela_rota_do_dia.dart';
import 'package:app/embarque/dominio/aluno_da_rota.dart';
import 'package:app/embarque/dominio/embarque_remoto.dart';
import 'package:app/embarque/dominio/registro_embarque.dart';
import 'package:app/embarque/dominio/rota_do_dia.dart';

/// Servidor falso com Ana, Beatriz e Carlos na rota de hoje.
class RemotoFalso implements EmbarqueRemoto {
  @override
  Future<RotaDoDia> buscarRotaDoDia() async => RotaDoDia(
        rotaId: 1,
        trajeto: 'IDA',
        horarioPrevisto: DateTime.parse('2026-11-16T06:30:00-03:00'),
        placa: 'ABC-1D23',
      );

  @override
  Future<List<AlunoDaRota>> listarAlunos(int rotaId) async => const [
        AlunoDaRota(alunoId: 1, nome: 'Ana Souza', ordem: 1, endereco: 'Rua 1', embarcado: false),
        AlunoDaRota(alunoId: 2, nome: 'Beatriz Reis', ordem: 2, endereco: 'Rua 2', embarcado: false),
        AlunoDaRota(alunoId: 3, nome: 'Carlos Lima', ordem: 3, endereco: 'Rua 3', embarcado: false),
      ];

  @override
  Future<void> enviar(RegistroEmbarque registro) async {}

  @override
  Future<Map<String, int>> sincronizar(int rotaId, List<RegistroEmbarque> registros) async => {};
}

/// Módulo de embarque falso: responde com o status configurado ou lança o
/// erro configurado, e permite emitir eventos de pendentes.
class ModuloFalso implements ModuloEmbarque {
  StatusEnvio status = StatusEnvio.enviado;
  Exception? erro;
  List<RegistroPendente> pendentes = const [];
  final eventos = StreamController<EventoPendente>.broadcast();
  final List<int> registrados = [];

  @override
  Future<ResultadoEmbarque> registrarEmbarque(int rotaId, int alunoId) async {
    registrados.add(alunoId);
    final e = erro;
    if (e != null) throw e;
    return ResultadoEmbarque('r$alunoId', alunoId, DateTime.parse('2026-11-16T06:42:00-03:00'), status);
  }

  @override
  Future<List<RegistroPendente>> listarPendentes(int rotaId) async => pendentes;

  @override
  Stream<EventoPendente> get aoMudarPendentes => eventos.stream;
}

void main() {
  late ModuloFalso modulo;

  setUp(() => modulo = ModuloFalso());

  Future<void> abrirTela(WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(
      home: TelaRotaDoDia(modulo: modulo, rotaDoDiaService: RotaDoDiaService(RemotoFalso())),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('um toque registra o embarque, sem diálogo de confirmação', (tester) async {
    await abrirTela(tester);

    await tester.tap(find.text('EMBARCOU'));
    await tester.pumpAndSettle();

    expect(modulo.registrados, [1]);
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text('Embarcou às 06:42'), findsOneWidget);
  });

  testWidgets('o aluno pode embarcar fora da ordem pelo botão de "Depois"', (tester) async {
    await abrirTela(tester);

    await tester.tap(find.widgetWithText(OutlinedButton, 'Embarcou').last); // Carlos
    await tester.pumpAndSettle();

    expect(modulo.registrados, [3]);
    expect(find.text('1 de 3 na van'), findsOneWidget);
  });

  testWidgets('pendente sincronizado muda de âmbar para verde sem recarregar', (tester) async {
    modulo.status = StatusEnvio.pendente;
    await abrirTela(tester);
    await tester.tap(find.text('EMBARCOU'));
    await tester.pumpAndSettle();
    expect(find.text('Pendente de sincronização'), findsOneWidget);

    modulo.eventos.add(const EventoPendente('r1', 1, true));
    await tester.pumpAndSettle();

    expect(find.text('Pendente de sincronização'), findsNothing);
    expect(find.byIcon(Icons.check_circle), findsOneWidget);
  });

  testWidgets('embarques pendentes guardados aparecem em âmbar ao abrir a tela', (tester) async {
    modulo.pendentes = [RegistroPendente('r2', 2, DateTime.parse('2026-11-16T06:45:00-03:00'))];

    await abrirTela(tester);

    expect(find.text('Pendente de sincronização'), findsOneWidget);
    expect(find.text('1 de 3 na van'), findsOneWidget);
  });

  testWidgets('409: avisa que o aluno já embarcou e ele fica em Na van (teste 6)', (tester) async {
    modulo.erro = const EmbarqueException(409, 'Ana Souza já embarcou.');
    await abrirTela(tester);

    await tester.tap(find.text('EMBARCOU'));
    await tester.pumpAndSettle();

    expect(find.text('Ana Souza já embarcou.'), findsOneWidget);
    expect(find.text('1 de 3 na van'), findsOneWidget);
  });

  testWidgets('erro inesperado: avisa e o aluno volta para a lista', (tester) async {
    modulo.erro = Exception('falha');
    await abrirTela(tester);

    await tester.tap(find.text('EMBARCOU'));
    await tester.pumpAndSettle();

    expect(find.text('Não foi possível registrar. Tente de novo.'), findsOneWidget);
    expect(find.text('0 de 3 na van'), findsOneWidget);
  });

  testWidgets('pendente recusado pelo servidor volta para a lista com aviso', (tester) async {
    modulo.status = StatusEnvio.pendente;
    await abrirTela(tester);
    await tester.tap(find.text('EMBARCOU'));
    await tester.pumpAndSettle();

    modulo.eventos.add(const EventoPendente('r1', 1, false, 403));
    await tester.pumpAndSettle();

    expect(find.text('O embarque de Ana Souza foi recusado pelo servidor.'), findsOneWidget);
    expect(find.text('0 de 3 na van'), findsOneWidget);
  });
}
