import 'aluno_da_rota.dart';
import 'rota_do_dia.dart';

/// Rota guardada no aparelho, com o dia em que foi carregada ("2026-11-24").
typedef RotaGuardada = ({String dia, RotaDoDia rota, List<AlunoDaRota> alunos});

/// Contrato da última rota do dia carregada neste aparelho.
///
/// Com ela, o motorista que abre o app sem conexão ainda vê a rota de hoje e
/// os embarques pendentes (teste 9, RNF-006; Bug VT-75). A implementação fica
/// na infraestrutura (`RotaSalvaLocal`).
abstract class RotaSalva {
  /// Guarda a rota e os alunos dela, junto com o dia em que foram carregados.
  Future<void> guardar(RotaGuardada rota);

  /// Última rota guardada, ou nulo se não houver.
  Future<RotaGuardada?> ler();

  /// Apaga a rota guardada (ex.: quando o motorista sai do app).
  Future<void> apagar();
}
