"""
Seed de dados para testar o dashboard de métricas administrativas.

Cria um cenário realista com:
- 3 personal trainers com carteiras de tamanhos diferentes
- 16 alunos com perfis de aderência variados (alta / média / baixa / crítica)
- Histórico de sessões de treino nos últimos 30 dias
- Registros de dieta e passos proporcionais ao engajamento
- Metas ativas com diferentes percentuais de progresso
- Convites por trainer (usados + não usados) para testar taxa de conversão
- Conversas de chatbot com mensagens e feedbacks para AI Analytics

Distribuição de risco esperada após o seed
------------------------------------------
  Crítico  : Diego Santos, Bianca Rocha, Caio Braga
  Alto     : Eduardo Carmo, Isabela Faria
  Médio    : André Almeida, Larissa Melo
  Baixo    : demais 9 alunos

Uso
---
    # Modo idempotente (cria apenas o que não existe)
    python scripts/seed_admin_metrics.py

    # Modo destrutivo (remove dados de seed anteriores antes de criar)
    python scripts/seed_admin_metrics.py --force
"""

import asyncio
import logging
import os
import random
import secrets
import string
import sys
from datetime import date, datetime, timedelta, timezone
from typing import Optional
from uuid import uuid4

import bcrypt
from sqlalchemy import func, or_, select
from sqlalchemy.ext.asyncio import AsyncSession, create_async_engine
from sqlalchemy.orm import sessionmaker

# Garante que o módulo app fica acessível independente de onde o script é chamado
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from app.config.settings import settings
from app.models.chatbot import ChatConversation, ChatFeedback, ChatMessage
from app.models.diet_logbook import DietLogbook
from app.models.goal import Goal
from app.models.invitation import Invitation
from app.models.logbook import WorkoutSession
from app.models.step_log import StepLog
from app.models.user import User

logging.basicConfig(
    level=logging.INFO,
    format="%(levelname)s  %(message)s",
)
logger = logging.getLogger(__name__)

RNG = random.Random(7)  # semente fixa: resultados reproduzíveis

# ──────────────────────────────────────────────────────────────────────────────
# Perfis dos alunos
# Colunas: nome, email, trainer_key, n_completed, n_total, last_active_days,
#          diet_days, steps_days, goal_progress_pct, n_conversations, helpful_rate
#
# Fórmula de risco do backend (app/services/admin_metrics_service.py):
#   score += 5 se adherence < 30%   |  +3 se adherence < 50%
#   score += 3 se days_inactive > 7  |  +1 se days_inactive > 3
#   critical≥7, high≥4, medium≥2, low=0-1
# ──────────────────────────────────────────────────────────────────────────────

STUDENT_SPECS = [
    # ─── Ana Silva — 8 alunos ────────────────────────────────────────────────
    # high adherence (≥80%), low risk
    ("Fernanda Oliveira", "fernanda.oliveira@metrics.test", "ana",  10, 12,  0, 20, 15, 82.0, 3, 0.82),
    ("Ricardo Batista",   "ricardo.batista@metrics.test",   "ana",  11, 12,  1, 22, 18, 90.0, 2, 0.90),
    ("Felipe Costa",      "felipe.costa@metrics.test",      "ana",  10, 12,  0, 18, 12, 80.0, 2, 0.78),
    # medium adherence (50-79%), low risk
    ("Gabriela Torres",   "gabriela.torres@metrics.test",   "ana",   8, 12,  2, 14, 10, 66.0, 2, 0.70),
    ("Vanessa Lima",      "vanessa.lima@metrics.test",      "ana",   9, 12,  1, 16,  8, 74.0, 2, 0.72),
    # low adherence (<50%), medium risk — adherence 33%, inactive≤3d → score 3
    ("André Almeida",     "andre.almeida@metrics.test",     "ana",   4, 12,  2,  8,  3, 33.0, 1, 0.55),
    ("Larissa Melo",      "larissa.melo@metrics.test",      "ana",   4, 12,  3,  6,  2, 30.0, 1, 0.50),
    # critical risk — adherence 16%, inactive 12d → score 5+3=8
    ("Diego Santos",      "diego.santos@metrics.test",      "ana",   2, 12, 12,  2,  0, 15.0, 1, 0.40),

    # ─── Carlos Melo — 5 alunos ──────────────────────────────────────────────
    # high adherence, low risk
    ("Tatiane Pereira",   "tatiane.pereira@metrics.test",   "carlos", 11, 12,  1, 21, 15, 91.0, 3, 0.88),
    # medium adherence, low risk
    ("Rodrigo Ferreira",  "rodrigo.ferreira@metrics.test",  "carlos",  6, 12,  3, 12,  8, 58.0, 2, 0.65),
    ("Sandra Vieira",     "sandra.vieira@metrics.test",     "carlos",  9, 12,  2, 15,  9, 74.0, 2, 0.74),
    # high risk — adherence 41%, inactive 10d → score 3+3=6
    ("Eduardo Carmo",     "eduardo.carmo@metrics.test",     "carlos",  5, 12, 10,  5,  1, 41.0, 1, 0.45),
    # critical risk — adherence 16%, inactive 15d → score 5+3=8
    ("Bianca Rocha",      "bianca.rocha@metrics.test",      "carlos",  2, 12, 15,  1,  0, 14.0, 0, 0.00),

    # ─── Marcos Viana — 3 alunos ─────────────────────────────────────────────
    # medium adherence, low risk
    ("Gustavo Nunes",     "gustavo.nunes@metrics.test",     "marcos",  8, 12,  2, 13,  7, 65.0, 2, 0.68),
    # high risk — adherence 33%, inactive 5d → score 3+1=4
    ("Isabela Faria",     "isabela.faria@metrics.test",     "marcos",  4, 12,  5,  5,  2, 32.0, 1, 0.50),
    # critical risk — adherence 8%, inactive 22d → score 5+3=8
    ("Caio Braga",        "caio.braga@metrics.test",        "marcos",  1, 12, 22,  1,  0,  8.0, 0, 0.00),
]

_TRAINER_EMAILS = [
    "ana.silva@metrics.test",
    "carlos.melo@metrics.test",
    "marcos.viana@metrics.test",
]

AI_MODELS = [
    "claude-3-5-sonnet-20241022",
    "claude-3-5-sonnet-20241022",  # dobra o peso → ~65% das mensagens
    "claude-3-haiku-20240307",
]


# ──────────────────────────────────────────────────────────────────────────────
# HELPERS GERAIS
# ──────────────────────────────────────────────────────────────────────────────


def _hash(password: str) -> str:
    return bcrypt.hashpw(password.encode(), bcrypt.gensalt(rounds=12)).decode()


def _invite_code() -> str:
    chars = string.ascii_uppercase + string.digits
    return "".join(secrets.choice(chars) for _ in range(10))


def _now() -> datetime:
    return datetime.now(timezone.utc)


def _ago(days: int) -> datetime:
    return _now() - timedelta(days=days)


def _date_ago(days: int) -> date:
    return date.today() - timedelta(days=days)


def _session_schedule(
    n_completed: int,
    n_total: int,
    last_completed_days_ago: int,
) -> list[tuple[int, str]]:
    """
    Gera lista de (days_ago, status) para WorkoutSession.

    Regras:
    - O treino completado mais recente fica em last_completed_days_ago.
    - Todas as sessões ficam dentro de uma janela de 29 dias.
    - Treinos incompletos preenchem o espaço restante de forma uniforme.
    """
    period = 29
    result: list[tuple[int, str]] = []

    # Sessões completadas: distribuídas a partir de last_completed_days_ago
    for i in range(n_completed):
        days = min(period, last_completed_days_ago + i * 2)
        result.append((days, "completed"))

    # Sessões incompletas: a partir do final das completadas, dentro do período
    n_incomplete = n_total - n_completed
    if n_incomplete > 0 and n_completed > 0:
        latest_completed = min(period, last_completed_days_ago + (n_completed - 1) * 2)
        start = min(period, latest_completed + 2)
    else:
        start = last_completed_days_ago + 2

    remaining_space = max(0, period - start)
    step = max(1, remaining_space // max(1, n_incomplete)) if n_incomplete > 1 else 2

    for i in range(n_incomplete):
        days = min(period, start + i * step)
        result.append((days, "incomplete"))

    return result


# ──────────────────────────────────────────────────────────────────────────────
# BUILDERS IDEMPOTENTES
# ──────────────────────────────────────────────────────────────────────────────


async def _upsert_user(
    session: AsyncSession,
    *,
    name: str,
    email: str,
    role: str,
    trainer_id=None,
    age: Optional[int] = None,
    gender: Optional[str] = None,
    weight: Optional[float] = None,
    height: Optional[float] = None,
    goal_type: Optional[str] = None,
) -> User:
    result = await session.execute(select(User).where(User.email == email))
    user = result.scalars().first()
    if user:
        user.name = name
        user.role = role
        user.trainer_id = trainer_id
        user.is_active = True
        await session.flush()
        return user

    user = User(
        name=name,
        email=email,
        password=_hash("Teste123!"),
        role=role,
        is_active=True,
        trainer_id=trainer_id,
        age=age,
        gender=gender,
        weight=weight,
        height=height,
        goal_type=goal_type,
    )
    session.add(user)
    await session.flush()
    return user


async def _create_invitation(
    session: AsyncSession,
    trainer: User,
    used_by: Optional[User] = None,
) -> Invitation:
    inv = Invitation(
        code=_invite_code(),
        trainer_id=trainer.id,
        used=used_by is not None,
        used_by_id=used_by.id if used_by else None,
        used_at=_ago(RNG.randint(10, 60)) if used_by else None,
    )
    session.add(inv)
    await session.flush()
    return inv


async def _ensure_used_invitation(
    session: AsyncSession,
    trainer: User,
    student: User,
) -> None:
    """Garante que existe um convite utilizado por este aluno."""
    res = await session.execute(
        select(Invitation).where(
            Invitation.trainer_id == trainer.id,
            Invitation.used_by_id == student.id,
        )
    )
    if not res.scalars().first():
        await _create_invitation(session, trainer, used_by=student)


async def _ensure_unused_invitations(
    session: AsyncSession,
    trainer: User,
    count: int = 3,
) -> None:
    """Garante que o trainer tem pelo menos `count` convites não utilizados."""
    res = await session.execute(
        select(func.count(Invitation.id)).where(
            Invitation.trainer_id == trainer.id,
            Invitation.used == False,  # noqa: E712
        )
    )
    existing = res.scalar() or 0
    for _ in range(max(0, count - existing)):
        await _create_invitation(session, trainer, used_by=None)


async def _seed_sessions(
    session: AsyncSession,
    student: User,
    n_completed: int,
    n_total: int,
    last_active_days: int,
) -> None:
    """Cria histórico de WorkoutSessions se ainda não existir para este aluno."""
    count_res = await session.execute(
        select(func.count(WorkoutSession.id)).where(
            WorkoutSession.user_id == student.id
        )
    )
    if (count_res.scalar() or 0) > 0:
        return

    fake_sheet_id = uuid4()  # workout_sheet_id não tem FK constraint
    schedule = _session_schedule(n_completed, n_total, last_active_days)

    for days_ago, status in schedule:
        dt = _ago(days_ago)
        session.add(
            WorkoutSession(
                user_id=student.id,
                workout_sheet_id=fake_sheet_id,
                session_date=dt,
                status=status,
                general_notes="Sessão criada pelo seed de métricas.",
                difficulty_level=RNG.choice([5, 6, 7, 8]),
                mood=RNG.choice(["good", "great", "normal"]),
                completed_at=dt + timedelta(minutes=50) if status == "completed" else None,
            )
        )
    await session.flush()


async def _seed_diet_logs(
    session: AsyncSession,
    student: User,
    n_days: int,
) -> None:
    """Cria DietLogbook para os últimos n_days dias (pula dias já existentes)."""
    for i in range(1, n_days + 1):
        day = _date_ago(i)
        res = await session.execute(
            select(DietLogbook).where(
                DietLogbook.user_id == student.id,
                DietLogbook.date == day,
            )
        )
        if res.scalars().first():
            continue
        session.add(
            DietLogbook(
                user_id=student.id,
                date=day,
                total_kcal=round(RNG.uniform(1700, 2500), 1),
                total_protein=round(RNG.uniform(110, 185), 1),
                total_carbs=round(RNG.uniform(190, 320), 1),
                total_fats=round(RNG.uniform(50, 95), 1),
            )
        )
    await session.flush()


async def _seed_steps(
    session: AsyncSession,
    student: User,
    n_days: int,
) -> None:
    """Cria StepLog para os últimos n_days dias (pula dias já existentes)."""
    for i in range(1, n_days + 1):
        day = _date_ago(i)
        res = await session.execute(
            select(StepLog).where(
                StepLog.user_id == student.id,
                StepLog.date == day,
            )
        )
        if res.scalars().first():
            continue
        session.add(
            StepLog(
                user_id=student.id,
                date=day,
                steps=RNG.randint(3500, 13000),
                distance_meters=float(RNG.randint(2500, 10000)),
            )
        )
    await session.flush()


async def _seed_goal(
    session: AsyncSession,
    student: User,
    trainer: User,
    title: str,
    category: str,
    progress_pct: float,
) -> None:
    """Cria meta ativa para o aluno se ainda não existir."""
    res = await session.execute(
        select(Goal).where(Goal.user_id == student.id, Goal.title == title)
    )
    if res.scalars().first():
        return
    session.add(
        Goal(
            user_id=student.id,
            created_by_id=trainer.id,
            title=title,
            description=f"Meta principal de {student.name.split()[0]}",
            category=category,
            target_value=100.0,
            current_value=progress_pct,
            initial_value=0.0,
            unit="%",
            start_date=_ago(30),
            target_date=_now() + timedelta(days=60),
            status="active",
            progress_percentage=progress_pct,
        )
    )
    await session.flush()


async def _seed_chat(
    session: AsyncSession,
    student: User,
    n_conversations: int,
    n_messages_each: int,
    helpful_rate: float,
) -> None:
    """
    Cria ChatConversation → ChatMessage → ChatFeedback para um aluno.
    Pula a criação se o aluno já tiver conversas.
    """
    count_res = await session.execute(
        select(func.count(ChatConversation.id)).where(
            ChatConversation.user_id == student.id
        )
    )
    if (count_res.scalar() or 0) > 0:
        return

    for conv_idx in range(n_conversations):
        started = _ago(RNG.randint(1, 25))
        conv = ChatConversation(
            user_id=student.id,
            channel="app",
            status="closed",
            started_at=started,
            ended_at=started + timedelta(minutes=n_messages_each * 2 + 5),
        )
        session.add(conv)
        await session.flush()

        for msg_idx in range(n_messages_each):
            is_assistant = msg_idx % 2 == 1
            model = RNG.choice(AI_MODELS) if is_assistant else None
            msg = ChatMessage(
                conversation_id=conv.id,
                role="assistant" if is_assistant else "user",
                content="Mensagem de seed para testes de métricas.",
                channel="app",
                model_used=model,
                tokens_used=RNG.randint(120, 850) if is_assistant else None,
                latency_ms=RNG.randint(550, 2400) if is_assistant else None,
                created_at=started + timedelta(minutes=msg_idx * 2),
            )
            session.add(msg)
            await session.flush()

            # ~55% das mensagens do assistente recebem feedback
            if is_assistant and RNG.random() < 0.55:
                was_helpful = RNG.random() < helpful_rate
                session.add(
                    ChatFeedback(
                        message_id=msg.id,
                        user_id=student.id,
                        was_helpful=was_helpful,
                        feedback_type="good" if was_helpful else "incomplete",
                    )
                )

    await session.flush()


# ──────────────────────────────────────────────────────────────────────────────
# LIMPEZA (--force)
# ──────────────────────────────────────────────────────────────────────────────


async def _force_clean(session: AsyncSession) -> None:
    """Remove todos os usuários e dados criados por este seed."""
    all_emails = [spec[1] for spec in STUDENT_SPECS] + _TRAINER_EMAILS

    # IDs dos usuários de seed
    ids_res = await session.execute(
        select(User.id).where(User.email.in_(all_emails))
    )
    ids = [row[0] for row in ids_res.all()]
    if not ids:
        logger.info("[seed_metrics] Nenhum dado de seed encontrado para remover.")
        return

    # Invitations têm FKs sem CASCADE — deletar antes dos usuários
    inv_res = await session.execute(
        select(Invitation).where(
            or_(
                Invitation.trainer_id.in_(ids),
                Invitation.used_by_id.in_(ids),
            )
        )
    )
    for inv in inv_res.scalars().all():
        await session.delete(inv)
    await session.flush()

    # Usuários: as demais tabelas possuem ON DELETE CASCADE
    users_res = await session.execute(
        select(User).where(User.email.in_(all_emails))
    )
    for user in users_res.scalars().all():
        await session.delete(user)

    await session.commit()
    logger.info("[seed_metrics] %d usuário(s) e dados relacionados removidos.", len(ids))


# ──────────────────────────────────────────────────────────────────────────────
# SEED PRINCIPAL
# ──────────────────────────────────────────────────────────────────────────────


async def seed(force: bool = False) -> None:
    engine = create_async_engine(settings.DATABASE_URL, echo=False)
    async_session = sessionmaker(engine, class_=AsyncSession, expire_on_commit=False)

    async with async_session() as session:
        if force:
            logger.info("[seed_metrics] --force: removendo dados anteriores...")
            await _force_clean(session)

        # ── Trainers ──────────────────────────────────────────────────────────
        ana = await _upsert_user(
            session, name="Ana Silva", email="ana.silva@metrics.test",
            role="personal_trainer", age=30, gender="female",
        )
        carlos = await _upsert_user(
            session, name="Carlos Melo", email="carlos.melo@metrics.test",
            role="personal_trainer", age=35, gender="male",
        )
        marcos = await _upsert_user(
            session, name="Marcos Viana", email="marcos.viana@metrics.test",
            role="personal_trainer", age=40, gender="male",
        )
        await session.commit()

        trainers = {"ana": ana, "carlos": carlos, "marcos": marcos}

        # Convites não utilizados (para testar funil de conversão)
        for trainer in trainers.values():
            await _ensure_unused_invitations(session, trainer, count=3)
        await session.flush()

        # ── Alunos ────────────────────────────────────────────────────────────
        total_created = 0
        for (
            name, email, trainer_key,
            n_completed, n_total, last_active_days,
            diet_days, steps_days,
            goal_progress, n_convs, helpful_rate,
        ) in STUDENT_SPECS:
            trainer = trainers[trainer_key]

            student = await _upsert_user(
                session,
                name=name,
                email=email,
                role="client",
                trainer_id=trainer.id,
                age=RNG.randint(22, 45),
                gender=RNG.choice(["male", "female"]),
                weight=round(RNG.uniform(58.0, 96.0), 1),
                height=round(RNG.uniform(160.0, 186.0), 1),
                goal_type=RNG.choice(["lose_weight", "gain_mass", "maintenance", "endurance"]),
            )

            # Convite utilizado por este aluno
            await _ensure_used_invitation(session, trainer, student)

            # Histórico de treinos
            await _seed_sessions(session, student, n_completed, n_total, last_active_days)

            # Registros de dieta
            if diet_days > 0:
                await _seed_diet_logs(session, student, diet_days)

            # Registros de passos
            if steps_days > 0:
                await _seed_steps(session, student, steps_days)

            # Meta ativa
            await _seed_goal(
                session, student, trainer,
                title=f"Meta principal — {name.split()[0]}",
                category=RNG.choice(["composition", "strength", "frequency", "endurance"]),
                progress_pct=goal_progress,
            )

            # Conversas de chatbot
            if n_convs > 0:
                await _seed_chat(
                    session, student,
                    n_conversations=n_convs,
                    n_messages_each=8,
                    helpful_rate=helpful_rate,
                )

            total_created += 1

        await session.commit()

    # ── Resumo ────────────────────────────────────────────────────────────────
    logger.info("")
    logger.info("[seed_metrics] ✓ Seed concluído com sucesso!")
    logger.info("[seed_metrics] Trainers criados: 3  (Ana Silva, Carlos Melo, Marcos Viana)")
    logger.info("[seed_metrics] Alunos criados:   %d", total_created)
    logger.info("")
    logger.info("[seed_metrics] Distribuição de aderência esperada:")
    logger.info("  Alta  (≥80%%) : Fernanda, Ricardo, Felipe, Tatiane")
    logger.info("  Média (50-79%%): Gabriela, Vanessa, Rodrigo, Sandra, Gustavo")
    logger.info("  Baixa (<50%%) : André, Larissa, Diego, Eduardo, Bianca, Isabela, Caio")
    logger.info("")
    logger.info("[seed_metrics] Distribuição de risco esperada:")
    logger.info("  Crítico  : Diego Santos, Bianca Rocha, Caio Braga")
    logger.info("  Alto     : Eduardo Carmo, Isabela Faria")
    logger.info("  Médio    : André Almeida, Larissa Melo")
    logger.info("  Baixo    : demais 9 alunos")
    logger.info("")
    logger.info("[seed_metrics] Credenciais (todos os usuários): Teste123!")


if __name__ == "__main__":
    force = "--force" in sys.argv
    if force:
        logger.info("[seed_metrics] Modo --force ativado.")
    asyncio.run(seed(force=force))
