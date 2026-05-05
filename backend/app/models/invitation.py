"""
Modelo SQLAlchemy para convites de acesso.

Define a tabela 'invitations' com campos para rastrear códigos gerados por
personal trainers e usados por alunos para se cadastrar.
"""

from datetime import datetime
from uuid import uuid4
from sqlalchemy import Column, String, Boolean, DateTime, ForeignKey
from sqlalchemy.dialects.postgresql import UUID as PG_UUID

from app.models.user import Base


class Invitation(Base):
    """
    Modelo de Convite de Acesso do OmniConnect Fitness.

    Armazena códigos de convite gerados por personal trainers.
    Cada código é único, pode ser usado uma única vez, e vincula o aluno ao PT.

    Atributos:
        id: UUID única gerada automaticamente
        code: Código único do convite (ex: AB3X7KP2QR)
        trainer_id: FK para users.id (quem gerou o convite)
        used: Flag indicando se o código já foi utilizado
        used_by_id: FK para users.id (quem usou o convite)
        created_at: Data de criação (imutável)
        used_at: Data de utilização (preenchida ao usar)
    """

    __tablename__ = "invitations"

    id = Column(
        PG_UUID(as_uuid=True),
        primary_key=True,
        default=uuid4,
        nullable=False,
    )

    code = Column(
        String(20),
        nullable=False,
        unique=True,
        index=True,
    )

    trainer_id = Column(
        PG_UUID(as_uuid=True),
        ForeignKey("users.id"),
        nullable=False,
        index=True,
    )

    used = Column(Boolean, nullable=False, default=False, index=True)

    used_by_id = Column(
        PG_UUID(as_uuid=True),
        ForeignKey("users.id"),
        nullable=True,
        index=True,
    )

    created_at = Column(DateTime, nullable=False, default=datetime.utcnow)

    used_at = Column(DateTime, nullable=True)

    def __repr__(self) -> str:
        return f"<Invitation(code={self.code}, trainer_id={self.trainer_id}, used={self.used})>"
