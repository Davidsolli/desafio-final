"""
Modelo SQLAlchemy para o catálogo de exercícios.

Tabela somente leitura (seed via script), usada para fornecer
sugestões de exercícios ao personal ao montar fichas.
Os dados vêm do dataset open-source PT-BR:
  https://github.com/joao-gugel/exercicios-bd-ptbr
"""

from sqlalchemy import Column, String, Text
from sqlalchemy.dialects.postgresql import ARRAY, JSON

from app.models.user import Base


class ExerciseCatalog(Base):
    """
    Catálogo de exercícios pré-carregados (somente leitura).

    Populado via: backend/scripts/seed_exercises.py
    Fonte dos dados: exercicios-bd-ptbr (tradução PT-BR do free-exercise-db)

    Atributos:
        id: ID original do dataset (ex: "3_4_Sit-Up")
        name: Nome em português
        category: Categoria (força, cardio, etc.)
        level: Nível (iniciante, intermediário, avançado)
        equipment: Equipamento necessário
        primary_muscles: Músculos primários (lista)
        secondary_muscles: Músculos secundários (lista)
        instructions: Passo a passo em português (lista)
        image_url: URL da imagem estática
        gif_url: URL do GIF demonstrativo
        muscle_group_mapped: Valor mapeado para VALID_MUSCLE_GROUPS do sistema
    """

    __tablename__ = "exercise_catalog"

    id = Column(String(100), primary_key=True, nullable=False)

    name = Column(String(255), nullable=False, index=True)

    category = Column(String(100), nullable=True, index=True)

    level = Column(String(50), nullable=True, index=True)

    equipment = Column(String(100), nullable=True)

    primary_muscles = Column(JSON, nullable=True)   # list[str]

    secondary_muscles = Column(JSON, nullable=True)  # list[str]

    instructions = Column(JSON, nullable=True)       # list[str]

    image_url = Column(String(2048), nullable=True)

    gif_url = Column(String(2048), nullable=True)

    # Valor mapeado para o enum interno do sistema (VALID_MUSCLE_GROUPS)
    muscle_group_mapped = Column(String(50), nullable=True, index=True)

    def __repr__(self) -> str:
        return f"<ExerciseCatalog(id={self.id!r}, name={self.name!r})>"
