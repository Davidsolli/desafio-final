from pydantic_settings import BaseSettings, SettingsConfigDict

class Settings(BaseSettings):
    """Configurações da aplicação."""

    APP_NAME: str = "OmniConnect Fitness"

    # Banco de Dados
    DATABASE_URL: str
    DATABASE_ECHO: bool = False

    # Ambiente
    ENV: str = "development"

    model_config = SettingsConfigDict(env_file=".env", extra="ignore")

settings = Settings()
