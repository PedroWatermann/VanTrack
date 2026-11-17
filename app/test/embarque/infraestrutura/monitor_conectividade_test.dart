import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart';

import 'package:app/embarque/dominio/excecoes.dart';
import 'package:app/embarque/infraestrutura/monitor_conectividade.dart';

class _ConnectivityMock extends Mock implements Connectivity {}

void main() {
  late _ConnectivityMock connectivity;
  late StreamController<List<ConnectivityResult>> fluxoRede;
  late MonitorConectividade monitor;

  setUp(() {
    connectivity = _ConnectivityMock();
    fluxoRede = StreamController<List<ConnectivityResult>>.broadcast();
    when(() => connectivity.onConnectivityChanged)
        .thenAnswer((_) => fluxoRede.stream);
    when(() => connectivity.checkConnectivity())
        .thenAnswer((_) async => [ConnectivityResult.wifi]);
    monitor = MonitorConectividade(connectivity: connectivity);
  });

  tearDown(() async {
    await monitor.dispose();
    await fluxoRede.close();
  });

  test('detecta modo avião no Android (none) e retorno do sinal', () async {
    final mudancas = <bool>[];
    final inscricao = monitor.aoMudar.listen(mudancas.add);
    addTearDown(inscricao.cancel);

    expect(monitor.estaOnline, isTrue);
    expect(monitor.online.value, isTrue);

    fluxoRede.add([ConnectivityResult.none]);
    await pumpEventQueue();

    expect(monitor.estaOnline, isFalse);
    expect(monitor.online.value, isFalse);

    fluxoRede.add([ConnectivityResult.mobile]);
    await pumpEventQueue();

    expect(monitor.estaOnline, isTrue);
    expect(monitor.online.value, isTrue);
    expect(mudancas, [false, true]);
  });

  test('verifica conectividade inicial por checkConnectivity', () async {
    when(() => connectivity.checkConnectivity())
        .thenAnswer((_) async => [ConnectivityResult.none]);

    final resultado = await monitor.verificarConectividade();

    expect(resultado, isFalse);
    expect(monitor.online.value, isFalse);
  });

  test('na Web, falha de rede na chamada muda estado para offline', () async {
    final mudancas = <bool>[];
    final inscricao = monitor.aoMudar.listen(mudancas.add);
    addTearDown(inscricao.cancel);

    await expectLater(
      monitor.monitorarChamada<void>(
        () async => throw http.ClientException('Failed to fetch'),
      ),
      throwsA(isA<SemConexaoException>()),
    );

    expect(monitor.estaOnline, isFalse);
    expect(monitor.online.value, isFalse);

    // Quando uma chamada posterior passa a responder, volta para online.
    await monitor.monitorarChamada<void>(() async {});
    await pumpEventQueue();

    expect(monitor.estaOnline, isTrue);
    expect(monitor.online.value, isTrue);
    expect(mudancas, [false, true]);
  });

  test('timeout na chamada conta como offline e lança SemConexaoException',
      () async {
    final mudancas = <bool>[];
    final inscricao = monitor.aoMudar.listen(mudancas.add);
    addTearDown(inscricao.cancel);

    await expectLater(
      monitor.monitorarChamada<void>(
        () => Completer<void>().future,
        limite: const Duration(milliseconds: 20),
      ),
      throwsA(isA<SemConexaoException>()),
    );
    await pumpEventQueue();

    expect(monitor.estaOnline, isFalse);
    expect(monitor.online.value, isFalse);
    expect(mudancas, [false]);
  });

  test('recusa do servidor (403/404/409) confirma conexão e repassa erro',
      () async {
    monitor.registrarFalhaDeRede();
    expect(monitor.estaOnline, isFalse);

    await expectLater(
      monitor.monitorarChamada<void>(
        () async => throw const EnvioRecusadoException(409, 'Já embarcou'),
      ),
      throwsA(
        isA<EnvioRecusadoException>()
            .having((e) => e.codigoHttp, 'codigoHttp', 409),
      ),
    );

    expect(monitor.estaOnline, isTrue);
    expect(monitor.online.value, isTrue);
  });

  test('não emite eventos repetidos quando o estado não muda', () async {
    final mudancas = <bool>[];
    final inscricao = monitor.aoMudar.listen(mudancas.add);
    addTearDown(inscricao.cancel);

    fluxoRede.add([ConnectivityResult.wifi]);
    await pumpEventQueue();
    monitor.registrarSucessoDeRede();

    fluxoRede.add([ConnectivityResult.none]);
    await pumpEventQueue();
    monitor.registrarFalhaDeRede();
    fluxoRede.add([]);
    await pumpEventQueue();

    expect(mudancas, [false]);
  });
}
