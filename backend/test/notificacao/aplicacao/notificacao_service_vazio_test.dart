import 'package:test/test.dart';
import 'package:vantrack_backend/cadastro/dominio/aluno.dart';
import 'package:vantrack_backend/notificacao/aplicacao/notificacao_service.dart';
import 'package:vantrack_backend/notificacao/aplicacao/notificacao_service_vazio.dart';
import 'package:vantrack_backend/notificacao/dominio/notificacao.dart';
import 'package:vantrack_backend/rota/dominio/localizacao.dart';
import 'package:vantrack_backend/rota/dominio/ponto_parada.dart';
import 'package:vantrack_backend/rota/dominio/presenca.dart';

/// Testes da task B-05 (VT-34): contrato `NotificacaoService` e a versão vazia.
void main() {
  Presenca presencaEmbarcada() {
    final presenca = Presenca(
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
        localizacao: const Localizacao(latitude: -23.4205, longitude: -51.9331),
      ),
      ordem: 1,
      situacao: SituacaoPresenca.confirmado,
    );
    presenca.registrarEmbarque(
      '2b1f0c3e-8a4d-4f6e-9c1a-7d2e5b8f0a11',
      DateTime.parse('2026-11-16T06:42:10-03:00'),
    );
    return presenca;
  }

  group('NotificacaoServiceVazio', () {
    test('cumpre o contrato NotificacaoService', () {
      const NotificacaoService servico = NotificacaoServiceVazio();

      expect(servico, isA<NotificacaoService>());
    });

    test('notificarMovimentacao termina sem erro e sem alterar a presença',
        () async {
      const servico = NotificacaoServiceVazio();
      final presenca = presencaEmbarcada();
      final embarque = presenca.embarque;

      await expectLater(
        servico.notificarMovimentacao(presenca, TipoMovimentacao.embarque),
        completes,
      );
      expect(presenca.situacao, SituacaoPresenca.embarcado);
      expect(presenca.embarque, same(embarque));
    });
  });
}
