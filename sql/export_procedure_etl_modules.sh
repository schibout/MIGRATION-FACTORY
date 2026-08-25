#!/bin/bash
#
# Exporte UNIQUEMENT les procedures/fonctions appelees par les modules Python
# backend/etl_modules/etl_*.py, depuis la base vers sql/etl_modules/<module_python>/.
#
# La liste n'est PAS figee : elle est extraite des sources Python a chaque
# execution (motif `clean_data.nom(` / `public.nom(` — la parenthese distingue
# un appel de routine d'un nom de table). Une routine appelee par plusieurs
# modules est exportee dans chaque dossier concerne.
#
# A lancer SUR LE SERVEUR (psql requis, l'export local corrompt les accents).
#
# Usage :
#   bash sql/export_procedure_etl_modules.sh            # tous les modules Python
#   bash sql/export_procedure_etl_modules.sh --list     # liste sans rien exporter
#
# ATTENTION : les fichiers de sql/etl_modules/ sont ECRASES par les definitions
# reelles de la base. Committer avant, puis relire `git diff`.

RACINE_SQL="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RACINE_DEPOT="$(dirname "$RACINE_SQL")"
DOSSIER_PY="$RACINE_DEPOT/backend/etl_modules"
DOSSIER_SORTIE="$RACINE_SQL/etl_modules"

DB_HOST="10.190.100.58"
DB_PORT="5432"
DB_NAME="sap_migration_db"
DB_USER="postgres"
DB_PASSWORD="trimet2025"
export PGPASSWORD="$DB_PASSWORD"

GREEN='\033[0;32m'; RED='\033[0;31m'; YELLOW='\033[1;33m'; NC='\033[0m'
log_info()    { echo -e "${GREEN}[INFO]${NC} $1"; }
log_error()   { echo -e "${RED}[ERROR]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }

if [ ! -d "$DOSSIER_PY" ]; then
    log_error "Dossier introuvable : $DOSSIER_PY"
    exit 1
fi

extraire_routines() {
    # Appels de routine du fichier Python : schema.nom( — parenthese obligatoire.
    grep -ohE "(clean_data|public)\.[a-zA-Z0-9_]+\(" "$1" | tr -d '(' | sort -u
}

if [ "$1" = "--list" ]; then
    for py in "$DOSSIER_PY"/etl_*.py; do
        module="$(basename "$py" .py)"
        echo "$module :"
        extraire_routines "$py" | sed 's/^/   /'
    done
    exit 0
fi

echo "=================================================="
echo "  Export des procedures appelees par etl_modules"
echo "=================================================="
log_info "Connexion: $DB_USER@$DB_HOST:$DB_PORT/$DB_NAME"
echo ""

total_ok=0
total_ko=0
resume=()

for py in "$DOSSIER_PY"/etl_*.py; do
    module="$(basename "$py" .py)"
    dossier="$DOSSIER_SORTIE/$module"
    mkdir -p "$dossier"

    echo "------------------------------------------"
    log_info "Module $module"
    echo "------------------------------------------"

    ok=0
    ko=0
    while IFS= read -r routine; do
        schema="${routine%%.*}"
        nom="${routine##*.}"
        fichier="$dossier/${nom}.sql"

        # Toutes les surcharges, pas de LIMIT 1 : une routine surchargee doit
        # etre recompilable entierement depuis son fichier.
        query="
        SELECT string_agg(pg_get_functiondef(p.oid), E'\n;\n' ORDER BY p.oid)
        FROM pg_proc p
        JOIN pg_namespace n ON p.pronamespace = n.oid
        WHERE n.nspname = '$schema'
          AND p.proname = '$nom';
        "
        result=$(psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -t -A -c "$query" 2>&1)

        if [ $? -eq 0 ] && [ -n "$result" ]; then
            echo "$result" > "$fichier"
            log_info "✅ $module/${nom}.sql"
            ((ok++))
        else
            log_error "❌ $routine introuvable en base (appelee par $module.py)"
            [ -n "$result" ] && echo "   $result"
            ((ko++))
        fi
    done < <(extraire_routines "$py")

    total_ok=$((total_ok + ok))
    total_ko=$((total_ko + ko))
    resume+=("$(printf '%-28s %3d exportees  %3d en echec' "$module" "$ok" "$ko")")
    echo ""
done

echo "=================================================="
echo "  RESUME"
echo "=================================================="
printf '%s\n' "${resume[@]}"
echo "--------------------------------------------------"
log_info "Total exporte : $total_ok"

if [ "$total_ko" -gt 0 ]; then
    log_error "Total en echec : $total_ko"
    log_warning "Une routine en echec est appelee par un etl_*.py mais absente de la"
    log_warning "base : soit elle a ete supprimee, soit le code Python est perime."
    exit 1
fi

if [ "$total_ok" -eq 0 ]; then
    log_error "Aucune routine exportee : connexion a la base probablement impossible"
    exit 1
fi

log_info "Tous les exports ont reussi"
log_warning "Les fichiers de sql/etl_modules/ ont ete ecrases : relire 'git diff' avant de committer"
exit 0
