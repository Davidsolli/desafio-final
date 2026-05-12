"""
Migration: Adicionar coluna token_version à tabela users

Usada para invalidar JWTs emitidos antes de um reset de senha.
Cada redefinição incrementa token_version; o JWT inclui o valor
no claim 'tv' e é rejeitado quando 'tv' não bate com o banco.
"""

from alembic import op
import sqlalchemy as sa


def upgrade():
    """Adiciona coluna token_version com default 0 aos usuários."""
    op.add_column(
        'users',
        sa.Column(
            'token_version',
            sa.Integer,
            nullable=False,
            server_default='0',
            comment='Incrementado a cada reset de senha; invalida JWTs anteriores',
        ),
    )


def downgrade():
    """Remove coluna token_version."""
    op.drop_column('users', 'token_version')
