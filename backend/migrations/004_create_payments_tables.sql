-- Migração: Criar tabelas de Pagamentos e Assinaturas (MVP V1)
-- Data: 2026-05-08

-- Tabela: plans
CREATE TABLE IF NOT EXISTS plans (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    admin_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,

    name VARCHAR(100) NOT NULL,
    description VARCHAR(500),

    price NUMERIC(10, 2) NOT NULL,
    currency VARCHAR(3) DEFAULT 'BRL',

    duration_months INTEGER NOT NULL,

    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    deleted_at TIMESTAMP,

    CONSTRAINT price_positive CHECK (price > 0),
    CONSTRAINT duration_valid CHECK (duration_months IN (1, 3, 6, 12))
);

CREATE INDEX idx_plans_admin_id ON plans(admin_id);
CREATE INDEX idx_plans_is_active ON plans(is_active) WHERE deleted_at IS NULL;
CREATE INDEX idx_plans_created_at ON plans(created_at DESC);

-- Tabela: subscriptions
CREATE TABLE IF NOT EXISTS subscriptions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    student_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    plan_id UUID NOT NULL REFERENCES plans(id),
    admin_id UUID NOT NULL REFERENCES users(id),

    status VARCHAR(20) DEFAULT 'pending',
    payment_method VARCHAR(20),
    external_payment_id VARCHAR(100) UNIQUE,

    started_at TIMESTAMP,
    expires_at TIMESTAMP,
    canceled_at TIMESTAMP,

    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT status_valid CHECK (status IN ('pending', 'active', 'expired', 'canceled_pending', 'canceled'))
);

CREATE INDEX idx_subscriptions_student_id ON subscriptions(student_id);
CREATE INDEX idx_subscriptions_admin_id ON subscriptions(admin_id);
CREATE INDEX idx_subscriptions_status ON subscriptions(status);
CREATE INDEX idx_subscriptions_expires_at ON subscriptions(expires_at) WHERE status = 'active';
CREATE INDEX idx_subscriptions_external_payment_id ON subscriptions(external_payment_id);
CREATE INDEX idx_subscriptions_created_at ON subscriptions(created_at DESC);

-- Comentários
COMMENT ON TABLE plans IS 'Planos de assinatura criados pelos admins';
COMMENT ON TABLE subscriptions IS 'Assinaturas dos alunos em planos';

COMMENT ON COLUMN plans.price IS 'Preço em BRL';
COMMENT ON COLUMN plans.duration_months IS 'Duração em meses (1, 3, 6 ou 12)';
COMMENT ON COLUMN subscriptions.status IS 'Status: pending, active, expired, canceled_pending, canceled';
COMMENT ON COLUMN subscriptions.external_payment_id IS 'ID do pagamento no Asaas/MercadoPago';
