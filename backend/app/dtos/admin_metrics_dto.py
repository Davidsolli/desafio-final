"""DTOs de resposta para o módulo de métricas admin."""

from datetime import datetime
from typing import Optional
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field


class StudentMetricsItemDTO(BaseModel):
    """Métricas individuais de um aluno."""

    user_id: UUID
    user_name: str
    trainer_id: Optional[UUID] = None
    trainer_name: Optional[str] = None
    adherence_rate: float = Field(description="% de sessões completadas no período")
    adherence_category: str = Field(description="high | medium | low")
    sessions_completed: int
    sessions_total: int
    diet_logs_count: int
    risk_level: str = Field(description="critical | high | medium | low")
    risk_score: int
    days_inactive: int
    last_activity: Optional[datetime] = None
    goal_progress: Optional[float] = Field(None, description="% médio de progresso nas metas ativas")

    model_config = ConfigDict(from_attributes=True)


class StudentMetricsSummaryDTO(BaseModel):
    """Resumo agregado das métricas de alunos."""

    total_students: int
    high_adherence_count: int
    medium_adherence_count: int
    low_adherence_count: int
    avg_adherence_rate: float
    at_risk_critical: int
    at_risk_high: int
    at_risk_medium: int
    at_risk_low: int


class PaginatedStudentMetricsDTO(BaseModel):
    """Resposta paginada com métricas de alunos."""

    total: int
    page: int
    limit: int
    data: list[StudentMetricsItemDTO]
    summary: StudentMetricsSummaryDTO


class TrainerMetricsItemDTO(BaseModel):
    """Métricas individuais de um personal trainer."""

    trainer_id: UUID
    trainer_name: str
    total_students: int
    active_students: int
    at_risk_students: int
    portfolio_health: float = Field(description="% de alunos ativos vs total")
    avg_student_adherence: float
    invites_generated: int
    invites_used: int
    conversion_rate: float = Field(description="% de convites resgatados")

    model_config = ConfigDict(from_attributes=True)


class PaginatedTrainerMetricsDTO(BaseModel):
    """Resposta paginada com métricas de trainers."""

    total: int
    page: int
    limit: int
    data: list[TrainerMetricsItemDTO]


class SystemMetricsDTO(BaseModel):
    """Métricas globais do sistema."""

    period_days: int
    total_users: int
    active_users: int
    new_users_in_period: int
    total_trainers: int
    total_students: int
    dau: int = Field(description="Daily Active Users (hoje)")
    mau: int = Field(description="Monthly Active Users (últimos 30 dias)")
    dau_mau_ratio: float
    total_workouts_completed: int
    total_diet_logs: int
    chatbot_adoption_rate: float = Field(description="% de usuários que usaram o chatbot")
    chatbot_quality_score: float = Field(description="% de respostas marcadas como úteis")


class AIModelStatsDTO(BaseModel):
    """Estatísticas de uso por modelo de IA."""

    model: str
    messages_count: int
    total_tokens: int
    avg_latency_ms: float
    percent_of_total: float


class AIAnalyticsDTO(BaseModel):
    """Analytics de uso e custo de IA."""

    period_days: int
    total_messages: int
    total_tokens: int
    avg_tokens_per_message: float
    avg_latency_ms: float
    quality_score: float = Field(description="% de respostas marcadas como úteis")
    by_model: list[AIModelStatsDTO]
