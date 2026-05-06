"""
Script de seed do catálogo de alimentos (Tabela TACO).

Baixa o JSON da Tabela Brasileira de Composição de Alimentos (TACO)
e importa para a tabela food_catalog no PostgreSQL.

Se o download falhar, usa um seed local mínimo.

Uso:
    # Dentro do container Docker:
    python scripts/seed_food.py

    # Com reset forçado:
    python scripts/seed_food.py --force

Fonte dos dados:
    https://github.com/marcelosanto/tabela_taco
    Dados originais: NEPA/UNICAMP (Tabela TACO 4ª edição)
"""

import asyncio
import json
import os
import sys
import urllib.request
from typing import Any, Dict, List

# Adiciona o backend ao path
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

DATASET_URL = (
    "https://raw.githubusercontent.com/marcelosanto/tabela_taco/"
    "main/TACO.json"
)

# Seed local mínimo como fallback (alimentos mais comuns)
LOCAL_FALLBACK_FOODS = [
    {"id": 1, "description": "Arroz, integral, cozido", "category": "Cereais e derivados", "energy_kcal": 111, "protein_g": 2.6, "carbohydrate_g": 23, "lipid_g": 0.9, "fiber_g": 1.6},
    {"id": 2, "description": "Arroz, branco, cozido", "category": "Cereais e derivados", "energy_kcal": 130, "protein_g": 2.7, "carbohydrate_g": 28, "lipid_g": 0.3, "fiber_g": 0.4},
    {"id": 3, "description": "Batata, cozida", "category": "Raízes, tubérculos e derivados", "energy_kcal": 77, "protein_g": 2.1, "carbohydrate_g": 17, "lipid_g": 0.1, "fiber_g": 2.1},
    {"id": 4, "description": "Banana, prata", "category": "Frutas e sucos naturais", "energy_kcal": 89, "protein_g": 1.1, "carbohydrate_g": 23, "lipid_g": 0.3, "fiber_g": 2.7},
    {"id": 5, "description": "Maçã, com pele", "category": "Frutas e sucos naturais", "energy_kcal": 52, "protein_g": 0.3, "carbohydrate_g": 14, "lipid_g": 0.2, "fiber_g": 2.4},
    {"id": 6, "description": "Laranja, pêra", "category": "Frutas e sucos naturais", "energy_kcal": 47, "protein_g": 0.7, "carbohydrate_g": 12, "lipid_g": 0.2, "fiber_g": 2.4},
    {"id": 7, "description": "Peito de frango, cozido", "category": "Carnes e derivados", "energy_kcal": 165, "protein_g": 31, "carbohydrate_g": 0, "lipid_g": 3.6, "fiber_g": 0},
    {"id": 8, "description": "Carne bovina, magra, cozida", "category": "Carnes e derivados", "energy_kcal": 215, "protein_g": 36, "carbohydrate_g": 0, "lipid_g": 8, "fiber_g": 0},
    {"id": 9, "description": "Ovo, inteiro, cozido", "category": "Ovos e derivados", "energy_kcal": 155, "protein_g": 13, "carbohydrate_g": 1.1, "lipid_g": 11, "fiber_g": 0},
    {"id": 10, "description": "Leite, integral", "category": "Leite e produtos lácteos", "energy_kcal": 61, "protein_g": 3.2, "carbohydrate_g": 4.8, "lipid_g": 3.3, "fiber_g": 0},
    {"id": 11, "description": "Iogurte, natural desnatado", "category": "Leite e produtos lácteos", "energy_kcal": 39, "protein_g": 3.5, "carbohydrate_g": 4.7, "lipid_g": 0.4, "fiber_g": 0},
    {"id": 12, "description": "Queijo meia cura", "category": "Leite e produtos lácteos", "energy_kcal": 337, "protein_g": 25, "carbohydrate_g": 1.3, "lipid_g": 27, "fiber_g": 0},
    {"id": 13, "description": "Brócolis, cozido", "category": "Hortaliças", "energy_kcal": 34, "protein_g": 2.8, "carbohydrate_g": 6.6, "lipid_g": 0.4, "fiber_g": 2.4},
    {"id": 14, "description": "Cenoura, cozida", "category": "Hortaliças", "energy_kcal": 41, "protein_g": 0.9, "carbohydrate_g": 10, "lipid_g": 0.2, "fiber_g": 2.8},
    {"id": 15, "description": "Abóbora, cozida", "category": "Hortaliças", "energy_kcal": 30, "protein_g": 1.1, "carbohydrate_g": 7.3, "lipid_g": 0.1, "fiber_g": 1.2},
    {"id": 16, "description": "Pão, branco", "category": "Cereais e derivados", "energy_kcal": 265, "protein_g": 9, "carbohydrate_g": 49, "lipid_g": 3.3, "fiber_g": 2.3},
    {"id": 17, "description": "Feijão, cozido", "category": "Cereais e derivados", "energy_kcal": 76, "protein_g": 5.3, "carbohydrate_g": 14, "lipid_g": 0.3, "fiber_g": 3.7},
    {"id": 18, "description": "Azeite de oliva", "category": "Óleos e gorduras", "energy_kcal": 884, "protein_g": 0, "carbohydrate_g": 0, "lipid_g": 100, "fiber_g": 0},
    {"id": 19, "description": "Chocolate, ao leite", "category": "Açúcares e doces", "energy_kcal": 535, "protein_g": 8.3, "carbohydrate_g": 57, "lipid_g": 30, "fiber_g": 0},
    {"id": 20, "description": "Café, coado", "category": "Bebidas não alcoólicas", "energy_kcal": 0, "protein_g": 0.1, "carbohydrate_g": 0, "lipid_g": 0, "fiber_g": 0},
]


def safe_float(value: Any) -> float:
    """
    Converte valor da TACO para float.

    A tabela TACO usa convenções especiais:
      - "NA" = Não Analisado → 0.0
      - "Tr" = Traço (quantidade desprezível) → 0.0
      - ""   = Não Disponível → 0.0
      - Números normais → float
    """
    if value is None or value == "" or value == "NA" or value == "Tr":
        return 0.0
    try:
        return float(value)
    except (ValueError, TypeError):
        return 0.0


def download_dataset() -> List[Dict[str, Any]]:
    """Baixa o dataset JSON da TACO do GitHub. Retorna fallback local se falhar."""
    print(f"[seed_food] Tentando baixar dataset de: {DATASET_URL}")
    try:
        with urllib.request.urlopen(DATASET_URL, timeout=30) as response:
            data = json.loads(response.read().decode("utf-8"))
        print(f"[seed_food] ✓ Dataset baixado: {len(data)} alimentos.")
        return data
    except Exception as e:
        print(f"[seed_food] ⚠️  Erro ao baixar dataset: {e}")
        print(f"[seed_food] ℹ️  Usando seed local mínimo com {len(LOCAL_FALLBACK_FOODS)} alimentos mais comuns.")
        return LOCAL_FALLBACK_FOODS


async def seed(force: bool = False) -> None:
    """Importa alimentos da TACO para a tabela food_catalog."""
    from sqlalchemy import select, text
    from sqlalchemy.ext.asyncio import create_async_engine, AsyncSession
    from sqlalchemy.orm import sessionmaker

    from app.config.settings import settings
    from app.models.user import Base
    from app.models.food_catalog import FoodCatalog
    import app.models  # noqa: F401 — garante que Base.metadata tem todas as tabelas

    engine = create_async_engine(settings.DATABASE_URL, echo=False)
    async_session = sessionmaker(engine, class_=AsyncSession, expire_on_commit=False)

    # Garantir que as tabelas existem
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
    print("[seed_food] Tabelas verificadas/criadas.")

    async with async_session() as session:
        # Verificar se já existe dados
        count_result = await session.execute(
            select(FoodCatalog).limit(1)
        )
        existing = count_result.scalars().first()

        if existing and not force:
            print("[seed_food] Catálogo já contém dados. Use --force para reimportar.")
            return

        if force and existing:
            print("[seed_food] Limpando catálogo existente (--force)...")
            await session.execute(text("DELETE FROM food_catalog"))
            await session.commit()

        # Baixar dataset
        foods = download_dataset()

        # Importar
        print(f"[seed_food] Importando {len(foods)} alimentos...")
        batch_size = 100
        imported = 0
        skipped = 0

        for i, food in enumerate(foods):
            try:
                food_id = food.get("id")
                name = food.get("description", "").strip()

                if not food_id or not name:
                    skipped += 1
                    continue

                catalog_item = FoodCatalog(
                    id=int(food_id),
                    name=name,
                    category=food.get("category"),
                    energy_kcal=safe_float(food.get("energy_kcal")),
                    protein_g=safe_float(food.get("protein_g")),
                    carbohydrate_g=safe_float(food.get("carbohydrate_g")),
                    lipid_g=safe_float(food.get("lipid_g")),
                    fiber_g=safe_float(food.get("fiber_g")),
                )
                session.add(catalog_item)
                imported += 1

                # Commit em batches para evitar sobrecarga
                if (i + 1) % batch_size == 0:
                    await session.commit()
                    print(f"[seed_food]   {imported} importados...")

            except Exception as e:
                print(f"[seed_food] AVISO: erro ao importar '{food.get('id', '?')}': {e}")
                skipped += 1
                continue

        await session.commit()

    print(f"\n[seed_food] ✅ Concluído!")
    print(f"[seed_food]   Importados: {imported}")
    print(f"[seed_food]   Ignorados:  {skipped}")
    print(f"[seed_food]   Total:      {len(foods)}")


if __name__ == "__main__":
    force = "--force" in sys.argv
    if force:
        print("[seed_food] Modo --force ativado: dados existentes serão substituídos.")
    asyncio.run(seed(force=force))
