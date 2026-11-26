import 'package:test/test.dart';
import 'package:vantrack_backend/cadastro/dominio/aluno.dart';
import 'package:vantrack_backend/rota/dominio/localizacao.dart';
import 'package:vantrack_backend/rota/dominio/ponto_parada.dart';
import 'package:vantrack_backend/rota/dominio/presenca.dart';
import 'package:vantrack_backend/rota/dominio/rota.dart';

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

  group('Presenca.estaConfirmada', () {
    test('só a presença CONFIRMADO está confirmada', () {
      expect(presenca(SituacaoPresenca.confirmado).estaConfirmada(), isTrue);
      expect(presenca(SituacaoPresenca.ausente).estaConfirmada(), isFalse);
      expect(presenca(SituacaoPresenca.embarcado).estaConfirmada(), isFalse);
    });

    test('a situação é exposta só para leitura', () {
      expect(
        presenca(SituacaoPresenca.ausente).situacao,
        SituacaoPresenca.ausente,
      );
    });
  });

  group('Localizacao (value object)', () {
    test('é igual pelo valor, sem identidade', () {
      const a = Localizacao(latitude: -23.4, longitude: -51.9);
      const b = Localizacao(latitude: -23.4, longitude: -51.9);
      const c = Localizacao(latitude: -23.5, longitude: -51.9);

      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(c));
    });
  });

  group('códigos dos enums (banco e JSON)', () {
    test('SituacaoPresenca e Trajeto convertem o código', () {
      expect(SituacaoPresenca.deCodigo('AUSENTE'), SituacaoPresenca.ausente);
      expect(SituacaoPresenca.embarcado.codigo, 'EMBARCADO');
      expect(Trajeto.deCodigo('IDA'), Trajeto.ida);
      expect(Trajeto.volta.codigo, 'VOLTA');
    });
  });
}
