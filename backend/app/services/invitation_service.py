"""
Serviço de Convites.

Camada de negócio que orquestra operações com convites de acesso.
Inclui: geração de códigos, validação, e rastreamento de uso.
"""

import secrets
import string
from datetime import datetime, timedelta, timezone
from uuid import UUID

from sqlalchemy.ext.asyncio import AsyncSession

from app.models.invitation import Invitation
from app.dtos.invitation_dto import (
    InvitationResponseDTO,
    ListInvitationsResponseDTO,
)
from app.repositories.invitation_repository import InvitationRepository


class InvalidInvitationError(Exception):
    """Exceção quando um convite é inválido."""

    pass


class InvitationService:
    """Serviço de negócio para convites."""

    def __init__(self, session: AsyncSession):
        """Inicializar serviço com sessão async."""
        self.session = session
        self.repository = InvitationRepository(session)

    @staticmethod
    def _generate_code() -> str:
        """
        Gerar código de convite único.

        Formato: 10 caracteres (letras maiúsculas + dígitos)
        Exemplo: AB3X7KP2QR

        Returns:
            str: Código gerado
        """
        chars = string.ascii_uppercase + string.digits
        return "".join(secrets.choice(chars) for _ in range(10))

    _TTL_HOURS = 72

    async def generate(self, trainer_id: UUID) -> InvitationResponseDTO:
        """
        Gerar novo código de convite com TTL de 72h.

        Args:
            trainer_id: UUID do personal trainer / admin que está gerando

        Returns:
            InvitationResponseDTO: Convite criado com código gerado

        Raises:
            Exception: Se houver erro ao salvar no banco
        """
        code = self._generate_code()
        expires_at = datetime.now(timezone.utc) + timedelta(hours=self._TTL_HOURS)

        invitation = Invitation(
            code=code,
            trainer_id=trainer_id,
            used=False,
            expires_at=expires_at,
        )

        created = await self.repository.create(invitation)
        await self.repository.commit()

        return InvitationResponseDTO.model_validate(created)

    async def validate(self, code: str) -> bool:
        """
        Validar código de convite.

        Um código é válido se:
        - Existe no banco
        - Ainda não foi utilizado (used=False)
        - Não expirou (expires_at > now)

        Args:
            code: Código a validar

        Returns:
            bool: True se válido, False caso contrário
        """
        invitation = await self.repository.get_by_code(code)

        if not invitation:
            return False

        if invitation.used:
            return False

        if invitation.expires_at:
            now = datetime.now(timezone.utc)
            expires = invitation.expires_at
            if expires.tzinfo is None:
                expires = expires.replace(tzinfo=timezone.utc)
            if expires < now:
                return False

        return True

    async def get_by_code(self, code: str) -> Invitation | None:
        """
        Buscar convite por código.

        Args:
            code: Código do convite

        Returns:
            Invitation ou None
        """
        return await self.repository.get_by_code(code)

    async def mark_as_used(
        self,
        invitation: Invitation,
        used_by_id: UUID,
    ) -> InvitationResponseDTO:
        """
        Marcar convite como utilizado.

        Args:
            invitation: Objeto Invitation a atualizar
            used_by_id: UUID do usuário que usou o convite

        Returns:
            InvitationResponseDTO: Convite atualizado
        """
        invitation.used = True
        invitation.used_by_id = used_by_id
        invitation.used_at = datetime.utcnow()

        updated = await self.repository.update(invitation)
        await self.repository.commit()

        return InvitationResponseDTO.model_validate(updated)

    async def list_by_trainer(
        self,
        trainer_id: UUID,
    ) -> ListInvitationsResponseDTO:
        """
        Listar convites gerados por um personal trainer.

        Args:
            trainer_id: UUID do personal trainer

        Returns:
            ListInvitationsResponseDTO com contadores e lista de convites
        """
        invitations = await self.repository.get_by_trainer(trainer_id)

        total = len(invitations)
        pending = sum(1 for inv in invitations if not inv.used)
        used = total - pending

        invitation_dtos = [
            InvitationResponseDTO.model_validate(inv) for inv in invitations
        ]

        return ListInvitationsResponseDTO(
            total=total,
            pending=pending,
            used=used,
            invitations=invitation_dtos,
        )
