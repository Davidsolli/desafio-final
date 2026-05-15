"""
Seed de Planos e Assinaturas para testes de troca de plano.
"""

import asyncio
import logging
import os
import sys
from datetime import datetime, timedelta
from uuid import UUID

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession, create_async_engine
from sqlalchemy.orm import sessionmaker

# Adiciona o backend ao path
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from app.config.settings import settings
from app.models.payment import Plan, Subscription
from app.models.user import User

logger = logging.getLogger(__name__)
logging.basicConfig(level=logging.INFO)

async def seed_payments(force: bool = False):
    engine = create_async_engine(settings.DATABASE_URL, echo=False)
    async_session = sessionmaker(engine, class_=AsyncSession, expire_on_commit=False)

    async with async_session() as session:
        # 1. Obter o Admin (dono dos planos)
        admin_email = os.getenv("ADMIN_EMAIL", "admin@omniconnect.fit")
        result = await session.execute(select(User).where(User.email == admin_email))
        admin = result.scalars().first()
        
        if not admin:
            logger.error(f"Admin com email {admin_email} não encontrado. Execute o seed_users_domain_data.py primeiro.")
            return

        # 2. Criar Planos de Exemplo
        plans_data = [
            {
                "name": "Plano Mensal Bronze",
                "description": "Acesso básico mensal",
                "price": 89.90,
                "duration_months": 1,
                "modality": "fitness"
            },
            {
                "name": "Plano Trimestral Prata",
                "description": "Acesso completo por 3 meses com desconto",
                "price": 239.70,
                "duration_months": 3,
                "modality": "fitness"
            },
            {
                "name": "Plano Anual Ouro",
                "description": "Melhor custo-benefício. 12 meses de acesso premium",
                "price": 718.80,
                "duration_months": 12,
                "modality": "fitness"
            }
        ]

        created_plans = []
        for p_data in plans_data:
            result = await session.execute(select(Plan).where(Plan.name == p_data["name"]))
            existing_plan = result.scalars().first()
            
            if not existing_plan:
                plan = Plan(
                    admin_id=admin.id,
                    name=p_data["name"],
                    description=p_data["description"],
                    price=p_data["price"],
                    duration_months=p_data["duration_months"],
                    modality=p_data["modality"]
                )
                session.add(plan)
                logger.info(f"Criando plano: {p_data['name']}")
                created_plans.append(plan)
            else:
                logger.info(f"Plano já existe: {p_data['name']}")
                created_plans.append(existing_plan)
        
        await session.flush()

        # 3. Vincular Assinatura a um Usuário de Teste (Bruno Aluno)
        student_email = "bruno.aluno@omniconnect.fit"
        result = await session.execute(select(User).where(User.email == student_email))
        student = result.scalars().first()
        
        if student and created_plans:
            # Verificar se já tem assinatura
            result = await session.execute(select(Subscription).where(Subscription.student_id == student.id))
            existing_sub = result.scalars().first()
            
            if not existing_sub or force:
                if existing_sub and force:
                    await session.delete(existing_sub)
                    await session.flush()
                
                # Criar uma assinatura ativa que expira em 15 dias para testar a troca
                plan = created_plans[0] # Bronze Mensal
                now = datetime.utcnow()
                sub = Subscription(
                    student_id=student.id,
                    plan_id=plan.id,
                    admin_id=admin.id,
                    status="active",
                    payment_method="pix",
                    external_payment_id=f"TEST_SEED_{UUID(int=0)}",
                    started_at=now - timedelta(days=15),
                    expires_at=now + timedelta(days=15)
                )
                session.add(sub)
                logger.info(f"Criando assinatura ativa para {student.email} (expira em 15 dias)")
            else:
                logger.info(f"Usuário {student.email} já possui uma assinatura.")
        else:
            logger.warning(f"Estudante {student_email} não encontrado ou planos não criados.")

        await session.commit()
        logger.info("Seed de pagamentos concluído com sucesso.")

if __name__ == "__main__":
    force = "--force" in sys.argv
    asyncio.run(seed_payments(force=force))
