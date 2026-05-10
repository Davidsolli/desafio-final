"""Instância compartilhada do rate limiter (slowapi).

Exportar esta instância única garante que os contadores de rate limit
sejam compartilhados entre todos os routers que usam @limiter.limit.
"""

from slowapi import Limiter
from slowapi.util import get_remote_address

limiter = Limiter(key_func=get_remote_address)
