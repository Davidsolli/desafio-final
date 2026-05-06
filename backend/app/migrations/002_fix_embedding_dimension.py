"""
Migration: Atualizar dimensão de embeddings (768 → 384)

Quando: Após trocar de Google Embeddings (768 dims) para HuggingFace (384 dims)
Ação: Regenerar embeddings com nova dimensão

Nota: Se nenhum documento existe ainda, essa migration é segura (passa sem erro).
"""

from alembic import op
import sqlalchemy as sa


def upgrade():
    """Drop docs com embeddings antigos, deixa tabela limpa para novos docs."""
    # Se a tabela knowledge_base existe, deleta registros (embeddings inválidos)
    try:
        op.execute(sa.text(
            """
            DELETE FROM knowledge_base WHERE embedding IS NOT NULL
            AND json_array_length(embedding::json) != 384
            """
        ))
    except Exception:
        # Tabela pode não existir ainda (migrate em DB vazio)
        pass


def downgrade():
    """Não fazer downgrade (dados foram deletados)."""
    pass
