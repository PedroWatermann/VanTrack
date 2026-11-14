import 'package:flutter/material.dart';

import 'compartilhado/cores.dart';

/// Ponto de entrada do app VanTrack (UC-S05 Registrar Embarque).
///
/// Roda no Android e na Web (RNF-004).
void main() {
  runApp(const VanTrackApp());
}

/// Configuração geral do app: título, tema e tela inicial.
class VanTrackApp extends StatelessWidget {
  const VanTrackApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'VanTrack',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: CoresApp.verde,
        useMaterial3: true,
      ),
      home: const TelaInicial(),
    );
  }
}

/// Tela inicial provisória, só com o nome do app.
class TelaInicial extends StatelessWidget {
  const TelaInicial({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Text(
          'VanTrack',
          style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
