#!/bin/bash
#
# Exporte les procedures stockees de TOUS les modules, depuis la base vers les
# fichiers .sql de chaque dossier. C'est la base qui fait foi : les fichiers du
# depot derivent et doivent etre rafraichis avant toute analyse ou recompilation.
#
# Les dossiers sont DECOUVERTS automatiquement (sql/*/export_procedures.sh) :
# aucune liste figee ici, sinon ce script se perimerait a son tour -- c'est
# exactement le defaut qui avait laisse 26 routines hors de tout export.
#
# Usage :
#   bash sql/export_procedure_all.sh                  # tous les modules
#   bash sql/export_procedure_all.sh supplier customer  # modules choisis
#   bash sql/export_procedure_all.sh --list           # liste sans rien executer
#
# ATTENTION : les fichiers .sql des dossiers traites sont ECRASES par les
# definitions reelles de la base. Committer avant, puis relire `git diff` pour
# mesurer l'ecart entre le depot et la production.

RACINE_SQL="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

GREEN='\033[0;32m'; RED='\033[0;31m'; YELLOW='\033[1;33m'; NC='\033[0m'
log_info()    { echo -e "${GREEN}[INFO]${NC} $1"; }
log_error()   { echo -e "${RED}[ERROR]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }

# --- Decouverte des modules -------------------------------------------------
modules=()
for script in "$RACINE_SQL"/*/export_procedures.sh; do
    [ -f "$script" ] || continue
    modules+=("$(basename "$(dirname "$script")")")
done

if [ ${#modules[@]} -eq 0 ]; then
    log_error "Aucun export_procedures.sh trouve sous $RACINE_SQL"
    exit 1
fi

# --- Arguments --------------------------------------------------------------
if [ "$1" = "--list" ]; then
    echo "Modules exportables (${#modules[@]}) :"
    printf '   %s\n' "${modules[@]}"
    exit 0
fi

if [ $# -gt 0 ]; then
    demandes=()
    for demande in "$@"; do
        trouve=0
        for module in "${modules[@]}"; do
            [ "$module" = "$demande" ] && trouve=1 && break
        done
        if [ $trouve -eq 0 ]; then
            log_error "Module inconnu : $demande"
            echo "Modules disponibles : ${modules[*]}"
            exit 1
        fi
        demandes+=("$demande")
    done
    modules=("${demandes[@]}")
fi

# --- Execution --------------------------------------------------------------
echo "=========================================="
echo "  Export des procedures - TOUS LES MODULES"
echo "=========================================="
log_info "${#modules[@]} module(s) : ${modules[*]}"
echo ""

total_ok=0
total_ko=0
resume=()

for module in "${modules[@]}"; do
    echo "------------------------------------------"
    log_info "Module $module"
    echo "------------------------------------------"

    # Les scripts enfants utilisent des chemins relatifs : se placer dans leur dossier.
    sortie=$(cd "$RACINE_SQL/$module" && bash export_procedures.sh 2>&1)
    echo "$sortie"

    # Les scripts enfants renvoient TOUJOURS 0, meme quand chaque export echoue :
    # le seul signal fiable est le marqueur qu'ils impriment. Leurs libelles
    # different d'un module a l'autre ("Erreur lors de l'export" ici, "non trouvee
    # dans le schema" ailleurs, avec ou sans accents), on compte donc les marqueurs
    # eux-memes plutot que le texte.
    # Le succes est filtre sur ".sql" pour ne compter que les lignes par fichier et
    # ignorer la ligne de resume finale, qui porte aussi un ✅.
    ok=$(echo "$sortie" | grep -c "✅.*\.sql")
    ko=$(echo "$sortie" | grep -cE "❌|⚠")

    total_ok=$((total_ok + ok))
    total_ko=$((total_ko + ko))
    resume+=("$(printf '%-24s %3d exportees  %3d en echec' "$module" "$ok" "$ko")")
    echo ""
done

# --- Resume -----------------------------------------------------------------
echo "=========================================="
echo "  RESUME"
echo "=========================================="
printf '%s\n' "${resume[@]}"
echo "------------------------------------------"
log_info "Total exporte : $total_ok"

if [ "$total_ko" -gt 0 ]; then
    log_error "Total en echec : $total_ko"
    log_warning "Verifier la connexion PostgreSQL et que les procedures listees existent"
    log_warning "encore en base : une entree obsolete dans un export_procedures.sh"
    log_warning "produit exactement ce symptome."
    exit 1
fi

if [ "$total_ok" -eq 0 ]; then
    log_error "Aucune procedure exportee : connexion a la base probablement impossible"
    exit 1
fi

log_info "Tous les exports ont reussi"
log_warning "Les fichiers .sql ont ete ecrases : relire 'git diff' avant de committer"
exit 0
