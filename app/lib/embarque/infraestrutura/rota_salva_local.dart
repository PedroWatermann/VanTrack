import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../dominio/aluno_da_rota.dart';
import '../dominio/rota_do_dia.dart';
import '../dominio/rota_salva.dart';

/// Guarda a última rota do dia em JSON no `shared_preferences` (Android e Web),
/// no mesmo formato das respostas da API.
///
/// RNF-006; UC-S05 fluxo alternativo A1 (Bug VT-75).
class RotaSalvaLocal implements RotaSalva {
  RotaSalvaLocal([this._prefs]);

  /// Chave usada no [SharedPreferences] para gravar a rota.
  static const String chave = 'rota_do_dia';

  SharedPreferences? _prefs;

  Future<SharedPreferences> _obterPrefs() async =>
      _prefs ??= await SharedPreferences.getInstance();

  @override
  Future<void> guardar(RotaGuardada rota) async {
    final prefs = await _obterPrefs();
    await prefs.setString(
      chave,
      jsonEncode({
        'dia': rota.dia,
        'rota': rota.rota.paraJson(),
        'alunos': [for (final aluno in rota.alunos) aluno.paraJson()],
      }),
    );
  }

  @override
  Future<RotaGuardada?> ler() async {
    final prefs = await _obterPrefs();
    final bruto = prefs.getString(chave);
    if (bruto == null) return null;
    try {
      final dados = jsonDecode(bruto) as Map<String, dynamic>;
      return (
        dia: dados['dia'] as String,
        rota: RotaDoDia.deJson(dados['rota'] as Map<String, dynamic>),
        alunos: [
          for (final aluno in (dados['alunos'] as List).cast<Map<String, dynamic>>())
            AlunoDaRota.deJson(aluno),
        ],
      );
    } catch (_) {
      // Conteúdo não reconhecido: é como se não houvesse rota guardada.
      return null;
    }
  }

  @override
  Future<void> apagar() async {
    final prefs = await _obterPrefs();
    await prefs.remove(chave);
  }
}
