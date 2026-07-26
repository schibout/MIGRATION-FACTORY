#!/usr/bin/env bash
# =====================================================================
# link-tools.sh — Associe Open WebUI et mcpo (outils MCP)
#
# Ce script :
#   1. Vérifie que les conteneurs open-webui et mcpo tournent
#   2. Les rattache au même réseau Docker (ia-net) si nécessaire
#   3. Teste la connectivité open-webui -> mcpo (résolution + OpenAPI)
#   4. Affiche les URLs et la clé à copier dans Open WebUI
#
# Usage :
#   chmod +x link-tools.sh
#   ./link-tools.sh
# =====================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# --- Chargement de la config (.env) ---
if [[ -f .env ]]; then
  if grep -q $'\r' .env 2>/dev/null; then sed -i 's/\r$//' .env; fi
  set -a; # shellcheck disable=SC1091
  source .env; set +a
fi

SERVER_IP="${SERVER_IP:-10.190.100.58}"
DOCKER_NETWORK="${DOCKER_NETWORK:-ia-net}"
MCPO_PORT="${MCPO_PORT:-8800}"
MCPO_API_KEY="${MCPO_API_KEY:-trimet-mcp-CHANGE_ME}"
WEBUI_CONTAINER="open-webui"
MCPO_CONTAINER="mcpo"
TOOLS=("postgres" "fetch" "time")

log()  { echo -e "\033[1;36m[link-tools]\033[0m $*"; }
ok()   { echo -e "\033[1;32m[link-tools]\033[0m $*"; }
warn() { echo -e "\033[1;33m[link-tools]\033[0m $*"; }
err()  { echo -e "\033[1;31m[link-tools]\033[0m $*" >&2; }

# ---------------------------------------------------------------------
# 1. Conteneurs présents et démarrés
# ---------------------------------------------------------------------
check_running() {
  local name="$1"
  if ! docker ps --format '{{.Names}}' | grep -qx "$name"; then
    err "Le conteneur '$name' n'est pas démarré."
    err "  -> Lancez d'abord : ./deploytool.sh"
    exit 1
  fi
  ok "Conteneur '$name' actif."
}

# ---------------------------------------------------------------------
# 2. Réseau Docker partagé
# ---------------------------------------------------------------------
ensure_network() {
  if ! docker network inspect "$DOCKER_NETWORK" >/dev/null 2>&1; then
    log "Création du réseau Docker '$DOCKER_NETWORK'"
    docker network create "$DOCKER_NETWORK"
  fi
}

connect_network() {
  local name="$1"
  local nets
  nets="$(docker inspect -f '{{range $k,$v := .NetworkSettings.Networks}}{{$k}} {{end}}' "$name")"
  if echo "$nets" | grep -qw "$DOCKER_NETWORK"; then
    ok "'$name' est déjà sur le réseau '$DOCKER_NETWORK'."
  else
    log "Rattachement de '$name' au réseau '$DOCKER_NETWORK' (réseaux actuels : $nets)"
    docker network connect "$DOCKER_NETWORK" "$name"
    ok "'$name' rattaché à '$DOCKER_NETWORK'."
  fi
}

# ---------------------------------------------------------------------
# 3. Test de connectivité open-webui -> mcpo
# ---------------------------------------------------------------------
test_connectivity() {
  local url="http://${MCPO_CONTAINER}:8000/${TOOLS[0]}/openapi.json"
  log "Test depuis '$WEBUI_CONTAINER' : $url"
  if docker exec "$WEBUI_CONTAINER" curl -sf \
        -H "Authorization: Bearer ${MCPO_API_KEY}" \
        "$url" >/dev/null 2>&1; then
    ok "Connectivité OK : Open WebUI joint mcpo par son nom de conteneur."
  else
    warn "Échec de connexion par nom. Diagnostic détaillé :"
    docker exec "$WEBUI_CONTAINER" curl -s -o /dev/null -w "  code HTTP=%{http_code}\n" \
        -H "Authorization: Bearer ${MCPO_API_KEY}" "$url" 2>&1 || true
    warn "Si 'could not resolve host' : le réseau n'est pas partagé (relancez ce script)."
    warn "Si code 401 : la clé MCPO_API_KEY ne correspond pas."
    warn "Si 'connection refused' : le conteneur mcpo n'écoute pas (vérifiez ./deploytool.sh --logs)."
    warn "Repli possible : utilisez l'URL hôte http://${SERVER_IP}:${MCPO_PORT}/<outil>"
  fi
}

# ---------------------------------------------------------------------
# 4. Récapitulatif à copier dans Open WebUI
# ---------------------------------------------------------------------
print_summary() {
  echo
  echo "====================================================================="
  echo " À configurer dans Open WebUI : Settings (⚙️) → Tools → +"
  echo " Auth : Bearer    |    Clé : ${MCPO_API_KEY}"
  echo "---------------------------------------------------------------------"
  echo " URL interne (même réseau Docker, recommandé) :"
  for t in "${TOOLS[@]}"; do
    echo "   • http://${MCPO_CONTAINER}:8000/${t}"
  done
  echo
  echo " URL externe (repli, depuis le navigateur / hors Docker) :"
  for t in "${TOOLS[@]}"; do
    echo "   • http://${SERVER_IP}:${MCPO_PORT}/${t}"
  done
  echo "---------------------------------------------------------------------"
  echo " Swagger de vérification : http://${SERVER_IP}:${MCPO_PORT}/${TOOLS[0]}/docs"
  echo "====================================================================="
}

# ---------------------------------------------------------------------
# Exécution
# ---------------------------------------------------------------------
log "Vérification des conteneurs..."
check_running "$MCPO_CONTAINER"
check_running "$WEBUI_CONTAINER"

log "Vérification du réseau Docker '$DOCKER_NETWORK'..."
ensure_network
connect_network "$MCPO_CONTAINER"
connect_network "$WEBUI_CONTAINER"

test_connectivity
print_summary
