#!/usr/bin/env bash
# =====================================================================
# deploytool.sh — Déploiement Open WebUI + mcpo (outils MCP) avec Ollama
# Serveur cible : FRSJMTAL1 (10.190.100.58)
#
# Usage :
#   cp .env.example .env      # puis adapter les valeurs (mots de passe, clé API)
#   chmod +x deploytool.sh
#   ./deploytool.sh           # déploie mcpo + Open WebUI
#   ./deploytool.sh --mcpo    # déploie uniquement mcpo
#   ./deploytool.sh --webui   # déploie uniquement Open WebUI
#   ./deploytool.sh --down    # arrête et supprime les deux conteneurs
#   ./deploytool.sh --logs    # affiche les logs des deux conteneurs
# =====================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# ---------------------------------------------------------------------
# 1. Chargement de la configuration
# ---------------------------------------------------------------------
if [[ ! -f .env ]]; then
  echo "❌ Fichier .env introuvable. Lancez : cp .env.example .env puis adaptez-le."
  exit 1
fi
# Supprime d'éventuelles fins de ligne Windows (CRLF) avant de charger
if grep -q $'\r' .env 2>/dev/null; then
  sed -i 's/\r$//' .env
fi
set -a
# shellcheck disable=SC1091
source .env
set +a

: "${SERVER_IP:?Variable SERVER_IP manquante dans .env}"
: "${DOCKER_NETWORK:=ia-net}"
: "${OLLAMA_BASE_URL:?Variable OLLAMA_BASE_URL manquante}"
: "${OPENWEBUI_IMAGE:=ghcr.io/open-webui/open-webui:main}"
: "${OPENWEBUI_PORT:=3001}"
: "${OPENWEBUI_VOLUME:=open-webui}"
: "${MCPO_IMAGE:=ghcr.io/open-webui/mcpo:main}"
: "${MCPO_PORT:=8000}"
: "${MCPO_API_KEY:?Variable MCPO_API_KEY manquante}"

log()  { echo -e "\033[1;36m[deploytool]\033[0m $*"; }
warn() { echo -e "\033[1;33m[deploytool]\033[0m $*"; }
err()  { echo -e "\033[1;31m[deploytool]\033[0m $*" >&2; }

# ---------------------------------------------------------------------
# 2. Génération de la config mcpo (password injecté depuis .env)
# ---------------------------------------------------------------------
generate_mcp_config() {
  : "${PG_HOST:?PG_HOST manquant}"; : "${PG_PORT:?PG_PORT manquant}"
  : "${PG_DB:?PG_DB manquant}"; : "${PG_USER:?PG_USER manquant}"
  : "${PG_PASSWORD:?PG_PASSWORD manquant}"
  local dsn="postgresql://${PG_USER}:${PG_PASSWORD}@${PG_HOST}:${PG_PORT}/${PG_DB}"
  log "Génération de mcp-config.runtime.json"
  cat > mcp-config.runtime.json <<JSON
{
  "mcpServers": {
    "postgres": {
      "command": "uvx",
      "args": ["postgres-mcp", "--access-mode=unrestricted"],
      "env": {
        "DATABASE_URI": "${dsn}"
      }
    },
    "fetch": {
      "command": "uvx",
      "args": ["mcp-server-fetch"]
    },
    "time": {
      "command": "uvx",
      "args": ["mcp-server-time", "--local-timezone", "Europe/Paris"]
    }
  }
}
JSON
  chmod 600 mcp-config.runtime.json
}

# ---------------------------------------------------------------------
# 3. Réseau Docker partagé
# ---------------------------------------------------------------------
ensure_network() {
  if ! docker network inspect "$DOCKER_NETWORK" >/dev/null 2>&1; then
    log "Création du réseau Docker '$DOCKER_NETWORK'"
    docker network create "$DOCKER_NETWORK"
  else
    log "Réseau Docker '$DOCKER_NETWORK' déjà présent"
  fi
}

# ---------------------------------------------------------------------
# 4. Déploiement mcpo
# ---------------------------------------------------------------------
deploy_mcpo() {
  generate_mcp_config
  ensure_network
  log "Récupération de l'image mcpo"
  docker pull "$MCPO_IMAGE"
  log "(Re)démarrage du conteneur mcpo sur le port $MCPO_PORT"
  docker rm -f mcpo >/dev/null 2>&1 || true
  docker run -d \
    --name mcpo \
    --restart always \
    --network "$DOCKER_NETWORK" \
    -p "${MCPO_PORT}:8000" \
    -v "${SCRIPT_DIR}/mcp-config.runtime.json:/app/config.json:ro" \
    "$MCPO_IMAGE" \
    --config /app/config.json --api-key "$MCPO_API_KEY"
  log "✅ mcpo lancé. Swagger : http://${SERVER_IP}:${MCPO_PORT}/docs"
  log "   Outils exposés : /postgres  /fetch  /time"
}

# ---------------------------------------------------------------------
# 5. Déploiement Open WebUI
# ---------------------------------------------------------------------
deploy_webui() {
  ensure_network
  log "Récupération de l'image Open WebUI"
  docker pull "$OPENWEBUI_IMAGE"
  log "(Re)démarrage du conteneur open-webui sur le port $OPENWEBUI_PORT"
  docker rm -f open-webui >/dev/null 2>&1 || true
  docker run -d \
    --name open-webui \
    --restart always \
    --network "$DOCKER_NETWORK" \
    -p "${OPENWEBUI_PORT}:8080" \
    -e OLLAMA_BASE_URL="$OLLAMA_BASE_URL" \
    -v "${OPENWEBUI_VOLUME}:/app/backend/data" \
    "$OPENWEBUI_IMAGE"
  log "✅ Open WebUI lancé : http://${SERVER_IP}:${OPENWEBUI_PORT}"
  warn "Pensez à déclarer les outils dans Open WebUI :"
  warn "  Settings → Tools → +  →  http://mcpo:8000/postgres  (Bearer: ${MCPO_API_KEY})"
  warn "  (depuis le même réseau Docker, utilisez 'mcpo' comme hôte)"
}

# ---------------------------------------------------------------------
# 6. Arrêt / logs
# ---------------------------------------------------------------------
down() {
  log "Arrêt et suppression des conteneurs mcpo + open-webui"
  docker rm -f mcpo open-webui >/dev/null 2>&1 || true
  log "✅ Terminé (volumes et réseau conservés)"
}

show_logs() {
  docker logs --tail 50 mcpo 2>/dev/null || warn "mcpo non démarré"
  echo "----"
  docker logs --tail 50 open-webui 2>/dev/null || warn "open-webui non démarré"
}

status() {
  echo
  docker ps --filter "name=mcpo" --filter "name=open-webui" \
    --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
}

# ---------------------------------------------------------------------
# 7. Dispatch
# ---------------------------------------------------------------------
case "${1:-all}" in
  --mcpo)  deploy_mcpo;  status ;;
  --webui) deploy_webui; status ;;
  --down)  down ;;
  --logs)  show_logs ;;
  all|"")  deploy_mcpo; deploy_webui; status ;;
  *) err "Option inconnue : $1"; echo "Voir l'en-tête du script pour l'usage."; exit 1 ;;
esac
