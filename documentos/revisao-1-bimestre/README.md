# Revisão dos Artefatos do 1º Bimestre (E-07 / VT-65)

Esta pasta reúne as atualizações dos artefatos originais do 1º bimestre (repositório
[luisgustavoribeirodefreitas/VanTrack](https://github.com/luisgustavoribeirodefreitas/VanTrack))
para mantê-los coerentes com o projeto e o código implementado no **UC-S05 Registrar Embarque**
(com o `<<include>>` **UC-I02 Notificar Responsável** e o fluxo alternativo **A1 — Sem conectividade**).

A revisão atende à demanda **"melhorias em todo o projeto"** descrita na
[seção 8 de `documentos/desenvolvimento/03-arquitetura.md`](../desenvolvimento/03-arquitetura.md#8-pontos-para-a-equipe-decidir).

---

## Resumo das alterações aplicadas

| Ponto (`03-arquitetura.md`) | O que mudou na implementação | Artefatos revisados nesta pasta |
|---|---|---|
| **Ponto 5** | `Presenca.registrarEmbarque` passou a receber o `registroId` (UUID gerado no aparelho) para garantir idempotência na sincronização offline (`RNF-006`). | [`atividade-04/scripts/UC-S05.puml`](atividade-04/scripts/UC-S05.puml), [`atividade-04/01-diagramas-de-sequencia.md`](atividade-04/01-diagramas-de-sequencia.md), [`atividade-03/01-casos-de-uso.md`](atividade-03/01-casos-de-uso.md) |
| **Ponto 6** | `montarMensagem` deixou de ser uma responsabilidade do `NotificacaoService` e passou para a fábrica `Notificacao.deEmbarque(...)` na própria entidade (horário de Brasília UTC-3, evitando entidade anêmica). A entrega ao responsável ocorre por *polling* em `TelaAvisos`. | [`atividade-04/scripts/UC-I02.puml`](atividade-04/scripts/UC-I02.puml), [`atividade-04/01-diagramas-de-sequencia.md`](atividade-04/01-diagramas-de-sequencia.md), [`atividade-03/01-casos-de-uso.md`](atividade-03/01-casos-de-uso.md) |
| **Ponto 10 + VT-65** | No **Mapa de Dados**, a coluna `sincronizado` foi removida da entidade `Embarque` (no servidor todo embarque salvo já está sincronizado; a fila fica no aparelho em `ArmazenamentoLocal`), foi adicionado `registro_id` (UUID) em `Embarque`, e foi incluída a entidade de apoio `Sessão` (`token`, `papel`, usuário) usada pelo login simplificado. | [`atividade-01/03-mapa-dados.md`](atividade-01/03-mapa-dados.md) |
| **Ponto 18 + Ponto 22** | A regra **RN-012** (*Motorista ativo da van*) foi incluída na cadeia completa do **UC-S05** (`validarMotoristaAtivo` no registro e na listagem, e `buscarVinculoAtivoDoMotorista` no `GET /rotas/hoje` retornando `403` sem vínculo). | [`atividade-02/01-regras-negocio.md`](atividade-02/01-regras-negocio.md), [`atividade-02/02-requisitos-funcionais.md`](atividade-02/02-requisitos-funcionais.md), [`atividade-02/04-rastreabilidade.md`](atividade-02/04-rastreabilidade.md), [`atividade-03/01-casos-de-uso.md`](atividade-03/01-casos-de-uso.md), [`atividade-04/scripts/UC-S05.puml`](atividade-04/scripts/UC-S05.puml) |
| **RNF-003 no UC-S05 / UC-I02** | A faixa âmbar `"Sem conexão"` (`FaixaSemConexao`) aparece tanto em `TelaRotaDoDia` quanto em `TelaAvisos`, refletindo a perda de conectividade também no módulo de embarque e avisos. | [`atividade-02/04-rastreabilidade.md`](atividade-02/04-rastreabilidade.md), [`atividade-03/01-casos-de-uso.md`](atividade-03/01-casos-de-uso.md), [`atividade-04/scripts/UC-R02.puml`](atividade-04/scripts/UC-R02.puml) |

---

## Estrutura dos artefatos revisados

- [`atividade-01/03-mapa-dados.md`](atividade-01/03-mapa-dados.md) — Mapa de dados revisado (`registro_id`, remoção de `sincronizado` em `Embarque`, inclusão de `Sessão`).
- [`atividade-02/01-regras-negocio.md`](atividade-02/01-regras-negocio.md) — Regras de negócio com **RN-012** ligada ao **RF-009** e **UC-S05**.
- [`atividade-02/02-requisitos-funcionais.md`](atividade-02/02-requisitos-funcionais.md) — Requisitos funcionais com **RF-009** e **RF-011** atualizados.
- [`atividade-02/04-rastreabilidade.md`](atividade-02/04-rastreabilidade.md) — Matriz completa com **RN-012**, **RNF-003** e **RNF-006** atualizados para `UC-S05` / `UC-R02` / `UC-I02`.
- [`atividade-03/01-casos-de-uso.md`](atividade-03/01-casos-de-uso.md) — Casos de uso com **UC-S05**, **UC-R02** e **UC-I02** alinhados ao implementado.
- [`atividade-04/01-diagramas-de-sequencia.md`](atividade-04/01-diagramas-de-sequencia.md) — Diagramas de sequência revisados (`UC-S05`, `UC-I02` e `UC-R02`), scripts `.puml` e imagens `.png`/`.svg`.
