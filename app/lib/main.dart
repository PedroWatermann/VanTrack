import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'avisos/aplicacao/avisos_service.dart';
import 'avisos/apresentacao/tela_avisos.dart';
import 'avisos/infraestrutura/avisos_api.dart';
import 'compartilhado/api_client.dart';
import 'compartilhado/cores.dart';
import 'compartilhado/sessao.dart';
import 'embarque/aplicacao/modulo_embarque.dart';
import 'embarque/aplicacao/modulo_embarque_com_fila.dart';
import 'embarque/aplicacao/rota_do_dia_service.dart';
import 'embarque/apresentacao/tela_rota_do_dia.dart';
import 'embarque/infraestrutura/armazenamento_local.dart';
import 'embarque/infraestrutura/embarque_api.dart';
import 'embarque/infraestrutura/localizador_geolocator.dart';
import 'embarque/infraestrutura/monitor_conectividade.dart';
import 'login/aplicacao/login_service.dart';
import 'login/apresentacao/tela_login.dart';

/// Ponto de entrada do app VanTrack (UC-S05 Registrar Embarque).
///
/// Roda no Android e na Web (RNF-004). É aqui que as peças do app são
/// criadas e ligadas umas às outras.
void main() {
  WidgetsFlutterBinding.ensureInitialized();

  final sessao = Sessao();
  final api = ApiClient(sessao: sessao);

  final embarqueApi = EmbarqueApi(api);
  final monitorConectividade = MonitorConectividade()
    ..verificarConectividade();

  // Implementação do módulo de embarque usada pelo app (com fila offline, RNF-006).
  final ModuloEmbarque moduloEmbarque = ModuloEmbarqueComFila(
    remoto: embarqueApi,
    fila: ArmazenamentoLocal(),
    conectividade: monitorConectividade,
    localizador: LocalizadorGeolocator(),
  );

  runApp(VanTrackApp(
    loginService: LoginService(api: api, sessao: sessao),
    moduloEmbarque: moduloEmbarque,
    rotaDoDiaService: RotaDoDiaService(embarqueApi),
    online: monitorConectividade.online,
  ));
}

/// Configuração geral do app: título, tema e tela inicial (login).
class VanTrackApp extends StatelessWidget {
  const VanTrackApp({
    super.key,
    required this.loginService,
    required this.moduloEmbarque,
    required this.rotaDoDiaService,
    this.online,
  });

  final LoginService loginService;
  final ModuloEmbarque moduloEmbarque;
  final RotaDoDiaService rotaDoDiaService;

  /// Estado da conectividade do aparelho para exibir a `FaixaSemConexao` (RNF-003).
  final ValueListenable<bool>? online;

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
          online: online,
        ),
        telaDoResponsavel: (usuario) => EscopoAvisos(
          service: AvisosService(AvisosApi(loginService.api)),
          child: TelaAvisos(usuario: usuario),
        ),
      ),
    );
  }
}
