# Importar todos os modelos para que o Base.metadata contenha todas as tabelas.
# Necessário para que create_all() nas fixtures de teste crie todas as tabelas.
from app.models.user import Base, User  # noqa: F401
from app.models.chatbot import (  # noqa: F401
    KnowledgeBase,
    ChatConversation,
    ChatMessage,
    ChatFeedback,
)
from app.models.workout_sheet import WorkoutSheet, Exercise  # noqa: F401
from app.models.exercise_catalog import ExerciseCatalog  # noqa: F401
from app.models.food_catalog import FoodCatalog  # noqa: F401
from app.models.diet import CustomFood, Diet, DietMeal, DietItem  # noqa: F401
from app.models.diet_logbook import DietLogbook, DietLogbookEntry  # noqa: F401

__all__ = [
    "Base",
    "User",
    "KnowledgeBase",
    "ChatConversation",
    "ChatMessage",
    "ChatFeedback",
    "WorkoutSheet",
    "Exercise",
    "ExerciseCatalog",
    "FoodCatalog",
    "CustomFood",
    "Diet",
    "DietMeal",
    "DietItem",
    "DietLogbook",
    "DietLogbookEntry",
]

