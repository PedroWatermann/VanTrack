import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:app/embarque/aplicacao/rota_do_dia_service.dart';
import 'package:app/embarque/dominio/aluno_da_rota.dart';
import 'package:app/embarque/dominio/embarque_remoto.dart';
import 'package:app/embarque/dominio/excecoes.dart';
import 'package:app/embarque/dominio/registro_embarque.dart';
import 'package:app/embarque/dominio/rota_do_dia.dart';
import 'package:app/embarque/infraestrutura/rota_salva_local.dart';

/// Servidor falso: responde a rota 1 ou lança o erro configurado.
class _Remoto implements EmbarqueRemoto {
  Exception? erro;

  @override
  Future<RotaDoDia> buscarRotaDoDia() async {
    final e = erro;
    if (e != null) throw e;
    return RotaDoDia(
      rotaId: 1,
      trajeto: 'IDA',
      horarioPrevisto: DateTime.parse('2026-11-24T06:30:00-03:00'),
      placa: 'ABC-1D23',
    );
  }

  @override
  Future<List<AlunoDaRota>> listarAlunos(int rotaId) async {
    final e = erro;
    if (e != null) throw e;
    return const [
      AlunoDaRota(alunoId: 3, nome: 'Carlos Lima', ordem: 3, endereco: 'Rua 3', embarcado: false),
      AlunoDaRota(alunoId: 1, nome: 'Ana Souza', ordem: 1, endereco: 'Rua das Acácias, 100', embarcado: true),
      AlunoDaRota(alunoId: 2, nome: 'Beatriz Reis', ordem: 2, endereco: 'Rua 2', embarcado: false),
    ];
  }

  @override
  Future<void> enviar(RegistroEmbarque registro) async {}

  @override
  Future<Map<String, int>> sincronizar(int rotaId, List<RegistroEmbarque> registros) async => {};
}

/// Bug VT-75: a rota de hoje fica guardada para abrir o app sem conexão.
void main() {
  late _Remoto remoto;
  late DateTime agora;

  RotaDoDiaService servico() =>
      RotaDoDiaService(remoto, salva: RotaSalvaLocal(), relogio: () => agora);

  /// Abre a rota como a tela faz: rota de hoje e depois os alunos dela.
  Future<(RotaDoDia, List<AlunoDaRota>)> abrir(RotaDoDiaService s) async {
    final rota = await s.buscarRotaDoDia();
    return (rota, await s.listarAlunosConfirmados(rota.rotaId));
  }

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    remoto = _Remoto();
    agora = DateTime(2026, 11, 24, 6, 40);
  });

  test('sem conexão, usa a rota de hoje carregada antes, na ordem das paradas', () async {
    await abrir(servico());

    remoto.erro = const SemConexaoException();
    final (rota, alunos) = await abrir(servico()); // app aberto de novo, offline

    expect(rota.rotaId, 1);
    expect(rota.placa, 'ABC-1D23');
    expect(rota.trajeto, 'IDA');
    expect(rota.horarioPrevisto, DateTime.parse('2026-11-24T06:30:00-03:00'));
    expect(alunos.map((a) => a.nome), ['Ana Souza', 'Beatriz Reis', 'Carlos Lima']);
    expect(alunos.map((a) => a.embarcado), [true, false, false]);
    expect(alunos.first.endereco, 'Rua das Acácias, 100');
  });

  test('a rota guardada de outro dia não é usada', () async {
    await abrir(servico());

    agora = DateTime(2026, 11, 25, 6, 40);
    remoto.erro = const SemConexaoException();

    expect(() => servico().buscarRotaDoDia(), throwsA(isA<SemConexaoException>()));
  });

  test('sem conexão e sem rota guardada, o erro chega à tela', () async {
    remoto.erro = const SemConexaoException();

    expect(() => servico().buscarRotaDoDia(), throwsA(isA<SemConexaoException>()));
    expect(() => servico().listarAlunosConfirmados(1), throwsA(isA<SemConexaoException>()));
  });

  test('uma recusa do servidor (403, RN-012) nunca usa a rota guardada', () async {
    await abrir(servico());

    remoto.erro = const EnvioRecusadoException(403, 'Você não é o motorista ativo desta van.');

    expect(() => servico().buscarRotaDoDia(), throwsA(isA<EnvioRecusadoException>()));
  });

  test('aluno embarcado depois de abrir a rota fica embarcado na rota guardada', () async {
    final s = servico();
    await abrir(s);
    await s.marcarEmbarcado(1, 2);

    remoto.erro = const SemConexaoException();
    final (_, alunos) = await abrir(servico());

    expect(alunos.map((a) => a.embarcado), [true, true, false]);
  });

  test('ao sair, a rota guardada é esquecida', () async {
    final s = servico();
    await abrir(s);
    await s.esquecer();

    remoto.erro = const SemConexaoException();

    expect(() => servico().buscarRotaDoDia(), throwsA(isA<SemConexaoException>()));
  });

  test('sem RotaSalva, nada é guardado', () async {
    await abrir(RotaDoDiaService(remoto, relogio: () => agora));

    remoto.erro = const SemConexaoException();

    expect(() => servico().buscarRotaDoDia(), throwsA(isA<SemConexaoException>()));
  });
}
