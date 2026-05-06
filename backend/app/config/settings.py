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

    # ── RAG Pipeline ───────────────────────────────────────────────────────
    RAG_EMBEDDING_DIM: int = 384                # HuggingFace all-MiniLM-L6-v2 embedding dimension
    RAG_MIN_RELEVANCE_SCORE: float = 0.70       # RN-06: score mínimo para usar documento
    RAG_ESCALATE_THRESHOLD: float = 0.60        # RN-07: score abaixo disso → escalar
    RAG_TOP_K_DOCS: int = 5                     # Máximo de documentos recuperados
    RAG_MAX_DOC_CONTENT_LENGTH: int = 5000      # Max caracteres por documento
    RAG_LLM_MAX_TOKENS: int = 500               # RN PRD: max tokens na resposta
    RAG_LLM_TEMPERATURE: float = 0.3            # RN PRD: temperatura baixa para consistência
    RAG_HISTORY_MAX_TOKENS: int = 80            # RN-05: máximo de tokens do histórico

    # ── Chat Service ───────────────────────────────────────────────────────
    CHAT_RATE_LIMIT_MESSAGES: int = 30          # RN-16: max mensagens por hora por usuário
    CHAT_RATE_LIMIT_WINDOW_HOURS: int = 1
    CHAT_MAX_MESSAGE_LENGTH: int = 500          # RN segurança: máximo de caracteres
    CHAT_INACTIVITY_CLOSE_HOURS: int = 24       # RN-02: fechar conversa após 24h inativa

    model_config = SettingsConfigDict(env_file=".env", extra="ignore")


settings = Settings()

