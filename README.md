# Konecta - Atendimento Inteligente

Sistema completo de atendimento ao cliente com automação WhatsApp para escritórios jurídicos. Integra CRM, chatbots e follow-up automático em uma stack Docker Compose.

## O que faz

- **Atendimento via WhatsApp** — recebe e gerencia conversas de clientes pelo WhatsApp usando Chatwoot como CRM
- **Chatbot automático** — fluxos de atendimento automatizados com TypeBot (triagem, coleta de dados, agendamento)
- **Follow-up automático** — envia mensagens de acompanhamento para leads que não responderam (24h, 72h e 168h após resolução)
- **Multi-instância WhatsApp** — suporta múltiplos números de WhatsApp simultâneos
- **Backup automático** — backup diário dos bancos de dados com retenção de 7 dias

## Serviços

| Serviço | Porta | Descrição |
|---------|-------|-----------|
| Chatwoot | 3000 | CRM de atendimento ao cliente |
| Evolution API | 8081 | Ponte de conexão com WhatsApp |
| TypeBot Builder | 3001 | Editor visual de chatbots |
| TypeBot Viewer | 3002 | Execução dos chatbots |
| MinIO | 9001 | Armazenamento S3 (console) |
| PostgreSQL | 5432 | Banco de dados compartilhado |
| Redis | 6379 | Cache e filas |

## Pré-requisitos

- Docker e Docker Compose instalados
- VPS com no mínimo 4GB de RAM
- Número de WhatsApp para conectar

## Instalação

### 1. Clone o repositório

```bash
git clone https://github.com/TONICOL0/konecta.git
cd konecta
```

### 2. Configure as variáveis de ambiente

Copie os arquivos de exemplo e preencha com suas credenciais:

```bash
cp .env.example .env
```

Edite o `.env` e substitua todos os valores `GERAR_*` por senhas fortes. Você também precisa criar os arquivos de ambiente dos serviços:

- `chatwoot/.env` — configurações do Chatwoot (banco, Redis, SMTP, storage)
- `evolution/.env` — configurações da Evolution API
- `typebot/.env` — configurações do TypeBot (NextAuth, S3, SMTP)

### 3. Suba os containers

```bash
docker compose up -d
```

### 4. Execute o setup inicial

```bash
bash scripts/setup.sh
```

Este script:
- Cria os 3 bancos de dados (`chatwoot_production`, `typebot`, `evolution_v2`)
- Prepara o banco do Chatwoot
- Cria as instâncias WhatsApp na Evolution API
- Exibe instruções para configuração manual

### 5. Crie o admin do Chatwoot

```bash
docker exec -it konecta-chatwoot bundle exec rails console
```

No console Rails:
```ruby
SuperAdmin.create!(email: 'seu@email.com', password: 'SuaSenhaForte!', name: 'Admin')
```

### 6. Conecte o WhatsApp

Acesse a Evolution API para escanear o QR code:

```bash
curl http://localhost:8081/instance/connect/konecta-principal -H 'apikey: SUA_API_KEY'
```

### 7. Vincule o WhatsApp ao Chatwoot + TypeBot

```bash
bash scripts/link-instance.sh konecta-principal
```

Este script configura automaticamente:
- O TypeBot para responder a palavras-chave específicas
- O Chatwoot para receber todas as conversas em uma inbox

## Como funciona o Follow-up

O worker de follow-up (`followup/`) monitora conversas resolvidas no Chatwoot e envia mensagens automáticas pelo WhatsApp:

1. **24h após resolução** — primeira mensagem perguntando se restou alguma dúvida
2. **72h após resolução** — segunda tentativa de contato
3. **168h após resolução** — última mensagem de acompanhamento

Conversas com as etiquetas `clientes-fechados` ou `planejamento-fechado` são ignoradas.

## Scripts úteis

```bash
# Ver logs de um serviço
docker compose logs -f followup-worker

# Reiniciar um serviço
docker compose restart followup-worker

# Rebuild após alterar código do follow-up
docker compose up -d --build followup-worker

# Backup manual
bash scripts/backup.sh

# Restaurar bancos de dados (após deploy limpo)
bash scripts/restore-db.sh
```

## Estrutura do Projeto

```
.
├── chatwoot/           # Configuração do Chatwoot (.env)
├── evolution/          # Configuração da Evolution API (.env)
├── followup/           # Worker de follow-up automático (Node.js)
│   ├── Dockerfile
│   ├── index.js
│   └── package.json
├── nginx/              # Configuração do Nginx (reverse proxy)
├── scripts/
│   ├── setup.sh        # Setup inicial
│   ├── backup.sh       # Backup automático
│   ├── restore-db.sh   # Restauração de databases
│   └── link-instance.sh # Vincular WhatsApp ao Chatwoot + TypeBot
├── typebot/            # Configuração do TypeBot (.env)
├── docker-compose.yml  # Orquestração dos serviços
└── .env.example        # Modelo de variáveis de ambiente
```

## Backup

O backup roda automaticamente às 3h da manhã via cron:

```bash
# Adicionar ao crontab
crontab -e
0 3 * * * /opt/konecta/scripts/backup.sh
```

Faz backup de:
- Todos os 3 bancos PostgreSQL
- Sessões do WhatsApp (Evolution instances)
- Retenção de 7 dias

## Licença

Este projeto é de uso privado.
