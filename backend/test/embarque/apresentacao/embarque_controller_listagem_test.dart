import 'package:dart_frog/dart_frog.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';
import 'package:vantrack_backend/cadastro/dominio/aluno.dart';
import 'package:vantrack_backend/cadastro/dominio/usuario.dart';
import 'package:vantrack_backend/cadastro/dominio/van.dart';
import 'package:vantrack_backend/compartilhado/aplicacao/excecoes.dart';
import 'package:vantrack_backend/compartilhado/apresentacao/usuario_logado.dart';
import 'package:vantrack_backend/embarque/aplicacao/embarque_service.dart';
import 'package:vantrack_backend/embarque/apresentacao/embarque_controller.dart';
import 'package:vantrack_backend/rota/dominio/localizacao.dart';
import 'package:vantrack_backend/rota/dominio/ponto_parada.dart';
import 'package:vantrack_backend/rota/dominio/presenca.dart';
import 'package:vantrack_backend/rota/dominio/rota.dart';

class _Service extends Mock implements EmbarqueService {}

/// Testes da task A-08 (VT-31): `EmbarqueController.listarAlunos` e
/// `buscarRotaDoDia`, com as respostas no formato da seção 3 do backlog.
void main() {
  const motorista = UsuarioLogado(id: 1, papel: Papel.motorista);
  const responsavel = UsuarioLogado(id: 1, papel: Papel.responsavel);
  final alunos = Uri.parse('http://localhost/rotas/1/alunos');
  final hoje = Uri.parse('http://localhost/rotas/hoje');

  final ana = Presenca(
    id: 1,
    rotaId: 1,
    aluno: Aluno(id: 1, nome: 'Ana Souza', dataNascimento: DateTime(2014)),
    pontoParada: PontoParada(
      id: 1,
      endereco: 'Rua das Acácias, 100',
      localizacao: const Localizacao(latitude: -23.4205, longitude: -51.9331),
    ),
    ordem: 1,
    situacao: SituacaoPresenca.confirmado,
  );

  final rota = Rota(
    id: 1,
    van: Van(id: 1, placa: 'ABC-1D23', modelo: 'Sprinter', capacidade: 15),
    data: DateTime(2026, 11, 16),
    trajeto: Trajeto.ida,
    horarioPrevisto: DateTime.parse('2026-11-16T06:30:00-03:00'),
    situacao: 'ATIVA',
  );

  late _Service service;
  late EmbarqueController controller;

  setUp(() {
    service = _Service();
    controller = EmbarqueController(service);
  });

  group('GET /rotas/{rotaId}/alunos', () {
    test('200 no formato exato da seção 3 do backlog', () async {
      when(() => service.listarAlunosConfirmados(1, 1))
          .thenAnswer((_) async => [ana]);

      final resposta =
          await controller.listarAlunos('1', Request.get(alunos), motorista);

      expect(resposta.statusCode, 200);
      expect(await resposta.json(), [
        {
          'alunoId': 1,
          'nome': 'Ana Souza',
          'ordem': 1,
          'pontoParada': {
            'endereco': 'Rua das Acácias, 100',
            'latitude': -23.4205,
            'longitude': -51.9331,
          },
          'status': 'CONFIRMADO',
        },
      ]);
    });

    test('motorista sem vínculo recebe 403 com a mensagem da tela', () async {
      when(() => service.listarAlunosConfirmados(1, 1)).thenThrow(
        const AcessoNegadoException('Você não é o motorista ativo desta van.'),
      );

      final resposta =
          await controller.listarAlunos('1', Request.get(alunos), motorista);

      expect(resposta.statusCode, 403);
      expect(await resposta.json(), {
        'erro': 'Você não é o motorista ativo desta van.',
      });
    });

    test('responsável recebe 403 sem chamar o service', () async {
      final resposta =
          await controller.listarAlunos('1', Request.get(alunos), responsavel);

      expect(resposta.statusCode, 403);
      verifyZeroInteractions(service);
    });

    test('rota que não existe ou rotaId inválido recebe 404', () async {
      when(() => service.listarAlunosConfirmados(99, 1)).thenThrow(
        const NaoEncontradoException('Rota não encontrada.'),
      );

      final inexistente =
          await controller.listarAlunos('99', Request.get(alunos), motorista);
      final invalido =
          await controller.listarAlunos('abc', Request.get(alunos), motorista);

      expect(inexistente.statusCode, 404);
      expect(invalido.statusCode, 404);
    });

    test('método diferente de GET recebe 405', () async {
      final resposta =
          await controller.listarAlunos('1', Request.post(alunos), motorista);

      expect(resposta.statusCode, 405);
    });
  });

  group('GET /rotas/hoje', () {
    test('200 com rotaId, trajeto, horário em Brasília e placa', () async {
      when(() => service.buscarRotaDoDia(1)).thenAnswer((_) async => rota);

      final resposta =
          await controller.buscarRotaDoDia(Request.get(hoje), motorista);

      expect(resposta.statusCode, 200);
      expect(await resposta.json(), {
        'rotaId': 1,
        'trajeto': 'IDA',
        'horarioPrevisto': '2026-11-16T06:30:00-03:00',
        'placa': 'ABC-1D23',
      });
    });

    test('motorista sem rota hoje recebe 404', () async {
      when(() => service.buscarRotaDoDia(1)).thenThrow(
        const NaoEncontradoException('Motorista sem rota hoje.'),
      );

      final resposta =
          await controller.buscarRotaDoDia(Request.get(hoje), motorista);

      expect(resposta.statusCode, 404);
    });

    test('responsável recebe 403', () async {
      final resposta =
          await controller.buscarRotaDoDia(Request.get(hoje), responsavel);

      expect(resposta.statusCode, 403);
      verifyZeroInteractions(service);
    });
  });
}
