#!/bin/bash
# ============================================
# Konecta - Backup Automático
# ============================================
# Adicione ao crontab: 0 3 * * * /opt/konecta/scripts/backup.sh
# Faz backup dos 3 databases + volumes críticos

set -e

BACKUP_DIR="/opt/konecta/backups"
DATE=$(date +%Y%m%d_%H%M%S)
RETENTION_DAYS=7

mkdir -p "${BACKUP_DIR}"

echo "[$(date)] Iniciando backup..."

# Backup PostgreSQL - todos os databases
echo "Backup PostgreSQL..."
docker exec konecta-postgres pg_dumpall -U konecta > "${BACKUP_DIR}/pg_all_${DATE}.sql"

# Backup individual por database (mais fácil restaurar)
for DB in chatwoot_production typebot evolution_v2; do
  docker exec konecta-postgres pg_dump -U konecta "${DB}" > "${BACKUP_DIR}/pg_${DB}_${DATE}.sql"
done

# Backup Evolution instances (sessões WhatsApp)
echo "Backup Evolution instances..."
docker cp konecta-evolution:/evolution/instances "${BACKUP_DIR}/evolution_instances_${DATE}"

# Compactar
echo "Compactando..."
tar -czf "${BACKUP_DIR}/konecta_backup_${DATE}.tar.gz" \
  -C "${BACKUP_DIR}" \
  "pg_all_${DATE}.sql" \
  "pg_chatwoot_production_${DATE}.sql" \
  "pg_typebot_${DATE}.sql" \
  "pg_evolution_v2_${DATE}.sql" \
  "evolution_instances_${DATE}"

# Limpar arquivos temporários
rm -f "${BACKUP_DIR}/pg_"*"_${DATE}.sql"
rm -rf "${BACKUP_DIR}/evolution_instances_${DATE}"

# Remover backups antigos
echo "Removendo backups com mais de ${RETENTION_DAYS} dias..."
find "${BACKUP_DIR}" -name "konecta_backup_*.tar.gz" -mtime +${RETENTION_DAYS} -delete

echo "[$(date)] Backup concluído: konecta_backup_${DATE}.tar.gz"
echo "Tamanho: $(du -h ${BACKUP_DIR}/konecta_backup_${DATE}.tar.gz | cut -f1)"
