import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';
import 'package:vantrack_backend/cadastro/dominio/aluno.dart';
import 'package:vantrack_backend/compartilhado/aplicacao/excecoes.dart';
import 'package:vantrack_backend/notificacao/aplicacao/avisos_service.dart';
import 'package:vantrack_backend/notificacao/dominio/notificacao.dart';
import 'package:vantrack_backend/notificacao/dominio/notificacao_repository.dart';

class _Repositorio extends Mock implements NotificacaoRepository {}

/// VT-45, UC-I02/RF-011: consulta por destinatário e leitura restrita (RN-002).
void main() {
  late _Repositorio repositorio;
  late AvisosService service;
  late Notificacao aviso;

  setUp(() {
    repositorio = _Repositorio();
    service = AvisosService(repositorio);
    aviso = Notificacao(
      id: 10,
      tipo: TipoMovimentacao.embarque,
      responsavelId: 1,
      aluno: Aluno(id: 1, nome: 'Ana Souza', dataNascimento: DateTime(2014)),
      mensagem: 'Ana Souza embarcou na van às 06:42.',
      dataHoraEvento: DateTime.parse('2026-11-16T06:42:10-03:00'),
    );
  });

  test('consulta repassa somente o destinatário informado e o filtro desde',
      () async {
    final desde = DateTime.parse('2026-11-16T06:00:00-03:00');
    when(() => repositorio.buscarDoResponsavel(1, desde))
        .thenAnswer((_) async => [aviso]);

    expect(await service.listarDoResponsavel(1, desde), [aviso]);
    verify(() => repositorio.buscarDoResponsavel(1, desde)).called(1);
    verifyNoMoreInteractions(repositorio);
  });

  test('destinatário marca o aviso como lido e pode repetir a operação',
      () async {
    when(() => repositorio.buscarPorId(10)).thenAnswer((_) async => aviso);
    when(() => repositorio.salvar(aviso)).thenAnswer((_) async {});

    await service.marcarComoLida(10, 1);
    await service.marcarComoLida(10, 1);

    expect(aviso.lida, isTrue);
    verify(() => repositorio.salvar(aviso)).called(2);
  });

  test('outra família não altera nem salva o aviso (RN-002)', () async {
    when(() => repositorio.buscarPorId(10)).thenAnswer((_) async => aviso);

    await expectLater(
      service.marcarComoLida(10, 3),
      throwsA(isA<AcessoNegadoException>()),
    );

    expect(aviso.lida, isFalse);
    verify(() => repositorio.buscarPorId(10)).called(1);
    verifyNoMoreInteractions(repositorio);
  });

  test('aviso inexistente não é salvo e gera erro de não encontrado', () async {
    when(() => repositorio.buscarPorId(99)).thenAnswer((_) async => null);

    await expectLater(
      service.marcarComoLida(99, 1),
      throwsA(isA<NaoEncontradoException>()),
    );

    verify(() => repositorio.buscarPorId(99)).called(1);
    verifyNoMoreInteractions(repositorio);
  });
}
