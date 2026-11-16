import '../dominio/aluno_da_rota.dart';
import '../dominio/embarque_remoto.dart';
import '../dominio/rota_do_dia.dart';

/// Busca os dados que a tela "Rota do dia" mostra: a rota de hoje do motorista
/// logado e os alunos confirmados nela.
///
/// Erros do servidor (`EnvioRecusadoException`, ex.: 403 quando o usuário não
/// é o motorista ativo da van, RN-012) e falta de conexão
/// (`SemConexaoException`) são repassados para a tela tratar.
///
/// UC-R02 passo 1; UC-S05 passo 1.
class RotaDoDiaService {
  RotaDoDiaService(this.remoto);

  final EmbarqueRemoto remoto;

  /// Rota de hoje do motorista logado.
  Future<RotaDoDia> buscarRotaDoDia() => remoto.buscarRotaDoDia();

  /// Alunos confirmados na rota, sempre na ordem das paradas. Alunos ausentes
  /// não vêm na lista (RN-010).
  Future<List<AlunoDaRota>> listarAlunosConfirmados(int rotaId) async {
    final alunos = await remoto.listarAlunos(rotaId);
    return [...alunos]..sort((a, b) => a.ordem.compareTo(b.ordem));
  }
}
