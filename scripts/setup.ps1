# ============================================
# Konecta - Script de Setup Inicial (PowerShell)
# ============================================
# Execute após o primeiro "docker compose up -d"
# Uso: .\scripts\setup.ps1

Write-Host "============================================" -ForegroundColor Cyan
Write-Host "  Konecta Atendimento Inteligente - Setup"   -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan

# Aguarda serviços
Write-Host "`n[1/4] Aguardando servicos..." -ForegroundColor Yellow
Start-Sleep -Seconds 10

# Cria databases
Write-Host "[2/4] Criando databases..." -ForegroundColor Yellow
docker exec konecta-postgres psql -U konecta -c "CREATE DATABASE chatwoot_production;" 2>$null
docker exec konecta-postgres psql -U konecta -c "CREATE DATABASE typebot;" 2>$null
docker exec konecta-postgres psql -U konecta -c "CREATE DATABASE evolution_v2;" 2>$null
Write-Host "  Databases OK" -ForegroundColor Green

# Chatwoot migrate
Write-Host "[3/4] Preparando Chatwoot (pode demorar)..." -ForegroundColor Yellow
docker compose stop chatwoot-rails chatwoot-sidekiq 2>$null
docker compose run --rm chatwoot-rails bundle exec rails db:chatwoot_prepare
docker compose up -d chatwoot-rails chatwoot-sidekiq
Write-Host "  Chatwoot OK" -ForegroundColor Green

# Cria instancias WhatsApp
Write-Host "[4/4] Criando instancias WhatsApp..." -ForegroundColor Yellow
$API_KEY = "9b6c865307df7d6e7127b1514ad06e9c56087ef43abd11c0b8d9cb5ff39c2b7f"
$instances = @("konecta-principal", "konecta-secundario", "konecta-teste")

foreach ($instance in $instances) {
    $body = "{`"instanceName`":`"$instance`",`"integration`":`"WHATSAPP-BAILEYS`",`"qrcode`":true}"
    docker run --rm --network konecta_konecta-network curlimages/curl -s -X POST "http://evolution-api:8080/instance/create" -H "apikey: $API_KEY" -H "Content-Type: application/json" -d $body
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
Write-Host "     docker exec -it konecta-chatwoot bundle exec rails console"
Write-Host "     SuperAdmin.create!(email: 'admin@konecta.adv.br', password: 'SuaSenhaForte123!', name: 'Admin Konecta')"
Write-Host ""
Write-Host "  2. Conectar WhatsApp (QR Code):"
foreach ($instance in $instances) {
    Write-Host "     docker run --rm --network konecta_konecta-network curlimages/curl -s http://evolution-api:8080/instance/connect/$instance -H 'apikey: $API_KEY'"
}
Write-Host ""
