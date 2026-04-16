# OmniConnect Fitness — Frontend Flutter

Frontend do OmniConnect Fitness desenvolvido em **Flutter** para Web, iOS e Android.

## 🚀 Começar Rápido

### Pré-requisitos
- [Flutter SDK](https://flutter.dev/docs/get-started/install) (3.0+)
- [Dart SDK](https://dart.dev/get-dart) (incluído no Flutter)

### Setup

```bash
# 1. Instale dependências
flutter pub get

# 2. Rode o app
flutter run -d chrome      # Web
flutter run -d emulator    # Android
flutter run -d macos       # macOS
```

## 📁 Estrutura de Pastas

```
lib/
├── main.dart              ← Ponto de entrada do app
├── routes/                ← Navegação (go_router)
├── screens/
│   ├── auth/              ← Login, Registro, Splash
│   └── student/           ← Telas do aluno
├── widgets/               ← Componentes reutilizáveis
├── services/              ← APIs e HTTP
├── providers/             ← State management
├── models/                ← Modelos de dados
└── theme/                 ← Temas e cores
```

## 🎨 Tema

Tema escuro com cores do protótipo:
- **Primária**: Verde `#3dba5e`
- **Fundo**: `#0a0e1a`

## 📱 Telas Implementadas

- ✅ Splash Screen
- ✅ Login
- ✅ Registro
- ✅ Home (Aluno)
- ⏳ Fichas de Treino
- ⏳ Nutrição
- ⏳ Logbook
- ⏳ Perfil

## 🔧 Desenvolvimento

```bash
flutter run           # Rodar app
flutter clean         # Limpar cache
flutter pub get       # Instalar dependências
```

---

*Alpha EdTech · Turma Aurora · OmniConnect Fitness*
