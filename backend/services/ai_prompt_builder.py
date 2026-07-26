# -*- coding: utf-8 -*-
"""
ai_prompt_builder — Assemble le prompt système DYNAMIQUE de l'Assistant IA (RAG).

Remplace le system prompt statique de config/ai_system_prompt.py. Structure :

    [ SOCLE_HEAD ]   règles SAP + dialecte + format JSON   (STABLE -> reste en cache KV Ollama)
    [ SCHÉMA CIBLÉ ] uniquement les tables pertinentes, colonnes réelles du dictionnaire
    [ EXEMPLES ]     2-3 few-shots du dataset les plus proches de la question
    [ SOCLE_TAIL ]   consigne finale

Le SOCLE_HEAD est IDENTIQUE à chaque appel : place en tête, c'est le préfixe que
le keep-warm garde chaud, donc seul le suffixe court (schéma + exemples, ~600 tokens)
est ré-évalué par question au lieu des ~3800 tokens du prompt statique.

Le schéma ne contient que des colonnes réelles (cf. ai_schema_retriever) -> pas
d'hallucination de colonnes.
"""

import os
import json
import logging

from services.ai_schema_retriever import (
    build_schema_block, retrieve_tables, detect_domains, _normalize,
)
from services.ai_knowledge_graph import get_relevant_subgraph
from services.ai_rag_budget import get_budget
from services.knowledge_service import build_knowledge_block
from services.ai_embeddings import embed, to_pgvector
from services.ai_config_store import get_packs_db
from config.database import get_db_connection

logger = logging.getLogger(__name__)

NB_EXEMPLES = 3

# --------------------------------------------------------------------------- #
# SOCLE : partie stable du prompt (conventions non déductibles du dictionnaire).
# Tenu volontairement court (~700 tokens) et identique à chaque requête.
# --------------------------------------------------------------------------- #
_COT_ENABLED = os.getenv("AI_COT_ENABLED", "true").strip().lower() in ("1", "true", "yes", "on")

# Bloc « format de réponse » : variante CoT (raisonnement AVANT le SQL) ou directe.
if _COT_ENABLED:
    _FORMAT_BLOC = (
        "REPONSE OBLIGATOIRE : un objet JSON strict, sans markdown, sans backticks, sans texte autour.\n"
        "Raisonne D'ABORD dans \"raisonnement\" (tables a utiliser, jointures justifiees par le schema, "
        "regles SAP a appliquer, filtres), PUIS ecris le SQL qui en decoule :\n"
        '{"raisonnement": "...", "sql": "...", "explication": "..."}'
    )
    SOCLE_TAIL = ('Genere maintenant le JSON ({"raisonnement","sql","explication"}) pour la question '
                  "suivante. JSON UNIQUEMENT.")
else:
    _FORMAT_BLOC = (
        "REPONSE OBLIGATOIRE : un objet JSON strict, sans markdown, sans backticks, sans texte autour :\n"
        '{"sql": "...", "explication": "..."}'
    )
    SOCLE_TAIL = "Genere maintenant le JSON pour la question suivante. JSON UNIQUEMENT."

_SOCLE_HEAD_TPL = """Tu es un assistant SQL pour le projet Migration Factory (migration SAP ECC vers IFS Cloud).
Tu génères UNIQUEMENT des requêtes PostgreSQL en LECTURE SEULE (SELECT ou WITH).

__FORMAT_BLOC__

=== REGLES SAP CRITIQUES ===
1. matnr (codes articles) a des zeros de tete -> affichage LTRIM(matnr, '0').
2. PRESQUE TOUTES les colonnes SAP sont varchar (quantites, montants, dates) : calculs avec CAST, ex SUM(labst::numeric). Dates SAP varchar 'YYYYMMDD'.
3. Textes multilingues (makt, t005t, t023t, eqkt, iflotx) : colonne spras, preferer 'F'.
N'AJOUTE PAS de filtre technique mandt, loevm, lvorm, loekz ni stblg : genere des requetes simples sur les principaux champs.

=== DIALECTE : POSTGRESQL 14+ STRICT ===
- Cast valeur::numeric / ::date (PAS CONVERT/TO_NUMBER) ; NULL via COALESCE (PAS NVL/ISNULL)
- ILIKE '%texte%' pour la casse ; concatenation avec || ; limite LIMIT n (PAS TOP/ROWNUM)
- Identifiants entre "..." si necessaire (JAMAIS backticks) ; TO_DATE(col, 'YYYYMMDD') pour les dates
- TOUJOURS qualifier les tables par leur schema (raw_data. / clean_data. / public.)

IMPORTANT : utilise UNIQUEMENT les tables et colonnes listees ci-dessous. N'invente AUCUNE colonne."""

# Préfixe stable du prompt (gardé chaud par le keep-warm). Le format CoT/direct est
# figé au démarrage via AI_COT_ENABLED -> get_socle() reste identique à chaque appel.
SOCLE_HEAD = _SOCLE_HEAD_TPL.replace("__FORMAT_BLOC__", _FORMAT_BLOC)


# --------------------------------------------------------------------------- #
# Banque d'exemples (few-shots) — chargée une fois au démarrage.
# --------------------------------------------------------------------------- #
def _examples_path() -> str:
    return os.getenv(
        "AI_EXAMPLES_PATH",
        os.path.join(os.path.dirname(__file__), "..", "config", "dataset_sap_ia.jsonl"),
    )


def _load_examples() -> list:
    """Charge le dataset jsonl en liste de (question, reponse_json_str)."""
    path = _examples_path()
    exemples = []
    try:
        with open(path, encoding="utf-8") as fh:
            for ligne in fh:
                ligne = ligne.strip()
                if not ligne:
                    continue
                msgs = json.loads(ligne).get("messages", [])
                q = next((m["content"] for m in msgs if m.get("role") == "user"), None)
                a = next((m["content"] for m in msgs if m.get("role") == "assistant"), None)
                if q and a:
                    exemples.append((q, a, set(_normalize(q).split())))
    except FileNotFoundError:
        logger.warning(f"Dataset few-shots introuvable ({path}) — exemples desactives.")
    except Exception as e:
        logger.warning(f"Lecture dataset few-shots impossible : {e}")
    logger.info(f"Few-shots charges : {len(exemples)} exemples depuis {path}")
    return exemples


_EXAMPLES = _load_examples()

# Index question (normalisée) -> réponse, pour retrouver la réponse d'un exemple
# sélectionné sémantiquement (l'index vectoriel ne stocke que la question).
_EXAMPLES_BY_Q = {_normalize(q): a for q, a, _m in _EXAMPLES}


# --------------------------------------------------------------------------- #
# Packs de connaissances (skills) — connaissances métier curées par domaine
# (jointures/FK, valeurs/enums, requêtes-types, règles). Injectées de façon
# compacte et ciblée par domaine, en plus du schéma réel. Chargées au démarrage.
# --------------------------------------------------------------------------- #
def _skills_dir() -> str:
    return os.getenv(
        "AI_SKILLS_PATH",
        os.path.join(os.path.dirname(__file__), "..", "config", "skills"),
    )


def _load_skills() -> dict:
    """Charge les packs {domain_id: pack} depuis config/skills/*.json."""
    import glob
    dossier = _skills_dir()
    packs = {}
    try:
        for chemin in sorted(glob.glob(os.path.join(dossier, "*.json"))):
            try:
                with open(chemin, encoding="utf-8") as fh:
                    pack = json.load(fh)
                domain = pack.get("domain") or os.path.splitext(os.path.basename(chemin))[0]
                packs[domain] = pack
            except Exception as e:
                logger.warning(f"Pack skills illisible ({chemin}) : {e}")
    except Exception as e:
        logger.warning(f"Lecture des packs skills impossible : {e}")
    logger.info(f"Packs de connaissances charges : {len(packs)} ({', '.join(packs) or 'aucun'})")
    return packs


# Repli (chargé une fois depuis les fichiers). La source PRIORITAIRE est la base
# éditable public.ai_packs via get_skills().
_SKILLS_FICHIERS = _load_skills()


def get_skills() -> dict:
    """Packs {domain: pack} : base éditable (ai_packs) en priorité, sinon fichiers."""
    db = get_packs_db()
    return db if db else _SKILLS_FICHIERS


def _skill_enabled() -> bool:
    return os.getenv("AI_SKILL_ENABLED", "true").strip().lower() in ("1", "true", "yes", "on")


def _render_pack(pack: dict, max_chars: int) -> str:
    """
    Rendu compact d'un pack, plafonné à `max_chars`. Sous-sections par ordre de
    valeur décroissante (jointures > modèle > valeurs > règles). En débordement,
    une section entière est abandonnée — JAMAIS de SQL tronqué.
    """
    nom = pack.get("domain", "?")
    sections = []
    if pack.get("joins"):
        sections.append(("JOINTURES", " ; ".join(pack["joins"])))
    patterns = pack.get("patterns") or []
    if patterns:
        p0 = patterns[0]
        sql = (p0.get("sql") or "").strip()
        if sql:
            intent = p0.get("intent", "")
            sections.append((f"MODELE ({intent})" if intent else "MODELE", sql))
    if pack.get("docs"):
        sections.append(("DEFINITIONS", " ; ".join(pack["docs"])))
    if pack.get("enums"):
        sections.append(("VALEURS", " ; ".join(pack["enums"])))
    if pack.get("rules"):
        sections.append(("REGLES", " ; ".join(pack["rules"])))

    entete = f"[{nom}]"
    out = entete
    for label, contenu in sections:
        bloc = f"\n{label}: {contenu}"
        if len(out) + len(bloc) <= max_chars:
            out += bloc
    return out if out != entete else ""


def build_skill_block(question: str) -> str:
    """
    Bloc de connaissances métier pour le(s) domaine(s) déclenché(s) par `question`.
    Renvoie '' si aucun domaine ne matche ou si la fonctionnalité est désactivée.
    Détection : (1) ids DOMAIN_TABLES (priorité), (2) keywords/synonymes des packs.
    """
    skills = get_skills()
    if not _skill_enabled() or not skills:
        return ""
    budget = get_budget()
    max_packs = max(1, budget["max_packs"])
    max_chars = budget["pack_chars"]

    ids = [d for d in detect_domains(question) if d in skills]
    qn = _normalize(question)
    for domain, pack in skills.items():
        if domain in ids:
            continue
        phrases = (pack.get("keywords") or []) + (pack.get("synonyms") or [])
        if any(_normalize(p) in qn for p in phrases):
            ids.append(domain)

    blocs = [r for d in ids[:max_packs] if (r := _render_pack(skills[d], max_chars))]
    return "\n".join(blocs)


def _select_examples_lexical(question: str, k: int) -> str:
    """Sélection par recouvrement de mots (repli si embeddings indisponibles)."""
    qmots = set(_normalize(question).split())
    if not qmots:
        return ""
    scored = []
    for q, a, mots in _EXAMPLES:
        recouvrement = len(qmots & mots)
        if recouvrement:
            scored.append((recouvrement, q, a))
    scored.sort(key=lambda x: x[0], reverse=True)
    blocs = [f"Question : {q}\n{a}" for _s, q, a in scored[:k]]
    return "\n\n".join(blocs)


def _select_examples_semantic(question: str, k: int, conn) -> str:
    """
    Sélection SÉMANTIQUE des exemples : k plus proches par similarité cosinus sur
    public.ai_embeddings (kind='example'). Renvoie "" pour signaler à l'appelant
    de retomber sur la sélection lexicale (embeddings/index indisponibles).
    """
    vector = embed(question)
    if vector is None:
        return ""
    try:
        own_conn = conn is None
        if own_conn:
            conn = get_db_connection().__enter__()
        try:
            with conn.cursor() as cur:
                cur.execute(
                    """
                    SELECT content
                    FROM public.ai_embeddings
                    WHERE kind = 'example'
                    ORDER BY embedding <=> %s::vector
                    LIMIT %s
                    """,
                    (to_pgvector(vector), k),
                )
                contents = [r[0] for r in cur.fetchall()]
        finally:
            if own_conn:
                conn.close()
    except Exception as e:
        logger.warning(f"⚠️ Sélection sémantique des exemples indisponible : {e}")
        return ""

    blocs = []
    for content in contents:
        a = _EXAMPLES_BY_Q.get(_normalize(content))
        if a:
            blocs.append(f"Question : {content}\n{a}")
    return "\n\n".join(blocs)


def _feedback_fewshot_enabled() -> bool:
    return os.getenv("AI_FEEDBACK_FEWSHOT_ENABLED", "true").strip().lower() in ("1", "true", "yes", "on")


def _select_validated_examples(question: str, k: int, conn) -> list:
    """
    Few-shots VIVANTS : requêtes validées par l'usage (ai_query_log.feedback='up'),
    les plus proches sémantiquement (l'embedding de la question est déjà stocké).
    Renvoie une liste de (question, bloc_formaté). [] si désactivé / indisponible.
    """
    if not _feedback_fewshot_enabled() or conn is None:
        return []
    vector = embed(question)
    if vector is None:
        return []
    try:
        with conn.cursor() as cur:
            cur.execute(
                """
                SELECT question, sql_genere
                FROM public.ai_query_log
                WHERE feedback = 'up' AND embedding IS NOT NULL
                  AND sql_genere IS NOT NULL AND question IS NOT NULL
                ORDER BY embedding <=> %s::vector
                LIMIT %s
                """,
                (to_pgvector(vector), k),
            )
            rows = cur.fetchall()
    except Exception as e:
        logger.warning(f"⚠️ Few-shots validés (pouce-haut) indisponibles : {e}")
        return []
    blocs = []
    for q, sql in rows:
        q = (q or "").strip()
        reponse = json.dumps({"sql": sql, "explication": ""}, ensure_ascii=False)
        blocs.append((q, f"Question : {q}\n{reponse}"))
    return blocs


def _select_examples(question: str, k: int = NB_EXEMPLES, conn=None) -> str:
    """
    Renvoie les k exemples les plus proches. Priorité aux few-shots VALIDÉS par
    l'usage (pouce-haut), complétés par le dataset statique (sémantique, repli
    lexical), sans doublon de question.
    """
    if not _normalize(question).split():
        return ""

    valides = _select_validated_examples(question, k, conn)
    vus = {_normalize(q) for q, _b in valides}
    blocs = [b for _q, b in valides]

    if len(blocs) < k and _EXAMPLES:
        statiques = _select_examples_semantic(question, k, conn) or _select_examples_lexical(question, k)
        for bloc in statiques.split("\n\n"):
            if not bloc.strip():
                continue
            qline = bloc.split("\n", 1)[0].replace("Question :", "").strip()
            if _normalize(qline) in vus:
                continue
            vus.add(_normalize(qline))
            blocs.append(bloc)
            if len(blocs) >= k:
                break

    return "\n\n".join(blocs[:k])


# --------------------------------------------------------------------------- #
# API publique
# --------------------------------------------------------------------------- #
def get_socle() -> str:
    """Partie STABLE du prompt (préfixe). Fournie au keep-warm pour que le cache
    KV d'Ollama garde ce préfixe chaud : seul le suffixe dynamique est ré-évalué."""
    return SOCLE_HEAD


def _kg_enabled() -> bool:
    return os.getenv("AI_KG_ENABLED", "true").strip().lower() in ("1", "true", "yes", "on")


def _knowledge_enabled() -> bool:
    return os.getenv("AI_KNOWLEDGE_ENABLED", "true").strip().lower() in ("1", "true", "yes", "on")


def _connaissances_block(question: str, tables, conn) -> str:
    """Bloc CONNAISSANCES METIER : cards granulaires (si activées) avec repli sur
    les packs de domaine. Toute erreur cards -> repli packs."""
    bloc = ""
    if _knowledge_enabled():
        try:
            bloc = build_knowledge_block(question, tables, conn)
        except Exception as e:
            logger.warning(f"⚠️ Knowledge cards indisponibles, repli packs : {e}")
    return bloc or build_skill_block(question)


def build_dynamic_prompt(question: str, conn=None) -> str:
    """
    Construit le system prompt complet pour `question` :
    SOCLE stable + schéma ciblé + sous-graphe de jointures (DDIC) + connaissances
    métier (cards/packs) + few-shots + consigne finale. Une seule connexion partagée
    et un seul appel à retrieve_tables (réutilisé partout).
    """
    if conn is None:
        with get_db_connection() as c:
            return build_dynamic_prompt(question, c)

    tables = retrieve_tables(question, conn)
    schema = build_schema_block(question, conn, tables=tables)
    subgraph = get_relevant_subgraph(question, tables, conn) if _kg_enabled() else ""
    connaissances = _connaissances_block(question, tables, conn)
    exemples = _select_examples(question, k=get_budget()["nb_exemples"], conn=conn)

    parties = [SOCLE_HEAD,
               "=== TABLES PERTINENTES (schema reel, colonnes exactes) ===\n" + schema]
    if subgraph:
        parties.append("=== JOINTURES (cles etrangeres DDIC) ===\n" + subgraph)
    if connaissances:
        parties.append("=== CONNAISSANCES METIER (jointures, valeurs, modeles) ===\n" + connaissances)
    if exemples:
        parties.append("=== EXEMPLES ===\n" + exemples)
    parties.append(SOCLE_TAIL)
    return "\n\n".join(parties)


if __name__ == "__main__":
    # Test autonome (sur le serveur) :
    #   python -m services.ai_prompt_builder "donne moi une facture fournisseur"
    import sys
    logging.basicConfig(level=logging.INFO)
    q = sys.argv[1] if len(sys.argv) > 1 else "donne moi une facture fournisseur"
    prompt = build_dynamic_prompt(q)
    print("\n" + "=" * 70)
    print(prompt)
    print("=" * 70)
    print(f"\nLongueur : {len(prompt)} caracteres (~{round(len(prompt)/3.2)} tokens estimes)")
