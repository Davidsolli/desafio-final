import asyncio
from contextlib import asynccontextmanager

from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from slowapi import Limiter
from slowapi.util import get_remote_address
from slowapi.errors import RateLimitExceeded

from app.config.database import init_db
from app.routes import user, auth, chat, logbook, goal, invitation, password
from app.tasks.cleanup_tasks import background_cleanup_task
from app.routes.workout_sheet import router as workout_sheet_router, catalog_router as exercise_catalog_router
from app.routes.food_catalog import router as food_catalog_router
from app.routes.diet import custom_food_router, diet_router
from app.routes.diet_logbook import router as diet_logbook_router

# Rota básica de Health Check
@asynccontextmanager
async def lifespan(app: FastAPI):
    """
    Gerenciar lifecycle da aplicação.
    Inicializa o banco de dados e inicia tasks de limpeza na startup.
    """
    # Startup
    await init_db()

    # Iniciar task de limpeza de tokens expirados (background)
    cleanup_task = asyncio.create_task(background_cleanup_task())

    yield

    # Shutdown: Cancelar task de limpeza
    cleanup_task.cancel()
    try:
        await cleanup_task
    except asyncio.CancelledError:
        pass


# Inicialização da aplicação
app = FastAPI(
    title="OmniConnect API",
    version="1.0.0",
    description="Backend do sistema OmniConnect Fitness",
    lifespan=lifespan,
)

# Configurar Rate Limiting (slowapi)
limiter = Limiter(key_func=get_remote_address)
app.state.limiter = limiter
app.add_exception_handler(
    RateLimitExceeded,
    lambda request, exc: JSONResponse(
        status_code=429,
        content={"detail": "Muitas requisições. Tente novamente mais tarde."}
    )
)

# Configurar CORS para permitir requisições do Flutter web (desenvolvimento)
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Permitir todas as origens em desenvolvimento
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Health Check
@app.get("/")
async def health_check():
    """Health check da API."""
    return {
        "status": "online",
        "message": "Servidor OmniConnect rodando com sucesso!",
        "docs": "Acesse http://localhost:8000/docs para ver a documentação interativa.",
        "version": "1.0.1"
    }

# Registrar rotas
app.include_router(auth.router)
app.include_router(password.router)
app.include_router(user.router)
app.include_router(invitation.router)
app.include_router(chat.router)
app.include_router(logbook.router)
app.include_router(goal.router)
app.include_router(workout_sheet_router)
app.include_router(exercise_catalog_router)
app.include_router(food_catalog_router)
app.include_router(custom_food_router)
app.include_router(diet_router)
app.include_router(diet_logbook_router)

