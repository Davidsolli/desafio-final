# OmniConnect Fitness — Backend

> API REST com IA (Padrão de Arquitetura em Camadas - Spring Boot Style)

Este projeto é a base do backend para o aplicativo OmniConnect Fitness. Ele foi estruturado utilizando o framework FastAPI em conjunto com LangChain para a Inteligência Artificial. Para manter a organização e escalabilidade com a equipe, adotamos uma estrutura de pastas semelhante à do Spring Boot (Java), adaptada para o ecossistema Python.

---

## 🚀 Como Configurar e Rodar o Projeto

Siga o passo a passo abaixo para rodar o backend localmente na sua máquina.

### 1. Pré-requisitos
- **Python 3.11** ou superior
- Recomendado o uso de algum terminal bash/zsh.

### 2. Criar e Ativar o Ambiente Virtual
O ambiente virtual isola as bibliotecas do projeto para não conflitar com a sua máquina:

No terminal, estando na raiz da pasta `backend`:

```bash
# Cria o ambiente virtual
python3 -m venv .venv

# Ativa o ambiente virtual (Linux/macOS)
source .venv/bin/activate
```
*(Se estiver usando Windows, o comando de ativação é: `.venv\Scripts\activate`)*

### 4. Rodar o Servidor (Via Docker)
Configuramos tudo para rodar através de containers Docker. Isso sobe tanto a **API (FastAPI)** quanto o **Banco de Dados (PostgreSQL + pgvector)** juntos de forma orquestrada sem precisar sujar a sua máquina.

Para criar as imagens e inicializar, basta rodar uma única vez:

```bash
docker compose up --build
```
*(Nas próximas vezes, basta usar apenas `docker compose up`)*

Os volumes locais foram configurados. Se você editar o código do backend e salvar, não é necessário reinstalar o container! A API recarregará automaticamente devido ao Live Reload do volume espelhado com o Host local.

O servidor será iniciado. Você pode testar se está tudo funcionando acessando:
- **Health Check API:** [http://localhost:8000/](http://localhost:8000/)
- **Documentação Interativa (Swagger/OpenAPI):** [http://localhost:8000/docs](http://localhost:8000/docs)

---

## 📁 Arquitetura do Projeto

Implementamos uma separação clara de responsabilidades:

```text
backend/
├── main.py
└── app/
    ├── controllers/  → Camada de API (Endpoints/Rotas). Recebe os requests HTTP e devolve responses.
    ├── dtos/         → Data Transfer Objects (Pydantic). Responsáveis pela validação do que entra e sai da API.
    ├── services/     → Camada da Regra de Negócio. É aqui que você programa a lógica de verdade do sistema.
    ├── repositories/ → Camada de Banco de Dados. Único lugar que faz selects/inserts/updates via ORM.
    ├── models/       → Representam as Tabelas/Entidades do Banco de Dados.
    ├── config/       → Variáveis de ambiente (.env), configs de Segurança e JWT.
    ├── ai/           → Arquivos focados em Inteligência Artificial (Agentes, Skills e RAG).
    └── integrations/ → Integrações terceirizadas (Webhook Meta WhatsApp Cloud API e Firebase FCM).
```

### 🔁 Fluxo de Execução Padrão:
O frontend (aplicativo / whatsapp) chama o nosso **Controller** → Validação via **DTO** → Controller chama a lógica no **Service** → Service usa o **Repository** se precisar acessar ou mudar algum **Model** do Banco de Dados.

---

*Alpha EdTech · Turma Aurora · OmniConnect Fitness*
