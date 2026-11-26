/// O servidor recusou a requisição (ex.: 403, 404 ou 409).
///
/// Um embarque recusado nunca vai para a fila: tentar de novo daria o mesmo
/// resultado. A tela mostra a mensagem para o motorista.
class EnvioRecusadoException implements Exception {
  final int codigoHttp;
  final String mensagem;

  const EnvioRecusadoException(this.codigoHttp, this.mensagem);

  @override
  String toString() => 'EnvioRecusadoException($codigoHttp): $mensagem';
}

/// Não foi possível falar com o servidor (sem conexão ou sem resposta a tempo).
///
/// Diferente da recusa, aqui o embarque pode ser guardado na fila e enviado
/// depois (fluxo A1 do UC-S05).
class SemConexaoException implements Exception {
  const SemConexaoException();

  @override
  String toString() => 'SemConexaoException';
}
