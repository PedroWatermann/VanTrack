import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../dominio/fila_embarques.dart';
import '../dominio/registro_embarque.dart';

/// `ArmazenamentoLocal` — embarque :: infraestrutura (participante
/// "ArmazenamentoLocal (dispositivo)" do diagrama de sequência UC-S05, A1).
///
/// Responsabilidade: manter a fila persistente de registros de embarque em JSON
/// no `shared_preferences` (compatível com Android e Web), garantindo que os
/// registros feitos sem conexão sobrevivam ao fechar e reabrir o aplicativo.
///
/// RNF-006 (check-ins offline sincronizados em até 5 min); RF-009.
/// UC-S05 fluxo alternativo A1; UC-R02 E1.
class ArmazenamentoLocal implements FilaEmbarques {
  ArmazenamentoLocal([this._prefs]);

  /// Chave usada no [SharedPreferences] para gravar a fila em JSON.
  static const String chaveFila = 'fila_embarques_pendentes';

  SharedPreferences? _prefs;

  Future<SharedPreferences> _obterPrefs() async =>
      _prefs ??= await SharedPreferences.getInstance();

  @override
  Future<void> guardar(RegistroEmbarque registro) async {
    final prefs = await _obterPrefs();
    final registros = _lerTodos(prefs);

    // RNF-006: evita duplicar o mesmo registroId na fila local.
    final jaExiste = registros.any((r) => r.registroId == registro.registroId);
    if (!jaExiste) {
      registros.add(registro);
      await _salvarTodos(prefs, registros);
    }
  }

  @override
  Future<List<RegistroEmbarque>> listar(int rotaId) async {
    final prefs = await _obterPrefs();
    return [
      for (final registro in _lerTodos(prefs))
        if (registro.rotaId == rotaId) registro,
    ];
  }

  @override
  Future<void> remover(Set<String> registroIds) async {
    if (registroIds.isEmpty) return;
    final prefs = await _obterPrefs();
    final restantes = _lerTodos(prefs)
        .where((r) => !registroIds.contains(r.registroId))
        .toList();
    await _salvarTodos(prefs, restantes);
  }

  List<RegistroEmbarque> _lerTodos(SharedPreferences prefs) {
    final bruto = prefs.getString(chaveFila);
    if (bruto == null || bruto.isEmpty) return [];

    final lista = jsonDecode(bruto) as List<dynamic>;
    return [
      for (final item in lista.cast<Map<String, dynamic>>())
        RegistroEmbarque.deJson(item['rotaId'] as int, item),
    ];
  }

  Future<void> _salvarTodos(
    SharedPreferences prefs,
    List<RegistroEmbarque> registros,
  ) async {
    final jsonLista = [
      for (final r in registros)
        {
          'rotaId': r.rotaId,
          ...r.paraJson(),
        },
    ];
    await prefs.setString(chaveFila, jsonEncode(jsonLista));
  }
}
