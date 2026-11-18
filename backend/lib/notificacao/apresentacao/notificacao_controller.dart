import 'package:dart_frog/dart_frog.dart';

import '../../cadastro/dominio/usuario.dart';
import '../../compartilhado/aplicacao/excecoes.dart';
import '../../compartilhado/apresentacao/usuario_logado.dart';
import '../../compartilhado/dominio/horario_brasilia.dart';
import '../aplicacao/avisos_service.dart';

/// Traduz as requisições de avisos em chamadas ao service e respostas HTTP.
/// UC-I02, RF-011; RN-002: só aceita o papel de responsável.
/// Não acessa repositórios nem contém a regra de propriedade do aviso.
class NotificacaoController {
  const NotificacaoController(this.avisosService);

  final AvisosService avisosService;

  Future<Response> listar(Request pedido, UsuarioLogado usuario) async {
    if (pedido.method != HttpMethod.get) {
      return Response(statusCode: 405, headers: {'Allow': 'GET'});
    }
    if (usuario.papel != Papel.responsavel) {
      return _erro(403, 'Somente responsáveis podem acessar os avisos.');
    }
    final texto = pedido.uri.queryParameters['desde'];
    final desde = texto == null ? null : DateTime.tryParse(texto);
    if (texto != null && (desde == null || !desde.isUtc)) {
      return _erro(400, 'Informe desde em ISO 8601 com fuso horário.');
    }
    final avisos = await avisosService.listarDoResponsavel(usuario.id, desde);
    return Response.json(body: [
      for (final aviso in avisos)
        {
          'id': aviso.id,
          'tipo': aviso.tipo.codigo,
          'alunoNome': aviso.aluno.nome,
          'mensagem': aviso.mensagem,
          'dataHora': HorarioBrasilia.formatarIso8601(aviso.dataHoraEvento),
          'lida': aviso.lida,
        },
    ]);
  }

  Future<Response> marcarComoLida(
      String notificacaoId, Request pedido, UsuarioLogado usuario) async {
    if (pedido.method != HttpMethod.patch) {
      return Response(statusCode: 405, headers: {'Allow': 'PATCH'});
    }
    if (usuario.papel != Papel.responsavel) {
      return _erro(403, 'Somente responsáveis podem acessar os avisos.');
    }
    final id = int.tryParse(notificacaoId);
    if (id == null || id <= 0) {
      return _erro(404, 'Notificação não encontrada.');
    }
    try {
      await avisosService.marcarComoLida(id, usuario.id);
      return Response(statusCode: 204);
    } on AcessoNegadoException catch (erro) {
      return _erro(403, erro.mensagem);
    } on NaoEncontradoException catch (erro) {
      return _erro(404, erro.mensagem);
    }
  }

  Response _erro(int codigo, String mensagem) =>
      Response.json(statusCode: codigo, body: {'erro': mensagem});
}
