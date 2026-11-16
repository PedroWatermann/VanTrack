import 'package:flutter_test/flutter_test.dart';

import 'package:app/compartilhado/api_client.dart';
import 'package:app/compartilhado/mock/dados_mock.dart';
import 'package:app/compartilhado/sessao.dart';
import 'package:app/embarque/dominio/excecoes.dart';
import 'package:app/embarque/dominio/registro_embarque.dart';
import 'package:app/embarque/infraestrutura/embarque_api.dart';

void main() {
  /// API usando os dados simulados, com o usuário já logado.
  EmbarqueApi apiLogadaComo(String token) {
    final sessao = Sessao()
      ..entrar(const UsuarioLogado(id: 1, nome: 'teste', papel: Papel.motorista), token);
    return EmbarqueApi(
      ApiClient(sessao: sessao, usarMock: true, mock: DadosMock(atraso: Duration.zero)),
    );
  }

  RegistroEmbarque registro(String registroId, int alunoId) => RegistroEmbarque(
        registroId: registroId,
        rotaId: 1,
        alunoId: alunoId,
        dataHora: DateTime.parse('2026-11-16T06:42:10-03:00'),
      );

  test('busca a rota de hoje', () async {
    final rota = await apiLogadaComo('mock-MOTORISTA-1').buscarRotaDoDia();

    expect(rota.rotaId, 1);
    expect(rota.placa, 'ABC-1D23');
    expect(rota.trajeto, 'IDA');
  });

  test('lista os alunos confirmados na ordem, sem o ausente', () async {
    final alunos = await apiLogadaComo('mock-MOTORISTA-1').listarAlunos(1);

    expect(alunos.map((a) => a.nome), ['Ana Souza', 'Beatriz Reis', 'Carlos Lima']);
    expect(alunos.first.endereco, 'Rua das Acácias, 100');
    expect(alunos.every((a) => !a.embarcado), isTrue);
  });

  test('motorista sem vínculo: EnvioRecusadoException com 403', () async {
    expect(
      () => apiLogadaComo('mock-MOTORISTA-2').listarAlunos(1),
      throwsA(isA<EnvioRecusadoException>().having((e) => e.codigoHttp, 'codigoHttp', 403)),
    );
  });

  test('sincroniza vários embarques e devolve o código de cada um', () async {
    final resultado = await apiLogadaComo('mock-MOTORISTA-1').sincronizar(1, [
      registro('r1', 1),
      registro('r1', 1), // repetido: não duplica
      registro('r2', 4), // ausente
    ]);

    expect(resultado, {'r1': 200, 'r2': 409});
  });

  test('o registro vira o JSON do contrato e volta igual', () {
    final original = registro('r1', 2);

    final json = original.paraJson();
    final lido = RegistroEmbarque.deJson(1, json);

    expect(json.keys, containsAll(['registroId', 'alunoId', 'dataHora']));
    expect(json.containsKey('latitude'), isFalse);
    expect(lido.registroId, 'r1');
    expect(lido.dataHora, original.dataHora);
  });
}
