#!/bin/bash
# ============================================
# Proj-Chat - Backup Automático
# ============================================
# Adicione ao crontab: 0 3 * * * /opt/proj-chat/scripts/backup.sh
# Faz backup dos 3 databases + volumes críticos

set -e

BACKUP_DIR="/opt/proj-chat/backups"
DATE=$(date +%Y%m%d_%H%M%S)
RETENTION_DAYS=7

mkdir -p "${BACKUP_DIR}"

echo "[$(date)] Iniciando backup..."

# Backup PostgreSQL - todos os databases
echo "Backup PostgreSQL..."
docker exec proj-chat-postgres pg_dumpall -U proj_chat > "${BACKUP_DIR}/pg_all_${DATE}.sql"

# Backup individual por database (mais fácil restaurar)
for DB in chatwoot_production typebot evolution_v2; do
  docker exec proj-chat-postgres pg_dump -U proj_chat "${DB}" > "${BACKUP_DIR}/pg_${DB}_${DATE}.sql"
done

# Backup Evolution instances (sessões WhatsApp)
echo "Backup Evolution instances..."
docker cp proj-chat-evolution:/evolution/instances "${BACKUP_DIR}/evolution_instances_${DATE}"

# Compactar
echo "Compactando..."
tar -czf "${BACKUP_DIR}/proj-chat_backup_${DATE}.tar.gz" \
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
find "${BACKUP_DIR}" -name "proj-chat_backup_*.tar.gz" -mtime +${RETENTION_DAYS} -delete

echo "[$(date)] Backup concluído: proj-chat_backup_${DATE}.tar.gz"
echo "Tamanho: $(du -h ${BACKUP_DIR}/proj-chat_backup_${DATE}.tar.gz | cut -f1)"
