# Testes de aceitação — UC-S05 Registrar Embarque

Execução dos 10 testes da seção 7 do backlog (`01-backlog-uc-s05.md`), task **VT-63
(A-11)**. Cada falha vira um **Bug** no Jira, com branch própria, e o número do bug é
anotado na tabela de resultados.

Os testes formam um roteiro único: cada um parte do estado que o anterior deixou. Rode na
ordem, do 1 ao 10, depois de um reset do banco.

---

## Resultados

Preencha durante a execução: **Passou**, **Falhou** ou **Bloqueado** (dependência não
mergeada), o número do bug e quem testou.

| # | Cenário | Fluxo / regra | Resultado | Bug | Quem testou |
|---|---|---|---|---|---|
| 1 | Motorista ativo abre a rota | UC-S05 passo 1, RN-010 | Passou | | Membro A |
| 2 | Toca "Embarcou" no aluno 1 | UC-S05 passos 2 a 4, UC-R02 | Passou | | Membro A |
| 3 | Os 2 responsáveis do aluno 1 abrem "Avisos" | UC-I02 fluxo principal | Passou | | Membro A |
| 4 | Responsável do aluno 2 abre "Avisos" | RN-002 | Passou | | Membro A |
| 5 | Embarque do aluno 3 | UC-I02 A1 | Passou | (ver bug A) | Membro A |
| 6 | Tentar embarcar o aluno 1 de novo | 409 | Passou | | Membro A |
| 7 | Motorista sem vínculo tenta abrir a rota | RN-012 | Passou | | Membro A |
| 8 | Sem conexão, embarcar o aluno 2 | UC-S05 A1, UC-R02 E1 | Passou | | Membro A |
| 9 | Fechar e abrir o app ainda sem conexão | RNF-006 | Falhou | bug B | Membro A |
| 10 | Reconectar | UC-S05 A1, RNF-006 | Falhou | bug A | Membro A |

Bugs A, B e C: ver [Bugs encontrados](#bugs-encontrados). Troque a letra pelo número do Jira
quando forem criados.

**Execução:** 24/11/2026, das 21:10 às 21:22 · commit da `desenvolvimento` testado `32361cc`
· banco: **projeto Supabase de desenvolvimento do Membro A** (não o vantrack-demo), com o
reset aplicado antes · backend com `dart_frog dev` · app: Web (build de produção no
Chrome). O Android não foi testado.

### O que se viu em cada teste (24/11)

| # | Observado |
|---|---|
| 1 | "Rota do dia · Ida · 06:30", Van ABC-1D23, "0 de 3 na van". Ana em "Próxima parada", Beatriz e Carlos em "Depois". Bruno não aparece. |
| 2 | Toque às 21:12, sem confirmação. Ana em "Na van" com check verde e "Embarcou às 21:12". Beatriz vira a próxima parada; "1 de 3 na van". |
| 3 | Maria e Paulo veem o card "Na van desde 21:12" e o aviso "Ana Souza embarcou na van às 21:12." (com o ponto de não lido para o Paulo). |
| 4 | Fernanda vê só o card da Beatriz, "Aguardando embarque", e "Nenhum aviso hoje. Você será avisado quando o aluno embarcar." |
| 5 | Embarque do Carlos gravado (201); nenhum responsável recebeu aviso dele (`GET /notificacoes` dos 4). O servidor levou 5,1 s para responder, o app desistiu pelo limite de 5 s e mostrou o Carlos como pendente: ver bug A. |
| 6 | Feito com uma segunda aba aberta antes do embarque. O servidor respondeu 409, continua havendo um único embarque da Ana, e o rodapé mostrou "Ana Souza já embarcou.". |
| 7 | Tela inteira "Você não é o motorista ativo desta van." (corrigido pela VT-72). |
| 8 | Backend parado. Toque às 21:18:20 aceito na hora: Beatriz em "Na van" com a nuvem âmbar e "Pendente de sincronização", faixa "Sem conexão…" e "Todos os alunos embarcaram". |
| 9 | A fila sobreviveu a fechar e abrir a aba (registro da Beatriz guardado, com a hora do toque). Mas o app abre no login, que precisa do servidor ("Não foi possível carregar os usuários. Tente de novo."), então o motorista não vê o pendente: ver bug B. |
| 10 | Backend de volta às 21:19:14. Em mais de 1,5 min o app não tentou sincronizar, nem depois do login e de a rota carregar: ver bug A. Enviando o mesmo registro da fila pela API (21:21:41), o servidor gravou a hora do toque (21:18:20) e a tela da Fernanda mostrou sozinha, em menos de 10 s, "Beatriz Reis embarcou na van às 21:18.". |

## Bugs encontrados

| Bug | Testes | Dono | Problema |
|---|---|---|---|
| **A** | 5, 10 | Membro E | **O app fica "sem conexão" para sempre depois de uma falha.** Um timeout ou erro de rede chama `registrarFalhaDeRede()`; o monitor só volta a online com um evento do `connectivity_plus` ou depois de um envio que deu certo. Mas o `sincronizar()` e o `registrarEmbarque()` não tentam nada enquanto está offline. Na Web (e no Android com o Wi-Fi ligado e o servidor fora do ar) o evento de rede não chega, então nada mais é enviado e o RNF-006 (até 5 min) não é cumprido. Sugestão: deixar a sincronização periódica tentar mesmo offline, ou marcar online quando qualquer chamada à API der certo. |
| **B** | 9 | Membro D | **Sem login salvo, abrir o app sem conexão não mostra os pendentes.** O login não fica guardado e a lista de usuários vem do servidor. Sugestão: guardar a sessão (usuário e token) no aparelho e abrir direto na "Rota do dia". |
| **C** | encontrado no 7 | Membro E | **A fila offline é do aparelho, não do motorista, e pode perder embarques.** Ao abrir o app, ele sincroniza a fila com o token de quem estiver logado: sem login (401) ou com outro usuário. Com o Marcos (sem vínculo), o servidor respondeu 403 para o registro e o app apagou o embarque pendente do João da fila. Só não houve perda porque esse embarque já estava no servidor. Sugestão: guardar na fila quem registrou e só sincronizar com a sessão desse motorista; nunca apagar por 401/403. |

**Observações (não são bugs do código):**

- O banco usado fica em us-east-1, e cada consulta levou de 0,6 s a 5 s. Com o limite de 5 s
  do app, um servidor lento parece "sem conexão". Para a demo, crie o vantrack-demo na
  região de São Paulo (sa-east-1).
- Depois de recarregar a rota, quem já embarcou aparece só com "Embarcou", sem a hora: o
  `GET /rotas/{rotaId}/alunos` não devolve a hora do embarque.

---

## Situação antes da execução (18/11)

O que já estava mergeado na `desenvolvimento` quando este roteiro foi escrito:

| Testes | Situação |
|---|---|
| 1, 2, 6, 7, 8, 9 | Prontos: dá para fazer tudo pelo app. |
| 3, 4, 5, 10 | O servidor já gera os avisos (VT-40, VT-44, VT-45, VT-70), mas a tela "Avisos" do app ainda é provisória (VT-46 e VT-47 abertas). Até elas entrarem, confira os avisos pela API, como descrito em cada teste. Depois que entrarem, refaça a conferência pela tela. |

---

## Preparação

1. **Banco:** com o `backend/.env` apontando para o projeto **vantrack-demo**, recrie o
   banco a partir do seed. Isso apaga tudo, então combine com o grupo antes.

   ```bash
   dart run bin/reset_db.dart
   ```

2. **Backend:** dentro de `backend/`, suba o servidor e confira que
   `http://localhost:8080/` responde `{"status":"ok"}`.

   ```bash
   dart_frog dev
   ```

3. **App:** dentro de `app/`, abra o app no Chrome. Use **duas janelas** (uma comum e uma
   anônima) para ter o motorista e o responsável logados ao mesmo tempo.

   ```bash
   flutter run -d chrome
   ```

4. **Conferência pela API** (testes 3, 4, 5 e 10 enquanto a tela "Avisos" não está
   pronta): no Postman, faça `POST /login` com o corpo `{"id": <id>, "papel": "RESPONSAVEL"}`
   e use o token recebido em Authorization → Bearer Token no `GET /notificacoes`. Detalhes
   no `backend/README.md`.
5. **Relógio:** anote a hora de cada toque em "Embarcou". Os testes 3 e 10 conferem esse
   horário nas mensagens.

Usuários do seed:

| Usuário | id | Papel | Observação |
|---|---|---|---|
| João Pereira | 1 | MOTORISTA | ativo na van ABC-1D23 |
| Marcos Oliveira | 2 | MOTORISTA | sem vínculo com van |
| Maria Souza / Paulo Souza | 1 / 2 | RESPONSAVEL | responsáveis da Ana (aluno 1) |
| Fernanda Reis | 3 | RESPONSAVEL | responsável da Beatriz (aluno 2) |
| Ricardo Alves | 4 | RESPONSAVEL | responsável do Bruno (aluno 4, ausente) |

Carlos Lima (aluno 3) é maior de idade e não tem responsável.

---

## Roteiro

### Teste 1 — Motorista ativo abre a rota

1. No login, toque em **João Pereira**.

**Esperado:** a tela "Rota do dia" mostra Ida, 06:30 e a van ABC-1D23. Os alunos aparecem
na ordem Ana Souza, Beatriz Reis e Carlos Lima, com a Ana em "Próxima parada". **Bruno
Alves não aparece** (ausente, exceção da RN-010).

### Teste 2 — Toca "Embarcou" no aluno 1

1. Na "Rota do dia" do João, toque uma vez em **Embarcou** na Ana Souza e anote a hora.

**Esperado:** nenhuma confirmação extra (um toque, RNF-005). A Ana vai na hora para "Na
van", com check verde e "Embarcou às HH:MM". A Beatriz passa a ser a "Próxima parada".

### Teste 3 — Os 2 responsáveis do aluno 1 veem o aviso

1. Na outra janela, entre como **Maria Souza** e abra "Avisos". Depois, faça o mesmo com
   **Paulo Souza**.

**Esperado:** os dois veem o aviso "Ana Souza embarcou na van às HH:MM.", com a hora do
teste 2, e o card da Ana como "Na van desde HH:MM".

**Enquanto a tela "Avisos" não está pronta:** faça `GET /notificacoes` com o token da Maria
e depois com o do Paulo. Os dois devem receber esse aviso.

### Teste 4 — Responsável do aluno 2 não vê o aviso do aluno 1

1. Entre como **Fernanda Reis** e abra "Avisos".

**Esperado:** nenhum aviso da Ana (RN-002). O card da Beatriz aparece como "Aguardando
embarque".

**Enquanto a tela "Avisos" não está pronta:** o `GET /notificacoes` da Fernanda devolve
`[]` e o `GET /alunos` dela devolve só a Beatriz Reis.

### Teste 5 — Embarque do aluno 3 (sem responsável)

1. Na "Rota do dia" do João, toque em **Embarcou** no Carlos Lima.

**Esperado:** o Carlos vai para "Na van" (embarque salvo) e **nenhum aviso é criado**
(fluxo A1 do UC-I02).

**Como conferir:** os `GET /notificacoes` da Maria, do Paulo, da Fernanda e do Ricardo não
têm nenhum aviso do Carlos. Pelo SQL Editor do Supabase:

```sql
select count(*) from notificacao n join aluno a on a.id = n.aluno_id where a.nome = 'Carlos Lima';
```

O resultado deve ser `0`.

### Teste 6 — Tentar embarcar o aluno 1 de novo

Depois do teste 2, a Ana não tem mais o botão. Para reproduzir dois toques para a mesma
aluna:

1. Abra a "Rota do dia" do João em **duas abas**, antes de qualquer embarque. Se a Ana já
   embarcou, rode o reset e refaça os testes 1 e 2 assim: abra as duas abas, embarque a
   Ana na primeira e, **sem recarregar**, toque em **Embarcou** na Ana na segunda aba.

**Esperado:** o aviso rápido no rodapé "Ana Souza já embarcou." (409). Nada é duplicado:
continua existindo um único embarque da Ana.

**Pela API (alternativa):** faça `POST /rotas/1/embarques` com o token do João, `alunoId` 1
e um `registroId` novo. A resposta deve ser `409`.

### Teste 7 — Motorista sem vínculo tenta abrir a rota

1. Saia e entre como **Marcos Oliveira**.

**Esperado:** acesso negado (RN-012). A tela inteira mostra "Você não é o motorista ativo
desta van.", sem lista de alunos.

O `GET /rotas/hoje` devolve `403` para o motorista sem vínculo ativo com van, e o app
mostra a mensagem do 403. Antes ele devolvia `404` e a tela dizia "Você não tem rota para
hoje."; a equipe decidiu tratar isso como Bug (ponto 22 do `03-arquitetura.md`).

**Pela API:** com o token do Marcos, `GET /rotas/hoje` e `GET /rotas/1/alunos` devolvem
`403`.

### Teste 8 — Sem conexão, embarcar o aluno 2

1. Com o João na "Rota do dia", corte a conexão:
   - no **Chrome**, pare o backend (Ctrl+C no terminal do `dart_frog dev`). O app trata
     falha de rede como sem conexão;
   - no **Android**, ative o modo avião.
2. Toque em **Embarcou** na Beatriz Reis e anote a hora.

**Esperado:** o toque é aceito na hora, sem travar. A Beatriz vai para "Na van" com a nuvem
riscada âmbar e "Pendente de sincronização". A faixa "Sem conexão. Os embarques serão
enviados quando o sinal voltar." aparece no topo (RNF-003).

### Teste 9 — Fechar e abrir o app ainda sem conexão

1. Ainda sem conexão, feche o app (no Chrome, feche a aba; no Android, encerre o app).
2. Abra de novo e entre como João Pereira, se pedir login.

**Esperado:** a Beatriz continua "Pendente de sincronização" (a fila sobrevive, RNF-006).

### Teste 10 — Reconectar

1. Espere pelo menos 1 minuto desde o toque do teste 8. Assim dá para distinguir a hora do
   toque da hora da sincronização.
2. Volte a conexão (suba o backend de novo com `dart_frog dev`, ou desligue o modo avião).

**Esperado:**

- Em até 5 minutos, a Beatriz troca a nuvem âmbar pelo check verde, sem recarregar a tela,
  e a faixa "Sem conexão" some.
- O horário salvo é o **do toque** (teste 8), não o da reconexão. No SQL Editor:

  ```sql
  select e.data_hora at time zone 'America/Sao_Paulo' from embarque e
    join presenca p on p.id = e.presenca_id join aluno a on a.id = p.aluno_id
   where a.nome = 'Beatriz Reis';
  ```

- A Fernanda Reis recebe "Beatriz Reis embarcou na van às HH:MM." com a hora do toque.
  Enquanto a tela "Avisos" não está pronta, confira pelo `GET /notificacoes` da Fernanda.

---

## Como registrar um bug

Para cada teste que falhar:

1. Crie um **Bug** no Jira (projeto VT), dentro da Story S6, com o título
   `Teste <n> — <o que falhou>`.
2. Na descrição, coloque os passos que levaram ao erro, o resultado esperado (copie deste
   documento) e o que aconteceu, com print se possível.
3. Anote o número do bug na tabela de resultados.
4. O dono do código corrige numa branch `task-<nº>-<descricao>` a partir da
   `desenvolvimento`. Depois do merge, refaça o teste e atualize a tabela.
