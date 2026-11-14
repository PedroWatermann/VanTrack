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
| Seção 1 — Identificação das classes | **B-01** (este PR) |
| Seção 2 — Diagrama de classes | **B-01** (este PR) |
| Arquitetura em camadas, diretórios e decisões arquiteturais | B-02 (próxima branch) |
| Documentação das classes principais e rastreabilidade até as classes | B-03 |
| Seção 3 — Pontos para a equipe decidir | atualizada a cada task |

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
| `registrarEmbarque(dataHora, local)` em `Presenca` | `Presenca.registrarEmbarque(registroId, dataHora, localizacao)` (ganhou o `registroId`, ver seção 3) |
| `salvar(presenca)` | `PresencaRepository.salvar` |
| `guardar(registroEmbarque)` | `FilaEmbarques.guardar` (implementado por `ArmazenamentoLocal`) |
| `sincronizar(registros)` | `ModuloEmbarqueComFila.sincronizar` → `EmbarqueRemoto.sincronizar` → `EmbarqueController.sincronizar` |
| `notificarMovimentacao(presenca, tipo)` | `NotificacaoService.notificarMovimentacao` |
| `buscarResponsaveis(aluno)` | `VinculoRepository.buscarResponsaveis` |
| `montarMensagem(tipo, horário)` | `Notificacao.deEmbarque(...)`. A regra passou do service para a entidade, para a entidade não ficar anêmica (ver seção 3) |
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
| Identificação do usuário: login (modelado, mas **fora do ciclo de implementação**: a disciplina proíbe que o caso de uso implementado seja login) | `Usuario`, `Papel`, `Sessao`, `SessaoRepository`, `AutenticacaoMiddleware`, `UsuarioLogado`, `ApiClient` |

### 1.3 Classes, camadas e responsabilidades

#### Back-end (Dart Frog)

| Classe | Camada | Responsabilidade | Atributos | Operações |
|---|---|---|---|---|
| `Aluno` | domínio (cadastro) | Representar o aluno transportado e saber se é menor de idade (RN-009) | id, nome, dataNascimento | `ehMenorDeIdade(referencia)` |
| `Usuario` | domínio (cadastro), abstrata | O que motorista e responsável têm em comum: identificação, login e senha, e o papel | id, nome, login, senhaHash (privada) | `papel` (abstrato), `autenticar(senha)` |
| `Papel` | domínio (cadastro), enum | Papel do usuário na API | MOTORISTA, RESPONSAVEL | — |
| `Responsavel` | domínio (cadastro), herda de `Usuario` | Representar quem recebe os avisos do aluno | telefone, email | — |
| `Motorista` | domínio (cadastro), herda de `Usuario` | Representar o motorista que opera a van | telefone, cnh | — |
| `Sessao` | domínio (autenticação), apoio | Token de acesso de um usuário | token, criadaEm | `estaValida(agora)` |
| `SessaoRepository` | domínio (contrato), apoio | Achar a sessão pelo token | — | `buscarPorToken(token)`, `salvar(sessao)` |
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
| `HorarioBrasilia` | domínio (compartilhado), utilitário | Formatar HH:MM em UTC-3, mesmo com o servidor em UTC | — | `formatarHoraMinuto(dataHora)` |
| `EmbarqueController` | apresentação (embarque) | Converter JSON ↔ objetos e exceções ↔ códigos HTTP. Sem regra de negócio e sem acesso a repositório | service | `buscarRotaDoDia`, `listarAlunos`, `registrarEmbarque`, `sincronizar`, `codigoHttpDe(erro)` |
| `NotificacaoController` | apresentação (notificacao) | Converter as rotas de avisos em chamadas ao `AvisosService` | avisosService | `listar(usuario, desde?)`, `marcarComoLida(notificacaoId, usuario)` |
| `AutenticacaoMiddleware` | apresentação (autenticação), apoio | Ler o token do header `Authorization`, achar a `Sessao` e entregar o `UsuarioLogado` às rotas (sem token válido → 401) | sessaoRepository | `identificar(token)` |
| `UsuarioLogado` | apresentação (autenticação), apoio | Quem fez a requisição e o seu papel; é o que os controllers recebem | id, papel | — |
| `EmbarqueService` | aplicação (embarque) | **Coordenar o UC-S05**: rota existe, motorista ativo, idempotência, chamar a `Presenca`, salvar e acionar o UC-I02 | rotaRepository, presencaRepository, vinculoRepository, notificacaoService | `buscarRotaDoDia(motoristaId)`, `listarAlunosConfirmados(rotaId, motoristaId)`, `registrarEmbarque(rotaId, alunoId, registroId, dataHora, localizacao?, motoristaId)` |
| `ResultadoRegistro` | aplicação (embarque) | Resultado do registro; `jaProcessado` diferencia o 201 do 200 | alunoId, situacao, jaProcessado | — |
| `AcessoNegadoException`, `NaoEncontradoException` | aplicação (compartilhado) | Erros de coordenação que viram 403 e 404 | mensagem | — |
| `NotificacaoService` | aplicação (contrato) | Ponto do `<<include>>` UC-I02 usado pelo `EmbarqueService` | — | `notificarMovimentacao(presenca, tipo)` |
| `NotificacaoServiceVazio` | aplicação (notificacao) | Versão que não faz nada, para o UC-S05 não esperar o UC-I02 (task B-05) | — | `notificarMovimentacao` |
| `NotificacaoServicePadrao` | aplicação (notificacao) | **Coordenar o UC-I02**: buscar os responsáveis, criar uma `Notificacao` por responsável e registrar o comunicado; A1 sem responsável não cria nada | vinculoRepository, notificacaoRepository | `notificarMovimentacao` |
| `AvisosService` | aplicação (notificacao) | Consultar os avisos do responsável logado e marcar como lido só os dele (RN-002) | notificacaoRepository | `listarDoResponsavel(responsavelId, desde?)`, `marcarComoLida(notificacaoId, responsavelId)` |
| `ConexaoBanco` | infraestrutura (compartilhado) | Único *pool* de conexões com o Postgres e transação (`runTx`) | pool | `abrir(databaseUrl)`, `executar(sql, parametros)`, `emTransacao(acao)` |
| `PresencaRepositoryPostgres`, `RotaRepositoryPostgres`, `VinculoRepositoryPostgres`, `NotificacaoRepositoryPostgres`, `SessaoRepositoryPostgres` | infraestrutura | Implementar os contratos com SQL no Postgres (Supabase) | conexao | as do contrato |

#### App (Flutter) — módulo embarque

| Classe | Camada | Responsabilidade | Atributos | Operações |
|---|---|---|---|---|
| `TelaRotaDoDia` | apresentação | Mostrar a rota (cabeçalho, próxima parada, Depois, Na van) e registrar com **um toque** (RNF-005). Só conversa com `ModuloEmbarque` e `RotaDoDiaService` | modulo, rotaDoDiaService, rota, alunos | `abrirRota(rotaId)`, `confirmarEmbarque(alunoId)` |
| `FaixaSemConexao` | apresentação | Faixa âmbar "Sem conexão" sempre visível quando offline (RNF-003) | semConexao | — |
| `ModuloEmbarque` | aplicação (contrato D–E) | Contrato interno da seção 3 do backlog, **sem alteração** | — | `registrarEmbarque(rotaId, alunoId)`, `listarPendentes(rotaId)`, `aoMudarPendentes` |
| `StatusEnvio`, `ResultadoEmbarque`, `RegistroPendente`, `EventoPendente`, `EmbarqueException` | aplicação | Tipos do contrato, exatamente como no backlog | (ver backlog) | — |
| `ModuloEmbarqueOnline` | aplicação | Implementação só online (Membro D): captura hora e GPS (até 2 s), gera o `registroId` e envia | remoto, localizador | as do contrato |
| `ModuloEmbarqueComFila` | aplicação | Implementação com fila offline (Membro E): decide entre API e fila, sincroniza ao reconectar, a cada 30 s e ao abrir o app, sem sincronizações simultâneas (RNF-006) | remoto, fila, conectividade, localizador, sincronizando, eventos | as do contrato + `sincronizar()` |
| `RotaDoDiaService` | aplicação | Descobrir a rota de hoje e listar os seus alunos para a tela | remoto | `buscarRotaDoDia()`, `listarAlunosConfirmados(rotaId)` |
| `RotaDoDia` | domínio | Dados do cabeçalho da tela (formato do `GET /rotas/hoje`) | rotaId, trajeto, horarioPrevisto, placa | — |
| `AlunoDaRota` | domínio | Aluno como a tela o mostra (formato do `GET /rotas/{rotaId}/alunos`) | alunoId, nome, ordem, endereco, embarcado | — |
| `RegistroEmbarque` | domínio | Um toque em "Embarcou": corpo do `POST` + `rotaId`. É o item guardado na fila | registroId, rotaId, alunoId, dataHora, localizacao? | — |
| `Localizacao` | domínio, value object | Latitude/longitude do toque | latitude, longitude | — |
| `EnvioRecusadoException`, `SemConexaoException` | domínio | Separar "servidor recusou" (403/404/409, nunca vai para a fila) de "sem rede/timeout" (vai para a fila) | codigoHttp, mensagem | — |
| `EmbarqueRemoto` | domínio (contrato) | Falar com a API de embarque | — | `buscarRotaDoDia`, `listarAlunos`, `enviar`, `sincronizar` |
| `FilaEmbarques` | domínio (contrato) | Fila persistente de registros pendentes | — | `guardar`, `listar(rotaId)`, `remover(registroIds)` |
| `Conectividade` | domínio (contrato) | Dizer se há rede e avisar quando muda | — | `estaOnline`, `aoMudar` |
| `Localizador` | domínio (contrato) | Obter a localização com tempo limite | — | `obterLocalizacao(limite)` |
| `EmbarqueApi` | infraestrutura | `EmbarqueRemoto` com o pacote `http` (timeout de 5 s) | api | as do contrato |
| `ArmazenamentoLocal` | infraestrutura | `FilaEmbarques` em JSON no `shared_preferences` (Android e Web) | prefs | as do contrato |
| `MonitorConectividade` | infraestrutura | `Conectividade` com `connectivity_plus`; expõe `ValueNotifier<bool>` para a faixa | online | as do contrato |
| `LocalizadorGeolocator` | infraestrutura | `Localizador` com `geolocator` | — | `obterLocalizacao(limite)` |
| `ApiClient` | infraestrutura (compartilhado), apoio | Cliente HTTP com `API_URL` e o token | baseUrl, token | `get`, `post` |

---

## 2. Diagrama de classes

Os diagramas estão em PlantUML. Como o diagrama completo fica grande, ele foi dividido em três:

| # | Arquivo | Conteúdo |
|---|---|---|
| 1 | [`scripts/diagrama-classes-uc-s05.puml`](scripts/diagrama-classes-uc-s05.puml) | **Domínio do back-end**: entidades, enums, value objects e contratos de repositório, com atributos, operações, relacionamentos e multiplicidades |
| 2 | [`scripts/diagrama-classes-uc-s05-backend.puml`](scripts/diagrama-classes-uc-s05-backend.puml) | **Camadas do back-end**: controllers, services, contrato `NotificacaoService` e implementações Postgres que realizam os contratos |
| 3 | [`scripts/diagrama-classes-uc-s05-app.puml`](scripts/diagrama-classes-uc-s05-app.puml) | **App Flutter**: `TelaRotaDoDia`, contrato `ModuloEmbarque` e as suas duas implementações, `ArmazenamentoLocal` e os contratos usados nos testes |

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

## 3. Pontos para a equipe decidir

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

### 3.1 Texto proposto para a seção 3 do backlog (pontos 8 e 9)

```text
GET /rotas/hoje

Usado logo depois do login do motorista, para abrir a "Rota do dia".
Devolve a rota de hoje da van em que o usuário logado é o motorista ativo (RN-012).

200 { "rotaId": 1, "trajeto": "IDA", "horarioPrevisto": "2026-11-16T06:30:00-03:00",
      "placa": "ABC-1D23" }
403 Usuário não é motorista
404 Motorista sem rota hoje (inclui o motorista sem vínculo com van)
```
