import 'package:dart_frog/dart_frog.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';
import 'package:vantrack_backend/cadastro/aplicacao/aluno_service.dart';
import 'package:vantrack_backend/cadastro/apresentacao/aluno_controller.dart';
import 'package:vantrack_backend/cadastro/dominio/aluno.dart';
import 'package:vantrack_backend/cadastro/dominio/usuario.dart';
import 'package:vantrack_backend/cadastro/dominio/vinculo_repository.dart';
import 'package:vantrack_backend/compartilhado/apresentacao/usuario_logado.dart';

class _Vinculos extends Mock implements VinculoRepository {}

/// Testes da task VT-70: `GET /alunos` devolve os alunos do responsável logado
/// (RN-002), para a tela "Avisos" mostrar quem ainda não embarcou.
void main() {
  const maria = UsuarioLogado(id: 1, papel: Papel.responsavel);
  const semAluno = UsuarioLogado(id: 99, papel: Papel.responsavel);
  const motorista = UsuarioLogado(id: 1, papel: Papel.motorista);
  final uri = Uri.parse('http://localhost/alunos');

  final ana = Aluno(id: 1, nome: 'Ana Souza', dataNascimento: DateTime(2014));

  late _Vinculos vinculos;
  late AlunoController controller;

  setUp(() {
    vinculos = _Vinculos();
    controller = AlunoController(AlunoService(vinculos));
    when(() => vinculos.buscarAlunosDoResponsavel(1))
        .thenAnswer((_) async => [ana]);
    when(() => vinculos.buscarAlunosDoResponsavel(99))
        .thenAnswer((_) async => []);
  });

  test('responsável recebe os seus alunos no formato combinado', () async {
    final resposta =
        await controller.listarDoResponsavel(Request.get(uri), maria);

    expect(resposta.statusCode, 200);
    expect(await resposta.json(), [
      {'alunoId': 1, 'nome': 'Ana Souza'},
    ]);
  });

  test('a consulta usa o id do token, não um parâmetro da requisição (RN-002)',
      () async {
    await controller.listarDoResponsavel(
      Request.get(Uri.parse('http://localhost/alunos?responsavelId=3')),
      maria,
    );

    verify(() => vinculos.buscarAlunosDoResponsavel(1)).called(1);
    verifyNever(() => vinculos.buscarAlunosDoResponsavel(3));
  });

  test('responsável sem aluno vinculado recebe lista vazia', () async {
    final resposta =
        await controller.listarDoResponsavel(Request.get(uri), semAluno);

    expect(resposta.statusCode, 200);
    expect(await resposta.json(), isEmpty);
  });

  test('motorista recebe 403 sem consultar o banco', () async {
    final resposta =
        await controller.listarDoResponsavel(Request.get(uri), motorista);

    expect(resposta.statusCode, 403);
    verifyZeroInteractions(vinculos);
  });

  test('método diferente de GET recebe 405', () async {
    final resposta =
        await controller.listarDoResponsavel(Request.post(uri), maria);

    expect(resposta.statusCode, 405);
  });
}
