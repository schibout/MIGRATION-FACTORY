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
#             si la config d'IMAGE a changé : requirements.txt, package.json,
#             Dockerfile, .dockerignore, docker-compose.yml.
#        - RESTART  (docker-compose up -d --force-recreate, SANS rebuild)
#             si seul le code ou la config d'EXÉCUTION a changé — tout est monté
#             en volume (./backend:/app, ./frontend:/workspace/frontend), une
#             recréation suffit à recharger le code Python / le code servi par Vite.
#   Redis n'est jamais redéployé (image officielle, aucun code applicatif).
#   Hors périmètre, signalés mais jamais appliqués : migrations/ et nginx/
#   (nginx tourne sur l'hôte, pas dans docker-compose).
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
# Helper : lister les chemins du diff qui matchent (pour tracer la décision).
matched_files() { echo "$CHANGED" | grep -E "$1" | sed 's/^/    /'; }

# --- Fichiers de configuration : deux familles, deux traitements ---
# Toute la config n'exige pas un rebuild, parce que le code ET sa config vivent
# dans un volume monté (./backend:/app, ./frontend:/workspace/frontend) :
#
#   * config d'IMAGE -> REBUILD. Elle est cuite dans l'image (dépendances
#     installées, Dockerfile) ou dans la définition du service
#     (docker-compose.yml) : seul un build/une recréation la prend en compte.
#   * config d'EXÉCUTION -> RESTART. Elle est lue au démarrage du process depuis
#     le volume (vite.config.ts, tsconfig*.json, backend/config/*.py) :
#     reconstruire l'image ne changerait rien de plus qu'un redémarrage.
#
# docker-compose.yml est classé côté image pour les DEUX services : il porte le
# bloc build: autant que les variables d'environnement et les volumes.
IMAGE_CFG_BACKEND='^(backend/(requirements[^/]*\.txt|Dockerfile)|\.dockerignore|docker-compose\.ya?ml)$'
IMAGE_CFG_FRONTEND='^(frontend/(package(-lock)?\.json|Dockerfile)|\.dockerignore|docker-compose\.ya?ml)$'
RUNTIME_CFG='^(frontend/(vite\.config\.[jt]s|tsconfig[^/]*\.json)|backend/config/.*\.py)$'

BACKEND_ACTION="none"    # none | restart | rebuild
FRONTEND_ACTION="none"

if [ "$FORCE_BUILD" = true ] || [ -z "$CHANGED" ]; then
  # --build, ou déploiement forcé sans diff : on reconstruit tout.
  BACKEND_ACTION="rebuild"
  FRONTEND_ACTION="rebuild"
else
  # --- Backend ---
  if matches "$IMAGE_CFG_BACKEND"; then
    BACKEND_ACTION="rebuild"     # dépendances Python / image / définition du service
    info "[backend] config d'image modifiée -> REBUILD :"
    matched_files "$IMAGE_CFG_BACKEND"
  elif matches '^backend/'; then
    BACKEND_ACTION="restart"     # code ou config d'exécution (montés en volume)
  fi

  # --- Frontend ---
  if matches "$IMAGE_CFG_FRONTEND"; then
    FRONTEND_ACTION="rebuild"    # dépendances npm / image / définition du service
    info "[frontend] config d'image modifiée -> REBUILD :"
    matched_files "$IMAGE_CFG_FRONTEND"
  elif matches '^frontend/'; then
    FRONTEND_ACTION="restart"    # code ou config d'exécution (servis depuis le volume)
  fi

  # Trace : une config d'exécution a changé, un simple restart la recharge.
  if matches "$RUNTIME_CFG"; then
    info "Config d'exécution modifiée (relue au démarrage, pas de rebuild nécessaire) :"
    matched_files "$RUNTIME_CFG"
  fi

  # Nginx tourne sur l'HÔTE, pas dans docker-compose : hors de portée de ce script.
  if matches '^nginx/'; then
    warn "Config nginx modifiée — À APPLIQUER MANUELLEMENT SUR L'HÔTE :"
    matched_files '^nginx/'
    warn "Ex. : sudo cp nginx/<fichier>.conf /etc/nginx/conf.d/ && sudo nginx -t && sudo nginx -s reload"
  fi

  # Migrations SQL : jamais jouées automatiquement (risque). On alerte seulement.
  if matches '^migrations/'; then
    warn "Des migrations ont changé — À JOUER MANUELLEMENT (non automatisé ici) :"
    matched_files '^migrations/'
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
info "Application   : http://10.190.100.58:8081/  (nginx ; portail d’accueil sur 80, 3000 et 8080)"
