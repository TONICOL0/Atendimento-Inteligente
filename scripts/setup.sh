#!/bin/bash
# ============================================
# Proj-Chat - Script de Setup Inicial
# ============================================
# Execute após o primeiro "docker compose up -d"
# Uso: bash scripts/setup.sh

set -e

echo "============================================"
echo "  Proj-Chat Atendimento Inteligente - Setup"
echo "============================================"

# Cores
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Aguarda serviços ficarem prontos
echo -e "${YELLOW}[1/5] Aguardando serviços ficarem prontos...${NC}"
sleep 10

# Verifica se PostgreSQL está acessível
until docker exec proj-chat-postgres pg_isready -U proj_chat > /dev/null 2>&1; do
  echo "Aguardando PostgreSQL..."
  sleep 3
done
echo -e "${GREEN}✓ PostgreSQL pronto${NC}"

# Verifica se Redis está acessível
until docker exec proj-chat-redis redis-cli -a "$(grep REDIS_PASSWORD .env | cut -d= -f2)" ping > /dev/null 2>&1; do
  echo "Aguardando Redis..."
  sleep 3
done
echo -e "${GREEN}✓ Redis pronto${NC}"

# ============================================
# Criar databases adicionais
# ============================================
echo -e "${YELLOW}[2/6] Criando databases...${NC}"
docker exec proj-chat-postgres psql -U proj_chat -c "SELECT 1 FROM pg_database WHERE datname='chatwoot_production'" | grep -q 1 || \
  docker exec proj-chat-postgres psql -U proj_chat -c "CREATE DATABASE chatwoot_production;"
docker exec proj-chat-postgres psql -U proj_chat -c "SELECT 1 FROM pg_database WHERE datname='typebot'" | grep -q 1 || \
  docker exec proj-chat-postgres psql -U proj_chat -c "CREATE DATABASE typebot;"
docker exec proj-chat-postgres psql -U proj_chat -c "SELECT 1 FROM pg_database WHERE datname='evolution_v2'" | grep -q 1 || \
  docker exec proj-chat-postgres psql -U proj_chat -c "CREATE DATABASE evolution_v2;"
echo -e "${GREEN}✓ Databases criados${NC}"

# ============================================
# Chatwoot - Preparar database
# ============================================
echo -e "${YELLOW}[3/6] Preparando database do Chatwoot...${NC}"
docker exec proj-chat-chatwoot bundle exec rails db:chatwoot_prepare
echo -e "${GREEN}✓ Database Chatwoot preparado${NC}"

# ============================================
# Chatwoot - Criar Super Admin
# ============================================
echo -e "${YELLOW}[4/6] Criando Super Admin do Chatwoot...${NC}"
echo ""
echo "Acesse: http://localhost:3000/super_admin"
echo "Use o console para criar o admin:"
echo ""
echo "  docker exec -it proj-chat-chatwoot bundle exec rails console"
echo ""
echo "  No console Rails, execute:"
echo "  SuperAdmin.create!(email: 'admin@proj-chat.com', password: 'SuaSenhaForte123!', name: 'Admin Proj-Chat')"
echo ""
echo -e "${GREEN}✓ Instruções de criação do admin exibidas${NC}"

# ============================================
# Evolution API - Criar Instâncias WhatsApp
# ============================================
echo -e "${YELLOW}[5/6] Criando instâncias WhatsApp na Evolution API...${NC}"

API_KEY=$(grep EVOLUTION_API_KEY .env | cut -d= -f2)
EVOLUTION_URL="http://localhost:8081"

# Instância 1: Principal (tráfego pago)
echo "Criando instância: proj-chat-principal..."
curl -s -X POST "${EVOLUTION_URL}/instance/create" \
  -H "apikey: ${API_KEY}" \
  -H "Content-Type: application/json" \
  -d '{
    "instanceName": "proj-chat-principal",
    "integration": "WHATSAPP-BAILEYS",
    "qrcode": true
  }' | head -c 200
echo ""

# Instância 2: Secundário (tráfego pago)
echo "Criando instância: proj-chat-secundario..."
curl -s -X POST "${EVOLUTION_URL}/instance/create" \
  -H "apikey: ${API_KEY}" \
  -H "Content-Type: application/json" \
  -d '{
    "instanceName": "proj-chat-secundario",
    "integration": "WHATSAPP-BAILEYS",
    "qrcode": true
  }' | head -c 200
echo ""

# Instância 3: Teste
echo "Criando instância: proj-chat-teste..."
curl -s -X POST "${EVOLUTION_URL}/instance/create" \
  -H "apikey: ${API_KEY}" \
  -H "Content-Type: application/json" \
  -d '{
    "instanceName": "proj-chat-teste",
    "integration": "WHATSAPP-BAILEYS",
    "qrcode": true
  }' | head -c 200
echo ""

echo -e "${GREEN}✓ 3 instâncias WhatsApp criadas${NC}"

# ============================================
# Instruções de configuração manual
# ============================================
echo -e "${YELLOW}[6/6] Configurações manuais necessárias no Chatwoot:${NC}"
echo ""
echo "Acesse http://localhost:3000 e configure:"
echo ""
echo "📋 SETORES (Settings > Teams):"
echo "   1. Financeiro"
echo "   2. Atendimento"
echo "   3. Comercial"
echo "   4. Planejamento"
echo "   5. Administrativo"
echo ""
echo "🏷️  ETIQUETAS (Settings > Labels):"
echo "   trabalhista, previdenciario, usucapiao, consumidor,"
echo "   primeira-fase, planejamento-prev, planejamento-fechado,"
echo "   clientes-fechados"
echo ""
echo "👥 USUÁRIOS (Settings > Agents):"
echo "   Cadastre os 15 usuários e atribua aos setores"
echo ""
echo "⚡ RESPOSTAS RÁPIDAS (Settings > Canned Responses):"
echo "   /orcamento, /documentos, /horario, /pix,"
echo "   /aguarde, /boasvindas, /cnis, /formulario"
echo ""
echo "🤖 AUTOMAÇÕES (Settings > Automation):"
echo "   - Auto-tag por palavras-chave"
echo "   - Resposta fora do horário"
echo "   - Novo lead → funil 'Novo Lead'"
echo ""
echo "📊 ATRIBUTOS CUSTOM (Settings > Custom Attributes):"
echo "   Contato: cpf, cidade, estado, origem_lead, funil, area_direito"
echo "   Conversa: tipo_servico, urgencia"
echo ""
echo "🔗 QR CODE WhatsApp:"
echo "   curl http://localhost:8081/instance/connect/proj-chat-principal -H 'apikey: ${API_KEY}'"
echo "   curl http://localhost:8081/instance/connect/proj-chat-secundario -H 'apikey: ${API_KEY}'"
echo "   curl http://localhost:8081/instance/connect/proj-chat-teste -H 'apikey: ${API_KEY}'"
echo ""
echo "============================================"
echo -e "${GREEN}  Setup concluído!${NC}"
echo "============================================"
echo ""
echo "Serviços disponíveis:"
echo "  Chatwoot:        http://localhost:3000"
echo "  Evolution API:   http://localhost:8081"
echo "  TypeBot Builder: http://localhost:3001"
echo "  TypeBot Viewer:  http://localhost:3002"
echo "  MinIO Console:   http://localhost:9001"
echo ""
