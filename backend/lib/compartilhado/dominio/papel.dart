/// `Papel` — compartilhado :: domínio (enum).
///
/// Papel do usuário na API: MOTORISTA ou RESPONSAVEL. Fica no módulo
/// compartilhado porque é usado por `Usuario` (cadastro) e por `UsuarioLogado`
/// (identidade da requisição, usada pelos controllers de todos os módulos).
/// Assim o compartilhado não precisa importar o cadastro (Bug VT-71, ponto 15
/// do 03-arquitetura.md). O `cadastro/dominio/usuario.dart` reexporta este enum.
enum Papel {
  motorista('MOTORISTA'),
  responsavel('RESPONSAVEL');

  const Papel(this.codigo);

  /// Valor usado no JSON e no banco.
  final String codigo;

  /// Converte `"MOTORISTA"`/`"RESPONSAVEL"` no enum; `null` se for inválido.
  static Papel? deCodigo(Object? codigo) {
    for (final papel in values) {
      if (papel.codigo == codigo) return papel;
    }
    return null;
  }
}
