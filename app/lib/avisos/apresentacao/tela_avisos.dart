import 'dart:async';

import 'package:flutter/material.dart';

import '../../compartilhado/cores.dart';
import '../../compartilhado/sessao.dart';
import '../aplicacao/avisos_service.dart';
import '../dominio/aluno_do_responsavel.dart';
import '../dominio/aviso.dart';

/// Entrega à rota do responsável o serviço que usa sua sessão (UC-I02, RN-002).
class EscopoAvisos extends InheritedWidget {
  const EscopoAvisos({super.key, required this.service, required super.child});

  final AvisosService service;

  static AvisosService of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<EscopoAvisos>()!.service;

  @override
  bool updateShouldNotify(EscopoAvisos oldWidget) =>
      service != oldWidget.service;
}

/// Atualiza os avisos do responsável e preserva a última consulta sem conexão
/// (UC-I02, RF-011, RN-002, RNF-003).
class TelaAvisos extends StatefulWidget {
  const TelaAvisos({super.key, required this.usuario, this.aoSair});

  final UsuarioLogado usuario;

  /// Ação do botão "Sair" da barra do topo (troca de usuário). Sem ela, o
  /// botão não aparece (Bug VT-75).
  final VoidCallback? aoSair;

  @override
  State<TelaAvisos> createState() => _TelaAvisosState();
}

class _TelaAvisosState extends State<TelaAvisos> {
  AvisosService? _service;
  AvisosDoDia? _dados;
  Timer? _atualizacao;
  Timer? _relogio;
  bool _consultando = false;
  bool _semConexao = false;
  final _emLeitura = <int>{};
  final _lidos = <int>{};

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final service = EscopoAvisos.of(context);
    if (identical(service, _service)) return;

    _service = service;
    _dados = null;
    _consultando = false;
    _semConexao = false;
    _emLeitura.clear();
    _lidos.clear();
    _atualizacao?.cancel();
    _relogio?.cancel();
    _atualizacao = Timer.periodic(
      const Duration(seconds: 10),
      (_) => unawaited(_atualizar(service)),
    );
    _relogio = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_dados != null) setState(() {});
    });
    unawaited(_atualizar(service));
  }

  @override
  void dispose() {
    _atualizacao?.cancel();
    _relogio?.cancel();
    super.dispose();
  }

  Future<void> _atualizar(AvisosService service) async {
    if (_consultando) return;
    _consultando = true;
    try {
      final dados = await service.carregar();
      if (!mounted || !identical(service, _service)) return;
      setState(() {
        _dados = dados;
        _semConexao = false;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !identical(dados, _dados)) return;
        for (final aviso in dados.avisos) {
          if (!aviso.lida && !_lidos.contains(aviso.id)) {
            unawaited(_marcarComoLida(service, aviso.id));
          }
        }
      });
    } catch (_) {
      // RNF-003: uma consulta que falhou preserva os dados da última consulta.
      if (mounted && identical(service, _service)) {
        setState(() => _semConexao = true);
      }
    } finally {
      if (identical(service, _service)) _consultando = false;
    }
  }

  Future<void> _marcarComoLida(AvisosService service, int id) async {
    if (!_emLeitura.add(id)) return;
    try {
      await service.marcarComoLida(id);
    } catch (_) {
      // Um PATCH que falhou pode ser tentado novamente após a próxima consulta.
      return;
    } finally {
      if (identical(service, _service)) _emLeitura.remove(id);
    }
    if (mounted && identical(service, _service)) {
      setState(() => _lidos.add(id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final dados = _dados;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Avisos'),
        actions: [
          if (widget.aoSair != null)
            IconButton(
              icon: const Icon(Icons.logout),
              tooltip: 'Sair',
              onPressed: widget.aoSair,
            ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_semConexao)
            _FaixaAvisosSemConexao(ultimaAtualizacao: dados?.consultadoEm),
          if (dados != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Text(
                'Atualizado há ${_segundosDesde(dados.consultadoEm)} s',
              ),
            ),
          Expanded(
            child: dados != null
                ? _conteudo(dados)
                : _semConexao
                ? const Center(
                    child: Text('Não foi possível carregar os avisos.'),
                  )
                : const Center(child: CircularProgressIndicator()),
          ),
        ],
      ),
    );
  }

  Widget _conteudo(AvisosDoDia dados) {
    final agora = _service!.agora();
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        for (final aluno in dados.alunos)
          _CardAluno(aluno: aluno, embarque: dados.embarquesPorAluno[aluno.id]),
        const SizedBox(height: 16),
        Text('HOJE', style: Theme.of(context).textTheme.titleSmall),
        if (dados.avisos.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Text(
              'Nenhum aviso hoje. Você será avisado quando o aluno embarcar.',
            ),
          ),
        for (final aviso in dados.avisos)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: aviso.lida || _lidos.contains(aviso.id)
                ? null
                : const Icon(
                    Icons.circle,
                    size: 8,
                    color: Colors.blue,
                    semanticLabel: 'Não lido',
                  ),
            title: Text(aviso.mensagem),
            trailing: Text(_tempoDecorrido(aviso.dataHora, agora)),
          ),
      ],
    );
  }

  int _segundosDesde(DateTime consulta) {
    final segundos = _service!.agora().difference(consulta).inSeconds;
    return segundos < 0 ? 0 : segundos;
  }

  String _tempoDecorrido(DateTime evento, DateTime referencia) {
    final tempo = referencia.difference(evento);
    if (tempo.inMinutes < 1) return 'agora';
    if (tempo.inHours < 1) return 'há ${tempo.inMinutes} min';
    return 'há ${tempo.inHours} h';
  }
}

/// Informa a indisponibilidade e o horário da última consulta (RNF-003).
class _FaixaAvisosSemConexao extends StatelessWidget {
  const _FaixaAvisosSemConexao({required this.ultimaAtualizacao});

  final DateTime? ultimaAtualizacao;

  @override
  Widget build(BuildContext context) {
    final horario = ultimaAtualizacao;
    return Container(
      color: CoresApp.ambar,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          const Icon(Icons.wifi_off, color: Colors.black),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Sem conexão. Os avisos podem estar desatualizados.'
              '${horario == null ? '' : ' Última atualização às ${_horaMinuto(horario)}.'}',
              style: const TextStyle(color: Colors.black),
            ),
          ),
        ],
      ),
    );
  }
}

class _CardAluno extends StatelessWidget {
  const _CardAluno({required this.aluno, required this.embarque});

  final AlunoDoResponsavel aluno;
  final DateTime? embarque;

  @override
  Widget build(BuildContext context) {
    final hora = embarque;
    final cor = hora == null ? CoresApp.cinza : CoresApp.verde;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(aluno.nome, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(
                  hora == null ? Icons.radio_button_unchecked : Icons.circle,
                  size: 12,
                  color: cor,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    hora == null
                        ? 'Aguardando embarque'
                        : 'Na van desde ${_horaMinuto(hora)}',
                    style: TextStyle(color: cor),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

String _horaMinuto(DateTime evento) {
  final hora = horarioEmBrasilia(evento);
  String dois(int numero) => numero.toString().padLeft(2, '0');
  return '${dois(hora.hour)}:${dois(hora.minute)}';
}
