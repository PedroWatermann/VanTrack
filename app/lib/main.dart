import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'avisos/aplicacao/avisos_service.dart';
import 'avisos/apresentacao/tela_avisos.dart';
import 'avisos/infraestrutura/avisos_api.dart';
import 'compartilhado/api_client.dart';
import 'compartilhado/cores.dart';
import 'compartilhado/sessao.dart';
import 'compartilhado/sessao_salva.dart';
import 'embarque/aplicacao/modulo_embarque.dart';
import 'embarque/aplicacao/modulo_embarque_com_fila.dart';
import 'embarque/aplicacao/rota_do_dia_service.dart';
import 'embarque/apresentacao/tela_rota_do_dia.dart';
import 'embarque/infraestrutura/armazenamento_local.dart';
import 'embarque/infraestrutura/embarque_api.dart';
import 'embarque/infraestrutura/localizador_geolocator.dart';
import 'embarque/infraestrutura/monitor_conectividade.dart';
import 'embarque/infraestrutura/rota_salva_local.dart';
import 'login/aplicacao/login_service.dart';
import 'login/apresentacao/tela_login.dart';

/// Ponto de entrada do app VanTrack (UC-S05 Registrar Embarque).
///
/// Roda no Android e na Web (RNF-004). É aqui que as peças do app são
/// criadas e ligadas umas às outras.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // A sessão fica guardada no aparelho: quem já entrou abre o app direto na
  // sua tela, mesmo sem conexão (Bug VT-75).
  final sessao = Sessao(SessaoSalva());
  await sessao.restaurar();
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
    // A fila é do aparelho: cada motorista só vê e sincroniza os embarques
    // que ele registrou (Bug VT-76).
    motoristaLogado: () {
      final usuario = sessao.usuario;
      return usuario?.papel == Papel.motorista ? usuario!.id : null;
    },
  );

  runApp(VanTrackApp(
    loginService: LoginService(api: api, sessao: sessao),
    moduloEmbarque: moduloEmbarque,
    // Guarda a última rota de hoje, para abrir sem conexão (Bug VT-75).
    rotaDoDiaService: RotaDoDiaService(embarqueApi, salva: RotaSalvaLocal()),
    online: monitorConectividade.online,
  ));
}

/// Configuração geral do app: título, tema e tela inicial.
///
/// A tela inicial é o login. Se já houver alguém logado (sessão guardada no
/// aparelho), o app abre direto na tela dele, e o botão "Sair" volta ao login
/// (Bug VT-75).
class VanTrackApp extends StatefulWidget {
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
  State<VanTrackApp> createState() => _VanTrackAppState();
}

class _VanTrackAppState extends State<VanTrackApp> {
  final _navegador = GlobalKey<NavigatorState>();

  /// Tela aberta ao iniciar: a do usuário logado ou, se não houver, o login.
  late final Widget _telaInicial = _telaDe(widget.loginService.sessao.usuario);

  Widget _telaDe(UsuarioLogado? usuario) => switch (usuario?.papel) {
        null => _telaLogin(),
        Papel.motorista => _telaDoMotorista(usuario!),
        Papel.responsavel => _telaDoResponsavel(usuario!),
      };

  Widget _telaLogin() => TelaLogin(
        loginService: widget.loginService,
        telaDoMotorista: _telaDoMotorista,
        telaDoResponsavel: _telaDoResponsavel,
      );

  Widget _telaDoMotorista(UsuarioLogado _) => TelaRotaDoDia(
        modulo: widget.moduloEmbarque,
        rotaDoDiaService: widget.rotaDoDiaService,
        online: widget.online,
        aoSair: _sair,
      );

  Widget _telaDoResponsavel(UsuarioLogado usuario) => EscopoAvisos(
        service: AvisosService(AvisosApi(widget.loginService.api)),
        child: TelaAvisos(usuario: usuario, aoSair: _sair),
      );

  /// Sai do app: apaga a sessão guardada e volta ao login. Se quem sai é o
  /// motorista, a rota guardada dele também é apagada: outro usuário não pode
  /// vê-la.
  Future<void> _sair() async {
    final eraMotorista = widget.loginService.sessao.usuario?.papel == Papel.motorista;
    await widget.loginService.sair();
    if (eraMotorista) await widget.rotaDoDiaService.esquecer();
    _navegador.currentState?.pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => _telaLogin()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'VanTrack',
      debugShowCheckedModeBanner: false,
      navigatorKey: _navegador,
      theme: ThemeData(
        colorSchemeSeed: CoresApp.verde,
        useMaterial3: true,
      ),
      home: _telaInicial,
    );
  }
}
