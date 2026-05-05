"""
DTOs para o módulo Dashboard Profissional (RF-43 a RF-48).
"""

from datetime import datetime
from typing import Optional
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field


# ---------------------------------------------------------------------------
# Shared / Nested
# ---------------------------------------------------------------------------


class WorkoutSummaryDTO(BaseModel):
    session_id: UUID
    session_date: datetime
    status: str
    difficulty_level: Optional[int] = None
    mood: Optional[str] = None
    total_exercises: int = 0

    model_config = ConfigDict(from_attributes=True)


class GoalSummaryDTO(BaseModel):
    goal_id: UUID
    title: str
    category: str
    progress_percentage: float
    status: str
    target_date: datetime
    days_remaining: int

    model_config = ConfigDict(from_attributes=True)


class DietAdhierenceDTO(BaseModel):
    """Resumo de adesão alimentar dos últimos 7 dias."""

    days_logged: int = Field(..., description="Dias com registro no logbook alimentar")
    avg_kcal: float = Field(..., description="Média de kcal por dia registrado")
    avg_protein: float
    avg_carbs: float
    avg_fats: float


class MuscleGroupDTO(BaseModel):
    muscle_group: str
    sessions_count: int


# ---------------------------------------------------------------------------
# RF-43: Card de aluno para lista do personal
# ---------------------------------------------------------------------------


class StudentSummaryDTO(BaseModel):
    student_id: UUID
    name: str
    email: str
    last_workout_date: Optional[datetime] = None
    adherence_percentage: float = Field(0.0, ge=0.0, le=100.0)
    total_workouts_30d: int = 0
    active_goals: int = 0
    status: str = Field(..., description="engaged | at_risk | inactive")

    model_config = ConfigDict(from_attributes=True)


class PaginatedStudentsDTO(BaseModel):
    total: int
    page: int
    limit: int
    data: list[StudentSummaryDTO]


# ---------------------------------------------------------------------------
# RF-44: Visão 360° do aluno
# ---------------------------------------------------------------------------


class Student360DTO(BaseModel):
    student_id: UUID
    name: str
    email: str
    weight: Optional[float] = None
    height: Optional[float] = None
    age: Optional[int] = None
    gender: Optional[str] = None

    # Resumo de métricas
    status: str
    adherence_percentage: float
    total_workouts_30d: int
    last_workout_date: Optional[datetime] = None

    # Seções detalhadas (RF-44)
    recent_workouts: list[WorkoutSummaryDTO] = Field(default_factory=list)
    active_goals: list[GoalSummaryDTO] = Field(default_factory=list)
    diet_adherence: Optional[DietAdhierenceDTO] = None
    muscle_group_frequency: list[MuscleGroupDTO] = Field(default_factory=list)

    model_config = ConfigDict(from_attributes=True)


# ---------------------------------------------------------------------------
# RF-46: Visão do Gestor (Admin)
# ---------------------------------------------------------------------------


class AdminOverviewDTO(BaseModel):
    total_active_students: int
    total_personal_trainers: int
    dau: int = Field(..., description="Daily Active Users — treinos completados hoje")
    mau: int = Field(..., description="Monthly Active Users — treinos completados no mês")
    global_adherence_avg: float = Field(..., description="Média de adesão global (%)")
    students_engaged: int
    students_at_risk: int
    students_inactive: int


# ---------------------------------------------------------------------------
# RF-47: Filtros de busca
# ---------------------------------------------------------------------------


class DashboardFiltersDTO(BaseModel):
    """Query params para RF-47."""

    period: str = Field(
        "month",
        description="week | month | year",
        pattern="^(week|month|year)$",
    )
    status: Optional[str] = Field(
        None,
        description="engaged | at_risk | inactive",
        pattern="^(engaged|at_risk|inactive)$",
    )
    page: int = Field(1, ge=1)
    limit: int = Field(20, ge=1, le=100)
