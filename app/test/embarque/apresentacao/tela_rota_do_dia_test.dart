import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:app/embarque/aplicacao/modulo_embarque.dart';
import 'package:app/embarque/aplicacao/rota_do_dia_service.dart';
import 'package:app/embarque/apresentacao/tela_rota_do_dia.dart';
import 'package:app/embarque/dominio/aluno_da_rota.dart';
import 'package:app/embarque/dominio/embarque_remoto.dart';
import 'package:app/embarque/dominio/excecoes.dart';
import 'package:app/embarque/dominio/registro_embarque.dart';
import 'package:app/embarque/dominio/rota_do_dia.dart';

/// Servidor falso: devolve a rota e os alunos configurados, ou lança o erro.
class RemotoFalso implements EmbarqueRemoto {
  RemotoFalso({this.alunos = const [], this.erro});

  final List<AlunoDaRota> alunos;
  final Exception? erro;

  @override
  Future<RotaDoDia> buscarRotaDoDia() async => RotaDoDia(
        rotaId: 1,
        trajeto: 'IDA',
        horarioPrevisto: DateTime.parse('2026-11-16T06:30:00-03:00'),
        placa: 'ABC-1D23',
      );

  @override
  Future<List<AlunoDaRota>> listarAlunos(int rotaId) async {
    final e = erro;
    if (e != null) throw e;
    return alunos;
  }

  @override
  Future<void> enviar(RegistroEmbarque registro) async {}

  @override
  Future<Map<String, int>> sincronizar(int rotaId, List<RegistroEmbarque> registros) async => {};
}

/// Módulo de embarque falso, que não faz nada.
class ModuloFalso implements ModuloEmbarque {
  @override
  Future<ResultadoEmbarque> registrarEmbarque(int rotaId, int alunoId) async =>
      ResultadoEmbarque('r', alunoId, DateTime.now(), StatusEnvio.enviado);

  @override
  Future<List<RegistroPendente>> listarPendentes(int rotaId) async => const [];

  @override
  Stream<EventoPendente> get aoMudarPendentes => const Stream.empty();
}

AlunoDaRota aluno(int id, String nome, {bool embarcado = false}) => AlunoDaRota(
      alunoId: id,
      nome: nome,
      ordem: id,
      endereco: 'Rua $id',
      embarcado: embarcado,
    );

void main() {
  Future<void> abrirTela(WidgetTester tester, RemotoFalso remoto) async {
    await tester.pumpWidget(MaterialApp(
      home: TelaRotaDoDia(
        modulo: ModuloFalso(),
        rotaDoDiaService: RotaDoDiaService(remoto),
      ),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('mostra o cabeçalho e os alunos na ordem, com a próxima parada em destaque',
      (tester) async {
    await abrirTela(
      tester,
      RemotoFalso(alunos: [aluno(2, 'Beatriz Reis'), aluno(1, 'Ana Souza'), aluno(3, 'Carlos Lima')]),
    );

    expect(find.text('Rota do dia · Ida · 06:30'), findsOneWidget);
    expect(find.text('Van ABC-1D23'), findsOneWidget);
    expect(find.text('0 de 3 na van'), findsOneWidget);
    expect(find.text('PRÓXIMA PARADA'), findsOneWidget);
    expect(find.text('EMBARCOU'), findsOneWidget);
    expect(find.text('DEPOIS'), findsOneWidget);

    // Ana (ordem 1) é a próxima parada, mesmo vindo fora de ordem do servidor.
    final topoAna = tester.getTopLeft(find.text('Ana Souza')).dy;
    final topoBeatriz = tester.getTopLeft(find.text('Beatriz Reis')).dy;
    expect(topoAna, lessThan(topoBeatriz));
  });

  testWidgets('botão Embarcou tem largura total e no mínimo 56 de altura (RNF-005)',
      (tester) async {
    await abrirTela(tester, RemotoFalso(alunos: [aluno(1, 'Ana Souza')]));

    final botao = tester.getSize(find.widgetWithText(FilledButton, 'EMBARCOU'));
    final tela = tester.getSize(find.byType(ListView));
    expect(botao.height, greaterThanOrEqualTo(56));
    expect(botao.width, greaterThan(tela.width * 0.8));
  });

  testWidgets('aluno já embarcado aparece em Na van, com ícone verde', (tester) async {
    await abrirTela(
      tester,
      RemotoFalso(alunos: [aluno(1, 'Ana Souza', embarcado: true), aluno(2, 'Beatriz Reis')]),
    );

    expect(find.text('NA VAN (1)'), findsOneWidget);
    expect(find.text('1 de 2 na van'), findsOneWidget);
    expect(find.byIcon(Icons.check_circle), findsOneWidget);
    expect(find.text('Embarcou'), findsOneWidget);
  });

  testWidgets('todos embarcados: mostra o aviso', (tester) async {
    await abrirTela(tester, RemotoFalso(alunos: [aluno(1, 'Ana Souza', embarcado: true)]));

    expect(find.text('Todos os alunos embarcaram'), findsOneWidget);
    expect(find.text('PRÓXIMA PARADA'), findsNothing);
  });

  testWidgets('lista vazia: mostra a mensagem', (tester) async {
    await abrirTela(tester, RemotoFalso());

    expect(find.text('Nenhum aluno confirmado para esta rota.'), findsOneWidget);
  });

  testWidgets('403: mostra que não é o motorista ativo, sem lista (RN-012)', (tester) async {
    await abrirTela(
      tester,
      RemotoFalso(erro: const EnvioRecusadoException(403, 'Você não é o motorista ativo desta van.')),
    );

    expect(find.text('Você não é o motorista ativo desta van.'), findsOneWidget);
    expect(find.text('PRÓXIMA PARADA'), findsNothing);
    expect(find.text('Tentar de novo'), findsNothing);
  });

  testWidgets('sem conexão: mostra erro e botão para tentar de novo', (tester) async {
    await abrirTela(tester, RemotoFalso(erro: const SemConexaoException()));

    expect(find.text('Não foi possível carregar a rota. Tente de novo.'), findsOneWidget);
    expect(find.text('Tentar de novo'), findsOneWidget);
  });
}
