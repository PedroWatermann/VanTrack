import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../compartilhado/cores.dart';
import '../aplicacao/modulo_embarque.dart';
import '../aplicacao/rota_do_dia_service.dart';
import '../dominio/aluno_da_rota.dart';
import '../dominio/excecoes.dart';
import '../dominio/rota_do_dia.dart';
import 'faixa_sem_conexao.dart';

/// Situação de um aluno na tela.
enum _Situacao { aguardando, enviado, pendente }

/// Tela "Rota do dia" do motorista (UC-R02; seção 10 do backlog, Tela 2).
///
/// Mostra a rota de hoje em três partes:
/// - "Próxima parada": o primeiro aluno da ordem que ainda não embarcou, em
///   destaque, com o botão "Embarcou" grande, de largura total (RNF-005);
/// - "Depois": os demais alunos que ainda vão embarcar, com botão menor
///   (o aluno pode embarcar fora da ordem);
/// - "Na van": quem já embarcou, sempre com cor, ícone e texto.
///
/// Um toque em "Embarcou" registra o embarque, sem diálogo de confirmação
/// (RNF-005): o aluno vai na hora para "Na van" e a próxima parada passa a ser
/// destacada. Embarques pendentes (sem conexão) ficam em âmbar e mudam para
/// verde quando são sincronizados, sem recarregar a tela.
///
/// A tela só conversa com o [ModuloEmbarque] e com o [RotaDoDiaService],
/// nunca direto com a API.
class TelaRotaDoDia extends StatefulWidget {
  const TelaRotaDoDia({
    super.key,
    required this.modulo,
    required this.rotaDoDiaService,
    this.online,
  });

  /// Módulo usado para registrar os embarques.
  final ModuloEmbarque modulo;

  /// Serviço que busca a rota de hoje e os alunos.
  final RotaDoDiaService rotaDoDiaService;

  /// Estado da conectividade do aparelho; quando `false`, exibe [FaixaSemConexao] (RNF-003).
  final ValueListenable<bool>? online;

  @override
  State<TelaRotaDoDia> createState() => _TelaRotaDoDiaState();
}

class _TelaRotaDoDiaState extends State<TelaRotaDoDia> {
  RotaDoDia? _rota;
  List<AlunoDaRota> _alunos = const [];

  /// Situação de cada aluno, pelo identificador.
  final Map<int, _Situacao> _situacao = {};

  /// Hora do embarque registrado neste aparelho, pelo identificador do aluno.
  final Map<int, DateTime> _horaDoEmbarque = {};

  /// Alunos com um registro de embarque em andamento (evita toque duplo).
  final Set<int> _registrando = {};

  /// Acompanha os embarques pendentes que são sincronizados ou recusados.
  late final _assinaturaPendentes = widget.modulo.aoMudarPendentes.listen(_aoMudarPendente);

  bool _carregando = true;
  String? _erro;

  /// Indica se o erro de carregamento permite tentar de novo.
  bool _podeTentarDeNovo = false;

  @override
  void initState() {
    super.initState();
    _assinaturaPendentes; // começa a acompanhar os embarques pendentes
    _carregar();
  }

  @override
  void dispose() {
    _assinaturaPendentes.cancel();
    super.dispose();
  }

  /// Busca a rota de hoje e abre a lista de alunos.
  Future<void> _carregar() async {
    setState(() {
      _carregando = true;
      _erro = null;
    });
    try {
      final rota = await widget.rotaDoDiaService.buscarRotaDoDia();
      _rota = rota;
      await abrirRota(rota.rotaId);
    } on EnvioRecusadoException catch (erro) {
      _mostrarErro(_mensagemDeRecusa(erro.codigoHttp), podeTentarDeNovo: false);
    } catch (_) {
      _mostrarErro('Não foi possível carregar a rota. Tente de novo.', podeTentarDeNovo: true);
    }
  }

  /// Carrega os alunos confirmados da rota (UC-S05 passo 1).
  Future<void> abrirRota(int rotaId) async {
    final alunos = await widget.rotaDoDiaService.listarAlunosConfirmados(rotaId);
    // Embarques feitos sem conexão que ainda não foram enviados (RNF-006).
    final pendentes = await widget.modulo.listarPendentes(rotaId);
    if (!mounted) return;
    setState(() {
      _alunos = alunos;
      _situacao
        ..clear()
        ..addEntries(alunos.map((a) => MapEntry(
              a.alunoId,
              a.embarcado ? _Situacao.enviado : _Situacao.aguardando,
            )));
      for (final pendente in pendentes) {
        if (_situacao[pendente.alunoId] == _Situacao.aguardando) {
          _situacao[pendente.alunoId] = _Situacao.pendente;
          _horaDoEmbarque[pendente.alunoId] = pendente.dataHora;
        }
      }
      _carregando = false;
    });
  }

  /// Registra o embarque do aluno com um toque (UC-S05 passos 2 a 4; UC-R02).
  ///
  /// O aluno vai para "Na van" na hora do toque. Quando o módulo responde, a
  /// situação fica verde (enviado) ou âmbar (pendente). Se o registro falhar,
  /// o aluno volta para a lista e uma mensagem é mostrada.
  Future<void> confirmarEmbarque(int alunoId) async {
    final rota = _rota;
    if (rota == null || _registrando.contains(alunoId)) return;

    setState(() {
      _registrando.add(alunoId);
      _situacao[alunoId] = _Situacao.enviado;
      _horaDoEmbarque[alunoId] = DateTime.now();
    });

    try {
      final resultado = await widget.modulo.registrarEmbarque(rota.rotaId, alunoId);
      if (!mounted) return;
      setState(() {
        _situacao[alunoId] = resultado.status == StatusEnvio.pendente
            ? _Situacao.pendente
            : _Situacao.enviado;
        _horaDoEmbarque[alunoId] = resultado.dataHora;
      });
    } on EmbarqueException catch (erro) {
      if (!mounted) return;
      switch (erro.codigoHttp) {
        case 409:
          // O aluno já tinha embarcado: ele fica em "Na van".
          setState(() => _horaDoEmbarque.remove(alunoId));
          _avisar('${_nomeDoAluno(alunoId)} já embarcou.');
        case 403:
          // RN-012: só o motorista ativo da van registra embarques.
          _mostrarErro(_mensagemDeRecusa(403), podeTentarDeNovo: false);
        default:
          _voltarParaAguardando(alunoId);
          _avisar('Não foi possível registrar. Tente de novo.');
      }
    } catch (_) {
      if (!mounted) return;
      _voltarParaAguardando(alunoId);
      _avisar('Não foi possível registrar. Tente de novo.');
    } finally {
      if (mounted) setState(() => _registrando.remove(alunoId));
    }
  }

  /// Um embarque pendente foi sincronizado (fica verde) ou recusado pelo
  /// servidor (volta para a lista, a menos que o aluno já tenha embarcado).
  void _aoMudarPendente(EventoPendente evento) {
    if (!mounted) return;
    if (evento.sincronizado || evento.codigoHttp == 409) {
      setState(() => _situacao[evento.alunoId] = _Situacao.enviado);
      return;
    }
    _voltarParaAguardando(evento.alunoId);
    _avisar('O embarque de ${_nomeDoAluno(evento.alunoId)} foi recusado pelo servidor.');
  }

  void _voltarParaAguardando(int alunoId) {
    setState(() {
      _situacao[alunoId] = _Situacao.aguardando;
      _horaDoEmbarque.remove(alunoId);
    });
  }

  /// Mensagem rápida no rodapé da tela.
  void _avisar(String mensagem) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(mensagem)));
  }

  String _nomeDoAluno(int alunoId) {
    final aluno = _alunos.where((a) => a.alunoId == alunoId);
    return aluno.isEmpty ? 'O aluno' : aluno.first.nome;
  }

  void _mostrarErro(String mensagem, {required bool podeTentarDeNovo}) {
    if (!mounted) return;
    setState(() {
      _erro = mensagem;
      _podeTentarDeNovo = podeTentarDeNovo;
      _carregando = false;
    });
  }

  String _mensagemDeRecusa(int codigoHttp) => switch (codigoHttp) {
        403 => 'Você não é o motorista ativo desta van.', // RN-012
        404 => 'Você não tem rota para hoje.',
        _ => 'Não foi possível carregar a rota. Tente de novo.',
      };

  /// Ação do botão "Embarcou" do aluno (desativado enquanto registra).
  VoidCallback? _aoTocar(int alunoId) =>
      _registrando.contains(alunoId) ? null : () => confirmarEmbarque(alunoId);

  List<AlunoDaRota> get _aguardando =>
      _alunos.where((a) => _situacao[a.alunoId] == _Situacao.aguardando).toList();

  List<AlunoDaRota> get _naVan =>
      _alunos.where((a) => _situacao[a.alunoId] != _Situacao.aguardando).toList();

  @override
  Widget build(BuildContext context) {
    final rota = _rota;
    return Scaffold(
      appBar: AppBar(
        title: Text(rota == null || _carregando || _erro != null
            ? 'Rota do dia'
            : 'Rota do dia · ${_nomeDoTrajeto(rota.trajeto)} · ${_horaBrasilia(rota.horarioPrevisto)}'),
      ),
      body: SafeArea(child: _conteudo()),
    );
  }

  Widget _conteudo() {
    if (_carregando) {
      return const _Mensagem(
        texto: 'Carregando a rota…',
        icone: CircularProgressIndicator(),
      );
    }

    final erro = _erro;
    if (erro != null) {
      return _Mensagem(
        texto: erro,
        icone: const Icon(Icons.block, size: 48),
        acao: _podeTentarDeNovo
            ? FilledButton(onPressed: _carregar, child: const Text('Tentar de novo'))
            : null,
      );
    }

    final rota = _rota!;
    final aguardando = _aguardando;
    final naVan = _naVan;

    return Column(
      children: [
        if (widget.online != null)
          ValueListenableBuilder<bool>(
            valueListenable: widget.online!,
            builder: (_, estaOnline, _) => FaixaSemConexao(semConexao: !estaOnline),
          )
        else
          const FaixaSemConexao(semConexao: false),
        _Cabecalho(rota: rota, naVan: naVan.length, total: _alunos.length),
        Expanded(
          child: _alunos.isEmpty
              ? const _Mensagem(texto: 'Nenhum aluno confirmado para esta rota.')
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    if (aguardando.isEmpty)
                      const _AvisoTodosEmbarcaram()
                    else ...[
                      const _TituloSecao('PRÓXIMA PARADA'),
                      _CartaoProximaParada(
                        aluno: aguardando.first,
                        aoEmbarcar: _aoTocar(aguardando.first.alunoId),
                      ),
                      if (aguardando.length > 1) ...[
                        const SizedBox(height: 24),
                        const _TituloSecao('DEPOIS'),
                        for (final aluno in aguardando.skip(1))
                          _LinhaDepois(aluno: aluno, aoEmbarcar: _aoTocar(aluno.alunoId)),
                      ],
                    ],
                    const SizedBox(height: 24),
                    _TituloSecao('NA VAN (${naVan.length})'),
                    if (naVan.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Text('Nenhum aluno embarcou ainda.', style: TextStyle(fontSize: 16)),
                      ),
                    for (final aluno in naVan)
                      _LinhaNaVan(
                        aluno: aluno,
                        pendente: _situacao[aluno.alunoId] == _Situacao.pendente,
                        hora: _horaDoEmbarque[aluno.alunoId],
                      ),
                  ],
                ),
        ),
      ],
    );
  }
}

/// Cabeçalho com a placa da van e quantos alunos já estão na van.
class _Cabecalho extends StatelessWidget {
  const _Cabecalho({required this.rota, required this.naVan, required this.total});

  final RotaDoDia rota;
  final int naVan;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Text('Van ${rota.placa}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const Spacer(),
          Text('$naVan de $total na van', style: const TextStyle(fontSize: 18)),
        ],
      ),
    );
  }
}

/// Título de cada parte da tela ("PRÓXIMA PARADA", "DEPOIS", "NA VAN").
class _TituloSecao extends StatelessWidget {
  const _TituloSecao(this.texto);

  final String texto;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        texto,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 1),
      ),
    );
  }
}

/// Número da parada dentro de um círculo.
class _NumeroParada extends StatelessWidget {
  const _NumeroParada(this.ordem);

  final int ordem;

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: 18,
      child: Text('$ordem', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
    );
  }
}

/// Próxima parada em destaque, com o botão "Embarcou" grande, de largura
/// total e no mínimo 56 de altura (RNF-005).
class _CartaoProximaParada extends StatelessWidget {
  const _CartaoProximaParada({required this.aluno, required this.aoEmbarcar});

  final AlunoDaRota aluno;
  final VoidCallback? aoEmbarcar;

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: CoresApp.verde, width: 2),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _NumeroParada(aluno.ordem),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(aluno.nome, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                      Text(aluno.endereco, style: const TextStyle(fontSize: 18)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 64,
              child: FilledButton(
                onPressed: aoEmbarcar,
                style: FilledButton.styleFrom(backgroundColor: CoresApp.verde),
                child: const Text('EMBARCOU', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Aluno que vai embarcar depois da próxima parada, com botão menor.
class _LinhaDepois extends StatelessWidget {
  const _LinhaDepois({required this.aluno, required this.aoEmbarcar});

  final AlunoDaRota aluno;
  final VoidCallback? aoEmbarcar;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          _NumeroParada(aluno.ordem),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(aluno.nome, style: const TextStyle(fontSize: 18)),
                Text(aluno.endereco, style: const TextStyle(fontSize: 14)),
              ],
            ),
          ),
          SizedBox(
            height: 48,
            child: OutlinedButton(onPressed: aoEmbarcar, child: const Text('Embarcou')),
          ),
        ],
      ),
    );
  }
}

/// Aluno que já está na van: verde com check quando o servidor recebeu,
/// âmbar com nuvem riscada quando ainda está pendente de envio.
class _LinhaNaVan extends StatelessWidget {
  const _LinhaNaVan({required this.aluno, required this.pendente, required this.hora});

  final AlunoDaRota aluno;
  final bool pendente;

  /// Hora do embarque, quando foi registrado neste aparelho.
  final DateTime? hora;

  @override
  Widget build(BuildContext context) {
    final horaDoEmbarque = hora;
    final cor = pendente ? CoresApp.ambar : CoresApp.verde;
    final texto = pendente
        ? 'Pendente de sincronização'
        : horaDoEmbarque == null
            ? 'Embarcou'
            : 'Embarcou às ${_horaBrasilia(horaDoEmbarque)}';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(pendente ? Icons.cloud_off : Icons.check_circle, color: cor, size: 28),
          const SizedBox(width: 12),
          Expanded(child: Text(aluno.nome, style: const TextStyle(fontSize: 18))),
          Text(texto, style: TextStyle(fontSize: 16, color: cor, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

/// Aviso mostrado quando todos os alunos já embarcaram.
class _AvisoTodosEmbarcaram extends StatelessWidget {
  const _AvisoTodosEmbarcaram();

  @override
  Widget build(BuildContext context) {
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(Icons.check_circle, color: CoresApp.verde, size: 32),
            SizedBox(width: 12),
            Text('Todos os alunos embarcaram', style: TextStyle(fontSize: 20)),
          ],
        ),
      ),
    );
  }
}

/// Mensagem centralizada (carregando, erro ou lista vazia).
class _Mensagem extends StatelessWidget {
  const _Mensagem({required this.texto, this.icone, this.acao});

  final String texto;
  final Widget? icone;
  final Widget? acao;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icone != null) ...[icone!, const SizedBox(height: 16)],
            Text(texto, textAlign: TextAlign.center, style: const TextStyle(fontSize: 20)),
            if (acao != null) ...[const SizedBox(height: 16), acao!],
          ],
        ),
      ),
    );
  }
}

/// "IDA" -> "Ida", "VOLTA" -> "Volta".
String _nomeDoTrajeto(String trajeto) =>
    trajeto.isEmpty ? trajeto : trajeto[0] + trajeto.substring(1).toLowerCase();

/// Hora no formato HH:MM, no horário de Brasília (UTC-3).
String _horaBrasilia(DateTime dataHora) {
  final hora = dataHora.toUtc().subtract(const Duration(hours: 3));
  String dois(int n) => n.toString().padLeft(2, '0');
  return '${dois(hora.hour)}:${dois(hora.minute)}';
}
