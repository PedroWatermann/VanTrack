import 'rota.dart';

/// `RotaRepository` — contrato no rota :: domínio (ponto 3 do 03-arquitetura.md).
///
/// Responsabilidade: buscar a rota com a sua van, para o 404 de rota inexistente
/// e para o RN-012 (motorista ativo da van), e achar a rota de hoje do motorista
/// (`GET /rotas/hoje`, pontos 8 e 9). Implementação: `RotaRepositoryPostgres`.
/// UC-S05, UC-R02.
abstract class RotaRepository {
  /// Rota pelo id, ou `null` se não existir.
  Future<Rota?> buscarPorId(int rotaId);

  /// Rota do dia [data] da van em que o motorista tem vínculo ativo (RN-012), ou
  /// `null` se ele não tem rota nesse dia (inclui o motorista sem vínculo).
  /// Só o dia de [data] é considerado (ano, mês e dia).
  Future<Rota?> buscarDoMotorista(int motoristaId, DateTime data);
}
