# -*- coding: utf-8 -*-
"""
seed_ai_config — Peuple les tables éditables de config IA (migration 019) à partir
des valeurs par défaut (code + fichiers config/skills).

Idempotent : ne fait rien si les tables contiennent déjà des données (pour ne pas
écraser les éditions faites depuis l'écran). Utiliser --force pour réinitialiser
(TRUNCATE + ré-insertion des défauts).

À lancer une fois après la migration 019 :
    docker-compose exec backend python seed_ai_config.py
"""

import sys
import json
import argparse
import logging

from config.database import get_db_connection
from services.ai_schema_retriever import _DOMAIN_TABLES_DEFAUT
from services.knowledge_service import _load_packs_files

logger = logging.getLogger(__name__)


def seed_domains(cur, force: bool) -> int:
    if force:
        cur.execute("TRUNCATE public.ai_domain_tables")
    else:
        cur.execute("SELECT COUNT(*) FROM public.ai_domain_tables")
        if cur.fetchone()[0] > 0:
            return -1  # déjà peuplé
    n = 0
    for pos, (domain_id, keywords, tables) in enumerate(_DOMAIN_TABLES_DEFAUT):
        cur.execute(
            """INSERT INTO public.ai_domain_tables (domain_id, keywords, tables, position)
               VALUES (%s, %s::jsonb, %s::jsonb, %s)""",
            (domain_id, json.dumps(sorted(keywords)), json.dumps(list(tables)), pos),
        )
        n += 1
    return n


def seed_packs(cur, force: bool) -> int:
    if force:
        cur.execute("TRUNCATE public.ai_packs")
    else:
        cur.execute("SELECT COUNT(*) FROM public.ai_packs")
        if cur.fetchone()[0] > 0:
            return -1
    n = 0
    for domain, content in _load_packs_files().items():
        cur.execute(
            "INSERT INTO public.ai_packs (domain, content) VALUES (%s, %s::jsonb)",
            (domain, json.dumps(content)),
        )
        n += 1
    return n


def main() -> int:
    logging.basicConfig(level=logging.INFO, format="%(message)s")
    parser = argparse.ArgumentParser(description="Seed config IA éditable (019).")
    parser.add_argument("--force", action="store_true",
                        help="Réinitialise (TRUNCATE) puis ré-insère les défauts — écrase les éditions.")
    args = parser.parse_args()

    try:
        with get_db_connection() as conn:
            with conn.cursor() as cur:
                d = seed_domains(cur, args.force)
                p = seed_packs(cur, args.force)
            conn.commit()
    except Exception as e:
        logger.error(f"❌ Seed échoué : {e} (migration 019 jouée ?)")
        return 1

    logger.info(f"Domaines : {'déjà peuplé (ignoré)' if d == -1 else str(d) + ' insérés'}")
    logger.info(f"Packs    : {'déjà peuplé (ignoré)' if p == -1 else str(p) + ' insérés'}")
    if d == -1 or p == -1:
        logger.info("(Utiliser --force pour réinitialiser depuis les défauts.)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
