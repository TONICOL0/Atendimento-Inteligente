# ============================================
# Proj-Chat - Script de Setup Inicial (PowerShell)
# ============================================
# Execute após o primeiro "docker compose up -d"
# Uso: .\scripts\setup.ps1

Write-Host "============================================" -ForegroundColor Cyan
Write-Host "  Proj-Chat Atendimento Inteligente - Setup"   -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan

# Aguarda serviços
Write-Host "`n[1/4] Aguardando servicos..." -ForegroundColor Yellow
Start-Sleep -Seconds 10

# Cria databases
Write-Host "[2/4] Criando databases..." -ForegroundColor Yellow
docker exec proj-chat-postgres psql -U proj_chat -c "CREATE DATABASE chatwoot_production;" 2>$null
docker exec proj-chat-postgres psql -U proj_chat -c "CREATE DATABASE typebot;" 2>$null
docker exec proj-chat-postgres psql -U proj_chat -c "CREATE DATABASE evolution_v2;" 2>$null
Write-Host "  Databases OK" -ForegroundColor Green

# Chatwoot migrate
Write-Host "[3/4] Preparando Chatwoot (pode demorar)..." -ForegroundColor Yellow
docker compose stop chatwoot-rails chatwoot-sidekiq 2>$null
docker compose run --rm chatwoot-rails bundle exec rails db:chatwoot_prepare
docker compose up -d chatwoot-rails chatwoot-sidekiq
Write-Host "  Chatwoot OK" -ForegroundColor Green

# Cria instancias WhatsApp
Write-Host "[4/4] Criando instancias WhatsApp..." -ForegroundColor Yellow
$API_KEY = $env:EVOLUTION_API_KEY
if (-not $API_KEY) {
    Write-Host "  ERRO: Defina a variavel EVOLUTION_API_KEY" -ForegroundColor Red
    exit 1
}
$instances = @("proj-chat-principal", "proj-chat-secundario", "proj-chat-teste")

foreach ($instance in $instances) {
    $body = "{`"instanceName`":`"$instance`",`"integration`":`"WHATSAPP-BAILEYS`",`"qrcode`":true}"
    docker run --rm --network proj-chat_proj-chat-network curlimages/curl -s -X POST "http://evolution-api:8080/instance/create" -H "apikey: $API_KEY" -H "Content-Type: application/json" -d $body
    Write-Host "  $instance criada" -ForegroundColor Green
}

Write-Host "`n============================================" -ForegroundColor Cyan
Write-Host "  Setup concluido!" -ForegroundColor Green
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Servicos disponiveis (via IP da VPS):"
Write-Host "  Chatwoot:        porta 3000"
Write-Host "  Evolution API:   porta 8081"
Write-Host "  TypeBot Builder: porta 3001"
Write-Host "  TypeBot Viewer:  porta 3002"
Write-Host "  MinIO Console:   porta 9001"
Write-Host ""
Write-Host "Proximos passos:" -ForegroundColor Yellow
Write-Host "  1. Criar admin do Chatwoot:"
Write-Host "     docker exec -it proj-chat-chatwoot bundle exec rails console"
Write-Host "     SuperAdmin.create!(email: 'admin@seudominio.com', password: 'SuaSenhaForte123!', name: 'Admin')"
Write-Host ""
Write-Host "  2. Conectar WhatsApp (QR Code):"
foreach ($instance in $instances) {
    Write-Host "     docker run --rm --network proj-chat_proj-chat-network curlimages/curl -s http://evolution-api:8080/instance/connect/$instance -H 'apikey: $API_KEY'"
}
Write-Host ""
