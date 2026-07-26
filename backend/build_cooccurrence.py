# -*- coding: utf-8 -*-
"""
build_cooccurrence — Alimente public.ai_table_cooccurrence à partir de l'usage.

Parcourt les requêtes RÉUSSIES de ai_query_log, extrait les tables schéma-qualifiées
de chaque SQL, et compte combien de fois chaque PAIRE de tables apparaît ensemble.
Ces co-occurrences complètent les FK DDIC dans le sous-graphe de jointures
(ai_knowledge_graph) : elles capturent les jointures « métier » réellement utilisées
mais non déclarées comme check_table dans le dictionnaire.

Reconstruction complète à chaque exécution (TRUNCATE + INSERT) -> idempotent.
À lancer périodiquement (cf. cron) dans le conteneur backend :
    docker-compose exec backend python build_cooccurrence.py
"""

import os
import re
import sys
import logging
from itertools import combinations

from config.database import get_db_connection

logger = logging.getLogger(__name__)

# Tables schéma-qualifiées : raw_data.xxx / clean_data.xxx / public.xxx
_TABLE_RE = re.compile(r"\b(?:raw_data|clean_data|public)\.([a-zA-Z_][a-zA-Z0-9_]*)", re.IGNORECASE)

# Poids minimal pour conserver une paire (évite le bruit des requêtes uniques).
MIN_POIDS = int(os.getenv("AI_COOC_MIN", "1"))


def _tables_de(sql: str) -> set:
    """Noms de tables (sans schéma, minuscule) référencés dans `sql`."""
    return {m.group(1).lower() for m in _TABLE_RE.finditer(sql or "")}


def construire(conn) -> int:
    paires = {}
    with conn.cursor() as cur:
        cur.execute(
            "SELECT sql_genere FROM public.ai_query_log "
            "WHERE statut = 'succes' AND sql_genere IS NOT NULL"
        )
        for (sql,) in cur.fetchall():
            tbls = sorted(_tables_de(sql))
            for a, b in combinations(tbls, 2):   # paires ordonnées a < b
                paires[(a, b)] = paires.get((a, b), 0) + 1

    paires = {k: v for k, v in paires.items() if v >= MIN_POIDS}

    with conn.cursor() as cur:
        cur.execute("TRUNCATE public.ai_table_cooccurrence")
        for (a, b), poids in paires.items():
            cur.execute(
                "INSERT INTO public.ai_table_cooccurrence (src_table, dst_table, poids) "
                "VALUES (%s, %s, %s)",
                (a, b, poids),
            )
    conn.commit()
    return len(paires)


def main() -> int:
    logging.basicConfig(level=logging.INFO, format="%(message)s")
    try:
        with get_db_connection() as conn:
            n = construire(conn)
    except Exception as e:
        logger.error(f"❌ Échec build_cooccurrence : {e} "
                     "(migration 018 jouée ? table ai_table_cooccurrence présente ?)")
        return 1
    logger.info(f"✅ {n} paire(s) de co-occurrence écrite(s) dans ai_table_cooccurrence "
                f"(poids >= {MIN_POIDS}).")
    return 0


if __name__ == "__main__":
    sys.exit(main())
