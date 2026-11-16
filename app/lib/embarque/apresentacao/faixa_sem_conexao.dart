import 'package:flutter/material.dart';

import '../../compartilhado/cores.dart';

/// Faixa âmbar no topo da tela, sempre visível quando o app está sem conexão
/// (RNF-003). Com conexão, não ocupa espaço.
class FaixaSemConexao extends StatelessWidget {
  const FaixaSemConexao({super.key, required this.semConexao});

  /// Indica se o app está sem conexão.
  final bool semConexao;

  @override
  Widget build(BuildContext context) {
    if (!semConexao) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      color: CoresApp.ambar,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: const Row(
        children: [
          Icon(Icons.wifi_off, color: Colors.black),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Sem conexão. Os embarques serão enviados quando o sinal voltar.',
              style: TextStyle(fontSize: 16, color: Colors.black),
            ),
          ),
        ],
      ),
    );
  }
}
