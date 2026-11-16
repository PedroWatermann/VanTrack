import '../../cadastro/dominio/vinculo_repository.dart';
import '../../compartilhado/aplicacao/excecoes.dart';
import '../../notificacao/aplicacao/notificacao_service.dart';
import '../../notificacao/dominio/notificacao.dart';
import '../../rota/dominio/localizacao.dart';
import '../../rota/dominio/presenca.dart';
import '../../rota/dominio/presenca_repository.dart';
import '../../rota/dominio/rota.dart';
import '../../rota/dominio/rota_repository.dart';

/// `ResultadoRegistro` — embarque :: aplicação.
///
/// Resultado de `EmbarqueService.registrarEmbarque`. O controller monta o corpo
/// `{ "alunoId": ..., "status": "EMBARCADO" }` a partir dele; [jaProcessado]
/// diferencia o 201 (embarque registrado agora) do 200 (o `registroId` já tinha
/// sido processado, RNF-006 — task B-07).
class ResultadoRegistro {
  const ResultadoRegistro({
    required this.alunoId,
    required this.situacao,
    this.jaProcessado = false,
  });

  final int alunoId;
  final SituacaoPresenca situacao;
  final bool jaProcessado;
}

/// `EmbarqueService` — embarque :: aplicação (participante "EmbarqueService"
/// do diagrama de sequência UC-S05).
///
/// Responsabilidade: **coordenar o UC-S05** no servidor, na ordem do diagrama
/// de sequência: a rota existe, o usuário é o motorista ativo da van (RN-012),
/// a presença do aluno existe, a própria `Presenca` registra o embarque
/// (RN-010), a presença e o embarque são salvos em uma transação e só então o
/// `<<include>>` UC-I02 é acionado.
///
/// Não contém regra de entidade (RN-010 fica em `Presenca.registrarEmbarque`)
/// nem acesso a banco: depende só dos contratos, injetados no construtor, e por
/// isso é testado com mocks, sem banco.
///
/// UC-S05 passos 2 a 5 e A1 (lado do servidor); RF-009; RN-010, RN-012;
/// RNF-006.
class EmbarqueService {
  EmbarqueService({
    required RotaRepository rotaRepository,
    required PresencaRepository presencaRepository,
    required VinculoRepository vinculoRepository,
    required NotificacaoService notificacaoService,
  })  : _rotaRepository = rotaRepository,
        _presencaRepository = presencaRepository,
        _vinculoRepository = vinculoRepository,
        _notificacaoService = notificacaoService;

  final RotaRepository _rotaRepository;
  final PresencaRepository _presencaRepository;
  final VinculoRepository _vinculoRepository;
  final NotificacaoService _notificacaoService;

  /// Registra o embarque do aluno [alunoId] na rota [rotaId] (UC-S05).
  ///
  /// [dataHora] é o momento do toque no aparelho, NÃO a hora do servidor: o
  /// embarque feito offline guarda o horário real (RNF-006). [localizacao] é
  /// opcional ("quando disponível", RF-009).
  ///
  /// Lança:
  /// - [NaoEncontradoException] (404): a rota não existe ou o aluno não tem
  ///   presença nela;
  /// - [AcessoNegadoException] (403): [motoristaId] não é o motorista ativo da
  ///   van da rota (RN-012);
  /// - `EmbarqueNaoPermitidoException` (409): a presença não está CONFIRMADO
  ///   (RN-010), lançada pela própria `Presenca`.
  Future<ResultadoRegistro> registrarEmbarque({
    required int rotaId,
    required int alunoId,
    required String registroId,
    required DateTime dataHora,
    required int motoristaId,
    Localizacao? localizacao,
  }) async {
    final rota = await _rotaRepository.buscarPorId(rotaId);
    if (rota == null) {
      throw const NaoEncontradoException('Rota não encontrada.');
    }

    await _validarMotoristaAtivo(rota, motoristaId);

    final presenca = await _presencaRepository.buscarPresenca(alunoId, rotaId);
    if (presenca == null) {
      throw const NaoEncontradoException('Aluno não encontrado nesta rota.');
    }

    // RN-010: a própria Presenca valida o status e cria o Embarque com a hora
    // do toque (lança EmbarqueNaoPermitidoException -> 409).
    presenca.registrarEmbarque(registroId, dataHora, localizacao);

    // Situação e embarque gravados na mesma transação.
    await _presencaRepository.salvar(presenca);

    // <<include>> UC-I02, só depois de salvar (UC-S05 passo 5).
    await _notificacaoService.notificarMovimentacao(
      presenca,
      TipoMovimentacao.embarque,
    );

    return ResultadoRegistro(alunoId: alunoId, situacao: presenca.situacao);
  }

  /// RN-012: só o motorista do vínculo ativo da van da [rota] pode operar a
  /// rota. Senão lança [AcessoNegadoException] (403).
  Future<void> _validarMotoristaAtivo(Rota rota, int motoristaId) async {
    final vinculo = await _vinculoRepository.buscarVinculoAtivo(rota.van.id);
    if (vinculo == null || !vinculo.autoriza(motoristaId)) {
      throw const AcessoNegadoException(
        'Você não é o motorista ativo desta van.',
      );
    }
  }
}
