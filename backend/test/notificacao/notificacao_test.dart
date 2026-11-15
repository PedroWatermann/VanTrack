import 'package:mocktail/mocktail.dart';
import 'package:postgres/postgres.dart';
import 'package:test/test.dart';
import 'package:vantrack_backend/cadastro/dominio/aluno.dart';
import 'package:vantrack_backend/cadastro/dominio/responsavel.dart';
import 'package:vantrack_backend/compartilhado/infraestrutura/conexao_banco.dart';
import 'package:vantrack_backend/notificacao/dominio/notificacao.dart';
import 'package:vantrack_backend/notificacao/infraestrutura/notificacao_repository_postgres.dart';

class _Banco extends Mock implements ConexaoBanco {}

Result _resultado(List<List<Object?>> valores) {
  final schema = ResultSchema([]);
  return Result(rows: [
    for (final valoresLinha in valores)
      ResultRow(values: valoresLinha, schema: schema),
  ], affectedRows: valores.length, schema: schema);
}

void main() {
  final aluno =
      Aluno(id: 1, nome: 'Ana Souza', dataNascimento: DateTime(2014, 3, 10));
  final responsavel = Responsavel(
      id: 1, nome: 'Maria', login: 'maria', telefone: '', email: '');
  final horario = DateTime.parse('2026-11-14T09:42:10Z');
  Notificacao criar() => Notificacao.deEmbarque(responsavel, aluno, horario);

  test('fábrica usa as entidades do cadastro e o horário original do embarque',
      () {
    final notificacao = criar();
    expect(notificacao.id, isNull);
    expect(notificacao.tipo, TipoMovimentacao.embarque);
    expect(notificacao.responsavelId, responsavel.id);
    expect(notificacao.alunoId, aluno.id);
    expect(notificacao.lida, isFalse);
    expect(notificacao.mensagem, 'Ana Souza embarcou na van às 06:42.');
    expect(notificacao.dataHoraEvento, horario);
    expect(notificacao.dataHoraEvento.isUtc, isTrue);
  });

  final horarios = {
    '2026-11-14T06:42:10-03:00': '06:42',
    '2026-11-14T11:42:10+02:00': '06:42',
    '2026-11-15T00:05:00Z': '21:05',
    '2001-01-01T07:05:00Z': '04:05',
  };
  for (final caso in horarios.entries) {
    test('mensagem converte ${caso.key} para Brasília, sem usar a hora atual',
        () {
      final evento = DateTime.parse(caso.key);
      final notificacao = Notificacao.deEmbarque(responsavel, aluno, evento);
      expect(
          notificacao.mensagem, 'Ana Souza embarcou na van às ${caso.value}.');
      expect(notificacao.dataHoraEvento.isAtSameMomentAs(evento), isTrue);
    });
  }

  test('marcar como lida altera apenas o estado de leitura e pode ser repetido',
      () {
    final notificacao = criar();
    notificacao.marcarComoLida();
    notificacao.marcarComoLida();
    expect(notificacao.lida, isTrue);
    expect(notificacao.mensagem, 'Ana Souza embarcou na van às 06:42.');
    expect(notificacao.dataHoraEvento, horario);
  });

  test('pertenceA identifica somente o destinatário (RN-002)', () {
    expect(criar().pertenceA(1), isTrue);
    expect(criar().pertenceA(2), isFalse);
  });

  group('repositório Postgres', () {
    late _Banco banco;
    late NotificacaoRepositoryPostgres repositorio;
    setUp(() {
      banco = _Banco();
      repositorio = NotificacaoRepositoryPostgres(banco);
    });

    test('consulta parametriza destinatário/data e recupera o estado salvo',
        () async {
      when(() => banco.executar(any(), any()))
          .thenAnswer((_) async => _resultado([
                [77, 'EMBARQUE', 1, 1, 'Mensagem armazenada.', horario, true],
              ]));
      final desde = horario.subtract(const Duration(minutes: 1));
      final lista = await repositorio.buscarDoResponsavel(1, desde);
      expect(lista.single.id, 77);
      expect(lista.single.mensagem, 'Mensagem armazenada.');
      expect(lista.single.dataHoraEvento, horario);
      expect(lista.single.lida, isTrue);
      final argumentos =
          verify(() => banco.executar(captureAny(), captureAny())).captured;
      expect(argumentos[0], contains('responsavel_id = @responsavel'));
      expect(argumentos[0], contains('data_hora_evento > @desde'));
      expect(argumentos[1], {'responsavel': 1, 'desde': desde.toUtc()});
    });

    test('buscar id inexistente devolve nulo', () async {
      when(() => banco.executar(any(), any()))
          .thenAnswer((_) async => _resultado([]));
      expect(await repositorio.buscarPorId(999), isNull);
      verify(() => banco.executar(any(), {'id': 999})).called(1);
    });

    test('salvar persiste a leitura sem reescrever mensagem ou destinatário',
        () async {
      when(() => banco.executar(any(), any()))
          .thenAnswer((_) async => _resultado([]));
      final notificacao = Notificacao(
        id: 77,
        tipo: TipoMovimentacao.embarque,
        responsavelId: 1,
        alunoId: 1,
        mensagem: 'Mensagem armazenada.',
        dataHoraEvento: horario,
      )..marcarComoLida();
      await repositorio.salvar(notificacao);
      final argumentos =
          verify(() => banco.executar(captureAny(), captureAny())).captured;
      expect(argumentos[0], isNot(contains('mensagem')));
      expect(argumentos[1], {'id': 77, 'lida': true});
    });

    test('salvar exige uma notificação já persistida', () async {
      await expectLater(repositorio.salvar(criar()), throwsArgumentError);
      verifyZeroInteractions(banco);
    });
  });
}
