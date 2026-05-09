"""
Seed inicial de dados de dominio (usuarios, metas, treino e dieta).

Popula dados realistas e relacionados para facilitar testes manuais do
frontend/backend sem depender de mocks.
"""

import asyncio
import logging
import os
import random
import sys
from datetime import date, datetime, timedelta
from typing import Dict, List, Sequence

import bcrypt
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession, create_async_engine
from sqlalchemy.orm import sessionmaker

# Adiciona o backend ao path
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from app.config.settings import settings
from app.models.diet import Diet, DietItem, DietMeal
from app.models.diet_logbook import DietLogbook, DietLogbookEntry
from app.models.exercise_catalog import ExerciseCatalog
from app.models.food_catalog import FoodCatalog
from app.models.goal import Goal, GoalProgressEntry
from app.models.logbook import SessionExercise, WorkoutSession
from app.models.user import User
from app.models.workout_sheet import Exercise, WorkoutSheet

logger = logging.getLogger(__name__)
RNG = random.Random(42)


def hash_password(password: str) -> str:
    """Hash de senha usando bcrypt."""
    salt = bcrypt.gensalt(rounds=12)
    return bcrypt.hashpw(password.encode(), salt).decode()


async def get_or_create_user(
    session: AsyncSession,
    *,
    name: str,
    email: str,
    password: str,
    role: str,
    trainer_id=None,
    weight=None,
    height=None,
    age=None,
    gender=None,
    phone_whatsapp=None,
    goal_type=None,
) -> User:
    """Busca usuario por email; cria se nao existir."""
    result = await session.execute(select(User).where(User.email == email))
    existing = result.scalars().first()
    if existing:
        # Atualiza dados basicos para manter seed consistente.
        existing.name = name
        existing.role = role
        existing.is_active = True
        existing.trainer_id = trainer_id
        existing.weight = weight
        existing.height = height
        existing.age = age
        existing.gender = gender
        existing.phone_whatsapp = phone_whatsapp
        existing.goal_type = goal_type
        # Atualiza senha apenas quando usuario ainda nao possui hash bcrypt valido.
        if not (existing.password or "").startswith("$2"):
            existing.password = hash_password(password)
        await session.flush()
        return existing

    user = User(
        name=name,
        email=email,
        password=hash_password(password),
        role=role,
        is_active=True,
        trainer_id=trainer_id,
        weight=weight,
        height=height,
        age=age,
        gender=gender,
        phone_whatsapp=phone_whatsapp,
        goal_type=goal_type,
    )
    session.add(user)
    await session.flush()
    return user


def _sample_unique(candidates: Sequence, count: int) -> List:
    """Seleciona elementos sem repeticao com fallback para quantidade disponivel."""
    if not candidates:
        return []
    if len(candidates) <= count:
        return list(candidates)
    return RNG.sample(list(candidates), k=count)


async def _build_exercise_template(
    session: AsyncSession,
    student_index: int,
) -> List[Dict]:
    """
    Monta template de exercicios com base no exercise_catalog.

    Usa grupos musculares para manter ficha equilibrada.
    """
    target_groups = ["perna_anterior", "peito", "costa"]
    selected_templates: List[Dict] = []

    for group in target_groups:
        result = await session.execute(
            select(ExerciseCatalog).where(ExerciseCatalog.muscle_group_mapped == group)
        )
        catalog_rows = result.scalars().all()
        chosen = _sample_unique(catalog_rows, 1)
        if not chosen:
            continue
        row = chosen[0]
        selected_templates.append(
            {
                "name": row.name,
                "group": row.muscle_group_mapped or group,
                "series": 4 if group in {"perna_anterior", "peito"} else 3,
                "reps": 10 if group != "costa" else 12,
                "load": 28.0 + (student_index * 2),
                "obs": f"Baseado no catalogo: {row.id}",
            }
        )

    if selected_templates:
        return selected_templates

    logger.warning("[seed_domain] exercise_catalog vazio. Aplicando fallback de exercicios.")
    return [
        {"name": "Agachamento Livre", "group": "perna_anterior", "series": 4, "reps": 10, "load": 45.0, "obs": "Fallback"},
        {"name": "Supino Reto", "group": "peito", "series": 4, "reps": 8, "load": 35.0, "obs": "Fallback"},
        {"name": "Remada Curvada", "group": "costa", "series": 3, "reps": 12, "load": 28.0, "obs": "Fallback"},
    ]


async def _pick_foods_for_meals(session: AsyncSession) -> Dict[str, FoodCatalog]:
    """Escolhe alimentos da TACO para cafe da manha e almoco."""
    breakfast_keywords = ["leite", "aveia", "banana", "pao", "ovo", "iogurte"]
    lunch_keywords = ["arroz", "frango", "feijao", "patinho", "batata", "peixe"]

    breakfast_pool: List[FoodCatalog] = []
    lunch_pool: List[FoodCatalog] = []

    all_foods_result = await session.execute(select(FoodCatalog))
    all_foods = all_foods_result.scalars().all()
    if not all_foods:
        logger.warning("[seed_domain] food_catalog vazio. Itens de dieta nao serao criados.")
        return {}

    for food in all_foods:
        name = (food.name or "").lower()
        if any(keyword in name for keyword in breakfast_keywords):
            breakfast_pool.append(food)
        if any(keyword in name for keyword in lunch_keywords):
            lunch_pool.append(food)

    # Fallback para qualquer alimento caso filtros sejam muito restritivos.
    if not breakfast_pool:
        breakfast_pool = all_foods
    if not lunch_pool:
        lunch_pool = all_foods

    breakfast_choice = _sample_unique(breakfast_pool, 1)[0]
    lunch_choice = _sample_unique(lunch_pool, 1)[0]
    return {"breakfast": breakfast_choice, "lunch": lunch_choice}


def _macro_by_quantity(per_100g: float, quantity_g: float) -> float:
    return round((per_100g or 0.0) * quantity_g / 100.0, 2)


def _resolve_admin_bootstrap() -> Dict[str, str]:
    """
    Resolve credenciais do admin com fallback para ambiente de desenvolvimento.

    Mantem o seed funcional mesmo se o time esquecer de atualizar o .env.
    """
    defaults = {
        "ADMIN_NAME": "Administrador OmniConnect",
        "ADMIN_EMAIL": "admin@omniconnect.fit",
        "ADMIN_PASSWORD": "AdminForte123!",
    }
    values = {}
    missing_keys = []
    for key, default_value in defaults.items():
        raw = os.getenv(key)
        if raw is None or not raw.strip():
            missing_keys.append(key)
            values[key] = default_value
        else:
            values[key] = raw.strip()

    if missing_keys:
        logger.warning(
            "[seed_domain] Variaveis %s ausentes no .env. Usando valores padrao de dev.",
            ", ".join(missing_keys),
        )
    return values


async def seed(force: bool = False) -> None:
    """
    Popula base com admin, personais e alunos com dados correlacionados.

    Se force=True, remove dados de dominio antes de recriar.
    """
    engine = create_async_engine(settings.DATABASE_URL, echo=False)
    async_session = sessionmaker(engine, class_=AsyncSession, expire_on_commit=False)

    async with async_session() as session:
        if force:
            for model in (
                SessionExercise,
                WorkoutSession,
                GoalProgressEntry,
                Goal,
                DietLogbookEntry,
                DietLogbook,
                DietItem,
                DietMeal,
                Diet,
                Exercise,
                WorkoutSheet,
            ):
                rows = await session.execute(select(model))
                for row in rows.scalars().all():
                    await session.delete(row)
            await session.commit()

        admin_bootstrap = _resolve_admin_bootstrap()
        admin = await get_or_create_user(
            session,
            name=admin_bootstrap["ADMIN_NAME"],
            email=admin_bootstrap["ADMIN_EMAIL"],
            password=admin_bootstrap["ADMIN_PASSWORD"],
            role="admin",
            phone_whatsapp="+55 11 90000-0000",
        )

        trainers: Dict[str, User] = {}
        trainers["camila"] = await get_or_create_user(
            session,
            name="Camila Rocha",
            email="camila.personal@omniconnect.fit",
            password="TreinoForte123!",
            role="personal_trainer",
            age=31,
            gender="female",
            phone_whatsapp="+55 11 98888-1010",
        )
        trainers["rafael"] = await get_or_create_user(
            session,
            name="Rafael Lima",
            email="rafael.personal@omniconnect.fit",
            password="TreinoForte123!",
            role="personal_trainer",
            age=34,
            gender="male",
            phone_whatsapp="+55 21 97777-2020",
        )

        students: List[User] = []
        students.append(
            await get_or_create_user(
                session,
                name="Bruno Martins",
                email="bruno.aluno@omniconnect.fit",
                password="AlunoForte123!",
                role="client",
                trainer_id=trainers["camila"].id,
                weight=92.0,
                height=180.0,
                age=29,
                gender="male",
                phone_whatsapp="+55 11 96666-1111",
                goal_type="lose_weight",
            )
        )
        students.append(
            await get_or_create_user(
                session,
                name="Juliana Costa",
                email="juliana.aluna@omniconnect.fit",
                password="AlunoForte123!",
                role="client",
                trainer_id=trainers["camila"].id,
                weight=61.0,
                height=165.0,
                age=26,
                gender="female",
                phone_whatsapp="+55 11 96666-2222",
                goal_type="gain_mass",
            )
        )
        students.append(
            await get_or_create_user(
                session,
                name="Leonardo Souza",
                email="leonardo.aluno@omniconnect.fit",
                password="AlunoForte123!",
                role="client",
                trainer_id=trainers["rafael"].id,
                weight=79.0,
                height=173.0,
                age=35,
                gender="male",
                phone_whatsapp="+55 21 95555-3333",
                goal_type="maintenance",
            )
        )
        students.append(
            await get_or_create_user(
                session,
                name="Patricia Nunes",
                email="patricia.aluna@omniconnect.fit",
                password="AlunoForte123!",
                role="client",
                trainer_id=trainers["rafael"].id,
                weight=70.0,
                height=169.0,
                age=32,
                gender="female",
                phone_whatsapp="+55 21 95555-4444",
                goal_type="endurance",
            )
        )
        await session.flush()

        goal_specs = [
            ("Reduzir peso corporal", "composition", 82.0, 90.5, "kg", students[0], trainers["camila"]),
            ("Aumentar carga no agachamento", "strength", 90.0, 62.5, "kg", students[1], trainers["camila"]),
            ("Manter frequencia semanal", "frequency", 4.0, 3.0, "treinos/semana", students[2], trainers["rafael"]),
            ("Melhorar corrida 5km", "endurance", 28.0, 33.0, "min", students[3], trainers["rafael"]),
        ]

        for title, category, target, current, unit, student, trainer in goal_specs:
            existing_goal = await session.execute(
                select(Goal).where(Goal.user_id == student.id, Goal.title == title)
            )
            goal = existing_goal.scalars().first()
            if not goal:
                goal = Goal(
                    user_id=student.id,
                    created_by_id=trainer.id,
                    title=title,
                    description=f"Meta principal de {student.name}",
                    category=category,
                    target_value=target,
                    current_value=current,
                    initial_value=current - 1.5 if target > current else current + 1.5,
                    unit=unit,
                    start_date=datetime.utcnow() - timedelta(days=15),
                    target_date=datetime.utcnow() + timedelta(days=90),
                    status="active",
                    progress_percentage=25.0,
                )
                session.add(goal)
                await session.flush()

                entry = GoalProgressEntry(
                    goal_id=goal.id,
                    current_value=current,
                    recorded_at=datetime.utcnow() - timedelta(days=2),
                    notes="Atualizacao inicial da consultoria",
                )
                session.add(entry)

        for index, student in enumerate(students):
            trainer = trainers["camila"] if student.trainer_id == trainers["camila"].id else trainers["rafael"]
            sheet_name = f"Treino Base {student.name.split()[0]}"
            existing_sheet_result = await session.execute(
                select(WorkoutSheet).where(
                    WorkoutSheet.user_id == student.id,
                    WorkoutSheet.name == sheet_name,
                )
            )
            sheet = existing_sheet_result.scalars().first()

            if not sheet:
                sheet = WorkoutSheet(
                    user_id=student.id,
                    personal_trainer_id=trainer.id,
                    name=sheet_name,
                    description="Ficha inicial para ciclo de 4 semanas",
                    day_of_week=index % 5,
                    is_active=True,
                )
                session.add(sheet)
                await session.flush()

                exercise_list = await _build_exercise_template(session, index)
                for order, exercise_tpl in enumerate(exercise_list, start=1):
                    ex = Exercise(
                        workout_sheet_id=sheet.id,
                        name=exercise_tpl["name"],
                        muscle_group=exercise_tpl["group"],
                        series=exercise_tpl["series"],
                        repetitions=exercise_tpl["reps"],
                        load_kg=exercise_tpl["load"],
                        rest_seconds=75,
                        observations=exercise_tpl["obs"],
                        order=order,
                    )
                    session.add(ex)
                await session.flush()

            existing_session_result = await session.execute(
                select(WorkoutSession).where(
                    WorkoutSession.user_id == student.id,
                    WorkoutSession.workout_sheet_id == sheet.id,
                )
            )
            workout_session = existing_session_result.scalars().first()
            if not workout_session:
                workout_session = WorkoutSession(
                    user_id=student.id,
                    workout_sheet_id=sheet.id,
                    session_date=datetime.utcnow() - timedelta(days=1),
                    status="completed",
                    general_notes="Sessao finalizada com boa aderencia.",
                    difficulty_level=7,
                    mood="good",
                    completed_at=datetime.utcnow() - timedelta(days=1, minutes=-55),
                    approved_by_personal_id=trainer.id,
                    approved_at=datetime.utcnow() - timedelta(hours=20),
                )
                session.add(workout_session)
                await session.flush()

                exercises_result = await session.execute(
                    select(Exercise).where(Exercise.workout_sheet_id == sheet.id).order_by(Exercise.order)
                )
                for ex in exercises_result.scalars().all():
                    session.add(
                        SessionExercise(
                            session_id=workout_session.id,
                            exercise_id=ex.id,
                            planned_series=ex.series,
                            planned_repetitions=ex.repetitions,
                            planned_load_kg=ex.load_kg,
                            actual_series=ex.series,
                            actual_repetitions=max(6, ex.repetitions - 1),
                            actual_load_kg=ex.load_kg,
                            series_details=[
                                {"series": 1, "reps": max(6, ex.repetitions - 1), "load": ex.load_kg},
                                {"series": 2, "reps": max(6, ex.repetitions - 1), "load": ex.load_kg},
                            ],
                            exercise_notes="Bom controle de movimento.",
                            pain_or_discomfort=False,
                            status="completed",
                        )
                    )

            meal_foods = await _pick_foods_for_meals(session)

            diet_name = f"Dieta Inicial {student.name.split()[0]}"
            existing_diet_result = await session.execute(
                select(Diet).where(Diet.user_id == student.id, Diet.name == diet_name)
            )
            diet = existing_diet_result.scalars().first()
            if not diet:
                diet = Diet(
                    user_id=student.id,
                    professional_id=trainer.id,
                    is_custom=False,
                    name=diet_name,
                    goal="cutting" if student.goal_type == "lose_weight" else "bulking",
                    is_active=True,
                )
                session.add(diet)
                await session.flush()

                breakfast = DietMeal(diet_id=diet.id, name="Cafe da Manha", time="07:30", order=1)
                lunch = DietMeal(diet_id=diet.id, name="Almoco", time="12:30", order=2)
                session.add_all([breakfast, lunch])
                await session.flush()

                if meal_foods:
                    session.add_all(
                        [
                            DietItem(
                                meal_id=breakfast.id,
                                food_id=meal_foods["breakfast"].id,
                                quantity_g=180.0,
                                observations=f"TACO: {meal_foods['breakfast'].name}",
                            ),
                            DietItem(
                                meal_id=lunch.id,
                                food_id=meal_foods["lunch"].id,
                                quantity_g=220.0,
                                observations=f"TACO: {meal_foods['lunch'].name}",
                            ),
                        ]
                    )
                else:
                    logger.warning("[seed_domain] Dieta criada sem itens para %s por falta de dados TACO.", student.email)

            today = date.today()
            existing_logbook_result = await session.execute(
                select(DietLogbook).where(DietLogbook.user_id == student.id, DietLogbook.date == today)
            )
            logbook = existing_logbook_result.scalars().first()
            if not logbook:
                breakfast_food = meal_foods.get("breakfast") if meal_foods else None
                lunch_food = meal_foods.get("lunch") if meal_foods else None

                breakfast_qty = 180.0
                lunch_qty = 220.0
                breakfast_kcal = _macro_by_quantity(
                    breakfast_food.energy_kcal if breakfast_food else 0.0,
                    breakfast_qty,
                )
                lunch_kcal = _macro_by_quantity(
                    lunch_food.energy_kcal if lunch_food else 0.0,
                    lunch_qty,
                )
                breakfast_protein = _macro_by_quantity(
                    breakfast_food.protein_g if breakfast_food else 0.0,
                    breakfast_qty,
                )
                lunch_protein = _macro_by_quantity(
                    lunch_food.protein_g if lunch_food else 0.0,
                    lunch_qty,
                )
                breakfast_carbs = _macro_by_quantity(
                    breakfast_food.carbohydrate_g if breakfast_food else 0.0,
                    breakfast_qty,
                )
                lunch_carbs = _macro_by_quantity(
                    lunch_food.carbohydrate_g if lunch_food else 0.0,
                    lunch_qty,
                )
                breakfast_fats = _macro_by_quantity(
                    breakfast_food.lipid_g if breakfast_food else 0.0,
                    breakfast_qty,
                )
                lunch_fats = _macro_by_quantity(
                    lunch_food.lipid_g if lunch_food else 0.0,
                    lunch_qty,
                )

                logbook = DietLogbook(
                    user_id=student.id,
                    date=today,
                    total_kcal=round(breakfast_kcal + lunch_kcal, 2),
                    total_protein=round(breakfast_protein + lunch_protein, 2),
                    total_carbs=round(breakfast_carbs + lunch_carbs, 2),
                    total_fats=round(breakfast_fats + lunch_fats, 2),
                )
                session.add(logbook)
                await session.flush()

                if meal_foods:
                    session.add_all(
                        [
                            DietLogbookEntry(
                                logbook_id=logbook.id,
                                meal_name="Cafe da Manha",
                                food_name=breakfast_food.name,
                                food_id=breakfast_food.id,
                                quantity_g=breakfast_qty,
                                kcal=breakfast_kcal,
                                protein=breakfast_protein,
                                carbs=breakfast_carbs,
                                fats=breakfast_fats,
                            ),
                            DietLogbookEntry(
                                logbook_id=logbook.id,
                                meal_name="Almoco",
                                food_name=lunch_food.name,
                                food_id=lunch_food.id,
                                quantity_g=lunch_qty,
                                kcal=lunch_kcal,
                                protein=lunch_protein,
                                carbs=lunch_carbs,
                                fats=lunch_fats,
                            ),
                        ]
                    )

        await session.commit()
        print("[seed_domain] Seed de usuarios e dados de dominio concluido com sucesso.")
        print(f"[seed_domain] Admin: {admin.email}")
        print(f"[seed_domain] Personais: {len(trainers)} | Alunos: {len(students)}")
        for s in students:
            print(f"[seed_domain]   - {s.name} ({s.email})")


if __name__ == "__main__":
    force = "--force" in sys.argv
    if force:
        print("[seed_domain] Modo --force ativado.")
    asyncio.run(seed(force=force))
