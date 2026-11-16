import 'package:flutter/material.dart';

import 'avisos/apresentacao/tela_avisos.dart';
import 'compartilhado/api_client.dart';
import 'compartilhado/cores.dart';
import 'compartilhado/sessao.dart';
import 'embarque/aplicacao/modulo_embarque.dart';
import 'embarque/aplicacao/modulo_embarque_online.dart';
import 'embarque/aplicacao/rota_do_dia_service.dart';
import 'embarque/apresentacao/tela_rota_do_dia.dart';
import 'embarque/infraestrutura/embarque_api.dart';
import 'embarque/infraestrutura/localizador_geolocator.dart';
import 'login/aplicacao/login_service.dart';
import 'login/apresentacao/tela_login.dart';

/// Ponto de entrada do app VanTrack (UC-S05 Registrar Embarque).
///
/// Roda no Android e na Web (RNF-004). É aqui que as peças do app são
/// criadas e ligadas umas às outras.
void main() {
  final sessao = Sessao();
  final api = ApiClient(sessao: sessao);

  final embarqueApi = EmbarqueApi(api);

  // Implementação do módulo de embarque usada pelo app. É escolhida só aqui:
  // para usar a versão com fila (sem conexão), basta trocar esta linha.
  final ModuloEmbarque moduloEmbarque = ModuloEmbarqueOnline(
    remoto: embarqueApi,
    localizador: LocalizadorGeolocator(),
  );

  runApp(VanTrackApp(
    loginService: LoginService(api: api, sessao: sessao),
    moduloEmbarque: moduloEmbarque,
    rotaDoDiaService: RotaDoDiaService(embarqueApi),
  ));
}

/// Configuração geral do app: título, tema e tela inicial (login).
class VanTrackApp extends StatelessWidget {
  const VanTrackApp({
    super.key,
    required this.loginService,
    required this.moduloEmbarque,
    required this.rotaDoDiaService,
  });

  final LoginService loginService;
  final ModuloEmbarque moduloEmbarque;
  final RotaDoDiaService rotaDoDiaService;

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
        telaDoMotorista: (_) => TelaRotaDoDia(
          modulo: moduloEmbarque,
          rotaDoDiaService: rotaDoDiaService,
        ),
        telaDoResponsavel: (usuario) => TelaAvisos(usuario: usuario),
      ),
    );
  }
}
