import '../../cadastro/dominio/aluno.dart';
import 'embarque.dart';
import 'localizacao.dart';
import 'ponto_parada.dart';

/// Situação da presença de um aluno em uma rota.
enum SituacaoPresenca {
  confirmado('CONFIRMADO'),
  ausente('AUSENTE'),
  embarcado('EMBARCADO');

  const SituacaoPresenca(this.codigo);

  /// Valor usado no JSON e no banco.
  final String codigo;

  static SituacaoPresenca deCodigo(String codigo) =>
      values.firstWhere((s) => s.codigo == codigo);
}

/// `Presenca` — rota :: domínio (participante "Presenca" do diagrama de
/// sequência UC-S05).
///
/// Responsabilidade: guardar a situação do aluno na rota, com a ordem e o ponto
/// de parada, e **registrar o próprio embarque**, validando o status (RN-010).
/// UC-S05 passos 1 e 3; RF-009. Aluno AUSENTE não entra na rota do dia
/// (exceção da RN-010).
///
/// A situação e o embarque são privados: só operações da própria entidade os
/// alteram (entidade não anêmica, seção 2.1 do 03-arquitetura.md).
class Presenca {
  Presenca({
    required this.id,
    required this.rotaId,
    required this.aluno,
    required this.pontoParada,
    required this.ordem,
    required SituacaoPresenca situacao,
    Embarque? embarque,
  })  : _situacao = situacao,
        _embarque = embarque;

  final int id;

  /// Associação Rota 1 — 0..* Presenca (guardada como id).
  final int rotaId;

  /// Associação navegável Presenca → Aluno (carregado: a tela mostra o nome).
  final Aluno aluno;

  /// Associação navegável Presenca → PontoParada.
  final PontoParada pontoParada;

  /// Posição na ordem da rota (1 = primeira parada).
  final int ordem;

  SituacaoPresenca _situacao;

  /// Composição Presenca 1 — 0..1 Embarque.
  Embarque? _embarque;

  SituacaoPresenca get situacao => _situacao;

  Embarque? get embarque => _embarque;

  /// A presença está CONFIRMADO (pode embarcar)?
  bool estaConfirmada() => _situacao == SituacaoPresenca.confirmado;

  /// RN-010: registra o embarque desta presença. Só se estiver CONFIRMADO; muda
  /// para EMBARCADO e cria o [Embarque]. Senão lança
  /// `EmbarqueNaoPermitidoException` (409).
  ///
  /// Implementação: task B-04 (Membro B).
  Embarque registrarEmbarque(
    String registroId,
    DateTime dataHora, [
    Localizacao? localizacao,
  ]) {
    throw UnimplementedError('Presenca.registrarEmbarque: task B-04.');
  }
}
