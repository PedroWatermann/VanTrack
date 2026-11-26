import 'dart:async';
import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:app/compartilhado/api_client.dart';
import 'package:app/compartilhado/sessao.dart';
import 'package:app/embarque/aplicacao/modulo_embarque.dart';
import 'package:app/embarque/aplicacao/modulo_embarque_com_fila.dart';
import 'package:app/embarque/dominio/localizacao.dart';
import 'package:app/embarque/dominio/localizador.dart';
import 'package:app/embarque/infraestrutura/armazenamento_local.dart';
import 'package:app/embarque/infraestrutura/embarque_api.dart';
import 'package:app/embarque/infraestrutura/monitor_conectividade.dart';

class _ConnectivityMock extends Mock implements Connectivity {}

class _SemGps implements Localizador {
  @override
  Future<Localizacao?> obterLocalizacao(Duration limite) async => null;
}

/// Bug VT-77 (teste 10): na Web, com a rede do aparelho normal, o servidor cai
/// e volta. O `connectivity_plus` não avisa nada; quem tem que perceber a volta
/// é a tentativa periódica de sincronização.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const intervalo = Duration(milliseconds: 40);

  late bool servidorNoAr;
  late List<String> caminhos;
  late MonitorConectividade monitor;
  late ModuloEmbarqueComFila modulo;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    servidorNoAr = false;
    caminhos = [];

    // A rede do aparelho está sempre "wifi" e nunca muda: nenhum evento.
    final connectivity = _ConnectivityMock();
    when(() => connectivity.onConnectivityChanged)
        .thenAnswer((_) => const Stream.empty());
    when(() => connectivity.checkConnectivity())
        .thenAnswer((_) async => [ConnectivityResult.wifi]);
    monitor = MonitorConectividade(connectivity: connectivity);

    final servidor = MockClient((pedido) async {
      if (!servidorNoAr) throw http.ClientException('servidor fora do ar');
      caminhos.add(pedido.url.path);
      if (!pedido.url.path.endsWith('/sincronizar')) {
        return http.Response(jsonEncode({'status': 'EMBARCADO'}), 201);
      }
      final corpo = jsonDecode(pedido.body) as Map<String, dynamic>;
      return http.Response(
        jsonEncode({
          'resultados': [
            for (final r in (corpo['registros'] as List).cast<Map<String, dynamic>>())
              {'registroId': r['registroId'], 'codigo': 201},
          ],
        }),
        200,
      );
    });
    final sessao = Sessao();
    await sessao.entrar(
      const UsuarioLogado(id: 1, nome: 'João Pereira', papel: Papel.motorista),
      'token-do-joao',
    );

    modulo = ModuloEmbarqueComFila(
      remoto: EmbarqueApi(ApiClient(sessao: sessao, usarMock: false, cliente: servidor)),
      fila: ArmazenamentoLocal(),
      conectividade: monitor,
      localizador: _SemGps(),
      intervaloSincronizacao: intervalo,
    );
  });

  tearDown(() async {
    await modulo.dispose();
    await monitor.dispose();
  });

  Future<void> esperarTentativas([int quantas = 3]) async {
    await Future<void>.delayed(intervalo * quantas);
    await pumpEventQueue();
  }

  test('o servidor volta: a tentativa periódica sincroniza e o app sai do "sem conexão"',
      () async {
    final eventos = <EventoPendente>[];
    final inscricao = modulo.aoMudarPendentes.listen(eventos.add);
    addTearDown(inscricao.cancel);

    // Teste 8: servidor fora do ar, o toque vira pendente e o app fica offline.
    final beatriz = await modulo.registrarEmbarque(1, 2);
    expect(beatriz.status, StatusEnvio.pendente);
    expect(monitor.online.value, isFalse);

    // Enquanto o servidor não volta, nada se perde e o app continua offline.
    await esperarTentativas();
    expect(monitor.online.value, isFalse);
    expect(await ArmazenamentoLocal().listar(1), hasLength(1));

    // Teste 10: o servidor volta, sem nenhum evento de rede.
    servidorNoAr = true;
    await esperarTentativas();

    expect(caminhos, contains('/rotas/1/embarques/sincronizar'));
    expect(await ArmazenamentoLocal().listar(1), isEmpty);
    expect(monitor.online.value, isTrue); // a faixa "Sem conexão" some
    expect(eventos.map((e) => (e.registroId, e.sincronizado)), [(beatriz.registroId, true)]);
  });

  test('depois de voltar, o próximo toque é enviado na hora', () async {
    await modulo.registrarEmbarque(1, 2);
    servidorNoAr = true;
    await esperarTentativas();

    final carlos = await modulo.registrarEmbarque(1, 3);

    expect(carlos.status, StatusEnvio.enviado);
    expect(caminhos.last, '/rotas/1/embarques');
  });

  test('com a fila vazia, as tentativas periódicas não chamam o servidor', () async {
    servidorNoAr = true;
    await esperarTentativas();

    expect(caminhos, isEmpty);
  });
}
