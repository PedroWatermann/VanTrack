import 'dart:convert';

import 'package:http/http.dart' as http;

import 'config.dart';
import 'mock/dados_mock.dart';
import 'sessao.dart';

/// Resposta do servidor a uma requisição do app.
///
/// [codigo] indica o resultado da requisição. Os usados neste projeto:
///   200 ou 201 = sucesso
///   401 = usuário não está logado
///   403 = usuário sem permissão (ex.: não é o motorista da van)
///   404 = não encontrado (ex.: rota ou aluno inexistente)
///   409 = conflito (ex.: o aluno já embarcou)
///
/// [corpo] é o conteúdo da resposta (ex.: a lista de alunos da rota).
class RespostaApi {
  final int codigo;
  final dynamic corpo;

  const RespostaApi(this.codigo, [this.corpo]);

  /// Indica se a requisição deu certo (códigos de 200 a 299).
  bool get sucesso => codigo >= 200 && codigo < 300;
}

/// Responsável pela comunicação do app com o servidor.
///
/// - Envia as requisições para o endereço definido em [Config.apiUrl].
/// - Inclui em cada requisição o token do usuário logado, que identifica
///   quem está fazendo o pedido.
/// - Com os dados simulados ligados (USE_MOCK=true), não acessa o servidor:
///   a resposta vem do [DadosMock].
///
/// Falhas de conexão (sem internet ou servidor sem responder em 5 segundos)
/// não são tratadas aqui: o erro é repassado para quem fez a requisição, que
/// decide o que fazer (ex.: guardar o embarque para enviar depois).
///
/// Camada de infraestrutura do módulo compartilhado (03-arquitetura.md).
class ApiClient {
  ApiClient({
    required this.sessao,
    String? baseUrl,
    http.Client? cliente,
    DadosMock? mock,
    bool? usarMock,
  })  : baseUrl = baseUrl ?? Config.apiUrl,
        _http = cliente ?? http.Client(),
        _mock = (usarMock ?? Config.useMock) ? (mock ?? DadosMock()) : null;

  /// Endereço do servidor.
  final String baseUrl;

  /// Sessão do usuário logado, de onde vem o token.
  final Sessao sessao;

  /// Cliente HTTP que faz as requisições de fato.
  final http.Client _http;

  /// Dados simulados. Fica nulo quando o app usa o servidor real.
  final DadosMock? _mock;

  /// Tempo máximo de espera pela resposta do servidor.
  static const Duration tempoLimite = Duration(seconds: 5);

  /// Indica se o app está usando os dados simulados.
  bool get emModoMock => _mock != null;

  /// Busca informações no servidor (ex.: a lista de alunos da rota).
  Future<RespostaApi> get(String caminho) => _enviar('GET', caminho);

  /// Envia uma informação nova ao servidor (ex.: um embarque).
  Future<RespostaApi> post(String caminho, [Object? corpo]) =>
      _enviar('POST', caminho, corpo);

  /// Altera uma informação existente (ex.: marcar um aviso como lido).
  Future<RespostaApi> patch(String caminho, [Object? corpo]) =>
      _enviar('PATCH', caminho, corpo);

  /// Faz a requisição, para o servidor real ou para os dados simulados.
  Future<RespostaApi> _enviar(String metodo, String caminho, [Object? corpo]) async {
    // Dados simulados ligados: responde sem acessar o servidor.
    final mock = _mock;
    if (mock != null) {
      return mock.responder(metodo, caminho, token: sessao.token, corpo: corpo);
    }

    // Monta o endereço completo e os cabeçalhos da requisição,
    // incluindo o token do usuário logado.
    final url = Uri.parse('$baseUrl$caminho');
    final cabecalhos = <String, String>{
      'Content-Type': 'application/json',
      if (sessao.token != null) 'Authorization': 'Bearer ${sessao.token}',
    };
    final texto = corpo == null ? null : jsonEncode(corpo);

    // Envia a requisição e espera no máximo 5 segundos pela resposta.
    final http.Response resposta;
    switch (metodo) {
      case 'GET':
        resposta = await _http.get(url, headers: cabecalhos).timeout(tempoLimite);
      case 'POST':
        resposta = await _http
            .post(url, headers: cabecalhos, body: texto)
            .timeout(tempoLimite);
      case 'PATCH':
        resposta = await _http
            .patch(url, headers: cabecalhos, body: texto)
            .timeout(tempoLimite);
      default:
        throw ArgumentError('Método HTTP não suportado: $metodo');
    }
    return RespostaApi(resposta.statusCode, _lerJson(resposta));
  }

  /// Converte o conteúdo da resposta (em JSON) para dados que o app usa.
  dynamic _lerJson(http.Response resposta) {
    if (resposta.bodyBytes.isEmpty) return null;
    try {
      return jsonDecode(utf8.decode(resposta.bodyBytes));
    } on FormatException {
      return utf8.decode(resposta.bodyBytes);
    }
  }
}
