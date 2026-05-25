#!/bin/bash
# ─────────────────────────────────────────────────────────────────────────────
# deploy.sh — rebuild and restart the Skidoo web app on the server.
#
# Usage (run from the repo root on the server):
#   chmod +x deploy.sh   # first time only
#   ./deploy.sh
#
# Requirements: Docker, Git
# ─────────────────────────────────────────────────────────────────────────────
set -e

IMAGE_NAME="skidoo-web"
CONTAINER_NAME="skidoo-web"
HOST_PORT=80          # change to e.g. 8080 if port 80 is taken

# ── Colours ───────────────────────────────────────────────────────────────────
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

info()    { echo -e "${GREEN}[deploy]${NC} $1"; }
warning() { echo -e "${YELLOW}[deploy]${NC} $1"; }
error()   { echo -e "${RED}[deploy] ERROR:${NC} $1"; exit 1; }

# ── Checks ────────────────────────────────────────────────────────────────────
command -v docker >/dev/null 2>&1 || error "Docker is not installed."
command -v git    >/dev/null 2>&1 || error "Git is not installed."

# Must be run from the repo root (where mobile/ and deploy.sh live).
[ -f "mobile/Dockerfile" ] || error "Run this script from the repo root (where mobile/ folder is)."

# ── 1. Pull latest code ───────────────────────────────────────────────────────
info "Pulling latest code from main..."
git pull origin main

# ── 2. Build Docker image (Flutter build happens inside Docker) ───────────────
info "Building Docker image '${IMAGE_NAME}' (this takes a few minutes on first run)..."
docker build \
  --file mobile/Dockerfile \
  --tag  "${IMAGE_NAME}:latest" \
  .

# ── 3. Stop + remove old container ───────────────────────────────────────────
if docker ps -q --filter "name=^/${CONTAINER_NAME}$" | grep -q .; then
  info "Stopping running container '${CONTAINER_NAME}'..."
  docker stop "${CONTAINER_NAME}"
fi

if docker ps -aq --filter "name=^/${CONTAINER_NAME}$" | grep -q .; then
  info "Removing old container '${CONTAINER_NAME}'..."
  docker rm "${CONTAINER_NAME}"
fi

# ── 4. Start new container ────────────────────────────────────────────────────
info "Starting new container on port ${HOST_PORT}..."
docker run \
  --detach \
  --name    "${CONTAINER_NAME}" \
  --restart unless-stopped \
  --publish "${HOST_PORT}:80" \
  "${IMAGE_NAME}:latest"

# ── 5. Clean up dangling images ───────────────────────────────────────────────
info "Removing dangling images..."
docker image prune -f

# ── Done ──────────────────────────────────────────────────────────────────────
echo ""
info "Done! App is live on port ${HOST_PORT}."
info "Check logs: docker logs -f ${CONTAINER_NAME}"
