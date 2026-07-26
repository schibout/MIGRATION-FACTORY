#!/bin/bash
# =====================================================================
# prechauffe_ia.sh — Préchauffage des modèles IA + indexation des cards.
# À exécuter SUR LE SERVEUR (10.190.100.58), à la racine du dépôt,
# APRÈS un déploiement (backend + frontend up) :
#
#   ./prechauffe_ia.sh
#
# POURQUOI un exécutable séparé (extrait de deploy_all.sh) :
#   Cette étape est LENTE (modèles CPU « à froid », ~8-10 min) et SATURE le CPU
#   du serveur. Laissée dans le chemin critique du déploiement, elle faisait
#   « flapper » le healthcheck du backend (/health en timeout), ce qui faisait
#   ÉCHOUER le déploiement du frontend (depends_on: backend service_healthy).
#   En la sortant ici, on la lance une fois backend + frontend déjà en ligne :
#   un éventuel flap n'a plus aucun impact sur les conteneurs déjà démarrés.
#
# SÉQUENCE (l'ordre compte) :
#   1. Préchauffe des modèles LOCAUX encore utilisés (prechauffe_ollama.py) :
#      - embeddings bge-m3 en RAM (TOUJOURS local : indexation cards + RAG) ;
#      - modèle de génération qwen2.5-coder:7b UNIQUEMENT si AI_PROVIDER=ollama.
#        Avec AI_PROVIDER=openai (génération déléguée au modèle EXTERNE), cette
#        passe est automatiquement sautée — seuls les embeddings sont chauffés.
#   2. Indexe les knowledge cards avec le modèle d'embeddings DÉJÀ chaud
#      (build_ai_index.py) -> plus de timeouts « modèle en chauffe » : les 71
#      cards sont indexées (l'ordre inverse en manquait ~3 à froid).
#
# ⚠️ En génération LOCALE : après ce préchauffage, laisser l'assistant tranquille
#    ~8-10 min (chaque /ask annule le keep-warm en vol ; ne pas spammer
#    « réessayer » sur un 1er timeout). En génération EXTERNE, ce délai ne
#    s'applique pas à la génération (seuls les embeddings locaux sont concernés).
#
# Idempotent : ré-exécutable sans risque (warmup sans effet de bord, index = upsert).
# =====================================================================
set -e

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; BLUE='\033[0;34m'; NC='\033[0m'
info()  { echo -e "${BLUE}[INFO]${NC} $1"; }
ok()    { echo -e "${GREEN}[OK]${NC} $1"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $1"; }
err()   { echo -e "${RED}[ERREUR]${NC} $1"; }

cd "$(dirname "$0")"

# ---------------------------------------------------------------------
# 1. Préchauffage des modèles (génération + embeddings)
# ---------------------------------------------------------------------
info "=== 1/2 Préchauffage des modèles locaux (embeddings bge-m3 ; génération qwen si AI_PROVIDER=ollama) ==="
info "1er appel à froid : chargement RAM du/des modèle(s) (~8 min possibles). Patience."
if docker-compose exec -T backend python prechauffe_ollama.py; then
  ok "Modèles locaux chauds (la passe génération est sautée si le fournisseur est externe)."
else
  warn "Préchauffage échoué (Ollama injoignable ? modèle bge-m3 pull ?). L'indexation ci-dessous risque de timeouter à froid."
fi

# ---------------------------------------------------------------------
# 2. Indexation des knowledge cards (modèle d'embeddings désormais chaud)
# ---------------------------------------------------------------------
info "=== 2/2 Indexation des knowledge cards ==="
if docker-compose exec -T backend python build_ai_index.py --only knowledge; then
  ok "Cards indexées (embeddings chauds -> plus de card ignorée pour cause de timeout)."
else
  warn "Indexation cards échouée (migration 017 jouée ? Ollama bge-m3 dispo ?). Les cards fonctionnent en lexical sans index."
fi

echo ""
ok "=== Préchauffage IA terminé ==="
info "Laissez l'assistant tranquille ~8-10 min : le keep-warm garde le SOCLE en cache KV."
