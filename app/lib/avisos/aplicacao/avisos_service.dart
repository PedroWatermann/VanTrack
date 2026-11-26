import '../dominio/aluno_do_responsavel.dart';
import '../dominio/aviso.dart';
import '../dominio/avisos_remoto.dart';

/// Dados da tela Avisos em um carregamento (UC-I02, RF-011).
class AvisosDoDia {
  const AvisosDoDia({
    required this.alunos,
    required this.avisos,
    required this.embarquesPorAluno,
    required this.consultadoEm,
  });

  final List<AlunoDoResponsavel> alunos;
  final List<Aviso> avisos;
  final Map<int, DateTime> embarquesPorAluno;
  final DateTime consultadoEm;
}

/// Organiza os avisos do dia e associa cada embarque ao aluno (UC-I02, RN-002).
class AvisosService {
  AvisosService(this._remoto, {DateTime Function()? agora})
    : _agora = agora ?? DateTime.now;

  final AvisosRemoto _remoto;
  final DateTime Function() _agora;

  DateTime agora() => _agora();

  Future<void> marcarComoLida(int notificacaoId) =>
      _remoto.marcarComoLida(notificacaoId);

  Future<AvisosDoDia> carregar() async {
    final alunos = await _remoto.listarAlunos();
    final todosOsAvisos = await _remoto.listarAvisos();
    final consultadoEm = agora();
    final hoje = horarioEmBrasilia(consultadoEm);
    final inicio = DateTime.utc(hoje.year, hoje.month, hoje.day);
    final fim = inicio.add(const Duration(days: 1));
    final avisos =
        todosOsAvisos.where((aviso) {
          final hora = horarioEmBrasilia(aviso.dataHora);
          return !hora.isBefore(inicio) && hora.isBefore(fim);
        }).toList()..sort((a, b) {
          final porHora = b.dataHora.compareTo(a.dataHora);
          return porHora == 0 ? b.id.compareTo(a.id) : porHora;
        });

    final embarquesPorAluno = <int, DateTime>{};
    for (final aviso in avisos) {
      if (aviso.deEmbarque) {
        embarquesPorAluno.putIfAbsent(aviso.alunoId, () => aviso.dataHora);
      }
    }
    return AvisosDoDia(
      alunos: alunos,
      avisos: avisos,
      embarquesPorAluno: embarquesPorAluno,
      consultadoEm: consultadoEm,
    );
  }
}
