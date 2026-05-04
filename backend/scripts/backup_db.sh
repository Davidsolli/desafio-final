#!/usr/bin/env bash
# ============================================================
# backup_db.sh — Backup automático do PostgreSQL (RNF-09)
#
# Funcionalidades:
#   - Dump diário comprimido (pg_dump + gzip)
#   - Retenção de 30 dias (remove backups mais antigos)
#   - Logging de sucesso/falha
#   - Exit code != 0 em caso de erro (para integração com cron/alertas)
#
# Uso:
#   ./backup_db.sh                  # usa variáveis de ambiente
#   BACKUP_DIR=/backups ./backup_db.sh
#
# Instalação via cron (todo dia às 2h):
#   0 2 * * * /app/scripts/backup_db.sh >> /var/log/backup_db.log 2>&1
# ============================================================

set -euo pipefail

# ── Configuração (sobrescreva via env se necessário) ──────────────────────────
BACKUP_DIR="${BACKUP_DIR:-/var/backups/omniconnect}"
RETENTION_DAYS="${RETENTION_DAYS:-30}"

DB_HOST="${PGHOST:-db}"
DB_PORT="${PGPORT:-5432}"
DB_NAME="${PGDATABASE:-omniconnect_db}"
DB_USER="${PGUSER:-omni_user}"
export PGPASSWORD="${PGPASSWORD:-omni_pass}"

TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
BACKUP_FILE="${BACKUP_DIR}/omniconnect_${DB_NAME}_${TIMESTAMP}.sql.gz"
LOG_PREFIX="[$(date '+%Y-%m-%d %H:%M:%S')] [backup_db]"

# ── Garante que o diretório de backup existe ──────────────────────────────────
mkdir -p "${BACKUP_DIR}"

echo "${LOG_PREFIX} Iniciando backup do banco '${DB_NAME}'..."

# ── Dump + compressão ─────────────────────────────────────────────────────────
if pg_dump \
    --host="${DB_HOST}" \
    --port="${DB_PORT}" \
    --username="${DB_USER}" \
    --dbname="${DB_NAME}" \
    --format=plain \
    --no-password \
    | gzip > "${BACKUP_FILE}"; then

    SIZE=$(du -sh "${BACKUP_FILE}" | cut -f1)
    echo "${LOG_PREFIX} Backup criado com sucesso: ${BACKUP_FILE} (${SIZE})"
else
    echo "${LOG_PREFIX} ERRO: falha ao criar backup de '${DB_NAME}'" >&2
    exit 1
fi

# ── Remove backups antigos (retenção de 30 dias) ──────────────────────────────
REMOVED=$(find "${BACKUP_DIR}" -name "omniconnect_${DB_NAME}_*.sql.gz" \
    -mtime "+${RETENTION_DAYS}" -print -delete | wc -l)

if [[ "${REMOVED}" -gt 0 ]]; then
    echo "${LOG_PREFIX} ${REMOVED} backup(s) antigo(s) removido(s) (retenção ${RETENTION_DAYS} dias)"
fi

echo "${LOG_PREFIX} Backup concluído."
