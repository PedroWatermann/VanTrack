import 'package:flutter/material.dart';

import '../../compartilhado/sessao.dart';
import '../aplicacao/login_service.dart';

/// Função que monta a tela aberta depois do login.
typedef ConstrutorDeTela = Widget Function(UsuarioLogado usuario);

/// Tela de login (seção 10 do backlog, Tela 1).
///
/// Lista os usuários com nome e papel. Um toque entra no app: o motorista vai
/// para a "Rota do dia" e o responsável para "Avisos".
///
/// As telas de destino vêm prontas do main.dart. Assim o módulo de login não
/// precisa conhecer os módulos de embarque e de avisos.
class TelaLogin extends StatefulWidget {
  const TelaLogin({
    super.key,
    required this.loginService,
    required this.telaDoMotorista,
    required this.telaDoResponsavel,
  });

  final LoginService loginService;

  /// Tela aberta quando um motorista entra.
  final ConstrutorDeTela telaDoMotorista;

  /// Tela aberta quando um responsável entra.
  final ConstrutorDeTela telaDoResponsavel;

  @override
  State<TelaLogin> createState() => _TelaLoginState();
}

class _TelaLoginState extends State<TelaLogin> {
  List<UsuarioLogado> _usuarios = const [];
  bool _carregando = true;
  bool _entrando = false;
  String? _erro;

  @override
  void initState() {
    super.initState();
    _carregarUsuarios();
  }

  /// Busca a lista de usuários no servidor (ou nos dados simulados).
  Future<void> _carregarUsuarios() async {
    setState(() {
      _carregando = true;
      _erro = null;
    });
    try {
      final usuarios = await widget.loginService.listarUsuarios();
      if (!mounted) return;
      setState(() {
        _usuarios = usuarios;
        _carregando = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _erro = 'Não foi possível carregar os usuários. Tente de novo.';
        _carregando = false;
      });
    }
  }

  /// Entra como o usuário tocado e abre a tela correspondente ao seu papel.
  Future<void> _entrar(UsuarioLogado usuario) async {
    if (_entrando) return;
    setState(() => _entrando = true);
    try {
      await widget.loginService.entrar(usuario);
      if (!mounted) return;
      final destino = usuario.papel == Papel.motorista
          ? widget.telaDoMotorista(usuario)
          : widget.telaDoResponsavel(usuario);
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(builder: (_) => destino),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _entrando = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não foi possível entrar. Tente de novo.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('VanTrack')),
      body: SafeArea(child: _conteudo()),
    );
  }

  Widget _conteudo() {
    if (_carregando) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Carregando…', style: TextStyle(fontSize: 18)),
          ],
        ),
      );
    }

    final erro = _erro;
    if (erro != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(erro, textAlign: TextAlign.center, style: const TextStyle(fontSize: 18)),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _carregarUsuarios,
                child: const Text('Tentar de novo'),
              ),
            ],
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'Quem está usando o app?',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        for (final usuario in _usuarios)
          _CartaoUsuario(
            usuario: usuario,
            aoTocar: _entrando ? null : () => _entrar(usuario),
          ),
      ],
    );
  }
}

/// Um usuário da lista: nome e papel, com área de toque grande.
class _CartaoUsuario extends StatelessWidget {
  const _CartaoUsuario({required this.usuario, required this.aoTocar});

  final UsuarioLogado usuario;
  final VoidCallback? aoTocar;

  @override
  Widget build(BuildContext context) {
    final ehMotorista = usuario.papel == Papel.motorista;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Icon(
          ehMotorista ? Icons.directions_bus : Icons.family_restroom,
          size: 32,
        ),
        title: Text(usuario.nome, style: const TextStyle(fontSize: 20)),
        subtitle: Text(
          ehMotorista ? 'Motorista' : 'Responsável',
          style: const TextStyle(fontSize: 16),
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: aoTocar,
      ),
    );
  }
}
