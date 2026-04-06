#!/bin/bash
# ============================================
# Proj-Chat - Linkar Instância do WhatsApp
# ============================================
# Após conectar o WhatsApp via QR code no Evolution API,
# execute este script para configurar TypeBot + Chatwoot.
#
# Uso:
#   bash scripts/link-instance.sh <nome-da-instancia>
#
# Exemplo:
#   bash scripts/link-instance.sh proj-chat-principal
# ============================================

set -e

# Configurações - ajuste conforme seu ambiente
EVOLUTION_URL="${EVOLUTION_URL:-http://localhost:8081}"
EVOLUTION_API_KEY="${EVOLUTION_API_KEY:?Defina EVOLUTION_API_KEY}"
CHATWOOT_URL_INTERNAL="${CHATWOOT_URL_INTERNAL:-http://chatwoot-rails:3000}"
CHATWOOT_API_TOKEN="${CHATWOOT_API_TOKEN:?Defina CHATWOOT_API_TOKEN}"
CHATWOOT_ACCOUNT_ID="${CHATWOOT_ACCOUNT_ID:-1}"
TYPEBOT_URL_INTERNAL="${TYPEBOT_URL_INTERNAL:-http://typebot-viewer:3000}"
TYPEBOT_BOT_ID="${TYPEBOT_BOT_ID:-proj-chat-juridico}"
TYPEBOT_TRIGGER="${TYPEBOT_TRIGGER:-planejamento previdenci}"

# Validar argumento
INSTANCE_NAME="$1"
if [ -z "$INSTANCE_NAME" ]; then
    echo "Uso: bash scripts/link-instance.sh <nome-da-instancia>"
    echo ""
    echo "Instâncias disponíveis:"
    curl -s "${EVOLUTION_URL}/instance/fetchInstances" \
        -H "apikey: ${EVOLUTION_API_KEY}" 2>/dev/null | \
        grep -o '"instanceName":"[^"]*"' | sed 's/"instanceName":"//;s/"/  /' | while read name; do
        echo "  - $name"
    done
    exit 1
fi

echo "============================================"
echo "  Proj-Chat - Linkar Instância: $INSTANCE_NAME"
echo "============================================"
echo ""

# 1. Verificar se a instância está conectada
echo "[1/4] Verificando conexão do WhatsApp..."
STATE=$(curl -s "${EVOLUTION_URL}/instance/connectionState/${INSTANCE_NAME}" \
    -H "apikey: ${EVOLUTION_API_KEY}" 2>/dev/null | grep -o '"state":"[^"]*"' | head -1 | sed 's/"state":"//;s/"//')

if [ "$STATE" != "open" ]; then
    echo "  ERRO: WhatsApp não está conectado! (estado: $STATE)"
    echo "  Conecte primeiro via QR code em ${EVOLUTION_URL}/manager"
    exit 1
fi
echo "  WhatsApp conectado!"

# 2. Configurar TypeBot
echo "[2/4] Configurando TypeBot..."
TYPEBOT_RESULT=$(curl -s -X POST "${EVOLUTION_URL}/typebot/create/${INSTANCE_NAME}" \
    -H "apikey: ${EVOLUTION_API_KEY}" \
    -H "Content-Type: application/json; charset=utf-8" \
    -d "{
        \"enabled\": true,
        \"url\": \"${TYPEBOT_URL_INTERNAL}\",
        \"typebot\": \"${TYPEBOT_BOT_ID}\",
        \"triggerType\": \"keyword\",
        \"triggerOperator\": \"regex\",
        \"triggerValue\": \"${TYPEBOT_TRIGGER}\",
        \"expire\": 20,
        \"keywordFinish\": \"#sair\",
        \"delayMessage\": 1000,
        \"unknownMessage\": \"\",
        \"listeningFromMe\": false,
        \"stopBotFromMe\": false,
        \"keepOpen\": false,
        \"debounceTime\": 10
    }" 2>/dev/null)

if echo "$TYPEBOT_RESULT" | grep -q '"enabled":true'; then
    echo "  TypeBot configurado!"
    echo "    Bot: $TYPEBOT_BOT_ID"
    echo "    Gatilho: regex '$TYPEBOT_TRIGGER'"
else
    echo "  AVISO: Possível erro ao configurar TypeBot:"
    echo "  $TYPEBOT_RESULT"
fi

# 3. Configurar Chatwoot
echo "[3/4] Configurando Chatwoot..."
INBOX_NAME="WhatsApp - $(echo $INSTANCE_NAME | sed 's/-/ /g' | sed 's/\b\(.\)/\u\1/g')"

CHATWOOT_RESULT=$(curl -s -X POST "${EVOLUTION_URL}/chatwoot/set/${INSTANCE_NAME}" \
    -H "apikey: ${EVOLUTION_API_KEY}" \
    -H "Content-Type: application/json" \
    -d "{
        \"enabled\": true,
        \"accountId\": \"${CHATWOOT_ACCOUNT_ID}\",
        \"token\": \"${CHATWOOT_API_TOKEN}\",
        \"url\": \"${CHATWOOT_URL_INTERNAL}\",
        \"signMsg\": true,
        \"nameInbox\": \"${INBOX_NAME}\",
        \"number\": \"\",
        \"reopenConversation\": true,
        \"conversationPending\": false,
        \"mergeBrazilContacts\": true,
        \"importContacts\": true,
        \"importMessages\": true,
        \"daysLimitImportMessages\": 3
    }" 2>/dev/null)

if echo "$CHATWOOT_RESULT" | grep -q '"enabled":true'; then
    echo "  Chatwoot configurado!"
    echo "    Inbox: $INBOX_NAME"
    echo "    Account ID: $CHATWOOT_ACCOUNT_ID"
else
    echo "  AVISO: Possível erro ao configurar Chatwoot:"
    echo "  $CHATWOOT_RESULT"
fi

# 4. Verificação final
echo "[4/4] Verificação final..."
echo ""

echo "  TypeBot:"
curl -s "${EVOLUTION_URL}/typebot/find/${INSTANCE_NAME}" \
    -H "apikey: ${EVOLUTION_API_KEY}" 2>/dev/null | \
    grep -o '"enabled":[^,]*' | head -1 | sed 's/^/    /'

echo "  Chatwoot:"
curl -s "${EVOLUTION_URL}/chatwoot/find/${INSTANCE_NAME}" \
    -H "apikey: ${EVOLUTION_API_KEY}" 2>/dev/null | \
    grep -o '"enabled":[^,]*' | head -1 | sed 's/^/    /'

echo ""
echo "============================================"
echo "  Instância $INSTANCE_NAME linkada!"
echo "============================================"
echo ""
echo "  O bot vai responder quando alguém enviar"
echo "  uma mensagem contendo '$TYPEBOT_TRIGGER'"
echo ""
echo "  As conversas aparecerão no Chatwoot em:"
echo "  Inbox: $INBOX_NAME"
echo ""
