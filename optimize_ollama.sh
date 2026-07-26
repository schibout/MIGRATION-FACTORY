#!/usr/bin/env bash
#
# optimize_ollama.sh — Optimisation d'Ollama et des deux modèles de l'Assistant IA
#   - qwen2.5-coder:7b  (génération SQL)
#   - bge-m3            (embeddings : cache sémantique + RAG)
#
# Ce script (à lancer SUR LE SERVEUR qui héberge Ollama, en root/sudo) :
#   1. configure le service systemd Ollama (threads, keep-alive, 2 modèles en RAM)
#   2. redémarre Ollama et attend qu'il réponde
#   3. télécharge les modèles si absents
#   4. précharge (warm) les DEUX modèles en mémoire pour 24h
#   5. vérifie l'état final (ollama ps)
#
# Idempotent : peut être relancé sans risque.
#
# Usage :
#   sudo ./optimize_ollama.sh
#
# Variables d'environnement optionnelles :
#   OLLAMA_HOST_URL   (def: http://localhost:11434)  endpoint de l'API Ollama
#   SQL_MODEL         (def: qwen2.5-coder:7b)
#   EMBED_MODEL       (def: bge-m3)
#   NUM_THREADS       (def: 4)  nb de cœurs CPU alloués
#   KEEP_ALIVE        (def: 24h) durée de maintien des modèles en RAM
set -euo pipefail

OLLAMA_HOST_URL="${OLLAMA_HOST_URL:-http://localhost:11434}"
SQL_MODEL="${SQL_MODEL:-qwen2.5-coder:7b}"
EMBED_MODEL="${EMBED_MODEL:-bge-m3}"
NUM_THREADS="${NUM_THREADS:-4}"
KEEP_ALIVE="${KEEP_ALIVE:-24h}"

log()  { printf '\033[1;34m[optimize]\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[attention]\033[0m %s\n' "$*"; }
err()  { printf '\033[1;31m[erreur]\033[0m %s\n' "$*" >&2; }

# --------------------------------------------------------------------------- #
# 0. Vérifications préalables
# --------------------------------------------------------------------------- #
if ! command -v ollama >/dev/null 2>&1; then
  err "Ollama n'est pas installé. Lancez d'abord l'installation (cf. install_IA.sh)."
  exit 1
fi

USE_SYSTEMD=1
if ! command -v systemctl >/dev/null 2>&1 || ! systemctl list-unit-files 2>/dev/null | grep -q '^ollama.service'; then
  warn "Service systemd 'ollama' introuvable : la configuration systemd sera ignorée."
  warn "Le préchauffage et le keep-alive via l'API restent appliqués."
  USE_SYSTEMD=0
fi

# --------------------------------------------------------------------------- #
# 1. Configuration systemd : threads, keep-alive, 2 modèles chargés ensemble
# --------------------------------------------------------------------------- #
if [ "$USE_SYSTEMD" -eq 1 ]; then
  if [ "$(id -u)" -ne 0 ]; then
    err "La configuration systemd nécessite les droits root. Relancez : sudo ./optimize_ollama.sh"
    exit 1
  fi

  log "Écriture de l'override systemd Ollama…"
  mkdir -p /etc/systemd/system/ollama.service.d
  cat > /etc/systemd/system/ollama.service.d/override.conf <<EOF
[Service]
# Accessible depuis le backend (autre conteneur/hôte)
Environment="OLLAMA_HOST=0.0.0.0:11434"
# Cœurs CPU alloués à l'inférence
Environment="OLLAMA_NUM_THREADS=${NUM_THREADS}"
# Garde les modèles chargés en RAM (évite les rechargements à froid)
Environment="OLLAMA_KEEP_ALIVE=${KEEP_ALIVE}"
# Autorise les DEUX modèles (SQL + embeddings) en RAM simultanément :
# sans cela, bge-m3 éjecte qwen (et inversement) -> rechargements coûteux
Environment="OLLAMA_MAX_LOADED_MODELS=2"
# Une seule génération à la fois (l'appli sérialise déjà via sémaphore/verrou)
Environment="OLLAMA_NUM_PARALLEL=1"
# Attention plus rapide et moins gourmande en mémoire
Environment="OLLAMA_FLASH_ATTENTION=1"
EOF

  log "Rechargement de systemd et redémarrage d'Ollama…"
  systemctl daemon-reload
  systemctl restart ollama
fi

# --------------------------------------------------------------------------- #
# 2. Attente de la disponibilité de l'API
# --------------------------------------------------------------------------- #
log "Attente de la disponibilité d'Ollama sur ${OLLAMA_HOST_URL}…"
for i in $(seq 1 30); do
  if curl -fsS "${OLLAMA_HOST_URL}/api/tags" >/dev/null 2>&1; then
    log "Ollama répond."
    break
  fi
  if [ "$i" -eq 30 ]; then
    err "Ollama ne répond pas après 30s. Vérifiez : systemctl status ollama"
    exit 1
  fi
  sleep 1
done

# --------------------------------------------------------------------------- #
# 3. Téléchargement des modèles si absents
# --------------------------------------------------------------------------- #
ensure_model() {
  local model="$1"
  if ollama list 2>/dev/null | awk '{print $1}' | grep -qx "$model"; then
    log "Modèle déjà présent : $model"
  else
    log "Téléchargement du modèle : $model (peut prendre plusieurs minutes)…"
    ollama pull "$model"
  fi
}

ensure_model "$SQL_MODEL"
ensure_model "$EMBED_MODEL"

# --------------------------------------------------------------------------- #
# 4. Préchauffage : charge les DEUX modèles en RAM pour KEEP_ALIVE
# --------------------------------------------------------------------------- #
log "Préchauffage du modèle SQL ($SQL_MODEL)…"
curl -fsS "${OLLAMA_HOST_URL}/api/generate" \
  -d "{\"model\":\"${SQL_MODEL}\",\"keep_alive\":\"${KEEP_ALIVE}\"}" >/dev/null

log "Préchauffage du modèle d'embeddings ($EMBED_MODEL)…"
# /api/embeddings charge le modèle d'embeddings et applique keep_alive
curl -fsS "${OLLAMA_HOST_URL}/api/embeddings" \
  -d "{\"model\":\"${EMBED_MODEL}\",\"prompt\":\"warmup\",\"keep_alive\":\"${KEEP_ALIVE}\"}" >/dev/null

# --------------------------------------------------------------------------- #
# 5. Vérification finale
# --------------------------------------------------------------------------- #
log "État des modèles chargés en mémoire :"
if command -v ollama >/dev/null 2>&1; then
  ollama ps || true
fi

cat <<EOF

------------------------------------------------------------------
✅ Optimisation terminée.

Récapitulatif :
  - Service Ollama : OLLAMA_MAX_LOADED_MODELS=2, NUM_THREADS=${NUM_THREADS},
    KEEP_ALIVE=${KEEP_ALIVE}, FLASH_ATTENTION=1, NUM_PARALLEL=1
  - Modèles préchargés (warm 24h) :
      * ${SQL_MODEL}   (génération SQL)
      * ${EMBED_MODEL} (embeddings : cache + RAG)

Vérifier que les DEUX restent chargés "24 hours from now" :
    ollama ps

Côté application (.env du backend), valeurs recommandées :
    AI_TIMEOUT_SECONDS=600
    AI_NUM_CTX=4096
    AI_NUM_PREDICT=256
    AI_EMBED_ENABLED=true
    AI_EMBED_KEEP_ALIVE=24h
Puis redémarrer le backend pour prise en compte.
------------------------------------------------------------------
EOF
