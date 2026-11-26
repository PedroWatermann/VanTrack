import '../dominio/aluno_da_rota.dart';
import '../dominio/embarque_remoto.dart';
import '../dominio/excecoes.dart';
import '../dominio/rota_do_dia.dart';
import '../dominio/rota_salva.dart';

/// Busca os dados que a tela "Rota do dia" mostra: a rota de hoje do motorista
/// logado e os alunos confirmados nela.
///
/// Erros do servidor (`EnvioRecusadoException`, ex.: 403 quando o usuário não
/// é o motorista ativo da van, RN-012) e falta de conexão
/// (`SemConexaoException`) são repassados para a tela tratar.
///
/// Com uma [RotaSalva], a última rota carregada fica guardada no aparelho.
/// Sem conexão, a rota guardada **de hoje** é usada no lugar da do servidor,
/// para o motorista ver a rota e os pendentes mesmo abrindo o app offline
/// (teste 9, RNF-006; Bug VT-75). Uma recusa do servidor nunca usa a rota
/// guardada.
///
/// UC-R02 passo 1; UC-S05 passo 1 e fluxo A1.
class RotaDoDiaService {
  RotaDoDiaService(this.remoto, {this.salva, DateTime Function()? relogio})
      : _relogio = relogio ?? DateTime.now;

  final EmbarqueRemoto remoto;

  /// Onde a última rota carregada fica guardada (nula = não guarda).
  final RotaSalva? salva;

  final DateTime Function() _relogio;

  /// Última rota que veio do servidor, guardada junto com os alunos dela.
  RotaDoDia? _rotaDoServidor;

  /// Rota de hoje do motorista logado.
  Future<RotaDoDia> buscarRotaDoDia() async {
    try {
      return _rotaDoServidor = await remoto.buscarRotaDoDia();
    } on SemConexaoException {
      final guardada = await _guardadaDeHoje();
      if (guardada == null) rethrow;
      return guardada.rota;
    }
  }

  /// Alunos confirmados na rota, sempre na ordem das paradas. Alunos ausentes
  /// não vêm na lista (RN-010).
  Future<List<AlunoDaRota>> listarAlunosConfirmados(int rotaId) async {
    List<AlunoDaRota> alunos;
    try {
      alunos = await remoto.listarAlunos(rotaId);
      final rota = _rotaDoServidor;
      if (rota != null && rota.rotaId == rotaId) {
        await salva?.guardar((dia: _hoje(), rota: rota, alunos: alunos));
      }
    } on SemConexaoException {
      final guardada = await _guardadaDeHoje();
      if (guardada == null || guardada.rota.rotaId != rotaId) rethrow;
      alunos = guardada.alunos;
    }
    return [...alunos]..sort((a, b) => a.ordem.compareTo(b.ordem));
  }

  /// Marca o aluno como embarcado na rota guardada, para ele não voltar a
  /// aparecer como "aguardando" se o app for aberto sem conexão.
  Future<void> marcarEmbarcado(int rotaId, int alunoId) async {
    final guardada = await salva?.ler();
    if (guardada == null || guardada.rota.rotaId != rotaId) return;
    await salva?.guardar((
      dia: guardada.dia,
      rota: guardada.rota,
      alunos: [
        for (final aluno in guardada.alunos)
          aluno.alunoId == alunoId ? aluno.comoEmbarcado() : aluno,
      ],
    ));
  }

  /// Esquece a rota guardada (ex.: o motorista saiu do app; outro usuário não
  /// pode ver a rota dele).
  Future<void> esquecer() async {
    _rotaDoServidor = null;
    await salva?.apagar();
  }

  Future<RotaGuardada?> _guardadaDeHoje() async {
    final guardada = await salva?.ler();
    return guardada != null && guardada.dia == _hoje() ? guardada : null;
  }

  /// Dia de hoje no aparelho, como "2026-11-24".
  String _hoje() {
    final agora = _relogio();
    String doisDigitos(int n) => n.toString().padLeft(2, '0');
    return '${agora.year}-${doisDigitos(agora.month)}-${doisDigitos(agora.day)}';
  }
}
