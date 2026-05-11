# Setup do Firebase Cloud Messaging (FCM)

O app usa FCM para push notifications no Android. O arquivo
`android/app/google-services.json` é gerado pelo console do Firebase
e **não é versionado** (entrada no `.gitignore`).

## Como obter o `google-services.json`

1. Acesse o [console do Firebase](https://console.firebase.google.com/) com a conta do projeto
   `omniconnect-fitness`.
2. Selecione **Configurações do projeto** → aba **Geral**.
3. Em **Seus apps**, escolha o app Android (`com.example.omniconnect_fitness`).
4. Baixe o arquivo `google-services.json`.
5. Coloque o arquivo em `frontend/android/app/google-services.json`.

## Template

Há um arquivo `frontend/android/app/google-services.json.example` com a
estrutura esperada — campos sensíveis (`project_number`, `project_id`,
`api_key`, `mobilesdk_app_id`) marcados como `REPLACE_ME`.

Se você só quer rodar o app **sem** push notifications (Web ou
desenvolvimento backend-only), pode copiar o `.example` para o nome real
e ignorar o aviso de FCM no boot — o `NotificationService` já trata o
erro de inicialização (ver `lib/main.dart`).

## Sobre a API key

A API key Android do FCM é considerada sensível por permitir abuso de
quota se não restringida. Por isso:

- **Restrição** — no console do Firebase / Google Cloud, restringir a
  chave por **package name + SHA1 fingerprint** do app.
- **Rotação** — só rotacionar a chave depois de avisar o squad, pois
  invalida builds em circulação que usam a chave antiga.
