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
    1. Gera um código de convite
    2. Vincula ao pré-cadastro
    3. Envia o código ao usuário via WhatsApp
    """
    if current_user.role != "admin":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Apenas admins podem aprovar pré-cadastros",
        )

    result = await session.execute(
        select(WhatsAppPreRegistration).where(
            WhatsAppPreRegistration.phone == dto.phone,
            WhatsAppPreRegistration.state == "pending_approval",
        )
    )
    pre_reg = result.scalar_one_or_none()

    if not pre_reg:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Pré-cadastro não encontrado ou já aprovado",
        )

    invitation_service = InvitationService(session)
    invitation = await invitation_service.generate(current_user.id)

    whatsapp_service = WhatsAppService(session)
    await whatsapp_service.send_approval_code(dto.phone, invitation.code)

    return invitation
