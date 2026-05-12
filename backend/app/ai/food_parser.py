"""
Parser de refeição a partir de texto transcrito.

Fluxo:
  1. LLM extrai: food_name, quantity_g, meal_name do texto
  2. Busca FoodCatalog (TACO) com ILIKE no nome extraído
  3. Se múltiplos resultados: LLM escolhe o melhor match
  4. Retorna FoodParseResult com o alimento identificado e sua categoria

Nunca cria registros de CustomFood automaticamente — apenas usa o catálogo TACO.
Se o alimento não for encontrado, levanta FoodNotFoundError para que o
endpoint possa informar o usuário adequadamente.
"""

from __future__ import annotations

import json
import logging
import re
from dataclasses import dataclass
from datetime import datetime
from typing import Any

from langchain_core.messages import HumanMessage, SystemMessage
from langchain_groq import ChatGroq
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.config.settings import settings
from app.models.food_catalog import FoodCatalog

logger = logging.getLogger(__name__)

# ── Prompts ────────────────────────────────────────────────────────────────────

_EXTRACT_PROMPT = """\
Você recebeu a fala de um usuário descrevendo o que comeu.

Extraia as informações e retorne SOMENTE um JSON válido, sem textos extras:
{{
  "food_name": "<nome do alimento em português, sem modo de preparo>",
  "quantity_g": <número em gramas, float>,
  "meal_name": "<refeição: Café da Manhã | Lanche da Manhã | Almoço | Lanche da Tarde | Jantar | Ceia>",
  "confidence": "<high se identificou claramente, low se teve de inferir>"
}}

Regras:
- "food_name": apenas o alimento base (ex: "arroz integral", "frango", "banana"), sem modo de
  preparo como "grelhado", "cozido". Isso facilita a busca no catálogo nutricional.
- "quantity_g": se a fala disser "1 unidade" e for fruta, converta para gramas típicos.
  Se disser "1 prato" ou similar, estime em gramas. Se não mencionar, use null.
- "meal_name": se não mencionado, infira pelo horário atual ({current_time}).
- Se não conseguir identificar o alimento: "food_name": null
- Se não conseguir identificar a quantidade: "quantity_g": null

Fala do usuário: "{transcription}"

JSON:"""

_PICK_BEST_MATCH_PROMPT = """\
O usuário disse que comeu "{food_name_raw}".

Os seguintes alimentos foram encontrados no catálogo nutricional TACO:
{candidates}

Qual desses alimentos é o mais provável que o usuário quis dizer?
Retorne SOMENTE o número da opção (ex: "2"), sem explicações.\
"""

_JSON_EXTRACTION_RE = re.compile(r"\{[^{}]+\}", re.DOTALL)


def _infer_meal_name(local_hour: int | None = None) -> str:
    """
    Infere o nome da refeição pelo horário.

    Usa `local_hour` (enviado pelo cliente) quando disponível — garante
    que a refeição reflita o horário local do usuário, não o UTC do servidor.
    Cai para `datetime.now().hour` (UTC) apenas como fallback.
    """
    hour = local_hour if local_hour is not None else datetime.now().hour
    if 6 <= hour < 10:
        return "Café da Manhã"
    if 10 <= hour < 12:
        return "Lanche da Manhã"
    if 12 <= hour < 15:
        return "Almoço"
    if 15 <= hour < 18:
        return "Lanche da Tarde"
    if 18 <= hour < 21:
        return "Jantar"
    return "Ceia"


# ── Exceções ───────────────────────────────────────────────────────────────────

class FoodParseError(Exception):
    """Erro geral ao interpretar a fala."""


class FoodNotFoundError(FoodParseError):
    """Alimento não encontrado no catálogo TACO."""


class QuantityNotFoundError(FoodParseError):
    """Quantidade não identificada na fala."""


# ── Resultado ──────────────────────────────────────────────────────────────────

@dataclass
class FoodParseResult:
    """Resultado do parser de refeição."""

    food_name_raw: str          # Nome como o LLM extraiu da fala
    quantity_g: float
    meal_name: str
    catalog_item: FoodCatalog   # Melhor match no catálogo TACO
    confidence: str             # "high" | "low"


# ── Serviço ────────────────────────────────────────────────────────────────────

class FoodParser:
    """
    Interpreta texto descrevendo uma refeição e identifica o alimento no catálogo.

    Uso:
        parser = FoodParser()
        result = await parser.parse("comi 150 gramas de arroz integral", session)
        # result.catalog_item.id → food_id para o DietLogbookEntry
    """

    def _get_llm(self) -> ChatGroq:
        return ChatGroq(
            model_name=settings.GROQ_MODEL,
            groq_api_key=settings.GROQ_API_KEY,
            temperature=0.0,    # determinístico para parsing estruturado
            max_tokens=256,
        )

    # ── Etapa 1: Extrair alimento + quantidade + refeição ─────────────────────

    async def _extract_from_text(self, transcription: str) -> dict[str, Any]:
        """
        Chama o LLM para estruturar a fala do usuário como JSON.

        Returns:
            Dict com food_name, quantity_g, meal_name, confidence.

        Raises:
            FoodParseError: Se o LLM não retornar JSON válido.
        """
        llm = self._get_llm()
        current_time = datetime.now().strftime("%H:%M")

        prompt = _EXTRACT_PROMPT.format(
            transcription=transcription,
            current_time=current_time,
        )

        response = await llm.ainvoke([HumanMessage(content=prompt)])
        raw = response.content.strip()

        logger.debug("LLM extract raw: %r", raw[:200])

        # Tolerância: extrair JSON de dentro de blocos `json ... ` ou similar
        match = _JSON_EXTRACTION_RE.search(raw)
        json_str = match.group(0) if match else raw

        try:
            data = json.loads(json_str)
        except json.JSONDecodeError as exc:
            raise FoodParseError(
                f"LLM retornou resposta inválida para o alimento: {raw!r}"
            ) from exc

        return data

    # ── Etapa 2: Buscar no catálogo TACO ─────────────────────────────────────

    async def _search_catalog(
        self, food_name: str, session: AsyncSession, limit: int = 8
    ) -> list[FoodCatalog]:
        """
        Busca alimentos no catálogo TACO usando ILIKE com fallback por palavra-chave.

        Estratégia:
          1. Busca com o nome completo extraído (ILIKE "%{name}%")
          2. Se 0 resultados: busca novamente com a palavra mais longa do nome
             (geralmente é a mais específica — ex: "frango" de "peito de frango")
        """
        async def _ilike_search(term: str) -> list[FoodCatalog]:
            stmt = (
                select(FoodCatalog)
                .where(FoodCatalog.name.ilike(f"%{term}%"))
                .order_by(FoodCatalog.name)
                .limit(limit)
            )
            result = await session.execute(stmt)
            return list(result.scalars().all())

        items = await _ilike_search(food_name)
        if items:
            return items

        # Fallback: palavra mais longa (filtra artigos e preposições)
        stopwords = {"de", "da", "do", "com", "em", "ao", "à", "e", "para", "no", "na"}
        words = [w for w in food_name.lower().split() if w not in stopwords and len(w) > 2]
        if words:
            keyword = max(words, key=len)
            if keyword != food_name.lower():
                logger.debug("Fallback keyword search: %r → %r", food_name, keyword)
                items = await _ilike_search(keyword)

        return items

    # ── Etapa 3: Escolher melhor match (quando há múltiplos) ─────────────────

    async def _pick_best_match(
        self, food_name_raw: str, candidates: list[FoodCatalog]
    ) -> FoodCatalog:
        """
        Pede ao LLM para escolher o melhor match entre os candidatos.

        Com apenas 1 candidato, devolve diretamente sem chamar o LLM.
        """
        if len(candidates) == 1:
            return candidates[0]

        llm = self._get_llm()
        candidates_text = "\n".join(
            f"{i + 1}. {c.name} ({c.category})"
            for i, c in enumerate(candidates)
        )
        prompt = _PICK_BEST_MATCH_PROMPT.format(
            food_name_raw=food_name_raw,
            candidates=candidates_text,
        )

        response = await llm.ainvoke([HumanMessage(content=prompt)])
        raw = response.content.strip()

        logger.debug("LLM pick_best_match: raw=%r | candidates=%d", raw, len(candidates))

        # Extrai número da resposta
        digits = re.findall(r"\d+", raw)
        if digits:
            idx = int(digits[0]) - 1  # 1-based → 0-based
            if 0 <= idx < len(candidates):
                return candidates[idx]

        # Fallback: primeiro resultado
        logger.warning("LLM não retornou índice válido (%r), usando primeiro candidato", raw)
        return candidates[0]

    # ── Pipeline principal ────────────────────────────────────────────────────

    async def parse(
        self,
        transcription: str,
        session: AsyncSession,
        local_hour: int | None = None,
    ) -> FoodParseResult:
        """
        Interpreta a transcrição e identifica o alimento no catálogo TACO.

        Args:
            transcription: Texto transcrito do áudio do usuário.
            session: Sessão assíncrona do banco de dados.

        Returns:
            FoodParseResult com alimento identificado e metadados da refeição.

        Raises:
            FoodParseError: Erro ao interpretar o texto.
            FoodNotFoundError: Alimento não encontrado no catálogo TACO.
            QuantityNotFoundError: Quantidade não mencionada pelo usuário.
        """
        # Etapa 1: Extração estruturada
        extracted = await self._extract_from_text(transcription)
        logger.info("Extração: %s", extracted)

        food_name_raw: str | None = extracted.get("food_name")
        quantity_g_raw = extracted.get("quantity_g")
        meal_name: str = extracted.get("meal_name") or _infer_meal_name(local_hour)
        confidence: str = extracted.get("confidence", "low")

        if not food_name_raw:
            raise FoodParseError(
                "Não consegui identificar o alimento na sua fala. "
                "Tente dizer, por exemplo: 'comi 150 gramas de arroz integral'."
            )

        if quantity_g_raw is None:
            raise QuantityNotFoundError(
                f"Identifiquei '{food_name_raw}' mas não a quantidade. "
                "Tente incluir a quantidade em gramas, ex: '200 gramas de frango'."
            )

        try:
            quantity_g = float(quantity_g_raw)
        except (TypeError, ValueError):
            raise QuantityNotFoundError(
                f"Não entendi a quantidade para '{food_name_raw}'. "
                "Informe em gramas, ex: '150 gramas'."
            )

        if quantity_g <= 0:
            raise QuantityNotFoundError("A quantidade deve ser maior que zero.")

        # Etapa 2: Busca no catálogo
        candidates = await self._search_catalog(food_name_raw, session)

        if not candidates:
            raise FoodNotFoundError(
                f"'{food_name_raw}' não foi encontrado no catálogo nutricional. "
                "Tente digitar o nome do alimento manualmente pelo app."
            )

        # Etapa 3: Melhor match
        best_match = await self._pick_best_match(food_name_raw, candidates)

        logger.info(
            "Parser concluído | raw=%r → TACO=%r (id=%d) | qty=%.1fg | meal=%r",
            food_name_raw,
            best_match.name,
            best_match.id,
            quantity_g,
            meal_name,
        )

        return FoodParseResult(
            food_name_raw=food_name_raw,
            quantity_g=quantity_g,
            meal_name=meal_name,
            catalog_item=best_match,
            confidence=confidence,
        )


# Singleton reutilizável
food_parser = FoodParser()
