"""
Rotas HTTP para gerenciamento de convites de acesso.

Endpoints:
- POST /api/v1/invitations → Gerar novo convite (apenas personal_trainer)
- POST /api/v1/invitations/validate → Validar código (público)
- GET /api/v1/invitations → Listar meus convites (apenas personal_trainer)
"""

from fastapi import APIRouter, HTTPException, Depends, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.user import User
from app.dtos.invitation_dto import (
    GenerateInvitationDTO,
    ValidateInvitationDTO,
    InvitationResponseDTO,
    ListInvitationsResponseDTO,
    ValidateInvitationResponseDTO,
)
from app.services.invitation_service import InvitationService
from app.config.database import get_db
from app.dependencies.auth import get_current_user


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
    responses={
        201: {"description": "Convite gerado com sucesso"},
        401: {"description": "Não autenticado"},
        403: {"description": "Apenas personal_trainer pode gerar convites"},
    },
)
async def generate_invitation(
    dto: GenerateInvitationDTO,
    current_user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_db),
) -> InvitationResponseDTO:
    """
    Gerar novo código de convite.

    Apenas personal trainers podem gerar convites.
    O código gerado é único e pode ser compartilhado com alunos.

    **Requer autenticação:** Usuário deve ter role=personal_trainer

    **Response:**
    - 201: Código gerado (10 caracteres aleatórios)
    - 403: Usuário não é personal_trainer
    """
    if current_user.role != "personal_trainer":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Apenas personal trainers podem gerar convites",
        )

    service = InvitationService(session)

    try:
        return await service.generate(current_user.id)
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Erro ao gerar convite",
        )


@router.post(
    "/validate",
    response_model=ValidateInvitationResponseDTO,
    status_code=status.HTTP_200_OK,
    summary="Validar código de convite",
    responses={
        200: {"description": "Validação concluída"},
        400: {"description": "Código inválido ou já utilizado"},
    },
)
async def validate_invitation(
    dto: ValidateInvitationDTO,
    session: AsyncSession = Depends(get_db),
) -> ValidateInvitationResponseDTO:
    """
    Validar um código de convite.

    Pode ser chamado sem autenticação (para usar na tela de cadastro do aluno).

    **Request body:**
    - code: Código a validar

    **Response:**
    - valid: true se o código é válido
    - message: Descrição do status
    """
    service = InvitationService(session)
    is_valid = await service.validate(dto.code)

    if is_valid:
        return ValidateInvitationResponseDTO(
            valid=True,
            code=dto.code,
            message="Código válido e pronto para usar",
        )
    else:
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
    responses={
        200: {"description": "Lista de convites retornada"},
        401: {"description": "Não autenticado"},
        403: {"description": "Apenas personal_trainer pode listar"},
    },
)
async def list_invitations(
    current_user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_db),
) -> ListInvitationsResponseDTO:
    """
    Listar todos os convites gerados pelo personal trainer autenticado.

    **Requer autenticação:** Apenas personal_trainer

    **Response:**
    - total: Total de convites gerados
    - pending: Quantos ainda não foram usados
    - used: Quantos já foram usados
    - invitations: Lista detalhada dos convites
    """
    if current_user.role != "personal_trainer":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Apenas personal trainers podem listar convites",
        )

    service = InvitationService(session)

    try:
        return await service.list_by_trainer(current_user.id)
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Erro ao listar convites",
        )
