"""
Rotas HTTP para gerenciamento de convites de acesso.

Endpoints:
- POST /api/v1/invitations → Gerar novo convite (personal_trainer ou admin)
- POST /api/v1/invitations/validate → Validar código (público)
- GET /api/v1/invitations → Listar meus convites (personal_trainer ou admin)
- GET /api/v1/invitations/whatsapp-pending → Listar pré-cadastros aguardando aprovação (admin)
- POST /api/v1/invitations/whatsapp-approve → Aprovar pré-cadastro e enviar código (admin)
"""

from sqlalchemy import select
from fastapi import APIRouter, HTTPException, Depends, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.user import User
from app.models.whatsapp_pre_registration import WhatsAppPreRegistration
from app.dtos.invitation_dto import (
    ApproveWhatsAppDTO,
    GenerateInvitationDTO,
    ValidateInvitationDTO,
    InvitationResponseDTO,
    ListInvitationsResponseDTO,
    ValidateInvitationResponseDTO,
    WhatsAppPendingItemDTO,
    WhatsAppPendingListDTO,
    WhatsAppPrefillResponseDTO,
)
from app.services.invitation_service import InvitationService
from app.services.whatsapp_service import WhatsAppService
from app.config.database import get_db
from app.dependencies.auth import get_current_user

_ALLOWED_ROLES = {"personal_trainer", "admin"}

router = APIRouter(
    prefix="/api/v1/invitations",
    tags=["invitations"],
    responses={
        400: {"description": "Requisição inválida"},
        401: {"description": "Não autenticado"},
        403: {"description": "Acesso negado"},
        500: {"description": "Erro interno do servidor"},
    },
)


@router.post(
    "",
    response_model=InvitationResponseDTO,
    status_code=status.HTTP_201_CREATED,
    summary="Gerar novo convite",
)
async def generate_invitation(
    dto: GenerateInvitationDTO,
    current_user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_db),
) -> InvitationResponseDTO:
    """Gerar novo código de convite. Permitido para personal_trainer e admin."""
    if current_user.role not in _ALLOWED_ROLES:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Apenas personal trainers e admins podem gerar convites",
        )

    service = InvitationService(session)
    try:
        return await service.generate(current_user.id)
    except Exception:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Erro ao gerar convite",
        )


@router.post(
    "/validate",
    response_model=ValidateInvitationResponseDTO,
    status_code=status.HTTP_200_OK,
    summary="Validar código de convite",
)
async def validate_invitation(
    dto: ValidateInvitationDTO,
    session: AsyncSession = Depends(get_db),
) -> ValidateInvitationResponseDTO:
    """Validar um código de convite. Público, sem autenticação."""
    service = InvitationService(session)
    is_valid = await service.validate(dto.code)

    if is_valid:
        return ValidateInvitationResponseDTO(
            valid=True,
            code=dto.code,
            message="Código válido e pronto para usar",
        )
    return ValidateInvitationResponseDTO(
        valid=False,
        code=None,
        message="Código inválido, expirado ou já utilizado",
    )


@router.get(
    "",
    response_model=ListInvitationsResponseDTO,
    status_code=status.HTTP_200_OK,
    summary="Listar meus convites",
)
async def list_invitations(
    current_user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_db),
) -> ListInvitationsResponseDTO:
    """Listar convites gerados. Permitido para personal_trainer e admin."""
    if current_user.role not in _ALLOWED_ROLES:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Apenas personal trainers e admins podem listar convites",
        )

    service = InvitationService(session)
    try:
        return await service.list_by_trainer(current_user.id)
    except Exception:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Erro ao listar convites",
        )


@router.get(
    "/whatsapp-prefill",
    response_model=WhatsAppPrefillResponseDTO,
    status_code=status.HTTP_200_OK,
    summary="Buscar dados do pré-cadastro WhatsApp pelo código de convite (público)",
)
async def whatsapp_prefill(
    code: str,
    session: AsyncSession = Depends(get_db),
) -> WhatsAppPrefillResponseDTO:
    """
    Retorna nome, email e telefone do pré-cadastro WhatsApp vinculado ao código.

    Chamado pelo app quando o usuário digita o código de convite na tela de cadastro.
    Se não houver pré-cadastro vinculado, retorna found=false sem erro — o usuário
    simplesmente preenche os campos manualmente.
    """
    result = await session.execute(
        select(WhatsAppPreRegistration).where(
            WhatsAppPreRegistration.invitation_code == code.upper(),
            WhatsAppPreRegistration.state == "approved",
        )
    )
    pre_reg = result.scalar_one_or_none()

    if not pre_reg:
        return WhatsAppPrefillResponseDTO(found=False)

    return WhatsAppPrefillResponseDTO(
        found=True,
        name=pre_reg.name,
        email=pre_reg.email,
        phone=pre_reg.phone,
    )


@router.get(
    "/whatsapp-pending",
    response_model=WhatsAppPendingListDTO,
    status_code=status.HTTP_200_OK,
    summary="Listar pré-cadastros WhatsApp aguardando aprovação (admin)",
)
async def list_whatsapp_pending(
    current_user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_db),
) -> WhatsAppPendingListDTO:
    """Retorna todos os pré-cadastros via WhatsApp com estado pending_approval."""
    if current_user.role != "admin":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Apenas admins podem ver pré-cadastros pendentes",
        )

    result = await session.execute(
        select(WhatsAppPreRegistration).where(
            WhatsAppPreRegistration.state == "pending_approval"
        )
    )
    rows = result.scalars().all()

    items = [WhatsAppPendingItemDTO.model_validate(r) for r in rows]
    return WhatsAppPendingListDTO(total=len(items), items=items)


@router.post(
    "/whatsapp-approve",
    response_model=InvitationResponseDTO,
    status_code=status.HTTP_201_CREATED,
    summary="Aprovar pré-cadastro WhatsApp e enviar código (admin)",
)
async def approve_whatsapp_registration(
    dto: ApproveWhatsAppDTO,
    current_user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_db),
) -> InvitationResponseDTO:
    """
    Aprova um pré-cadastro via WhatsApp:
    1. Valida que o personal trainer selecionado existe e está ativo
    2. Valida que o pagamento foi confirmado (ou é pré-cadastro sem pagamento)
    3. Invalida convite anterior se existir (evita múltiplos tokens válidos)
    4. Gera novo código de convite vinculado ao personal trainer
    5. Envia o código ao usuário via WhatsApp
    """
    if current_user.role != "admin":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Apenas admins podem aprovar pré-cadastros",
        )

    # Validar personal trainer
    trainer_result = await session.execute(
        select(User).where(User.id == dto.trainer_id)
    )
    trainer = trainer_result.scalar_one_or_none()
    if not trainer or trainer.role != "personal_trainer" or not trainer.is_active:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="Personal trainer inválido, inativo ou não encontrado",
        )

    # Buscar pré-cadastro pendente
    pre_reg_result = await session.execute(
        select(WhatsAppPreRegistration).where(
            WhatsAppPreRegistration.phone == dto.phone,
            WhatsAppPreRegistration.state == "pending_approval",
        )
    )
    pre_reg = pre_reg_result.scalar_one_or_none()

    if not pre_reg:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Pré-cadastro não encontrado ou já aprovado",
        )

    # Gate de pagamento: bloquear aprovação se pagamento pendente
    if pre_reg.payment_status == "pending":
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="Pagamento ainda não confirmado. Aguarde a confirmação para aprovar.",
        )

    # Invalidar convite anterior para evitar múltiplos tokens válidos
    if pre_reg.invitation_code:
        from app.repositories.invitation_repository import InvitationRepository
        inv_repo = InvitationRepository(session)
        old_invitation = await inv_repo.get_by_code(pre_reg.invitation_code)
        if old_invitation and not old_invitation.used:
            old_invitation.used = True
            await session.flush()

    invitation_service = InvitationService(session)
    invitation = await invitation_service.generate(dto.trainer_id)

    whatsapp_service = WhatsAppService(session)
    await whatsapp_service.send_approval_code(dto.phone, invitation.code)

    return invitation
