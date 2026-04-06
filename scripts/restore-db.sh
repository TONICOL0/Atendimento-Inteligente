#!/bin/bash
# ============================================
# Konecta - Restauração de Databases
# ============================================
# Este script restaura todas as databases de configuração
# na VPS após um deploy limpo.
#
# Uso:
#   1. Suba os containers: docker compose up -d
#   2. Aguarde o PostgreSQL ficar healthy: docker compose ps
#   3. Execute: bash scripts/restore-db.sh
# ============================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DUMP_DIR="$SCRIPT_DIR/db-dumps"
CONTAINER="konecta-postgres"
DB_USER="${POSTGRES_USER:-konecta}"

echo "============================================"
echo "  Konecta - Restauração de Databases"
echo "============================================"
echo ""

# Verificar se o container está rodando
if ! docker ps --format '{{.Names}}' | grep -q "^${CONTAINER}$"; then
    echo "ERRO: Container $CONTAINER não está rodando!"
    echo "Execute 'docker compose up -d' primeiro."
    exit 1
fi

# Verificar se o PostgreSQL está pronto
echo "[1/6] Verificando se PostgreSQL está pronto..."
for i in $(seq 1 30); do
    if docker exec $CONTAINER pg_isready -U $DB_USER > /dev/null 2>&1; then
        echo "  PostgreSQL está pronto!"
        break
    fi
    if [ $i -eq 30 ]; then
        echo "ERRO: PostgreSQL não ficou pronto em 30 segundos."
        exit 1
    fi
    sleep 1
done

# Criar databases se não existirem
echo "[2/6] Criando databases se necessário..."
for DB in typebot chatwoot_production evolution_v2; do
    EXISTS=$(docker exec $CONTAINER psql -U $DB_USER -tAc "SELECT 1 FROM pg_database WHERE datname='$DB'" 2>/dev/null)
    if [ "$EXISTS" != "1" ]; then
        echo "  Criando database: $DB"
        docker exec $CONTAINER psql -U $DB_USER -c "CREATE DATABASE $DB;" 2>/dev/null || true
    else
        echo "  Database $DB já existe"
    fi
done

# Restaurar TypeBot
echo "[3/6] Restaurando TypeBot..."
if [ -f "$DUMP_DIR/typebot.sql" ]; then
    cat "$DUMP_DIR/typebot.sql" | docker exec -i $CONTAINER psql -U $DB_USER -d typebot --quiet 2>/dev/null
    TYPEBOT_COUNT=$(docker exec $CONTAINER psql -U $DB_USER -d typebot -tAc "SELECT count(*) FROM \"Typebot\"" 2>/dev/null)
    echo "  TypeBot restaurado! ($TYPEBOT_COUNT bots encontrados)"
else
    echo "  AVISO: Arquivo typebot.sql não encontrado, pulando..."
fi

# Restaurar Chatwoot
echo "[4/6] Restaurando Chatwoot..."
if [ -f "$DUMP_DIR/chatwoot.sql" ]; then
    cat "$DUMP_DIR/chatwoot.sql" | docker exec -i $CONTAINER psql -U $DB_USER -d chatwoot_production --quiet 2>/dev/null
    echo "  Chatwoot restaurado!"
else
    echo "  AVISO: Arquivo chatwoot.sql não encontrado, pulando..."
fi

# Restaurar Evolution API
echo "[5/6] Restaurando Evolution API..."
if [ -f "$DUMP_DIR/evolution.sql" ]; then
    cat "$DUMP_DIR/evolution.sql" | docker exec -i $CONTAINER psql -U $DB_USER -d evolution_v2 --quiet 2>/dev/null
    echo "  Evolution API restaurado!"
else
    echo "  AVISO: Arquivo evolution.sql não encontrado, pulando..."
fi

# Verificação final
echo "[6/6] Verificação final..."
echo ""
echo "  Databases:"
docker exec $CONTAINER psql -U $DB_USER -l 2>/dev/null | grep -E "typebot|chatwoot|evolution" | while read line; do
    echo "    $line"
done

echo ""
echo "============================================"
echo "  Restauração concluída!"
echo "============================================"
echo ""
echo "IMPORTANTE - Próximos passos:"
echo "  1. Reinicie os containers: docker compose restart"
echo "  2. O WhatsApp precisará ser reconectado (novo QR code)"
echo "     - Acesse http://SEU_IP:8081/manager"
echo "     - Conecte as instâncias via QR code"
echo "  3. Atualize os URLs nos .env se o domínio mudou"
echo "  4. Verifique se o Chatwoot está acessível: http://SEU_IP:3000"
echo "  5. Verifique se o TypeBot está acessível: http://SEU_IP:3001"
echo ""
echo "  Login Chatwoot: use as credenciais configuradas no setup"
echo "  Login TypeBot: via GitHub OAuth"
echo ""
