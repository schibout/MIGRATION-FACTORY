#!/bin/bash
# =====================================================================
# deploy.sh — Redéploiement incrémental depuis GitHub.
# À exécuter SUR LE SERVEUR (10.190.100.58), à la racine du dépôt.
#
#   ssh user@10.190.100.58 'cd /chemin/migration-Factory && ./deploy.sh'
#   ou, une fois connecté au serveur :  ./deploy.sh
#
# Workflow :
#   1. git pull (fast-forward) de la branche courante.
#   2. Analyse du diff (ancien HEAD -> nouveau HEAD).
#   3. Par service, on décide :
#        - REBUILD  (docker-compose build + up --force-recreate)
#             si dépendances/Dockerfile modifiés (requirements.txt, package.json…)
#        - RESTART  (docker-compose up -d --force-recreate, SANS rebuild)
#             si seul le code a changé — le code est monté en volume
#             (./backend:/app, ./frontend:/workspace/frontend), une recréation
#             suffit à recharger le code Python / relire le code servi par Vite.
#   Redis n'est jamais redéployé (image officielle, aucun code applicatif).
#
# Options :
#   --build          Forcer le REBUILD des deux services (ignore le diff).
#   --force          Déployer même si aucun nouveau commit (pull no-op).
#   --no-pull        Ne pas faire de git pull (déployer l'état local courant).
#   -h, --help       Aide.
#
# Idempotent : ré-exécutable sans risque.
# NB : les .env (serveur, gitignorés) ne sont pas touchés par le pull.
# =====================================================================
set -euo pipefail

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; BLUE='\033[0;34m'; NC='\033[0m'
info() { echo -e "${BLUE}[INFO]${NC} $1"; }
ok()   { echo -e "${GREEN}[OK]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
err()  { echo -e "${RED}[ERREUR]${NC} $1"; }

cd "$(dirname "$0")"

# --- docker compose : supporte le plugin v2 (`docker compose`) et le binaire v1 ---
if docker compose version >/dev/null 2>&1; then
  DC="docker compose"
elif command -v docker-compose >/dev/null 2>&1; then
  DC="docker-compose"
else
  err "Ni 'docker compose' ni 'docker-compose' trouvé. Installez Docker Compose."
  exit 1
fi

# --- Arguments ---
FORCE_BUILD=false
FORCE_DEPLOY=false
DO_PULL=true
for a in "$@"; do
  case "$a" in
    --build)   FORCE_BUILD=true ;;
    --force)   FORCE_DEPLOY=true ;;
    --no-pull) DO_PULL=false ;;
    -h|--help)
      sed -n '2,40p' "$0" | sed 's/^# \{0,1\}//'
      exit 0 ;;
    *) warn "Argument inconnu ignoré : $a" ;;
  esac
done

# ---------------------------------------------------------------------
# 1. git pull (fast-forward uniquement)
# ---------------------------------------------------------------------
BRANCH=$(git rev-parse --abbrev-ref HEAD)
BEFORE=$(git rev-parse HEAD)
info "=== 1/3 Mise à jour du code (branche '$BRANCH') ==="

if [ "$DO_PULL" = true ]; then
  # --ff-only : échoue franchement si la branche a divergé (ex. commits locaux
  # sur le serveur) plutôt que de créer un merge silencieux. Un serveur de déploiement
  # ne doit contenir que du code venu de GitHub.
  if ! git pull --ff-only; then
    err "git pull --ff-only a échoué (branche divergée ou conflit)."
    err "Le serveur a-t-il des commits/modifs locaux ? Résolvez à la main puis relancez."
    exit 1
  fi
else
  warn "git pull ignoré (--no-pull) : déploiement de l'état local courant."
fi

AFTER=$(git rev-parse HEAD)

if [ "$BEFORE" = "$AFTER" ] && [ "$FORCE_DEPLOY" != true ] && [ "$FORCE_BUILD" != true ]; then
  ok "Aucun nouveau commit — rien à redéployer."
  info "Forcer quand même : ./deploy.sh --force  (ou --build pour reconstruire)."
  exit 0
fi

if [ "$BEFORE" = "$AFTER" ]; then
  warn "Aucun nouveau commit, mais déploiement forcé demandé."
  # Sans diff exploitable : on redéploie les deux services par sécurité.
  CHANGED=""
else
  info "$BEFORE -> $AFTER"
  CHANGED=$(git diff --name-only "$BEFORE" "$AFTER")
  echo "$CHANGED" | sed 's/^/    /'
fi

# ---------------------------------------------------------------------
# 2. Décision : quoi redéployer, et en rebuild ou en restart ?
# ---------------------------------------------------------------------
info "=== 2/3 Analyse des changements ==="

# Helper : le diff contient-il au moins un chemin matchant le motif regex ?
matches() { echo "$CHANGED" | grep -qE "$1"; }

BACKEND_ACTION="none"    # none | restart | rebuild
FRONTEND_ACTION="none"

if [ "$FORCE_BUILD" = true ] || [ -z "$CHANGED" ]; then
  # --build, ou déploiement forcé sans diff : on reconstruit tout.
  BACKEND_ACTION="rebuild"
  FRONTEND_ACTION="rebuild"
else
  # docker-compose.yml : touche la définition des deux services -> recréer les deux.
  COMPOSE_CHANGED=false
  matches '^docker-compose\.ya?ml$' && COMPOSE_CHANGED=true

  # --- Backend ---
  if matches '^backend/'; then
    if matches '^backend/(requirements\.txt|Dockerfile)$'; then
      BACKEND_ACTION="rebuild"   # dépendances Python / image modifiées
    else
      BACKEND_ACTION="restart"   # code seul (monté en volume)
    fi
  fi

  # --- Frontend ---
  if matches '^frontend/'; then
    if matches '^frontend/(package(-lock)?\.json|Dockerfile)$'; then
      FRONTEND_ACTION="rebuild"  # dépendances npm / image modifiées
    else
      FRONTEND_ACTION="restart"  # code seul (servi depuis le volume par Vite)
    fi
  fi

  # Un changement de compose force au minimum une recréation des deux services.
  if [ "$COMPOSE_CHANGED" = true ]; then
    [ "$BACKEND_ACTION" = "none" ]  && BACKEND_ACTION="restart"
    [ "$FRONTEND_ACTION" = "none" ] && FRONTEND_ACTION="restart"
    info "docker-compose.yml modifié -> recréation des services concernés."
  fi

  # Migrations SQL : jamais jouées automatiquement (risque). On alerte seulement.
  if matches '^migrations/'; then
    warn "Des migrations ont changé — À JOUER MANUELLEMENT (non automatisé ici) :"
    echo "$CHANGED" | grep -E '^migrations/' | sed 's/^/    /'
    warn "Ex. : PGPASSWORD=... psql -h 10.190.100.58 -U postgres -d sap_migration_db -f migrations/XXX.sql"
  fi
fi

info "Backend : $BACKEND_ACTION | Frontend : $FRONTEND_ACTION"
if [ "$BACKEND_ACTION" = "none" ] && [ "$FRONTEND_ACTION" = "none" ]; then
  ok "Aucun service à redéployer (changements hors backend/frontend/compose)."
  exit 0
fi

# ---------------------------------------------------------------------
# 3. Déploiement
# ---------------------------------------------------------------------
info "=== 3/3 Redéploiement ==="

deploy_service() {
  local service="$1" action="$2" container="$3" extra="${4:-}"
  case "$action" in
    rebuild)
      info "[$service] REBUILD (dépendances/Dockerfile ou --build)…"
      $DC build "$service"
      # --force-recreate : indispensable car le code est monté en volume ; sans
      # recréation, un conteneur en cours ne recharge ni le code ni le .env à jour.
      $DC up -d --force-recreate $extra "$service"
      ;;
    restart)
      info "[$service] RESTART (code seul, pas de rebuild)…"
      $DC up -d --force-recreate $extra "$service"
      ;;
    none) return 0 ;;
  esac
  sleep 5
  if docker ps -q -f "name=$container" | grep -q .; then
    ok "[$service] conteneur en cours d'exécution ($container)."
  else
    err "[$service] le conteneur n'a pas démarré. Logs :"
    docker logs --tail 40 "$container" 2>&1 || true
    return 1
  fi
}

# Backend d'abord (le frontend en dépend via depends_on: service_healthy).
deploy_service backend "$BACKEND_ACTION" migration-app-backend

# --no-deps sur le frontend : ne pas revalider la santé du backend (il chauffe
# Ollama sur CPU au boot et peut passer 'unhealthy' quelques instants -> sinon
# docker-compose refuse de recréer le frontend). Cf. deployfrontend.sh.
deploy_service frontend "$FRONTEND_ACTION" migration-app-frontend --no-deps

echo ""
ok "=== Déploiement terminé ==="
info "Logs backend  : docker logs -f migration-app-backend"
info "Logs frontend : docker logs -f migration-app-frontend"
info "Frontend      : http://10.190.100.58:3000"
