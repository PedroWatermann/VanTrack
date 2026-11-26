# Checklist da entrega — UC-S05 Registrar Embarque

Conferência das exigências da disciplina (seção 11 do backlog) para a entrega de
**02/12 às 19:31**. Task **VT-67 (A-12)**.

**Conferido em 25/11** sobre a `desenvolvimento` no commit `34f411d`, mais os ajustes
finais da VT-79. Esse estado tem:
- a VT-64 (diagrama final), a VT-65 (revisão do 1º bimestre), a VT-66 (roteiro da demo e
  evidências) e a VT-73 (imagens dos diagramas);
- as correções dos bugs dos testes de aceitação: VT-75, VT-76 e VT-77;
- a 2ª execução dos testes, com os 10 aprovados (`05-testes-aceitacao.md`);
- a sessão vencida em "Avisos" (bug VT-78);
- os ajustes finais (VT-79): o comentário de rastreabilidade no `ModuloEmbarque`, o roteiro
  da demo só na Web, a seção 3 do backlog atualizada e a tabela da equipe no `README.md`.

Legenda: **OK** atendido · **Parcial** atendido com pendência · **Falta** não atendido.

## Exigências

| # | Exigência do professor | Situação | Onde está / o que falta |
|---|---|---|---|
| 1 | Entrega até 02/12 às 19:31 | Falta | O trabalho está na `desenvolvimento`. A `master`, branch padrão do GitHub, ainda tem só o commit inicial e o revert do diagrama. Falta o PR da `desenvolvimento` para a `master`. Ele foi simulado em 25/11 e entra sem conflito: o resultado é igual à `desenvolvimento`, com os diagramas que o revert tinha apagado. |
| 2 | 1 caso de uso, que não seja login nem relatório | OK | UC-S05 Registrar Embarque, com o UC-I02 e o fluxo A1. O login é só apoio para identificar o usuário (`03-arquitetura.md`, ponto 1). |
| 3 | Regras de negócio, requisitos (RF e RNF), definição do UC e diagrama de sequência | OK | Feitos no 1º bimestre e revisados conforme a implementação em `documentos/revisao-1-bimestre/` (VT-65): mapa de dados, regras, requisitos, rastreabilidade, casos de uso e diagramas de sequência UC-S05, UC-R02 e UC-I02. |
| 4 | Diagrama de classes do UC | OK | `03-arquitetura.md`, com os 3 diagramas em `scripts/` (PlantUML) e em `imagens/` (PNG e SVG), atualizados com o código (VT-64, VT-73). |
| 5 | Interface gráfica, back-end (API REST) e banco de dados | OK | App Flutter em `app/` (108 testes), API em Dart Frog em `backend/` (134 testes sem banco), PostgreSQL no Supabase em `supabase/` (2 migrations e o seed). Analisador sem avisos nos dois. |
| 6 | Arquitetura em camadas e estrutura de diretórios justificada | OK | `03-arquitetura.md`, seções 3 (camadas, dependências permitidas e proibidas) e 4 (diretórios do back-end, do app e do banco). |
| 7 | Contrato do repositório separado da implementação na infraestrutura | OK | No back-end, 6 contratos em `*/dominio/*_repository.dart` e 5 implementações em `*/infraestrutura/*_postgres.dart` (o `SessaoRepositoryPostgres` implementa dois). No app, o mesmo padrão: `FilaEmbarques`, `RotaSalva` e `EmbarqueRemoto` no domínio, implementados na infraestrutura. O domínio não importa `dart_frog` nem `postgres`. |
| 8 | Entidades com comportamento (sem classes anêmicas) | OK | `Presenca.registrarEmbarque` (RN-010), `VinculoMotoristaVan.estaAtivo` e `autoriza` (RN-012), `Aluno.ehMenorDeIdade` (RN-009), `Notificacao.deEmbarque`, `marcarComoLida` e `pertenceA` (RN-002). |
| 9 | Rastreabilidade RN → RF → UC → classes | OK | Tabela na seção 7 do `03-arquitetura.md` e comentário `///` com RN, RF e UC nas classes principais do back-end e do app, inclusive no contrato `ModuloEmbarque` e nas suas duas implementações. |
| 10 | Jira em ciclos de 7 dias com epic, story, task e bug | OK | Projeto VT, "VT Sprint 2", com Epic, Stories, tasks e 7 bugs: VT-68, VT-69, VT-71 e VT-72 (desenvolvimento) e VT-75, VT-76 e VT-77 (testes de aceitação). Prints em `documentos/desenvolvimento/evidencias/` (VT-66), de 22/11. |
| 11 | Cada task do Jira vira uma branch no GitHub | Parcial | Quase todas têm branch `task-<nº>-…` e PR, inclusive os bugs. Exceções: VT-21 (veio no PR #1, da branch `desenvolvimento`), VT-46 (entrou junto com a VT-47 no PR #46) e VT-51 (o PR #22 foi mergeado na `task-50`, não na `desenvolvimento`). Vale saber explicar na apresentação. |
| 12 | "Melhorias em todo o projeto" | OK | Revisão dos artefatos do 1º bimestre (VT-65), roteiro da demo (`06-roteiro-demo.md`, VT-66), correções dos testes de aceitação (VT-75, VT-76, VT-77) e a seção 3 do backlog (contrato da API) atualizada conforme a implementação. |

## Testes de aceitação

Foram duas execuções; os detalhes estão em `05-testes-aceitacao.md`.

| Execução | Commit | Resultado |
|---|---|---|
| 24/11 | `32361cc` | 8 de 10. O 9 e o 10 falharam, e apareceram 3 bugs. |
| 25/11 | `55b7924` | **10 de 10.** Também passou uma conferência extra da fila separada por motorista. |

| Bug | Problema | PR |
|---|---|---|
| VT-75 | O login não ficava salvo: aberto sem conexão, o app não mostrava a rota nem os pendentes (teste 9). | #56 |
| VT-76 | A fila offline era do aparelho: com outro usuário logado, um 403 apagava o embarque pendente. | #58 |
| VT-77 | Depois de uma falha de rede, o app ficava "sem conexão" para sempre e não sincronizava (testes 5 e 10). | #57 |

As duas execuções foram no vantrack-demo e só na Web, como será a apresentação. O Android
não foi testado.

## O que falta

| # | Pendência | Dono |
|---|---|---|
| 1 | Preencher o nome e o RA na tabela "Equipe" do `README.md`, cada um em um commit seu | Membros A a E |
| 2 | PR da `desenvolvimento` para a `master`, com **merge commit** (não squash), até 01/12 | Membro A |
| 3 | Antes de apresentar: `dart run bin/reset_db.dart` no vantrack-demo e seguir o `06-roteiro-demo.md` | Quem apresentar |
