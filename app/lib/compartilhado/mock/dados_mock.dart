import '../api_client.dart';

/// Dados simulados para o app funcionar sem o servidor.
///
/// Simula o servidor: recebe as mesmas requisições e devolve as respostas no
/// mesmo formato definido no contrato da API (seção 3 do backlog). Permite
/// desenvolver e testar as telas antes de o servidor ficar pronto.
///
/// Usa os dados de teste combinados pelo grupo (seção 6 do backlog):
/// a rota de hoje com Ana Souza, Beatriz Reis e Carlos Lima confirmados,
/// e Bruno Alves ausente (por isso não aparece na lista).
///
/// Os embarques ficam guardados apenas enquanto o app está aberto. Ao fechar
/// o app, os dados voltam ao estado inicial.
///
/// Classe de apoio para desenvolvimento e testes: não faz parte do caso de
/// uso avaliado (UC-S05).
class DadosMock {
  DadosMock({this.atraso = const Duration(milliseconds: 300)});

  /// Tempo de espera antes de cada resposta, para simular a demora da rede.
  /// Permite ver as mensagens de carregamento nas telas.
  final Duration atraso;

  /// Identificador da rota de hoje.
  static const int rotaId = 1;

  /// Identificador do motorista ativo da van dessa rota.
  static const int motoristaAtivoId = 1;

  /// Usuários exibidos na tela de login.
  /// Os nomes dos motoristas e responsáveis devem ser os mesmos do banco de
  /// dados de teste (seed). Se forem alterados lá, alterar aqui também.
  static const List<Map<String, dynamic>> usuarios = [
    {'id': 1, 'nome': 'Marcos Pereira', 'papel': 'MOTORISTA'}, // motorista ativo da van da rota
    {'id': 2, 'nome': 'Rafael Costa', 'papel': 'MOTORISTA'}, // sem vínculo com van (para testar a RN-012)
    {'id': 1, 'nome': 'Juliana Souza', 'papel': 'RESPONSAVEL'}, // responsável pela Ana
    {'id': 2, 'nome': 'Ricardo Souza', 'papel': 'RESPONSAVEL'}, // responsável pela Ana
    {'id': 3, 'nome': 'Fernanda Reis', 'papel': 'RESPONSAVEL'}, // responsável pela Beatriz
    {'id': 4, 'nome': 'Paula Alves', 'papel': 'RESPONSAVEL'}, // responsável pelo Bruno
  ];

  /// Dados que aparecem no topo da tela "Rota do dia".
  static const Map<String, dynamic> rotaDeHoje = {
    'rotaId': rotaId,
    'trajeto': 'IDA',
    'horarioPrevisto': '2026-11-16T06:30:00-03:00',
    'placa': 'ABC-1D23',
  };

  /// Alunos com presença confirmada na rota de hoje, na ordem das paradas.
  static const List<Map<String, dynamic>> alunosConfirmados = [
    {
      'alunoId': 1,
      'nome': 'Ana Souza',
      'ordem': 1,
      'pontoParada': {'endereco': 'Av. Brasil, 1500', 'latitude': -23.4205, 'longitude': -51.9331},
    },
    {
      'alunoId': 2,
      'nome': 'Beatriz Reis',
      'ordem': 2,
      'pontoParada': {'endereco': 'Rua Neo Alves Martins, 820', 'latitude': -23.4231, 'longitude': -51.9387},
    },
    {
      'alunoId': 3,
      'nome': 'Carlos Lima',
      'ordem': 3,
      'pontoParada': {'endereco': 'Rua das Flores, 210', 'latitude': -23.4262, 'longitude': -51.9410},
    },
  ];

  /// O aluno 4 (Bruno Alves) está ausente hoje.
  /// Por isso não aparece na lista e não pode embarcar (RN-010).
  static const int alunoAusenteId = 4;

  /// Responsáveis de cada aluno (identificador do aluno -> identificadores dos responsáveis).
  /// Cada responsável só recebe avisos dos seus alunos (RN-002).
  /// O Carlos (aluno 3) é maior de idade e não tem responsável.
  static const Map<int, List<int>> responsaveisDoAluno = {
    1: [1, 2],
    2: [3],
    4: [4],
  };

  /// Alunos que já embarcaram hoje.
  final Set<int> _embarcados = {};

  /// Embarques já recebidos, identificados pelo código único de cada um (registroId).
  /// Evita registrar o mesmo embarque duas vezes.
  final Map<String, int> _registrosProcessados = {}; // registroId -> alunoId

  /// Avisos criados para os responsáveis.
  final List<Map<String, dynamic>> _notificacoes = [];

  /// Identificador do próximo aviso a ser criado.
  int _proximaNotificacaoId = 1;

  /// Volta os dados ao estado inicial (nenhum aluno embarcado, nenhum aviso).
  void reiniciar() {
    _embarcados.clear();
    _registrosProcessados.clear();
    _notificacoes.clear();
    _proximaNotificacaoId = 1;
  }

  /// Recebe uma requisição do app e devolve a resposta, como o servidor faria.
  Future<RespostaApi> responder(
    String metodo,
    String caminho, {
    String? token,
    Object? corpo,
  }) async {
    if (atraso > Duration.zero) await Future<void>.delayed(atraso);
    return _rotear(metodo, Uri.parse(caminho), token, corpo);
  }

  /// Identifica qual requisição foi feita e direciona para a resposta correspondente.
  RespostaApi _rotear(String metodo, Uri uri, String? token, Object? corpo) {
    final partes = uri.pathSegments;

    // Requisições que não exigem login: listar usuários e entrar.
    if (metodo == 'GET' && _igual(partes, ['usuarios'])) {
      return RespostaApi(200, usuarios);
    }
    if (metodo == 'POST' && _igual(partes, ['login'])) {
      return _login(corpo);
    }

    // As demais requisições exigem um token válido.
    // Sem token válido, responde 401 (não autenticado).
    final usuario = _usuarioDoToken(token);
    if (usuario == null) return const RespostaApi(401, {'erro': 'Não autenticado'});
    final papel = usuario['papel'] as String;
    final id = usuario['id'] as int;

    // Rota de hoje: apenas para motorista. Motorista sem van não tem rota (404).
    if (metodo == 'GET' && _igual(partes, ['rotas', 'hoje'])) {
      if (papel != 'MOTORISTA') return const RespostaApi(403);
      if (id != motoristaAtivoId) return const RespostaApi(404, {'erro': 'Motorista sem rota hoje'});
      return RespostaApi(200, rotaDeHoje);
    }

    if (partes.length >= 3 && partes[0] == 'rotas') {
      final rota = int.tryParse(partes[1]);
      if (rota != rotaId) return const RespostaApi(404, {'erro': 'Rota não existe'});
      // RN-012: apenas o motorista ativo da van dessa rota pode ver os alunos
      // e registrar embarques. Qualquer outro usuário recebe 403 (sem permissão).
      if (papel != 'MOTORISTA' || id != motoristaAtivoId) {
        return const RespostaApi(403, {'erro': 'Você não é o motorista ativo desta van.'});
      }
      // Lista de alunos da rota.
      if (metodo == 'GET' && partes.length == 3 && partes[2] == 'alunos') {
        return RespostaApi(200, _listarAlunos());
      }
      // Registrar o embarque de um aluno.
      if (metodo == 'POST' && partes.length == 3 && partes[2] == 'embarques') {
        return _registrarEmbarque(corpo as Map<String, dynamic>);
      }
      // Envia de uma vez os embarques que ficaram guardados sem conexão.
      if (metodo == 'POST' && partes.length == 4 && partes[2] == 'embarques' && partes[3] == 'sincronizar') {
        return _sincronizar(corpo as Map<String, dynamic>);
      }
    }

    // Avisos do responsável logado (usados na tela "Avisos").
    if (metodo == 'GET' && _igual(partes, ['notificacoes'])) {
      if (papel != 'RESPONSAVEL') return const RespostaApi(403);
      return RespostaApi(200, _avisosDoResponsavel(id, uri.queryParameters['desde']));
    }
    // Marca um aviso como lido.
    if (metodo == 'PATCH' && partes.length == 3 && partes[0] == 'notificacoes' && partes[2] == 'lida') {
      final aviso = _notificacoes.where((n) => n['id'] == int.tryParse(partes[1]));
      if (aviso.isEmpty) return const RespostaApi(404);
      aviso.first['lida'] = true;
      return const RespostaApi(204);
    }

    // Requisição que não existe nos dados simulados.
    return const RespostaApi(404, {'erro': 'Rota da API não existe no mock'});
  }

  /// Login: confere se o usuário existe e devolve o token de acesso.
  RespostaApi _login(Object? corpo) {
    final dados = corpo as Map<String, dynamic>;
    final encontrado = usuarios.where(
      (u) => u['id'] == dados['id'] && u['papel'] == dados['papel'],
    );
    if (encontrado.isEmpty) return const RespostaApi(401, {'erro': 'Usuário não encontrado'});
    return RespostaApi(200, {'token': 'mock-${dados['papel']}-${dados['id']}'});
  }

  /// Identifica o usuário a partir do token.
  /// O token simulado tem o formato "mock-PAPEL-ID", ex.: "mock-MOTORISTA-1".
  Map<String, dynamic>? _usuarioDoToken(String? token) {
    if (token == null || !token.startsWith('mock-')) return null;
    final partes = token.split('-'); // mock-PAPEL-ID
    if (partes.length != 3) return null;
    final encontrado = usuarios.where(
      (u) => u['papel'] == partes[1] && u['id'] == int.tryParse(partes[2]),
    );
    return encontrado.isEmpty ? null : encontrado.first;
  }

  /// Lista os alunos da rota, indicando se cada um já embarcou.
  List<Map<String, dynamic>> _listarAlunos() => [
        for (final aluno in alunosConfirmados)
          {
            ...aluno,
            'status': _embarcados.contains(aluno['alunoId']) ? 'EMBARCADO' : 'CONFIRMADO',
          },
      ];

  /// Registra o embarque de um aluno (UC-S05).
  ///
  /// Respostas possíveis:
  ///   201 = embarque registrado
  ///   200 = esse embarque já tinha sido recebido antes (não é registrado de novo)
  ///   404 = o aluno não existe nesta rota
  ///   409 = o aluno está ausente hoje ou já embarcou
  RespostaApi _registrarEmbarque(Map<String, dynamic> registro) {
    final registroId = registro['registroId'] as String;
    final alunoId = registro['alunoId'] as int;

    // Cada embarque tem um código único (registroId), gerado no celular.
    // Se o mesmo embarque chegar duas vezes (comum quando a conexão volta),
    // não é registrado de novo: apenas confirma que já foi recebido.
    if (_registrosProcessados.containsKey(registroId)) {
      return RespostaApi(200, {'alunoId': alunoId, 'status': 'EMBARCADO'});
    }
    final confirmado = alunosConfirmados.any((a) => a['alunoId'] == alunoId);
    if (!confirmado) {
      if (alunoId == alunoAusenteId) {
        return const RespostaApi(409, {'erro': 'Aluno não está confirmado nesta rota'});
      }
      return const RespostaApi(404, {'erro': 'Aluno não existe nesta rota'});
    }
    if (_embarcados.contains(alunoId)) {
      return RespostaApi(409, {'erro': '${_nomeDoAluno(alunoId)} já embarcou.'});
    }

    // Embarque válido: registra e gera os avisos para os responsáveis.
    _embarcados.add(alunoId);
    _registrosProcessados[registroId] = alunoId;
    _criarAvisos(alunoId, registro['dataHora'] as String);
    return RespostaApi(201, {'alunoId': alunoId, 'status': 'EMBARCADO'});
  }

  /// Recebe vários embarques de uma vez (os que ficaram guardados sem conexão)
  /// e devolve o resultado de cada um.
  RespostaApi _sincronizar(Map<String, dynamic> corpo) {
    final registros = (corpo['registros'] as List).cast<Map<String, dynamic>>();
    final resultados = [
      for (final r in registros)
        {'registroId': r['registroId'], 'codigo': _registrarEmbarque(r).codigo},
    ];
    return RespostaApi(200, {'resultados': resultados});
  }

  /// Cria o aviso de embarque para cada responsável do aluno (UC-I02).
  /// Se o aluno não tem responsável, como o Carlos, nenhum aviso é gerado
  /// (fluxo alternativo A1 do UC-I02).
  void _criarAvisos(int alunoId, String dataHora) {
    final nome = _nomeDoAluno(alunoId);
    for (final responsavelId in responsaveisDoAluno[alunoId] ?? const <int>[]) {
      _notificacoes.add({
        'id': _proximaNotificacaoId++,
        'responsavelId': responsavelId,
        'tipo': 'EMBARQUE',
        'alunoNome': nome,
        'mensagem': '$nome embarcou na van às ${_horaDeBrasilia(dataHora)}.',
        'dataHora': dataHora,
        'lida': false,
      });
    }
  }

  /// Devolve apenas os avisos dos alunos desse responsável (RN-002), do mais
  /// recente para o mais antigo. Se receber uma data ("desde"), devolve apenas
  /// os avisos posteriores a ela.
  List<Map<String, dynamic>> _avisosDoResponsavel(int responsavelId, String? desde) {
    final limite = desde == null ? null : DateTime.tryParse(desde);
    final avisos = _notificacoes.where((n) {
      if (n['responsavelId'] != responsavelId) return false;
      if (limite == null) return true;
      return DateTime.parse(n['dataHora'] as String).isAfter(limite);
    }).map((n) => Map<String, dynamic>.from(n)..remove('responsavelId')).toList();
    return avisos.reversed.toList(); // mais recente primeiro
  }

  /// Busca o nome do aluno pelo identificador.
  String _nomeDoAluno(int alunoId) =>
      alunosConfirmados.firstWhere((a) => a['alunoId'] == alunoId)['nome'] as String;

  /// Formata a hora como HH:MM (ex.: 06:42), no horário de Brasília.
  String _horaDeBrasilia(String dataHora) {
    final hora = DateTime.parse(dataHora).toUtc().subtract(const Duration(hours: 3));
    String dois(int n) => n.toString().padLeft(2, '0');
    return '${dois(hora.hour)}:${dois(hora.minute)}';
  }

  /// Compara duas listas de texto (usado para identificar o caminho da requisição).
  static bool _igual(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
