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

/// Mostra os alunos vinculados e os avisos do dia (UC-I02, RF-011, RN-002).
class TelaAvisos extends StatefulWidget {
  const TelaAvisos({super.key, required this.usuario});

  final UsuarioLogado usuario;

  @override
  State<TelaAvisos> createState() => _TelaAvisosState();
}

class _TelaAvisosState extends State<TelaAvisos> {
  AvisosService? _service;
  late Future<AvisosDoDia> _carregamento;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final service = EscopoAvisos.of(context);
    if (service != _service) {
      _service = service;
      _carregamento = service.carregar();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Avisos')),
      body: FutureBuilder<AvisosDoDia>(
        future: _carregamento,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return const Center(
              child: Text('Não foi possível carregar os avisos.'),
            );
          }
          final dados = snapshot.requireData;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              for (final aluno in dados.alunos)
                _CardAluno(
                  aluno: aluno,
                  embarque: dados.embarquesPorAluno[aluno.id],
                ),
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
                  leading: aviso.lida
                      ? null
                      : const Icon(
                          Icons.circle,
                          size: 8,
                          color: Colors.blue,
                          semanticLabel: 'Não lido',
                        ),
                  title: Text(aviso.mensagem),
                  trailing: Text(
                    _tempoDecorrido(aviso.dataHora, dados.consultadoEm),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  String _tempoDecorrido(DateTime evento, DateTime referencia) {
    final tempo = referencia.difference(evento);
    if (tempo.inMinutes < 1) return 'agora';
    if (tempo.inHours < 1) return 'há ${tempo.inMinutes} min';
    return 'há ${tempo.inHours} h';
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

  String _horaMinuto(DateTime evento) {
    final hora = horarioEmBrasilia(evento);
    String dois(int numero) => numero.toString().padLeft(2, '0');
    return '${dois(hora.hour)}:${dois(hora.minute)}';
  }
}
