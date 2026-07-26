# -*- coding: utf-8 -*-
"""
knowledge_service — Knowledge Cards granulaires pour l'Assistant IA.

Au lieu d'injecter un pack de domaine entier, on découpe la connaissance curée en
CARDS atomiques (1 jointure / 1 règle / 1 enum / 1 requête-type) et on ne retient
que les plus pertinentes pour la question + les tables retrouvées.

Source des cards : les packs déjà validés (`backend/config/skills/*.json`) — rien
n'est dupliqué ni re-saisi. Les cards sont indexées (embeddings bge-m3) dans
`public.ai_embeddings` avec `kind='knowledge'` (cf. build_ai_index.py), ce qui
permet un classement sémantique. SANS embeddings, le recouvrement de tables suffit
(dégradation propre).

Tolérant aux pannes : toute erreur -> repli lexical, puis '' si rien.
"""

import os
import glob
import json
import logging

from services.ai_schema_retriever import _normalize
from services.ai_embeddings import embed, to_pgvector
from services.ai_config_store import get_packs_db
from config.database import get_db_connection

logger = logging.getLogger(__name__)

MAX_CARDS = 5
TYPES = ("join", "rule", "enum", "pattern", "doc")


def _skills_dir() -> str:
    return os.getenv(
        "AI_SKILLS_PATH",
        os.path.join(os.path.dirname(__file__), "..", "config", "skills"),
    )


def _bare(table_qualifie: str) -> str:
    return table_qualifie.split(".")[-1].strip().lower()


def _load_packs_files() -> dict:
    """Repli : {domain: pack} chargé depuis config/skills/*.json."""
    packs = {}
    for chemin in sorted(glob.glob(os.path.join(_skills_dir(), "*.json"))):
        try:
            with open(chemin, encoding="utf-8") as fh:
                pack = json.load(fh)
            domain = pack.get("domain") or os.path.splitext(os.path.basename(chemin))[0]
            packs[domain] = pack
        except Exception as e:
            logger.warning(f"Pack illisible pour cards ({chemin}) : {e}")
    return packs


def _packs_source() -> dict:
    """Packs {domain: pack} : base éditable (ai_packs) en priorité, sinon fichiers."""
    db = get_packs_db()
    return db if db else _load_packs_files()


def _derive_cards(packs: dict) -> list:
    """Explose les packs en cards atomiques. Chaque card : dict(id,type,domain,
    tables(bare),keywords,priority,content)."""
    cards = []
    for domain, pack in sorted((packs or {}).items()):
        tables = [_bare(t) for t in pack.get("tables", [])]
        kw = (pack.get("keywords") or []) + (pack.get("synonyms") or [])

        def _add(type_, idx, content, priority):
            content = (content or "").strip()
            if content:
                cards.append({
                    "id": f"{domain}:{type_}:{idx}",
                    "type": type_, "domain": domain, "tables": tables,
                    "keywords": kw, "priority": priority, "content": content,
                })

        for i, j in enumerate(pack.get("joins", [])):
            _add("join", i, j, 3)          # jointures = plus haute valeur
        for i, p in enumerate(pack.get("patterns", [])):
            intent = (p.get("intent") or "").strip()
            sql = (p.get("sql") or "").strip()
            if sql:
                _add("pattern", i, f"{intent} : {sql}" if intent else sql, 2)
        for i, d in enumerate(pack.get("docs", [])):
            _add("doc", i, d, 2)           # définitions métier / glossaire / KPI
        for i, e in enumerate(pack.get("enums", [])):
            _add("enum", i, e, 1)
        for i, r in enumerate(pack.get("rules", [])):
            _add("rule", i, r, 1)
    return cards


def get_cards() -> list:
    """Cards dérivées à la volée de la source de packs (DB éditable ou fichiers)."""
    return _derive_cards(_packs_source())


def iter_cards() -> list:
    """Expose les cards (pour l'indexation par build_ai_index)."""
    return get_cards()


def _knowledge_enabled() -> bool:
    return os.getenv("AI_KNOWLEDGE_ENABLED", "true").strip().lower() in ("1", "true", "yes", "on")


def _semantic_card_ids(question: str, conn, k: int = 10) -> set:
    """Ids des cards les plus proches sémantiquement (bge-m3). set() si indispo."""
    try:
        vec = embed(question)
        if vec is None:
            return set()
        with conn.cursor() as cur:
            cur.execute(
                """
                SELECT ref_id
                FROM public.ai_embeddings
                WHERE kind = 'knowledge'
                ORDER BY embedding <=> %s::vector
                LIMIT %s
                """,
                (to_pgvector(vec), k),
            )
            return {r[0] for r in cur.fetchall()}
    except Exception as e:
        logger.warning(f"⚠️ Classement sémantique des cards indisponible : {e}")
        return set()


def retrieve_relevant_knowledge(question: str, tables, conn=None) -> list:
    """
    Renvoie les cards les plus pertinentes (objets), classées. Signal principal =
    recouvrement avec les tables retrouvées (robuste, sans embeddings) ; bonus
    sémantique si l'index est disponible.
    """
    cards = get_cards()
    if not _knowledge_enabled() or not cards:
        return []
    table_names = {_bare(t) for t in (tables or [])}
    qn = _normalize(question)

    if conn is None:
        try:
            with get_db_connection() as c:
                return retrieve_relevant_knowledge(question, tables, c)
        except Exception:
            conn = None  # on continue en lexical pur

    sem = _semantic_card_ids(question, conn) if conn is not None else set()

    scored = []
    for c in cards:
        # Pertinence : une card n'est éligible que si elle cible une table retrouvée
        # OU contient un mot-clé de la question. La priorité (join>pattern>enum/rule)
        # et la proximité sémantique ne font que RECLASSER des cards déjà pertinentes
        # — elles ne rendent jamais une card éligible à elles seules.
        rel = 0
        if table_names & set(c["tables"]):
            rel += 3                                 # card ciblant une table retrouvée
        if any(_normalize(k) in qn for k in c["keywords"]):
            rel += 1                                 # mot-clé du domaine présent
        if rel <= 0:
            continue
        score = rel + c.get("priority", 0) + (2 if c["id"] in sem else 0)
        scored.append((score, c))

    scored.sort(key=lambda x: (-x[0], x[1]["id"]))
    return [c for _s, c in scored[:MAX_CARDS]]


def build_knowledge_block(question: str, tables, conn=None) -> str:
    """
    Bloc compact de connaissances métier (cards) pour la question + tables. '' si
    aucune. Plafonné par AI_KNOWLEDGE_MAX_CHARS (défaut 500). Jamais de SQL tronqué.
    """
    try:
        max_chars = int(os.getenv("AI_KNOWLEDGE_MAX_CHARS", "500"))
    except ValueError:
        max_chars = 500

    cards = retrieve_relevant_knowledge(question, tables, conn)
    if not cards:
        return ""
    lignes, total = [], 0
    for c in cards:
        ligne = f"- [{c['type']}] {c['content']}"
        if total + len(ligne) + 1 > max_chars:
            continue                                 # saute cette card (pas de troncature)
        lignes.append(ligne)
        total += len(ligne) + 1
    return "\n".join(lignes)


if __name__ == "__main__":
    # Test autonome (serveur) : python -m services.knowledge_service "factures fournisseur"
    import sys
    logging.basicConfig(level=logging.INFO)
    q = sys.argv[1] if len(sys.argv) > 1 else "stock par article et fournisseur"
    print(f"\n=== {q}\n")
    print(build_knowledge_block(q, ["raw_data.mara", "raw_data.mard", "raw_data.lfa1"]))
