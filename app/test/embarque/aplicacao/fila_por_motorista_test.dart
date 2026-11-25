import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:app/embarque/aplicacao/modulo_embarque.dart';
import 'package:app/embarque/aplicacao/modulo_embarque_com_fila.dart';
import 'package:app/embarque/dominio/aluno_da_rota.dart';
import 'package:app/embarque/dominio/conectividade.dart';
import 'package:app/embarque/dominio/embarque_remoto.dart';
import 'package:app/embarque/dominio/excecoes.dart';
import 'package:app/embarque/dominio/localizacao.dart';
import 'package:app/embarque/dominio/localizador.dart';
import 'package:app/embarque/dominio/registro_embarque.dart';
import 'package:app/embarque/dominio/rota_do_dia.dart';
import 'package:app/embarque/infraestrutura/armazenamento_local.dart';

class _SemGps implements Localizador {
  @override
  Future<Localizacao?> obterLocalizacao(Duration limite) async => null;
}

class _Conectividade implements Conectividade {
  bool online = true;

  @override
  bool get estaOnline => online;

  @override
  Stream<bool> get aoMudar => const Stream.empty();

  @override
  void registrarFalhaDeRede() => online = false;

  @override
  void registrarSucessoDeRede() => online = true;
}

/// Servidor falso. Sem conexão, o envio falha; na sincronização, responde o
/// código que [codigo] der para cada registro (201 por padrão).
class _Servidor implements EmbarqueRemoto {
  bool noAr = false;
  int Function(RegistroEmbarque) codigo = (_) => 201;
  final lotes = <List<RegistroEmbarque>>[];

  @override
  Future<void> enviar(RegistroEmbarque registro) async {
    if (!noAr) throw const SemConexaoException();
  }

  @override
  Future<Map<String, int>> sincronizar(int rotaId, List<RegistroEmbarque> registros) async {
    if (!noAr) throw const SemConexaoException();
    lotes.add(List.of(registros));
    return {for (final r in registros) r.registroId: codigo(r)};
  }

  @override
  Future<RotaDoDia> buscarRotaDoDia() => throw UnimplementedError();

  @override
  Future<List<AlunoDaRota>> listarAlunos(int rotaId) => throw UnimplementedError();
}

/// Bug VT-76: a fila offline é do aparelho, mas cada embarque é de quem o
/// registrou; um 401/403 nunca apaga um embarque pendente.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const joao = 1;
  const marcos = 2;

  late _Servidor servidor;
  late _Conectividade conectividade;
  late ModuloEmbarqueComFila modulo;
  int? logado;
  late List<EventoPendente> eventos;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    servidor = _Servidor();
    conectividade = _Conectividade();
    logado = joao;
    eventos = [];
    modulo = ModuloEmbarqueComFila(
      remoto: servidor,
      fila: ArmazenamentoLocal(),
      conectividade: conectividade,
      localizador: _SemGps(),
      motoristaLogado: () => logado,
    );
    final inscricao = modulo.aoMudarPendentes.listen(eventos.add);
    addTearDown(() async {
      await inscricao.cancel();
      await modulo.dispose();
    });
    // Deixa terminar a sincronização que o módulo faz ao ser criado.
    await pumpEventQueue();
  });

  /// O que está guardado no aparelho, como o navegador mostraria.
  Future<List<Map<String, dynamic>>> filaGuardada() async {
    final prefs = await SharedPreferences.getInstance();
    final bruto = prefs.getString(ArmazenamentoLocal.chaveFila);
    return bruto == null ? [] : (jsonDecode(bruto) as List).cast<Map<String, dynamic>>();
  }

  test('o embarque pendente guarda o motorista que o registrou', () async {
    await modulo.registrarEmbarque(1, 3);

    final guardados = await filaGuardada();
    expect(guardados.single['motoristaId'], joao);
    expect(guardados.single['alunoId'], 3);
  });

  test('outro motorista no mesmo aparelho não vê nem sincroniza o pendente', () async {
    final carlos = await modulo.registrarEmbarque(1, 3);
    expect(carlos.status, StatusEnvio.pendente);

    // Teste 7 depois do 5: Marcos entra no mesmo navegador.
    logado = marcos;
    servidor.noAr = true;
    await modulo.sincronizar();

    expect(await modulo.listarPendentes(1), isEmpty);
    expect(servidor.lotes, isEmpty);
    expect(await filaGuardada(), hasLength(1));

    // João volta: o pendente reaparece e é enviado com a sessão dele.
    logado = joao;
    expect((await modulo.listarPendentes(1)).single.registroId, carlos.registroId);
    await modulo.sincronizar();

    expect(servidor.lotes.single.single.registroId, carlos.registroId);
    expect(await filaGuardada(), isEmpty);
    expect(eventos.single.sincronizado, isTrue);
  });

  test('sem ninguém logado (tela de login), não sincroniza', () async {
    await modulo.registrarEmbarque(1, 3);

    logado = null;
    servidor.noAr = true;
    await modulo.sincronizar();

    expect(servidor.lotes, isEmpty);
    expect(await filaGuardada(), hasLength(1));
  });

  test('401 e 403 de um registro não o tiram da fila; 409 tira', () async {
    final ana = await modulo.registrarEmbarque(1, 1);
    final beatriz = await modulo.registrarEmbarque(1, 2);
    final carlos = await modulo.registrarEmbarque(1, 3);

    servidor
      ..noAr = true
      ..codigo = (r) => switch (r.alunoId) { 1 => 403, 2 => 401, _ => 409 };
    await modulo.sincronizar();

    expect(
      (await modulo.listarPendentes(1)).map((p) => p.registroId),
      [ana.registroId, beatriz.registroId],
    );
    expect(eventos.map((e) => (e.registroId, e.sincronizado, e.codigoHttp)), [
      (carlos.registroId, false, 409),
    ]);
  });

  test('registro antigo, sem motorista, não se perde com um 403', () async {
    // Fila gravada por uma versão anterior do app, sem o motoristaId.
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      ArmazenamentoLocal.chaveFila,
      jsonEncode([
        {
          'rotaId': 1,
          ...RegistroEmbarque(
            registroId: 'antigo',
            rotaId: 1,
            alunoId: 3,
            dataHora: DateTime.parse('2026-11-24T21:13:00-03:00'),
          ).paraJson(),
        },
      ]),
    );

    logado = marcos;
    servidor
      ..noAr = true
      ..codigo = (_) => 403;
    await modulo.sincronizar();

    expect(servidor.lotes.single.single.registroId, 'antigo');
    expect((await filaGuardada()).single['registroId'], 'antigo');
    expect(eventos, isEmpty);
  });
}
