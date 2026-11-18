import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';
import 'package:vantrack_backend/cadastro/dominio/aluno.dart';
import 'package:vantrack_backend/cadastro/dominio/responsavel.dart';
import 'package:vantrack_backend/cadastro/dominio/vinculo_repository.dart';
import 'package:vantrack_backend/notificacao/aplicacao/notificacao_service.dart';
import 'package:vantrack_backend/notificacao/aplicacao/notificacao_service_padrao.dart';
import 'package:vantrack_backend/notificacao/dominio/notificacao.dart';
import 'package:vantrack_backend/notificacao/dominio/notificacao_repository.dart';
import 'package:vantrack_backend/rota/dominio/localizacao.dart';
import 'package:vantrack_backend/rota/dominio/ponto_parada.dart';
import 'package:vantrack_backend/rota/dominio/presenca.dart';

class MockVinculoRepository extends Mock implements VinculoRepository {}

class MockNotificacaoRepository extends Mock implements NotificacaoRepository {}

/// VT-44: fluxo principal e A1 do UC-I02, RN-002/RN-009 e hora offline (RNF-006).
void main() {
  late MockVinculoRepository vinculos;
  late MockNotificacaoRepository notificacoes;
  late NotificacaoService servico;

  final horaEmbarque = DateTime.parse('2026-11-16T06:42:10-03:00');

  Presenca criarPresenca({int alunoId = 1, String nome = 'Ana Souza'}) =>
      Presenca(
        id: alunoId,
        rotaId: 1,
        aluno: Aluno(
          id: alunoId,
          nome: nome,
          dataNascimento: DateTime(alunoId == 3 ? 2000 : 2014, 3, 10),
        ),
        pontoParada: PontoParada(
          id: 1,
          endereco: 'Rua das Acácias, 100',
          localizacao:
              const Localizacao(latitude: -23.4205, longitude: -51.9331),
        ),
        ordem: 1,
        situacao: SituacaoPresenca.confirmado,
      );

  Responsavel criarResponsavel(int id, String nome) => Responsavel(
        id: id,
        nome: nome,
        login: 'responsavel$id',
        telefone: '44999990000',
        email: 'responsavel$id@example.com',
      );

  setUp(() {
    vinculos = MockVinculoRepository();
    notificacoes = MockNotificacaoRepository();
    servico = NotificacaoServicePadrao(
      vinculoRepository: vinculos,
      notificacaoRepository: notificacoes,
    );
    when(() => notificacoes.registrarComunicado(any()))
        .thenAnswer((_) async {});
  });

  test('Ana com dois responsáveis gera dois avisos com a hora do embarque',
      () async {
    final presenca = criarPresenca();
    presenca.registrarEmbarque(
      '2b1f0c3e-8a4d-4f6e-9c1a-7d2e5b8f0a11',
      horaEmbarque,
    );
    final embarque = presenca.embarque;
    when(() => vinculos.buscarResponsaveis(1)).thenAnswer((_) async => [
          criarResponsavel(1, 'Maria Souza'),
          criarResponsavel(2, 'João Souza'),
        ]);

    await servico.notificarMovimentacao(presenca, TipoMovimentacao.embarque);

    final avisos = verify(() => notificacoes.registrarComunicado(captureAny()))
        .captured
        .single as List<Notificacao>;
    expect(avisos, hasLength(2));
    expect(avisos.map((aviso) => aviso.responsavelId), [1, 2]);
    for (final aviso in avisos) {
      expect(aviso.alunoId, 1);
      expect(aviso.tipo, TipoMovimentacao.embarque);
      expect(aviso.mensagem, 'Ana Souza embarcou na van às 06:42.');
      expect(aviso.dataHoraEvento, horaEmbarque.toUtc());
      expect(aviso.lida, isFalse);
    }
    expect(presenca.embarque, same(embarque));
    verify(() => vinculos.buscarResponsaveis(1)).called(1);
    verifyNoMoreInteractions(vinculos);
    verifyNoMoreInteractions(notificacoes);
  });

  test('Carlos sem responsável retorna sem erro e não registra comunicado',
      () async {
    final presenca = criarPresenca(alunoId: 3, nome: 'Carlos Lima');
    presenca.registrarEmbarque(
      '5ef62da5-0d88-4354-b419-dd738e03a033',
      horaEmbarque,
    );
    when(() => vinculos.buscarResponsaveis(3)).thenAnswer((_) async => []);

    await expectLater(
      servico.notificarMovimentacao(presenca, TipoMovimentacao.embarque),
      completes,
    );

    verify(() => vinculos.buscarResponsaveis(3)).called(1);
    verifyZeroInteractions(notificacoes);
  });

  test('falha ao gravar o comunicado é devolvida ao chamador', () async {
    final presenca = criarPresenca();
    presenca.registrarEmbarque(
      '2b1f0c3e-8a4d-4f6e-9c1a-7d2e5b8f0a11',
      horaEmbarque,
    );
    when(() => vinculos.buscarResponsaveis(1))
        .thenAnswer((_) async => [criarResponsavel(1, 'Maria Souza')]);
    final erro = StateError('Falha ao registrar comunicado.');
    when(() => notificacoes.registrarComunicado(any()))
        .thenAnswer((_) async => throw erro);

    await expectLater(
      servico.notificarMovimentacao(presenca, TipoMovimentacao.embarque),
      throwsA(same(erro)),
    );
  });

  test('presença sem embarque não gera aviso', () async {
    await expectLater(
      servico.notificarMovimentacao(criarPresenca(), TipoMovimentacao.embarque),
      throwsA(isA<StateError>()),
    );
    verifyZeroInteractions(vinculos);
    verifyZeroInteractions(notificacoes);
  });

  test('desembarque não é registrado como aviso de embarque', () async {
    await expectLater(
      servico.notificarMovimentacao(
          criarPresenca(), TipoMovimentacao.desembarque),
      throwsA(isA<UnsupportedError>()),
    );
    verifyZeroInteractions(vinculos);
    verifyZeroInteractions(notificacoes);
  });
}
