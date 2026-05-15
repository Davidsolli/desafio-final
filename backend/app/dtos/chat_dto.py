"""DTOs Pydantic para o Chatbot de Dúvidas."""

from __future__ import annotations

from datetime import datetime
from typing import Any
from uuid import UUID

from pydantic import BaseModel, Field, field_validator


# ── Request DTOs ──────────────────────────────────────────────────────────────

class SendMessageDTO(BaseModel):
    """Enviar mensagem para o chatbot."""

    conversation_id: UUID | None = Field(None, description="UUID da conversa existente (null = nova)")
    message: str = Field(..., min_length=1, max_length=500, description="Texto da mensagem")

    @field_validator("message")
    @classmethod
    def message_not_empty(cls, v: str) -> str:
        if not v.strip():
            raise ValueError("Mensagem não pode ser vazia.")
        return v.strip()


class RateConversationDTO(BaseModel):
    """Avaliar conversa (1-5 estrelas)."""

    rating: int = Field(..., ge=1, le=5, description="Avaliação de 1 a 5")
    feedback: str | None = Field(None, max_length=1000, description="Comentário opcional")


class MessageFeedbackDTO(BaseModel):
    """Feedback sobre uma mensagem específica."""

    was_helpful: bool = Field(..., description="A resposta foi útil?")
    feedback_type: str = Field(
        "good",
        pattern="^(irrelevant|incorrect|incomplete|good)$",
        description="Tipo do feedback",
    )
    comment: str | None = Field(None, max_length=500, description="Comentário opcional")


class CreateKnowledgeDocumentDTO(BaseModel):
    """Criar documento na base de conhecimento."""

    title: str = Field(..., min_length=3, max_length=500)
    content: str = Field(..., min_length=10, description="Conteúdo em markdown")
    category: str = Field(
        "exercicio",
        pattern="^(exercicio|forma|nutricao|periodizacao)$",
    )
    exercise_id: UUID | None = None
    muscle_group: str | None = Field(None, max_length=100)
    difficulty_level: str | None = Field(
        None,
        pattern="^(iniciante|intermediario|avancado)$",
    )


# ── Response DTOs ─────────────────────────────────────────────────────────────

class RetrievedDocumentDTO(BaseModel):
    """Documento recuperado pelo RAG."""

    id: str
    title: str
    relevance_score: float


class EscalationDTO(BaseModel):
    """Informações de escalação."""

    escalated: bool
    reason: str


class SendMessageResponseDTO(BaseModel):
    """Resposta do chatbot após envio de mensagem."""

    message_id: str
    conversation_id: str
    role: str
    content: str
    retrieved_documents: list[RetrievedDocumentDTO] = []
    escalation: EscalationDTO | None = None
    latency_ms: int
    created_at: str


class ConversationSummaryDTO(BaseModel):
    """Resumo de conversa na listagem."""

    id: str
    started_at: str
    ended_at: str | None
    status: str
    channel: str
    rating: int | None
    escalated: bool
    message_count: int


class ConversationListResponseDTO(BaseModel):
    """Resposta paginada da listagem de conversas."""

    conversations: list[ConversationSummaryDTO]
    total: int
    page: int


class MessageDetailDTO(BaseModel):
    """Mensagem detalhada dentro de uma conversa."""

    id: str
    role: str
    content: str
    retrieved_documents: list[RetrievedDocumentDTO] = []
    latency_ms: int | None
    created_at: str


class ConversationDetailDTO(BaseModel):
    """Detalhes completos de uma conversa."""

    id: str
    started_at: str
    ended_at: str | None
    status: str
    escalated: bool
    escalation_reason: str | None
    messages: list[MessageDetailDTO]
    rating: int | None
    feedback: str | None


class KnowledgeDocumentDTO(BaseModel):
    """Documento da base de conhecimento com métricas."""

    id: str
    title: str
    category: str
    muscle_group: str | None
    difficulty_level: str | None
    views_count: int
    helpful_count: int
    helpfulness_rate: float
    created_at: str


class KnowledgeListResponseDTO(BaseModel):
    """Lista de documentos da base de conhecimento."""

    documents: list[KnowledgeDocumentDTO]


class EscalatedConversationDTO(BaseModel):
    """Conversa escalada para Personal."""

    id: str
    student_id: str
    student_name: str
    reason: str | None
    original_question: str
    escalated_at: str | None
    message_count: int


class EscalatedListResponseDTO(BaseModel):
    """Lista de conversas escaladas."""

    escalated_conversations: list[EscalatedConversationDTO]
    total: int


# ── DTOs para Audio Food Logging ──────────────────────────────────────────────

class FoodLoggedDTO(BaseModel):
    """Alimento registrado no diário alimentar a partir de áudio."""

    food_name: str
    quantity_g: float
    meal_name: str
    kcal: float
    protein: float
    carbs: float
    fats: float
    logbook_entry_id: str
    food_source: str = "taco"   # "taco" | "web" | "estimativa"


class AudioFoodResponseDTO(BaseModel):
    """Resposta do endpoint de audio food logging."""

    message_id: str
    conversation_id: str
    transcription: str              # Texto transcrito do áudio
    content: str                    # Mensagem de confirmação do Vitali
    food_logged: FoodLoggedDTO | None = None   # None se o parse falhou
    parse_confidence: str           # "high" | "low" | "failed"
    created_at: str


class PhotoFoodResponseDTO(BaseModel):
    """Resposta do endpoint de photo food logging."""

    message_id: str
    conversation_id: str
    description: str                        # Descrição do prato pela IA
    content: str                            # Mensagem de confirmação do Vitali
    foods_logged: list[FoodLoggedDTO] = []  # Alimentos registrados
    parse_confidence: str                   # "high" | "medium" | "low" | "failed"
    created_at: str
