#!/bin/bash
# =====================================================================
# cron_ai_maintenance.sh — Maintenance périodique de l'Assistant IA.
# À appeler par cron sur le serveur. Exécute dans le conteneur backend :
#   1. build_cooccurrence.py  -> alimente le Knowledge Graph (tables co-utilisées)
#   2. mine_query_log.py      -> exporte les candidats few-shot (pour revue humaine)
#
# Installation (crontab) — tous les lundis à 03h00 :
#   crontab -e
#   0 3 * * 1  /CHEMIN/migration-Factory/cron_ai_maintenance.sh
#
# Les pouces-haut (👍) deviennent des few-shots VIVANTS immédiatement (sans ce cron) ;
# ce script sert au signal d'usage (co-occurrences) et à la curation du dataset.
# =====================================================================
cd "$(dirname "$0")" || exit 1
LOG="${AI_CRON_LOG:-./ai_maintenance.log}"

{
  echo "===== $(date '+%F %T') — maintenance IA ====="

  echo "[1/2] Co-occurrences de tables (Knowledge Graph)…"
  docker-compose exec -T backend python build_cooccurrence.py \
    || echo "[WARN] build_cooccurrence a échoué"

  echo "[2/2] Export des candidats few-shot…"
  docker-compose exec -T backend python mine_query_log.py --limit 500 \
    || echo "[WARN] mine_query_log a échoué"

  echo "----- terminé -----"
} >> "$LOG" 2>&1
