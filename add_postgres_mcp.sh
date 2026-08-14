#!/usr/bin/env bash
#
# add_postgres_mcp.sh — Ajoute le serveur MCP PostgreSQL à l'agent Hermes (Docker)
#
# Écrit l'entrée `mcp_servers.postgres` dans la config Hermes
# (/opt/data/config.yaml = ~/.hermes/config.yaml côté hôte).
#
# IMPORTANT : Hermes réécrit sa config à l'arrêt. Éditer le fichier pendant que
# le gateway tourne puis redémarrer ferait perdre l'ajout. Ce script édite donc
# la config **gateway arrêté** (dans un conteneur jetable), puis redémarre.
#
# Le serveur MCP utilisé est @modelcontextprotocol/server-postgres (via npx),
# identique à celui employé côté Claude. Node 22 est présent dans l'image Hermes,
# et grâce à network_mode: host le conteneur joint 10.190.100.58:5432.
#
# Usage (sur le serveur, depuis ~/hermes) — le MOT DE PASSE doit être fourni,
# il n'est jamais codé en dur dans ce script :
#
#   chmod +x add_postgres_mcp.sh
#   PGPASSWORD='monMotDePasse' ./add_postgres_mcp.sh
#   # ou en fournissant l'URL complète :
#   PG_URL='postgresql://postgres:monMotDePasse@10.190.100.58:5432/sap_migration_db' ./add_postgres_mcp.sh
#
# Variables :
#   PG_URL             URL de connexion complète (prioritaire si fournie)
#   PGPASSWORD         mot de passe (OBLIGATOIRE si PG_URL absent)
#   PGHOST             hôte      (défaut : 10.190.100.58)
#   PGPORT             port      (défaut : 5432)
#   PGUSER             user      (défaut : postgres)
#   PGDATABASE         base      (défaut : sap_migration_db)
#   HERMES_CONTAINER   nom du conteneur gateway     (défaut : hermes)
#   HERMES_COMPOSE     chemin du docker-compose.yml (défaut : ~/hermes/hermes-agent/docker-compose.yml)

set -euo pipefail

# Éléments non sensibles : valeurs par défaut acceptables.
PG_HOST="${PGHOST:-10.190.100.58}"
PG_PORT="${PGPORT:-5432}"
PG_USER="${PGUSER:-postgres}"
PG_DB="${PGDATABASE:-sap_migration_db}"

# Le mot de passe n'est PAS stocké dans ce fichier : il doit venir de l'environnement.
PG_URL="${PG_URL:-}"
if [ -z "$PG_URL" ]; then
  if [ -z "${PGPASSWORD:-}" ]; then
    printf 'ERREUR : fournis la connexion PostgreSQL.\n' >&2
    printf "  PGPASSWORD='***' ./add_postgres_mcp.sh\n" >&2
    printf "  ou PG_URL='postgresql://user:***@host:5432/db' ./add_postgres_mcp.sh\n" >&2
    exit 1
  fi
  PG_URL="postgresql://${PG_USER}:${PGPASSWORD}@${PG_HOST}:${PG_PORT}/${PG_DB}"
fi

CONTAINER="${HERMES_CONTAINER:-hermes}"
COMPOSE_FILE="${HERMES_COMPOSE:-$HOME/hermes/hermes-agent/docker-compose.yml}"

# --- Log ---
if [ -t 1 ]; then
  C_RESET=$'\033[0m'; C_BLUE=$'\033[1;34m'; C_GREEN=$'\033[1;32m'
  C_YELLOW=$'\033[1;33m'; C_RED=$'\033[1;31m'
else
  C_RESET=""; C_BLUE=""; C_GREEN=""; C_YELLOW=""; C_RED=""
fi
info() { printf '%s[INFO]%s  %s\n'  "$C_BLUE"   "$C_RESET" "$*"; }
ok()   { printf '%s[OK]%s    %s\n'  "$C_GREEN"  "$C_RESET" "$*"; }
warn() { printf '%s[WARN]%s  %s\n'  "$C_YELLOW" "$C_RESET" "$*" >&2; }
die()  { printf '%s[ERREUR]%s %s\n' "$C_RED"    "$C_RESET" "$*" >&2; exit 1; }

command -v docker >/dev/null 2>&1 || die "Docker introuvable."
docker ps -a --format '{{.Names}}' | grep -qx "$CONTAINER" \
  || die "Le conteneur '$CONTAINER' n'existe pas. Lance d'abord ./docker_hermes.sh"

# --- Localise le volume de données et l'image (avant d'arrêter) ---
DATA_SRC="$(docker inspect -f '{{range .Mounts}}{{if eq .Destination "/opt/data"}}{{.Source}}{{end}}{{end}}' "$CONTAINER")"
[ -n "$DATA_SRC" ] || die "Impossible de localiser le volume monté sur /opt/data."
IMAGE="$(docker inspect -f '{{.Config.Image}}' "$CONTAINER")"
info "Volume de données : $DATA_SRC"
info "Image : $IMAGE"

# --- Arrêt des services (édition hors-ligne) ---
info "Arrêt des services (pour éviter que Hermes réécrase la config à l'arrêt)..."
docker compose -f "$COMPOSE_FILE" stop gateway dashboard

# --- Édition de la config dans un conteneur jetable ---
# On lance le python du venv Hermes (ruamel/yaml garantis) en root, en montant
# le même volume, et on restaure le propriétaire d'origine du fichier après écriture.
info "Ajout de mcp_servers.postgres dans config.yaml (hors-ligne)..."
docker run --rm -i --user 0:0 -e PG_URL="$PG_URL" \
  -v "$DATA_SRC:/opt/data" \
  --entrypoint /opt/hermes/.venv/bin/python3 "$IMAGE" - <<'PY'
import os, shutil

PATH = "/opt/data/config.yaml"
server = {
    "command": "npx",
    "args": ["-y", "@modelcontextprotocol/server-postgres", os.environ["PG_URL"]],
    "env": {},
    "enabled": True,
    "timeout": 120,
    "tools": {"resources": True, "prompts": False},
}

uid = gid = None
if os.path.exists(PATH):
    st = os.stat(PATH)
    uid, gid = st.st_uid, st.st_gid
    shutil.copy2(PATH, PATH + ".bak")

lib = None
try:
    from ruamel.yaml import YAML
    y = YAML()
    y.preserve_quotes = True
    data = None
    if os.path.exists(PATH):
        with open(PATH) as f:
            data = y.load(f)
    if data is None:
        data = {}
    if data.get("mcp_servers") is None:
        data["mcp_servers"] = {}
    data["mcp_servers"]["postgres"] = server
    with open(PATH, "w") as f:
        y.dump(data, f)
    lib = "ruamel"
except ImportError:
    import yaml
    data = {}
    if os.path.exists(PATH):
        with open(PATH) as f:
            data = yaml.safe_load(f) or {}
    if data.get("mcp_servers") is None:
        data["mcp_servers"] = {}
    data["mcp_servers"]["postgres"] = server
    with open(PATH, "w") as f:
        yaml.safe_dump(data, f, default_flow_style=False, sort_keys=False, allow_unicode=True)
    lib = "pyyaml"

# Restaure le propriétaire d'origine (sinon le service Hermes ne pourrait plus lire/écrire)
if uid is not None:
    try:
        os.chown(PATH, uid, gid)
        os.chown(PATH + ".bak", uid, gid)
    except PermissionError:
        pass

print(f"OK ({lib}): entree mcp_servers.postgres ecrite dans {PATH}")
PY
ok "Config mise à jour (hors-ligne)."

# --- Redémarrage ---
info "Redémarrage des services Hermes..."
docker compose -f "$COMPOSE_FILE" up -d

# --- Vérification ---
info "Vérification de la présence de l'entrée dans la config..."
if grep -q "postgres" "$DATA_SRC/config.yaml" 2>/dev/null; then
  ok "Entrée 'postgres' présente dans config.yaml."
else
  warn "Entrée 'postgres' introuvable dans $DATA_SRC/config.yaml — vérifie la sortie ci-dessus."
fi

echo
ok "Serveur MCP PostgreSQL ajouté à Hermes."
info "Base : ${PG_URL%%\?*}"
info "Outil exposé : mcp_postgres_query (+ ressources de schéma)."
info "Logs :   docker compose -f \"$COMPOSE_FILE\" logs --since 2m gateway | grep -i mcp"
warn "Le mot de passe figure en clair dans ~/.hermes/config.yaml (fonctionnement natif de Hermes)."
