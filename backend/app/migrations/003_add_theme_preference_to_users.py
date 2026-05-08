"""
Migration: Adicionar coluna theme_preference à tabela users

Adiciona suporte a preferência de tema (light, dark, system) por usuário.
Padrão: NULL (usuário não definiu, usar padrão do sistema)
"""

from alembic import op
import sqlalchemy as sa


def upgrade():
    """Adiciona coluna theme_preference aos usuários."""
    op.add_column(
        'users',
        sa.Column(
            'theme_preference',
            sa.String(20),
            nullable=True,
            default=None,
            comment='Preferência de tema: light, dark, system, ou NULL (padrão do dispositivo)'
        )
    )


def downgrade():
    """Remove coluna theme_preference."""
    op.drop_column('users', 'theme_preference')
