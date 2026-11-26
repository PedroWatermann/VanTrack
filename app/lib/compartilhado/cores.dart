import 'package:flutter/material.dart';

/// Cores do app, usadas por todas as telas.
///
/// O grupo combinou um único verde e um único âmbar para mostrar a situação
/// de cada aluno (seção 10 do backlog). Para trocar uma cor no app inteiro,
/// basta mudar aqui.
///
class CoresApp {
  CoresApp._();

  /// Verde: o aluno embarcou e o servidor já recebeu.
  static const Color verde = Color(0xFF2E7D32);

  /// Âmbar: o aluno embarcou, mas ainda não foi enviado ao servidor
  /// (por exemplo, quando está sem internet).
  static const Color ambar = Color(0xFFFF8F00);

  /// Cinza: o aluno ainda está esperando para embarcar.
  static const Color cinza = Color(0xFF757575);
}
