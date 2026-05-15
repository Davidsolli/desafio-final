"""
Utilitários para verificação de roles compostas.

O campo `role` do User pode conter uma única role ou múltiplas separadas por vírgula.
Exemplos válidos:
    "client"
    "admin"
    "personal_trainer"
    "nutritionist"
    "nutritionist,personal_trainer"
"""

PROFESSIONAL_ROLES = {"personal_trainer", "nutritionist"}
ALL_ATOMIC_ROLES = {"admin", "personal_trainer", "nutritionist", "client"}


def has_role(role_str: str, role: str) -> bool:
    """Verifica se role_str contém a role (suporta roles compostas separadas por vírgula)."""
    return role in {r.strip() for r in role_str.split(",")}


def is_professional(role_str: str) -> bool:
    """Verifica se o usuário tem ao menos uma especialidade profissional."""
    return any(has_role(role_str, r) for r in PROFESSIONAL_ROLES)


def normalize_roles(roles: list[str]) -> str:
    """Converte lista de roles para string canônica (ordenada, sem duplicatas)."""
    valid = {r.strip() for r in roles if r.strip() in ALL_ATOMIC_ROLES}
    return ",".join(sorted(valid))
