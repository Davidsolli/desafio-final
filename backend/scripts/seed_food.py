"""
Script de seed do catálogo de alimentos (Tabela TACO).

Baixa o JSON da Tabela Brasileira de Composição de Alimentos (TACO)
e importa para a tabela food_catalog no PostgreSQL.

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
    """Baixa o dataset JSON da TACO do GitHub."""
    print(f"[seed_food] Baixando dataset de: {DATASET_URL}")
    try:
        with urllib.request.urlopen(DATASET_URL, timeout=30) as response:
            data = json.loads(response.read().decode("utf-8"))
        print(f"[seed_food] Dataset baixado: {len(data)} alimentos.")
        return data
    except Exception as e:
        print(f"[seed_food] ERRO ao baixar dataset: {e}")
        print("[seed_food] Verifique sua conexão e tente novamente.")
        sys.exit(1)


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
