import 'dart:developer' as developer;

import '../../cadastro/dominio/vinculo_repository.dart';
import '../../compartilhado/aplicacao/excecoes.dart';
import '../../notificacao/aplicacao/notificacao_service.dart';
import '../../notificacao/dominio/notificacao.dart';
import '../../rota/dominio/excecoes.dart';
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
    DateTime Function()? relogio,
  })  : _rotaRepository = rotaRepository,
        _presencaRepository = presencaRepository,
        _vinculoRepository = vinculoRepository,
        _notificacaoService = notificacaoService,
        _relogio = relogio ?? DateTime.now;

  final RotaRepository _rotaRepository;
  final PresencaRepository _presencaRepository;
  final VinculoRepository _vinculoRepository;
  final NotificacaoService _notificacaoService;

  /// Hora atual; injetável para os testes de "hoje" (task A-08).
  final DateTime Function() _relogio;

  /// Rota de hoje do motorista, para abrir a "Rota do dia" logo depois do
  /// login (`GET /rotas/hoje`, pontos 8 e 9 do 03-arquitetura.md; task A-08).
  ///
  /// "Hoje" é a data de Brasília (UTC-3): o servidor pode estar em UTC, e depois
  /// das 21h a data UTC já é a do dia seguinte. A rota é a da van em que o
  /// motorista tem vínculo ativo (RN-012).
  ///
  /// Lança [NaoEncontradoException] (404) se ele não tem rota hoje, o que inclui
  /// o motorista sem vínculo com van.
  Future<Rota> buscarRotaDoDia(int motoristaId) async {
    final hojeEmBrasilia =
        _relogio().toUtc().subtract(const Duration(hours: 3));
    final rota =
        await _rotaRepository.buscarDoMotorista(motoristaId, hojeEmBrasilia);
    if (rota == null) {
      throw const NaoEncontradoException('Motorista sem rota hoje.');
    }
    return rota;
  }

  /// UC-S05 passo 1: alunos da rota na ordem das paradas, para a tela
  /// "Rota do dia" (`GET /rotas/{rotaId}/alunos`; task A-08).
  ///
  /// Só presenças CONFIRMADO ou EMBARCADO: aluno AUSENTE não aparece (exceção
  /// da RN-010).
  ///
  /// Lança [NaoEncontradoException] (404) se a rota não existe e
  /// [AcessoNegadoException] (403) se [motoristaId] não é o motorista ativo da
  /// van da rota (RN-012).
  Future<List<Presenca>> listarAlunosConfirmados(
    int rotaId,
    int motoristaId,
  ) async {
    final rota = await _rotaRepository.buscarPorId(rotaId);
    if (rota == null) {
      throw const NaoEncontradoException('Rota não encontrada.');
    }

    await _validarMotoristaAtivo(rota, motoristaId);

    final presencas = await _presencaRepository.buscarConfirmados(rotaId);
    // RN-010 (exceção): o repositório já deixa os ausentes de fora no SQL; o
    // service garante a regra e a ordem da rota mesmo com outra implementação.
    return [
      for (final presenca in presencas)
        if (presenca.situacao != SituacaoPresenca.ausente) presenca,
    ]..sort((a, b) => a.ordem.compareTo(b.ordem));
  }

  /// Registra o embarque do aluno [alunoId] na rota [rotaId] (UC-S05).
  ///
  /// [dataHora] é o momento do toque no aparelho, NÃO a hora do servidor: o
  /// embarque feito offline guarda o horário real (RNF-006). [localizacao] é
  /// opcional ("quando disponível", RF-009).
  ///
  /// Idempotência (RNF-006): se o [registroId] já foi processado, devolve o
  /// mesmo resultado com `jaProcessado: true` (200), sem salvar nem notificar
  /// de novo. Vale também para duas requisições simultâneas com o mesmo
  /// registro: a unicidade do banco recusa a segunda.
  ///
  /// Se a notificação (UC-I02) falhar depois de salvar, o embarque continua
  /// registrado (201) e o erro vai para o log do servidor.
  ///
  /// Lança:
  /// - [NaoEncontradoException] (404): a rota não existe ou o aluno não tem
  ///   presença nela;
  /// - [AcessoNegadoException] (403): [motoristaId] não é o motorista ativo da
  ///   van da rota (RN-012);
  /// - [EmbarqueNaoPermitidoException] (409): a presença não está CONFIRMADO
  ///   (RN-010), lançada pela própria `Presenca`, ou o aluno já embarcou com
  ///   outro `registroId`.
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

    // RNF-006: registroId já processado -> mesmo resultado (200), sem salvar
    // nem notificar de novo (reenvio da sincronização offline).
    final jaProcessada =
        await _presencaRepository.buscarPorRegistroId(registroId);
    if (jaProcessada != null) {
      return _jaProcessado(alunoId, jaProcessada);
    }

    final presenca = await _presencaRepository.buscarPresenca(alunoId, rotaId);
    if (presenca == null) {
      throw const NaoEncontradoException('Aluno não encontrado nesta rota.');
    }

    // RN-010: a própria Presenca valida o status e cria o Embarque com a hora
    // do toque (lança EmbarqueNaoPermitidoException -> 409).
    presenca.registrarEmbarque(registroId, dataHora, localizacao);

    // Situação e embarque gravados na mesma transação.
    try {
      await _presencaRepository.salvar(presenca);
    } on EmbarqueDuplicadoException {
      // Corrida entre requisições: o banco recusou por unicidade. Se foi o
      // MESMO registro, quem salvou primeiro já notificou -> 200. Senão, outro
      // registroId já embarcou o aluno -> 409 (RN-010).
      final mesma = await _presencaRepository.buscarPorRegistroId(registroId);
      if (mesma != null) {
        return _jaProcessado(alunoId, mesma);
      }
      throw const EmbarqueNaoPermitidoException(SituacaoPresenca.embarcado);
    }

    // <<include>> UC-I02, só depois de salvar (UC-S05 passo 5).
    try {
      await _notificacaoService.notificarMovimentacao(
        presenca,
        TipoMovimentacao.embarque,
      );
    } on Object catch (erro, pilha) {
      // O embarque já está salvo: uma falha no aviso não desfaz o registro
      // nem vira erro para o motorista (o app reenviaria e receberia 200 sem
      // notificar de novo). O erro fica no log do servidor (decisão da B-11).
      developer.log(
        'Falha ao notificar o embarque $registroId (aluno $alunoId).',
        name: 'EmbarqueService',
        error: erro,
        stackTrace: pilha,
      );
    }

    return ResultadoRegistro(alunoId: alunoId, situacao: presenca.situacao);
  }

  /// Resultado de um `registroId` que já tinha sido processado (200).
  ResultadoRegistro _jaProcessado(int alunoId, Presenca presenca) =>
      ResultadoRegistro(
        alunoId: alunoId,
        situacao: presenca.situacao,
        jaProcessado: true,
      );

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
