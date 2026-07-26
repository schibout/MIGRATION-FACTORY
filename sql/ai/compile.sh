#!/bin/bash

# Script de livraison de la CONFIG de l'Assistant IA (RAG)
# Peuple public.ai_domain_tables et public.ai_packs avec la connaissance des
# tables cibles IFS (clean_data). Scripts idempotents : rejouables sans risque.

# Charger les variables depuis .profile
if [ -f ~/.profile ]; then
    source ~/.profile
fi

# Configuration de la connexion PostgreSQL.
# Le mot de passe n'est PAS code en dur : on le lit depuis l'environnement
# (DB_PASSWORD ou PGPASSWORD) ou depuis ~/.profile (source ci-dessus).
# Ex : export PGPASSWORD='...' ; ./compile.sh
DB_HOST="${DB_HOST:-10.190.100.58}"
DB_PORT="${DB_PORT:-5432}"
DB_NAME="${DB_NAME:-sap_migration_db}"
DB_USER="${DB_USER:-postgres}"
DB_PASSWORD="${DB_PASSWORD:-${PGPASSWORD:-}}"

if [ -z "$DB_PASSWORD" ]; then
    echo "[ERROR] Mot de passe DB absent. Faites : export PGPASSWORD='...' avant de lancer ./compile.sh" >&2
    exit 1
fi

# Couleurs pour les messages
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Fonction pour afficher les messages
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Fonction pour exécuter un fichier SQL
execute_sql() {
    local file=$1
    local filename=$(basename "$file")

    log_info "Compilation de $filename..."

    # Définir le mot de passe pour psql
    export PGPASSWORD="$DB_PASSWORD"

    if psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -f "$file" > /dev/null 2>&1; then
        log_info "✅ $filename compilé avec succès"
        return 0
    else
        log_error "❌ Erreur lors de la compilation de $filename"
        psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -f "$file"
        return 1
    fi
}

# Début du script
echo "=========================================="
echo "  Livraison CONFIG Assistant IA (clean_data)"
echo "=========================================="
echo ""
log_info "Connexion: $DB_USER@$DB_HOST:$DB_PORT/$DB_NAME"
echo ""

# Compteur d'erreurs
errors=0

# Liste des fichiers dans l'ordre d'exécution (domaines AVANT packs)
files=(
    "01_ifs_domain_tables.sql"
    "02_ifs_packs.sql"
)

# Exécution de chaque fichier
for file in "${files[@]}"; do
    if [ -f "$file" ]; then
        execute_sql "$file"
        if [ $? -ne 0 ]; then
            ((errors++))
        fi
    else
        log_warning "Fichier non trouvé: $file"
        ((errors++))
    fi
    echo ""
done

# Vérification post-insertion (compte des domaines / packs ifs_*)
if [ $errors -eq 0 ]; then
    export PGPASSWORD="$DB_PASSWORD"
    log_info "Vérification des objets IA insérés :"
    psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -t -c \
      "SELECT 'domaines ifs_* : ' || count(*) FROM public.ai_domain_tables WHERE domain_id LIKE 'ifs_%';
       SELECT 'packs ifs_*    : ' || count(*) FROM public.ai_packs WHERE domain LIKE 'ifs_%';"
    echo ""
fi

# Résumé
echo "=========================================="
if [ $errors -eq 0 ]; then
    log_info "✅ Config IA livrée avec succès!"
    log_warning "Effet immédiat sur la génération (cache 60 s). Pour le classement"
    log_warning "sémantique, réindexer (Ollama requis) :"
    echo "    docker-compose exec backend python build_ai_index.py --only tables"
    echo "    docker-compose exec backend python build_ai_index.py --only knowledge"
    exit 0
else
    log_error "❌ $errors erreur(s) détectée(s)"
    exit 1
fi
