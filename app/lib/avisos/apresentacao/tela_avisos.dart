import 'package:flutter/material.dart';

import '../../compartilhado/sessao.dart';

/// Tela "Avisos" do responsável (UC-I02).
///
/// Versão provisória, apenas para o login ter para onde ir. A tela completa
/// é feita pelo Membro C.
class TelaAvisos extends StatelessWidget {
  const TelaAvisos({super.key, required this.usuario});

  final UsuarioLogado usuario;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Avisos')),
      body: Center(
        child: Text('Olá, ${usuario.nome}', style: const TextStyle(fontSize: 20)),
      ),
    );
  }
}
