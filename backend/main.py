import time
from contextlib import asynccontextmanager

from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse

from app.config.database import init_db
from app.routes import user, auth, chat, logbook, goal
from app.routes.workout_sheet import router as workout_sheet_router, catalog_router as exercise_catalog_router
from app.routes.nutrition import router as nutrition_router


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Gerenciar lifecycle da aplicação."""
    await init_db()
    yield


app = FastAPI(
    title="OmniConnect API",
    version="1.0.0",
    description="Backend do sistema OmniConnect Fitness",
    lifespan=lifespan,
)

# CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


# ── Middleware de latência (RNF-08) ────────────────────────────────────────────
@app.middleware("http")
async def add_process_time_header(request: Request, call_next):
    """Injeta header X-Process-Time-Ms em toda resposta para monitorar latência."""
    start = time.time()
    response = await call_next(request)
    elapsed_ms = round((time.time() - start) * 1000, 2)
    response.headers["X-Process-Time-Ms"] = str(elapsed_ms)
    return response


# ── Health Check (RNF-07) ─────────────────────────────────────────────────────
@app.get("/")
async def root():
    """Raiz da API."""
    return {"status": "online", "docs": "/docs"}


@app.get("/api/v1/health", tags=["health"])
async def health_check():
    """
    Health check completo — usado pelo Docker healthcheck (RNF-07).

    Retorna status 200 enquanto a aplicação estiver saudável.
    Pode ser expandido para checar conexão com o banco se necessário.
    """
    return JSONResponse(
        status_code=200,
        content={
            "status": "healthy",
            "version": "1.0.0",
        },
    )


# ── Rotas da aplicação ────────────────────────────────────────────────────────
app.include_router(auth.router)
app.include_router(user.router)
app.include_router(chat.router)
app.include_router(logbook.router)
app.include_router(goal.router)
app.include_router(workout_sheet_router)
app.include_router(exercise_catalog_router)
app.include_router(nutrition_router)
