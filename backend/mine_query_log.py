# -*- coding: utf-8 -*-
"""
mine_query_log — Boucle d'amélioration continue (C4).

Extrait de `public.ai_query_log` les requêtes RÉUSSIES (statut='succes') qui ne
sont pas déjà couvertes par le dataset few-shot, et produit un fichier de
**candidats** au format dataset, pour REVUE HUMAINE.

⚠️ N'ajoute JAMAIS automatiquement au dataset (éviter d'empoisonner les few-shots
avec du SQL « exécutable mais faux »). Workflow :
  1. python backend/mine_query_log.py            # -> config/dataset_candidates.jsonl
  2. relire / corriger / garder les bons candidats
  3. les copier dans config/dataset_sap_ia.jsonl
  4. python build_ai_index.py --only examples    # ré-embarque

Usage :
  python backend/mine_query_log.py [--limit 200] [--min-rows 1] [--out <chemin>]
"""

import os
import sys
import json
import argparse
import logging

from config.database import get_db_connection
from services.ai_schema_retriever import _normalize

logger = logging.getLogger(__name__)


def _dataset_path() -> str:
    return os.getenv(
        "AI_EXAMPLES_PATH",
        os.path.join(os.path.dirname(__file__), "config", "dataset_sap_ia.jsonl"),
    )


def _questions_existantes() -> set:
    """Questions déjà dans le dataset (normalisées), pour dédupliquer."""
    vues = set()
    try:
        with open(_dataset_path(), encoding="utf-8") as fh:
            for ligne in fh:
                ligne = ligne.strip()
                if not ligne:
                    continue
                msgs = json.loads(ligne).get("messages", [])
                q = next((m["content"] for m in msgs if m.get("role") == "user"), None)
                if q:
                    vues.add(_normalize(q))
    except FileNotFoundError:
        logger.warning("Dataset introuvable — dédup désactivée.")
    return vues


def extraire_candidats(limit: int, min_rows: int) -> list:
    """Q→SQL distincts, réussis, hors dataset. Le plus récent SQL par question."""
    deja = _questions_existantes()
    sql = """
        SELECT DISTINCT ON (lower(btrim(question)))
               question, sql_genere, nb_lignes, date_creation
        FROM public.ai_query_log
        WHERE statut = 'succes'
          AND question IS NOT NULL AND btrim(question) <> ''
          AND sql_genere IS NOT NULL
          AND coalesce(nb_lignes, 0) >= %s
        ORDER BY lower(btrim(question)), date_creation DESC
        LIMIT %s
    """
    candidats, vus = [], set()
    with get_db_connection() as conn:
        with conn.cursor() as cur:
            cur.execute(sql, (min_rows, limit))
            for question, sql_genere, _nb, _dt in cur.fetchall():
                norm = _normalize(question)
                if norm in deja or norm in vus:
                    continue
                vus.add(norm)
                candidats.append((question.strip(), sql_genere.strip()))
    return candidats


def main():
    logging.basicConfig(level=logging.INFO, format="%(message)s")
    parser = argparse.ArgumentParser(description="Candidats few-shot depuis ai_query_log (revue humaine).")
    parser.add_argument("--limit", type=int, default=200, help="Nb max de requêtes scannées.")
    parser.add_argument("--min-rows", type=int, default=1, help="Min de lignes renvoyées (filtre le bruit).")
    parser.add_argument("--out", default=os.path.join(os.path.dirname(__file__), "config",
                                                       "dataset_candidates.jsonl"))
    args = parser.parse_args()

    candidats = extraire_candidats(args.limit, args.min_rows)
    if not candidats:
        logger.info("Aucun nouveau candidat (rien de réussi hors dataset).")
        return

    with open(args.out, "w", encoding="utf-8") as fh:
        for question, sql_genere in candidats:
            ligne = {"messages": [
                {"role": "user", "content": question},
                {"role": "assistant",
                 "content": json.dumps({"sql": sql_genere, "explication": ""}, ensure_ascii=False)},
            ]}
            fh.write(json.dumps(ligne, ensure_ascii=False) + "\n")

    logger.info(f"✅ {len(candidats)} candidat(s) écrit(s) dans {args.out}")
    logger.info("⚠️  À RELIRE avant d'ajouter au dataset (ne PAS injecter tel quel).")


if __name__ == "__main__":
    sys.exit(main())
