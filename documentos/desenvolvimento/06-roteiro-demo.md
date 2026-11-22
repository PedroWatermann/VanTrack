# VanTrack — Roteiro de demonstração e evidências

**Análise e Projeto de Software · UEM**

**Caso de uso** UC-S05 Registrar Embarque · **Entrega** VT-66 · **Duração prevista** 4 minutos

O VanTrack registra o embarque de alunos em uma van escolar. O motorista confirma o
embarque no app, a API grava o evento e o responsável consulta o aviso em sua própria
sessão (UC-I02). Se o motorista estiver sem conexão, o app guarda o registro no aparelho
e o envia quando a rede volta, preservando a hora do toque (fluxo A1).

O aplicativo Flutter acessa a API REST em Dart Frog. O backend usa PostgreSQL no
Supabase para persistir embarques e avisos. O login simplificado do seed identifica
o motorista e o responsável para aplicar as regras de acesso. A estrutura dos módulos
e a rastreabilidade estão na [arquitetura do projeto](03-arquitetura.md).

## Antes de apresentar

- Prepare o [ambiente com a API real e os dados do seed](../../README.md#subir-tudo-do-zero).
  Combine com o grupo a preparação do banco da demo. Confirme que Ana e Beatriz
  aparecem na rota e ainda aguardam embarque.
- Deixe as três sessões abertas: **João Pereira** no Android, em **Rota do dia**,
  e **Maria Souza** (Ana) e **Fernanda Reis** (Beatriz) em duas abas de **Avisos** no Chrome.
- Ensaie desligar e religar a rede só no Android do motorista, com a API em execução.
  Se for apresentar tudo no Chrome, valide no ensaio que a simulação de queda e volta
  da rede do motorista dispara a sincronização.

## Sequência da demonstração

| Tempo | Ação | Resultado esperado | Cenário de aceitação |
|---|---|---|---|
| 0:00–0:30 | Abra **Rota do dia** como João e mostre a próxima parada. | Ana, Beatriz e Carlos aparecem na ordem da rota. Bruno, ausente, fica fora da lista. | 1 · RN-010 |
| 0:30–1:30 | Toque em **Embarcou** na Ana e alterne entre os **Avisos** de Maria e Fernanda. | Com um toque, Ana passa para **Na van**. Maria recebe o aviso com o horário do embarque. Fernanda vê apenas Beatriz, ainda aguardando. | 2–4 · UC-I02, RF-011, RN-002 e RNF-005 |
| 1:30–2:30 | Desligue a rede do motorista, registre o embarque da Beatriz e anote a hora. Confira a aba da Fernanda antes de religar a rede. | O motorista vê **Sem conexão** e **Pendente de sincronização**. Para Fernanda, Beatriz ainda está aguardando. | 8 · RNF-003 e RNF-006 |
| 2:30–4:00 | Após mudar o minuto, religue a rede do motorista e mantenha a tela aberta. Quando sair de **Pendente de sincronização**, mostre o aviso da Fernanda. | O registro é enviado automaticamente. O horário do aviso corresponde ao do toque, mesmo com o envio posterior. | 10 · A1 do UC-S05 e RNF-006 |

## Validação técnica da entrega

A revisão usou a `desenvolvimento` no commit `c572d2b`. Passaram **85 testes
automatizados do app** e **134 testes do backend sem banco**. Uma consulta de
leitura ao PostgreSQL confirmou a tabela de avisos com RLS ativa e as duas chaves
estrangeiras para aluno e responsável.

| Tarefa | Entrega conferida |
|---|---|
| VT-41 | A migration `002_notificacao.sql` cria a tabela de avisos com RLS. O comando de reset aplica as migrations em ordem de nome, antes do seed. |
| VT-42 | O login lista os usuários do seed e atribui um token com o papel correto. As rotas protegidas devolvem `401` para token ausente ou inválido. |
| VT-43 | A entidade monta o aviso com a hora original do embarque em Brasília. O contrato de persistência está separado da implementação Postgres. |
| VT-44 | A aplicação notifica os dois responsáveis da Ana. O cenário do Carlos, sem responsáveis, termina sem criar avisos. |
| VT-45 | O responsável consulta os próprios avisos com filtro `desde` e só pode marcar como lidos os avisos destinados a ele. |
| VT-46 | A tela Avisos mostra os alunos vinculados, inclusive quem aguarda embarque, e associa os avisos ao aluno pelo identificador. |
| VT-47 | Avisos consulta a API a cada 10 segundos, preserva os últimos dados em falha de conexão e marca como lidos os avisos apresentados. |

A organização atual de **Avisos** está nas entregas integradas
[VT-46](https://github.com/PedroWatermann/VanTrack/pull/47) e
[VT-47](https://github.com/PedroWatermann/VanTrack/pull/46). O ponto 19 da
arquitetura descreve a etapa anterior à integração.

Os resultados acima são de testes automatizados e inspeção do banco. O registro
da execução dos dez cenários pela equipe fica na [tabela da VT-63](05-testes-aceitacao.md#resultados),
que ainda está sem resultados preenchidos.

## Evidências do Jira

Capturas do projeto VanTrack em 22/11/2026, durante a **VT Sprint 2**.

| Evidência | Conteúdo |
|---|---|
| [Backlog](evidencias/01-backlog.jpg) | Lista de trabalho e seção de itens fora da sprint. |
| [VT Sprint 2](evidencias/02-sprint.jpg) | Período da sprint e itens atribuídos ao ciclo. |
| [Quadro](evidencias/03-quadro.jpg) | Colunas de acompanhamento e situação das histórias no dia da captura. |
| [Épico VT-13 e histórias](evidencias/04-epico-historias.jpg) | Escopo do UC-S05 e as sete histórias vinculadas. |
