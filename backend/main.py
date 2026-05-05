from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.config.database import init_db, _get_async_session_local
from app.routes import user, auth, chat, logbook, goal
from app.routes.workout_sheet import router as workout_sheet_router, catalog_router as exercise_catalog_router
from app.routes.food_catalog import router as food_catalog_router
from app.routes.diet import custom_food_router, diet_router
from app.routes.diet_logbook import router as diet_logbook_router
from app.routes.dashboard import router as dashboard_router
from app.tasks.analytics_refresh import setup_analytics_scheduler

# Rota básica de Health Check
@asynccontextmanager
async def lifespan(app: FastAPI):
    """
    Gerenciar lifecycle da aplicação.
    Inicializa o banco de dados e o scheduler de analytics na startup.
    """
    # Startup
    await init_db()

    scheduler = setup_analytics_scheduler(_get_async_session_local())
    scheduler.start()

    yield

    # Shutdown
    scheduler.shutdown(wait=False)


# Inicialização da aplicação
app = FastAPI(
    title="OmniConnect API",
    version="1.0.0",
    description="Backend do sistema OmniConnect Fitness",
    lifespan=lifespan,
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
        "docs": "Acesse http://localhost:8000/docs para ver a documentação interativa."
    }

# Registrar rotas
app.include_router(auth.router)
app.include_router(user.router)
app.include_router(chat.router)
app.include_router(logbook.router)
app.include_router(goal.router)
app.include_router(workout_sheet_router)
app.include_router(exercise_catalog_router)
app.include_router(food_catalog_router)
app.include_router(custom_food_router)
app.include_router(diet_router)
app.include_router(diet_logbook_router)
app.include_router(dashboard_router)

