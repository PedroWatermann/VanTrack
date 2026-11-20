# VanTrack — App (Flutter)

App do motorista (UC-R02) e do responsável (UC-I02).

## Como rodar

```bash
cd app
flutter pub get
```

### Com o servidor de verdade

Suba antes o banco e o servidor (passo a passo no [README da raiz](../README.md)). Com o
servidor respondendo em `http://localhost:8080/`:

```bash
flutter run -d chrome                                       # no navegador
flutter run --dart-define=API_URL=http://10.0.2.2:8080     # no emulador Android
```

No emulador Android, `10.0.2.2` é o endereço do computador visto de dentro do emulador.
Em um celular de verdade, use o IP do computador na rede (ex.: `http://192.168.0.10:8080`).

### Com os dados simulados (sem servidor)

```bash
flutter run -d chrome --dart-define=USE_MOCK=true
```

Os dados simulados (`lib/compartilhado/mock/dados_mock.dart`) respondem no mesmo formato do
servidor, com os usuários e alunos do `supabase/seed.sql`. Os embarques ficam guardados só
enquanto o app está aberto.

### Testes

```bash
flutter test
```

### Opções

| Opção | Para que serve | Padrão |
|---|---|---|
| `--dart-define=API_URL=...` | Endereço do servidor | `http://localhost:8080` |
| `--dart-define=USE_MOCK=true` | Usa os dados simulados, sem servidor | `false` |

Para trocar de usuário, recarregue a página (no navegador) ou feche e abra o app: o login
fica guardado só enquanto o app está aberto.

## Pastas (lib/)

| Pasta | O que tem | Quem cuida |
|---|---|---|
| `compartilhado/` | conexão com o servidor, usuário logado, cores | Membro D |
| `login/` | tela de entrada | Membro D |
| `embarque/` | tela "Rota do dia" e registro do embarque | Membro D (online) e Membro E (offline) |
| `avisos/` | tela "Avisos" do responsável | Membro C |

Cada módulo é dividido em `apresentacao/` (telas), `aplicacao/` (o que coordena o caso de uso),
`dominio/` (dados e regras) e `infraestrutura/` (servidor, GPS, armazenamento),
como no documento `03-arquitetura.md`.
