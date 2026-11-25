import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:app/compartilhado/sessao.dart';
import 'package:app/compartilhado/sessao_salva.dart';

/// Bug VT-75: a sessão sobrevive a fechar e abrir o app.
void main() {
  const joao = UsuarioLogado(id: 1, nome: 'João Pereira', papel: Papel.motorista);

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('quem entrou continua logado ao abrir o app de novo', () async {
    await Sessao(SessaoSalva()).entrar(joao, 'token-do-joao');

    // "Abre o app de novo": uma sessão nova, lendo o que ficou no aparelho.
    final reaberta = Sessao(SessaoSalva());
    expect(await reaberta.restaurar(), isTrue);

    expect(reaberta.logado, isTrue);
    expect(reaberta.token, 'token-do-joao');
    expect(reaberta.usuario?.id, 1);
    expect(reaberta.usuario?.nome, 'João Pereira');
    expect(reaberta.usuario?.papel, Papel.motorista);
  });

  test('depois de sair, o app abre sem ninguém logado', () async {
    final sessao = Sessao(SessaoSalva());
    await sessao.entrar(joao, 'token-do-joao');
    await sessao.sair();

    final reaberta = Sessao(SessaoSalva());
    expect(await reaberta.restaurar(), isFalse);
    expect(reaberta.logado, isFalse);
    expect(reaberta.usuario, isNull);
  });

  test('conteúdo guardado que não é reconhecido é ignorado', () async {
    SharedPreferences.setMockInitialValues({SessaoSalva.chave: 'não é json'});

    final sessao = Sessao(SessaoSalva());
    expect(await sessao.restaurar(), isFalse);
    expect(sessao.logado, isFalse);
  });

  test('sem SessaoSalva, a sessão fica só na memória', () async {
    await Sessao().entrar(joao, 'token-do-joao');

    expect(await Sessao(SessaoSalva()).restaurar(), isFalse);
  });
}
