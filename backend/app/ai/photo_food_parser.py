"""
Parser de refeição a partir de foto usando Groq Vision (Llama 4 Scout).

Fluxo:
  1. Recebe bytes da imagem (jpg/png/webp)
  2. Envia para o modelo de visão via Groq API
  3. Modelo retorna JSON com lista de alimentos e quantidades estimadas
  4. Cada alimento é retornado como texto descritivo para o FoodParser processar
"""

from __future__ import annotations

import base64
import json
import logging
import re
from dataclasses import dataclass, field

from groq import AsyncGroq

from app.config.settings import settings

logger = logging.getLogger(__name__)

ALLOWED_MIME_TYPES = {"image/jpeg", "image/jpg", "image/png", "image/webp"}
MAX_SIZE_BYTES = 20 * 1024 * 1024  # 20 MB

_VISION_PROMPT = """\
Analise esta foto de refeição e identifique todos os alimentos visíveis.

Retorne SOMENTE um JSON válido, sem textos extras:
{
  "foods": [
    {"name": "<nome do alimento em português>", "quantity_g": <estimativa em gramas, float>},
    {"name": "<nome do alimento em português>", "quantity_g": <estimativa em gramas, float>}
  ],
  "confidence": "<high|medium|low>",
  "description": "<descrição curta do prato>"
}

Regras:
- Liste cada alimento separadamente (porções individuais)
- Para quantity_g: estime baseado no tamanho visual típico de uma porção adulta
- Nomes simples em português, sem modo de preparo (ex: "arroz" não "arroz cozido")
- Se não conseguir identificar com certeza, não inclua o alimento
- Se a imagem não contiver comida: {"foods": [], "confidence": "low", "description": "Sem alimentos identificados"}

JSON:"""

_JSON_RE = re.compile(r"\{.*\}", re.DOTALL)


# ── Exceções ───────────────────────────────────────────────────────────────────

class PhotoFormatError(Exception):
    """Formato de imagem não suportado."""


class PhotoTooLargeError(Exception):
    """Imagem excede o tamanho máximo."""


class PhotoParseError(Exception):
    """Erro ao analisar a imagem."""


# ── Resultado ──────────────────────────────────────────────────────────────────

@dataclass
class PhotoFood:
    """Alimento identificado na foto."""
    name: str
    quantity_g: float

    @property
    def description_text(self) -> str:
        return f"comi {self.quantity_g:.0f} gramas de {self.name}"


@dataclass
class PhotoParseResult:
    """Resultado da análise da foto."""
    foods: list[PhotoFood]
    confidence: str   # "high" | "medium" | "low"
    description: str  # descrição do prato


# ── Parser ─────────────────────────────────────────────────────────────────────

class PhotoFoodParser:
    """
    Identifica alimentos em fotos usando Groq Vision.

    Uso:
        result = await photo_food_parser.analyze(image_bytes, "foto.jpg", "image/jpeg")
        for food in result.foods:
            parse_result = await food_parser.parse(food.description_text, session, ...)
    """

    def _resolve_mime_type(self, filename: str, content_type: str | None) -> str:
        ext_map = {
            "jpg": "image/jpeg",
            "jpeg": "image/jpeg",
            "png": "image/png",
            "webp": "image/webp",
        }
        ct = (content_type or "").split(";")[0].strip().lower()
        if ct in ALLOWED_MIME_TYPES:
            return ct
        ext = filename.rsplit(".", 1)[-1].lower() if "." in filename else ""
        if ext in ext_map:
            return ext_map[ext]
        raise PhotoFormatError(
            "Formato não suportado. Envie uma imagem JPG, PNG ou WebP."
        )

    async def analyze(
        self,
        image_bytes: bytes,
        filename: str,
        content_type: str | None = None,
    ) -> PhotoParseResult:
        """
        Analisa a imagem e retorna os alimentos identificados.

        Args:
            image_bytes: Conteúdo binário da imagem.
            filename: Nome do arquivo (usado para inferir o tipo).
            content_type: MIME type enviado pelo cliente.

        Returns:
            PhotoParseResult com lista de alimentos e metadados.

        Raises:
            PhotoTooLargeError: Arquivo > 20 MB.
            PhotoFormatError: Formato não suportado.
            PhotoParseError: Erro na análise ou nenhum alimento identificado.
        """
        if len(image_bytes) > MAX_SIZE_BYTES:
            raise PhotoTooLargeError(
                f"Imagem muito grande ({len(image_bytes) // 1024 // 1024:.1f} MB). "
                "Máximo permitido: 20 MB."
            )

        mime_type = self._resolve_mime_type(filename, content_type)
        image_b64 = base64.b64encode(image_bytes).decode()

        client = AsyncGroq(api_key=settings.GROQ_API_KEY)
        try:
            response = await client.chat.completions.create(
                model=settings.GROQ_VISION_MODEL,
                messages=[
                    {
                        "role": "user",
                        "content": [
                            {
                                "type": "image_url",
                                "image_url": {
                                    "url": f"data:{mime_type};base64,{image_b64}"
                                },
                            },
                            {"type": "text", "text": _VISION_PROMPT},
                        ],
                    }
                ],
                max_tokens=512,
                temperature=0.0,
            )
        except Exception as exc:
            logger.error("Groq Vision falhou: %s", exc)
            raise PhotoParseError(
                "Não foi possível analisar a imagem. Tente novamente."
            ) from exc

        raw = (response.choices[0].message.content or "").strip()
        logger.debug("Vision raw: %r", raw[:300])

        match = _JSON_RE.search(raw)
        json_str = match.group(0) if match else raw
        try:
            data = json.loads(json_str)
        except json.JSONDecodeError as exc:
            logger.warning("Vision JSON inválido: %r", raw[:200])
            raise PhotoParseError(
                "Não consegui identificar os alimentos na foto. "
                "Tente uma foto mais clara e bem iluminada."
            ) from exc

        foods_raw: list[dict] = data.get("foods", [])
        confidence: str = data.get("confidence", "low")
        description: str = data.get("description", "")

        if not foods_raw:
            raise PhotoParseError(
                "Não encontrei alimentos reconhecíveis na foto. "
                "Tente uma foto mais próxima do prato."
            )

        foods: list[PhotoFood] = []
        for item in foods_raw:
            name = (item.get("name") or "").strip()
            qty_raw = item.get("quantity_g")
            if not name or qty_raw is None:
                continue
            try:
                qty = float(qty_raw)
                if qty <= 0:
                    continue
            except (TypeError, ValueError):
                continue
            foods.append(PhotoFood(name=name, quantity_g=qty))

        if not foods:
            raise PhotoParseError(
                "Não consegui estimar as quantidades dos alimentos na foto. "
                "Tente descrever o alimento por áudio ou texto."
            )

        logger.info(
            "Vision OK | %d alimentos | confidence=%s | %s",
            len(foods),
            confidence,
            [f.name for f in foods],
        )
        return PhotoParseResult(foods=foods, confidence=confidence, description=description)


photo_food_parser = PhotoFoodParser()
