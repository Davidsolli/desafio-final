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

    model_config = SettingsConfigDict(env_file=".env", extra="ignore")

settings = Settings()
