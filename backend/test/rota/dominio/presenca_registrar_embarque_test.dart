import 'package:test/test.dart';
import 'package:vantrack_backend/cadastro/dominio/aluno.dart';
import 'package:vantrack_backend/rota/dominio/excecoes.dart';
import 'package:vantrack_backend/rota/dominio/localizacao.dart';
import 'package:vantrack_backend/rota/dominio/ponto_parada.dart';
import 'package:vantrack_backend/rota/dominio/presenca.dart';

/// Testes da task B-04 (VT-33): `Presenca.registrarEmbarque` (RN-010, RF-009,
/// UC-S05 passos 3 e 4).
void main() {
  Presenca presenca(SituacaoPresenca situacao) => Presenca(
        id: 1,
        rotaId: 1,
        aluno: Aluno(
          id: 1,
          nome: 'Ana Souza',
          dataNascimento: DateTime(2014, 3, 10),
        ),
        pontoParada: PontoParada(
          id: 1,
          endereco: 'Rua das Acácias, 100',
          localizacao:
              const Localizacao(latitude: -23.4205, longitude: -51.9331),
        ),
        ordem: 1,
        situacao: situacao,
      );

  const registroId = '2b1f0c3e-8a4d-4f6e-9c1a-7d2e5b8f0a11';
  final horaDoToque = DateTime.parse('2026-11-16T06:42:10-03:00');
  const localDoToque = Localizacao(latitude: -23.40, longitude: -51.93);

  group('Presenca.registrarEmbarque com presença CONFIRMADO', () {
    test('embarca: muda para EMBARCADO e devolve o Embarque', () {
      final p = presenca(SituacaoPresenca.confirmado);

      final embarque =
          p.registrarEmbarque(registroId, horaDoToque, localDoToque);

      expect(p.situacao, SituacaoPresenca.embarcado);
      expect(p.estaConfirmada(), isFalse);
      expect(p.embarque, same(embarque));
      expect(embarque.registroId, registroId);
      expect(embarque.localizacao, localDoToque);
      expect(embarque.id, isNull, reason: 'ainda não foi gravado no banco');
    });

    test('guarda a hora do toque enviada, não a hora atual', () {
      final p = presenca(SituacaoPresenca.confirmado);

      final embarque = p.registrarEmbarque(registroId, horaDoToque);

      expect(embarque.dataHora, horaDoToque);
      expect(embarque.dataHora.toUtc(), DateTime.utc(2026, 11, 16, 9, 42, 10));
    });

    test('embarca sem localização quando o GPS não respondeu', () {
      final p = presenca(SituacaoPresenca.confirmado);

      final embarque = p.registrarEmbarque(registroId, horaDoToque);

      expect(embarque.localizacao, isNull);
      expect(p.situacao, SituacaoPresenca.embarcado);
    });
  });

  group('Presenca.registrarEmbarque fora de CONFIRMADO (RN-010)', () {
    test('AUSENTE lança a exceção e não cria embarque', () {
      final p = presenca(SituacaoPresenca.ausente);

      expect(
        () => p.registrarEmbarque(registroId, horaDoToque),
        throwsA(
          isA<EmbarqueNaoPermitidoException>().having(
            (e) => e.situacaoAtual,
            'situacaoAtual',
            SituacaoPresenca.ausente,
          ),
        ),
      );
      expect(p.situacao, SituacaoPresenca.ausente);
      expect(p.embarque, isNull);
    });

    test('EMBARCADO lança a exceção e mantém o embarque anterior', () {
      final p = presenca(SituacaoPresenca.confirmado);
      final primeiro = p.registrarEmbarque(registroId, horaDoToque);

      expect(
        () => p.registrarEmbarque(
          '9f8e7d6c-5b4a-4f3e-8d2c-1b0a9f8e7d6c',
          horaDoToque.add(const Duration(minutes: 5)),
        ),
        throwsA(
          isA<EmbarqueNaoPermitidoException>().having(
            (e) => e.situacaoAtual,
            'situacaoAtual',
            SituacaoPresenca.embarcado,
          ),
        ),
      );
      expect(p.situacao, SituacaoPresenca.embarcado);
      expect(p.embarque, same(primeiro));
    });

    test('presença carregada já EMBARCADO também lança a exceção', () {
      final p = presenca(SituacaoPresenca.embarcado);

      expect(
        () => p.registrarEmbarque(registroId, horaDoToque),
        throwsA(isA<EmbarqueNaoPermitidoException>()),
      );
    });
  });
}
