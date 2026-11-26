import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:app/compartilhado/api_client.dart';
import 'package:app/compartilhado/sessao.dart';
import 'package:app/embarque/aplicacao/modulo_embarque.dart';
import 'package:app/embarque/aplicacao/modulo_embarque_online.dart';
import 'package:app/embarque/aplicacao/rota_do_dia_service.dart';
import 'package:app/embarque/dominio/localizacao.dart';
import 'package:app/embarque/dominio/localizador.dart';
import 'package:app/embarque/infraestrutura/embarque_api.dart';
import 'package:app/login/aplicacao/login_service.dart';

// Fluxo do motorista contra respostas no formato do servidor de verdade
// (backend/lib/compartilhado/apresentacao/autenticacao_controller.dart e
// backend/lib/embarque/apresentacao/embarque_controller.dart), sem os dados
// simulados. Confere também o que o app envia: token, URL e corpo do embarque.
//
// UC-S05 passos 1 a 5 (lado do app); UC-R02; RN-012; RF-009.

/// Localizador falso com uma posição fixa.
class LocalizadorFixo implements Localizador {
  @override
  Future<Localizacao?> obterLocalizacao(Duration limite) async =>
      const Localizacao(-23.4205, -51.9331);
}

http.Response respostaJson(Object corpo, [int codigo = 200]) => http.Response(
      jsonEncode(corpo),
      codigo,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );

void main() {
  late Sessao sessao;
  late List<http.Request> requisicoes;
  late ApiClient api;

  /// Servidor falso que responde como o backend em Dart Frog.
  Future<http.Response> servidor(http.Request req) async {
    requisicoes.add(req);
    final caminho = req.url.path;
    if (req.method == 'GET' && caminho == '/usuarios') {
      return respostaJson([
        {'id': 1, 'nome': 'João Pereira', 'papel': 'MOTORISTA'},
        {'id': 2, 'nome': 'Marcos Oliveira', 'papel': 'MOTORISTA'},
        {'id': 1, 'nome': 'Maria Souza', 'papel': 'RESPONSAVEL'},
      ]);
    }
    if (req.method == 'POST' && caminho == '/login') {
      return respostaJson({'token': '8f14e45f-ceea-467a-9575-4e5b3b2c7d10'});
    }
    if (req.method == 'GET' && caminho == '/rotas/hoje') {
      return respostaJson({
        'rotaId': 1,
        'trajeto': 'IDA',
        'horarioPrevisto': '2026-11-20T06:30:00-03:00',
        'placa': 'ABC-1D23',
      });
    }
    if (req.method == 'GET' && caminho == '/rotas/1/alunos') {
      return respostaJson([
        {
          'alunoId': 1,
          'nome': 'Ana Souza',
          'ordem': 1,
          'pontoParada': {'endereco': 'Rua das Acácias, 100', 'latitude': -23.4205, 'longitude': -51.9331},
          'status': 'CONFIRMADO',
        },
        {
          'alunoId': 2,
          'nome': 'Beatriz Reis',
          'ordem': 2,
          'pontoParada': {'endereco': 'Avenida Brasil, 1500', 'latitude': -23.423, 'longitude': -51.938},
          'status': 'EMBARCADO',
        },
      ]);
    }
    if (req.method == 'POST' && caminho == '/rotas/1/embarques') {
      final corpo = jsonDecode(req.body) as Map<String, dynamic>;
      if (corpo['alunoId'] == 2) {
        return respostaJson({'erro': 'O aluno não está confirmado nesta rota ou já embarcou.'}, 409);
      }
      return respostaJson({'alunoId': corpo['alunoId'], 'status': 'EMBARCADO'}, 201);
    }
    return respostaJson({'erro': 'Não encontrado.'}, 404);
  }

  setUp(() {
    sessao = Sessao();
    requisicoes = [];
    api = ApiClient(
      sessao: sessao,
      baseUrl: 'http://localhost:8080',
      usarMock: false,
      cliente: MockClient(servidor),
    );
  });

  Future<void> entrarComoJoao() async {
    final login = LoginService(api: api, sessao: sessao);
    final usuarios = await login.listarUsuarios();
    await login.entrar(usuarios.first);
  }

  test('login: lista os usuários e guarda o token devolvido pelo servidor', () async {
    await entrarComoJoao();

    expect(sessao.usuario?.nome, 'João Pereira');
    expect(sessao.usuario?.papel, Papel.motorista);
    expect(sessao.token, '8f14e45f-ceea-467a-9575-4e5b3b2c7d10');
    final corpoLogin = jsonDecode(requisicoes.last.body);
    expect(corpoLogin, {'id': 1, 'papel': 'MOTORISTA'});
  });

  test('depois do login, as requisições levam o token no formato Bearer', () async {
    await entrarComoJoao();

    await RotaDoDiaService(EmbarqueApi(api)).buscarRotaDoDia();

    expect(
      requisicoes.last.headers['Authorization'],
      'Bearer 8f14e45f-ceea-467a-9575-4e5b3b2c7d10',
    );
  });

  test('lê a rota de hoje e a lista de alunos no formato do servidor', () async {
    await entrarComoJoao();
    final servico = RotaDoDiaService(EmbarqueApi(api));

    final rota = await servico.buscarRotaDoDia();
    final alunos = await servico.listarAlunosConfirmados(rota.rotaId);

    expect(rota.placa, 'ABC-1D23');
    expect(rota.horarioPrevisto, DateTime.parse('2026-11-20T09:30:00Z'));
    expect(alunos.map((a) => a.nome), ['Ana Souza', 'Beatriz Reis']);
    expect(alunos[0].embarcado, isFalse);
    expect(alunos[1].embarcado, isTrue);
  });

  test('o embarque vai com UUID, hora com fuso e localização, como o servidor exige', () async {
    await entrarComoJoao();
    final modulo = ModuloEmbarqueOnline(remoto: EmbarqueApi(api), localizador: LocalizadorFixo());

    final resultado = await modulo.registrarEmbarque(1, 1);

    expect(resultado.status, StatusEnvio.enviado);
    final envio = requisicoes.last;
    expect(envio.url.toString(), 'http://localhost:8080/rotas/1/embarques');
    final corpo = jsonDecode(envio.body) as Map<String, dynamic>;
    expect(
      RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$')
          .hasMatch(corpo['registroId'] as String),
      isTrue,
    );
    expect(corpo['alunoId'], 1);
    // O servidor recusa (400) data sem fuso: precisa estar em UTC.
    expect(DateTime.parse(corpo['dataHora'] as String).isUtc, isTrue);
    expect(corpo['latitude'], -23.4205);
    expect(corpo['longitude'], -51.9331);
  });

  test('409 do servidor vira EmbarqueException com 409', () async {
    await entrarComoJoao();
    final modulo = ModuloEmbarqueOnline(remoto: EmbarqueApi(api), localizador: LocalizadorFixo());

    expect(
      () => modulo.registrarEmbarque(1, 2),
      throwsA(isA<EmbarqueException>().having((e) => e.codigoHttp, 'codigoHttp', 409)),
    );
  });
}
