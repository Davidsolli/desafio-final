"""
Serviço do módulo de Dieta.

Camada de lógica de negócio para alimentos personalizados e dietas
(prescrição e personalização), incluindo cálculo automático de macros.
"""

from typing import List, Optional
from uuid import UUID

from sqlalchemy.ext.asyncio import AsyncSession

from app.dtos.diet_dto import (
    CreateCustomFoodDTO,
    CreateDietDTO,
    CustomFoodResponseDTO,
    DietItemCreateDTO,
    DietItemResponseDTO,
    DietListItemDTO,
    DietMealCreateDTO,
    DietMealResponseDTO,
    DietResponseDTO,
    DuplicateDietDTO,
    PaginatedDietsDTO,
    UpdateDietDTO,
)
from app.models.diet import CustomFood, Diet, DietItem, DietMeal
from app.repositories.diet_repository import DietRepository


# ---------------------------------------------------------------------------
# Exceções de Negócio
# ---------------------------------------------------------------------------


class DietNotFoundError(Exception):
    """Dieta não encontrada."""


class DietForbiddenError(Exception):
    """Usuário não tem permissão para esta operação."""


class DietValidationError(Exception):
    """Validação de negócio falhou."""


# ---------------------------------------------------------------------------
# Papéis com permissão de prescrição
# ---------------------------------------------------------------------------

WRITE_ROLES = {"admin", "personal_trainer", "professor", "gestor"}


# ---------------------------------------------------------------------------
# Serviço Principal
# ---------------------------------------------------------------------------


class DietService:
    """Serviço de lógica de negócio para Dietas e Alimentos Personalizados."""

    def __init__(self, session: AsyncSession) -> None:
        self.session = session
        self.repository = DietRepository(session)

    # ------------------------------------------------------------------
    # Custom Foods
    # ------------------------------------------------------------------

    async def create_custom_food(
        self, user_id: UUID, dto: CreateCustomFoodDTO
    ) -> CustomFoodResponseDTO:
        """
        Cria um alimento personalizado para o usuário.

        Qualquer usuário autenticado (aluno ou personal) pode criar.
        """
        food = CustomFood(
            user_id=user_id,
            name=dto.name,
            category=dto.category,
            energy_kcal=dto.energy_kcal,
            protein_g=dto.protein_g,
            carbohydrate_g=dto.carbohydrate_g,
            lipid_g=dto.lipid_g,
            fiber_g=dto.fiber_g,
        )
        created = await self.repository.create_custom_food(food)
        await self.repository.commit()
        return CustomFoodResponseDTO.model_validate(created)

    async def list_custom_foods(
        self, user_id: UUID, search: Optional[str] = None
    ) -> List[CustomFoodResponseDTO]:
        """Lista alimentos personalizados do usuário."""
        foods = await self.repository.list_custom_foods(user_id, search)
        return [CustomFoodResponseDTO.model_validate(f) for f in foods]

    # ------------------------------------------------------------------
    # Criar Dieta
    # ------------------------------------------------------------------

    async def create_diet(
        self, requester_id: UUID, role: str, dto: CreateDietDTO
    ) -> DietResponseDTO:
        """
        Cria uma nova dieta.

        Regras:
        - Personal/Admin: is_custom=False (Dieta Prescrita). Desativa prescrita anterior.
        - Client: is_custom=True (Dieta Personalizada). Desativa custom anterior.
          O client só pode criar dieta para si mesmo (user_id == requester_id).
        """
        if role == "client":
            # Aluno só pode criar dieta para si mesmo
            if dto.user_id != requester_id:
                raise DietForbiddenError(
                    "Aluno só pode criar dieta personalizada para si mesmo."
                )
            is_custom = True
            professional_id = None
        elif role in WRITE_ROLES:
            is_custom = False
            professional_id = requester_id
        else:
            raise DietForbiddenError(
                "Você não tem permissão para criar dietas."
            )

        # RN-01: desativar dietas anteriores do mesmo tipo
        await self.repository.deactivate_diets(dto.user_id, is_custom)

        # Construir meals e items
        meals = self._build_meals(dto.meals)

        diet = Diet(
            user_id=dto.user_id,
            professional_id=professional_id,
            is_custom=is_custom,
            name=dto.name,
            goal=dto.goal,
            is_active=True,
            meals=meals,
            water_target_ml=dto.water_target_ml,
        )

        created = await self.repository.create_diet(diet)
        await self.repository.commit()
        return await self._to_response(created)

    # ------------------------------------------------------------------
    # Listar Dietas
    # ------------------------------------------------------------------

    async def list_diets(
        self,
        requester_id: UUID,
        role: str,
        user_id_filter: Optional[UUID],
        is_custom: Optional[bool],
        page: int,
        limit: int,
    ) -> PaginatedDietsDTO:
        """
        Lista dietas com filtros e paginação.

        - Client só vê suas próprias dietas.
        - Personal/Admin pode filtrar por user_id.
        """
        if role == "client":
            effective_user_id = requester_id
        else:
            effective_user_id = user_id_filter or requester_id

        diets, total = await self.repository.list_diets(
            user_id=effective_user_id,
            is_custom=is_custom,
            page=page,
            limit=limit,
        )

        items = []
        for d in diets:
            # Calcular total kcal para listagem
            total_kcal = await self._calculate_diet_kcal(d)

            # Obter ou calcular meta de água
            water_target = d.water_target_ml
            if water_target is None or water_target == 0:
                from app.models.user import User
                user_obj = await self.session.get(User, d.user_id)
                if user_obj and user_obj.weight:
                    water_target = int(user_obj.weight * 35)
                else:
                    water_target = 2500

            items.append(
                DietListItemDTO(
                    id=d.id,
                    user_id=d.user_id,
                    professional_id=d.professional_id,
                    is_custom=d.is_custom,
                    name=d.name,
                    goal=d.goal,
                    is_active=d.is_active,
                    meal_count=len(d.meals) if d.meals else 0,
                    total_kcal=total_kcal,
                    created_at=d.created_at,
                    water_target_ml=water_target,
                )
            )

        return PaginatedDietsDTO(total=total, page=page, limit=limit, data=items)

    # ------------------------------------------------------------------
    # Buscar Dieta por ID
    # ------------------------------------------------------------------

    async def get_diet(
        self, diet_id: UUID, requester_id: UUID, role: str
    ) -> DietResponseDTO:
        """Busca dieta com controle de acesso e cálculo de macros."""
        diet = await self._get_and_check_read(diet_id, requester_id, role)
        return await self._to_response(diet)

    # ------------------------------------------------------------------
    # Atualizar Dieta
    # ------------------------------------------------------------------

    async def update_diet(
        self, diet_id: UUID, requester_id: UUID, role: str, dto: UpdateDietDTO
    ) -> DietResponseDTO:
        """
        Atualiza uma dieta existente.

        - Personal/Admin podem editar dietas prescritas.
        - Client pode editar apenas dietas personalizadas.
        """
        diet = await self._get_and_check_write(diet_id, requester_id, role)

        if dto.name is not None:
            diet.name = dto.name
        if dto.goal is not None:
            diet.goal = dto.goal
        if dto.water_target_ml is not None:
            diet.water_target_ml = dto.water_target_ml

        # Substituição total de refeições
        if dto.meals is not None:
            await self.repository.delete_meals_from_diet(diet_id)
            diet.meals = self._build_meals(dto.meals)

        updated = await self.repository.update_diet(diet)
        await self.repository.commit()
        return await self._to_response(updated)

    # ------------------------------------------------------------------
    # Deletar Dieta (soft delete)
    # ------------------------------------------------------------------

    async def delete_diet(
        self, diet_id: UUID, requester_id: UUID, role: str
    ) -> None:
        """Soft delete da dieta."""
        await self._get_and_check_write(diet_id, requester_id, role)

        deleted = await self.repository.soft_delete_diet(diet_id)
        if not deleted:
            raise DietNotFoundError("Dieta não encontrada.")

        await self.repository.commit()

    # ------------------------------------------------------------------
    # Duplicar Dieta
    # ------------------------------------------------------------------

    async def duplicate_diet(
        self, diet_id: UUID, requester_id: UUID, role: str, dto: DuplicateDietDTO
    ) -> DietResponseDTO:
        """
        Duplica uma dieta existente.

        Apenas Personal/Admin podem duplicar.
        """
        if role not in WRITE_ROLES:
            raise DietForbiddenError("Apenas profissionais podem duplicar dietas.")

        original = await self.repository.get_diet_by_id(diet_id)
        if not original:
            raise DietNotFoundError("Dieta não encontrada.")

        target_user_id = dto.user_id or original.user_id
        new_name = dto.name or f"{original.name} (Cópia)"

        # RN-01: desativar prescritas anteriores do aluno destino
        await self.repository.deactivate_diets(target_user_id, is_custom=False)

        # Clonar meals e items
        cloned_meals = []
        for meal in (original.meals or []):
            cloned_items = [
                DietItem(
                    food_id=item.food_id,
                    custom_food_id=item.custom_food_id,
                    quantity_g=item.quantity_g,
                    observations=item.observations,
                )
                for item in (meal.items or [])
            ]
            cloned_meals.append(
                DietMeal(
                    name=meal.name,
                    time=meal.time,
                    order=meal.order,
                    items=cloned_items,
                )
            )

        new_diet = Diet(
            user_id=target_user_id,
            professional_id=requester_id,
            is_custom=False,
            name=new_name,
            goal=original.goal,
            is_active=True,
            meals=cloned_meals,
            water_target_ml=original.water_target_ml,
        )

        created = await self.repository.create_diet(new_diet)
        await self.repository.commit()
        return await self._to_response(created)

    # ------------------------------------------------------------------
    # Helpers Privados
    # ------------------------------------------------------------------

    async def _get_and_check_read(
        self, diet_id: UUID, requester_id: UUID, role: str
    ) -> Diet:
        """Busca a dieta e valida acesso de leitura."""
        diet = await self.repository.get_diet_by_id(diet_id)
        if not diet:
            raise DietNotFoundError("Dieta não encontrada.")

        if role == "client" and diet.user_id != requester_id:
            raise DietForbiddenError(
                "Você não tem permissão para visualizar esta dieta."
            )

        return diet

    async def _get_and_check_write(
        self, diet_id: UUID, requester_id: UUID, role: str
    ) -> Diet:
        """Busca a dieta e valida acesso de escrita."""
        diet = await self.repository.get_diet_by_id(diet_id)
        if not diet:
            raise DietNotFoundError("Dieta não encontrada.")

        if role == "client":
            # Client só edita suas dietas customizadas
            if diet.user_id != requester_id or not diet.is_custom:
                raise DietForbiddenError(
                    "Aluno só pode editar suas próprias dietas personalizadas."
                )
        elif role not in WRITE_ROLES:
            raise DietForbiddenError("Sem permissão para editar dietas.")

        return diet

    @staticmethod
    def _build_meals(meal_dtos: List[DietMealCreateDTO]) -> List[DietMeal]:
        """Constrói instâncias de DietMeal+DietItem a partir de DTOs."""
        meals = []
        for mdto in meal_dtos:
            items = [
                DietItem(
                    food_id=idto.food_id,
                    custom_food_id=idto.custom_food_id,
                    quantity_g=idto.quantity_g,
                    observations=idto.observations,
                )
                for idto in mdto.items
            ]
            meals.append(
                DietMeal(
                    name=mdto.name,
                    time=mdto.time,
                    order=mdto.order,
                    items=items,
                )
            )
        return meals

    async def _calculate_diet_kcal(self, diet: Diet) -> float:
        """Calcula total de kcal de uma dieta somando todos os itens."""
        total = 0.0
        for meal in (diet.meals or []):
            for item in (meal.items or []):
                food_data = await self._get_food_data(item)
                if food_data:
                    total += food_data["energy_kcal"] * (item.quantity_g / 100.0)
        return round(total, 2)

    async def _get_food_data(self, item: DietItem) -> Optional[dict]:
        """Busca dados nutricionais do alimento (TACO ou Custom)."""
        if item.food_id is not None:
            food = await self.repository.get_food_by_id(item.food_id)
            if food:
                return {
                    "name": food.name,
                    "energy_kcal": food.energy_kcal,
                    "protein_g": food.protein_g,
                    "carbohydrate_g": food.carbohydrate_g,
                    "lipid_g": food.lipid_g,
                }
        if item.custom_food_id is not None:
            food = await self.repository.get_custom_food_by_id(item.custom_food_id)
            if food:
                return {
                    "name": food.name,
                    "energy_kcal": food.energy_kcal,
                    "protein_g": food.protein_g,
                    "carbohydrate_g": food.carbohydrate_g,
                    "lipid_g": food.lipid_g,
                }
        return None

    async def _to_response(self, diet: Diet) -> DietResponseDTO:
        """Converte Diet para DietResponseDTO com macros calculados."""
        total_kcal = 0.0
        total_protein = 0.0
        total_carbs = 0.0
        total_fats = 0.0

        meal_dtos = []
        for meal in sorted(diet.meals or [], key=lambda m: m.order):
            sub_kcal = 0.0
            sub_protein = 0.0
            sub_carbs = 0.0
            sub_fats = 0.0

            item_dtos = []
            for item in (meal.items or []):
                food_data = await self._get_food_data(item)
                if food_data:
                    ratio = item.quantity_g / 100.0
                    kcal = round(food_data["energy_kcal"] * ratio, 2)
                    protein = round(food_data["protein_g"] * ratio, 2)
                    carbs = round(food_data["carbohydrate_g"] * ratio, 2)
                    fats = round(food_data["lipid_g"] * ratio, 2)
                    name = food_data["name"]
                else:
                    kcal = protein = carbs = fats = 0.0
                    name = "Alimento desconhecido"

                sub_kcal += kcal
                sub_protein += protein
                sub_carbs += carbs
                sub_fats += fats

                item_dtos.append(
                    DietItemResponseDTO(
                        id=item.id,
                        meal_id=item.meal_id,
                        food_id=item.food_id,
                        custom_food_id=item.custom_food_id,
                        food_name=name,
                        quantity_g=item.quantity_g,
                        observations=item.observations,
                        kcal=kcal,
                        protein=protein,
                        carbs=carbs,
                        fats=fats,
                    )
                )

            total_kcal += sub_kcal
            total_protein += sub_protein
            total_carbs += sub_carbs
            total_fats += sub_fats

            meal_dtos.append(
                DietMealResponseDTO(
                    id=meal.id,
                    diet_id=meal.diet_id,
                    name=meal.name,
                    time=meal.time,
                    order=meal.order,
                    items=item_dtos,
                    subtotal_kcal=round(sub_kcal, 2),
                    subtotal_protein=round(sub_protein, 2),
                    subtotal_carbs=round(sub_carbs, 2),
                    subtotal_fats=round(sub_fats, 2),
                )
            )

        # Obter ou calcular meta de água
        water_target = diet.water_target_ml
        if water_target is None or water_target == 0:
            from app.models.user import User
            user_obj = await self.session.get(User, diet.user_id)
            if user_obj and user_obj.weight:
                water_target = int(user_obj.weight * 35)
            else:
                water_target = 2500

        return DietResponseDTO(
            id=diet.id,
            user_id=diet.user_id,
            professional_id=diet.professional_id,
            is_custom=diet.is_custom,
            name=diet.name,
            goal=diet.goal,
            is_active=diet.is_active,
            created_at=diet.created_at,
            updated_at=diet.updated_at,
            meals=meal_dtos,
            total_kcal=round(total_kcal, 2),
            total_protein=round(total_protein, 2),
            total_carbs=round(total_carbs, 2),
            total_fats=round(total_fats, 2),
            water_target_ml=water_target,
        )
