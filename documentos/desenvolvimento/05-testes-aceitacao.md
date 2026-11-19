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
| 1 | Motorista ativo abre a rota | UC-S05 passo 1, RN-010 | | | |
| 2 | Toca "Embarcou" no aluno 1 | UC-S05 passos 2 a 4, UC-R02 | | | |
| 3 | Os 2 responsáveis do aluno 1 abrem "Avisos" | UC-I02 fluxo principal | | | |
| 4 | Responsável do aluno 2 abre "Avisos" | RN-002 | | | |
| 5 | Embarque do aluno 3 | UC-I02 A1 | | | |
| 6 | Tentar embarcar o aluno 1 de novo | 409 | | | |
| 7 | Motorista sem vínculo tenta abrir a rota | RN-012 | | | |
| 8 | Sem conexão, embarcar o aluno 2 | UC-S05 A1, UC-R02 E1 | | | |
| 9 | Fechar e abrir o app ainda sem conexão | RNF-006 | | | |
| 10 | Reconectar | UC-S05 A1, RNF-006 | | | |

**Execução:** data ____ · commit da `desenvolvimento` testado ____ · banco: vantrack-demo
· app: Web (Chrome) / Android (emulador).

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

**Esperado pelo backlog:** acesso negado (RN-012).

**Comportamento atual:** a tela mostra "Você não tem rota para hoje.", sem lista de alunos.
Isso acontece porque o `GET /rotas/hoje` devolve `404` para motorista sem vínculo (decisão
dos pontos 8 e 9 do `03-arquitetura.md`), e o app nem chega a pedir a lista. O acesso
continua negado. O `403` da RN-012 se confere pela API: `GET /rotas/1/alunos` com o token
do Marcos deve devolver `403` e "Você não é o motorista ativo desta van.".

**Ponto para a equipe:** considerar o teste aprovado com essa mensagem ou trocar o
`/rotas/hoje` para devolver `403` ao motorista sem vínculo (vira Bug).

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
