# -*- coding: utf-8 -*-
"""
ai_config — API de suivi (et, en phase E2, d'édition) de la configuration qui
alimente les prompts de l'Assistant IA :
  - associations mot-clé ↔ table (DOMAIN_TABLES)
  - packs de connaissances (jointures / enums / règles / patterns / définitions)
  - cards dérivées, few-shots, réglages
  - INSPECTEUR : pour une question, ce qui sera réellement injecté dans le prompt.

Phase E1 = LECTURE seule + inspecteur (aucun changement de schéma). Les sources sont
lues telles quelles depuis le code / les fichiers via les modules du pipeline.
"""

import os
import re
import json
import logging
import threading

from flask import Blueprint, request, jsonify
from flask_jwt_extended import jwt_required

from config.settings import Config
from config.database import get_db_connection

from services.ai_schema_retriever import (
    get_domain_tables, retrieve_tables, build_schema_block, detect_domains, _normalize,
)
from services.ai_knowledge_graph import get_relevant_subgraph
from services.knowledge_service import iter_cards, build_knowledge_block
from services.ai_config_store import invalidate as _invalider_cache
from services.sql_guard import validate_and_wrap, SqlGuardError
from services import ai_prompt_builder as apb

logger = logging.getLogger(__name__)

ai_config_blueprint = Blueprint("ai_config", __name__)


# --------------------------------------------------------------------------- #
# Sérialisation des sources de config
# --------------------------------------------------------------------------- #
def _domains_payload() -> list:
    """Associations mot-clé->tables. Renvoie l'id DB (éditable) si la table est
    peuplée, sinon le défaut codé (id=None, non éditable tant que pas seedé)."""
    try:
        with get_db_connection() as conn:
            with conn.cursor() as cur:
                cur.execute(
                    """SELECT id, domain_id, keywords, tables, position, actif
                       FROM public.ai_domain_tables ORDER BY position, id"""
                )
                rows = cur.fetchall()
        if rows:
            return [{
                "id": r[0], "domain_id": r[1], "keywords": r[2] or [],
                "tables": r[3] or [], "position": r[4], "actif": r[5],
            } for r in rows]
    except Exception:
        pass
    return [{
        "id": None, "domain_id": domain_id, "keywords": sorted(declencheurs),
        "tables": list(tables), "position": i, "actif": True,
    } for i, (domain_id, declencheurs, tables) in enumerate(get_domain_tables())]


def _packs_payload() -> list:
    """Packs (DB éditable ou fichiers) + nb de cards dérivées par domaine."""
    cards = iter_cards()
    par_domaine = {}
    for c in cards:
        par_domaine[c["domain"]] = par_domaine.get(c["domain"], 0) + 1
    packs = []
    for domain, pack in sorted(apb.get_skills().items()):
        packs.append({
            "domain": domain,
            "keywords": pack.get("keywords", []),
            "synonyms": pack.get("synonyms", []),
            "tables": pack.get("tables", []),
            "joins": pack.get("joins", []),
            "enums": pack.get("enums", []),
            "rules": pack.get("rules", []),
            "docs": pack.get("docs", []),
            "patterns": pack.get("patterns", []),
            "nb_cards": par_domaine.get(domain, 0),
        })
    return packs


# --------------------------------------------------------------------------- #
# Lecture
# --------------------------------------------------------------------------- #
@ai_config_blueprint.route("/overview", methods=["GET"])
@jwt_required()
def overview():
    """Réglages AI_* + compteurs des sources de prompt."""
    reglages = {
        "OLLAMA_MODEL": Config.OLLAMA_MODEL,
        "AI_NUM_CTX": int(os.getenv("AI_NUM_CTX", "4096")),
        "AI_COT_ENABLED": Config.AI_COT_ENABLED,
        "AI_NUM_PREDICT_COT": Config.AI_NUM_PREDICT_COT,
        "AI_SKILL_ENABLED": Config.AI_SKILL_ENABLED,
        "AI_SKILL_MAX_PACKS": Config.AI_SKILL_MAX_PACKS,
        "AI_SKILL_MAX_CHARS": Config.AI_SKILL_MAX_CHARS,
        "AI_KNOWLEDGE_ENABLED": Config.AI_KNOWLEDGE_ENABLED,
        "AI_KNOWLEDGE_MAX_CHARS": Config.AI_KNOWLEDGE_MAX_CHARS,
        "AI_KG_ENABLED": Config.AI_KG_ENABLED,
        "AI_FEEDBACK_FEWSHOT_ENABLED": Config.AI_FEEDBACK_FEWSHOT_ENABLED,
        "AI_CACHE_ENABLED": Config.AI_CACHE_ENABLED,
        "AI_SELFHEAL_ENABLED": Config.AI_SELFHEAL_ENABLED,
        "AI_EMBED_ENABLED": Config.AI_EMBED_ENABLED,
    }
    compteurs = {
        "domaines": len(get_domain_tables()),
        "packs": len(apb.get_skills()),
        "cards": len(iter_cards()),
        "few_shots": len(apb._EXAMPLES),
    }
    return jsonify({"reglages": reglages, "compteurs": compteurs}), 200


@ai_config_blueprint.route("/domains", methods=["GET"])
@jwt_required()
def domains():
    return jsonify({"domains": _domains_payload()}), 200


@ai_config_blueprint.route("/packs", methods=["GET"])
@jwt_required()
def packs():
    return jsonify({"packs": _packs_payload()}), 200


@ai_config_blueprint.route("/examples", methods=["GET"])
@jwt_required()
def examples():
    try:
        limit = max(1, min(500, int(request.args.get("limit", 100))))
    except (TypeError, ValueError):
        limit = 100
    items = [{"question": q, "reponse": a} for q, a, _m in apb._EXAMPLES[:limit]]
    return jsonify({"total": len(apb._EXAMPLES), "items": items}), 200


@ai_config_blueprint.route("/usage", methods=["GET"])
@jwt_required()
def usage():
    """Signal d'usage : votes feedback + top co-occurrences + résultats 30 j."""
    feedback = {"up": 0, "down": 0}
    cooccurrences = []
    erreurs_30j = []
    try:
        with get_db_connection() as conn:
            with conn.cursor() as cur:
                cur.execute(
                    "SELECT feedback, COUNT(*) FROM public.ai_query_log "
                    "WHERE feedback IS NOT NULL GROUP BY feedback"
                )
                for vote, n in cur.fetchall():
                    feedback[vote] = n
            try:
                with conn.cursor() as cur:
                    cur.execute(
                        "SELECT src_table, dst_table, poids FROM public.ai_table_cooccurrence "
                        "ORDER BY poids DESC LIMIT 25"
                    )
                    cooccurrences = [
                        {"src": s, "dst": d, "poids": p} for s, d, p in cur.fetchall()
                    ]
            except Exception:
                cooccurrences = []  # table 018 absente
            # Répartition succès/erreurs par type sur 30 j : mesure l'impact des
            # améliorations (filet SQL, RAG élargi, clean_data, auto-correction).
            # Requête SANS paramètres -> les % littéraux des ILIKE passent tels quels.
            try:
                with conn.cursor() as cur:
                    cur.execute(
                        """
                        SELECT CASE
                                 WHEN statut = 'rejete' THEN 'rejet_sql_guard'
                                 WHEN raison_rejet ILIKE '%délai imparti%'
                                   OR raison_rejet ILIKE '%delai imparti%' THEN 'timeout_modele'
                                 WHEN raison_rejet ILIKE '%does not exist%' THEN 'colonne_ou_table_inexistante'
                                 WHEN raison_rejet ILIKE '%JSON exploitable%' THEN 'json_modele'
                                 WHEN statut = 'succes' THEN 'succes'
                                 ELSE 'autre_erreur'
                               END AS type_resultat,
                               count(*) AS nb
                        FROM public.ai_query_log
                        WHERE date_creation >= CURRENT_TIMESTAMP - INTERVAL '30 days'
                        GROUP BY 1
                        ORDER BY nb DESC
                        """
                    )
                    erreurs_30j = [{"type": t, "nb": n} for t, n in cur.fetchall()]
            except Exception:
                erreurs_30j = []
    except Exception as e:
        return jsonify({"statut": "erreur", "raison": str(e)}), 500
    return jsonify({
        "feedback": feedback,
        "cooccurrences": cooccurrences,
        "erreurs_30j": erreurs_30j,
    }), 200


# --------------------------------------------------------------------------- #
# Inspecteur de prompt
# --------------------------------------------------------------------------- #
@ai_config_blueprint.route("/inspect", methods=["POST"])
@jwt_required()
def inspect():
    """
    Pour une question, renvoie CE QUI SERA INJECTÉ dans le prompt : domaines
    déclenchés, tables retrouvées, schéma, sous-graphe de jointures, connaissances
    (cards/packs), few-shots, prompt complet + estimation de tokens.
    Réutilise les sous-fonctions de build_dynamic_prompt (assemblage identique).
    """
    body = request.get_json(silent=True) or {}
    question = (body.get("question") or "").strip()
    if not question:
        return jsonify({"statut": "erreur", "raison": "Question vide."}), 400

    try:
        with get_db_connection() as conn:
            domaines = detect_domains(question)
            tables = retrieve_tables(question, conn)
            schema = build_schema_block(question, conn, tables=tables)
            subgraph = get_relevant_subgraph(question, tables, conn) if apb._kg_enabled() else ""
            connaissances = apb._connaissances_block(question, tables, conn)
            exemples = apb._select_examples(question, conn=conn)

            parties = [apb.get_socle(),
                       "=== TABLES PERTINENTES (schema reel, colonnes exactes) ===\n" + schema]
            if subgraph:
                parties.append("=== JOINTURES (cles etrangeres DDIC) ===\n" + subgraph)
            if connaissances:
                parties.append("=== CONNAISSANCES METIER (jointures, valeurs, modeles) ===\n" + connaissances)
            if exemples:
                parties.append("=== EXEMPLES ===\n" + exemples)
            parties.append(apb.SOCLE_TAIL)
            prompt = "\n\n".join(parties)
    except Exception as e:
        logger.error(f"❌ Inspecteur de prompt : {e}")
        return jsonify({"statut": "erreur", "raison": str(e)}), 500

    return jsonify({
        "question": question,
        "cot": apb._COT_ENABLED,
        "domaines": domaines,
        "tables": tables,
        "schema": schema,
        "subgraph": subgraph,
        "connaissances": connaissances,
        "exemples": exemples,
        "prompt": prompt,
        "tokens_estimes": round(len(prompt) / 3.2),
    }), 200


# --------------------------------------------------------------------------- #
# Édition (E2) — écrit dans ai_domain_tables / ai_packs (migration 019)
# --------------------------------------------------------------------------- #
@ai_config_blueprint.route("/domains", methods=["POST"])
@jwt_required()
def create_domain():
    body = request.get_json(silent=True) or {}
    domain_id = (body.get("domain_id") or "").strip()
    keywords = [str(k).strip() for k in (body.get("keywords") or []) if str(k).strip()]
    tables = [str(t).strip() for t in (body.get("tables") or []) if str(t).strip()]
    position = int(body.get("position", 999))
    if not domain_id or not keywords or not tables:
        return jsonify({"statut": "erreur", "raison": "domain_id, keywords et tables requis."}), 400
    try:
        with get_db_connection() as conn:
            with conn.cursor() as cur:
                cur.execute(
                    """INSERT INTO public.ai_domain_tables (domain_id, keywords, tables, position)
                       VALUES (%s, %s::jsonb, %s::jsonb, %s) RETURNING id""",
                    (domain_id, json.dumps(keywords), json.dumps(tables), position),
                )
                new_id = cur.fetchone()[0]
            conn.commit()
    except Exception as e:
        return jsonify({"statut": "erreur", "raison": str(e)}), 500
    _invalider_cache("domain_tables")
    return jsonify({"statut": "succes", "id": new_id}), 201


@ai_config_blueprint.route("/domains/<int:dom_id>", methods=["PUT"])
@jwt_required()
def update_domain(dom_id):
    body = request.get_json(silent=True) or {}
    domain_id = (body.get("domain_id") or "").strip()
    keywords = [str(k).strip() for k in (body.get("keywords") or []) if str(k).strip()]
    tables = [str(t).strip() for t in (body.get("tables") or []) if str(t).strip()]
    position = int(body.get("position", 0))
    actif = bool(body.get("actif", True))
    if not domain_id or not keywords or not tables:
        return jsonify({"statut": "erreur", "raison": "domain_id, keywords et tables requis."}), 400
    try:
        with get_db_connection() as conn:
            with conn.cursor() as cur:
                cur.execute(
                    """UPDATE public.ai_domain_tables
                       SET domain_id=%s, keywords=%s::jsonb, tables=%s::jsonb,
                           position=%s, actif=%s, date_maj=CURRENT_TIMESTAMP
                       WHERE id=%s""",
                    (domain_id, json.dumps(keywords), json.dumps(tables), position, actif, dom_id),
                )
                touched = cur.rowcount
            conn.commit()
    except Exception as e:
        return jsonify({"statut": "erreur", "raison": str(e)}), 500
    if not touched:
        return jsonify({"statut": "erreur", "raison": "Domaine introuvable."}), 404
    _invalider_cache("domain_tables")
    return jsonify({"statut": "succes"}), 200


@ai_config_blueprint.route("/domains/<int:dom_id>", methods=["DELETE"])
@jwt_required()
def delete_domain(dom_id):
    try:
        with get_db_connection() as conn:
            with conn.cursor() as cur:
                cur.execute("DELETE FROM public.ai_domain_tables WHERE id=%s", (dom_id,))
                touched = cur.rowcount
            conn.commit()
    except Exception as e:
        return jsonify({"statut": "erreur", "raison": str(e)}), 500
    if not touched:
        return jsonify({"statut": "erreur", "raison": "Domaine introuvable."}), 404
    _invalider_cache("domain_tables")
    return jsonify({"statut": "succes"}), 200


@ai_config_blueprint.route("/packs/<domain>", methods=["PUT"])
@jwt_required()
def upsert_pack(domain):
    """Crée/met à jour un pack. Valide chaque pattern SQL via sql_guard avant écriture."""
    content = request.get_json(silent=True) or {}
    if not isinstance(content, dict):
        return jsonify({"statut": "erreur", "raison": "Corps JSON attendu (objet pack)."}), 400
    # Validation des requêtes-types
    try:
        for p in content.get("patterns", []):
            sql = (p.get("sql") or "").strip()
            if sql:
                validate_and_wrap(sql, 1)
    except SqlGuardError as e:
        return jsonify({"statut": "rejete", "raison": f"Pattern SQL invalide : {e}"}), 400
    content.setdefault("domain", domain)
    try:
        with get_db_connection() as conn:
            with conn.cursor() as cur:
                cur.execute(
                    """INSERT INTO public.ai_packs (domain, content)
                       VALUES (%s, %s::jsonb)
                       ON CONFLICT (domain) DO UPDATE
                         SET content = EXCLUDED.content, date_maj = CURRENT_TIMESTAMP""",
                    (domain, json.dumps(content)),
                )
            conn.commit()
    except Exception as e:
        return jsonify({"statut": "erreur", "raison": str(e)}), 500
    _invalider_cache("packs")
    return jsonify({"statut": "succes",
                    "note": "Cards lexicales actives immédiatement ; lancez /reindex pour le classement sémantique."}), 200


@ai_config_blueprint.route("/packs/<domain>", methods=["DELETE"])
@jwt_required()
def delete_pack(domain):
    try:
        with get_db_connection() as conn:
            with conn.cursor() as cur:
                cur.execute("DELETE FROM public.ai_packs WHERE domain=%s", (domain,))
                touched = cur.rowcount
            conn.commit()
    except Exception as e:
        return jsonify({"statut": "erreur", "raison": str(e)}), 500
    if not touched:
        return jsonify({"statut": "erreur", "raison": "Pack introuvable."}), 404
    _invalider_cache("packs")
    return jsonify({"statut": "succes"}), 200


def _reindex_knowledge_async():
    try:
        from build_ai_index import index_knowledge
        with get_db_connection() as conn:
            index_knowledge(conn)
        logger.info("Réindexation des knowledge cards terminée.")
    except Exception as e:
        logger.error(f"❌ Réindexation knowledge échouée : {e}")


@ai_config_blueprint.route("/reindex", methods=["POST"])
@jwt_required()
def reindex():
    """Relance l'indexation sémantique des cards (embeddings) en tâche de fond."""
    threading.Thread(target=_reindex_knowledge_async, daemon=True).start()
    return jsonify({"statut": "demarre",
                    "note": "Réindexation lancée en arrière-plan (peut durer selon le nb de cards)."}), 202


# --------------------------------------------------------------------------- #
# Promotion d'une requête corrigée vers la config (depuis l'écran Résultats IA)
# --------------------------------------------------------------------------- #
@ai_config_blueprint.route("/detect", methods=["GET"])
@jwt_required()
def detect():
    """Domaines déclenchés par une question (pour pré-sélectionner la cible)."""
    q = (request.args.get("question") or "").strip()
    return jsonify({"domaines": detect_domains(q) if q else []}), 200


# Tables schéma-qualifiées (raw_data.x / clean_data.x / public.x) dans un SQL.
_QUALIFIED_RE = re.compile(
    r"\b((?:raw_data|clean_data|public)\.[a-zA-Z_][a-zA-Z0-9_]*)", re.IGNORECASE
)


@ai_config_blueprint.route("/promote", methods=["POST"])
@jwt_required()
def promote():
    """
    Promeut une requête corrigée vers la config éditable : ajoute son SQL comme
    requête-type (pattern) au pack du domaine, et (option) complète les tables du
    domaine. Pré-requis : config externalisée (seedée). SQL validé par sql_guard.
    """
    body = request.get_json(silent=True) or {}
    question = (body.get("question") or "").strip()
    sql = (body.get("sql") or "").strip()
    domain = (body.get("domain") or "").strip()
    intent = (body.get("intent") or question or "requête promue").strip()[:120]
    ajouter_mapping = bool(body.get("ajouter_mapping"))
    if not sql or not domain:
        return jsonify({"statut": "erreur", "raison": "domain et sql requis."}), 400

    try:
        validate_and_wrap(sql, 1)
    except SqlGuardError as e:
        return jsonify({"statut": "rejete", "raison": f"SQL invalide : {e}"}), 400

    try:
        with get_db_connection() as conn:
            with conn.cursor() as cur:
                cur.execute("SELECT (SELECT count(*) FROM public.ai_packs), "
                            "(SELECT count(*) FROM public.ai_domain_tables)")
                nb_packs, nb_dom = cur.fetchone()
            if not nb_packs or not nb_dom:
                return jsonify({
                    "statut": "erreur",
                    "raison": "Config IA non externalisée en base — lancez seed_ai_config.py.",
                }), 409

            # --- 1) Pattern dans le pack du domaine ---
            with conn.cursor() as cur:
                cur.execute("SELECT content FROM public.ai_packs WHERE domain=%s", (domain,))
                row = cur.fetchone()
            content = (row[0] if row and row[0] else {"domain": domain})
            patterns = content.get("patterns") or []
            pattern_ajoute = not any((p.get("sql") or "").strip() == sql for p in patterns)
            if pattern_ajoute:
                patterns.append({"intent": intent, "sql": sql})
                content["patterns"] = patterns
                content.setdefault("domain", domain)
                with conn.cursor() as cur:
                    cur.execute(
                        """INSERT INTO public.ai_packs (domain, content) VALUES (%s, %s::jsonb)
                           ON CONFLICT (domain) DO UPDATE
                             SET content = EXCLUDED.content, date_maj = CURRENT_TIMESTAMP""",
                        (domain, json.dumps(content)),
                    )

            # --- 2) Mapping mot-clé↔tables (option) ---
            tables_ajoutees = []
            if ajouter_mapping:
                vus, tables_sql = set(), []
                for m in _QUALIFIED_RE.finditer(sql):
                    t = m.group(1).lower()
                    if t not in vus:
                        vus.add(t)
                        tables_sql.append(t)
                if tables_sql:
                    with conn.cursor() as cur:
                        cur.execute(
                            "SELECT id, tables FROM public.ai_domain_tables "
                            "WHERE domain_id=%s ORDER BY position, id LIMIT 1", (domain,)
                        )
                        drow = cur.fetchone()
                        if drow:
                            did = drow[0]
                            existantes = [str(t).lower() for t in (drow[1] or [])]
                            manquantes = [t for t in tables_sql if t not in existantes]
                            if manquantes:
                                cur.execute(
                                    "UPDATE public.ai_domain_tables SET tables=%s::jsonb, "
                                    "date_maj=CURRENT_TIMESTAMP WHERE id=%s",
                                    (json.dumps(existantes + manquantes), did),
                                )
                                tables_ajoutees = manquantes
                        else:
                            kws = [w for w in _normalize(question).replace("-", " ").split()
                                   if len(w) >= 4][:8]
                            cur.execute(
                                "INSERT INTO public.ai_domain_tables (domain_id, keywords, tables, position) "
                                "VALUES (%s, %s::jsonb, %s::jsonb, %s)",
                                (domain, json.dumps(kws), json.dumps(tables_sql), 999),
                            )
                            tables_ajoutees = tables_sql
            conn.commit()
    except Exception as e:
        logger.error(f"❌ promote : {e}")
        return jsonify({"statut": "erreur", "raison": str(e)}), 500

    _invalider_cache()
    return jsonify({
        "statut": "succes",
        "pattern_ajoute": pattern_ajoute,
        "tables_ajoutees": tables_ajoutees,
        "note": "Cards lexicales actives immédiatement ; lancez « Réindexer » pour le sémantique.",
    }), 200
