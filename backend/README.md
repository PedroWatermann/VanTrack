# VanTrack — Backend (Dart Frog)

API REST do UC-S05 Registrar Embarque. O Supabase é usado **só como banco PostgreSQL**:
o backend conecta direto no Postgres com o pacote `postgres`, e o app só fala com esta API.
Arquitetura e diagrama de classes: `documentos/desenvolvimento/03-arquitetura.md`.

## 1. Instalar

```bash
dart pub global activate dart_frog_cli
```

No Windows, se o comando `dart_frog` não for encontrado, adicione
`%LOCALAPPDATA%\Pub\Cache\bin` ao PATH e **feche e abra o VS Code inteiro** (os terminais
herdam o PATH de quando ele foi aberto). Sem mexer no PATH também funciona:
`dart pub global run dart_frog_cli:dart_frog dev`.

Dentro de `backend/`:

```bash
dart pub get
```

## 2. Configurar o `.env`

1. Crie um projeto gratuito no Supabase **só seu** (cada membro usa o próprio banco, para não
   apagar os dados dos outros ao rodar o reset).
2. Copie `.env.example` para `.env`.
3. Em Supabase → Project Settings → Database → Connection string, escolha o modo
   **Session pooler**, copie a URL para `DATABASE_URL` e troque `[YOUR-PASSWORD]` pela senha.
   Caracteres especiais da senha precisam de URL encoding (ex.: `@` → `%40`).

O `.env` está no `.gitignore`. **Nunca commite o `.env`.**

## 3. Resetar o banco

```bash
dart run bin/reset_db.dart
```

Apaga as tabelas do schema `public`, roda `../supabase/migrations/*.sql` em ordem de nome e
depois `../supabase/seed.sql`, em uma única transação (se algo falhar, nada muda). A rota
do seed é sempre a de hoje (horário de Brasília). **Rode de novo sempre que uma migration
mudar.**

Ao escrever um `.sql`: o pacote `postgres` do Dart não aceita mais de um `SELECT` solto no
mesmo arquivo. Use comandos sem resultado ou um bloco `DO $$ ... $$` (veja o `seed.sql`).

## 4. Subir o servidor

```bash
dart_frog dev
```

Sobe em `http://localhost:8080` (`GET /` responde `{"status":"ok"}`). No emulador Android o
app usa `http://10.0.2.2:8080`.

## 5. Testar

```bash
dart test -x integracao
```

Testes unitários, sem banco. Para incluir os testes de integração dos repositórios (que
leem o seu banco do Supabase), rode o reset antes e depois `dart test`.

### Teste manual com o servidor no ar

Rotas públicas: `GET /` (verificação), `GET /usuarios` e `POST /login`. As demais exigem o
header `Authorization: Bearer <token>`; sem ele, `401`:

| Rota | Quem | Respostas |
|---|---|---|
| `GET /rotas/hoje` | motorista | 200 `{rotaId, trajeto, horarioPrevisto, placa}`; 403 se não for motorista; 404 sem rota hoje (inclui o motorista sem vínculo) |
| `GET /rotas/{rotaId}/alunos` | motorista ativo da van | 200 com os alunos na ordem (sem os ausentes); 403 (RN-012); 404 |
| `POST /rotas/{rotaId}/embarques` | motorista ativo da van | 201, 200 (mesmo `registroId`), 400, 403, 404, 409 |
| `GET /alunos` | responsável | 200 `[{alunoId, nome}]` com os alunos dele (RN-002); 403 se não for responsável |

```bash
curl http://localhost:8080/usuarios
```

```bash
curl -X POST http://localhost:8080/login -H "Content-Type: application/json" -d "{\"id\": 1, \"papel\": \"MOTORISTA\"}"
```

O login devolve `{"token": "..."}`. Com o token do João Pereira (motorista 1):

```bash
curl http://localhost:8080/rotas/hoje -H "Authorization: Bearer COLE_O_TOKEN"
```

```bash
curl http://localhost:8080/rotas/1/alunos -H "Authorization: Bearer COLE_O_TOKEN"
```

Esperado: a rota 1 e os alunos Ana, Beatriz e Carlos, nessa ordem (Bruno está ausente).
Com o token do Marcos Oliveira (motorista 2, sem vínculo): `404` no `/rotas/hoje` e `403` no
`/rotas/1/alunos`.

No Postman: `POST /login` com o corpo em Body → raw → JSON e, nas outras rotas,
Authorization → Bearer Token com o token recebido.

## Dados do seed

| Quem | id | Papel | Observação |
|---|---|---|---|
| João Pereira | 1 | MOTORISTA | ativo na van ABC-1D23 |
| Marcos Oliveira | 2 | MOTORISTA | sem vínculo (RN-012) |
| Maria Souza / Paulo Souza | 1 / 2 | RESPONSAVEL | responsáveis da Ana |
| Fernanda Reis | 3 | RESPONSAVEL | responsável da Beatriz |
| Ricardo Alves | 4 | RESPONSAVEL | responsável do Bruno |

Rota `1` (hoje, ida, 06:30): Ana Souza (1), Beatriz Reis (2) e Carlos Lima (3, maior, sem
responsável) confirmados; Bruno Alves (4) ausente.

## Organização (por módulo, com as camadas dentro)

```
routes/                      só leem a requisição e chamam o Controller
  _middleware.dart           CORS, autenticação e montagem dos objetos (vale para todas)
lib/
  compartilhado/
    apresentacao/            CORS (RNF-004), AutenticacaoMiddleware, AutenticacaoController,
                             UsuarioLogado
    aplicacao/               AutenticacaoService (login simplificado)
    dominio/                 Sessao, HorarioBrasilia, contratos SessaoRepository e
                             UsuarioRepository
    infraestrutura/          ConexaoBanco (único pool), leitura do .env,
                             SessaoRepositoryPostgres
  cadastro/
    dominio/                 Usuario, Papel, Motorista, Responsavel, Aluno, Van,
                             VinculoMotoristaVan, contrato VinculoRepository
    infraestrutura/          VinculoRepositoryPostgres
  rota/
    dominio/                 Rota, Trajeto, PontoParada, Localizacao, Presenca,
                             SituacaoPresenca, Embarque, exceções, contratos
                             PresencaRepository e RotaRepository
    infraestrutura/          PresencaRepositoryPostgres, RotaRepositoryPostgres
  notificacao/
    dominio/                 Notificacao, contrato NotificacaoRepository
    aplicacao/               contrato NotificacaoService e NotificacaoServiceVazio
    infraestrutura/          NotificacaoRepositoryPostgres
bin/reset_db.dart            reseta o banco
```

O diagrama de classes e as camadas estão em `documentos/desenvolvimento/03-arquitetura.md`.

O domínio não importa Dart Frog nem `postgres`. Os repositórios recebem uma função que
devolve a `ConexaoBanco` (sempre o mesmo pool), como o login faz no `routes/_middleware.dart`:
`PresencaRepositoryPostgres(() => ConexaoBanco.abrir(lerDatabaseUrl()))`.
