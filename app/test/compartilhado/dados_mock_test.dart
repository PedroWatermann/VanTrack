import 'package:flutter_test/flutter_test.dart';

import 'package:app/compartilhado/api_client.dart';
import 'package:app/compartilhado/mock/dados_mock.dart';
import 'package:app/compartilhado/sessao.dart';

void main() {
  late Sessao sessao;
  late ApiClient api;

  setUp(() {
    sessao = Sessao();
    api = ApiClient(sessao: sessao, usarMock: true, mock: DadosMock(atraso: Duration.zero));
  });

  Future<void> entrarComo(int id, Papel papel) async {
    final resposta = await api.post('/login', {'id': id, 'papel': papel.texto});
    sessao.entrar(
      UsuarioLogado(id: id, nome: 'teste', papel: papel),
      resposta.corpo['token'] as String,
    );
  }

  Map<String, dynamic> embarque(String registroId, int alunoId) => {
        'registroId': registroId,
        'alunoId': alunoId,
        'dataHora': '2026-11-16T06:42:10-03:00',
      };

  test('lista os usuários do seed sem precisar de login', () async {
    final resposta = await api.get('/usuarios');
    expect(resposta.codigo, 200);
    expect((resposta.corpo as List).length, 6);
  });

  test('sem login, as outras rotas devolvem 401', () async {
    final resposta = await api.get('/rotas/1/alunos');
    expect(resposta.codigo, 401);
  });

  test('motorista ativo vê a rota de hoje e os alunos 1, 2 e 3 em ordem (teste 1)', () async {
    await entrarComo(1, Papel.motorista);

    final rota = await api.get('/rotas/hoje');
    expect(rota.codigo, 200);
    expect(rota.corpo['placa'], 'ABC-1D23');

    final alunos = await api.get('/rotas/1/alunos');
    expect(alunos.codigo, 200);
    final nomes = (alunos.corpo as List).map((a) => a['nome']).toList();
    expect(nomes, ['Ana Souza', 'Beatriz Reis', 'Carlos Lima']); // Bruno (ausente) não aparece
  });

  test('embarcar devolve 201 e o aluno passa a EMBARCADO (teste 2)', () async {
    await entrarComo(1, Papel.motorista);

    final resposta = await api.post('/rotas/1/embarques', embarque('r1', 1));
    expect(resposta.codigo, 201);

    final alunos = await api.get('/rotas/1/alunos');
    expect((alunos.corpo as List).first['status'], 'EMBARCADO');
  });

  test('embarcar de novo com outro registroId devolve 409 (teste 6)', () async {
    await entrarComo(1, Papel.motorista);
    await api.post('/rotas/1/embarques', embarque('r1', 1));

    final resposta = await api.post('/rotas/1/embarques', embarque('r2', 1));
    expect(resposta.codigo, 409);
  });

  test('o mesmo registroId duas vezes devolve 200 e não duplica', () async {
    await entrarComo(1, Papel.motorista);
    await api.post('/rotas/1/embarques', embarque('r1', 1));

    final resposta = await api.post('/rotas/1/embarques', embarque('r1', 1));
    expect(resposta.codigo, 200);
  });

  test('motorista sem vínculo recebe 403 na lista de alunos (teste 7)', () async {
    await entrarComo(2, Papel.motorista);

    final resposta = await api.get('/rotas/1/alunos');
    expect(resposta.codigo, 403);
  });

  test('motorista sem vínculo recebe 403 na rota de hoje, como o servidor (teste 7)', () async {
    await entrarComo(2, Papel.motorista);

    final resposta = await api.get('/rotas/hoje');
    expect(resposta.codigo, 403);
  });

  test('responsável só vê os avisos dos seus alunos (testes 3 e 4)', () async {
    await entrarComo(1, Papel.motorista);
    await api.post('/rotas/1/embarques', embarque('r1', 1)); // Ana

    await entrarComo(2, Papel.responsavel); // responsável da Ana
    final daAna = await api.get('/notificacoes');
    expect((daAna.corpo as List).single['mensagem'], 'Ana Souza embarcou na van às 06:42.');

    await entrarComo(3, Papel.responsavel); // responsável da Beatriz
    final daBeatriz = await api.get('/notificacoes');
    expect(daBeatriz.corpo, isEmpty);
  });
}
