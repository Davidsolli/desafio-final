-- Migração 006: Adicionar coluna replacement_policy em subscriptions
-- Data: 2026-05-15
--
-- Contexto: O commit cd0ba82 adicionou o campo `replacement_policy` no model
-- `Subscription` para suportar troca de assinatura (immediate | on_expiry),
-- mas não criou a migração correspondente. O INSERT em /subscriptions/checkout
-- falha com UndefinedColumnError porque a coluna não existe na tabela.

ALTER TABLE subscriptions
    ADD COLUMN IF NOT EXISTS replacement_policy VARCHAR(20);

-- Validação dos valores aceitos (mesma regra do Pydantic DTO)
ALTER TABLE subscriptions
    DROP CONSTRAINT IF EXISTS replacement_policy_valid;

ALTER TABLE subscriptions
    ADD CONSTRAINT replacement_policy_valid
    CHECK (replacement_policy IS NULL OR replacement_policy IN ('immediate', 'on_expiry'));

COMMENT ON COLUMN subscriptions.replacement_policy IS 'Política de troca de assinatura: immediate (substitui na hora) | on_expiry (substitui ao expirar a atual)';
