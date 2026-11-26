/// `AcessoNegadoException` — compartilhado :: aplicação.
///
/// Lançada por um service quando o usuário logado não pode fazer a operação
/// (ex.: não é o motorista ativo da van da rota, RN-012; ou o aviso não é dele,
/// RN-002). Vira HTTP 403 na apresentação.
///
/// Fica em `compartilhado/` porque é usada por mais de um módulo
/// (`EmbarqueService`, `AvisosService`).
class AcessoNegadoException implements Exception {
  const AcessoNegadoException(this.mensagem);

  final String mensagem;

  @override
  String toString() => 'AcessoNegadoException: $mensagem';
}

/// `NaoEncontradoException` — compartilhado :: aplicação.
///
/// Lançada por um service quando o recurso pedido não existe (ex.: rota
/// inexistente, ou aluno sem presença na rota). Vira HTTP 404 na apresentação.
class NaoEncontradoException implements Exception {
  const NaoEncontradoException(this.mensagem);

  final String mensagem;

  @override
  String toString() => 'NaoEncontradoException: $mensagem';
}
