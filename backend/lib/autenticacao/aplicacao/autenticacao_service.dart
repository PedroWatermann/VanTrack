import 'package:uuid/uuid.dart';

import '../../cadastro/dominio/usuario.dart';
import '../dominio/sessao.dart';
import '../dominio/sessao_repository.dart';
import '../dominio/usuario_repository.dart';

/// Coordena o login do seed e a criação da sessão, sem SQL ou HTTP.
/// RNF-002; apoio ao UC-S05/RF-009 e UC-I02/RF-011.
class AutenticacaoService {
  const AutenticacaoService(this.usuarios, this.sessoes);

  final UsuarioRepository usuarios;
  final SessaoRepository sessoes;

  Future<List<Usuario>> listarUsuarios() => usuarios.listar();

  Future<Sessao?> entrar(int id, Papel papel) async {
    final usuario = await usuarios.buscarPorIdEPapel(id, papel);
    if (usuario == null) return null;
    final sessao = Sessao(
      token: const Uuid().v4(),
      usuario: usuario,
      criadaEm: DateTime.now().toUtc(),
    );
    await sessoes.salvar(sessao);
    return sessao;
  }
}
