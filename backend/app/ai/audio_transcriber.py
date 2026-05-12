"""
Transcrição de áudio via Groq Whisper.

Converte arquivos de áudio (m4a, mp3, wav, webm, ogg) em texto usando
o modelo whisper-large-v3-turbo da Groq, otimizado para português brasileiro.

Limites da API Groq Whisper:
  - Tamanho máximo: 25 MB por arquivo
  - Formatos: mp3, mp4, m4a, mpeg, mpga, wav, webm, ogg
  - Linguagem: fixada em "pt" para melhorar acurácia em pt-BR
"""

from __future__ import annotations

import logging
from typing import Final

from groq import AsyncGroq

from app.config.settings import settings

logger = logging.getLogger(__name__)

MAX_FILE_SIZE: Final[int] = 25 * 1024 * 1024  # 25 MB

ALLOWED_CONTENT_TYPES: Final[frozenset[str]] = frozenset(
    [
        "audio/mp3",
        "audio/mpeg",
        "audio/mp4",
        "audio/x-m4a",
        "audio/m4a",
        "audio/wav",
        "audio/x-wav",
        "audio/webm",
        "audio/ogg",
        "video/mp4",      # alguns clientes enviam m4a como video/mp4
        "video/webm",
        "application/octet-stream",  # fallback genérico — validar por extensão
    ]
)

ALLOWED_EXTENSIONS: Final[frozenset[str]] = frozenset(
    [".mp3", ".mp4", ".m4a", ".mpeg", ".mpga", ".wav", ".webm", ".ogg"]
)

WHISPER_MODEL: Final[str] = "whisper-large-v3-turbo"


class AudioTranscriptionError(Exception):
    """Erro durante transcrição de áudio."""


class AudioTooLargeError(AudioTranscriptionError):
    """Arquivo de áudio excede o limite de 25 MB."""


class AudioFormatError(AudioTranscriptionError):
    """Formato de áudio não suportado."""


class AudioTranscriber:
    """
    Serviço de transcrição de áudio usando Groq Whisper.

    Uso:
        transcriber = AudioTranscriber()
        texto = await transcriber.transcribe(audio_bytes, "audio.m4a", "audio/m4a")
    """

    def _get_client(self) -> AsyncGroq:
        return AsyncGroq(api_key=settings.GROQ_API_KEY)

    def _validate(self, audio_bytes: bytes, filename: str, content_type: str) -> None:
        """Valida tamanho e formato antes de chamar a API."""
        if len(audio_bytes) > MAX_FILE_SIZE:
            raise AudioTooLargeError(
                f"Áudio muito grande ({len(audio_bytes) // (1024*1024)} MB). "
                f"Máximo: 25 MB."
            )

        ext = "." + filename.rsplit(".", 1)[-1].lower() if "." in filename else ""
        ct_ok = content_type.lower() in ALLOWED_CONTENT_TYPES
        ext_ok = ext in ALLOWED_EXTENSIONS

        if not ct_ok and not ext_ok:
            raise AudioFormatError(
                f"Formato de áudio não suportado: {content_type!r} / {ext!r}. "
                f"Formatos aceitos: mp3, m4a, wav, webm, ogg."
            )

    async def transcribe(
        self,
        audio_bytes: bytes,
        filename: str,
        content_type: str = "audio/m4a",
        language: str = "pt",
    ) -> str:
        """
        Transcreve o áudio em texto usando Groq Whisper.

        Args:
            audio_bytes: Conteúdo do arquivo de áudio.
            filename: Nome original do arquivo (usado para detectar extensão).
            content_type: MIME type do arquivo.
            language: Código do idioma ISO-639-1 (default: "pt" para português).

        Returns:
            Texto transcrito.

        Raises:
            AudioTooLargeError: Arquivo > 25 MB.
            AudioFormatError: Formato não suportado.
            AudioTranscriptionError: Falha na API do Groq.
        """
        self._validate(audio_bytes, filename, content_type)

        client = self._get_client()

        logger.info(
            "Iniciando transcrição | file=%r | size=%d KB | lang=%s",
            filename,
            len(audio_bytes) // 1024,
            language,
        )

        try:
            result = await client.audio.transcriptions.create(
                file=(filename, audio_bytes),
                model=WHISPER_MODEL,
                language=language,
                response_format="text",
            )

            # O SDK Groq retorna str quando response_format="text"
            transcript: str = result if isinstance(result, str) else str(result)
            transcript = transcript.strip()

            logger.info(
                "Transcrição concluída | chars=%d | preview=%r",
                len(transcript),
                transcript[:80],
            )
            return transcript

        except (AudioTooLargeError, AudioFormatError):
            raise
        except Exception as exc:
            logger.error("Falha na transcrição Groq Whisper: %s", exc)
            raise AudioTranscriptionError(
                f"Não foi possível transcrever o áudio: {exc}"
            ) from exc


# Singleton reutilizável
audio_transcriber = AudioTranscriber()
