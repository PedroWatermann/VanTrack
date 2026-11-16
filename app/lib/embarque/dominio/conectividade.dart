import 'dart:async';

/// `Conectividade` — embarque :: domínio (contrato).
///
/// Responsabilidade: informar se há conexão com a rede no momento e notificar
/// quando o estado da conexão mudar, além de permitir registrar falhas/sucessos
/// de chamadas de rede (como na Web, onde a queda pode só ser percebida ao
/// tentar chamar o servidor).
///
/// RNF-006 (sincronização offline em até 5 min); RNF-003 (visibilidade do
/// estado sem conexão).
/// UC-S05 fluxo alternativo A1; UC-R02 E1.
abstract class Conectividade {
  /// Indica se o aparelho está com conexão no momento.
  bool get estaOnline;

  /// Emite `true` quando a conexão volta e `false` quando cai.
  Stream<bool> get aoMudar;

  /// Registra que uma chamada de rede falhou por falta de conexão ou timeout,
  /// atualizando o estado para offline.
  void registrarFalhaDeRede();

  /// Registra que uma chamada de rede obteve resposta do servidor,
  /// confirmando que há conexão.
  void registrarSucessoDeRede();
}
