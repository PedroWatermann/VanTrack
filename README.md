# VanTrack

App de acompanhamento de vans escolares, trabalho da disciplina Análise e Projeto de
Software (UEM). Esta entrega implementa o caso de uso **UC-S05 Registrar Embarque**, com o
`<<include>>` **UC-I02 Notificar Responsável** e o fluxo alternativo **A1 (sem conexão)**.

| Pasta | O que tem | Como rodar |
|---|---|---|
| `backend/` | API REST em Dart Frog | [backend/README.md](backend/README.md) |
| `app/` | App Flutter (motorista e responsável) | [app/README.md](app/README.md) |
| `supabase/` | Migrations e dados de teste (seed) do PostgreSQL | rodam pelo reset do backend |
| `documentos/desenvolvimento/` | Arquitetura e diagrama de classes, testes de aceitação, roteiro da demo e checklist da entrega | [03-arquitetura.md](documentos/desenvolvimento/03-arquitetura.md) · [05-testes-aceitacao.md](documentos/desenvolvimento/05-testes-aceitacao.md) · [06-roteiro-demo.md](documentos/desenvolvimento/06-roteiro-demo.md) · [07-checklist-entrega.md](documentos/desenvolvimento/07-checklist-entrega.md) |
| `documentos/revisao-1-bimestre/` | Artefatos do 1º bimestre revisados conforme a implementação (E-07 / VT-65) | [revisao-1-bimestre/README.md](documentos/revisao-1-bimestre/README.md) |

O Supabase é usado **só como banco PostgreSQL**: o app fala apenas com a API, e a API fala
com o banco.

## Equipe

Cada membro preenche a própria linha com o nome e o RA, em um commit seu, para ficar
registrado no histórico do repositório.

| Membro | Parte no UC-S05 | Nome | RA |
|---|---|---|---|
| A | Backend base, seed e integração | | |
| B | Backend do embarque | | |
| C | Notificação ponta a ponta (UC-I02) | | |
| D | App do motorista (UC-R02) | | |
| E | Modo offline e sincronização (A1, RNF-006) | | |

## Subir tudo do zero

### 1. Pré-requisitos

- Flutter 3.47 ou mais novo, que traz o Dart 3.13 (`flutter --version`). Se for mais
  antigo, atualize com `flutter upgrade`.
- Dart Frog CLI:

  ```bash
  dart pub global activate dart_frog_cli
  ```

- Um projeto no Supabase (gratuito). Veja a seção [Bancos](#bancos) para saber qual usar.

### 2. Banco e backend

Dentro de `backend/`:

1. Copie `.env.example` para `.env` e cole a string de conexão do Supabase (modo
   **Session pooler**) em `DATABASE_URL`. O `.env` nunca vai para o git.
2. Instale as dependências, recrie o banco e suba o servidor:

   ```bash
   dart pub get
   ```

   ```bash
   dart run bin/reset_db.dart
   ```

   ```bash
   dart_frog dev
   ```

3. Confira: `http://localhost:8080/` responde `{"status":"ok"}`.

Detalhes e teste manual das rotas: [backend/README.md](backend/README.md).

### 3. App

Com o servidor no ar, dentro de `app/`:

```bash
flutter pub get
```

```bash
flutter run -d chrome
```

No emulador Android, o servidor fica em outro endereço:

```bash
flutter run --dart-define=API_URL=http://10.0.2.2:8080
```

Para mostrar o app sem servidor, use `--dart-define=USE_MOCK=true`. Detalhes em
[app/README.md](app/README.md).

O modo offline já vem ligado: sem conexão, o app mostra a faixa "Sem conexão", o embarque
fica como "Pendente de sincronização" e é enviado sozinho quando a conexão volta
(fluxo A1 do UC-S05, RNF-006).

### 4. Usuários do seed

O login é só a escolha de um usuário da lista.

| Usuário | Papel | Para testar |
|---|---|---|
| João Pereira | motorista | motorista ativo da van ABC-1D23: abre a rota de hoje e registra embarques |
| Marcos Oliveira | motorista | sem vínculo com a van: acesso negado (RN-012) |
| Maria Souza e Paulo Souza | responsáveis | os dois recebem o aviso da Ana Souza |
| Fernanda Reis | responsável | da Beatriz Reis; não vê os avisos da Ana (RN-002) |
| Ricardo Alves | responsável | do Bruno Alves, que está ausente hoje |

Rota de hoje: Ana Souza, Beatriz Reis e Carlos Lima confirmados, nessa ordem; Bruno Alves
ausente. Carlos é maior de idade e não tem responsável, então o embarque dele não gera aviso.

## Bancos

| Projeto Supabase | Quem usa | Quando rodar o reset |
|---|---|---|
| Um por membro | quem está desenvolvendo | quando quiser; só apaga os dados dele |
| **vantrack-demo** (compartilhado) | integração, testes de aceitação e apresentação | só combinando com o grupo: o reset apaga tudo |

A string de conexão do projeto da demo é passada entre os membros por mensagem privada,
nunca pelo git. Antes de cada rodada de testes de aceitação e antes da apresentação, rode
`dart run bin/reset_db.dart` apontando para ele, para começar sempre do seed.

## Fluxo de trabalho

- Cada task do Jira (projeto VT) vira uma branch `task-<nº>-<descricao>`, criada **sempre a
  partir da `desenvolvimento`**.
- Os commits começam com a chave da task (ex.: `VT-24 Cria o projeto...`).
- Cada branch vira um PR para a `desenvolvimento`, revisado por outro membro.
- Para a entrega, a `desenvolvimento` vai para a `master` em um PR, depois dos testes de
  aceitação.
