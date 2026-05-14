from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    """Configurações da aplicação."""

    APP_NAME: str = "OmniConnect Fitness"

    # Banco de Dados
    DATABASE_URL: str
    DATABASE_ECHO: bool = False

    # Ambiente
    ENV: str = "development"

    # JWT
    SECRET_KEY: str
    ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 1440

    # Seed/Admin bootstrap
    ADMIN_NAME: str = "Administrador OmniConnect"
    ADMIN_EMAIL: str = "admin@omniconnect.fit"
    ADMIN_PASSWORD: str = "AdminForte123!"

    # ── IA / Groq ────────────────────────────────────────────────
    GROQ_API_KEY: str = ""
    GROQ_MODEL: str = "llama-3.3-70b-versatile"
    GROQ_VISION_MODEL: str = "meta-llama/llama-4-scout-17b-16e-instruct"

    # ── RAG Pipeline ───────────────────────────────────────────────────────
    RAG_EMBEDDING_DIM: int = 384                # HuggingFace all-MiniLM-L6-v2 embedding dimension
    RAG_MIN_RELEVANCE_SCORE: float = 0.70       # RN-06: score mínimo para usar documento
    RAG_ESCALATE_THRESHOLD: float = 0.60        # RN-07: score abaixo disso → escalar
    RAG_TOP_K_DOCS: int = 5                     # Máximo de documentos recuperados
    RAG_MAX_DOC_CONTENT_LENGTH: int = 5000      # Max caracteres por documento
    RAG_LLM_MAX_TOKENS: int = 500               # RN PRD: max tokens na resposta
    RAG_LLM_TEMPERATURE: float = 0.3            # RN PRD: temperatura baixa para consistência
    RAG_HISTORY_MAX_TOKENS: int = 80            # RN-05: máximo de tokens do histórico

    # ── RAG Melhorias ──────────────────────────────────────────────────────
    RAG_HYBRID_SEARCH: bool = True              # BM25 (PostgreSQL FTS) + vetorial com RRF
    RAG_HYBRID_FETCH_K: int = 10               # Candidatos extras antes do re-ranking
    RAG_QUERY_REWRITE: bool = False            # LLM reformula query (desligado: +1 chamada Groq)
    RAG_RERANK_ENABLED: bool = True            # Cross-encoder após RETRIEVE
    RAG_RERANK_MODEL: str = "cross-encoder/ms-marco-MiniLM-L-2-v2"  # Configurável via env

    # ── Chat Service ───────────────────────────────────────────────────────
    CHAT_RATE_LIMIT_MESSAGES: int = 30          # RN-16: max mensagens por hora por usuário
    CHAT_RATE_LIMIT_WINDOW_HOURS: int = 1
    CHAT_MAX_MESSAGE_LENGTH: int = 500          # RN segurança: máximo de caracteres
    CHAT_INACTIVITY_CLOSE_HOURS: int = 24       # RN-02: fechar conversa após 24h inativa
    CHAT_MAX_RESPONSE_LATENCY_MS: int = 10000   # Timeout máximo para o LLM (cold start + rede)

    # ── Busca Web (nutrição) ──────────────────────────────────────────────
    TAVILY_API_KEY: str = ""
    FOOD_WEB_SEARCH_ENABLED: bool = True    # fallback web quando alimento não está na TACO

    # ── InfinitePay ────────────────────────────────────────────────────────
    INFINITEPAY_HANDLE: str = "natalia-faria-16"
    INFINITEPAY_WEBHOOK_URL: str = ""           # URL pública do servidor (ex: https://api.seudominio.com)

    # ── WhatsApp (Meta Cloud API) ──────────────────────────────────────────
    WHATSAPP_TOKEN: str = ""
    WHATSAPP_PHONE_NUMBER_ID: str = ""

    # ── Firebase ──────────────────────────────────────────────────────────
    FIREBASE_CREDENTIALS_PATH: str = "./firebase-credentials.json"

    # ── Recuperação de Senha ───────────────────────────────────────────────
    PASSWORD_RESET_TOKEN_EXPIRE_MINUTES: int = 60
    RESEND_API_KEY: str = ""
    RESEND_FROM_EMAIL: str = "noreply@getfitloop.com"
    RESEND_FROM_NAME: str = "OmniConnect Fitness"
    FRONTEND_URL: str = "http://localhost:3000"
    FRONTEND_RESET_PASSWORD_ROUTE: str = "/reset-password"

    # ── CORS ──────────────────────────────────────────────────────────────
    # Lista de origens separadas por vírgula, ex: "http://localhost:5000,https://meuapp.com"
    # Use "*" apenas em desenvolvimento
    CORS_ORIGINS: str = "*"

    # ── Seed ──────────────────────────────────────────────────────────────
    # Em produção, desabilitar o seed de dados de demo (alunos/personais de teste)
    SEED_DEMO_DATA: bool = True

    model_config = SettingsConfigDict(env_file=".env", extra="ignore")


settings = Settings()
