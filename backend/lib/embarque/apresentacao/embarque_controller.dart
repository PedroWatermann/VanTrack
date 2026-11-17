import 'package:dart_frog/dart_frog.dart';
import 'package:uuid/validation.dart';

import '../../cadastro/dominio/usuario.dart';
import '../../compartilhado/aplicacao/excecoes.dart';
import '../../compartilhado/apresentacao/usuario_logado.dart';
import '../../compartilhado/dominio/horario_brasilia.dart';
import '../../rota/dominio/excecoes.dart';
import '../../rota/dominio/localizacao.dart';
import '../aplicacao/embarque_service.dart';

/// `EmbarqueController` — embarque :: apresentação (participante
/// "EmbarqueController" do diagrama de sequência UC-S05).
///
/// Responsabilidade: converter HTTP/JSON em chamadas ao [EmbarqueService] e as
/// exceções em códigos HTTP, no formato da seção 3 do backlog. **Sem regra de
/// negócio e sem acesso a repositório**: quem coordena o caso de uso é o
/// service.
///
/// UC-S05 passos 2 a 5 (lado do servidor); RF-009; RN-010 e RN-012 (só
/// traduz as exceções em 409 e 403).
class EmbarqueController {
  const EmbarqueController(this.service);

  final EmbarqueService service;

  /// `GET /rotas/hoje` (task A-08; pontos 8 e 9 do 03-arquitetura.md).
  ///
  /// Respostas: 200 `{ rotaId, trajeto, horarioPrevisto, placa }`, 403 (não é
  /// motorista), 404 (motorista sem rota hoje, inclusive o sem vínculo) e 405.
  Future<Response> buscarRotaDoDia(
      Request pedido, UsuarioLogado usuario) async {
    if (pedido.method != HttpMethod.get) {
      return Response(statusCode: 405, headers: {'Allow': 'GET'});
    }
    if (usuario.papel != Papel.motorista) {
      return _erro(403, 'Só o motorista tem rota do dia.');
    }
    return _traduzindoErros(() async {
      final rota = await service.buscarRotaDoDia(usuario.id);
      return Response.json(
        body: {
          'rotaId': rota.id,
          'trajeto': rota.trajeto.codigo,
          'horarioPrevisto': HorarioBrasilia.formatarIso8601(
            rota.horarioPrevisto,
          ),
          'placa': rota.van.placa,
        },
      );
    });
  }

  /// `GET /rotas/{rotaId}/alunos` (task A-08; UC-S05 passo 1).
  ///
  /// Respostas: 200 com a lista da seção 3 do backlog (só CONFIRMADO ou
  /// EMBARCADO, na ordem da rota; RN-010), 403 (não é o motorista ativo da van,
  /// RN-012), 404 (rota não existe) e 405.
  Future<Response> listarAlunos(
    String rotaId,
    Request pedido,
    UsuarioLogado usuario,
  ) async {
    if (pedido.method != HttpMethod.get) {
      return Response(statusCode: 405, headers: {'Allow': 'GET'});
    }
    // Só motorista tem motoristaId (ver registrarEmbarque).
    if (usuario.papel != Papel.motorista) {
      return _erro(403, 'Você não é o motorista ativo desta van.');
    }
    final id = int.tryParse(rotaId);
    if (id == null || id <= 0) {
      return _erro(404, 'Rota não encontrada.');
    }
    return _traduzindoErros(() async {
      final presencas = await service.listarAlunosConfirmados(id, usuario.id);
      return Response.json(
        body: [
          for (final presenca in presencas)
            {
              'alunoId': presenca.aluno.id,
              'nome': presenca.aluno.nome,
              'ordem': presenca.ordem,
              'pontoParada': {
                'endereco': presenca.pontoParada.endereco,
                'latitude': presenca.pontoParada.localizacao.latitude,
                'longitude': presenca.pontoParada.localizacao.longitude,
              },
              'status': presenca.situacao.codigo,
            },
        ],
      );
    });
  }

  /// Converte as exceções conhecidas em 403/404/409; as demais sobem até o
  /// middleware raiz (503).
  Future<Response> _traduzindoErros(Future<Response> Function() acao) async {
    try {
      return await acao();
    } on Exception catch (erro) {
      final codigo = _codigoHttpDe(erro);
      if (codigo == null) rethrow;
      return _erro(codigo, _mensagemDe(erro));
    }
  }

  /// `POST /rotas/{rotaId}/embarques` (task B-08).
  ///
  /// Corpo: `{ registroId, alunoId, dataHora, latitude?, longitude? }`.
  /// Respostas: 201 (registrado), 200 (registroId já processado), 400 (corpo
  /// inválido), 403 (não é o motorista ativo da van), 404 (rota ou aluno não
  /// existe), 405 (método diferente de POST) e 409 (aluno não confirmado ou já
  /// embarcado).
  Future<Response> registrarEmbarque(
    String rotaId,
    Request pedido,
    UsuarioLogado usuario,
  ) async {
    if (pedido.method != HttpMethod.post) {
      return Response(statusCode: 405, headers: {'Allow': 'POST'});
    }
    // Só motorista tem motoristaId: o id de um responsável pode coincidir com
    // o de um motorista (tabelas diferentes).
    if (usuario.papel != Papel.motorista) {
      return _erro(403, 'Você não é o motorista ativo desta van.');
    }

    final id = int.tryParse(rotaId);
    if (id == null || id <= 0) {
      return _erro(404, 'Rota não encontrada.');
    }

    final Object? corpo;
    try {
      corpo = await pedido.json();
    } on FormatException {
      return _corpoInvalido();
    }
    final registro = _RegistroRecebido.ler(corpo);
    if (registro == null) return _corpoInvalido();

    try {
      final resultado = await service.registrarEmbarque(
        rotaId: id,
        alunoId: registro.alunoId,
        registroId: registro.registroId,
        dataHora: registro.dataHora,
        localizacao: registro.localizacao,
        motoristaId: usuario.id,
      );
      return Response.json(
        statusCode: resultado.jaProcessado ? 200 : 201,
        body: {
          'alunoId': resultado.alunoId,
          'status': resultado.situacao.codigo,
        },
      );
    } on Exception catch (erro) {
      final codigo = _codigoHttpDe(erro);
      if (codigo == null) rethrow;
      return _erro(codigo, _mensagemDe(erro));
    }
  }

  /// Exceções da aplicação e do domínio -> código HTTP (seção 3 do backlog).
  /// `null`: erro inesperado, que sobe até o middleware raiz (503).
  int? _codigoHttpDe(Exception erro) => switch (erro) {
        AcessoNegadoException() => 403,
        NaoEncontradoException() => 404,
        EmbarqueNaoPermitidoException() => 409,
        _ => null,
      };

  String _mensagemDe(Exception erro) => switch (erro) {
        AcessoNegadoException(:final mensagem) => mensagem,
        NaoEncontradoException(:final mensagem) => mensagem,
        _ => 'O aluno não está confirmado nesta rota ou já embarcou.',
      };

  Response _corpoInvalido() => _erro(
        400,
        'Informe registroId (UUID), alunoId (inteiro positivo), dataHora '
        '(ISO 8601 com fuso) e, se houver, latitude e longitude juntas.',
      );

  Response _erro(int codigo, String mensagem) =>
      Response.json(statusCode: codigo, body: {'erro': mensagem});
}

/// Corpo do `POST /rotas/{rotaId}/embarques` já validado (só formato; as regras
/// ficam no service e na entidade).
class _RegistroRecebido {
  const _RegistroRecebido({
    required this.registroId,
    required this.alunoId,
    required this.dataHora,
    this.localizacao,
  });

  final String registroId;
  final int alunoId;
  final DateTime dataHora;
  final Localizacao? localizacao;

  /// Lê e valida o JSON; `null` se o formato estiver errado (400).
  static _RegistroRecebido? ler(Object? corpo) {
    if (corpo is! Map<String, dynamic>) return null;

    final registroId = corpo['registroId'];
    final alunoId = corpo['alunoId'];
    final dataHoraTexto = corpo['dataHora'];
    if (registroId is! String ||
        !UuidValidation.isValidUUID(fromString: registroId)) {
      return null;
    }
    if (alunoId is! int || alunoId <= 0) return null;
    if (dataHoraTexto is! String) return null;
    final dataHora = DateTime.tryParse(dataHoraTexto);
    // O fuso é obrigatório: sem ele não dá para saber a hora real do toque.
    if (dataHora == null || !dataHora.isUtc) return null;

    final latitude = corpo['latitude'];
    final longitude = corpo['longitude'];
    final Localizacao? localizacao;
    if (latitude == null && longitude == null) {
      localizacao = null;
    } else if (latitude is num && longitude is num) {
      localizacao = Localizacao(
        latitude: latitude.toDouble(),
        longitude: longitude.toDouble(),
      );
    } else {
      return null;
    }

    return _RegistroRecebido(
      registroId: registroId,
      alunoId: alunoId,
      dataHora: dataHora,
      localizacao: localizacao,
    );
  }
}
