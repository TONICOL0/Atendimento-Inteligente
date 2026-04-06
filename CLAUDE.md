# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Konecta is a Docker Compose orchestration of microservices for legal services (Konecta Jurídico) customer support and WhatsApp automation. It integrates Chatwoot (CRM), Evolution API (WhatsApp), TypeBot (chatbots), PostgreSQL, Redis, and MinIO. The only custom code is the `followup/` Node.js worker.

## Common Commands

```bash
# Start all services
docker compose up -d

# Stop all services
docker compose down

# View logs for a service
docker compose logs -f followup-worker
docker compose logs -f chatwoot-rails

# Restart a single service
docker compose restart followup-worker

# Rebuild followup worker after code changes
docker compose up -d --build followup-worker

# Run the follow-up worker locally (for development)
cd followup && npm install && node index.js

# First-time deployment
bash scripts/setup.sh

# Restore databases from dumps (after fresh deploy)
bash scripts/restore-db.sh

# Link a WhatsApp instance to TypeBot + Chatwoot
bash scripts/link-instance.sh konecta-principal

# Backup (runs daily at 3am via cron)
bash scripts/backup.sh
```

## Architecture

### Services (docker-compose.yml)
- **PostgreSQL** (pgvector/pgvector:pg16) — shared database, 3 databases: `chatwoot_production`, `typebot`, `evolution_v2`
- **Redis** (7-alpine) — cache and queues for Chatwoot and TypeBot
- **MinIO** — S3-compatible storage for Chatwoot attachments and TypeBot assets; auto-creates `typebot` bucket
- **Chatwoot** — customer support platform (port 3000); two containers: `chatwoot-rails` (web) + `chatwoot-sidekiq` (background jobs), sharing `chatwoot_storage` volume
- **Evolution API** — WhatsApp integration bridge (port 8081, internal 8080)
- **TypeBot Builder/Viewer** — chatbot builder (ports 3001/3002)
- **Follow-up Worker** — custom Node.js polling service, built from `followup/Dockerfile`

### Container Names
All containers are prefixed `konecta-`: `konecta-postgres`, `konecta-redis`, `konecta-minio`, `konecta-evolution`, `konecta-chatwoot`, `konecta-chatwoot-sidekiq`, `konecta-typebot-builder`, `konecta-typebot-viewer`, `konecta-followup`.

### Network
All services share a single bridge network `konecta-network`. Inter-service communication uses Docker service names (e.g., `http://chatwoot-rails:3000`, `http://evolution-api:8080`).

### Follow-up Worker (`followup/index.js`)
The only custom code. Single file, single dependency (`axios`). Polls Chatwoot resolved conversations every `FOLLOWUP_INTERVAL_MS` (default: 1800000ms = 30 min) and sends automated WhatsApp messages via Evolution API.

**Flow**: Poll resolved conversations → determine follow-up stage → fetch contact phone → send WhatsApp message via Evolution API → tag conversation with stage label → 2s delay between sends.

**3-stage follow-up** (based on hours since resolution):
- Stage 1 (`followup-sent-1`): after 24h
- Stage 2 (`followup-sent-2`): after 72h
- Stage 3 (`followup-sent-3`): after 168h (final attempt)

**Skipped conversations**: those labeled `clientes-fechados` or `planejamento-fechado`.

**Key APIs used**:
- Chatwoot: `GET /conversations?status=resolved`, `GET /contacts/:id`, `POST /conversations/:id/labels`
- Evolution: `POST /message/sendText/:instanceName`

### Scripts
- `scripts/setup.sh` — first-time deployment: creates databases, prepares Chatwoot, creates WhatsApp instances, prints manual config instructions
- `scripts/restore-db.sh` — restores databases from `scripts/db-dumps/*.sql` on fresh deploy
- `scripts/link-instance.sh <instance>` — configures TypeBot trigger + Chatwoot inbox for a WhatsApp instance via Evolution API
- `scripts/backup.sh` — dumps all 3 PostgreSQL databases + Evolution instances, 7-day retention
- `scripts/init-db.sql` — CREATE DATABASE statements for the 3 databases
- `update_bot.sql` — SQL to update TypeBot flow definition directly in the database

### Environment Configuration
- Root `.env` — Docker Compose secrets (DB passwords, API keys, tokens)
- `evolution/.env` — Evolution API settings
- `chatwoot/.env` — Chatwoot Rails settings (DB, Redis, SMTP, storage)
- `typebot/.env` — TypeBot settings (NextAuth, encryption, S3, SMTP)

Copy `.env.example` to `.env` and generate strong secrets for all `GERAR_*` placeholders before first run.

## Key Identifiers

**WhatsApp instances** (created in Evolution API):
- `konecta-principal` — main production
- `konecta-secundario` — secondary production
- `konecta-teste` — testing

**Chatwoot labels used by follow-up logic**:
- `followup-sent-1`, `followup-sent-2`, `followup-sent-3` — state tracking
- `clientes-fechados`, `planejamento-fechado` — skip flags

**Service URLs (internal Docker network)**:
- Chatwoot: `http://chatwoot-rails:3000`
- Evolution API: `http://evolution-api:8080`
- TypeBot Viewer: `http://typebot-viewer:3000`

**Service URLs (host/external)**:
- Chatwoot: `http://localhost:3000`
- Evolution API: `http://localhost:8081`
- TypeBot Builder: `http://localhost:3001`
- TypeBot Viewer: `http://localhost:3002`
- MinIO Console: `http://localhost:9001`
