#!/bin/bash
# =====================================================================
# deploy_all.sh — Déploiement complet de l'Assistant IA EN UNE COMMANDE.
# À exécuter SUR LE SERVEUR (10.190.100.58), à la racine du dépôt.
# Le code est transféré MANUELLEMENT (pas de git ici).
#
#   chmod +x deploy_all.sh && ./deploy_all.sh
#   ./deploy_all.sh --no-prechauffe   # déploie sans préchauffer/indexer (rapide)
#
# Étapes : .env -> migrations -> backend -> ATTENTE healthy -> frontend + tests
#          -> préchauffage & index (délégués à ./prechauffe_ia.sh, hors chemin critique).
# Idempotent : ré-exécutable sans risque (migrations + index = upsert).
#
# NOTE : le préchauffage des modèles (lent, CPU saturé) est SORTI dans
# ./prechauffe_ia.sh et lancé EN DERNIER, une fois backend + frontend en ligne.
# Sinon il saturait le CPU pendant l'indexation, faisait timeouter /health, le
# backend passait 'unhealthy' et le frontend (depends_on service_healthy)
# refusait de démarrer ("container migration-app-backend is unhealthy").
# =====================================================================
set -e

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; BLUE='\033[0;34m'; NC='\033[0m'
info()  { echo -e "${BLUE}[INFO]${NC} $1"; }
ok()    { echo -e "${GREEN}[OK]${NC} $1"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $1"; }
err()   { echo -e "${RED}[ERREUR]${NC} $1"; }

cd "$(dirname "$0")"

# --- Arguments ---
RUN_PRECHAUFFE=true
for a in "$@"; do
  case "$a" in
    --no-prechauffe|-n) RUN_PRECHAUFFE=false ;;
    -h|--help)
      echo "Usage: $0 [--no-prechauffe]"
      echo "  --no-prechauffe, -n   Déploie sans préchauffer/indexer les modèles IA."
      exit 0 ;;
    *) warn "Argument inconnu ignoré : $a" ;;
  esac
done

# --- Lecture d'une clé dans les .env (retire commentaire de fin + guillemets) ---
# Cherche d'abord backend/.env (clés AI_*), puis le .env racine (clés DB_*,
# utilisées par docker-compose). Premier fichier où la clé est non vide gagne.
# -> le mot de passe DB est lu automatiquement, jamais saisi à la main.
read_env() {
  local key="$1" f v
  for f in backend/.env .env; do
    [ -f "$f" ] || continue
    v=$(grep -E "^${key}=" "$f" 2>/dev/null | head -1 \
        | sed -E "s/^${key}=//; s/[[:space:]]+#.*\$//; s/^\"//; s/\"\$//; s/[[:space:]]+\$//")
    if [ -n "$v" ]; then printf '%s' "$v"; return 0; fi
  done
  return 0
}

# --- Attente que le backend soit 'healthy' (dépendance du frontend) ---
# Le frontend a `depends_on: backend: condition: service_healthy` : tant que le
# backend n'est pas 'healthy', `docker-compose up frontend` échoue. On attend
# donc explicitement avant de déployer le frontend.
wait_backend_healthy() {
  local max="${1:-24}" i=1 st   # 24 * 5s = 2 min
  info "Attente que le backend soit 'healthy' (dépendance du frontend)…"
  while [ "$i" -le "$max" ]; do
    st=$(docker inspect -f '{{.State.Health.Status}}' migration-app-backend 2>/dev/null || echo unknown)
    case "$st" in
      healthy)   ok "Backend 'healthy' (après $((i*5))s)."; return 0 ;;
      unhealthy) warn "Backend 'unhealthy' (voir: docker logs migration-app-backend). On poursuit malgré tout." ; return 1 ;;
    esac
    sleep 5; i=$((i+1))
  done
  warn "Backend toujours pas 'healthy' après $((max*5))s (statut='$st'). On poursuit — le frontend peut échouer."
  return 1
}

# ---------------------------------------------------------------------
# 1. Vérification .env (le seul réglage non couvert par les défauts du code)
# ---------------------------------------------------------------------
info "=== 1/5 Vérification backend/.env ==="
TO="$(read_env AI_TIMEOUT_SECONDS)"
if [ "$TO" != "0" ]; then
  warn "AI_TIMEOUT_SECONDS='$TO' (attendu 0 = aucun délai imparti). Pensez à l'éditer."
else
  ok "AI_TIMEOUT_SECONDS=0."
fi
# (AI_COT_ENABLED / AI_KNOWLEDGE_ENABLED / AI_KG_ENABLED défaut=true dans le code.)

# ---------------------------------------------------------------------
# 2. Migrations 017 (KG + cards), 018 (feedback + co-occurrences), 019 (config)
# ---------------------------------------------------------------------
info "=== 2/5 Migrations 017 + 018 + 019 ==="
DB_HOST="$(read_env DB_HOST)";   DB_PORT="$(read_env DB_PORT)"
DB_NAME="$(read_env DB_NAME)";   DB_USER="${PSQL_USER:-$(read_env DB_USER)}"
DB_PASS="${PSQL_PASSWORD:-$(read_env DB_PASSWORD)}"
: "${DB_HOST:=10.190.100.58}"; : "${DB_PORT:=5432}"; : "${DB_NAME:=sap_migration_db}"; : "${DB_USER:=postgres}"
if [ -z "$DB_PASS" ]; then
  warn "DB_PASSWORD introuvable dans backend/.env ni .env — ajoutez DB_PASSWORD=... au .env racine (sinon psql échouera sans jamais demander de mot de passe)."
fi
if command -v psql >/dev/null 2>&1; then
  for M in migrations/017_create_ai_kg_and_knowledge.sql \
           migrations/018_create_ai_feedback_cooccurrence.sql \
           migrations/019_create_ai_config_editable.sql; do
    if PGPASSWORD="$DB_PASS" psql -w -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" \
          -v ON_ERROR_STOP=1 -f "$M"; then
      ok "Migration appliquée : $M"
    else
      warn "Migration $M en échec (droits ?). Réessayez : PSQL_USER=postgres ./deploy_all.sh"
    fi
  done
else
  warn "psql introuvable sur l'hôte. Jouez migrations/017_*, 018_* et 019_* manuellement."
fi

# ---------------------------------------------------------------------
# 3. Backend (rebuild + recreate forcé : recharge code + env) + seed config
# ---------------------------------------------------------------------
info "=== 3/5 Déploiement backend ==="
./deploybackend.sh
ok "Backend déployé."

# Seed de la config IA éditable (idempotent : ne fait rien si déjà peuplé)
info "Seed config IA éditable (ai_domain_tables / ai_packs)…"
docker-compose exec -T backend python seed_ai_config.py \
  || warn "seed_ai_config échoué (migration 019 jouée ?)"

# ---------------------------------------------------------------------
# 4. Frontend + tests (backend doit être 'healthy' AVANT le frontend)
# ---------------------------------------------------------------------
info "=== 4/5 Frontend + tests ==="
wait_backend_healthy || true
if [ -f ./deployfrontend.sh ]; then
  ./deployfrontend.sh && ok "Frontend déployé." || warn "deployfrontend.sh en échec."
else
  warn "deployfrontend.sh absent — frontend non déployé."
fi

if docker-compose exec -T backend pytest tests/test_skills.py tests/test_knowledge.py -q -p no:cacheprovider; then
  ok "Tests packs + knowledge OK."
else
  warn "Des tests ont échoué — vérifiez la sortie ci-dessus."
fi

# ---------------------------------------------------------------------
# 5. Préchauffage des modèles + indexation des cards (HORS chemin critique)
# ---------------------------------------------------------------------
# Délégué à ./prechauffe_ia.sh : lent (CPU saturé), lancé EN DERNIER une fois
# backend + frontend en ligne, pour ne plus faire flapper /health ni bloquer le
# frontend. Ré-exécutable seul à tout moment après un redémarrage.
info "=== 5/5 Préchauffage & indexation IA ==="
if [ "$RUN_PRECHAUFFE" != true ]; then
  warn "Préchauffage ignoré (--no-prechauffe). Lancez-le plus tard : ./prechauffe_ia.sh"
elif [ -f ./prechauffe_ia.sh ]; then
  ./prechauffe_ia.sh || warn "prechauffe_ia.sh en échec — relançable seul : ./prechauffe_ia.sh"
else
  warn "prechauffe_ia.sh absent — préchauffage/index non effectués."
fi

echo ""
ok "=== Déploiement complet terminé ==="
info "Astuce : après le préchauffage, laisser l'assistant ~8-10 min sans le spammer (keep-warm)."
info "Pour re-préchauffer seul après un redémarrage : ./prechauffe_ia.sh"
