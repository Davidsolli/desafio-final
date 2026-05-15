"""
Serviço de Usuários.

Camada de negócio que orquestra operações com usuários.
Inclui: criação, atualização, validação, hash de senhas e lógica de negócio.
"""

import bcrypt
from typing import Optional, List, Tuple
from uuid import UUID

from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.user import User
from app.dtos.user_dto import CreateUserDTO, UpdateUserDTO, UserResponseDTO
from app.dtos.auth_dto import ChangePasswordDTO
from app.repositories.user_repository import UserRepository
from app.services.invitation_service import InvitationService
from app.repositories.invitation_repository import InvitationRepository


class UserAlreadyExistsError(Exception):
    """Exceção quando email já existe no banco."""

    pass


class InvalidInvitationError(Exception):
    """Exceção quando código de convite é inválido."""

    pass


class UserNotFoundError(Exception):
    """Exceção quando usuário não é encontrado."""

    pass


class InvalidCredentialsError(Exception):
    """Exceção quando a senha atual está incorreta."""

    pass


class UserService:
    """Serviço de negócio para usuários."""

    def __init__(self, session: AsyncSession):
        """Inicializar serviço com sessão async."""
        self.session = session
        self.repository = UserRepository(session)

    @staticmethod
    def hash_password(password: str) -> str:
        """
        Hash de senha com bcrypt.

        Args:
            password: Senha em texto plano

        Returns:
            str: Senha hasheada
        """
        salt = bcrypt.gensalt(rounds=12)
        return bcrypt.hashpw(password.encode(), salt).decode()

    @staticmethod
    def verify_password(password: str, hashed: str) -> bool:
        """
        Verificar senha contra hash bcrypt.

        Args:
            password: Senha em texto plano
            hashed: Hash bcrypt armazenado

        Returns:
            bool: True se correspondem, False caso contrário
        """
        return bcrypt.checkpw(password.encode(), hashed.encode())

    async def create(self, dto: CreateUserDTO) -> UserResponseDTO:
        """
        Criar novo usuário.

        Args:
            dto: CreateUserDTO com dados do novo usuário

        Returns:
            UserResponseDTO: Usuário criado

        Raises:
            UserAlreadyExistsError: Se email já existe
            InvalidInvitationError: Se código de convite é inválido
        """
        # Normalizar email para minúsculo antes de qualquer operação
        dto.email = dto.email.lower()

        # Validar se email já existe
        existing_user = await self.repository.get_by_email_all_states(dto.email)
        if existing_user:
            raise UserAlreadyExistsError(f"Email '{dto.email}' já está cadastrado")

        # Validar código de convite: obrigatório para clientes
        invitation = None
        if dto.role == "client":
            if not dto.invitation_code:
                raise InvalidInvitationError("Código de convite obrigatório para clientes")
            invitation_repo = InvitationRepository(self.session)
            invitation = await invitation_repo.get_by_code(dto.invitation_code)
            if not invitation or invitation.used:
                raise InvalidInvitationError("Código de convite inválido ou já utilizado")

        # Criar instância de User com dados corporais
        user = User(
            name=dto.name,
            email=dto.email,
            password=self.hash_password(dto.password),
            role=dto.role,
            is_active=True,
            trainer_id=invitation.trainer_id if invitation else None,
            weight=dto.weight_kg,
            height=dto.height_cm,
            age=dto.age,
            goal_type=dto.goal_type,
        )

        try:
            # Salvar no banco
            created_user = await self.repository.create(user)

            # Marcar convite como utilizado (se houver)
            if invitation:
                from datetime import datetime
                invitation.used = True
                invitation.used_by_id = created_user.id
                invitation.used_at = datetime.utcnow()
                invitation_repo = InvitationRepository(self.session)
                await invitation_repo.update(invitation)

            # Auto-criar assinatura se pagamento foi confirmado no pré-cadastro
            if invitation and dto.invitation_code:
                await self._maybe_create_subscription_from_prereg(
                    created_user, dto.invitation_code
                )

            await self.repository.commit()

            return UserResponseDTO.model_validate(created_user)
        except IntegrityError as e:
            await self.repository.rollback()
            raise UserAlreadyExistsError(
                f"Erro de integridade ao criar usuário: {str(e)}"
            )

    async def _maybe_create_subscription_from_prereg(
        self, user: User, invitation_code: str
    ) -> None:
        """
        Se o pré-cadastro WhatsApp tiver pagamento confirmado, cria a assinatura
        automaticamente ao finalizar o cadastro no app.
        """
        from datetime import datetime, timedelta
        from sqlalchemy import select
        from app.models.whatsapp_pre_registration import WhatsAppPreRegistration
        from app.models.payment import Plan, Subscription

        try:
            result = await self.session.execute(
                select(WhatsAppPreRegistration).where(
                    WhatsAppPreRegistration.invitation_code == invitation_code,
                    WhatsAppPreRegistration.payment_status == "confirmed",
                )
            )
            pre_reg = result.scalar_one_or_none()
            if not pre_reg or not pre_reg.selected_plan_id:
                return

            plan_result = await self.session.execute(
                select(Plan).where(Plan.id == pre_reg.selected_plan_id, Plan.is_active == True)
            )
            plan = plan_result.scalar_one_or_none()
            if not plan:
                return

            now = datetime.utcnow()
            subscription = Subscription(
                student_id=user.id,
                plan_id=plan.id,
                admin_id=plan.admin_id,
                status="active",
                payment_method="whatsapp_prereg",
                external_payment_id=pre_reg.pre_reg_payment_id,
                started_at=now,
                expires_at=now + timedelta(days=30 * plan.duration_months),
            )
            self.session.add(subscription)
            await self.session.flush()

        except Exception:
            import logging
            logging.getLogger(__name__).exception(
                "Erro ao criar subscription automática para user=%s", user.id
            )

    async def get_by_id(self, user_id: UUID) -> UserResponseDTO:
        """
        Buscar usuário por ID.

        Args:
            user_id: UUID do usuário

        Returns:
            UserResponseDTO: Dados do usuário

        Raises:
            UserNotFoundError: Se usuário não encontrado
        """
        user = await self.repository.get_by_id(user_id)
        if not user:
            raise UserNotFoundError(f"Usuário com ID {user_id} não encontrado")

        return UserResponseDTO.model_validate(user)

    async def list_all(
        self,
        page: int = 1,
        limit: int = 10,
        role: Optional[str] = None,
        trainer_id: Optional[UUID] = None,
        include_inactive: bool = False,
    ) -> Tuple[List[UserResponseDTO], int]:
        """
        Listar usuários com paginação.

        Args:
            page: Número da página
            limit: Itens por página
            role: Filtrar por role (admin, personal_trainer, client)
            trainer_id: Filtrar alunos de um trainer específico
            include_inactive: Se True, inclui usuários inativos

        Returns:
            Tuple[List[UserResponseDTO], int]: Lista de usuários e total
        """
        users, total = await self.repository.list_all(page, limit, role, trainer_id, include_inactive)
        user_dtos = [UserResponseDTO.model_validate(user) for user in users]
        return user_dtos, total

    async def update(self, user_id: UUID, dto: UpdateUserDTO) -> UserResponseDTO:
        """
        Atualizar dados de usuário.

        Args:
            user_id: UUID do usuário
            dto: UpdateUserDTO com campos a atualizar

        Returns:
            UserResponseDTO: Usuário atualizado

        Raises:
            UserNotFoundError: Se usuário não encontrado
        """
        user = await self.repository.get_by_id_all_states(user_id)
        if not user:
            raise UserNotFoundError(f"Usuário com ID {user_id} não encontrado")

        # Atualizar apenas campos fornecidos
        if dto.name is not None:
            user.name = dto.name
        if dto.role is not None:
            user.role = dto.role
        if dto.is_active is not None:
            user.is_active = dto.is_active
        if dto.weight is not None:
            user.weight = dto.weight
        if dto.height is not None:
            user.height = dto.height
        if dto.age is not None:
            user.age = dto.age
        if dto.gender is not None:
            user.gender = dto.gender
        if dto.phone_whatsapp is not None:
            user.phone_whatsapp = dto.phone_whatsapp
        if dto.goal_type is not None:
            user.goal_type = dto.goal_type
        if dto.theme_preference is not None:
            user.theme_preference = dto.theme_preference
        if dto.timezone is not None:
            user.timezone = dto.timezone
        if dto.trainer_id is not None:
            # Valida que o profissional destino existe e é realmente um profissional
            from app.utils.role_utils import is_professional
            target = await self.repository.get_by_id(dto.trainer_id)
            if not target:
                raise UserNotFoundError("Profissional destino não encontrado")
            if not is_professional(target.role):
                raise Exception("O usuário destino não é um profissional")
            user.trainer_id = dto.trainer_id

        try:
            updated_user = await self.repository.update(user)
            await self.repository.commit()

            return UserResponseDTO.model_validate(updated_user)
        except IntegrityError as e:
            await self.repository.rollback()
            raise Exception(f"Erro ao atualizar usuário: {str(e)}")

    async def change_password(
        self,
        user_id: UUID,
        dto: ChangePasswordDTO,
        skip_current_check: bool = False,
    ) -> UserResponseDTO:
        """
        Trocar senha do usuário.

        Args:
            user_id: UUID do usuário
            dto: ChangePasswordDTO com senha atual e nova senha
            skip_current_check: Se True, não verifica a senha atual (uso exclusivo de admin
                alterando a senha de outro usuário)

        Returns:
            UserResponseDTO: Usuário com senha atualizada

        Raises:
            UserNotFoundError: Se usuário não encontrado
            InvalidCredentialsError: Se senha atual incorreta
        """
        user = await self.repository.get_by_id_all_states(user_id)
        if not user:
            raise UserNotFoundError(f"Usuário com ID {user_id} não encontrado")

        if not skip_current_check and not self.verify_password(dto.current_password, user.password):
            raise InvalidCredentialsError("Senha atual incorreta")

        user.password = self.hash_password(dto.new_password)

        try:
            updated_user = await self.repository.update(user)
            await self.repository.commit()
            return UserResponseDTO.model_validate(updated_user)
        except Exception as e:
            await self.repository.rollback()
            raise Exception(f"Erro ao trocar senha: {str(e)}")

    async def delete(self, user_id: UUID) -> bool:
        """
        Deletar usuário (soft delete).

        Args:
            user_id: UUID do usuário

        Returns:
            bool: True se deletado

        Raises:
            UserNotFoundError: Se usuário não encontrado
        """
        deleted = await self.repository.delete(user_id)
        if not deleted:
            raise UserNotFoundError(f"Usuário com ID {user_id} não encontrado")

        await self.repository.commit()
        return True

    async def get_by_email(self, email: str) -> Optional[UserResponseDTO]:
        """
        Buscar usuário por email (apenas ativos).

        Args:
            email: Email do usuário

        Returns:
            UserResponseDTO ou None
        """
        user = await self.repository.get_by_email(email)
        if not user:
            return None
        return UserResponseDTO.model_validate(user)

    async def list_students_for_trainer(
        self,
        trainer_id: UUID = None,
        page: int = 1,
        limit: int = 10,
    ) -> Tuple[List[UserResponseDTO], int]:
        """
        Listar alunos (clientes) de um personal trainer específico ou todos.

        Args:
            trainer_id: UUID do personal trainer. Se None, retorna todos os alunos
            page: Número da página
            limit: Itens por página

        Returns:
            Tuple[List[UserResponseDTO], int]: Lista de alunos e total
        """
        users, total = await self.repository.list_by_trainer(trainer_id, page, limit)
        user_dtos = [UserResponseDTO.model_validate(user) for user in users]
        return user_dtos, total
