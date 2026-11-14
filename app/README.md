# VanTrack — App (Flutter)

App do motorista (UC-R02) e do responsável (UC-I02).

## Como rodar

```bash
cd app
flutter pub get
flutter run -d chrome          # no navegador
flutter run                    # no celular ou emulador Android
```

Opções (a partir da VT-49):

- `--dart-define=USE_MOCK=true` — usa dados de mentira, sem precisar do servidor
- `--dart-define=API_URL=http://10.0.2.2:8080` — endereço do servidor no emulador Android
  (no navegador o padrão é `http://localhost:8080`)

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
