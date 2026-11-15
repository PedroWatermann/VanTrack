import 'package:flutter/material.dart';

import '../../compartilhado/sessao.dart';
import '../aplicacao/modulo_embarque.dart';

/// Tela "Rota do dia" do motorista (UC-R02).
///
/// Versão provisória: por enquanto mostra apenas quem entrou no app.
class TelaRotaDoDia extends StatelessWidget {
  const TelaRotaDoDia({super.key, required this.usuario, required this.modulo});

  final UsuarioLogado usuario;

  /// Módulo usado para registrar os embarques.
  final ModuloEmbarque modulo;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Rota do dia')),
      body: Center(
        child: Text('Olá, ${usuario.nome}', style: const TextStyle(fontSize: 20)),
      ),
    );
  }
}
