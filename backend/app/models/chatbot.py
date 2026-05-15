"""
Modelos SQLAlchemy para o Chatbot de Dúvidas Inteligente.

Define as tabelas:
- KnowledgeBase: Base de conhecimento da academia para RAG
- ChatConversation: Conversa do chatbot (agrupamento de mensagens)
- ChatMessage: Mensagem individual dentro de uma conversa
- ChatFeedback: Feedback do aluno sobre uma resposta do chatbot
"""

from datetime import datetime
from uuid import uuid4

from sqlalchemy import (
    Boolean,
    Column,
    DateTime,
    ForeignKey,
    Integer,
    String,
    Text,
    JSON,
)
from sqlalchemy.dialects.postgresql import UUID as PG_UUID
from sqlalchemy.orm import relationship

try:
    from pgvector.sqlalchemy import Vector
    HAS_PGVECTOR = True
except ImportError:  # pragma: no cover
    HAS_PGVECTOR = False

from app.models.user import Base

# Dimensão do embedding all-MiniLM-L6-v2 (padrão HuggingFace)
EMBEDDING_DIM = 384


class KnowledgeBase(Base):
    """
    Base de conhecimento da academia para o pipeline RAG.

    Atributos:
        id: UUID único do documento
        academy_id: UUID da academia proprietária (FK futuro)
        title: Título do documento (ex: "Como fazer Supino Reto")
        content: Conteúdo completo em markdown
        category: Categoria temática ("exercicio", "forma", "nutricao", "periodizacao")
        embedding: Vetor pgvector (384 dims — all-MiniLM-L6-v2)
        embedding_model: Nome do modelo usado para gerar o embedding
        exercise_id: UUID do exercício relacionado (FK futuro, opcional)
        muscle_group: Grupo muscular principal (ex: "Peito", "Costas")
        difficulty_level: Nível de dificuldade ("iniciante", "intermediario", "avancado")
        created_by_id: UUID do Personal/Gestor que criou o documento
        is_active: Indicador de atividade na RAG
        views_count: Quantidade de vezes consultada
        helpful_count: Quantidade de vezes marcada como útil
        created_at: Timestamp de criação
        updated_at: Timestamp de última atualização
    """

    __tablename__ = "knowledge_base"

    id = Column(
        PG_UUID(as_uuid=True),
        primary_key=True,
        default=uuid4,
        nullable=False,
    )

    # Academia proprietária (preparado para multi-tenant)
    academy_id = Column(PG_UUID(as_uuid=True), nullable=True, index=True)

    # ── Conteúdo ──────────────────────────────────────────────────────────
    title = Column(String(500), nullable=False, index=True)
    content = Column(Text, nullable=False)
    category = Column(
        String(50),
        nullable=False,
        default="exercicio",
        index=True,
    )  # exercicio | forma | nutricao | periodizacao

    # ── Vetor de Embedding para RAG ───────────────────────────────────────
    if HAS_PGVECTOR:
        embedding = Column(Vector(EMBEDDING_DIM), nullable=True)
    else:  # pragma: no cover — fallback para ambientes sem pgvector instalado
        embedding = Column(JSON, nullable=True)

    embedding_model = Column(
        String(100),
        nullable=False,
        default="huggingface:all-MiniLM-L6-v2",
    )

    # ── Metadados de Exercício ────────────────────────────────────────────
    exercise_id = Column(PG_UUID(as_uuid=True), nullable=True, index=True)
    muscle_group = Column(String(100), nullable=True, index=True)
    difficulty_level = Column(
        String(30),
        nullable=True,
        index=True,
    )  # iniciante | intermediario | avancado

    # ── Controle e Auditoria ─────────────────────────────────────────────
    created_by_id = Column(PG_UUID(as_uuid=True), nullable=True)
    is_active = Column(Boolean, nullable=False, default=True, index=True)
    views_count = Column(Integer, nullable=False, default=0)
    helpful_count = Column(Integer, nullable=False, default=0)

    created_at = Column(DateTime, nullable=False, default=datetime.utcnow)
    updated_at = Column(
        DateTime,
        nullable=False,
        default=datetime.utcnow,
        onupdate=datetime.utcnow,
    )

    def __repr__(self) -> str:
        return (
            f"<KnowledgeBase(id={self.id}, title={self.title!r}, "
            f"category={self.category!r}, active={self.is_active})>"
        )

    @property
    def helpfulness_rate(self) -> float:
        """Taxa de utilidade: helpful_count / views_count."""
        if not self.views_count:
            return 0.0
        return round(self.helpful_count / self.views_count, 4)


class ChatConversation(Base):
    """
    Conversa do chatbot — agrupa mensagens de uma sessão.

    Atributos:
        id: UUID único da conversa
        user_id: UUID do aluno (FK users)
        academy_id: UUID da academia (FK futuro)
        channel: Canal de origem ("app" no MVP 1, "whatsapp" no MVP 2)
        status: Estado da conversa ("active", "escalated", "closed")
        started_at: Timestamp de início
        ended_at: Timestamp de encerramento (NULL se aberta)
        escalated_to_personal_id: UUID do Personal que assumiu (nullable)
        escalation_reason: Motivo da escalação ("too_complex", "user_requested", etc.)
        escalated_at: Timestamp da escalação
        rating: Avaliação do aluno (1-5, nullable)
        feedback: Comentário do aluno (opcional)
        created_at / updated_at: Auditoria
    """

    __tablename__ = "chat_conversations"

    id = Column(
        PG_UUID(as_uuid=True),
        primary_key=True,
        default=uuid4,
        nullable=False,
    )

    # Relacionamentos de usuário/academia
    user_id = Column(
        PG_UUID(as_uuid=True),
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    academy_id = Column(PG_UUID(as_uuid=True), nullable=True, index=True)

    # ── Metadados da Conversa ─────────────────────────────────────────────
    channel = Column(
        String(20),
        nullable=False,
        default="app",
        index=True,
    )  # app | whatsapp (MVP 2)
    status = Column(
        String(20),
        nullable=False,
        default="active",
        index=True,
    )  # active | escalated | closed
    started_at = Column(DateTime, nullable=False, default=datetime.utcnow)
    ended_at = Column(DateTime, nullable=True)

    # ── Escalação para Personal ───────────────────────────────────────────
    escalated_to_personal_id = Column(PG_UUID(as_uuid=True), nullable=True)
    escalation_reason = Column(
        String(100),
        nullable=True,
    )  # too_complex | user_requested | low_confidence | health_risk |
    # validation_failed | timeout | generation_error
    escalated_at = Column(DateTime, nullable=True)

    # Contexto serializado da escalação (Card 19.10):
    #   {original_question, rag_best_score, reason, user_context_summary}
    escalation_data = Column(JSON, nullable=True)

    # ── Satisfação do Aluno ───────────────────────────────────────────────
    rating = Column(Integer, nullable=True)  # 1-5
    feedback = Column(Text, nullable=True)

    # ── Auditoria ─────────────────────────────────────────────────────────
    created_at = Column(DateTime, nullable=False, default=datetime.utcnow)
    updated_at = Column(
        DateTime,
        nullable=False,
        default=datetime.utcnow,
        onupdate=datetime.utcnow,
    )

    # ── Relações ORM ──────────────────────────────────────────────────────
    messages = relationship(
        "ChatMessage",
        back_populates="conversation",
        cascade="all, delete-orphan",
        order_by="ChatMessage.created_at",
    )

    def __repr__(self) -> str:
        return (
            f"<ChatConversation(id={self.id}, user_id={self.user_id}, "
            f"status={self.status!r}, channel={self.channel!r})>"
        )


class ChatMessage(Base):
    """
    Mensagem individual dentro de uma conversa do chatbot.

    Atributos:
        id: UUID único da mensagem
        conversation_id: UUID da conversa (FK chat_conversations)
        role: Papel do emissor ("user" ou "assistant")
        content: Texto da mensagem
        context_data: JSON com contexto enviado ao LLM
            {user_profile, active_workout_sheet, retrieved_documents}
        channel: Canal da mensagem ("app", "whatsapp")
        model_used: Identificador do modelo LLM utilizado
        tokens_used: Total de tokens consumidos (input + output)
        latency_ms: Tempo de resposta em milissegundos
        is_human_reviewed: Se foi revisada por Personal
        reviewed_by_id: UUID do Personal que revisou
        needs_human_review: Flag para fila de revisão
        created_at: Timestamp de criação
    """

    __tablename__ = "chat_messages"

    id = Column(
        PG_UUID(as_uuid=True),
        primary_key=True,
        default=uuid4,
        nullable=False,
    )

    conversation_id = Column(
        PG_UUID(as_uuid=True),
        ForeignKey("chat_conversations.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )

    # ── Conteúdo ──────────────────────────────────────────────────────────
    role = Column(
        String(20),
        nullable=False,
        index=True,
    )  # user | assistant
    content = Column(Text, nullable=False)

    # ── Contexto RAG ──────────────────────────────────────────────────────
    context_data = Column(
        JSON,
        nullable=True,
    )
    # Estrutura esperada:
    # {
    #   "user_profile": {name, role, level, objective},
    #   "active_workout_sheet": {id, name, exercises: [...]},
    #   "retrieved_documents": [{id, title, relevance_score}, ...]
    # }

    # ── Canal (preparado para MVP 2 — WhatsApp) ───────────────────────────
    channel = Column(String(20), nullable=False, default="app", index=True)

    # ── Rastreamento de Geração ───────────────────────────────────────────
    model_used = Column(String(100), nullable=True)
    tokens_used = Column(Integer, nullable=True, default=0)
    latency_ms = Column(Integer, nullable=True, default=0)

    # ── Validação Humana ──────────────────────────────────────────────────
    is_human_reviewed = Column(Boolean, nullable=False, default=False)
    reviewed_by_id = Column(PG_UUID(as_uuid=True), nullable=True)
    needs_human_review = Column(Boolean, nullable=False, default=False, index=True)

    # ── Auditoria ─────────────────────────────────────────────────────────
    created_at = Column(DateTime, nullable=False, default=datetime.utcnow, index=True)

    # ── Relações ORM ──────────────────────────────────────────────────────
    conversation = relationship("ChatConversation", back_populates="messages")
    feedbacks = relationship(
        "ChatFeedback",
        back_populates="message",
        cascade="all, delete-orphan",
    )

    def __repr__(self) -> str:
        return (
            f"<ChatMessage(id={self.id}, role={self.role!r}, "
            f"conversation_id={self.conversation_id})>"
        )


class ChatFeedback(Base):
    """
    Feedback do aluno sobre uma resposta do chatbot.

    Atributos:
        id: UUID único do feedback
        message_id: UUID da mensagem avaliada (FK chat_messages)
        user_id: UUID do aluno que deixou o feedback
        was_helpful: Verdadeiro/Falso — resposta foi útil?
        feedback_type: Tipo do feedback ("irrelevant", "incorrect", "incomplete", "good")
        comment: Comentário livre (opcional)
        created_at: Timestamp de criação
    """

    __tablename__ = "chat_feedback"

    id = Column(
        PG_UUID(as_uuid=True),
        primary_key=True,
        default=uuid4,
        nullable=False,
    )

    message_id = Column(
        PG_UUID(as_uuid=True),
        ForeignKey("chat_messages.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    user_id = Column(
        PG_UUID(as_uuid=True),
        ForeignKey("users.id", ondelete="SET NULL"),
        nullable=True,
        index=True,
    )

    # ── Feedback ──────────────────────────────────────────────────────────
    was_helpful = Column(Boolean, nullable=False)
    feedback_type = Column(
        String(30),
        nullable=False,
        default="good",
    )  # irrelevant | incorrect | incomplete | good
    comment = Column(Text, nullable=True)

    created_at = Column(DateTime, nullable=False, default=datetime.utcnow)

    # ── Relações ORM ──────────────────────────────────────────────────────
    message = relationship("ChatMessage", back_populates="feedbacks")

    def __repr__(self) -> str:
        return (
            f"<ChatFeedback(id={self.id}, message_id={self.message_id}, "
            f"was_helpful={self.was_helpful}, type={self.feedback_type!r})>"
        )
