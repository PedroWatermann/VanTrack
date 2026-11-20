import 'dart:io';

import 'package:test/test.dart';

/// Regras de dependência da arquitetura (03-arquitetura.md, seções 3.3, 3.5 e
/// 4.1), conferidas a cada `dart test` (Bug VT-71).
///
/// 1. Um módulo só importa módulos de nível MENOR (nunca do mesmo nível nem de
///    cima): assim não existe dependência circular entre módulos.
/// 2. Nenhum arquivo de `dominio/` importa framework ou biblioteca de I/O.
void main() {
  // Nível de cada módulo de backend/lib (seção 4.1).
  const niveis = {
    'compartilhado': 0,
    'cadastro': 1,
    'autenticacao': 2,
    'rota': 2,
    'notificacao': 3,
    'embarque': 4,
  };
  const proibidosNoDominio = [
    'package:dart_frog',
    'package:postgres',
    'package:http',
    'package:flutter',
  ];

  final arquivos = Directory('lib')
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .toList();

  // Caminho relativo a lib/, com "/" (funciona no Windows também).
  String relativo(File arquivo) =>
      arquivo.path.replaceAll(r'\', '/').split('lib/').last;

  String moduloDe(String caminho) => caminho.split('/').first;

  /// Módulo de destino de um import de outro módulo, ou `null` se for do
  /// próprio módulo, de pacote externo ou do SDK.
  String? moduloImportado(String linha, String moduloAtual) {
    final pacote = RegExp(r"""import\s+'package:vantrack_backend/(\w+)/""")
        .firstMatch(linha);
    if (pacote != null) return pacote.group(1);
    final relativoOutro =
        RegExp(r"""import\s+'\.\./\.\./(\w+)/""").firstMatch(linha);
    return relativoOutro?.group(1);
  }

  test('todo arquivo de lib/ está em um módulo conhecido', () {
    final desconhecidos = {
      for (final arquivo in arquivos) moduloDe(relativo(arquivo)),
    }.difference(niveis.keys.toSet());
    expect(desconhecidos, isEmpty, reason: 'acrescente o módulo em `niveis`');
  });

  test('um módulo só importa módulos de nível menor (sem ciclos)', () {
    final violacoes = <String>[];
    for (final arquivo in arquivos) {
      final caminho = relativo(arquivo);
      final modulo = moduloDe(caminho);
      for (final linha in arquivo.readAsLinesSync()) {
        final destino = moduloImportado(linha, modulo);
        if (destino == null || destino == modulo) continue;
        if (niveis[destino]! >= niveis[modulo]!) {
          violacoes.add('$caminho -> $destino');
        }
      }
    }
    expect(violacoes, isEmpty);
  });

  test('o domínio não importa framework nem biblioteca de I/O', () {
    final violacoes = <String>[];
    for (final arquivo in arquivos) {
      final caminho = relativo(arquivo);
      if (!caminho.contains('/dominio/')) continue;
      for (final linha in arquivo.readAsLinesSync()) {
        if (proibidosNoDominio.any(linha.contains)) {
          violacoes.add('$caminho: ${linha.trim()}');
        }
      }
    }
    expect(violacoes, isEmpty);
  });
}
