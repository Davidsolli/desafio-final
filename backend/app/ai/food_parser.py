"""
Parser de refeição a partir de texto transcrito.

Fluxo:
  1. LLM extrai: food_name, quantity_g, meal_name do texto
  2. Busca FoodCatalog (TACO) com ILIKE no nome extraído
  3. Se múltiplos resultados: LLM escolhe o melhor match
  4. [FALLBACK] Se não encontrado na TACO:
       a. Busca dados nutricionais na web via Tavily Search
       b. LLM extrai macros dos resultados web
       c. Cria CustomFood vinculado ao usuário
  5. [FALLBACK LLM] Se Tavily falhar ou não retornar dados úteis:
       a. LLM estima macros com base no conhecimento interno
       b. Cria CustomFood com categoria "estimativa_ia"

Fontes possíveis no FoodParseResult.source:
  "taco"       — catálogo oficial TACO (mais confiável)
  "web"        — dados encontrados via Tavily na web
  "estimativa" — estimativa do LLM (menos preciso, indica incerteza)
"""

from __future__ import annotations

import json
import logging
import re
from dataclasses import dataclass, field
from datetime import datetime
from typing import Any
from uuid import UUID

from langchain_core.messages import HumanMessage
from langchain_groq import ChatGroq
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.config.settings import settings
from app.models.diet import CustomFood
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

_NUTRITION_EXTRACT_PROMPT = """\
Com base nas informações abaixo encontradas na web, extraia os valores
nutricionais de "{food_name}" POR 100g.

Retorne SOMENTE um JSON válido, sem textos extras:
{{
  "energy_kcal": <float>,
  "protein_g": <float>,
  "carbohydrate_g": <float>,
  "lipid_g": <float>,
  "fiber_g": <float>,
  "confidence": "<high|medium|low>"
}}

Regras:
- Todos os valores devem ser por 100g do alimento.
- Se não for possível extrair um valor com segurança, use 0.0.
- Não invente valores — use apenas o que está nas informações abaixo.

Informações da web:
{search_results}

JSON:"""

_NUTRITION_ESTIMATE_PROMPT = """\
Você é um nutricionista especialista. Estime os valores nutricionais médios
de "{food_name}" POR 100g, usando seu conhecimento.

Retorne SOMENTE um JSON válido, sem textos extras:
{{
  "energy_kcal": <float>,
  "protein_g": <float>,
  "carbohydrate_g": <float>,
  "lipid_g": <float>,
  "fiber_g": <float>
}}

Forneça estimativas razoáveis baseadas em dados nutricionais típicos deste alimento.
JSON:"""

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


def _parse_nutrition_json(raw: str) -> dict[str, float] | None:
    """Extrai e valida JSON de macros de uma resposta LLM."""
    match = _JSON_EXTRACTION_RE.search(raw)
    json_str = match.group(0) if match else raw
    try:
        data = json.loads(json_str)
        # Verifica que tem pelo menos kcal
        if "energy_kcal" in data:
            return {
                "energy_kcal": float(data.get("energy_kcal") or 0),
                "protein_g": float(data.get("protein_g") or 0),
                "carbohydrate_g": float(data.get("carbohydrate_g") or 0),
                "lipid_g": float(data.get("lipid_g") or 0),
                "fiber_g": float(data.get("fiber_g") or 0),
            }
    except (json.JSONDecodeError, TypeError, ValueError):
        pass
    return None


# ── Exceções ───────────────────────────────────────────────────────────────────

class FoodParseError(Exception):
    """Erro geral ao interpretar a fala."""


class FoodNotFoundError(FoodParseError):
    """Alimento não encontrado em nenhuma fonte (TACO, web, LLM)."""


class QuantityNotFoundError(FoodParseError):
    """Quantidade não identificada na fala."""


# ── Resultado ──────────────────────────────────────────────────────────────────

@dataclass
class FoodParseResult:
    """Resultado do parser de refeição."""

    food_name_raw: str          # Nome como o LLM extraiu da fala
    quantity_g: float
    meal_name: str
    confidence: str             # "high" | "low"
    source: str                 # "taco" | "web" | "estimativa"

    # Exatamente um dos dois estará preenchido
    catalog_item: FoodCatalog | None = None     # fonte: taco
    custom_food: CustomFood | None = None       # fonte: web | estimativa


# ── Serviço ────────────────────────────────────────────────────────────────────

class FoodParser:
    """
    Interpreta texto descrevendo uma refeição e identifica o alimento.

    Cascata de fontes:
      1. Catálogo TACO (banco local)
      2. Busca web via Tavily + extração LLM → cria CustomFood
      3. Estimativa LLM pura → cria CustomFood com aviso

    Uso:
        parser = FoodParser()
        result = await parser.parse(
            "comi 150 gramas de whey protein",
            session,
            user_id=user_uuid,
        )
    """

    def _get_llm(self) -> ChatGroq:
        return ChatGroq(
            model_name=settings.GROQ_MODEL,
            groq_api_key=settings.GROQ_API_KEY,
            temperature=0.0,
            max_tokens=256,
        )

    # ── Etapa 1: Extrair alimento + quantidade + refeição ─────────────────────

    async def _extract_from_text(self, transcription: str) -> dict[str, Any]:
        """Chama o LLM para estruturar a fala do usuário como JSON."""
        llm = self._get_llm()
        prompt = _EXTRACT_PROMPT.format(
            transcription=transcription,
            current_time=datetime.now().strftime("%H:%M"),
        )
        response = await llm.ainvoke([HumanMessage(content=prompt)])
        raw = response.content.strip()
        logger.debug("LLM extract raw: %r", raw[:200])

        match = _JSON_EXTRACTION_RE.search(raw)
        json_str = match.group(0) if match else raw
        try:
            return json.loads(json_str)
        except json.JSONDecodeError as exc:
            raise FoodParseError(
                f"LLM retornou resposta inválida para o alimento: {raw!r}"
            ) from exc

    # ── Etapa 2: Buscar no catálogo TACO ─────────────────────────────────────

    async def _search_catalog(
        self, food_name: str, session: AsyncSession, limit: int = 8
    ) -> list[FoodCatalog]:
        """Busca TACO com ILIKE + fallback por palavra-chave."""
        async def _ilike(term: str) -> list[FoodCatalog]:
            stmt = (
                select(FoodCatalog)
                .where(FoodCatalog.name.ilike(f"%{term}%"))
                .order_by(FoodCatalog.name)
                .limit(limit)
            )
            result = await session.execute(stmt)
            return list(result.scalars().all())

        items = await _ilike(food_name)
        if items:
            return items

        stopwords = {"de", "da", "do", "com", "em", "ao", "à", "e", "para", "no", "na"}
        words = [w for w in food_name.lower().split() if w not in stopwords and len(w) > 2]
        if words:
            keyword = max(words, key=len)
            if keyword != food_name.lower():
                items = await _ilike(keyword)
        return items

    # ── Etapa 3: Escolher melhor match na TACO ────────────────────────────────

    async def _pick_best_match(
        self, food_name_raw: str, candidates: list[FoodCatalog]
    ) -> FoodCatalog:
        """LLM escolhe melhor candidato quando há múltiplos resultados."""
        if len(candidates) == 1:
            return candidates[0]

        llm = self._get_llm()
        candidates_text = "\n".join(
            f"{i + 1}. {c.name} ({c.category})" for i, c in enumerate(candidates)
        )
        prompt = _PICK_BEST_MATCH_PROMPT.format(
            food_name_raw=food_name_raw, candidates=candidates_text
        )
        response = await llm.ainvoke([HumanMessage(content=prompt)])
        digits = re.findall(r"\d+", response.content.strip())
        if digits:
            idx = int(digits[0]) - 1
            if 0 <= idx < len(candidates):
                return candidates[idx]

        logger.warning("LLM não retornou índice válido, usando primeiro candidato")
        return candidates[0]

    # ── Etapa 4a: Busca web via Tavily ────────────────────────────────────────

    async def _search_web_nutrition(
        self, food_name: str, session: AsyncSession, user_id: UUID
    ) -> CustomFood | None:
        """
        Busca macros do alimento na web via Tavily e salva como CustomFood.

        Retorna None se a busca não retornar dados úteis ou se Tavily não
        estiver configurado.
        """
        if not settings.TAVILY_API_KEY:
            logger.debug("TAVILY_API_KEY não configurada — pulando busca web")
            return None

        try:
            from tavily import AsyncTavilyClient
        except ImportError:
            logger.warning("tavily-python não instalado — pulando busca web")
            return None

        query = (
            f"tabela nutricional {food_name} por 100g "
            "calorias proteína carboidrato gordura"
        )
        logger.info("Tavily search: %r", query)

        try:
            client = AsyncTavilyClient(api_key=settings.TAVILY_API_KEY)
            response = await client.search(
                query=query,
                search_depth="basic",
                max_results=4,
                include_answer=True,
            )
        except Exception as exc:
            logger.warning("Tavily search falhou: %s", exc)
            return None

        # Montar texto com os resultados para o LLM
        snippets: list[str] = []
        if response.get("answer"):
            snippets.append(f"Resumo: {response['answer']}")
        for r in response.get("results", [])[:4]:
            content = r.get("content", "")[:600]
            if content:
                snippets.append(f"Fonte: {r.get('url', '')}\n{content}")

        if not snippets:
            logger.info("Tavily não retornou resultados úteis para %r", food_name)
            return None

        search_text = "\n\n".join(snippets)

        # LLM extrai macros do texto web
        llm = self._get_llm()
        prompt = _NUTRITION_EXTRACT_PROMPT.format(
            food_name=food_name,
            search_results=search_text,
        )
        try:
            llm_response = await llm.ainvoke([HumanMessage(content=prompt)])
            macros = _parse_nutrition_json(llm_response.content)
        except Exception as exc:
            logger.warning("LLM falhou ao extrair macros da web: %s", exc)
            return None

        if not macros or macros["energy_kcal"] == 0:
            logger.info("LLM não extraiu macros válidos dos resultados web para %r", food_name)
            return None

        logger.info(
            "Web search OK | %r → kcal=%.1f prot=%.1f carbs=%.1f fat=%.1f",
            food_name,
            macros["energy_kcal"],
            macros["protein_g"],
            macros["carbohydrate_g"],
            macros["lipid_g"],
        )

        return await self._create_custom_food(
            food_name=food_name,
            macros=macros,
            category="web_search",
            session=session,
            user_id=user_id,
        )

    # ── Etapa 4b: Estimativa via LLM ─────────────────────────────────────────

    async def _estimate_nutrition_llm(
        self, food_name: str, session: AsyncSession, user_id: UUID
    ) -> CustomFood | None:
        """
        Estima macros do alimento usando o conhecimento interno do LLM.
        Usado como último fallback quando TACO e web não têm o alimento.
        """
        llm = self._get_llm()
        prompt = _NUTRITION_ESTIMATE_PROMPT.format(food_name=food_name)

        try:
            response = await llm.ainvoke([HumanMessage(content=prompt)])
            macros = _parse_nutrition_json(response.content)
        except Exception as exc:
            logger.warning("LLM estimation falhou: %s", exc)
            return None

        if not macros or macros["energy_kcal"] == 0:
            return None

        logger.info(
            "LLM estimate | %r → kcal=%.1f (estimativa)",
            food_name,
            macros["energy_kcal"],
        )

        return await self._create_custom_food(
            food_name=food_name,
            macros=macros,
            category="estimativa_ia",
            session=session,
            user_id=user_id,
        )

    # ── Helper: criar CustomFood ──────────────────────────────────────────────

    async def _create_custom_food(
        self,
        food_name: str,
        macros: dict[str, float],
        category: str,
        session: AsyncSession,
        user_id: UUID,
    ) -> CustomFood:
        """Persiste um novo CustomFood com os macros fornecidos."""
        from app.repositories.diet_repository import DietRepository

        repo = DietRepository(session)
        custom_food = CustomFood(
            user_id=user_id,
            name=food_name,
            category=category,
            energy_kcal=macros["energy_kcal"],
            protein_g=macros["protein_g"],
            carbohydrate_g=macros["carbohydrate_g"],
            lipid_g=macros["lipid_g"],
            fiber_g=macros["fiber_g"],
        )
        created = await repo.create_custom_food(custom_food)
        logger.info(
            "CustomFood criado | id=%s | name=%r | category=%r | user=%s",
            created.id,
            created.name,
            created.category,
            user_id,
        )
        return created

    # ── Pipeline principal ────────────────────────────────────────────────────

    async def parse(
        self,
        transcription: str,
        session: AsyncSession,
        local_hour: int | None = None,
        user_id: UUID | None = None,
    ) -> FoodParseResult:
        """
        Interpreta a transcrição e identifica o alimento.

        Cascata: TACO → Tavily web search → LLM estimate

        Args:
            transcription: Texto transcrito do áudio do usuário.
            session: Sessão assíncrona do banco de dados.
            local_hour: Hora local do dispositivo para inferir refeição.
            user_id: UUID do aluno. Obrigatório para criar CustomFood no fallback.

        Returns:
            FoodParseResult com alimento identificado, fonte e metadados.

        Raises:
            FoodParseError: Erro ao interpretar o texto.
            FoodNotFoundError: Alimento não encontrado em nenhuma fonte.
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

        # Etapa 2: Busca no catálogo TACO
        candidates = await self._search_catalog(food_name_raw, session)

        if candidates:
            # Caminho feliz — encontrado na TACO
            best_match = await self._pick_best_match(food_name_raw, candidates)
            logger.info(
                "Parser TACO | raw=%r → %r (id=%d) | qty=%.1fg | meal=%r",
                food_name_raw, best_match.name, best_match.id, quantity_g, meal_name,
            )
            return FoodParseResult(
                food_name_raw=food_name_raw,
                quantity_g=quantity_g,
                meal_name=meal_name,
                confidence=confidence,
                source="taco",
                catalog_item=best_match,
            )

        # Etapa 3: TACO não encontrou — tentar fallback web/LLM
        if not user_id:
            raise FoodNotFoundError(
                f"'{food_name_raw}' não foi encontrado no catálogo nutricional. "
                "Tente digitar o nome do alimento manualmente pelo app."
            )

        # 3a: Busca web via Tavily
        custom_food: CustomFood | None = None
        source = "web"

        if settings.FOOD_WEB_SEARCH_ENABLED:
            custom_food = await self._search_web_nutrition(
                food_name_raw, session, user_id
            )

        # 3b: Estimativa LLM como último recurso
        if custom_food is None:
            source = "estimativa"
            custom_food = await self._estimate_nutrition_llm(
                food_name_raw, session, user_id
            )

        if custom_food is None:
            raise FoodNotFoundError(
                f"'{food_name_raw}' não foi encontrado no catálogo e não foi "
                "possível obter dados nutricionais. Tente um nome mais específico."
            )

        logger.info(
            "Parser %s | raw=%r → CustomFood id=%s | qty=%.1fg | meal=%r",
            source, food_name_raw, custom_food.id, quantity_g, meal_name,
        )

        return FoodParseResult(
            food_name_raw=food_name_raw,
            quantity_g=quantity_g,
            meal_name=meal_name,
            confidence=confidence,
            source=source,
            custom_food=custom_food,
        )


# Singleton reutilizável
food_parser = FoodParser()
