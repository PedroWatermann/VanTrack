import 'package:flutter/material.dart';

import 'avisos/apresentacao/tela_avisos.dart';
import 'compartilhado/api_client.dart';
import 'compartilhado/cores.dart';
import 'compartilhado/sessao.dart';
import 'embarque/apresentacao/tela_rota_do_dia.dart';
import 'login/aplicacao/login_service.dart';
import 'login/apresentacao/tela_login.dart';

/// Ponto de entrada do app VanTrack (UC-S05 Registrar Embarque).
///
/// Roda no Android e na Web (RNF-004). É aqui que as peças do app são
/// criadas e ligadas umas às outras.
void main() {
  final sessao = Sessao();
  final api = ApiClient(sessao: sessao);
  runApp(VanTrackApp(loginService: LoginService(api: api, sessao: sessao)));
}

/// Configuração geral do app: título, tema e tela inicial (login).
class VanTrackApp extends StatelessWidget {
  const VanTrackApp({super.key, required this.loginService});

  final LoginService loginService;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'VanTrack',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: CoresApp.verde,
        useMaterial3: true,
      ),
      home: TelaLogin(
        loginService: loginService,
        telaDoMotorista: (usuario) => TelaRotaDoDia(usuario: usuario),
        telaDoResponsavel: (usuario) => TelaAvisos(usuario: usuario),
      ),
    );
  }
}
