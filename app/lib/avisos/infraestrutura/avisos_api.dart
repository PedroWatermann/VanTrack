import '../../compartilhado/api_client.dart';
import '../dominio/aluno_do_responsavel.dart';
import '../dominio/aviso.dart';
import '../dominio/avisos_remoto.dart';

/// Lê o contrato de avisos usando o cliente e o token do login (UC-I02, RN-002).
class AvisosApi implements AvisosRemoto {
  const AvisosApi(this._api);

  final ApiClient _api;

  @override
  Future<List<AlunoDoResponsavel>> listarAlunos() async {
    final alunos = await _listar('/alunos');
    return [
      for (final aluno in alunos)
        AlunoDoResponsavel(
          id: aluno['alunoId'] as int,
          nome: aluno['nome'] as String,
        ),
    ];
  }

  @override
  Future<List<Aviso>> listarAvisos() async {
    final avisos = await _listar('/notificacoes');
    return [
      for (final aviso in avisos)
        Aviso(
          id: aviso['id'] as int,
          alunoId: aviso['alunoId'] as int,
          tipo: aviso['tipo'] as String,
          mensagem: aviso['mensagem'] as String,
          dataHora: DateTime.parse(aviso['dataHora'] as String),
          lida: aviso['lida'] as bool,
        ),
    ];
  }

  Future<List<Map<String, dynamic>>> _listar(String caminho) async {
    final resposta = await _api.get(caminho);
    final corpo = resposta.corpo;
    if (!resposta.sucesso || corpo is! List) {
      throw StateError('Não foi possível carregar os avisos.');
    }
    return corpo.cast<Map<String, dynamic>>();
  }
}
