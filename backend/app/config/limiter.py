"""Instância compartilhada do rate limiter (slowapi).

Exportar esta instância única garante que os contadores de rate limit
sejam compartilhados entre todos os routers que usam @limiter.limit.
"""

from slowapi import Limiter
from slowapi.util import get_remote_address

limiter = Limiter(key_func=get_remote_address, storage_uri="memory://")


def reset_limits() -> None:
    """Zera todos os contadores de rate limit. Uso exclusivo em testes."""
    limiter._limiter.storage.reset()
