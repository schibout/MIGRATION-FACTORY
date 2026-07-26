# -*- coding: utf-8 -*-
"""
ai_semantic_cache — Cache SÉMANTIQUE des questions de l'Assistant IA.

But : éviter de rappeler le modèle Ollama (lent sur CPU, ~4-6 s) quand une question
quasi identique a DÉJÀ été posée avec succès. On compare la question entrante aux
questions passées (statut 'succes') via la similarité cosinus de leurs embeddings
(colonne public.ai_query_log.embedding, migration 015) et, au-dessus d'un seuil, on
réutilise le SQL déjà généré.

Sécurité : le SQL réutilisé repasse TOUJOURS par sql_guard et s'exécute via le rôle
readonly_ai (côté appelant). Les données restituées sont donc fraîches et bornées —
seule la GÉNÉRATION est court-circuitée, pas l'exécution.

Tolérant aux pannes : si les embeddings ou pgvector sont indisponibles, lookup()
renvoie None et le pipeline appelle Ollama comme d'habitude.
"""

import os
import logging

from config.database import get_db_connection
from services.ai_embeddings import embed, to_pgvector

logger = logging.getLogger(__name__)


def _enabled() -> bool:
    return os.getenv("AI_CACHE_ENABLED", "true").lower() == "true"


def _threshold() -> float:
    """Similarité cosinus minimale pour considérer deux questions équivalentes."""
    try:
        return float(os.getenv("AI_CACHE_THRESHOLD", "0.94"))
    except ValueError:
        return 0.94


def lookup(question: str):
    """
    Cherche une question passée à succès sémantiquement très proche.

    Retour : dict {id_log, sql, question, similarity, vector} si un hit dépasse le
    seuil, sinon None. `vector` est l'embedding de la question entrante (réutilisable
    pour le store, afin de ne pas ré-embedder).
    """
    if not _enabled():
        return None
    vector = embed(question)
    if vector is None:
        return None

    pgvec = to_pgvector(vector)
    try:
        with get_db_connection() as conn:
            with conn.cursor() as cur:
                cur.execute(
                    """
                    SELECT id, question, sql_genere,
                           1 - (embedding <=> %s::vector) AS similarity
                    FROM public.ai_query_log
                    WHERE statut = 'succes'
                      AND embedding IS NOT NULL
                      AND sql_genere IS NOT NULL
                      AND feedback IS DISTINCT FROM 'down'
                    ORDER BY embedding <=> %s::vector, (feedback = 'up') DESC
                    LIMIT 1
                    """,
                    (pgvec, pgvec),
                )
                row = cur.fetchone()
    except Exception as e:
        logger.warning(f"⚠️ Cache sémantique indisponible (lookup) : {e}")
        return None

    if not row:
        return None
    id_log, q_passee, sql_genere, similarity = row
    if similarity is None or float(similarity) < _threshold():
        return None

    logger.info(
        f"♻️ Cache HIT (sim={float(similarity):.3f}) : «{question[:50]}» ≈ «{(q_passee or '')[:50]}»"
    )
    return {
        "id_log": id_log,
        "sql": sql_genere,
        "question": q_passee,
        "similarity": float(similarity),
        "vector": vector,
    }


def store(id_log: int, question: str, vector=None) -> None:
    """
    Mémorise l'embedding d'une question réussie (sur sa ligne ai_query_log) pour
    qu'elle puisse servir de hit au cache à l'avenir. Non bloquant : un échec ne
    doit jamais casser la réponse à l'utilisateur.

    `vector` peut être fourni (réutilisé du lookup) pour éviter un ré-embedding.
    """
    if not _enabled() or not id_log:
        return
    if vector is None:
        vector = embed(question)
    if vector is None:
        return
    try:
        with get_db_connection() as conn:
            with conn.cursor() as cur:
                cur.execute(
                    "UPDATE public.ai_query_log SET embedding = %s::vector WHERE id = %s",
                    (to_pgvector(vector), id_log),
                )
            conn.commit()
    except Exception as e:
        logger.warning(f"⚠️ Cache sémantique : écriture de l'embedding impossible : {e}")
