import 'package:flutter/material.dart';

import '../../compartilhado/sessao.dart';

/// Tela "Rota do dia" do motorista (UC-R02).
///
/// Versão provisória: por enquanto mostra apenas quem entrou no app.
class TelaRotaDoDia extends StatelessWidget {
  const TelaRotaDoDia({super.key, required this.usuario});

  final UsuarioLogado usuario;

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
