import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:app/embarque/dominio/localizacao.dart';
import 'package:app/embarque/dominio/registro_embarque.dart';
import 'package:app/embarque/infraestrutura/armazenamento_local.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  RegistroEmbarque registro(
    String registroId, {
    int rotaId = 1,
    int alunoId = 1,
    String dataHoraIso = '2026-11-16T06:42:10-03:00',
    Localizacao? localizacao,
  }) =>
      RegistroEmbarque(
        registroId: registroId,
        rotaId: rotaId,
        alunoId: alunoId,
        dataHora: DateTime.parse(dataHoraIso),
        localizacao: localizacao,
      );

  test('guarda e lista registros na ordem, com e sem localização', () async {
    final fila = ArmazenamentoLocal();
    final primeiro = registro(
      'reg-1',
      alunoId: 1,
      dataHoraIso: '2026-11-16T06:40:00-03:00',
      localizacao: const Localizacao(-23.4205, -51.9331),
    );
    final segundo = registro(
      'reg-2',
      alunoId: 2,
      dataHoraIso: '2026-11-16T06:45:00-03:00',
    );

    await fila.guardar(primeiro);
    await fila.guardar(segundo);

    final pendentes = await fila.listar(1);
    expect(pendentes, hasLength(2));

    expect(pendentes[0].registroId, 'reg-1');
    expect(pendentes[0].rotaId, 1);
    expect(pendentes[0].alunoId, 1);
    expect(pendentes[0].dataHora.isAtSameMomentAs(primeiro.dataHora), isTrue);
    expect(pendentes[0].localizacao?.latitude, -23.4205);
    expect(pendentes[0].localizacao?.longitude, -51.9331);

    expect(pendentes[1].registroId, 'reg-2');
    expect(pendentes[1].rotaId, 1);
    expect(pendentes[1].alunoId, 2);
    expect(pendentes[1].dataHora.isAtSameMomentAs(segundo.dataHora), isTrue);
    expect(pendentes[1].localizacao, isNull);
  });

  test('sobrevive a fechar e reabrir o app', () async {
    final primeiraSessao = ArmazenamentoLocal();
    final item = registro(
      'reg-offline-1',
      alunoId: 3,
      localizacao: const Localizacao(-23.4262, -51.9410),
    );
    await primeiraSessao.guardar(item);

    // Simula reabertura do app criando uma nova instância sem estado em memória.
    final segundaSessao = ArmazenamentoLocal();
    final pendentes = await segundaSessao.listar(1);

    expect(pendentes, hasLength(1));
    expect(pendentes.first.registroId, 'reg-offline-1');
    expect(pendentes.first.alunoId, 3);
    expect(pendentes.first.localizacao?.latitude, -23.4262);
    expect(pendentes.first.localizacao?.longitude, -51.9410);

    // Simula inicialização com valores já persistidos no dispositivo.
    final jsonSalvo = jsonEncode([
      {
        'rotaId': 1,
        'registroId': 'reg-disco-1',
        'alunoId': 2,
        'dataHora': '2026-11-16T09:50:00.000Z',
      },
    ]);
    SharedPreferences.setMockInitialValues({
      ArmazenamentoLocal.chaveFila: jsonSalvo,
    });

    final terceiraSessao = ArmazenamentoLocal();
    final carregadosDoDisco = await terceiraSessao.listar(1);
    expect(carregadosDoDisco, hasLength(1));
    expect(carregadosDoDisco.first.registroId, 'reg-disco-1');
    expect(carregadosDoDisco.first.alunoId, 2);
    expect(carregadosDoDisco.first.localizacao, isNull);
  });

  test('lista apenas os registros da rota solicitada', () async {
    final fila = ArmazenamentoLocal();
    await fila.guardar(registro('reg-r1', rotaId: 1, alunoId: 1));
    await fila.guardar(registro('reg-r2', rotaId: 2, alunoId: 2));
    await fila.guardar(registro('reg-r1-b', rotaId: 1, alunoId: 3));

    final rota1 = await fila.listar(1);
    final rota2 = await fila.listar(2);
    final rotaInexistente = await fila.listar(99);

    expect(rota1.map((r) => r.registroId), ['reg-r1', 'reg-r1-b']);
    expect(rota2.map((r) => r.registroId), ['reg-r2']);
    expect(rotaInexistente, isEmpty);
  });

  test('remove apenas os registroIds informados e mantém os demais', () async {
    final fila = ArmazenamentoLocal();
    await fila.guardar(registro('reg-1', rotaId: 1, alunoId: 1));
    await fila.guardar(registro('reg-2', rotaId: 1, alunoId: 2));
    await fila.guardar(registro('reg-3', rotaId: 2, alunoId: 3));

    await fila.remover({'reg-1'});

    final novaInstancia = ArmazenamentoLocal();
    final restantesRota1 = await novaInstancia.listar(1);
    final restantesRota2 = await novaInstancia.listar(2);

    expect(restantesRota1.map((r) => r.registroId), ['reg-2']);
    expect(restantesRota2.map((r) => r.registroId), ['reg-3']);

    // Remover conjunto vazio ou inexistente não altera os dados.
    await novaInstancia.remover({});
    await novaInstancia.remover({'nao-existe'});
    expect((await novaInstancia.listar(1)).map((r) => r.registroId), ['reg-2']);
  });

  test('não duplica quando o mesmo registroId é guardado duas vezes', () async {
    final fila = ArmazenamentoLocal();
    final item = registro('reg-unico', alunoId: 1);

    await fila.guardar(item);
    await fila.guardar(item);

    final pendentes = await fila.listar(1);
    expect(pendentes, hasLength(1));
    expect(pendentes.first.registroId, 'reg-unico');
  });
}
