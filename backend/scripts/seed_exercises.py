"""
Script de seed do catálogo de exercícios.

Baixa o dataset PT-BR de exercícios (exercicios-bd-ptbr) e importa
para a tabela exercise_catalog no PostgreSQL.

Uso:
    # Dentro do container Docker:
    python scripts/seed_exercises.py

    # Com reset forçado:
    python scripts/seed_exercises.py --force

Fonte dos dados:
    https://github.com/joao-gugel/exercicios-bd-ptbr
    (tradução PT-BR do free-exercise-db de yuhonas)
"""

import asyncio
import json
import os
import sys
import urllib.request
from typing import Any, Dict, List, Optional

# Adiciona o backend ao path
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

DATASET_URL = (
    "https://raw.githubusercontent.com/joao-gugel/exercicios-bd-ptbr/"
    "main/exercises/exercises-ptbr-full-translation.json"
)

# CDN base para imagens do repo original
IMAGE_CDN = (
    "https://raw.githubusercontent.com/yuhonas/free-exercise-db/"
    "main/exercises/"
)

# Mapeamento de músculos PT-BR para VALID_MUSCLE_GROUPS do sistema
MUSCLE_MAPPING: Dict[str, str] = {
    "abdominais": "core",
    "triceps": "tríceps",
    "meio-das-costas": "costa",
    "gluteos": "perna_posterior",
    "peito": "peito",
    "quadriceps": "perna_anterior",
    "ombros": "ombro",
    "abdutores": "perna_posterior",
    "pescoco": "costa",
    "panturrilhas": "panturrilha",
    "biceps": "bíceps",
    "adutores": "perna_anterior",
    "isquiotibiais": "perna_posterior",
    "dorsais": "costa",
    "trapezio": "costa",
    "antebracos": "antebraço",
    "inferior-das-costas": "costa"
}


def map_muscle_group(primary_muscles: Optional[List[str]]) -> Optional[str]:
    """Mapeia lista de músculos primários para o grupo do sistema."""
    if not primary_muscles:
        return None
    for muscle in primary_muscles:
        normalized = muscle.lower().strip()
        if normalized in MUSCLE_MAPPING:
            return MUSCLE_MAPPING[normalized]
    return None


def build_image_url(exercise_id: str, index: int = 0) -> Optional[str]:
    """Constrói URL da imagem a partir do ID do exercício."""
    return f"{IMAGE_CDN}{exercise_id}/{index}.jpg"


def build_gif_url(exercise_id: str) -> Optional[str]:
    """Constrói URL do GIF demonstrativo."""
    # O repo original tem imagens estáticas, não GIFs. Retorna None por ora.
    return None


def download_dataset() -> List[Dict[str, Any]]:
    """Baixa o dataset JSON PT-BR do GitHub."""
    print(f"[seed] Baixando dataset de: {DATASET_URL}")
    try:
        with urllib.request.urlopen(DATASET_URL, timeout=30) as response:
            data = json.loads(response.read().decode("utf-8"))
        print(f"[seed] Dataset baixado: {len(data)} exercícios.")
        return data
    except Exception as e:
        print(f"[seed] ERRO ao baixar dataset: {e}")
        print("[seed] Verifique sua conexão e tente novamente.")
        sys.exit(1)


async def seed(force: bool = False) -> None:
    """Importa exercícios para a tabela exercise_catalog."""
    from sqlalchemy import select, text
    from sqlalchemy.ext.asyncio import create_async_engine, AsyncSession
    from sqlalchemy.orm import sessionmaker

    from app.config.settings import settings
    from app.models.exercise_catalog import ExerciseCatalog
    import app.models  # noqa: F401 — garante que Base.metadata tem todas as tabelas

    engine = create_async_engine(settings.DATABASE_URL, echo=False)
    async_session = sessionmaker(engine, class_=AsyncSession, expire_on_commit=False)

    async with async_session() as session:
        # Verificar se já existe dados
        count_result = await session.execute(
            select(ExerciseCatalog).limit(1)
        )
        existing = count_result.scalars().first()

        if existing and not force:
            print("[seed] Catálogo já contém dados. Use --force para reimportar.")
            return

        if force and existing:
            print("[seed] Limpando catálogo existente (--force)...")
            await session.execute(text("DELETE FROM exercise_catalog"))
            await session.commit()

        # Baixar dataset
        exercises = download_dataset()

        # Importar
        print(f"[seed] Importando {len(exercises)} exercícios...")
        batch_size = 100
        imported = 0
        skipped = 0

        for i, ex in enumerate(exercises):
            try:
                exercise_id = ex.get("id", "")
                name = ex.get("name", "").strip()
                primary_muscles = ex.get("primaryMuscles", [])
                secondary_muscles = ex.get("secondaryMuscles", [])
                images = ex.get("images", [])

                if not exercise_id or not name:
                    skipped += 1
                    continue

                image_url = build_image_url(exercise_id, 0) if images else None
                gif_url = build_gif_url(exercise_id)
                muscle_group_mapped = map_muscle_group(primary_muscles)

                catalog_item = ExerciseCatalog(
                    id=exercise_id,
                    name=name,
                    category=ex.get("category"),
                    level=ex.get("level"),
                    equipment=ex.get("equipment"),
                    primary_muscles=primary_muscles,
                    secondary_muscles=secondary_muscles,
                    instructions=ex.get("instructions", []),
                    image_url=image_url,
                    gif_url=gif_url,
                    muscle_group_mapped=muscle_group_mapped,
                )
                session.add(catalog_item)
                imported += 1

                # Commit em batches para evitar sobrecarga
                if (i + 1) % batch_size == 0:
                    await session.commit()
                    print(f"[seed]   {imported} importados...")

            except Exception as e:
                print(f"[seed] AVISO: erro ao importar '{ex.get('id', '?')}': {e}")
                skipped += 1
                continue

        await session.commit()

    print(f"\n[seed] ✅ Concluído!")
    print(f"[seed]   Importados: {imported}")
    print(f"[seed]   Ignorados:  {skipped}")
    print(f"[seed]   Total:      {len(exercises)}")


if __name__ == "__main__":
    force = "--force" in sys.argv
    if force:
        print("[seed] Modo --force ativado: dados existentes serão substituídos.")
    asyncio.run(seed(force=force))
