import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:app/compartilhado/api_client.dart';
import 'package:app/compartilhado/mock/dados_mock.dart';
import 'package:app/compartilhado/sessao.dart';
import 'package:app/compartilhado/sessao_salva.dart';
import 'package:app/embarque/aplicacao/modulo_embarque.dart';
import 'package:app/embarque/aplicacao/rota_do_dia_service.dart';
import 'package:app/embarque/dominio/aluno_da_rota.dart';
import 'package:app/embarque/dominio/rota_do_dia.dart';
import 'package:app/embarque/infraestrutura/embarque_api.dart';
import 'package:app/embarque/infraestrutura/rota_salva_local.dart';
import 'package:app/login/aplicacao/login_service.dart';
import 'package:app/main.dart';

/// Módulo de embarque falso, com a Beatriz pendente na fila (teste 8).
class _ModuloComBeatrizPendente implements ModuloEmbarque {
  @override
  Future<ResultadoEmbarque> registrarEmbarque(int rotaId, int alunoId) =>
      throw UnimplementedError();

  @override
  Future<List<RegistroPendente>> listarPendentes(int rotaId) async =>
      [RegistroPendente('r-beatriz', 2, DateTime(2026, 11, 24, 21, 15))];

  @override
  Stream<EventoPendente> get aoMudarPendentes => const Stream.empty();
}

/// Bug VT-75: a sessão fica guardada no aparelho.
void main() {
  const joao = UsuarioLogado(id: 1, nome: 'João Pereira', papel: Papel.motorista);
  const ricardo = UsuarioLogado(id: 4, nome: 'Ricardo Alves', papel: Papel.responsavel);

  setUp(() => SharedPreferences.setMockInitialValues({}));

  /// Abre o app como o main.dart: restaura a sessão guardada antes.
  Future<Sessao> abrirApp(
    WidgetTester tester, {
    required ApiClient Function(Sessao) api,
    ModuloEmbarque? modulo,
  }) async {
    final sessao = Sessao(SessaoSalva());
    await sessao.restaurar();
    final cliente = api(sessao);
    await tester.pumpWidget(VanTrackApp(
      loginService: LoginService(api: cliente, sessao: sessao),
      moduloEmbarque: modulo ?? _ModuloComBeatrizPendente(),
      rotaDoDiaService: RotaDoDiaService(EmbarqueApi(cliente), salva: RotaSalvaLocal()),
    ));
    await tester.pumpAndSettle();
    return sessao;
  }

  testWidgets(
    'teste 9: motorista logado abre o app sem conexão e vê a rota e o pendente',
    (tester) async {
      await Sessao(SessaoSalva()).entrar(joao, 'token-do-joao');
      final hoje = DateTime.now();
      await RotaSalvaLocal().guardar((
        dia: '${hoje.year}-${hoje.month.toString().padLeft(2, '0')}-'
            '${hoje.day.toString().padLeft(2, '0')}',
        rota: RotaDoDia(
          rotaId: 1,
          trajeto: 'IDA',
          horarioPrevisto: DateTime.parse('2026-11-24T06:30:00-03:00'),
          placa: 'ABC-1D23',
        ),
        alunos: const [
          AlunoDaRota(alunoId: 1, nome: 'Ana Souza', ordem: 1, endereco: 'Rua 1', embarcado: true),
          AlunoDaRota(alunoId: 2, nome: 'Beatriz Reis', ordem: 2, endereco: 'Rua 2', embarcado: false),
          AlunoDaRota(alunoId: 3, nome: 'Carlos Lima', ordem: 3, endereco: 'Rua 3', embarcado: true),
        ],
      ));

      // Servidor fora do ar: toda requisição falha como sem conexão.
      await abrirApp(
        tester,
        api: (sessao) => ApiClient(
          sessao: sessao,
          usarMock: false,
          cliente: MockClient((_) async => throw http.ClientException('sem conexão')),
        ),
      );

      expect(find.text('Quem está usando o app?'), findsNothing);
      expect(find.textContaining('Rota do dia · Ida'), findsOneWidget);
      expect(find.text('Beatriz Reis'), findsOneWidget);
      expect(find.text('Pendente de sincronização'), findsOneWidget);
      expect(find.text('Não foi possível carregar a rota. Tente de novo.'), findsNothing);
    },
  );

  testWidgets('responsável logado abre direto em Avisos e "Sair" volta ao login',
      (tester) async {
    await Sessao(SessaoSalva()).entrar(ricardo, 'mock-RESPONSAVEL-4');

    final sessao = await abrirApp(
      tester,
      api: (sessao) => ApiClient(
        sessao: sessao,
        usarMock: true,
        mock: DadosMock(atraso: Duration.zero),
      ),
    );

    expect(find.text('Avisos'), findsOneWidget);
    expect(find.text('Bruno Alves'), findsOneWidget);

    await tester.tap(find.byTooltip('Sair'));
    await tester.pumpAndSettle();

    expect(find.text('Quem está usando o app?'), findsOneWidget);
    expect(sessao.logado, isFalse);
    expect(await Sessao(SessaoSalva()).restaurar(), isFalse);
  });

  testWidgets('sem sessão guardada, o app abre no login', (tester) async {
    await abrirApp(
      tester,
      api: (sessao) => ApiClient(
        sessao: sessao,
        usarMock: true,
        mock: DadosMock(atraso: Duration.zero),
      ),
    );

    expect(find.text('Quem está usando o app?'), findsOneWidget);
  });
}
