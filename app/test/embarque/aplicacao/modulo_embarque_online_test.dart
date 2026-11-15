import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:app/compartilhado/api_client.dart';
import 'package:app/compartilhado/mock/dados_mock.dart';
import 'package:app/compartilhado/sessao.dart';
import 'package:app/embarque/aplicacao/modulo_embarque.dart';
import 'package:app/embarque/aplicacao/modulo_embarque_online.dart';
import 'package:app/embarque/dominio/excecoes.dart';
import 'package:app/embarque/dominio/localizacao.dart';
import 'package:app/embarque/dominio/localizador.dart';
import 'package:app/embarque/infraestrutura/embarque_api.dart';

/// Localizador falso: devolve sempre a mesma resposta e guarda o limite pedido.
class LocalizadorFalso implements Localizador {
  LocalizadorFalso([this.resposta]);

  final Localizacao? resposta;
  Duration? limitePedido;

  @override
  Future<Localizacao?> obterLocalizacao(Duration limite) async {
    limitePedido = limite;
    return resposta;
  }
}

void main() {
  late Sessao sessao;

  /// Módulo usando os dados simulados, com o usuário já logado.
  ModuloEmbarqueOnline moduloLogadoComo(String token, Localizador localizador) {
    sessao = Sessao()
      ..entrar(const UsuarioLogado(id: 1, nome: 'teste', papel: Papel.motorista), token);
    final api = ApiClient(sessao: sessao, usarMock: true, mock: DadosMock(atraso: Duration.zero));
    return ModuloEmbarqueOnline(remoto: EmbarqueApi(api), localizador: localizador);
  }

  test('registra o embarque e devolve enviado, com a hora do toque', () async {
    final modulo = moduloLogadoComo('mock-MOTORISTA-1', LocalizadorFalso(const Localizacao(-23.42, -51.93)));
    final antes = DateTime.now();

    final resultado = await modulo.registrarEmbarque(1, 1);

    expect(resultado.status, StatusEnvio.enviado);
    expect(resultado.alunoId, 1);
    expect(resultado.registroId, isNotEmpty);
    expect(resultado.dataHora.isBefore(antes), isFalse);
  });

  test('pede a localização com limite de 2 segundos', () async {
    final localizador = LocalizadorFalso();
    final modulo = moduloLogadoComo('mock-MOTORISTA-1', localizador);

    await modulo.registrarEmbarque(1, 1);

    expect(localizador.limitePedido, const Duration(seconds: 2));
  });

  test('envia mesmo sem localização (GPS sem resposta)', () async {
    final modulo = moduloLogadoComo('mock-MOTORISTA-1', LocalizadorFalso(null));

    final resultado = await modulo.registrarEmbarque(1, 2);

    expect(resultado.status, StatusEnvio.enviado);
  });

  test('cada toque gera um registroId diferente', () async {
    final modulo = moduloLogadoComo('mock-MOTORISTA-1', LocalizadorFalso());

    final primeiro = await modulo.registrarEmbarque(1, 1);
    final segundo = await modulo.registrarEmbarque(1, 2);

    expect(primeiro.registroId, isNot(segundo.registroId));
  });

  test('aluno que já embarcou: lança EmbarqueException com 409', () async {
    final modulo = moduloLogadoComo('mock-MOTORISTA-1', LocalizadorFalso());
    await modulo.registrarEmbarque(1, 1);

    expect(
      () => modulo.registrarEmbarque(1, 1),
      throwsA(isA<EmbarqueException>().having((e) => e.codigoHttp, 'codigoHttp', 409)),
    );
  });

  test('motorista sem vínculo: lança EmbarqueException com 403 (RN-012)', () async {
    final modulo = moduloLogadoComo('mock-MOTORISTA-2', LocalizadorFalso());

    expect(
      () => modulo.registrarEmbarque(1, 1),
      throwsA(isA<EmbarqueException>().having((e) => e.codigoHttp, 'codigoHttp', 403)),
    );
  });

  test('sem conexão: repassa SemConexaoException', () async {
    sessao = Sessao();
    final semRede = MockClient((_) async => throw http.ClientException('sem rede'));
    final api = ApiClient(sessao: sessao, usarMock: false, cliente: semRede);
    final modulo = ModuloEmbarqueOnline(remoto: EmbarqueApi(api), localizador: LocalizadorFalso());

    expect(() => modulo.registrarEmbarque(1, 1), throwsA(isA<SemConexaoException>()));
  });

  test('não guarda pendentes', () async {
    final modulo = moduloLogadoComo('mock-MOTORISTA-1', LocalizadorFalso());

    expect(await modulo.listarPendentes(1), isEmpty);
  });
}
