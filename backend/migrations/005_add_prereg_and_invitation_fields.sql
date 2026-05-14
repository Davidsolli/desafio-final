-- Migração 005: Campos de expiração de convite e fluxo de pagamento no pré-cadastro WhatsApp
-- Data: 2026-05-14

-- 1. TTL do código de convite (72h por padrão)
ALTER TABLE invitations
    ADD COLUMN IF NOT EXISTS expires_at TIMESTAMP;

-- Preencher convites existentes com 72h a partir da criação (retrocompatibilidade)
UPDATE invitations
SET expires_at = created_at + INTERVAL '72 hours'
WHERE expires_at IS NULL;

CREATE INDEX IF NOT EXISTS idx_invitations_expires_at ON invitations(expires_at)
    WHERE used = false;

-- 2. Campos de seleção de plano e pagamento no pré-cadastro WhatsApp
ALTER TABLE whatsapp_pre_registrations
    ADD COLUMN IF NOT EXISTS selected_plan_id UUID REFERENCES plans(id),
    ADD COLUMN IF NOT EXISTS payment_status   VARCHAR(30) NOT NULL DEFAULT 'not_required',
    ADD COLUMN IF NOT EXISTS pre_reg_payment_id VARCHAR(100),
    ADD COLUMN IF NOT EXISTS checkout_url     TEXT;

CREATE UNIQUE INDEX IF NOT EXISTS idx_whatsapp_prereg_payment_id
    ON whatsapp_pre_registrations(pre_reg_payment_id)
    WHERE pre_reg_payment_id IS NOT NULL;

COMMENT ON COLUMN invitations.expires_at IS 'Expiração do código de convite (72h após geração)';
COMMENT ON COLUMN whatsapp_pre_registrations.selected_plan_id IS 'Plano escolhido pelo usuário durante o pré-cadastro';
COMMENT ON COLUMN whatsapp_pre_registrations.payment_status IS 'Status do pagamento: not_required | pending | confirmed | expired';
COMMENT ON COLUMN whatsapp_pre_registrations.pre_reg_payment_id IS 'ID do pagamento na InfinitePay (prereg_{uuid})';
COMMENT ON COLUMN whatsapp_pre_registrations.checkout_url IS 'URL de checkout gerada pela InfinitePay';
