"""Repositório para operações CRUD de metas."""

from typing import Optional, List, Tuple
from uuid import UUID

from sqlalchemy import select, func
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.models.goal import Goal, GoalProgressEntry


class GoalRepository:
    """Repositório para operações CRUD de metas."""

    def __init__(self, session: AsyncSession):
        self.session = session

    async def create(self, goal: Goal) -> Goal:
        self.session.add(goal)
        await self.session.flush()
        await self.session.refresh(goal)
        return goal

    async def get_by_id(self, goal_id: UUID) -> Optional[Goal]:
        query = (
            select(Goal)
            .options(selectinload(Goal.progress_entries))
            .where(Goal.id == goal_id)
        )
        result = await self.session.execute(query)
        return result.scalars().first()

    async def list_goals(
        self,
        user_id: Optional[UUID] = None,
        status: Optional[str] = None,
        page: int = 1,
        limit: int = 10,
    ) -> Tuple[List[Goal], int]:
        if limit > 100:
            limit = 100
        if page < 1:
            page = 1

        offset = (page - 1) * limit

        count_query = select(func.count(Goal.id))
        query = select(Goal).options(selectinload(Goal.progress_entries))

        if user_id is not None:
            count_query = count_query.where(Goal.user_id == user_id)
            query = query.where(Goal.user_id == user_id)
        if status is not None:
            count_query = count_query.where(Goal.status == status)
            query = query.where(Goal.status == status)

        count_result = await self.session.execute(count_query)
        total = count_result.scalar() or 0

        query = query.order_by(Goal.created_at.desc()).offset(offset).limit(limit)
        result = await self.session.execute(query)
        goals = list(result.scalars().all())

        return goals, total

    async def update(self, goal: Goal) -> Goal:
        await self.session.merge(goal)
        await self.session.flush()
        await self.session.refresh(goal)
        return goal

    async def delete(self, goal_id: UUID) -> bool:
        goal = await self.get_by_id(goal_id)
        if not goal:
            return False
        await self.session.delete(goal)
        await self.session.flush()
        return True

    async def create_progress_entry(self, entry: GoalProgressEntry) -> GoalProgressEntry:
        self.session.add(entry)
        await self.session.flush()
        await self.session.refresh(entry)
        return entry

    async def commit(self) -> None:
        await self.session.commit()

    async def rollback(self) -> None:
        await self.session.rollback()
