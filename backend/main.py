from dotenv import load_dotenv
load_dotenv()

from contextlib import asynccontextmanager
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.config.database import init_db
from app.routes import user, auth, chat, logbook, goal, invitation
from app.routes.workout_sheet import router as workout_sheet_router, catalog_router as exercise_catalog_router
from app.routes.food_catalog import router as food_catalog_router
from app.routes.diet import custom_food_router, diet_router
from app.routes.diet_logbook import router as diet_logbook_router
from app.routes.payment import router as payment_router


@asynccontextmanager
async def lifespan(app: FastAPI):
    await init_db()
    yield


app = FastAPI(
    title="OmniConnect API",
    version="1.0.0",
    description="Backend do sistema OmniConnect Fitness",
    lifespan=lifespan,
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.get("/")
async def health_check():
    return {
        "status": "online",
        "message": "Servidor OmniConnect rodando com sucesso!",
        "docs": "Acesse http://localhost:8000/docs para ver a documentação interativa.",
        "version": "1.0.1"
    }


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
app.include_router(payment_router)
