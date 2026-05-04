"""
Modelo SQLAlchemy para o catálogo de alimentos (Tabela TACO).

Tabela somente leitura (seed via script), usada como base oficial
de composição nutricional dos alimentos brasileiros.

Fonte dos dados:
    Tabela Brasileira de Composição de Alimentos (TACO) — NEPA/UNICAMP
    https://github.com/marcelosanto/tabela_taco
"""

from sqlalchemy import Column, Float, Integer, String

from app.models.user import Base


class FoodCatalog(Base):
    """
    Catálogo de alimentos da Tabela TACO (somente leitura).

    Populado via: backend/scripts/seed_food.py
    Valores nutricionais referem-se a 100g do alimento.

    Atributos:
        id: ID original da TACO (1–597)
        name: Nome do alimento (ex: "Arroz, integral, cozido")
        category: Categoria (ex: "Cereais e derivados", "Carnes")
        energy_kcal: Calorias em 100g
        protein_g: Proteínas em 100g
        carbohydrate_g: Carboidratos em 100g
        lipid_g: Gorduras totais em 100g
        fiber_g: Fibras em 100g
    """

    __tablename__ = "food_catalog"

    id = Column(Integer, primary_key=True, nullable=False)

    name = Column(String(255), nullable=False, index=True)

    category = Column(String(100), nullable=True, index=True)

    energy_kcal = Column(Float, nullable=False, default=0.0)

    protein_g = Column(Float, nullable=False, default=0.0)

    carbohydrate_g = Column(Float, nullable=False, default=0.0)

    lipid_g = Column(Float, nullable=False, default=0.0)

    fiber_g = Column(Float, nullable=False, default=0.0)

    def __repr__(self) -> str:
        return f"<FoodCatalog(id={self.id}, name={self.name!r})>"
