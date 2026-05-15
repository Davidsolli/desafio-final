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
from app.models.workout_sheet import Exercise, WorkoutSheet, WorkoutProgram

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
    base_load: float = 30.0,
) -> List[Dict]:
    """
    Monta template de exercicios com base no exercise_catalog.

    Usa 4 grupos musculares para manter ficha equilibrada.
    A carga base varia por aluno para gerar progressoes distintas.
    """
    target_groups = ["perna_anterior", "peito", "costa", "ombro"]
    series_map = {"perna_anterior": 4, "peito": 4, "costa": 3, "ombro": 3}
    reps_map = {"perna_anterior": 10, "peito": 8, "costa": 12, "ombro": 12}
    load_offsets = {"perna_anterior": 15.0, "peito": 5.0, "costa": 2.0, "ombro": -5.0}

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
        load = max(5.0, base_load + load_offsets.get(group, 0.0))
        selected_templates.append(
            {
                "name": row.name,
                "group": row.muscle_group_mapped or group,
                "series": series_map.get(group, 3),
                "reps": reps_map.get(group, 10),
                "load": round(load, 1),
                "obs": f"Baseado no catalogo: {row.id}",
            }
        )

    if selected_templates:
        return selected_templates

    logger.warning("[seed_domain] exercise_catalog vazio. Aplicando fallback de exercicios.")
    return [
        {"name": "Agachamento Livre",  "group": "perna_anterior", "series": 4, "reps": 10, "load": base_load + 15.0, "obs": "Fallback"},
        {"name": "Supino Reto",        "group": "peito",          "series": 4, "reps": 8,  "load": base_load + 5.0,  "obs": "Fallback"},
        {"name": "Remada Curvada",     "group": "costa",          "series": 3, "reps": 12, "load": base_load + 2.0,  "obs": "Fallback"},
        {"name": "Desenvolvimento",    "group": "ombro",          "series": 3, "reps": 12, "load": max(5.0, base_load - 5.0), "obs": "Fallback"},
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
    Popula base com admin, profissionais e alunos com dados correlacionados.

    Profissionais:
      - Camila Rocha    → personal_trainer
      - Rafael Lima     → personal_trainer
      - Ana Beatriz     → nutritionist
      - Pedro Alves     → nutritionist,personal_trainer  (dual)

    Alunos: 2 por profissional = 8 alunos no total.

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
                WorkoutProgram,
            ):
                rows = await session.execute(select(model))
                for row in rows.scalars().all():
                    await session.delete(row)
            await session.commit()

        # ── Admin ──────────────────────────────────────────────────────────
        admin_bootstrap = _resolve_admin_bootstrap()
        admin = await get_or_create_user(
            session,
            name=admin_bootstrap["ADMIN_NAME"],
            email=admin_bootstrap["ADMIN_EMAIL"],
            password=admin_bootstrap["ADMIN_PASSWORD"],
            role="admin",
            phone_whatsapp="5511900000000",
        )

        # ── Profissionais ──────────────────────────────────────────────────
        # Agora todos os profissionais têm a função dual: nutricionista e personal trainer
        professionals: Dict[str, User] = {}

        professionals["camila"] = await get_or_create_user(
            session,
            name="Camila Rocha",
            email="camila.personal@omniconnect.fit",
            password="TreinoForte123!",
            role="nutritionist,personal_trainer",
            age=31,
            gender="female",
            phone_whatsapp="5511988881010",
        )
        professionals["rafael"] = await get_or_create_user(
            session,
            name="Rafael Lima",
            email="rafael.personal@omniconnect.fit",
            password="TreinoForte123!",
            role="nutritionist,personal_trainer",
            age=34,
            gender="male",
            phone_whatsapp="5521977772020",
        )

        # ── Alunos — 2 por profissional (Total 4) ──────────────────────────
        #
        # Estrutura: (nome, email, prof_key, peso, altura, idade, genero, fone, objetivo, carga_base)
        #
        student_specs = [
            # Camila Rocha
            ("Bruno Martins",   "bruno.aluno@omniconnect.fit",    "camila", 92.0, 180.0, 29, "male",   "5511966661111", "lose_weight",  32.0),
            ("Juliana Costa",   "juliana.aluna@omniconnect.fit",  "camila", 61.0, 165.0, 26, "female", "5511966662222", "gain_mass",    18.0),
            # Rafael Lima
            ("Leonardo Souza",  "leonardo.aluno@omniconnect.fit", "rafael", 79.0, 173.0, 35, "male",   "5521955553333", "maintenance",  28.0),
            ("Patricia Nunes",  "patricia.aluna@omniconnect.fit", "rafael", 70.0, 169.0, 32, "female", "5521955554444", "endurance",    20.0),
        ]

        students: List[User] = []
        for (name, email, prof_key, weight, height, age, gender, phone, goal_type, _base_load) in student_specs:
            student = await get_or_create_user(
                session,
                name=name,
                email=email,
                password="AlunoForte123!",
                role="client",
                trainer_id=professionals[prof_key].id,
                weight=weight,
                height=height,
                age=age,
                gender=gender,
                phone_whatsapp=phone,
                goal_type=goal_type,
            )
            students.append(student)

        await session.flush()

        # ── Metas ──────────────────────────────────────────────────────────
        #
        # (titulo, categoria, target, current, unidade, student_idx, prof_key)
        #
        goal_specs = [
            ("Reduzir gordura corporal",     "composition", 82.0,  92.0,  "kg",            0, "camila"),
            ("Aumentar carga no supino",     "strength",    50.0,  32.0,  "kg",            1, "camila"),
            ("Manter frequência semanal",    "frequency",    4.0,   3.0,  "treinos/semana",2, "rafael"),
            ("Melhorar VO2 máx (corrida)",   "endurance",   28.0,  33.5,  "min/5km",       3, "rafael"),
        ]

        for title, category, target, current, unit, student_idx, prof_key in goal_specs:
            student = students[student_idx]
            prof = professionals[prof_key]
            existing = await session.execute(
                select(Goal).where(Goal.user_id == student.id, Goal.title == title)
            )
            goal = existing.scalars().first()
            if not goal:
                going_up = target > current
                initial = current - 1.5 if going_up else current + 1.5
                progress = round(abs(current - initial) / max(abs(target - initial), 0.01) * 100, 1)
                goal = Goal(
                    user_id=student.id,
                    created_by_id=prof.id,
                    title=title,
                    description=f"Meta principal de {student.name}",
                    category=category,
                    target_value=target,
                    current_value=current,
                    initial_value=initial,
                    unit=unit,
                    start_date=datetime.utcnow() - timedelta(days=20),
                    target_date=datetime.utcnow() + timedelta(days=80),
                    status="active",
                    progress_percentage=min(progress, 99.0),
                )
                session.add(goal)
                await session.flush()

                session.add(GoalProgressEntry(
                    goal_id=goal.id,
                    current_value=current,
                    recorded_at=datetime.utcnow() - timedelta(days=3),
                    notes="Atualização inicial da consultoria",
                ))

        # ── Programas de treino, fichas e histórico ────────────────────────
        for index, spec in enumerate(student_specs):
            name, email, prof_key, weight, height, age, gender, phone, goal_type, base_load = spec
            student = students[index]
            prof = professionals[prof_key]

            # Personais e o dual criam programas; nutricionista puro não precisa de programa de treino
            is_trainer_prof = "personal_trainer" in prof.role

            if is_trainer_prof:
                program_name = f"Programa Base {student.name.split()[0]}"
                existing_program = await session.execute(
                    select(WorkoutProgram).where(
                        WorkoutProgram.user_id == student.id,
                        WorkoutProgram.name == program_name,
                    )
                )
                program = existing_program.scalars().first()

                if not program:
                    goal_label = (
                        "Hipertrofia" if goal_type == "gain_mass"
                        else "Emagrecimento" if goal_type == "lose_weight"
                        else "Resistência" if goal_type == "endurance"
                        else "Manutenção"
                    )
                    program = WorkoutProgram(
                        user_id=student.id,
                        personal_trainer_id=prof.id,
                        name=program_name,
                        description=f"Programa de 4 semanas — foco em {goal_label.lower()}",
                        goal=goal_label,
                        is_active=True,
                    )
                    session.add(program)
                    await session.flush()

                sheets_result = await session.execute(
                    select(WorkoutSheet).where(
                        WorkoutSheet.workout_program_id == program.id,
                        WorkoutSheet.is_active.is_(True),
                    )
                )
                sheets_list = sheets_result.scalars().all()

                if not sheets_list:
                    sheet = WorkoutSheet(
                        workout_program_id=program.id,
                        name="Treino A",
                        description="Ficha base — adaptação",
                        day_of_week=index % 5,
                        order=1,
                        is_active=True,
                    )
                    session.add(sheet)
                    await session.flush()

                    exercise_list = await _build_exercise_template(session, index, base_load)
                    for order, tpl in enumerate(exercise_list, start=1):
                        session.add(Exercise(
                            workout_sheet_id=sheet.id,
                            name=tpl["name"],
                            muscle_group=tpl["group"],
                            series=tpl["series"],
                            repetitions=tpl["reps"],
                            load_kg=tpl["load"],
                            rest_seconds=75,
                            observations=tpl["obs"],
                            order=order,
                        ))
                    await session.flush()
                else:
                    sheet = sheets_list[0]

                # Histórico de 10 semanas (20 treinos) com progressão de carga
                existing_session = await session.execute(
                    select(WorkoutSession).where(
                        WorkoutSession.user_id == student.id,
                        WorkoutSession.status == "completed",
                    )
                )
                if not existing_session.scalars().first():
                    # Offsets espaçados de 3-4 dias para simular frequência real
                    offsets = [70, 66, 62, 59, 55, 52, 48, 45, 41, 38, 34, 31, 27, 24, 20, 17, 13, 10, 6, 3]

                    exercises_result = await session.execute(
                        select(Exercise).where(Exercise.workout_sheet_id == sheet.id).order_by(Exercise.order)
                    )
                    sheet_exercises = exercises_result.scalars().all()

                    for session_num, offset in enumerate(offsets):
                        week_idx = session_num // 2  # ~2 treinos por semana
                        s_date = datetime.utcnow() - timedelta(days=offset)

                        ws = WorkoutSession(
                            user_id=student.id,
                            workout_sheet_id=sheet.id,
                            session_date=s_date,
                            status="completed",
                            general_notes=f"Semana {week_idx + 1} — treino concluído.",
                            difficulty_level=RNG.choice([6, 7, 7, 8]),
                            mood=RNG.choice(["good", "good", "excellent"]),
                            completed_at=s_date + timedelta(minutes=RNG.randint(45, 65)),
                            approved_by_personal_id=prof.id,
                            approved_at=s_date + timedelta(hours=2),
                        )
                        session.add(ws)
                        await session.flush()

                        for ex in sheet_exercises:
                            # Progressão linear: 65 % → 100 % ao longo das 10 semanas
                            factor = 0.65 + (0.35 * (week_idx / 9.0))
                            actual_load = max(5.0, round(ex.load_kg * factor, 1))

                            series_details = []
                            for s_num in range(1, ex.series + 1):
                                fatigue = RNG.choice([0, 0, 1]) if s_num >= 3 else 0
                                series_details.append({
                                    "series": s_num,
                                    "reps": max(6, ex.repetitions - fatigue),
                                    "load": actual_load,
                                })

                            session.add(SessionExercise(
                                session_id=ws.id,
                                exercise_id=ex.id,
                                planned_series=ex.series,
                                planned_repetitions=ex.repetitions,
                                planned_load_kg=ex.load_kg,
                                actual_series=ex.series,
                                actual_repetitions=ex.repetitions,
                                actual_load_kg=actual_load,
                                series_details=series_details,
                                exercise_notes="Execução controlada.",
                                pain_or_discomfort=False,
                                status="completed",
                            ))
                    await session.flush()

            # ── Dieta prescrita (todos os alunos recebem dieta) ────────────
            meal_foods = await _pick_foods_for_meals(session)

            diet_name = f"Dieta Inicial {student.name.split()[0]}"
            existing_diet = await session.execute(
                select(Diet).where(Diet.user_id == student.id, Diet.name == diet_name)
            )
            diet = existing_diet.scalars().first()
            if not diet:
                diet = Diet(
                    user_id=student.id,
                    professional_id=prof.id,
                    is_custom=False,
                    name=diet_name,
                    goal="cutting" if goal_type == "lose_weight" else "bulking",
                    is_active=True,
                )
                session.add(diet)
                await session.flush()

                breakfast = DietMeal(diet_id=diet.id, name="Café da Manhã", time="07:30", order=1)
                lunch    = DietMeal(diet_id=diet.id, name="Almoço",         time="12:30", order=2)
                dinner   = DietMeal(diet_id=diet.id, name="Jantar",         time="19:30", order=3)
                session.add_all([breakfast, lunch, dinner])
                await session.flush()

                if meal_foods:
                    session.add_all([
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
                        DietItem(
                            meal_id=dinner.id,
                            food_id=meal_foods["lunch"].id,  # reutiliza proteína do almoço
                            quantity_g=180.0,
                            observations="Refeição noturna — porção reduzida",
                        ),
                    ])
                else:
                    logger.warning(
                        "[seed_domain] Dieta criada sem itens para %s (food_catalog vazio).",
                        student.email,
                    )

            # ── Diário alimentar do dia ────────────────────────────────────
            today = date.today()
            existing_logbook = await session.execute(
                select(DietLogbook).where(
                    DietLogbook.user_id == student.id,
                    DietLogbook.date == today,
                )
            )
            if not existing_logbook.scalars().first() and meal_foods:
                bf = meal_foods["breakfast"]
                lf = meal_foods["lunch"]
                bf_qty, lf_qty = 180.0, 220.0

                def macro(food, attr, qty): return _macro_by_quantity(getattr(food, attr, 0.0) or 0.0, qty)

                logbook = DietLogbook(
                    user_id=student.id,
                    date=today,
                    total_kcal=round(macro(bf, "energy_kcal", bf_qty) + macro(lf, "energy_kcal", lf_qty), 2),
                    total_protein=round(macro(bf, "protein_g", bf_qty) + macro(lf, "protein_g", lf_qty), 2),
                    total_carbs=round(macro(bf, "carbohydrate_g", bf_qty) + macro(lf, "carbohydrate_g", lf_qty), 2),
                    total_fats=round(macro(bf, "lipid_g", bf_qty) + macro(lf, "lipid_g", lf_qty), 2),
                )
                session.add(logbook)
                await session.flush()

                session.add_all([
                    DietLogbookEntry(
                        logbook_id=logbook.id,
                        meal_name="Café da Manhã",
                        food_name=bf.name,
                        food_id=bf.id,
                        quantity_g=bf_qty,
                        kcal=macro(bf, "energy_kcal", bf_qty),
                        protein=macro(bf, "protein_g", bf_qty),
                        carbs=macro(bf, "carbohydrate_g", bf_qty),
                        fats=macro(bf, "lipid_g", bf_qty),
                    ),
                    DietLogbookEntry(
                        logbook_id=logbook.id,
                        meal_name="Almoço",
                        food_name=lf.name,
                        food_id=lf.id,
                        quantity_g=lf_qty,
                        kcal=macro(lf, "energy_kcal", lf_qty),
                        protein=macro(lf, "protein_g", lf_qty),
                        carbs=macro(lf, "carbohydrate_g", lf_qty),
                        fats=macro(lf, "lipid_g", lf_qty),
                    ),
                ])

        await session.commit()

    print("[seed_domain] Seed de usuarios e dados de dominio concluido com sucesso.")
    print(f"[seed_domain]   Admin:         {admin.email}")
    print(f"[seed_domain]   Profissionais: {len(professionals)}")
    for key, p in professionals.items():
        role_label = (
            "Personal + Nutricionista" if "," in p.role
            else "Nutricionista" if p.role == "nutritionist"
            else "Personal Trainer"
        )
        print(f"[seed_domain]     [{role_label}] {p.name} ({p.email})")
    print(f"[seed_domain]   Alunos:        {len(students)}")
    for s in students:
        prof = next((p for p in professionals.values() if p.id == s.trainer_id), None)
        print(f"[seed_domain]     {s.name} ({s.email}) → {prof.name if prof else '?'}")


if __name__ == "__main__":
    force = "--force" in sys.argv
    if force:
        print("[seed_domain] Modo --force ativado: dados de dominio serao recriados.")
    asyncio.run(seed(force=force))
