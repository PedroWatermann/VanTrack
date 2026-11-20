# Arquitetura do UC-S05 — Registrar Embarque

Projeto da solução do **UC-S05 Registrar Embarque**, com o `<<include>>` **UC-I02 Notificar
Responsável** e o fluxo alternativo **A1 — Sem conectividade** (RNF-006).

O caminho seguido é o pedido pela disciplina:

```text
REGRAS DE NEGÓCIO -> REQUISITOS -> CASO DE USO -> DIAGRAMA DE SEQUÊNCIA
  -> IDENTIFICAÇÃO DE CLASSES -> RESPONSABILIDADES -> DIAGRAMA DE CLASSES
  -> ARQUITETURA -> DIRETÓRIOS
```

| Situação deste documento | Task |
|---|---|
| Situação deste documento | Task |
|---|---|
| Seção 1 — Identificação das classes | B-01 (VT-21); revisada na **B-12 (VT-64)** |
| Seção 2 — Diagrama de classes | B-01 (VT-21); **diagramas atualizados com o código real na B-12 (VT-64)** |
| Seção 3 — Arquitetura em camadas | B-02 (VT-22); revisada na B-12 |
| Seção 4 — Estrutura de diretórios | B-02 (VT-22); **árvore real da `desenvolvimento` na B-12** |
| Seção 5 — Decisões arquiteturais | B-02 (VT-22); decisão 11 na B-12 |
| Seções 6 e 7 — Documentação das classes principais e rastreabilidade até as classes | B-03 (VT-23); nomes reais na B-12 |
| Seção 8 — Pontos para a equipe decidir | atualizada a cada task |

> **B-12:** este documento e os três diagramas foram conferidos com o código da
> `desenvolvimento` em 18/11 (Dia 5). O que ainda difere está na seção 8: o login
> fora do módulo `autenticacao/` (ponto 15, Bug) e a tela "Avisos" (ponto 19,
> pendente da C-06 e da C-07).

---

## 0. Ponto de partida (artefatos do 1º bimestre)

Os artefatos de origem estão no repositório da 1ª parte do trabalho, em `documentos/`
(atividades 01 a 04).

| Artefato | O que foi usado |
|---|---|
| Regras de negócio (atividade-02) | RN-002 (acesso só aos alunos vinculados), RN-009 (menor tem responsável), RN-010 (embarque só de quem está presente), RN-012 (um motorista ativo por van) |
| Requisitos (atividade-02) | RF-009 (registrar embarque), RF-011 (notificar responsável), RNF-005 (uma única ação), RNF-006 (sincronização offline em até 5 min) |
| Casos de uso (atividade-03) | UC-S05 (sistema), UC-R02 (real, telas), UC-I02 (`<<include>>`) |
| Diagramas de sequência (atividade-04) | `UC-S05.puml`, `UC-R02.puml`, `UC-I02.puml` e a tabela de responsabilidades dos participantes |
| Mapa de dados (atividade-01) | Entidades Van, Motorista, Vínculo motorista–van, Responsável, Aluno, Ponto de parada, Rota, Presença, Embarque, Notificação |
| Backlog (`01-backlog-uc-s05.md`) | Seção 3 (contrato da API e do módulo de embarque) e seção 4 (classes de cada membro) |

---

## 1. Identificação das classes

### 1.1 De onde cada classe veio: participantes dos diagramas de sequência

Cada participante dos diagramas de sequência foi analisado. Alguns viraram classes com o mesmo
nome, para manter a rastreabilidade. Outros não viraram classe, pelo motivo indicado.

| Participante (diagrama) | Tipo na sequência | Vira classe? | Classe(s) no projeto |
|---|---|---|---|
| Motorista (UC-S05, UC-R02) | ator | **Não como ator**: atores ficam fora do sistema. O sistema guarda os dados dele (entidade `Motorista`, um `Usuario`) e sabe quem está usando o app (`UsuarioLogado`) | `Motorista`, `Usuario`, `UsuarioLogado` |
| Responsável (UC-R02, UC-I02) | ator | **Não como ator**, pelo mesmo motivo. Aparece como entidade (`Responsavel`, um `Usuario`) e como destinatário da `Notificacao` | `Responsavel`, `Usuario` |
| TelaRotaDoDia (UC-S05) / Tela Rota do dia (UC-R02) | boundary | **Sim** (app) | `TelaRotaDoDia`, `FaixaSemConexao` |
| ArmazenamentoLocal (dispositivo) (UC-S05, A1) | participante | **Sim** (app, infraestrutura) | `ArmazenamentoLocal`, que implementa `FilaEmbarques` |
| EmbarqueController (UC-S05) | control | **Sim** (back-end, apresentação) | `EmbarqueController` |
| EmbarqueService (UC-S05, UC-I02) | serviço | **Sim** (back-end, aplicação) | `EmbarqueService` |
| Presenca (UC-S05) | entity | **Sim** (back-end, domínio) | `Presenca`, que compõe `Embarque` |
| PresencaRepository (UC-S05) | database | **Sim**: contrato no domínio e implementação Postgres na infraestrutura | `PresencaRepository`, `PresencaRepositoryPostgres` |
| NotificacaoService (UC-I02) | serviço | **Sim**: contrato e duas implementações | `NotificacaoService`, `NotificacaoServiceVazio`, `NotificacaoServicePadrao` |
| VinculoRepository (UC-I02) | database | **Sim** | `VinculoRepository`, `VinculoRepositoryPostgres` |
| NotificacaoRepository (UC-I02) | database | **Sim** | `NotificacaoRepository`, `NotificacaoRepositoryPostgres` |
| Serviço de Notificação (push) (UC-I02) | sistema externo | **Não**: a entrega é por *polling*. O app consulta `GET /notificacoes` a cada ~10 s (backlog, seção 8). A notificação gravada pelo `NotificacaoRepository` já é o "envio" | — |
| Servidor (UC-R02) | participante | **Não**: no UC real o servidor é uma caixa-preta. No app ele é representado pela API (`EmbarqueRemoto` / `EmbarqueApi`) | `EmbarqueRemoto`, `EmbarqueApi` |

As mensagens dos diagramas de sequência viraram operações com o mesmo nome sempre que possível:

| Mensagem na sequência | Operação no diagrama de classes |
|---|---|
| `abrirRota(rotaId)`, `confirmarEmbarque(alunoId)` | `TelaRotaDoDia.abrirRota`, `TelaRotaDoDia.confirmarEmbarque` |
| `listarAlunosConfirmados(rotaId)` | `EmbarqueController.listarAlunos` → `EmbarqueService.listarAlunosConfirmados` (no app: `RotaDoDiaService.listarAlunosConfirmados`) |
| `buscarConfirmados(rotaId)` | `PresencaRepository.buscarConfirmados` |
| `registrarEmbarque(alunoId, dataHora, local)` | `EmbarqueController.registrarEmbarque` → `EmbarqueService.registrarEmbarque` |
| `buscarPresenca(alunoId, rotaId)` | `PresencaRepository.buscarPresenca` |
| `registrarEmbarque(dataHora, local)` em `Presenca` | `Presenca.registrarEmbarque(registroId, dataHora, localizacao)` (ganhou o `registroId`, ver seção 8) |
| `salvar(presenca)` | `PresencaRepository.salvar` |
| `guardar(registroEmbarque)` | `FilaEmbarques.guardar` (implementado por `ArmazenamentoLocal`) |
| `sincronizar(registros)` | `ModuloEmbarqueComFila.sincronizar` → `EmbarqueRemoto.sincronizar` → `EmbarqueController.sincronizar` |
| `notificarMovimentacao(presenca, tipo)` | `NotificacaoService.notificarMovimentacao` |
| `buscarResponsaveis(aluno)` | `VinculoRepository.buscarResponsaveis` |
| `montarMensagem(tipo, horário)` | `Notificacao.deEmbarque(...)`. A regra passou do service para a entidade, para a entidade não ficar anêmica (ver seção 8) |
| `registrarComunicado(evento)` | `NotificacaoRepository.registrarComunicado` |

### 1.2 Classes que vieram de outras fontes

| Fonte | Classes |
|---|---|
| Mapa de dados | `Aluno`, `Responsavel`, `Motorista`, `Van`, `VinculoMotoristaVan`, `Rota`, `PontoParada`, `Embarque`, `Notificacao` |
| RN-012 (só o motorista ativo registra) e resposta `404` do contrato | `RotaRepository` (achar a rota e a sua van), `VinculoRepository.buscarVinculoAtivo` |
| Contrato da API (seção 3 do backlog) | `ResultadoRegistro` (201 × 200), `NotificacaoController`, `AvisosService` (`GET /notificacoes`, `PATCH /notificacoes/{id}/lida`) |
| Contrato do módulo de embarque (seção 3 do backlog) | `ModuloEmbarque`, `StatusEnvio`, `ResultadoEmbarque`, `RegistroPendente`, `EventoPendente`, `EmbarqueException`, `ModuloEmbarqueOnline`, `ModuloEmbarqueComFila` |
| Respostas de erro (403, 404, 409) | `AcessoNegadoException`, `NaoEncontradoException`, `EmbarqueNaoPermitidoException`, `EmbarqueDuplicadoException` |
| Testes sem rede e sem GPS (prompts D e E) | `Conectividade`, `Localizador`, `EmbarqueRemoto`, `FilaEmbarques` (contratos que os testes substituem por versões falsas) |
| Identificação do usuário: login (modelado, mas **fora do ciclo de implementação**: a disciplina proíbe que o caso de uso implementado seja login) | `Usuario`, `Papel`, `Sessao`, `SessaoRepository`, `UsuarioRepository`, `AutenticacaoService`, `AutenticacaoController`, `AutenticacaoMiddleware`, `UsuarioLogado`; no app, `LoginService`, `LoginException`, `TelaLogin`, `Sessao`, `UsuarioLogado`, `ApiClient` |
| Implementação (classes que surgiram no código e entraram no diagrama na B-12) | `RespostaApi`, `DadosMock` (`USE_MOCK`), `Config`, `CoresApp` no app; `HorarioBrasilia.formatarIso8601` (A-08) |

### 1.3 Classes, camadas e responsabilidades

#### Back-end (Dart Frog)

| Classe | Camada | Responsabilidade | Atributos | Operações |
|---|---|---|---|---|
| `Aluno` | domínio (cadastro) | Representar o aluno transportado e saber se é menor de idade (RN-009) | id, nome, dataNascimento | `ehMenorDeIdade(referencia)` |
| `Usuario` | domínio (cadastro), abstrata | O que motorista e responsável têm em comum: identificação, login e senha, e o papel | id, nome, login, senhaHash? (privada) | `papel` (abstrato), `autenticar(senha)` (fora do ciclo: ainda `UnimplementedError`) |
| `Papel` | domínio (cadastro), enum | Papel do usuário na API | MOTORISTA, RESPONSAVEL; codigo | `deCodigo(codigo)` |
| `Responsavel` | domínio (cadastro), herda de `Usuario` | Representar quem recebe os avisos do aluno | telefone, email | — |
| `Motorista` | domínio (cadastro), herda de `Usuario` | Representar o motorista que opera a van | telefone, cnh | — |
| `Sessao` | domínio (autenticação), apoio | Token de acesso de um usuário | token, usuario, criadaEm | `estaValida(agora)` |
| `SessaoRepository` | domínio (contrato), apoio | Achar a sessão pelo token | — | `buscarPorToken(token)`, `salvar(sessao)` |
| `UsuarioRepository` | domínio (contrato), apoio | Listar os usuários do seed (`GET /usuarios`) e achar um pelo id e papel | — | `listar()`, `buscarPorIdEPapel(id, papel)` |
| `Van` | domínio (cadastro) | Representar o veículo | id, placa, modelo, capacidade | — |
| `VinculoMotoristaVan` | domínio (cadastro) | Dizer se o vínculo está ativo e se autoriza um motorista (RN-012) | id, inicio, fim? | `estaAtivo()`, `autoriza(motoristaId)` |
| `VinculoRepository` | domínio (contrato) | Buscar os responsáveis de um aluno (RN-002, RN-009) e o vínculo ativo de uma van (RN-012) | — | `buscarResponsaveis(alunoId)`, `buscarVinculoAtivo(vanId)` |
| `Rota` | domínio (rota) | Representar o percurso do dia de uma van | id, data, trajeto, horarioPrevisto, situacao | — |
| `PontoParada` | domínio (rota) | Onde o aluno embarca | id, endereco, localizacao | — |
| `Localizacao` | domínio (rota), value object | Par latitude/longitude, sem identidade | latitude, longitude | — |
| `Presenca` | domínio (rota) | Guardar a situação do aluno na rota e **registrar o próprio embarque**, validando o status (RN-010) | id, ordem, situacao (privada) | `estaConfirmada()`, `registrarEmbarque(registroId, dataHora, localizacao?)` |
| `Embarque` | domínio (rota) | Registro do embarque com a hora do toque e a localização opcional (RF-009); `registroId` garante a idempotência (RNF-006) | id?, registroId, dataHora, localizacao? | — |
| `SituacaoPresenca`, `Trajeto` | domínio (rota), enum | Valores possíveis | CONFIRMADO / AUSENTE / EMBARCADO; IDA / VOLTA | — |
| `EmbarqueNaoPermitidoException` | domínio (rota) | Erro de regra: presença não está CONFIRMADO (vira 409) | situacaoAtual | — |
| `EmbarqueDuplicadoException` | domínio (rota) | O banco recusou o embarque por unicidade (corrida entre requisições) | registroId | — |
| `PresencaRepository` | domínio (contrato) | Buscar e salvar presenças, gravando o embarque junto, na mesma transação | — | `buscarConfirmados(rotaId)`, `buscarPresenca(alunoId, rotaId)`, `buscarPorRegistroId(registroId)`, `salvar(presenca)` |
| `RotaRepository` | domínio (contrato) | Buscar a rota (404) com a sua van (RN-012 e placa do cabeçalho) e a rota de hoje do motorista | — | `buscarPorId(rotaId)`, `buscarDoMotorista(motoristaId, data)` |
| `Notificacao` | domínio (notificacao) | **Montar a própria mensagem** com a hora do embarque em horário de Brasília, marcar-se como lida e dizer a quem pertence (RN-002) | id?, tipo, mensagem, dataHoraEvento, lida (privada) | `deEmbarque(destinatario, aluno, dataHoraEmbarque)` (fábrica), `marcarComoLida()`, `pertenceA(responsavelId)` |
| `TipoMovimentacao` | domínio (notificacao), enum | Evento notificado | EMBARQUE, DESEMBARQUE | — |
| `NotificacaoRepository` | domínio (contrato) | Registrar o comunicado e consultar os avisos do responsável | — | `registrarComunicado(notificacoes)`, `buscarDoResponsavel(responsavelId, desde?)`, `buscarPorId(id)`, `salvar(notificacao)` |
| `HorarioBrasilia` | domínio (compartilhado), utilitário | Formatar HH:MM e ISO 8601 em UTC-3, mesmo com o servidor em UTC | — | `formatarHoraMinuto(dataHora)`, `formatarIso8601(dataHora)` |
| `EmbarqueController` | apresentação (embarque) | Converter HTTP/JSON ↔ objetos e exceções ↔ códigos HTTP. Sem regra de negócio e sem acesso a repositório | service | `buscarRotaDoDia(pedido, usuario)`, `listarAlunos(rotaId, pedido, usuario)`, `registrarEmbarque(rotaId, pedido, usuario)`, `sincronizar(rotaId, pedido, usuario)`; privadas: `traduzindoErros`, `codigoDoRegistro`, `codigoHttpDe`, `mensagemDe` |
| `NotificacaoController` | apresentação (notificacao) | Converter as rotas de avisos em chamadas ao `AvisosService` | avisosService | `listar(pedido, usuario)`, `marcarComoLida(notificacaoId, pedido, usuario)` |
| `AutenticacaoController` | apresentação (autenticação), apoio | `GET /usuarios` e `POST /login` | service | `listarUsuarios(metodo)`, `entrar(pedido)` |
| `AutenticacaoMiddleware` | apresentação (autenticação), apoio | Ler o token do header `Authorization`, achar a `Sessao` e entregar o `UsuarioLogado` às rotas (sem token válido → 401) | sessoes | `identificar(token)`, `middleware()` |
| `UsuarioLogado` | apresentação (autenticação), apoio | Quem fez a requisição e o seu papel; é o que os controllers recebem | id, papel | — |
| `AutenticacaoService` | aplicação (autenticação), apoio | Listar os usuários e abrir uma sessão (login simplificado) | usuarios, sessoes | `listarUsuarios()`, `entrar(id, papel)` |
| `EmbarqueService` | aplicação (embarque) | **Coordenar o UC-S05**: rota existe, motorista ativo, idempotência, chamar a `Presenca`, salvar e acionar o UC-I02 (se o aviso falhar, registra no log e mantém o 201) | rotaRepository, presencaRepository, vinculoRepository, notificacaoService, relogio (injetável) | `buscarRotaDoDia(motoristaId)`, `listarAlunosConfirmados(rotaId, motoristaId)`, `registrarEmbarque(rotaId, alunoId, registroId, dataHora, motoristaId, localizacao?)` (parâmetros nomeados) |
| `ResultadoRegistro` | aplicação (embarque) | Resultado do registro; `jaProcessado` diferencia o 201 do 200 | alunoId, situacao, jaProcessado | — |
| `AcessoNegadoException`, `NaoEncontradoException` | aplicação (compartilhado) | Erros de coordenação que viram 403 e 404 | mensagem | — |
| `NotificacaoService` | aplicação (contrato) | Ponto do `<<include>>` UC-I02 usado pelo `EmbarqueService` | — | `notificarMovimentacao(presenca, tipo)` |
| `NotificacaoServiceVazio` | aplicação (notificacao) | Versão que não faz nada, para o UC-S05 não esperar o UC-I02 (task B-05) | — | `notificarMovimentacao` |
| `NotificacaoServicePadrao` | aplicação (notificacao) | **Coordenar o UC-I02**: buscar os responsáveis, criar uma `Notificacao` por responsável e registrar o comunicado; A1 sem responsável não cria nada | vinculoRepository, notificacaoRepository | `notificarMovimentacao` |
| `AvisosService` | aplicação (notificacao) | Consultar os avisos do responsável logado e marcar como lido só os dele (RN-002) | notificacaoRepository | `listarDoResponsavel(responsavelId, desde?)`, `marcarComoLida(notificacaoId, responsavelId)` |
| `ConexaoBanco` | infraestrutura (compartilhado) | Único *pool* de conexões com o Postgres e transação (`runTx`) | pool | `abrir(databaseUrl)`, `executar(sql, parametros)`, `emTransacao(acao)`, `fechar()` |
| `PresencaRepositoryPostgres`, `RotaRepositoryPostgres`, `VinculoRepositoryPostgres`, `NotificacaoRepositoryPostgres`, `SessaoRepositoryPostgres` | infraestrutura | Implementar os contratos com SQL no Postgres (Supabase). O `SessaoRepositoryPostgres` implementa `SessaoRepository` e `UsuarioRepository` | obterConexao (função que abre a conexão) | as do contrato |

#### App (Flutter)

| Classe | Camada | Responsabilidade | Atributos | Operações |
|---|---|---|---|---|
| `TelaRotaDoDia` | apresentação | Mostrar a rota (cabeçalho, próxima parada, Depois, Na van) e registrar com **um toque** (RNF-005). Só conversa com `ModuloEmbarque` e `RotaDoDiaService`; liga a `FaixaSemConexao` ao `online` | modulo, rotaDoDiaService, online (no State: rota, alunos, situação) | `abrirRota(rotaId)`, `confirmarEmbarque(alunoId)` |
| `FaixaSemConexao` | apresentação | Faixa âmbar "Sem conexão" sempre visível quando offline (RNF-003) | semConexao | — |
| `ModuloEmbarque` | aplicação (contrato D–E) | Contrato interno da seção 3 do backlog, **sem alteração** | — | `registrarEmbarque(rotaId, alunoId)`, `listarPendentes(rotaId)`, `aoMudarPendentes` |
| `StatusEnvio`, `ResultadoEmbarque`, `RegistroPendente`, `EventoPendente`, `EmbarqueException` | aplicação | Tipos do contrato, exatamente como no backlog | (ver backlog) | — |
| `ModuloEmbarqueOnline` | aplicação | Implementação só online (Membro D): captura hora e GPS (até 2 s), gera o `registroId` e envia | remoto, localizador | as do contrato |
| `ModuloEmbarqueComFila` | aplicação | Implementação com fila offline (Membro E): decide entre API e fila, sincroniza ao reconectar, a cada 30 s e ao abrir o app, sem sincronizações simultâneas (RNF-006) | remoto, fila, conectividade, localizador, sincronizando, eventos | as do contrato + `sincronizar([rotaId])` |
| `RotaDoDiaService` | aplicação | Descobrir a rota de hoje e listar os seus alunos para a tela | remoto | `buscarRotaDoDia()`, `listarAlunosConfirmados(rotaId)` |
| `RotaDoDia` | domínio | Dados do cabeçalho da tela (formato do `GET /rotas/hoje`) | rotaId, trajeto, horarioPrevisto, placa | — |
| `AlunoDaRota` | domínio | Aluno como a tela o mostra (formato do `GET /rotas/{rotaId}/alunos`) | alunoId, nome, ordem, endereco, embarcado | — |
| `RegistroEmbarque` | domínio | Um toque em "Embarcou": corpo do `POST` + `rotaId`. É o item guardado na fila | registroId, rotaId, alunoId, dataHora, localizacao? | `paraJson()`, `deJson(rotaId, json)` |
| `Localizacao` | domínio, value object | Latitude/longitude do toque | latitude, longitude | — |
| `EnvioRecusadoException`, `SemConexaoException` | domínio | Separar "servidor recusou" (403/404/409, nunca vai para a fila) de "sem rede/timeout" (vai para a fila) | codigoHttp, mensagem | — |
| `EmbarqueRemoto` | domínio (contrato) | Falar com a API de embarque | — | `buscarRotaDoDia`, `listarAlunos`, `enviar`, `sincronizar` |
| `FilaEmbarques` | domínio (contrato) | Fila persistente de registros pendentes | — | `guardar`, `listar(rotaId)`, `remover(registroIds)` |
| `Conectividade` | domínio (contrato) | Dizer se há rede e avisar quando muda; o módulo informa falhas e sucessos de rede das chamadas | — | `estaOnline`, `aoMudar`, `registrarFalhaDeRede()`, `registrarSucessoDeRede()` |
| `Localizador` | domínio (contrato) | Obter a localização com tempo limite | — | `obterLocalizacao(limite)` |
| `EmbarqueApi` | infraestrutura | `EmbarqueRemoto` sobre o `ApiClient` (que aplica o timeout de 5 s); converte timeout e erro de rede em `SemConexaoException` e 4xx em `EnvioRecusadoException` | api | as do contrato |
| `ArmazenamentoLocal` | infraestrutura | `FilaEmbarques` em JSON no `shared_preferences` (Android e Web) | prefs | as do contrato |
| `MonitorConectividade` | infraestrutura | `Conectividade` com `connectivity_plus`; expõe `ValueNotifier<bool>` para a faixa | online | as do contrato + `verificarConectividade()`, `monitorarChamada(chamada, limite)` |
| `LocalizadorGeolocator` | infraestrutura | `Localizador` com `geolocator` | — | `obterLocalizacao(limite)` |
| `TelaLogin` | apresentação (login), apoio | Lista os usuários e entra com um toque; abre a tela do motorista ou do responsável recebida do `main.dart` | loginService, telaDoMotorista, telaDoResponsavel | — |
| `LoginService`, `LoginException` | aplicação (login), apoio | `GET /usuarios` e `POST /login`, guardando o token na `Sessao` | api, sessao | `listarUsuarios()`, `entrar(usuario)` |
| `TelaAvisos` | apresentação (avisos) | **Provisória** (D-03). A tela real é da C-06 e da C-07 (ponto 19) | usuario | — |
| `ApiClient`, `RespostaApi` | infraestrutura (compartilhado), apoio | Cliente HTTP com `API_URL`, o token da `Sessao` e o modo mock | baseUrl, sessao, mock | `get`, `post`, `patch` |
| `Sessao`, `UsuarioLogado`, `Papel` | aplicação (compartilhado), apoio | Quem está logado no app e o token | usuario, token | `entrar(usuario, token)`, `sair()` |
| `Config`, `CoresApp`, `DadosMock` | apoio | `--dart-define` (`API_URL`, `USE_MOCK`), as cores do app e as respostas simuladas da seção 3 | — | — |

---

## 2. Diagrama de classes

Os diagramas estão em PlantUML. Como o diagrama completo fica grande, ele foi dividido em três:

| # | Arquivo | Conteúdo |
|---|---|---|
| 1 | [`scripts/diagrama-classes-uc-s05.puml`](scripts/diagrama-classes-uc-s05.puml) | **Domínio do back-end**: entidades, enums, value objects e contratos de repositório, com atributos, operações, relacionamentos e multiplicidades |
| 2 | [`scripts/diagrama-classes-uc-s05-backend.puml`](scripts/diagrama-classes-uc-s05-backend.puml) | **Camadas do back-end**: controllers, services, contrato `NotificacaoService` e implementações Postgres que realizam os contratos |
| 3 | [`scripts/diagrama-classes-uc-s05-app.puml`](scripts/diagrama-classes-uc-s05-app.puml) | **App Flutter**: `TelaRotaDoDia`, contrato `ModuloEmbarque` e as suas duas implementações, `ArmazenamentoLocal` e os contratos usados nos testes; desde a B-12 também o login, o compartilhado e a tela "Avisos" (marcada como pendente) |

Para gerar as imagens, use a extensão PlantUML do VS Code ou
`java -jar plantuml.jar documentos/desenvolvimento/scripts/*.puml`.

### 2.1 Convenções usadas

| Notação | Significado em Dart |
|---|---|
| `+ nome : Tipo {readOnly}` | Campo público `final`, definido no construtor |
| `- situacao`, `- lida` | Estado privado (`_situacao`), alterado **só** por operações da própria entidade e lido por *getter*. É o que impede a entidade de ser anêmica: ninguém faz `presenca.situacao = EMBARCADO` de fora |
| `Tipo?` | Pode ser nulo (ex.: localização "quando disponível") |
| `<<contrato>>` (interface) | `abstract class` no domínio (ou na aplicação), implementada com `implements` |
| `..\|>` (realização) | Implementação de um contrato (ex.: `PresencaRepositoryPostgres implements PresencaRepository`) |
| Associação para outra entidade | Guardada como id (ex.: `Presenca` guarda `alunoId`; o repositório devolve o `Aluno` carregado quando a operação precisa do nome) |
| `<<apoio>>` / "fora do ciclo de implementação" | Faz parte do modelo do sistema (ex.: login com senha), mas não é o caso de uso implementado neste ciclo. Na entrega, só serve para saber quem faz a requisição |

### 2.2 Relacionamentos e multiplicidades

| Relacionamento | Tipo | Multiplicidade | Justificativa |
|---|---|---|---|
| `Presenca` ◆— `Embarque` | **Composição** | 1 — 0..1 | O embarque não existe sem a presença: só uma presença CONFIRMADO gera embarque (RN-010) e cada presença gera no máximo um (mapa de dados). Ele nasce dentro de `Presenca.registrarEmbarque` e é salvo junto com ela, na mesma transação. Apagar a presença apaga o embarque |
| `PontoParada` ◆— `Localizacao`, `Embarque` ◆— `Localizacao` | **Composição** | 1 — 1 / 1 — 0..1 | `Localizacao` é um *value object*: não tem identidade e só existe como parte do dono |
| `TelaRotaDoDia` ◆— `FaixaSemConexao` (app) | **Composição** | 1 — 1 | O widget da faixa é criado e descartado com a tela |
| `Rota` — `Presenca` | Associação | 1 — 0..* | **Não** é composição: a presença é confirmada (UC-S03) *antes* de a rota ser gerada com os confirmados (RN-005). Ela tem ciclo de vida próprio |
| `Motorista`, `Responsavel` —▷ `Usuario` | **Generalização** | — | Os dois **são** usuários: compartilham identificação, login, senha e papel, e cada um acrescenta os seus dados. É uma relação "é um", estável, sem troca de tipo em tempo de execução |
| `Sessao` → `Usuario` | Associação navegável | 0..* — 1 | Um usuário pode ter várias sessões (aparelhos); a sessão não é dona do usuário |
| `Presenca` → `Aluno`, `Presenca` → `PontoParada` | Associação navegável | 0..* — 1 | A presença conhece o aluno e o ponto, mas não é dona deles |
| `Aluno` — `Responsavel` | Associação N:N | 0..* — 0..* | Um responsável tem vários alunos e um aluno pode ter vários responsáveis. RN-009: o menor tem pelo menos 1; o maior pode ter 0 (A1 do UC-I02) |
| `Van` — `VinculoMotoristaVan` — `Motorista` | Associação | 1 — 0..* | Histórico de quem dirigiu cada van. O vínculo não é composto pela van nem pelo motorista, porque depende dos dois. RN-012: no máximo um ativo por van |
| `Rota` → `Van` | Associação navegável | 0..* — 1 | Uma rota por dia e por trajeto. A rota conhece a sua van: o service precisa dela para o RN-012 e para a placa do cabeçalho |
| `Notificacao` → `Responsavel`, `Notificacao` → `Aluno` | Associação navegável | 0..* — 1 | Destinatário e assunto do aviso |
| `XxxRepositoryPostgres` ..\|> `XxxRepository` | Realização | — | Contrato no domínio, implementação na infraestrutura: os services são testados com *mocks*, sem banco |
| `NotificacaoServiceVazio`, `NotificacaoServicePadrao` ..\|> `NotificacaoService` | Realização | — | Troca da versão vazia (B-05) pela real (B-11) sem mexer no `EmbarqueService` |
| `ModuloEmbarqueOnline`, `ModuloEmbarqueComFila` ..\|> `ModuloEmbarque` | Realização | — | Membros D e E trabalham em paralelo; o `main.dart` escolhe a implementação em uma linha |
| `EmbarqueService` → `NotificacaoService` | Associação (dependência injetada) | 1 | Ponto do `<<include>>` UC-I02 |
| Controllers → Services; Services → contratos | Associação (dependência injetada) | 1 | Camadas: apresentação → aplicação → domínio |
| `Presenca` ..> `EmbarqueNaoPermitidoException` | Dependência `<<lança>>` | — | Erro de regra da própria entidade (409) |

A generalização foi usada só em `Usuario`, onde existe de fato uma relação "é um". As
variações técnicas (repositórios, serviço de notificação, módulo de embarque) são
**realizações de contratos**, e não herança, para trocar as implementações sem acoplamento.

### 2.3 Comportamento nas entidades (sem classes anêmicas)

| Entidade | Operação | Regra que ela garante | Quem chama |
|---|---|---|---|
| `Presenca` | `registrarEmbarque(registroId, dataHora, localizacao?)` | RN-010: só embarca se CONFIRMADO; muda para EMBARCADO e cria o `Embarque`; senão lança `EmbarqueNaoPermitidoException` (409, inclusive "já embarcou com outro registroId") | `EmbarqueService` |
| `Presenca` | `estaConfirmada()` | Situação atual | `EmbarqueService`, testes |
| `VinculoMotoristaVan` | `estaAtivo()` | RN-012: vínculo sem data de fim | `autoriza` |
| `VinculoMotoristaVan` | `autoriza(motoristaId)` | RN-012: o motorista é o do vínculo **e** o vínculo está ativo | `EmbarqueService.validarMotoristaAtivo` |
| `Aluno` | `ehMenorDeIdade(referencia)` | RN-009 | testes / regras de cadastro |
| `Notificacao` | `deEmbarque(destinatario, aluno, dataHoraEmbarque)` | Mensagem "&lt;aluno&gt; embarcou na van às HH:MM." com a hora **do embarque** em UTC-3, não a hora atual (o embarque pode chegar por sincronização) | `NotificacaoServicePadrao` |
| `Notificacao` | `marcarComoLida()` | Estado de leitura | `AvisosService` |
| `Notificacao` | `pertenceA(responsavelId)` | RN-002: só o destinatário marca como lida | `AvisosService` |

### 2.4 O UC-S05 percorrendo as classes

Mesma ordem do diagrama de sequência `UC-S05.puml`:

0. Depois do login: `RotaDoDiaService.buscarRotaDoDia` → `GET /rotas/hoje` →
   `EmbarqueController.buscarRotaDoDia` → `EmbarqueService.buscarRotaDoDia` →
   `RotaRepository.buscarDoMotorista(motoristaId, hoje)` (404 se não houver rota hoje). Devolve
   o `rotaId` e o cabeçalho (trajeto, horário, placa).
1. `TelaRotaDoDia.abrirRota(rotaId)` → `RotaDoDiaService.listarAlunosConfirmados` → `GET /rotas/{rotaId}/alunos`
   → `EmbarqueController.listarAlunos` → `EmbarqueService.listarAlunosConfirmados` (RN-012)
   → `PresencaRepository.buscarConfirmados` (sem ausentes: exceção da RN-010).
2. `TelaRotaDoDia.confirmarEmbarque` → `ModuloEmbarque.registrarEmbarque`: captura `dataHora`,
   `Localizador.obterLocalizacao(2 s)` e gera o `registroId`.
3. **Com conexão:** `EmbarqueRemoto.enviar` → `POST /rotas/{rotaId}/embarques` →
   `EmbarqueController.registrarEmbarque` → `EmbarqueService.registrarEmbarque`:
   1. `RotaRepository.buscarPorId` → `NaoEncontradoException` (404) se não existir;
   2. `VinculoRepository.buscarVinculoAtivo(rota.vanId)` + `vinculo.autoriza(motoristaId)` →
      `AcessoNegadoException` (403), RN-012;
   3. `PresencaRepository.buscarPorRegistroId` → se achar, devolve `ResultadoRegistro(jaProcessado: true)` (200),
      sem salvar nem notificar;
   4. `PresencaRepository.buscarPresenca` → 404 se o aluno não tiver presença nesta rota;
   5. `presenca.registrarEmbarque(...)` → 409 se não estiver CONFIRMADO (RN-010);
   6. `PresencaRepository.salvar(presenca)`: situação + embarque em **uma transação**. Se o banco
      recusar por unicidade (`EmbarqueDuplicadoException`), o service consulta
      `buscarPorRegistroId` de novo: se achar, é o mesmo registro (200); se não, outro registro já
      embarcou o aluno (409);
   7. `NotificacaoService.notificarMovimentacao(presenca, EMBARQUE)` (`<<include>>` UC-I02) →
      `VinculoRepository.buscarResponsaveis` → `Notificacao.deEmbarque` para cada um →
      `NotificacaoRepository.registrarComunicado`.
4. **A1 — sem conexão:** `FilaEmbarques.guardar` (`ArmazenamentoLocal`) e `StatusEnvio.pendente`.
   Ao reconectar: `ModuloEmbarqueComFila.sincronizar` → `EmbarqueRemoto.sincronizar` →
   `POST .../embarques/sincronizar` → `EmbarqueController.sincronizar`, que chama o mesmo
   `EmbarqueService.registrarEmbarque` para cada registro (um erro não impede os outros).

### 2.5 O que o Membro A já pode implementar (A-06 e A-07)

- **Entidades** (Diagrama 1): `Usuario`, `Papel`, `Aluno`, `Responsavel`, `Motorista`, `Van`, `VinculoMotoristaVan`, `Rota`,
  `PontoParada`, `Localizacao`, `Presenca`, `Embarque`, os enums `SituacaoPresenca` e `Trajeto` e as
  exceções `EmbarqueNaoPermitidoException` e `EmbarqueDuplicadoException`.
  `Presenca.registrarEmbarque` fica com `UnimplementedError` (é a task B-04).
- **Contratos e implementações Postgres:** `PresencaRepository`, `RotaRepository` e `VinculoRepository`,
  além do `ConexaoBanco`.
- `Notificacao`, `TipoMovimentacao` e `NotificacaoRepository` são do Membro C;
  `HorarioBrasilia` é usado por ele. `Sessao`, `SessaoRepository` e `AutenticacaoMiddleware`
  também são do Membro C (C-02).

---

## 3. Arquitetura em camadas

O back-end e o app usam as mesmas quatro camadas. Elas vêm da distribuição de
responsabilidades dos diagramas de sequência do 1º bimestre (boundary → control/serviço →
entity → database/sistema externo), agora com nomes de camada:

### 3.1 As camadas e as classes de cada uma

| Camada | Responsabilidade | Back-end (Dart Frog) | App (Flutter) |
|---|---|---|---|
| **Apresentação** | Receber a ação do usuário ou a requisição HTTP e devolver a resposta. Converte formatos (JSON, widgets) e erros em códigos/mensagens. **Sem regra de negócio** | arquivos de `routes/`, `EmbarqueController`, `NotificacaoController`, `AutenticacaoController`, `AutenticacaoMiddleware`, `UsuarioLogado`, CORS | `TelaRotaDoDia`, `FaixaSemConexao`, `TelaLogin`, `TelaAvisos`, `CoresApp` |
| **Aplicação** | Coordenar o caso de uso: chamar os repositórios e as entidades na ordem do fluxo, validar acesso e acionar o `<<include>>`. Não sabe nada de HTTP, SQL ou widgets | `EmbarqueService`, `ResultadoRegistro`, `NotificacaoService` (contrato), `NotificacaoServiceVazio`, `NotificacaoServicePadrao`, `AvisosService`, `AutenticacaoService`, `AcessoNegadoException`, `NaoEncontradoException` | `ModuloEmbarque` e seus tipos, `ModuloEmbarqueOnline`, `ModuloEmbarqueComFila`, `RotaDoDiaService`, `LoginService`, `Sessao` do app |
| **Domínio** | As regras que pertencem ao próprio conceito (RN-010, RN-012, RN-002) e os **contratos** dos repositórios. Dart puro | entidades, value objects, enums e exceções de `cadastro`, `rota` e `notificacao`; `HorarioBrasilia`; contratos `PresencaRepository`, `RotaRepository`, `VinculoRepository`, `NotificacaoRepository`, `SessaoRepository`, `UsuarioRepository` | `AlunoDaRota`, `RotaDoDia`, `RegistroEmbarque`, `Localizacao`, `EnvioRecusadoException`, `SemConexaoException`; contratos `EmbarqueRemoto`, `FilaEmbarques`, `Conectividade`, `Localizador` |
| **Infraestrutura** | Falar com o mundo de fora: banco, `.env`, HTTP, armazenamento do aparelho, GPS e rede. **Implementa** os contratos do domínio | `ConexaoBanco`, `lerDatabaseUrl()` (`ambiente.dart`), `PresencaRepositoryPostgres`, `RotaRepositoryPostgres`, `VinculoRepositoryPostgres`, `NotificacaoRepositoryPostgres`, `SessaoRepositoryPostgres` | `ApiClient`, `RespostaApi`, `Config`, `EmbarqueApi`, `ArmazenamentoLocal`, `MonitorConectividade`, `LocalizadorGeolocator`, `DadosMock` |

Existe ainda um ponto de **composição** em cada lado: o único lugar que conhece ao mesmo tempo
o contrato e a implementação, e liga um ao outro.

| Lado | Onde | O que faz |
|---|---|---|
| Back-end | `routes/_middleware.dart` | Cria a `ConexaoBanco` e os repositórios Postgres e os entrega aos services e controllers por `provider`. A troca do `NotificacaoServiceVazio` pelo `NotificacaoServicePadrao` (B-11) é uma linha aqui |
| App | `lib/main.dart` | Escolhe a implementação de `ModuloEmbarque` (troca do Online pelo ComFila na E-05: uma linha), lê `API_URL`/`USE_MOCK` e liga a `FaixaSemConexao` ao `MonitorConectividade` |

### 3.2 Dependências permitidas

```text
        APRESENTAÇÃO  ──────►  APLICAÇÃO  ──────►  DOMÍNIO  ◄──────  INFRAESTRUTURA
   (routes, controllers,     (services,        (entidades,          (Postgres, http,
    middleware, telas)        ModuloEmbarque)   contratos)           shared_preferences)

   COMPOSIÇÃO (routes/_middleware.dart, main.dart): conhece todas e liga contrato -> implementação
```

- A seta vai sempre **para dentro**, até o domínio. O domínio não depende de nenhuma camada.
- A infraestrutura depende do domínio porque **implementa os seus contratos** (inversão de
  dependência). A aplicação usa só o contrato, e por isso é testada com *mocks* do mocktail,
  sem banco e sem rede.
- A apresentação pode **ler** os tipos do domínio que o service devolve (ex.: o controller
  monta o JSON a partir de uma `Presenca`), mas não chama comportamento de entidade nem
  repositório.

### 3.3 Dependências proibidas

| Proibido | Por quê | Exemplo do que **não** fazer |
|---|---|---|
| Controller acessar repositório | A coordenação é do service; o controller só converte | `EmbarqueController` chamando `presencaRepository.salvar` |
| Controller ou tela com regra de negócio | A regra fica onde está o conceito (entidade) ou a coordenação (service) | Controller testando `situacao == CONFIRMADO` antes de chamar o service |
| Domínio importar framework ou biblioteca de I/O | O domínio é a parte estável; tem que rodar em teste puro | `import 'package:dart_frog/...'`, `package:postgres`, `package:http`, `package:flutter/...` ou `shared_preferences` dentro de `dominio/` |
| Aplicação depender de implementação concreta | Impede trocar e testar com mock | `EmbarqueService` recebendo `PresencaRepositoryPostgres` em vez de `PresencaRepository` |
| Infraestrutura chamar aplicação ou apresentação | Inverteria o fluxo e criaria ciclo | `PresencaRepositoryPostgres` chamando `NotificacaoService` |
| Arquivo de `routes/` com lógica | Dart Frog exige o arquivo, mas a lógica fica no controller | SQL ou validação dentro de `routes/rotas/[rotaId]/embarques/index.dart` |
| Tela falar direto com a API | A tela só conhece `ModuloEmbarque` e `RotaDoDiaService` (contrato D–E) | `TelaRotaDoDia` usando `ApiClient` ou `http` |
| Entidade alterar o estado de outra | Cada entidade guarda o próprio estado | `Notificacao` mudando a situação da `Presenca` |

### 3.4 Camada lógica não é diretório físico

**Camada** é uma regra de responsabilidade e de dependência ("quem pode chamar quem").
**Diretório** é só onde o arquivo fica. As duas coisas andam juntas na maior parte do projeto,
mas não são a mesma coisa:

- As pastas são organizadas **primeiro por funcionalidade** (`embarque/`, `notificacao/`,
  `rota/`...) e só **dentro** de cada módulo por camada. Duas classes da mesma camada podem estar
  em pastas diferentes (ex.: `Presenca` em `rota/dominio/` e `Notificacao` em
  `notificacao/dominio/`).
- `routes/` é **apresentação**, mas fica fora de `lib/` porque o Dart Frog cria as rotas HTTP a
  partir dos nomes dos arquivos dessa pasta.
- No app, `compartilhado/` é uma pasta plana com poucos arquivos de apoio, mas cada arquivo
  pertence a uma camada: `api_client.dart` e `config.dart` são infraestrutura, `sessao.dart` é
  aplicação e `cores.dart` é apresentação. A camada está indicada no comentário `///` de cada
  classe.
- O módulo `embarque/` do back-end não tem pasta `dominio/`: as entidades que ele usa
  (`Presenca`, `Embarque`) pertencem ao conceito de rota e ficam em `rota/dominio/`
  (ver 4.1).

### 3.5 Como conferir no PR

O revisor pode rodar, a partir da raiz do repositório:

```bash
# O domínio não pode importar framework nem biblioteca de I/O (deve sair vazio)
grep -rnE "package:(dart_frog|postgres|http|flutter|shared_preferences|connectivity_plus|geolocator)" backend/lib/*/dominio app/lib/*/dominio

# Controllers não podem importar repositórios (deve sair vazio)
grep -rn "_repository" backend/lib/*/apresentacao/*_controller.dart
```

---

## 4. Estrutura de diretórios

### 4.1 Módulos do back-end e dependências entre eles

```text
   nível 4   embarque
                │  importa ▼
   nível 3   notificacao
                │
   nível 2   rota          autenticacao
                │               │
   nível 1   cadastro ◄─────────┘
                │
   nível 0   compartilhado

   Um módulo só importa módulos de nível MENOR (nunca do mesmo nível nem de cima).
```

| Nível | Módulo | Contém | Pode importar |
|---|---|---|---|
| 0 | `compartilhado` | Base técnica de todos: conexão, `.env`, CORS, exceções 403/404, `HorarioBrasilia` | **nenhum módulo** |
| 1 | `cadastro` | Quem participa: `Usuario`, `Motorista`, `Responsavel`, `Aluno`, `Van`, vínculos | `compartilhado` |
| 2 | `autenticacao` (apoio) | Login simplificado: `Sessao`, repositórios de sessão e usuário, middleware, `UsuarioLogado` | `cadastro`, `compartilhado` |
| 2 | `rota` | Operação do dia: `Rota`, `PontoParada`, `Presenca`, `Embarque` | `cadastro`, `compartilhado` |
| 3 | `notificacao` | UC-I02 e avisos: `Notificacao`, `NotificacaoService`, `AvisosService` | `rota`, `autenticacao`, `cadastro`, `compartilhado` |
| 4 | `embarque` | UC-S05: `EmbarqueService`, `EmbarqueController` | todos os outros |

Como os imports só descem de nível, **não há dependência circular**. Duas escolhas garantem isso:

1. **`Presenca` e `Embarque` ficam em `rota/`, e não em `embarque/`.** O `NotificacaoService`
   recebe a `Presenca` (`notificarMovimentacao(presenca, tipo)`) e o `EmbarqueService` chama o
   `NotificacaoService`. Se a `Presenca` estivesse em `embarque/`, teríamos
   `embarque → notificacao → embarque`.
2. **O login fica em um módulo próprio, `autenticacao/`.** Hoje (C-02) ele está em
   `compartilhado/` e importa `Usuario` de `cadastro/`. Quando a A-07 criar
   `cadastro/infraestrutura/vinculo_repository_postgres.dart`, que usa a `ConexaoBanco` de
   `compartilhado/`, fecha o ciclo `cadastro ↔ compartilhado`. A mudança está no ponto 15.

### 4.2 Back-end

Árvore **real** da `desenvolvimento` em 18/11 (B-12). Entre parênteses, a task que criou o
arquivo. O módulo `autenticacao/` é o **alvo** do Bug do ponto 15: hoje esses 8 arquivos ainda
estão em `compartilhado/` (indicado com `hoje em:`).

```text
backend/
├── .env.example                  # DATABASE_URL sem senha; o .env real NÃO vai para o Git (A-01)
├── README.md                     # instalar, configurar o .env, resetar o banco e subir o servidor (A-09)
├── pubspec.yaml / pubspec.lock   # dart_frog, postgres, dotenv, uuid; dev: test, mocktail
├── analysis_options.yaml         # lints do projeto
├── dart_test.yaml                # tag "integracao" (testes que usam o banco)
├── bin/
│   └── reset_db.dart             # apaga as tabelas, roda supabase/migrations em ordem e o seed (A-05)
├── routes/                       # APRESENTAÇÃO HTTP: só lê a requisição e chama o controller
│   ├── _middleware.dart          # COMPOSIÇÃO: CORS, providers (contrato -> implementação), autenticação (C-02, B-08, C-05, B-11)
│   ├── index.dart                # GET /  (servidor no ar)
│   ├── usuarios.dart             # GET /usuarios  (apoio, C-02)
│   ├── login.dart                # POST /login  (apoio, C-02)
│   ├── notificacoes/
│   │   ├── index.dart            # GET /notificacoes?desde=  (C-05)
│   │   └── [id]/
│   │       └── lida.dart         # PATCH /notificacoes/{id}/lida  (C-05)
│   └── rotas/
│       ├── hoje.dart             # GET /rotas/hoje  (A-08)
│       └── [rotaId]/
│           ├── alunos.dart       # GET /rotas/{rotaId}/alunos  (A-08)
│           └── embarques/
│               ├── index.dart        # POST /rotas/{rotaId}/embarques  (B-08)
│               └── sincronizar.dart  # POST /rotas/{rotaId}/embarques/sincronizar  (B-09)
├── lib/
│   ├── compartilhado/            # base técnica; NÃO deve importar nenhum outro módulo (ponto 15)
│   │   ├── dominio/
│   │   │   └── horario_brasilia.dart       # HH:MM e ISO 8601 em UTC-3 (C-03, A-08)
│   │   ├── aplicacao/
│   │   │   └── excecoes.dart               # AcessoNegadoException (403), NaoEncontradoException (404) (B-06)
│   │   ├── apresentacao/
│   │   │   └── cors.dart                   # CORS + preflight OPTIONS (A-02)
│   │   └── infraestrutura/
│   │       ├── ambiente.dart               # lê o DATABASE_URL do .env (A-01)
│   │       └── conexao_banco.dart          # ConexaoBanco: pool único e transação (A-01)
│   ├── cadastro/                 # quem participa do transporte
│   │   ├── dominio/
│   │   │   ├── usuario.dart                # Usuario (abstrata) e Papel (A-06)
│   │   │   ├── motorista.dart              # Motorista extends Usuario (A-06)
│   │   │   ├── responsavel.dart            # Responsavel extends Usuario (A-06)
│   │   │   ├── aluno.dart                  # Aluno, ehMenorDeIdade (RN-009) (A-06)
│   │   │   ├── van.dart                    # Van (A-06)
│   │   │   ├── vinculo_motorista_van.dart  # estaAtivo, autoriza (RN-012) (A-06)
│   │   │   └── vinculo_repository.dart     # contrato (A-07)
│   │   └── infraestrutura/
│   │       └── vinculo_repository_postgres.dart  # (A-07)
│   ├── autenticacao/             # APOIO, fora do ciclo de implementação. ALVO do Bug do ponto 15
│   │   ├── dominio/
│   │   │   ├── sessao.dart                 # Sessao                      hoje em: compartilhado/dominio
│   │   │   ├── sessao_repository.dart      # contrato                    hoje em: compartilhado/dominio
│   │   │   └── usuario_repository.dart     # contrato do GET /usuarios   hoje em: compartilhado/dominio
│   │   ├── aplicacao/
│   │   │   └── autenticacao_service.dart   #                             hoje em: compartilhado/aplicacao
│   │   ├── apresentacao/
│   │   │   ├── autenticacao_controller.dart  #                           hoje em: compartilhado/apresentacao
│   │   │   ├── autenticacao_middleware.dart  # token -> UsuarioLogado; 401 hoje em: compartilhado/apresentacao
│   │   │   └── usuario_logado.dart           #                           hoje em: compartilhado/apresentacao
│   │   └── infraestrutura/
│   │       └── sessao_repository_postgres.dart  # Sessao e Usuario      hoje em: compartilhado/infraestrutura
│   ├── rota/                     # a operação do dia
│   │   ├── dominio/
│   │   │   ├── rota.dart                   # Rota e Trajeto (A-06)
│   │   │   ├── ponto_parada.dart           # (A-06)
│   │   │   ├── localizacao.dart            # value object (A-06)
│   │   │   ├── presenca.dart               # Presenca, SituacaoPresenca (A-06); registrarEmbarque (B-04)
│   │   │   ├── embarque.dart               # composição de Presenca (A-06)
│   │   │   ├── excecoes.dart               # EmbarqueNaoPermitidoException (409), EmbarqueDuplicadoException (A-06)
│   │   │   ├── presenca_repository.dart    # contrato (A-07)
│   │   │   └── rota_repository.dart        # contrato (A-07)
│   │   └── infraestrutura/
│   │       ├── presenca_repository_postgres.dart  # situação + embarque em uma transação (A-07)
│   │       └── rota_repository_postgres.dart      # (A-07)
│   ├── notificacao/              # UC-I02 e a consulta de avisos
│   │   ├── dominio/
│   │   │   ├── notificacao.dart            # Notificacao (deEmbarque, marcarComoLida, pertenceA) e TipoMovimentacao (C-03)
│   │   │   └── notificacao_repository.dart # contrato (C-03)
│   │   ├── aplicacao/
│   │   │   ├── notificacao_service.dart          # contrato do <<include>> (B-05)
│   │   │   ├── notificacao_service_vazio.dart    # (B-05)
│   │   │   ├── notificacao_service_padrao.dart   # implementação real (C-04); ligada na B-11
│   │   │   └── avisos_service.dart               # (C-05)
│   │   ├── apresentacao/
│   │   │   └── notificacao_controller.dart       # (C-05)
│   │   └── infraestrutura/
│   │       └── notificacao_repository_postgres.dart  # (C-03)
│   └── embarque/                 # o caso de uso UC-S05: só coordenação e entrada HTTP
│       ├── aplicacao/
│       │   └── embarque_service.dart       # EmbarqueService e ResultadoRegistro (B-06, B-07, A-08, B-11)
│       └── apresentacao/
│           └── embarque_controller.dart    # (B-08, A-08, B-09)
└── test/                         # espelha lib/: test/<módulo>/<camada>/<arquivo>_test.dart
    ├── cadastro/dominio/          cadastro_dominio_test.dart
    ├── compartilhado/             autenticacao_test.dart, apresentacao/cors_test.dart,
    │                              dominio/horario_brasilia_iso_test.dart
    ├── rota/dominio/              rota_dominio_test.dart, presenca_registrar_embarque_test.dart
    ├── notificacao/               notificacao_test.dart; aplicacao/ (avisos_service, notificacao_service_padrao,
    │                              notificacao_service_vazio); apresentacao/notificacao_controller_test.dart
    ├── embarque/aplicacao/        embarque_service_test.dart (tabela da seção 3), embarque_service_listagem_test.dart
    ├── embarque/apresentacao/     embarque_controller_test.dart, embarque_controller_sincronizar_test.dart,
    │                              embarque_controller_listagem_test.dart
    └── integracao/                repositorios_postgres_test.dart; embarque_notificacao_postgres_test.dart (B-11)
                                   (tag "integracao": só rodam com o DATABASE_URL)
```

### 4.3 App

```text
app/
├── pubspec.yaml / pubspec.lock   # http, shared_preferences, connectivity_plus, geolocator, uuid, intl; dev: mocktail
├── lib/
│   ├── main.dart                 # COMPOSIÇÃO: cria Sessao, ApiClient, EmbarqueApi, MonitorConectividade e
│   │                             # o ModuloEmbarqueComFila (1 linha troca pelo Online); passa as telas ao login
│   ├── compartilhado/            # apoio de todos os módulos; NÃO importa nenhum módulo
│   │   ├── config.dart           # Config: API_URL e USE_MOCK (--dart-define) · infraestrutura (D-02)
│   │   ├── api_client.dart       # ApiClient e RespostaApi: http + token + modo mock · infraestrutura (D-02)
│   │   ├── sessao.dart           # Papel, UsuarioLogado, Sessao (token) · aplicação (D-02)
│   │   ├── cores.dart            # CoresApp: um verde e um âmbar · apresentação (D-02)
│   │   └── mock/
│   │       └── dados_mock.dart   # DadosMock: respostas simuladas no formato da seção 3 (D-02, E-04)
│   ├── login/                    # apoio, fora do ciclo de implementação
│   │   ├── aplicacao/
│   │   │   └── login_service.dart          # LoginService e LoginException (D-03)
│   │   └── apresentacao/
│   │       └── tela_login.dart             # TelaLogin: lista os usuários, um toque entra (D-03)
│   ├── embarque/                 # UC-R02 e fluxo A1
│   │   ├── apresentacao/
│   │   │   ├── tela_rota_do_dia.dart       # TelaRotaDoDia (D-05, D-06, E-05)
│   │   │   └── faixa_sem_conexao.dart      # FaixaSemConexao (D-05; ligada à rede na E-05)
│   │   ├── aplicacao/
│   │   │   ├── modulo_embarque.dart        # contrato D–E e tipos, EXATAMENTE como o backlog (D-04)
│   │   │   ├── modulo_embarque_online.dart # (D-04)
│   │   │   ├── modulo_embarque_com_fila.dart  # (E-03, E-04)
│   │   │   └── rota_do_dia_service.dart    # rota de hoje e alunos (D-05)
│   │   ├── dominio/
│   │   │   ├── aluno_da_rota.dart          # (D-05)
│   │   │   ├── rota_do_dia.dart            # (D-05)
│   │   │   ├── registro_embarque.dart      # um toque: corpo do POST + rotaId; paraJson/deJson (D-04, E-01)
│   │   │   ├── localizacao.dart            # (D-04)
│   │   │   ├── excecoes.dart               # EnvioRecusadoException, SemConexaoException (D-04)
│   │   │   ├── embarque_remoto.dart        # contrato (D-04)
│   │   │   ├── localizador.dart            # contrato (D-04)
│   │   │   ├── fila_embarques.dart         # contrato (E-01)
│   │   │   └── conectividade.dart          # contrato (E-02)
│   │   └── infraestrutura/
│   │       ├── embarque_api.dart           # EmbarqueRemoto sobre o ApiClient (timeout 5 s no ApiClient) (D-04)
│   │       ├── localizador_geolocator.dart # limite de 2 s (D-04)
│   │       ├── armazenamento_local.dart    # FilaEmbarques em shared_preferences (E-01)
│   │       └── monitor_conectividade.dart  # connectivity_plus + ValueNotifier<bool> (E-02)
│   └── avisos/                   # UC-I02 do lado do responsável
│       └── apresentacao/
│           └── tela_avisos.dart            # PROVISÓRIA (D-03); a tela real é da C-06 e da C-07 (ponto 19)
└── test/                         # espelha lib/
    ├── compartilhado/            dados_mock_test.dart
    ├── login/apresentacao/       tela_login_test.dart
    └── embarque/                 aplicacao/ (modulo_embarque_online, modulo_embarque_com_fila);
                                  apresentacao/ (tela_rota_do_dia, tela_rota_do_dia_embarque, faixa_sem_conexao);
                                  infraestrutura/ (armazenamento_local, embarque_api, monitor_conectividade)
```

Regras entre os módulos do app: `login`, `embarque` e `avisos` importam `compartilhado` e **não
importam um ao outro**. Quem liga o login às telas de `embarque` e `avisos` é o `main.dart`: ele
passa as telas ao `TelaLogin` como `ConstrutorDeTela` (`Widget Function(UsuarioLogado)`). Assim
o login não depende dos outros módulos. Isso é melhor do que a regra prevista na B-02, que
deixava o login importar as telas.

### 4.4 Banco de dados

```text
supabase/
├── migrations/                   # rodadas em ordem pelo reset (A-05); numeração = ordem
│   ├── 001_base.sql              # tabelas do mapa de dados + sessao, RLS em todas (A-03) ✓
│   └── 002_notificacao.sql       # tabela notificacao, RLS (C-01) ✓
└── seed.sql                      # dados da seção 6 do backlog, rota sempre em current_date (A-04) ✓
```

---

## 5. Decisões arquiteturais

| # | Decisão | Alternativas consideradas | Justificativa | Consequência |
|---|---|---|---|---|
| 1 | **API REST em Dart com Dart Frog** | App acessar o banco direto; servidor em outra linguagem | A disciplina pede back-end com API REST. As regras de acesso (RN-012, RN-002) ficam no servidor e não podem ser contornadas pelo app. Dart nas duas pontas: a equipe usa uma linguagem só. O Dart Frog cria as rotas pelos nomes dos arquivos, o que deixa o mapa URL → controller visível | `routes/` só delega; toda a lógica fica em `lib/` |
| 2 | **Supabase usado só como PostgreSQL** | `supabase_flutter`, Supabase Auth, Realtime, Edge Functions | O app não conhece o banco: tudo passa pela API (camadas). RLS ativado sem *policies* bloqueia a API automática do Supabase; o back-end entra como dono do banco. Trocar de provedor é trocar o `DATABASE_URL` | Sem notificação em tempo real nativa (ver decisão 5); cada membro tem um projeto próprio para rodar o seed |
| 3 | **Repositórios como contrato no domínio e implementação Postgres na infraestrutura** | Services chamando SQL direto | Exigência da disciplina; permite testar services com mocktail sem banco e trocar a versão vazia do `NotificacaoService` pela real | Um arquivo de contrato + um de implementação por repositório |
| 4 | **Idempotência pelo `registroId` (UUID gerado no aparelho)** | Bloquear por aluno + rota; gerar o id no servidor | Na sincronização offline o mesmo registro pode chegar duas vezes (falha no meio, reenvio). Com o id do aparelho, o servidor reconhece o repetido e devolve 200 sem salvar nem notificar de novo. `unique(registro_id)` no banco protege contra duas requisições simultâneas | O app gera o UUID no toque; o `EmbarqueService` diferencia 201 de 200 (`ResultadoRegistro.jaProcessado`) |
| 5 | **Notificação por *polling* (~10 s)** | Push com Firebase Cloud Messaging | Configurar FCM/APNs consumiria a sprint (risco da seção 8 do backlog). Gravar a `Notificacao` já é "registrar o evento como comunicado" (UC-I02, passo 4); a tela "Avisos" consulta `GET /notificacoes?desde=` | Aviso chega em até ~10 s; push fica como extra |
| 6 | **Fila offline no app (`shared_preferences`) + rota de sincronização em lote** | Bloquear o toque sem rede; SQLite; sincronizar um a um | RNF-006: o motorista não pode ficar travado sem sinal. `shared_preferences` funciona no Android e na Web. A `dataHora` do toque vai junto, então o horário salvo é o real. O lote reaproveita o mesmo `EmbarqueService` | `ModuloEmbarqueComFila` decide entre API e fila; sem rede ou timeout vai para a fila, 403/404/409 nunca |
| 7 | **Diretórios por funcionalidade, com as camadas dentro** | Pastas por camada no topo (`controllers/`, `services/`...) | Cada membro trabalha em um módulo, com menos conflito de merge. A pasta mostra o caso de uso (rastreabilidade), e a dependência entre módulos fica explícita (seção 4.1) | Regra de import entre módulos (sem ciclos), conferida no PR |
| 8 | **Composição em um único lugar por lado** (`routes/_middleware.dart` e `main.dart`) | Cada classe criar as suas dependências | As trocas planejadas (B-11 e E-05) viram uma linha; os testes injetam versões falsas pelo construtor | Os construtores recebem os contratos |
| 9 | **Hora em `timestamptz` e ISO 8601 com fuso; HH:MM em horário de Brasília** | Guardar hora local sem fuso | O servidor pode rodar em UTC. A conversão para UTC-3 acontece só na hora de mostrar (`HorarioBrasilia`) | Mensagem com a hora do embarque, mesmo se sincronizado depois |
| 10 | **Login simplificado como apoio** | Não identificar o usuário; login completo | A disciplina proíbe que o caso de uso implementado seja login, mas RN-012 e RN-002 precisam saber quem faz a requisição. O modelo tem `Usuario` com login e senha; a entrega usa o login pelos usuários do seed | Módulo `autenticacao` isolado, fora da contagem do caso de uso |
| 11 | **Falha no aviso não desfaz o embarque** (B-11) | Devolver erro (503) ao app; desfazer o embarque | O embarque já foi salvo. Com 503, o app reenviaria, receberia 200 (já processado) e o aviso se perderia do mesmo jeito, e o motorista ainda veria um erro. O `EmbarqueService` registra a falha no log (`dart:developer`) e devolve 201 | Um aviso pode se perder se o banco falhar justo ao gravá-lo; o registro do embarque (RF-009) nunca se perde |

---

## 6. Documentação das classes principais

As quatro classes que concentram o caso de uso, uma de cada papel: a entidade que guarda a
regra, o service que coordena o UC-S05, o contrato do `<<include>>` e o contrato do app que
separa a tela do envio.

| Classe | Camada / pasta | Responsabilidade | Operações | Dependências | RN | RF / RNF | UC |
|---|---|---|---|---|---|---|---|
| **`Presenca`** | domínio · `backend/lib/rota/dominio/presenca.dart` | Guardar a situação do aluno na rota (ordem, ponto de parada) e **registrar o próprio embarque**, validando o status. A situação e o embarque são privados: só a própria entidade os altera | `estaConfirmada()`; `registrarEmbarque(registroId, dataHora, localizacao?) : Embarque` (CONFIRMADO → EMBARCADO; senão `EmbarqueNaoPermitidoException`, 409) | `Aluno`, `PontoParada` (associação); `Embarque` (composição 0..1); `SituacaoPresenca`; `Localizacao` | RN-010 (só embarca quem está presente; ausente não tem embarque) | RF-009 | UC-S05 passos 3 e 4; UC-R02 passo 4 |
| **`EmbarqueService`** | aplicação · `backend/lib/embarque/aplicacao/embarque_service.dart` | **Coordenar o UC-S05** no servidor, na ordem do diagrama de sequência: rota existe, motorista ativo, idempotência, chamar a `Presenca`, salvar em uma transação e acionar o UC-I02. Também atende a listagem dos alunos e a rota de hoje | `registrarEmbarque(rotaId, alunoId, registroId, dataHora, localizacao?, motoristaId) : ResultadoRegistro`; `listarAlunosConfirmados(rotaId, motoristaId)`; `buscarRotaDoDia(motoristaId)`; `validarMotoristaAtivo(rota, motoristaId)` (privada) | contratos `RotaRepository`, `PresencaRepository`, `VinculoRepository`, `NotificacaoService` (injetados); exceções `AcessoNegadoException` (403), `NaoEncontradoException` (404) | RN-012 (só o motorista ativo da van); RN-010 (delegada à `Presenca`) | RF-009; RNF-006 (idempotência pelo `registroId`, lote) | UC-S05 passos 1 a 5 e A1 (lado do servidor) |
| **`NotificacaoService`** (contrato) | aplicação · `backend/lib/notificacao/aplicacao/notificacao_service.dart` | Ponto do `<<include>>`: o `EmbarqueService` avisa que houve uma movimentação, sem saber como o aviso é montado nem a quem vai. Implementações: `NotificacaoServiceVazio` (B-05) e `NotificacaoServicePadrao` (C-04), que busca os responsáveis, cria uma `Notificacao` por responsável e registra o comunicado | `notificarMovimentacao(presenca, tipo) : Future<void>` | `Presenca`, `TipoMovimentacao`; a implementação real usa `VinculoRepository`, `NotificacaoRepository` e a fábrica `Notificacao.deEmbarque` | RN-002 (só os responsáveis do aluno); RN-009 (menor tem responsável; maior pode não ter → A1) | RF-011 | UC-S05 passo 5; UC-I02 passos 1 a 4 e A1 |
| **`ModuloEmbarque`** (contrato D–E) | aplicação · `app/lib/embarque/aplicacao/modulo_embarque.dart` | Separar a tela do envio: a `TelaRotaDoDia` só pede "registre o embarque deste aluno" e recebe `enviado` ou `pendente`. Captura hora e localização no toque (GPS até 2 s) e gera o `registroId`. Implementações: `ModuloEmbarqueOnline` (D-04) e `ModuloEmbarqueComFila` (E-03, E-04) | `registrarEmbarque(rotaId, alunoId) : ResultadoEmbarque`; `listarPendentes(rotaId)`; `aoMudarPendentes : Stream<EventoPendente>` | tipos `StatusEnvio`, `ResultadoEmbarque`, `RegistroPendente`, `EventoPendente`, `EmbarqueException`; as implementações usam `EmbarqueRemoto`, `Localizador`, `FilaEmbarques`, `Conectividade` | RN-010 (o registro é a confirmação do motorista) | RF-009; RNF-005 (uma ação, sem esperar o GPS); RNF-006 (fila e sincronização) | UC-R02 passos 3 a 5 e E1; UC-S05 passo 2 e A1 (lado do app) |

Outras classes que também carregam regra (detalhes na seção 1.3):

| Classe | Regra que garante | RN / RF | UC |
|---|---|---|---|
| `VinculoMotoristaVan` | `estaAtivo()` e `autoriza(motoristaId)`: só o motorista do vínculo sem data de fim | RN-012 | UC-S05 (pré-condição) |
| `Notificacao` | `deEmbarque(...)` monta "&lt;aluno&gt; embarcou na van às HH:MM." com a hora do embarque em UTC-3; `pertenceA(responsavelId)` | RN-002; RF-011 | UC-I02 passo 2 |
| `ModuloEmbarqueComFila` | Sem rede ou timeout vai para a fila; 403/404/409 nunca vão; sincroniza ao reconectar, a cada 30 s e ao abrir o app | RNF-006; RF-009 | UC-S05 A1; UC-R02 E1 |
| `TelaRotaDoDia` | Um toque registra, sem diálogo; botão "Embarcou" de largura total e ≥ 56 de altura; status com cor + ícone + texto | RNF-005; RNF-004 | UC-R02 passos 1 a 5 |
| `AvisosService` | Só lista e só marca como lidos os avisos do responsável logado | RN-002; RF-011 | UC-I02 (consulta do aviso) |

### 6.1 Comentário de documentação no código

Cada classe principal leva no `///` a responsabilidade e as RN, RF e UC desta tabela, e cada
trecho que implementa uma regra cita a regra em um comentário curto. Modelo (como já está em
`presenca.dart`):

```dart
/// `Presenca` — rota :: domínio (participante "Presenca" do diagrama de
/// sequência UC-S05).
///
/// Responsabilidade: guardar a situação do aluno na rota e **registrar o
/// próprio embarque**, validando o status (RN-010).
/// UC-S05 passos 3 e 4; RF-009.
class Presenca {
  Embarque registrarEmbarque(String registroId, DateTime dataHora, [Localizacao? localizacao]) {
    // RN-010: só embarca quem está CONFIRMADO.
    ...
  }
}
```

## 7. Rastreabilidade RN → RF → UC → classes

Continua a cadeia do 1º bimestre (RN → RF → UC → sequência, em `documentos/atividade-02/04-rastreabilidade.md`
e `documentos/atividade-04/` do repositório do 1º bimestre) até as classes e operações deste projeto.

### 7.1 Cadeia de cada regra e requisito

| Item | Requisito | Caso de uso e passo | Mensagem na sequência | Classes e operações | Teste que comprova |
|---|---|---|---|---|---|
| **RN-010** Embarque só de quem está presente; ausente não tem embarque | RF-009 | UC-S05 passo 1 (ausente não aparece) | `buscarConfirmados(rotaId)` | `PresencaRepository.buscarConfirmados` (só CONFIRMADO e EMBARCADO, na ordem); `EmbarqueService.listarAlunosConfirmados` | Aceitação 1 (Bruno não aparece); teste da A-08 |
| | RF-009 | UC-S05 passos 3 e 4; UC-R02 passo 4 | `registrarEmbarque(dataHora, local)` em `Presenca` | **`Presenca.registrarEmbarque`** (CONFIRMADO → EMBARCADO); `EmbarqueNaoPermitidoException` → 409 no `EmbarqueController` | Testes da B-04 (CONFIRMADO embarca; AUSENTE e EMBARCADO lançam); aceitação 6 (409) |
| **RN-012** Um motorista ativo por van; só ele registra | RF-009 (aplicada aqui; ver ponto 18) · RF-014 no 1º bimestre | UC-S05, pré-condição (rota ativa da van do motorista) | — (não aparece na sequência; ver ponto 18) | `VinculoMotoristaVan.estaAtivo`, `VinculoMotoristaVan.autoriza`; `VinculoRepository.buscarVinculoAtivo`; `EmbarqueService.validarMotoristaAtivo` → `AcessoNegadoException` (403); banco: um vínculo ativo por van (A-03) | Teste da A-06 (`estaAtivo`); testes da A-08 e da B-10 (403); aceitação 7 |
| **RN-002** Responsável só vê os alunos sob sua responsabilidade | RF-011 | UC-I02 passos 1 e 3 | `buscarResponsaveis(aluno)` | `VinculoRepository.buscarResponsaveis`; `NotificacaoServicePadrao.notificarMovimentacao` (notifica só esses); `Notificacao.pertenceA`; `AvisosService.listarDoResponsavel` e `marcarComoLida` | Teste da C-05 (outra família não vê nem marca); aceitação 4 |
| **RN-009** Menor tem ao menos um responsável; maior pode não ter | RF-011 | UC-I02 passo 1 e A1 (aluno maior sem responsável) | `buscarResponsaveis(aluno)`; "nenhuma notificação é enviada" | `Aluno.ehMenorDeIdade`; `VinculoRepository.buscarResponsaveis` (lista vazia); `NotificacaoServicePadrao` (A1: não cria nada e retorna) | Testes da C-04 (Ana → 2, Carlos → 0); aceitação 5 |
| **RF-009** Registrar embarque com data, horário e localização | — | UC-S05 passos 2 a 4; UC-R02 passos 3 e 4 | `confirmarEmbarque(alunoId)`, `registrarEmbarque(...)`, `salvar(presenca)` | `TelaRotaDoDia.confirmarEmbarque` → `ModuloEmbarque.registrarEmbarque` → `POST /rotas/{rotaId}/embarques` → `EmbarqueController.registrarEmbarque` → **`EmbarqueService.registrarEmbarque`** → `Presenca.registrarEmbarque` → `PresencaRepository.salvar`; `Embarque` (dataHora do toque, localização opcional) | Testes da B-10 (dataHora salva é a enviada); aceitação 2 |
| **RF-011** Notificar o responsável sobre o embarque | — | UC-S05 passo 5 → UC-I02 passos 1 a 4 | `notificarMovimentacao(presenca, tipo)`, `montarMensagem`, `registrarComunicado(evento)` | **`NotificacaoService.notificarMovimentacao`** (`NotificacaoServicePadrao`); `Notificacao.deEmbarque`; `NotificacaoRepository.registrarComunicado`; `GET /notificacoes` → `NotificacaoController.listar` → `AvisosService.listarDoResponsavel`; ligado ao `EmbarqueService` no `routes/_middleware.dart` (B-11); tela "Avisos" com polling ~10 s (C-06/C-07, pendente: ponto 19) | `notificacao_test.dart` (hora em UTC-3), `notificacao_service_padrao_test.dart`, `embarque_notificacao_postgres_test.dart` (Ana → 2, Carlos → 0, com banco); aceitação 3 |
| **RNF-005** Ações do motorista com uma única ação principal | RF-009 | UC-R02 passo 3 (toque no botão "Embarcou") | `confirmarEmbarque(alunoId)` | `TelaRotaDoDia` (um toque, sem diálogo, botão ≥ 56); `ModuloEmbarque.registrarEmbarque` (uma chamada); `Localizador.obterLocalizacao(2 s)` (o toque nunca espera o GPS) | Testes da D-08; aceitação 2 |
| **RNF-006** Check-ins offline sincronizados em até 5 min | RF-009 | UC-S05 A1; UC-R02 E1 | `guardar(registroEmbarque)`, `sincronizar(registros)` | **`ModuloEmbarqueComFila`** (`registrarEmbarque`, `sincronizar`); `FilaEmbarques` / `ArmazenamentoLocal`; `Conectividade` / `MonitorConectividade`; `EmbarqueRemoto.sincronizar` → `EmbarqueController.sincronizar` → `EmbarqueService.registrarEmbarque`; idempotência: `Embarque.registroId`, `PresencaRepository.buscarPorRegistroId`, `EmbarqueDuplicadoException`, `ResultadoRegistro.jaProcessado` | Testes da E-06 e da B-10 (mesmo `registroId` → 1 embarque, 1 notificação); aceitação 8, 9 e 10 |

### 7.2 Visão inversa: de cada classe para o que ela atende

| Classe | RN | RF / RNF | UC |
|---|---|---|---|
| `Presenca` | RN-010 | RF-009 | UC-S05, UC-R02 |
| `Embarque` | RN-010 | RF-009, RNF-006 | UC-S05 |
| `VinculoMotoristaVan` | RN-012 | RF-009 | UC-S05 |
| `Aluno` | RN-009 | RF-011 | UC-I02 |
| `Notificacao` | RN-002 | RF-011 | UC-I02 |
| `PresencaRepository` | RN-010 | RF-009, RNF-006 | UC-S05 |
| `VinculoRepository` | RN-002, RN-009, RN-012 | RF-009, RF-011 | UC-S05, UC-I02 |
| `RotaRepository` | RN-012 | RF-009 | UC-S05 |
| `NotificacaoRepository` | RN-002 | RF-011 | UC-I02 |
| `EmbarqueService` | RN-010, RN-012 | RF-009, RNF-006 | UC-S05 |
| `NotificacaoService` / `NotificacaoServicePadrao` | RN-002, RN-009 | RF-011 | UC-I02 |
| `AvisosService` | RN-002 | RF-011 | UC-I02 |
| `EmbarqueController` | — (só converte) | RF-009, RNF-006 | UC-S05 |
| `TelaRotaDoDia` | RN-010 | RF-009, RNF-004, RNF-005 | UC-R02 |
| `ModuloEmbarque` / `ModuloEmbarqueOnline` | RN-010 | RF-009, RNF-005 | UC-R02, UC-S05 |
| `ModuloEmbarqueComFila`, `FilaEmbarques`, `ArmazenamentoLocal`, `Conectividade` | — | RNF-006 | UC-S05 A1, UC-R02 E1 |

A coluna "Teste que comprova" fecha a cadeia até a execução. Os números de aceitação são
os da seção 7 do backlog.

---

## 8. Pontos para a equipe decidir

O contrato do módulo de embarque (seção 3 do backlog) **não foi alterado**. O contrato da API
mudou em um único ponto, decidido na revisão: o novo `GET /rotas/hoje` (pontos 8 e 9). O
diagrama mostrou os pontos abaixo; os marcados como **Decidido** já foram aplicados aos
diagramas. Os demais (3 a 6 e 10 a 14) foram **aceitos como o diagrama assumiu** na revisão
do Membro B e seguem para a revisão da equipe no fim do Dia 1.

| # | Ponto | O que o diagrama assumiu | Quem decide / afeta |
|---|---|---|---|
| 1 | ~~Identificação do usuário~~ **Decidido.** A disciplina proíbe que o caso de uso **implementado** seja login, mas o modelo do sistema pode ter login | `Usuario` (login, senha, papel) com `Motorista` e `Responsavel` herdando dele, mais `Sessao` e `AutenticacaoMiddleware`. Na implementação, o login simplificado da C-02 só identifica quem faz a requisição (RN-012, RN-002). A conferência de senha (`autenticar`) fica no modelo; a C-02 decide se a usa ou se entra pelo id do seed | Membro C (C-02); Membro A (colunas de usuário na migration) |
| 2 | **Decidido: dono do `GET /rotas/{rotaId}/alunos`.** Segue a sequência UC-S05 | `EmbarqueController.listarAlunos` → `EmbarqueService.listarAlunosConfirmados`. O Membro A implementa esses métodos nos arquivos do módulo embarque (combinar com o B para não editarem o mesmo arquivo ao mesmo tempo) | Membros A e B |
| 3 | **`RotaRepository` é novo.** O backlog cita só `PresencaRepository` e `VinculoRepository`, mas o 404 da rota e a van da rota (RN-012) precisam dele | Contrato `RotaRepository.buscarPorId` | Membro A (A-07) |
| 4 | **Persistência do embarque.** Não existe `EmbarqueRepository`: o `Embarque` faz parte da `Presenca` (composição) e é salvo por `PresencaRepository.salvar` em uma transação. A idempotência usa `buscarPorRegistroId`, e a unicidade do banco vira `EmbarqueDuplicadoException` | Como descrito na seção 2.4. Sugestão para a migration: `unique(registro_id)` e `unique(presenca_id)` na tabela `embarque` | Membros A e B |
| 5 | **`Presenca.registrarEmbarque` recebe o `registroId`.** A sequência e o prompt do Membro B mostram `(dataHora, localizacao)`; sem o id a entidade não consegue criar o `Embarque` completo | `registrarEmbarque(registroId, dataHora, localizacao?)` | Membros A e B; E-07 atualiza `UC-S05.puml` |
| 6 | **`montarMensagem` saiu do service.** Na sequência UC-I02 é o `NotificacaoService` que monta a mensagem; aqui é a fábrica `Notificacao.deEmbarque` (entidade com comportamento, pedido do professor) | Fábrica na entidade | E-07 atualiza `UC-I02.puml` |
| 7 | **Decidido: aluno sem presença na rota → 404** ("aluno não existe nesta rota") | `buscarPresenca` devolve nulo → `NaoEncontradoException`. Não precisa de `AlunoRepository` | Membro B |
| 8 e 9 | **Decidido: rota do dia e cabeçalho por um endpoint novo, `GET /rotas/hoje`.** O app não tinha como descobrir o `rotaId` nem a placa, o trajeto e o horário do cabeçalho | `EmbarqueService.buscarRotaDoDia` + `RotaRepository.buscarDoMotorista`; no app, `RotaDoDiaService.buscarRotaDoDia` e `RotaDoDia`. **Muda o contrato da API**: acrescentar na seção 3 do backlog (texto proposto abaixo) | Equipe; Membro A (endpoint); Membro D (tela) |
| 10 | **Coluna `sincronizado` do embarque** (mapa de dados). No servidor, todo embarque gravado já está sincronizado; a fila fica no aparelho | O atributo não foi para a entidade `Embarque` | Membro A (A-03); E-07 atualiza o mapa de dados |
| 11 | **Pré-condição "rota ativa"** do UC-S05 não tem código de resposta no contrato | Não é validada nesta entrega (a rota do seed está sempre ativa) | Equipe |
| 12 | **`AvisosService` separado do `NotificacaoService`.** O contrato `NotificacaoService` fica só com `notificarMovimentacao` (o que o `EmbarqueService` precisa); a consulta de avisos da tela fica em outro service, e a versão vazia não precisa implementar consultas | Duas classes de aplicação no módulo notificacao | Membro C |
| 13 | **Contratos do app** (`EmbarqueRemoto`, `FilaEmbarques`, `Conectividade`, `Localizador`) e `RotaDoDiaService`, `AlunoDaRota`, `RegistroEmbarque`: nomes propostos aqui para aplicar no app a mesma regra do servidor (aplicação depende de contrato, infraestrutura implementa). `RegistroEmbarque` guarda a localização e o `rotaId`, que o `RegistroPendente` do contrato não tem | Como no Diagrama 3, sem mudar o `ModuloEmbarque` | Membros D e E |
| 14 | **`TipoMovimentacao.DESEMBARQUE`** já existe no enum para o bônus UC-S06 (seção 9 do backlog); nesta entrega só EMBARQUE é usado | Enum com os dois valores | Equipe |
| 15 | **Ciclo `cadastro ↔ compartilhado` (B-02).** O login da C-02 ficou em `compartilhado/` e importa `Usuario`, `Motorista` e `Responsavel` de `cadastro/`. A A-07 (PR #17, já mergeada) criou `cadastro/infraestrutura/vinculo_repository_postgres.dart`, que importa a `ConexaoBanco` de `compartilhado/`: **o ciclo já existe na `desenvolvimento`** | Mover os 8 arquivos do login para o módulo `lib/autenticacao/` (árvore da seção 4.2) e corrigir os imports em `routes/_middleware.dart`, `routes/login.dart`, `routes/usuarios.dart` e nos testes. Sem mudança de comportamento. **Bug no Jira** (decidido na B-12: o Membro B faz, com o OK do Membro C, porque o C está com a C-06, a C-07 e a C-08) | Membro B (Bug); Membro C revisa |
| 16 | ~~Bibliotecas do app (B-02)~~ **Resolvido.** O `material_ui` saiu do `app/pubspec.yaml` e o `mocktail` entrou nos `dev_dependencies` | — | Membro D |
| 17 | ~~Classes do código que não estão no diagrama (B-02)~~ **Resolvido na B-12.** `UsuarioRepository`, `AutenticacaoService`, `AutenticacaoController`, o login e o compartilhado do app entraram nos diagramas com os nomes reais | A tela "Avisos" continua no ponto 19 | Membro B (B-12) |
| 18 | **RN-012 fora da cadeia do UC-S05 no 1º bimestre (B-03).** Em `atividade-02/04-rastreabilidade.md` a RN-012 só aponta para RF-002, RF-007, RF-012 e RF-014. O UC-S05 cita só a RN-010, e a sequência `UC-S05.puml` não mostra a validação do motorista. Mas o UC-S05 depende dela: só o motorista ativo da van registra (403) | Aqui a cadeia foi completada (seção 7.1). Atualizar a rastreabilidade, as regras do UC-S05 (RN-010, **RN-012**) e incluir `validarMotoristaAtivo` na sequência ("melhorias em todo o projeto") | Membro E (E-07) |
| 19 | **Tela "Avisos" pendente (B-12).** No app, `avisos/` só tem a `TelaAvisos` provisória da D-03. A tela real (cards por aluno, lista do dia, polling ~10 s, faixa sem conexão, marcar como lido) é da C-06 e da C-07, que ainda não foram mergeadas. Os testes de aceitação 3, 4 e 5 dependem dela | No Diagrama 3 a tela aparece marcada como **PENDENTE**. Quando a C-06 e a C-07 entrarem, as classes reais entram no diagrama e na árvore da seção 4.3 | Membro C (C-06, C-07); Membro B complementa o diagrama |
| 20 | ~~Notificação que falha depois de salvar o embarque (B-10)~~ **Decidido na B-11.** Se o aviso falha, o embarque continua 201 e o erro vai para o log | Decisão 11 da seção 5; teste em `embarque_service_test.dart` | Membro B |
| 21 | **Código sem uso no app (B-12).** `MonitorConectividade.monitorarChamada` só é chamado nos testes: o `ModuloEmbarqueComFila` informa a rede com `registrarFalhaDeRede`/`registrarSucessoDeRede`, o timeout de 5 s fica no `ApiClient` e o `EmbarqueApi` converte timeout e erro de rede em `SemConexaoException` | Manter (está documentado no diagrama) ou remover numa task do Membro E | Membro E |

### 8.1 Texto proposto para a seção 3 do backlog (pontos 8 e 9)

```text
GET /rotas/hoje

Usado logo depois do login do motorista, para abrir a "Rota do dia".
Devolve a rota de hoje da van em que o usuário logado é o motorista ativo (RN-012).

200 { "rotaId": 1, "trajeto": "IDA", "horarioPrevisto": "2026-11-16T06:30:00-03:00",
      "placa": "ABC-1D23" }
403 Usuário não é motorista
404 Motorista sem rota hoje (inclui o motorista sem vínculo com van)
```
