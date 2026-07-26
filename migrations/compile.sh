#!/bin/bash

# Script d'installation de TOUTES les migrations SQL (dans l'ordre numérique).
# Les migrations sont idempotentes (CREATE ... IF NOT EXISTS / ADD COLUMN IF NOT EXISTS)
# -> ce script est ré-exécutable sans risque.
#
# Usage :
#   chmod +x compile.sh && ./compile.sh
#
# Surcharge possible par variables d'environnement (sinon valeurs par défaut) :
#   DB_HOST DB_PORT DB_NAME PGUSER PGPASSWORD
#   ex. PGUSER=postgres PGPASSWORD=secret ./compile.sh

# Charger les variables depuis .profile (cohérent avec les autres compile.sh)
if [ -f ~/.profile ]; then
    source ~/.profile
fi

# Configuration de la connexion PostgreSQL (surchargée par l'environnement si défini)
DB_HOST="${DB_HOST:-10.190.100.58}"
DB_PORT="${DB_PORT:-5432}"
DB_NAME="${DB_NAME:-sap_migration_db}"
DB_USER="${PGUSER:-postgres}"
DB_PASSWORD="${PGPASSWORD:-trimet2025}"

# Couleurs
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info()    { echo -e "${GREEN}[INFO]${NC} $1"; }
log_error()   { echo -e "${RED}[ERROR]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }

# Répertoire du script (pour trouver les .sql quel que soit le cwd)
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Exécute un fichier SQL. ON_ERROR_STOP=1 : la moindre erreur SQL fait échouer le fichier.
execute_sql() {
    local file="$1"
    local filename
    filename="$(basename "$file")"

    log_info "Installation de $filename..."
    export PGPASSWORD="$DB_PASSWORD"

    if psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" \
            -v ON_ERROR_STOP=1 -f "$file" > /dev/null 2>&1; then
        log_info "✅ $filename installé"
        return 0
    else
        log_error "❌ Échec de $filename — détail :"
        psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" \
             -v ON_ERROR_STOP=1 -f "$file"
        return 1
    fi
}

echo "=========================================="
echo "  Installation des migrations SQL"
echo "=========================================="
echo ""
log_info "Connexion: $DB_USER@$DB_HOST:$DB_PORT/$DB_NAME"
echo ""

# Toutes les migrations *.sql dans l'ordre numérique (003_, 004_, ... 019_).
# Le tri lexical suffit grâce au préfixe numérique zéro-paddé.
shopt -s nullglob
files=$(ls "$SCRIPT_DIR"/*.sql 2>/dev/null | sort)

if [ -z "$files" ]; then
    log_error "Aucun fichier .sql trouvé dans $SCRIPT_DIR"
    exit 1
fi

errors=0
count=0
for file in $files; do
    count=$((count + 1))
    execute_sql "$file" || errors=$((errors + 1))
    echo ""
done

echo "=========================================="
if [ "$errors" -eq 0 ]; then
    log_info "✅ $count migration(s) installée(s) avec succès."
    exit 0
else
    log_error "❌ $errors erreur(s) sur $count migration(s)."
    exit 1
fi
