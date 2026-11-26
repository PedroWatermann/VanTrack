import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'sessao.dart';

/// Guarda no aparelho o usuário logado e o token, para a [Sessao] sobreviver a
/// fechar e abrir o app (`shared_preferences`, que funciona no Android e na Web).
///
/// Sem isso, o app sempre abria no login, que precisa do servidor: aberto sem
/// conexão, o motorista não via a rota nem os embarques pendentes (teste 9,
/// RNF-006; Bug VT-75).
///
/// Classe de apoio: não faz parte do caso de uso avaliado (UC-S05).
class SessaoSalva {
  SessaoSalva([this._prefs]);

  /// Chave usada no [SharedPreferences] para gravar a sessão em JSON.
  static const String chave = 'sessao';

  SharedPreferences? _prefs;

  Future<SharedPreferences> _obterPrefs() async =>
      _prefs ??= await SharedPreferences.getInstance();

  /// Guarda o usuário e o token do login.
  Future<void> salvar(UsuarioLogado usuario, String token) async {
    final prefs = await _obterPrefs();
    await prefs.setString(
      chave,
      jsonEncode({
        'id': usuario.id,
        'nome': usuario.nome,
        'papel': usuario.papel.texto,
        'token': token,
      }),
    );
  }

  /// Lê a sessão guardada. Nulo se ninguém entrou ou se o conteúdo não for
  /// reconhecido (nesse caso o app simplesmente abre no login).
  Future<(UsuarioLogado, String)?> ler() async {
    final prefs = await _obterPrefs();
    final bruto = prefs.getString(chave);
    if (bruto == null) return null;
    try {
      final dados = jsonDecode(bruto) as Map<String, dynamic>;
      final usuario = UsuarioLogado(
        id: dados['id'] as int,
        nome: dados['nome'] as String,
        papel: Papel.deTexto(dados['papel'] as String),
      );
      return (usuario, dados['token'] as String);
    } catch (_) {
      return null;
    }
  }

  /// Apaga a sessão guardada (logout).
  Future<void> apagar() async {
    final prefs = await _obterPrefs();
    await prefs.remove(chave);
  }
}
