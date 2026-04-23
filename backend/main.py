from contextlib import asynccontextmanager

from fastapi import FastAPI

from app.config.database import init_db
from app.routes import user, auth
from app.routes import chat

# Rota básica de Health Check
@asynccontextmanager
async def lifespan(app: FastAPI):
    """
    Gerenciar lifecycle da aplicação.
    Inicializa o banco de dados na startup.
    """
    # Startup
    await init_db()
    yield
    # Shutdown (aqui iria lógica de cleanup se necessário)


# Inicialização da aplicação
app = FastAPI(
    title="OmniConnect API",
    version="1.0.0",
    description="Backend do sistema OmniConnect Fitness",
    lifespan=lifespan,
)

# Health Check
@app.get("/")
async def health_check():
    """Health check da API."""
    return {
        "status": "online",
        "message": "Servidor OmniConnect rodando com sucesso!",
        "docs": "Acesse http://localhost:8000/docs para ver a documentação interativa."
    }

# Registrar rotas
app.include_router(auth.router)
app.include_router(user.router)
app.include_router(chat.router)

