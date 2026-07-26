# -*- coding: utf-8 -*-
"""
ai_config_store — Accès caché à la configuration ÉDITABLE des prompts (base).

Lit `public.ai_domain_tables` et `public.ai_packs` (migration 019), avec un cache
TTL en mémoire. Renvoie None quand la source DB est vide ou indisponible : c'est le
signal pour que l'appelant utilise son REPLI (code / fichiers config/skills).

Ce module n'importe AUCUN consommateur (ai_schema_retriever / ai_prompt_builder /
knowledge_service) → pas de cycle d'import.

Multi-worker (gunicorn) : chaque process a son cache ; une édition est visible sous
`TTL_SECONDS` sur les autres workers, immédiatement sur le worker qui a invalidé.
"""

import os
import time
import logging

from config.database import get_db_connection

logger = logging.getLogger(__name__)

TTL_SECONDS = int(os.getenv("AI_CONFIG_TTL_SECONDS", "60"))

# cache : clé -> (timestamp, valeur)
_CACHE = {}


def invalidate(cle: str = None) -> None:
    """Vide le cache (une clé, ou tout)."""
    if cle is None:
        _CACHE.clear()
    else:
        _CACHE.pop(cle, None)


def _cached(cle: str, loader):
    now = time.time()
    ts, val = _CACHE.get(cle, (0.0, None))
    if now - ts < TTL_SECONDS and cle in _CACHE:
        return val
    val = loader()
    _CACHE[cle] = (now, val)
    return val


def _load_domain_tables_db():
    """[(domain_id, set(keywords), [tables])] depuis la base, ou None si vide/indispo."""
    try:
        with get_db_connection() as conn:
            with conn.cursor() as cur:
                cur.execute(
                    """SELECT domain_id, keywords, tables
                       FROM public.ai_domain_tables
                       WHERE actif = TRUE
                       ORDER BY position, id"""
                )
                rows = cur.fetchall()
        if not rows:
            return None
        return [(dom, set(kw or []), list(tbl or [])) for dom, kw, tbl in rows]
    except Exception as e:
        logger.warning(f"⚠️ ai_domain_tables indisponible ({e}) — repli sur le code.")
        return None


def _load_packs_db():
    """{domain: pack_dict} depuis la base, ou None si vide/indispo."""
    try:
        with get_db_connection() as conn:
            with conn.cursor() as cur:
                cur.execute(
                    "SELECT domain, content FROM public.ai_packs WHERE actif = TRUE"
                )
                rows = cur.fetchall()
        if not rows:
            return None
        return {dom: content for dom, content in rows}
    except Exception as e:
        logger.warning(f"⚠️ ai_packs indisponible ({e}) — repli sur les fichiers.")
        return None


def get_domain_tables_db():
    """Associations mot-clé->tables (DB, caché). None => l'appelant prend son repli."""
    return _cached("domain_tables", _load_domain_tables_db)


def get_packs_db():
    """Packs de connaissances (DB, caché). None => l'appelant prend son repli."""
    return _cached("packs", _load_packs_db)
