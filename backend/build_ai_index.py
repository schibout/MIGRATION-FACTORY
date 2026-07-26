# -*- coding: utf-8 -*-
"""
build_ai_index — Indexation vectorielle (pgvector) pour l'Assistant IA.

Peuple public.ai_embeddings (créée par la migration 015) avec :
  - kind='table'   : une entrée par table du dictionnaire SAP (raw_data), dont le
                     texte source = description FR + libellés des colonnes. Sert à
                     la sélection RAG SÉMANTIQUE des tables pertinentes.
  - kind='example' : une entrée par question du dataset few-shot
                     (config/dataset_sap_ia.jsonl). Sert à choisir les exemples les
                     plus proches sémantiquement de la question utilisateur.

Idempotent : upsert par (kind, ref_id). Relançable à volonté (après mise à jour du
dictionnaire ou du dataset).

Usage (sur le serveur, embeddings Ollama disponibles) :
    cd backend && python build_ai_index.py
    python build_ai_index.py --only tables
    python build_ai_index.py --only examples
"""

import os
import sys
import json
import argparse
import logging

# Permet `python build_ai_index.py` depuis backend/ comme depuis la racine.
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from config.database import get_db_connection            # noqa: E402
from services.ai_embeddings import embed, to_pgvector, is_enabled, EMBED_DIM  # noqa: E402

logging.basicConfig(level=logging.INFO, format="%(levelname)s %(message)s")
logger = logging.getLogger("build_ai_index")

# Budget de caractères par document de table. Les tables SAP riches (100+ colonnes)
# produisent un texte énorme qui sature le modèle d'embeddings et fait dépasser le
# timeout sur CPU. On tronque : description + premières colonnes suffisent à capter
# la sémantique de la table pour la sélection RAG.
MAX_DOC_CHARS = 1500


def _upsert_embedding(cur, kind: str, ref_id: str, content: str, vector: list):
    """Insère ou met à jour le vecteur d'une source (kind, ref_id)."""
    cur.execute(
        """
        INSERT INTO public.ai_embeddings (kind, ref_id, content, embedding)
        VALUES (%s, %s, %s, %s::vector)
        ON CONFLICT (kind, ref_id) DO UPDATE
            SET content = EXCLUDED.content,
                embedding = EXCLUDED.embedding,
                date_creation = CURRENT_TIMESTAMP
        """,
        (kind, ref_id, content, to_pgvector(vector)),
    )


# --------------------------------------------------------------------------- #
# 1) Tables du dictionnaire SAP
# --------------------------------------------------------------------------- #
def _fetch_table_documents(conn):
    """
    Construit, pour chaque table du dictionnaire, un document texte =
    description FR + libellés des colonnes. Renvoie [(ref_id, content), ...].
    """
    sql = """
        SELECT lower(p.table_name) AS tbl,
               coalesce(p.description, '') AS descr,
               string_agg(
                   coalesce(f.field_name, '') ||
                   CASE WHEN coalesce(f.field_text, '') <> ''
                        THEN ' (' || f.field_text || ')' ELSE '' END,
                   ', ' ORDER BY f.position
               ) AS colonnes
        FROM public.sap_table_properties p
        LEFT JOIN public.sap_table_fields f
               ON upper(f.table_name) = upper(p.table_name)
        GROUP BY p.table_name, p.description
    """
    docs = []
    with conn.cursor() as cur:
        cur.execute(sql)
        for tbl, descr, colonnes in cur.fetchall():
            ref_id = f"raw_data.{tbl}"
            content = f"Table {ref_id}. {descr}. Colonnes : {colonnes}".strip()
            # Tronque les très gros documents (tables à nombreuses colonnes) pour
            # rester sous le budget de contexte/temps du modèle d'embeddings.
            if len(content) > MAX_DOC_CHARS:
                content = content[:MAX_DOC_CHARS].rsplit(",", 1)[0] + " …"
            docs.append((ref_id, content))
    return docs


def _fetch_clean_table_documents(conn):
    """
    Documents des tables/vues clean_data (cible IFS) : nom + description
    (COMMENT ON TABLE, souvent vide) + colonnes avec leurs commentaires
    (COMMENT ON COLUMN). Ces tables sont absentes du dictionnaire SAP, d'où
    le passage par information_schema + pg_description.
    """
    sql = """
        SELECT c.table_name,
               coalesce(obj_description(pc.oid), '') AS descr,
               string_agg(
                   c.column_name ||
                   CASE WHEN coalesce(col_description(pc.oid, c.ordinal_position), '') <> ''
                        THEN ' (' || col_description(pc.oid, c.ordinal_position) || ')' ELSE '' END,
                   ', ' ORDER BY c.ordinal_position
               ) AS colonnes
        FROM information_schema.columns c
        JOIN pg_catalog.pg_class pc ON pc.relname = c.table_name
        JOIN pg_catalog.pg_namespace n ON n.oid = pc.relnamespace
                                       AND n.nspname = c.table_schema
        WHERE c.table_schema = 'clean_data'
        GROUP BY c.table_name, pc.oid
    """
    docs = []
    with conn.cursor() as cur:
        cur.execute(sql)
        for tbl, descr, colonnes in cur.fetchall():
            ref_id = f"clean_data.{tbl}"
            content = f"Table {ref_id} (donnees transformees pour IFS). {descr}. Colonnes : {colonnes}".strip()
            if len(content) > MAX_DOC_CHARS:
                content = content[:MAX_DOC_CHARS].rsplit(",", 1)[0] + " …"
            docs.append((ref_id, content))
    return docs


def index_tables(conn) -> int:
    docs = _fetch_table_documents(conn) + _fetch_clean_table_documents(conn)
    logger.info(f"Tables du dictionnaire à indexer : {len(docs)}")
    ok = 0
    with conn.cursor() as cur:
        for ref_id, content in docs:
            vector = embed(content)
            if vector is None:
                logger.warning(f"  ✗ embedding indisponible pour {ref_id} — ignoré.")
                continue
            _upsert_embedding(cur, "table", ref_id, content, vector)
            ok += 1
            if ok % 25 == 0:
                conn.commit()
                logger.info(f"  … {ok} tables indexées")
    conn.commit()
    logger.info(f"✅ Tables indexées : {ok}/{len(docs)}")
    return ok


# --------------------------------------------------------------------------- #
# 2) Exemples few-shot
# --------------------------------------------------------------------------- #
def _examples_path() -> str:
    return os.getenv(
        "AI_EXAMPLES_PATH",
        os.path.join(os.path.dirname(__file__), "config", "dataset_sap_ia.jsonl"),
    )


def _fetch_example_questions():
    """Renvoie [(ref_id, question), ...] depuis le dataset jsonl."""
    path = _examples_path()
    exemples = []
    try:
        with open(path, encoding="utf-8") as fh:
            for i, ligne in enumerate(fh):
                ligne = ligne.strip()
                if not ligne:
                    continue
                msgs = json.loads(ligne).get("messages", [])
                q = next((m["content"] for m in msgs if m.get("role") == "user"), None)
                if q:
                    exemples.append((f"ex_{i:04d}", q))
    except FileNotFoundError:
        logger.error(f"Dataset few-shots introuvable : {path}")
    return exemples


def index_examples(conn) -> int:
    exemples = _fetch_example_questions()
    logger.info(f"Exemples few-shot à indexer : {len(exemples)}")
    ok = 0
    with conn.cursor() as cur:
        for ref_id, question in exemples:
            vector = embed(question)
            if vector is None:
                logger.warning(f"  ✗ embedding indisponible pour {ref_id} — ignoré.")
                continue
            _upsert_embedding(cur, "example", ref_id, question, vector)
            ok += 1
    conn.commit()
    logger.info(f"✅ Exemples indexés : {ok}/{len(exemples)}")
    return ok


# --------------------------------------------------------------------------- #
# 3) Knowledge cards (dérivées des packs) — nécessite la colonne metadata (migr. 017)
# --------------------------------------------------------------------------- #
def index_knowledge(conn) -> int:
    from services.knowledge_service import iter_cards
    cards = iter_cards()
    logger.info(f"Knowledge cards à indexer : {len(cards)}")
    ok = 0
    with conn.cursor() as cur:
        for c in cards:
            vector = embed(c["content"])
            if vector is None:
                logger.warning(f"  ✗ embedding indisponible pour {c['id']} — ignoré.")
                continue
            meta = {"type": c["type"], "domain": c["domain"], "tables": c["tables"]}
            cur.execute(
                """
                INSERT INTO public.ai_embeddings (kind, ref_id, content, embedding, metadata)
                VALUES ('knowledge', %s, %s, %s::vector, %s::jsonb)
                ON CONFLICT (kind, ref_id) DO UPDATE
                    SET content = EXCLUDED.content, embedding = EXCLUDED.embedding,
                        metadata = EXCLUDED.metadata, date_creation = CURRENT_TIMESTAMP
                """,
                (c["id"], c["content"], to_pgvector(vector), json.dumps(meta)),
            )
            ok += 1
    conn.commit()
    logger.info(f"✅ Knowledge cards indexées : {ok}/{len(cards)}")
    return ok


def main():
    parser = argparse.ArgumentParser(description="Indexation vectorielle Assistant IA.")
    parser.add_argument("--only", choices=["tables", "examples", "knowledge"],
                        help="N'indexer qu'un seul type (par défaut : les trois).")
    args = parser.parse_args()

    if not is_enabled():
        logger.error("Embeddings désactivés (AI_EMBED_ENABLED=false). Indexation annulée.")
        sys.exit(1)

    # Vérifie tôt qu'Ollama répond et renvoie la bonne dimension.
    probe = embed("vérification de disponibilité du modèle d'embeddings")
    if probe is None:
        logger.error("Modèle d'embeddings injoignable. Vérifiez Ollama et `ollama pull bge-m3`.")
        sys.exit(1)
    logger.info(f"Modèle d'embeddings OK (dimension {EMBED_DIM}).")

    with get_db_connection() as conn:
        total = 0
        if args.only in (None, "tables"):
            total += index_tables(conn)
        if args.only in (None, "examples"):
            total += index_examples(conn)
        if args.only in (None, "knowledge"):
            try:
                total += index_knowledge(conn)
            except Exception as e:
                conn.rollback()
                logger.error(f"Indexation knowledge échouée ({e}). "
                             "Avez-vous joué la migration 017 (colonne ai_embeddings.metadata) ?")
    logger.info(f"Terminé. {total} vecteur(s) écrit(s) dans public.ai_embeddings.")


if __name__ == "__main__":
    main()
