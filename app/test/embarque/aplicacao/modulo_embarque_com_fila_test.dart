import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:app/compartilhado/api_client.dart';
import 'package:app/compartilhado/sessao.dart';
import 'package:app/embarque/aplicacao/modulo_embarque.dart';
import 'package:app/embarque/aplicacao/modulo_embarque_com_fila.dart';
import 'package:app/embarque/dominio/aluno_da_rota.dart';
import 'package:app/embarque/dominio/conectividade.dart';
import 'package:app/embarque/dominio/embarque_remoto.dart';
import 'package:app/embarque/dominio/excecoes.dart';
import 'package:app/embarque/dominio/fila_embarques.dart';
import 'package:app/embarque/dominio/localizacao.dart';
import 'package:app/embarque/dominio/localizador.dart';
import 'package:app/embarque/dominio/registro_embarque.dart';
import 'package:app/embarque/dominio/rota_do_dia.dart';
import 'package:app/embarque/infraestrutura/armazenamento_local.dart';
import 'package:app/embarque/infraestrutura/embarque_api.dart';

class _LocalizadorFalso implements Localizador {
  _LocalizadorFalso([this.resposta]);

  final Localizacao? resposta;
  Duration? limitePedido;

  @override
  Future<Localizacao?> obterLocalizacao(Duration limite) async {
    limitePedido = limite;
    return resposta;
  }
}

class _FilaEmMemoria implements FilaEmbarques {
  _FilaEmMemoria([List<RegistroEmbarque>? iniciais]) {
    if (iniciais != null) itens.addAll(iniciais);
  }

  final List<RegistroEmbarque> itens = [];

  @override
  Future<void> guardar(RegistroEmbarque registro) async {
    if (!itens.any((r) => r.registroId == registro.registroId)) {
      itens.add(registro);
    }
  }

  @override
  Future<List<RegistroEmbarque>> listar(int rotaId) async =>
      [for (final item in itens) if (item.rotaId == rotaId) item];

  @override
  Future<void> remover(Set<String> registroIds) async {
    itens.removeWhere((item) => registroIds.contains(item.registroId));
  }
}

class _ConectividadeFalsa implements Conectividade {
  _ConectividadeFalsa({bool inicialOnline = true}) : _online = inicialOnline;

  bool _online;
  final StreamController<bool> _controlador =
      StreamController<bool>.broadcast();
  int falhasRegistradas = 0;
  int sucessosRegistrados = 0;

  @override
  bool get estaOnline => _online;

  @override
  Stream<bool> get aoMudar => _controlador.stream;

  void simularMudanca(bool online) {
    _online = online;
    _controlador.add(online);
  }

  @override
  void registrarFalhaDeRede() {
    falhasRegistradas++;
    _online = false;
  }

  @override
  void registrarSucessoDeRede() {
    sucessosRegistrados++;
    _online = true;
  }

  Future<void> dispose() => _controlador.close();
}

class _RemotoFalso implements EmbarqueRemoto {
  _RemotoFalso({
    this.erroAoEnviar,
    this.erroAoSincronizar,
    this.aoSincronizar,
  });

  Object? erroAoEnviar;
  Object? erroAoSincronizar;
  Future<Map<String, int>> Function(int rotaId, List<RegistroEmbarque>)?
      aoSincronizar;

  final List<RegistroEmbarque> enviados = [];
  final List<List<RegistroEmbarque>> lotesSincronizados = [];

  @override
  Future<void> enviar(RegistroEmbarque registro) async {
    final erro = erroAoEnviar;
    if (erro != null) throw erro;
    enviados.add(registro);
  }

  @override
  Future<Map<String, int>> sincronizar(
    int rotaId,
    List<RegistroEmbarque> registros,
  ) async {
    lotesSincronizados.add(List.of(registros));
    final erro = erroAoSincronizar;
    if (erro != null) throw erro;
    final manipulador = aoSincronizar;
    if (manipulador != null) {
      return manipulador(rotaId, registros);
    }
    return {for (final r in registros) r.registroId: 201};
  }

  @override
  Future<RotaDoDia> buscarRotaDoDia() => throw UnimplementedError();

  @override
  Future<List<AlunoDaRota>> listarAlunos(int rotaId) =>
      throw UnimplementedError();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _RemotoFalso remoto;
  late _FilaEmMemoria fila;
  late _ConectividadeFalsa conectividade;
  late _LocalizadorFalso localizador;

  ModuloEmbarqueComFila criarModulo({
    bool online = true,
    Localizacao? localizacao = const Localizacao(-23.4205, -51.9331),
    Object? erroAoEnviar,
    Object? erroAoSincronizar,
    Future<Map<String, int>> Function(int, List<RegistroEmbarque>)?
        aoSincronizar,
    List<RegistroEmbarque>? iniciaisNaFila,
    Duration intervaloSincronizacao = const Duration(seconds: 30),
  }) {
    remoto = _RemotoFalso(
      erroAoEnviar: erroAoEnviar,
      erroAoSincronizar: erroAoSincronizar,
      aoSincronizar: aoSincronizar,
    );
    fila = _FilaEmMemoria(iniciaisNaFila);
    conectividade = _ConectividadeFalsa(inicialOnline: online);
    localizador = _LocalizadorFalso(localizacao);
    final criado = ModuloEmbarqueComFila(
      remoto: remoto,
      fila: fila,
      conectividade: conectividade,
      localizador: localizador,
      intervaloSincronizacao: intervaloSincronizacao,
    );
    final conn = conectividade;
    addTearDown(() async {
      await criado.dispose();
      await conn.dispose();
    });
    return criado;
  }

  test(
      'online: envia com hora e localização do toque (limite 2 s) e não guarda na fila',
      () async {
    final m = criarModulo(
      online: true,
      localizacao: const Localizacao(-23.42, -51.93),
    );
    final antes = DateTime.now();

    final resultado = await m.registrarEmbarque(1, 2);

    expect(resultado.status, StatusEnvio.enviado);
    expect(resultado.alunoId, 2);
    expect(resultado.registroId, isNotEmpty);
    expect(resultado.dataHora.isBefore(antes), isFalse);
    expect(localizador.limitePedido, const Duration(seconds: 2));

    expect(remoto.enviados, hasLength(1));
    expect(remoto.enviados.first.registroId, resultado.registroId);
    expect(remoto.enviados.first.rotaId, 1);
    expect(remoto.enviados.first.alunoId, 2);
    expect(remoto.enviados.first.dataHora, resultado.dataHora);
    expect(remoto.enviados.first.localizacao?.latitude, -23.42);
    expect(remoto.enviados.first.localizacao?.longitude, -51.93);
    expect(fila.itens, isEmpty);
    expect(conectividade.sucessosRegistrados, 1);
  });

  test(
      'offline: não chama servidor, guarda na fila com hora/localização do toque e devolve pendente',
      () async {
    final m = criarModulo(
      online: false,
      localizacao: const Localizacao(-23.4231, -51.9387),
    );
    final antes = DateTime.now();

    final resultado = await m.registrarEmbarque(1, 3);

    expect(resultado.status, StatusEnvio.pendente);
    expect(resultado.alunoId, 3);
    expect(resultado.dataHora.isBefore(antes), isFalse);
    expect(localizador.limitePedido, const Duration(seconds: 2));

    expect(remoto.enviados, isEmpty);
    expect(fila.itens, hasLength(1));
    expect(fila.itens.first.registroId, resultado.registroId);
    expect(fila.itens.first.dataHora, resultado.dataHora);
    expect(fila.itens.first.localizacao?.latitude, -23.4231);
    expect(fila.itens.first.localizacao?.longitude, -51.9387);
  });

  test(
      'falha de rede no envio (SemConexaoException): marca offline, guarda na fila e devolve pendente',
      () async {
    final m = criarModulo(
      online: true,
      localizacao: const Localizacao(-23.4262, -51.9410),
      erroAoEnviar: const SemConexaoException(),
    );

    final resultado = await m.registrarEmbarque(1, 1);

    expect(resultado.status, StatusEnvio.pendente);
    expect(conectividade.falhasRegistradas, 1);
    expect(conectividade.estaOnline, isFalse);
    expect(fila.itens, hasLength(1));
    expect(fila.itens.first.registroId, resultado.registroId);
    expect(fila.itens.first.dataHora, resultado.dataHora);
    expect(fila.itens.first.localizacao?.latitude, -23.4262);
  });

  test(
      'recusa do servidor (403, 404, 409): lança EmbarqueException e nunca guarda na fila',
      () async {
    for (final codigo in [403, 404, 409]) {
      final m = criarModulo(
        online: true,
        erroAoEnviar: EnvioRecusadoException(codigo, 'Erro $codigo'),
      );

      await expectLater(
        m.registrarEmbarque(1, 1),
        throwsA(
          isA<EmbarqueException>()
              .having((e) => e.codigoHttp, 'codigoHttp', codigo)
              .having((e) => e.mensagem, 'mensagem', 'Erro $codigo'),
        ),
      );
      expect(fila.itens, isEmpty);
      expect(conectividade.sucessosRegistrados, 1);
    }
  });

  test('listarPendentes retorna os pendentes da rota solicitada', () async {
    final m = criarModulo(online: false, localizacao: null);

    final primeiro = await m.registrarEmbarque(1, 1);
    await m.registrarEmbarque(2, 2);
    final segundo = await m.registrarEmbarque(1, 3);

    final pendentesRota1 = await m.listarPendentes(1);

    expect(pendentesRota1, hasLength(2));
    expect(pendentesRota1[0].registroId, primeiro.registroId);
    expect(pendentesRota1[0].alunoId, 1);
    expect(pendentesRota1[0].dataHora, primeiro.dataHora);
    expect(pendentesRota1[1].registroId, segundo.registroId);
    expect(pendentesRota1[1].alunoId, 3);
    expect(pendentesRota1[1].dataHora, segundo.dataHora);
  });

  test(
      'ao reconectar: sincroniza em lote, remove confirmados (201/200) e avisa aoMudarPendentes',
      () async {
    final m = criarModulo(
      online: false,
      aoSincronizar: (_, registros) async => {
        registros[0].registroId: 201,
        registros[1].registroId: 200,
      },
    );
    final eventos = <EventoPendente>[];
    final inscricao = m.aoMudarPendentes.listen(eventos.add);
    addTearDown(inscricao.cancel);

    final r1 = await m.registrarEmbarque(1, 1);
    final r2 = await m.registrarEmbarque(1, 2);
    expect(fila.itens, hasLength(2));

    conectividade.simularMudanca(true);
    await pumpEventQueue();

    expect(remoto.lotesSincronizados, hasLength(1));
    expect(remoto.lotesSincronizados.first.map((r) => r.registroId), [
      r1.registroId,
      r2.registroId,
    ]);
    expect(fila.itens, isEmpty);
    expect(eventos, hasLength(2));
    expect(eventos[0].registroId, r1.registroId);
    expect(eventos[0].alunoId, 1);
    expect(eventos[0].sincronizado, isTrue);
    expect(eventos[0].codigoHttp, isNull);
    expect(eventos[1].registroId, r2.registroId);
    expect(eventos[1].alunoId, 2);
    expect(eventos[1].sincronizado, isTrue);
  });

  test(
      'na sincronização, registro rejeitado (409) sai da fila e emite EventoPendente com código HTTP',
      () async {
    final m = criarModulo(
      online: false,
      aoSincronizar: (_, registros) async => {
        registros[0].registroId: 201,
        registros[1].registroId: 409,
        // Sem código retornado para o terceiro (ex.: erro parcial): fica na fila.
      },
    );
    final eventos = <EventoPendente>[];
    final inscricao = m.aoMudarPendentes.listen(eventos.add);
    addTearDown(inscricao.cancel);

    final ok = await m.registrarEmbarque(1, 1);
    final rejeitado = await m.registrarEmbarque(1, 2);
    final naoConfirmado = await m.registrarEmbarque(1, 3);

    conectividade.simularMudanca(true);
    await pumpEventQueue();

    expect(fila.itens.map((r) => r.registroId), [naoConfirmado.registroId]);
    expect(eventos, hasLength(2));
    expect(eventos[0].registroId, ok.registroId);
    expect(eventos[0].sincronizado, isTrue);
    expect(eventos[1].registroId, rejeitado.registroId);
    expect(eventos[1].alunoId, 2);
    expect(eventos[1].sincronizado, isFalse);
    expect(eventos[1].codigoHttp, 409);
  });

  test(
      'falha de rede na sincronização não perde nem duplica registros e marca offline',
      () async {
    final m = criarModulo(
      online: false,
      erroAoSincronizar: const SemConexaoException(),
    );

    final r1 = await m.registrarEmbarque(1, 1);
    final r2 = await m.registrarEmbarque(1, 2);

    conectividade.simularMudanca(true);
    await pumpEventQueue();

    expect(conectividade.estaOnline, isFalse);
    expect(fila.itens.map((r) => r.registroId), [r1.registroId, r2.registroId]);

    // Na tentativa seguinte sem falha, envia os mesmos registros sem duplicar.
    remoto.erroAoSincronizar = null;
    conectividade.simularMudanca(true);
    await pumpEventQueue();

    expect(fila.itens, isEmpty);
    expect(remoto.lotesSincronizados, hasLength(2));
  });

  test('não executa duas sincronizações simultâneas', () async {
    final bloqueador = Completer<Map<String, int>>();
    var chamadas = 0;

    final m = criarModulo(
      online: false,
      aoSincronizar: (_, _) {
        chamadas++;
        return bloqueador.future;
      },
    );

    final r1 = await m.registrarEmbarque(1, 1);
    conectividade.simularMudanca(true);
    await pumpEventQueue();

    expect(m.sincronizando, isTrue);
    expect(chamadas, 1);

    // Segunda chamada enquanto a primeira ainda está em voo é ignorada.
    await m.sincronizar();
    expect(chamadas, 1);

    bloqueador.complete({r1.registroId: 201});
    await pumpEventQueue();

    expect(m.sincronizando, isFalse);
    expect(fila.itens, isEmpty);
  });

  test('tenta sincronizar ao abrir o app quando há pendentes na fila',
      () async {
    final pendenteInicial = RegistroEmbarque(
      registroId: 'inicial-1',
      rotaId: 1,
      alunoId: 1,
      dataHora: DateTime.parse('2026-11-16T06:40:00-03:00'),
    );

    criarModulo(
      online: true,
      iniciaisNaFila: [pendenteInicial],
    );
    await pumpEventQueue();

    expect(remoto.lotesSincronizados, hasLength(1));
    expect(remoto.lotesSincronizados.first.first.registroId, 'inicial-1');
    expect(fila.itens, isEmpty);
  });

  test('tenta sincronizar periodicamente pelo timer', () async {
    final mTimer = criarModulo(
      online: false,
      intervaloSincronizacao: const Duration(milliseconds: 25),
    );
    final pendenteTimer = await mTimer.registrarEmbarque(1, 2);
    expect(fila.itens, hasLength(1));

    // Muda para online sem disparar evento no stream (simula polling periódico).
    conectividade.registrarSucessoDeRede();
    await Future<void>.delayed(const Duration(milliseconds: 60));
    await pumpEventQueue();

    expect(remoto.lotesSincronizados, hasLength(1));
    expect(
      remoto.lotesSincronizados.first.first.registroId,
      pendenteTimer.registroId,
    );
    expect(fila.itens, isEmpty);
  });

  group(
    'Integração offline (MockClient + SharedPreferences + ModuloEmbarqueComFila)',
    () {
      late _ConectividadeFalsa connIntegrada;

      setUp(() {
        SharedPreferences.setMockInitialValues({});
      });

      ModuloEmbarqueComFila criarIntegrado({
        required bool online,
        required MockClient mockClient,
        Localizacao? localizacao = const Localizacao(-23.4205, -51.9331),
      }) {
        final sessao = Sessao()
          ..entrar(
            const UsuarioLogado(
              id: 1,
              nome: 'Marcos Pereira',
              papel: Papel.motorista,
            ),
            'token-teste',
          );
        final api = ApiClient(
          sessao: sessao,
          usarMock: false,
          cliente: mockClient,
        );
        final conn = _ConectividadeFalsa(inicialOnline: online);
        connIntegrada = conn;

        final criado = ModuloEmbarqueComFila(
          remoto: EmbarqueApi(api),
          fila: ArmazenamentoLocal(),
          conectividade: conn,
          localizador: _LocalizadorFalso(localizacao),
        );
        addTearDown(() async {
          await criado.dispose();
          await conn.dispose();
        });
        return criado;
      }

      test(
          'toque online envia POST /rotas/1/embarques via MockClient e deixa SharedPreferences vazio',
          () async {
        Map<String, dynamic>? corpoEnviado;
        String? caminhoChamado;

        final mockClient = MockClient((req) async {
          caminhoChamado = req.url.path;
          corpoEnviado = jsonDecode(req.body) as Map<String, dynamic>;
          return http.Response(
            jsonEncode({'alunoId': 1, 'status': 'EMBARCADO'}),
            201,
          );
        });

        final m = criarIntegrado(
          online: true,
          mockClient: mockClient,
          localizacao: const Localizacao(-23.4205, -51.9331),
        );

        final resultado = await m.registrarEmbarque(1, 1);

        expect(resultado.status, StatusEnvio.enviado);
        expect(caminhoChamado, endsWith('/rotas/1/embarques'));
        expect(corpoEnviado?['registroId'], resultado.registroId);
        expect(corpoEnviado?['alunoId'], 1);
        expect(
          DateTime.parse(corpoEnviado?['dataHora'] as String)
              .isAtSameMomentAs(resultado.dataHora),
          isTrue,
        );
        expect(corpoEnviado?['latitude'], -23.4205);
        expect(corpoEnviado?['longitude'], -51.9331);
        expect(await ArmazenamentoLocal().listar(1), isEmpty);
      });

      test(
          'falha de rede ou timeout no MockClient grava no SharedPreferences e sobrevive ao reabrir o app',
          () async {
        var modoErro = 'rede';
        final mockClient = MockClient((_) async {
          if (modoErro == 'rede') {
            throw http.ClientException('Sem internet');
          }
          throw TimeoutException('Tempo esgotado');
        });

        final sessao1 = criarIntegrado(
          online: true,
          mockClient: mockClient,
          localizacao: const Localizacao(-23.4231, -51.9387),
        );

        final r1 = await sessao1.registrarEmbarque(1, 1);
        expect(r1.status, StatusEnvio.pendente);
        expect(connIntegrada.estaOnline, isFalse);

        // Volta a tentar com timeout no MockClient (simulando queda silenciosa).
        connIntegrada.registrarSucessoDeRede();
        modoErro = 'timeout';
        final r2 = await sessao1.registrarEmbarque(1, 2);
        expect(r2.status, StatusEnvio.pendente);
        expect(connIntegrada.estaOnline, isFalse);

        // Simula fechar e reabrir o app: nova instância lê do SharedPreferences.
        final sessao2 = criarIntegrado(
          online: false,
          mockClient: mockClient,
        );
        final pendentes = await sessao2.listarPendentes(1);

        expect(pendentes.map((p) => p.registroId), [r1.registroId, r2.registroId]);
        final persistidos = await ArmazenamentoLocal().listar(1);
        expect(persistidos, hasLength(2));
        expect(persistidos[0].localizacao?.latitude, -23.4231);
        expect(persistidos[0].localizacao?.longitude, -51.9387);
      });

      test(
          'recusa 403, 404 ou 409 do MockClient lança EmbarqueException e nunca grava no SharedPreferences',
          () async {
        for (final codigo in [403, 404, 409]) {
          SharedPreferences.setMockInitialValues({});
          final mockClient = MockClient(
            (_) async => http.Response(
              jsonEncode({'erro': 'Recusa $codigo'}),
              codigo,
            ),
          );
          final m = criarIntegrado(online: true, mockClient: mockClient);

          await expectLater(
            m.registrarEmbarque(1, 1),
            throwsA(
              isA<EmbarqueException>()
                  .having((e) => e.codigoHttp, 'codigoHttp', codigo)
                  .having((e) => e.mensagem, 'mensagem', 'Recusa $codigo'),
            ),
          );
          expect(await ArmazenamentoLocal().listar(1), isEmpty);
        }
      });

      test(
          'ao reconectar, envia lote no MockClient, remove 201/409 do SharedPreferences e mantém fila em falha parcial',
          () async {
        var falharRede = true;
        final lotesRecebidos = <List<Map<String, dynamic>>>[];

        final mockClient = MockClient((req) async {
          if (falharRede) {
            throw http.ClientException('Conexão caiu no meio');
          }
          expect(req.url.path, endsWith('/rotas/1/embarques/sincronizar'));
          final corpo = jsonDecode(req.body) as Map<String, dynamic>;
          final registros =
              (corpo['registros'] as List).cast<Map<String, dynamic>>();
          lotesRecebidos.add(registros);

          return http.Response(
            jsonEncode({
              'resultados': [
                {'registroId': registros[0]['registroId'], 'codigo': 201},
                {'registroId': registros[1]['registroId'], 'codigo': 409},
                {'registroId': registros[2]['registroId'], 'codigo': 500},
              ],
            }),
            200,
          );
        });

        final m = criarIntegrado(online: false, mockClient: mockClient);
        final eventos = <EventoPendente>[];
        final inscricao = m.aoMudarPendentes.listen(eventos.add);
        addTearDown(inscricao.cancel);

        final r1 = await m.registrarEmbarque(1, 1);
        final r2 = await m.registrarEmbarque(1, 2);
        final r3 = await m.registrarEmbarque(1, 3);

        // Falha no meio ao reconectar: não perde ninguém do SharedPreferences.
        connIntegrada.simularMudanca(true);
        await pumpEventQueue();
        expect(connIntegrada.estaOnline, isFalse);
        expect(
          (await ArmazenamentoLocal().listar(1)).map((r) => r.registroId),
          [r1.registroId, r2.registroId, r3.registroId],
        );

        // Agora o servidor responde: remove 201 e 409, mantém 500 na fila.
        falharRede = false;
        connIntegrada.simularMudanca(true);
        await pumpEventQueue();

        expect(lotesRecebidos, hasLength(1));
        expect(lotesRecebidos.first, hasLength(3));
        expect(
          (await ArmazenamentoLocal().listar(1)).map((r) => r.registroId),
          [r3.registroId],
        );
        expect(eventos, hasLength(2));
        expect(eventos[0].registroId, r1.registroId);
        expect(eventos[0].sincronizado, isTrue);
        expect(eventos[1].registroId, r2.registroId);
        expect(eventos[1].sincronizado, isFalse);
        expect(eventos[1].codigoHttp, 409);
      });

      test(
          'idempotência: mesmo registroId reenviado recebe 200 e sai do SharedPreferences sem duplicar',
          () async {
        final processados = <String>{};
        final totalGravacoes = <String, int>{};

        final mockClient = MockClient((req) async {
          final corpo = jsonDecode(req.body) as Map<String, dynamic>;
          final registros =
              (corpo['registros'] as List).cast<Map<String, dynamic>>();
          final resultados = <Map<String, dynamic>>[];

          for (final r in registros) {
            final id = r['registroId'] as String;
            if (processados.contains(id)) {
              resultados.add({'registroId': id, 'codigo': 200});
            } else {
              processados.add(id);
              totalGravacoes[id] = (totalGravacoes[id] ?? 0) + 1;
              resultados.add({'registroId': id, 'codigo': 201});
            }
          }
          return http.Response(
            jsonEncode({'resultados': resultados}),
            200,
          );
        });

        final m = criarIntegrado(online: false, mockClient: mockClient);
        final eventos = <EventoPendente>[];
        final inscricao = m.aoMudarPendentes.listen(eventos.add);
        addTearDown(inscricao.cancel);

        final pendente = await m.registrarEmbarque(1, 1);
        // Simula que o servidor já havia recebido esse registro antes da queda.
        processados.add(pendente.registroId);
        totalGravacoes[pendente.registroId] = 1;

        connIntegrada.simularMudanca(true);
        await pumpEventQueue();

        expect(totalGravacoes[pendente.registroId], 1);
        expect(await ArmazenamentoLocal().listar(1), isEmpty);
        expect(eventos, hasLength(1));
        expect(eventos.first.registroId, pendente.registroId);
        expect(eventos.first.sincronizado, isTrue);
      });
    },
  );
}
