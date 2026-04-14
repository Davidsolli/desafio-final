from pydantic_settings import BaseSettings, SettingsConfigDict

class Settings(BaseSettings):
    APP_NAME: str = "OmniConnect Fitness"
    
    # Será preenchido automaticamente ao ler o .env
    DATABASE_URL: str
    
    model_config = SettingsConfigDict(env_file=".env", extra="ignore")

settings = Settings()
