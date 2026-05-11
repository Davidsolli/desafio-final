from dotenv import load_dotenv
load_dotenv()

from contextlib import asynccontextmanager
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from slowapi import _rate_limit_exceeded_handler
from slowapi.errors import RateLimitExceeded

from app.config.database import init_db
from app.config.limiter import limiter
from app.routes import user, auth, chat, logbook, goal, invitation, webhooks
from app.routes.pages import router as pages_router
from app.routes.workout_sheet import router as workout_sheet_router, catalog_router as exercise_catalog_router
from app.routes.food_catalog import router as food_catalog_router
from app.routes.diet import custom_food_router, diet_router
from app.routes.diet_logbook import router as diet_logbook_router
from app.routes.password import router as password_router
from app.routes.notification import router as notification_router

from app.tasks.notification_scheduler import NotificationScheduler

# Rota básica de Health Check
@asynccontextmanager
async def lifespan(app: FastAPI):
    """
    Gerenciar lifecycle da aplicação.
    Inicializa o banco de dados e aquece o modelo de embeddings na startup
    para evitar latência adicional na primeira requisição do chatbot.
    """
    await init_db()

    # Pré-aquece o modelo de embeddings local (HuggingFace)
    try:
        from app.ai.rag_chain import rag_chain
        await rag_chain.warm_up()
    except Exception:
        pass

    # Iniciar Cronjob de Notificações
    NotificationScheduler.start()

    yield

    # Shutdown
    NotificationScheduler.stop()


# Inicialização da aplicação
app = FastAPI(
    title="OmniConnect API",
    version="1.0.0",
    description="Backend do sistema OmniConnect Fitness",
    lifespan=lifespan,
)

# Rate limiting global (slowapi) — instância compartilhada com os routers
app.state.limiter = limiter
app.add_exception_handler(RateLimitExceeded, _rate_limit_exceeded_handler)

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
app.include_router(webhooks.router)
app.include_router(pages_router)
app.include_router(password_router)
app.include_router(notification_router)
