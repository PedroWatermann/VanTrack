import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:app/embarque/aplicacao/modulo_embarque.dart';
import 'package:app/embarque/aplicacao/rota_do_dia_service.dart';
import 'package:app/embarque/apresentacao/faixa_sem_conexao.dart';
import 'package:app/embarque/apresentacao/tela_rota_do_dia.dart';
import 'package:app/embarque/dominio/aluno_da_rota.dart';
import 'package:app/embarque/dominio/embarque_remoto.dart';
import 'package:app/embarque/dominio/registro_embarque.dart';
import 'package:app/embarque/dominio/rota_do_dia.dart';

class _RemotoFalso implements EmbarqueRemoto {
  @override
  Future<RotaDoDia> buscarRotaDoDia() async => RotaDoDia(
        rotaId: 1,
        trajeto: 'IDA',
        horarioPrevisto: DateTime.parse('2026-11-16T06:30:00-03:00'),
        placa: 'ABC-1D23',
      );

  @override
  Future<List<AlunoDaRota>> listarAlunos(int rotaId) async => [
        const AlunoDaRota(
          alunoId: 1,
          nome: 'Ana Souza',
          ordem: 1,
          endereco: 'Av. Brasil, 1500',
          embarcado: false,
        ),
      ];

  @override
  Future<void> enviar(RegistroEmbarque registro) async {}

  @override
  Future<Map<String, int>> sincronizar(
    int rotaId,
    List<RegistroEmbarque> registros,
  ) async =>
      {};
}

class _ModuloFalso implements ModuloEmbarque {
  @override
  Future<ResultadoEmbarque> registrarEmbarque(int rotaId, int alunoId) async =>
      ResultadoEmbarque('r', alunoId, DateTime.now(), StatusEnvio.enviado);

  @override
  Future<List<RegistroPendente>> listarPendentes(int rotaId) async => const [];

  @override
  Stream<EventoPendente> get aoMudarPendentes => const Stream.empty();
}

void main() {
  testWidgets(
      'FaixaSemConexao reage ao ValueNotifier<bool> de conectividade na TelaRotaDoDia',
      (tester) async {
    final online = ValueNotifier<bool>(true);
    addTearDown(online.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: TelaRotaDoDia(
          modulo: _ModuloFalso(),
          rotaDoDiaService: RotaDoDiaService(_RemotoFalso()),
          online: online,
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Online: faixa escondida.
    expect(find.byType(FaixaSemConexao), findsOneWidget);
    expect(
      find.text('Sem conexão. Os embarques serão enviados quando o sinal voltar.'),
      findsNothing,
    );
    expect(find.byIcon(Icons.wifi_off), findsNothing);

    // Sem conexão: faixa âmbar visível.
    online.value = false;
    await tester.pump();

    expect(
      find.text('Sem conexão. Os embarques serão enviados quando o sinal voltar.'),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.wifi_off), findsOneWidget);

    // Conexão volta: faixa volta a ficar oculta.
    online.value = true;
    await tester.pump();

    expect(
      find.text('Sem conexão. Os embarques serão enviados quando o sinal voltar.'),
      findsNothing,
    );
    expect(find.byIcon(Icons.wifi_off), findsNothing);
  });
}
