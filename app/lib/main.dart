import 'package:flutter/material.dart';

/// Ponto de entrada do app VanTrack (UC-S05 Registrar Embarque).
///
/// Por enquanto (VT-48 / D-01) só abre uma tela inicial simples para
/// confirmar que o projeto roda no Android e na Web (RNF-004).
/// Nas próximas tasks:
/// - VT-50 (D-03) troca a tela inicial pela tela de login;
/// - VT-51 (D-04) escolhe aqui, em uma linha só, qual ModuloEmbarque usar.
void main() {
  runApp(const VanTrackApp());
}

class VanTrackApp extends StatelessWidget {
  const VanTrackApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'VanTrack',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFF2E7D32),
        useMaterial3: true,
      ),
      home: const TelaInicial(),
    );
  }
}

/// Tela provisória. Será substituída pela tela de login (VT-50).
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
