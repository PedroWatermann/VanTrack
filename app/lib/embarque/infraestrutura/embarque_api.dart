import 'dart:async';

import 'package:http/http.dart' as http;

import '../../compartilhado/api_client.dart';
import '../dominio/aluno_da_rota.dart';
import '../dominio/embarque_remoto.dart';
import '../dominio/excecoes.dart';
import '../dominio/registro_embarque.dart';
import '../dominio/rota_do_dia.dart';

/// Implementação do [EmbarqueRemoto] que fala com a API REST do servidor
/// (contrato da seção 3 do backlog), usando o [ApiClient].
///
/// Converte os resultados em exceções do domínio:
/// - servidor recusou (código fora de 2xx) -> [EnvioRecusadoException];
/// - sem conexão ou sem resposta em 5 segundos -> [SemConexaoException].
class EmbarqueApi implements EmbarqueRemoto {
  EmbarqueApi(this.api);

  final ApiClient api;

  @override
  Future<RotaDoDia> buscarRotaDoDia() async {
    final resposta = await _chamar(() => api.get('/rotas/hoje'));
    return RotaDoDia.deJson(resposta.corpo as Map<String, dynamic>);
  }

  @override
  Future<List<AlunoDaRota>> listarAlunos(int rotaId) async {
    final resposta = await _chamar(() => api.get('/rotas/$rotaId/alunos'));
    return [
      for (final aluno in resposta.corpo as List)
        AlunoDaRota.deJson(aluno as Map<String, dynamic>),
    ];
  }

  @override
  Future<void> enviar(RegistroEmbarque registro) async {
    await _chamar(
      () => api.post('/rotas/${registro.rotaId}/embarques', registro.paraJson()),
    );
  }

  @override
  Future<Map<String, int>> sincronizar(int rotaId, List<RegistroEmbarque> registros) async {
    final resposta = await _chamar(() => api.post(
          '/rotas/$rotaId/embarques/sincronizar',
          {'registros': [for (final r in registros) r.paraJson()]},
        ));
    final resultados = (resposta.corpo as Map<String, dynamic>)['resultados'] as List;
    return {
      for (final r in resultados)
        (r as Map<String, dynamic>)['registroId'] as String: r['codigo'] as int,
    };
  }

  /// Faz a requisição e trata os dois tipos de falha.
  Future<RespostaApi> _chamar(Future<RespostaApi> Function() requisicao) async {
    final RespostaApi resposta;
    try {
      resposta = await requisicao();
    } on TimeoutException {
      throw const SemConexaoException();
    } on http.ClientException {
      throw const SemConexaoException();
    }
    if (!resposta.sucesso) {
      throw EnvioRecusadoException(resposta.codigo, _mensagemDeErro(resposta));
    }
    return resposta;
  }

  /// Usa a mensagem de erro enviada pelo servidor, quando houver.
  String _mensagemDeErro(RespostaApi resposta) {
    final corpo = resposta.corpo;
    if (corpo is Map && corpo['erro'] is String) return corpo['erro'] as String;
    return 'Erro ${resposta.codigo}';
  }
}
