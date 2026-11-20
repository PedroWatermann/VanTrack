import 'sessao.dart';

/// Contrato de persistência de sessões (RNF-002; UC-S05/RF-009, UC-I02/RF-011).
abstract class SessaoRepository {
  Future<Sessao?> buscarPorToken(String token);
  Future<void> salvar(Sessao sessao);
}
