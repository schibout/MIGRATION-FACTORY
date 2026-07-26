"""
API Assistant IA — Blueprint /api/v1/ai

Pipeline en deux temps (cf. docs/AssistantIA.md) :
  question (FR) -> Ollama (SQL) -> sql_guard (validation) -> readonly_ai (exécution)
  -> résultats. PAS de synthèse en langage naturel par le modèle (trop lent).

Toutes les routes sont protégées par JWT ; l'identité alimente le journal
public.ai_query_log (succès, erreurs, rejets).
"""

import io
import time
import logging
from datetime import datetime, date
from decimal import Decimal

import pandas as pd
from flask import Blueprint, request, jsonify, make_response
from flask_jwt_extended import jwt_required, get_jwt_identity

from config.database import get_db_connection
from config.ai_system_prompt import get_system_prompt
from services.ai_prompt_builder import build_dynamic_prompt
from services.sql_guard import validate_and_wrap, SqlGuardError
from services.sql_filters import strip_technical_filters
from services.ai_readonly_db import run_readonly_query
from services.llm_service import (
    generate_sql,
    repair_sql,
    check_health,
    LLMBusyError,
    LLMUnavailableError,
    LLMError,
)
from services import ai_semantic_cache
from config.settings import Config

logger = logging.getLogger(__name__)

ai_blueprint = Blueprint("ai_assistant", __name__)


# --------------------------------------------------------------------------- #
# Helpers
# --------------------------------------------------------------------------- #
def _jsonable(value):
    """Rend une valeur SQL sérialisable en JSON (Decimal, dates, NaN)."""
    if value is None:
        return None
    if isinstance(value, Decimal):
        return float(value)
    if isinstance(value, (datetime, date)):
        return value.isoformat()
    if isinstance(value, float) and pd.isna(value):
        return None
    return value


def _sanitize_rows(lignes):
    return [{k: _jsonable(v) for k, v in row.items()} for row in lignes]


def _log_query(utilisateur, question, sql_genere, statut,
               raison_rejet=None, template_id=None, duree_ms=None, nb_lignes=None):
    """
    Journalise une requête dans public.ai_query_log (rôle applicatif principal).
    Renvoie l'id du log, ou None en cas d'échec d'écriture (non bloquant).
    """
    try:
        with get_db_connection() as conn:
            with conn.cursor() as cur:
                cur.execute(
                    """
                    INSERT INTO public.ai_query_log
                        (utilisateur, question, sql_genere, statut, raison_rejet,
                         template_id, duree_ms, nb_lignes)
                    VALUES (%s, %s, %s, %s, %s, %s, %s, %s)
                    RETURNING id
                    """,
                    (
                        (str(utilisateur) if utilisateur else None),
                        question, sql_genere, statut, raison_rejet,
                        template_id, duree_ms, nb_lignes,
                    ),
                )
                new_id = cur.fetchone()[0]
            conn.commit()
            return new_id
    except Exception as e:  # la journalisation ne doit jamais casser la réponse
        logger.error(f"⚠️ Échec d'écriture dans ai_query_log : {e}")
        return None


def _mark_feedback_up(id_log) -> bool:
    """Marque une entrée ai_query_log comme 'up' (bonne réponse). Best-effort :
    un échec ne doit pas casser la réponse. Renvoie True si la ligne a été mise à jour."""
    try:
        with get_db_connection() as conn:
            with conn.cursor() as cur:
                cur.execute(
                    """UPDATE public.ai_query_log
                       SET feedback = 'up', feedback_date = CURRENT_TIMESTAMP
                       WHERE id = %s""",
                    (id_log,),
                )
                touched = cur.rowcount
            conn.commit()
            return bool(touched)
    except Exception as e:
        logger.warning(f"⚠️ Auto-marquage 'up' impossible (id_log={id_log}) : {e}")
        return False


# Tables réellement exposées à l'assistant (cf. ai_system_prompt). Sert à
# produire un message clair quand le modèle invente une table/colonne.
_TABLES_CONNUES = (
    "raw_data.lfa1, raw_data.mara, raw_data.marc, raw_data.mard, "
    "raw_data.makt, clean_data.mapping_codification_articles"
)


def _friendly_db_error(e) -> str:
    """
    Transforme une erreur d'exécution PostgreSQL en message lisible (FR).
    Détecte notamment les tables/colonnes inexistantes (hallucination du modèle).
    """
    orig = getattr(e, "orig", None)
    # e peut être une erreur SQLAlchemy (pgcode dans .orig) ou psycopg2 brute (.pgcode)
    pgcode = getattr(orig, "pgcode", None) or getattr(e, "pgcode", None)
    if pgcode == "42P01":   # undefined_table
        return ("La requête fait référence à une table qui n'existe pas. "
                f"L'assistant ne connaît que ces tables : {_TABLES_CONNUES}. "
                "Reformulez votre question en restant sur ces données.")
    if pgcode == "42703":   # undefined_column
        return ("La requête fait référence à une colonne qui n'existe pas. "
                "Reformulez votre question (l'assistant a peut-être deviné un nom de champ).")
    if pgcode == "42601":   # syntax_error
        return "Le SQL généré contient une erreur de syntaxe. Reformulez votre question."
    if pgcode == "57014":   # query_canceled (statement_timeout)
        return "La requête a dépassé le délai autorisé (30 s). Affinez les filtres."
    # Repli générique
    return "Échec d'exécution de la requête. " + str(e)


def _execute_and_pack(utilisateur, question, raw_sql, *, max_rows,
                      explication="", template_id=None,
                      system_prompt=None, _repair_done=False):
    """
    Valide -> exécute -> journalise. Renvoie un tuple (payload, http_status).
    Utilisé par le pipeline ``process_question`` (chemin Ollama et chemin cache).

    Auto-correction (C) : si `system_prompt` est fourni et que l'exécution échoue
    sur une erreur de schéma/syntaxe (colonne/table inexistante), on demande UNE
    correction au modèle puis on ré-exécute (récursion bornée par `_repair_done`).
    """
    t0 = time.time()

    # 1) Validation + bornage
    try:
        safe_sql = validate_and_wrap(raw_sql, max_rows)
    except SqlGuardError as e:
        raison = str(e)
        _log_query(utilisateur, question, raw_sql, "rejete",
                   raison_rejet=raison, template_id=template_id)
        # On renvoie le SQL généré même en échec : il est ainsi conservé dans
        # l'historique conversationnel et affichable côté chat.
        return ({"statut": "rejete", "raison": raison, "sql": raw_sql}, 400)

    # 2) Exécution via le rôle readonly_ai
    try:
        colonnes, lignes = run_readonly_query(safe_sql)
    except Exception as e:
        # 2bis) Tentative d'auto-correction (une seule fois) sur erreur de schéma
        pgcode = getattr(getattr(e, "orig", None), "pgcode", None) or getattr(e, "pgcode", None)
        if (system_prompt and not _repair_done
                and getattr(Config, "AI_SELFHEAL_ENABLED", True)
                and pgcode in {"42703", "42P01", "42601"}):
            repaired = _try_repair(question, system_prompt, raw_sql, str(e))
            if repaired:
                logger.info(f"🔧 Auto-correction SQL déclenchée (pgcode {pgcode}).")
                return _execute_and_pack(
                    utilisateur, question, repaired, max_rows=max_rows,
                    explication=explication, template_id=template_id,
                    system_prompt=system_prompt, _repair_done=True,
                )

        logger.error(f"❌ Erreur d'exécution SQL IA : {e}")
        message = _friendly_db_error(e)
        duree_ms = int((time.time() - t0) * 1000)
        _log_query(utilisateur, question, raw_sql, "erreur",
                   raison_rejet=str(e)[:500], template_id=template_id, duree_ms=duree_ms)
        # SQL conservé même en échec (historique + affichage chat).
        return ({"statut": "erreur", "raison": message, "sql": raw_sql, "duree_ms": duree_ms}, 400)

    lignes = _sanitize_rows(lignes)
    duree_ms = int((time.time() - t0) * 1000)
    tronque = len(lignes) >= max_rows

    id_log = _log_query(utilisateur, question, raw_sql, "succes",
                        template_id=template_id, duree_ms=duree_ms, nb_lignes=len(lignes))

    return ({
        "statut": "succes",
        "id_log": id_log,
        "sql": raw_sql,
        "explication": explication,
        "colonnes": colonnes,
        "lignes": lignes,
        "duree_ms": duree_ms,
        "tronque": tronque,
    }, 200)


def _try_repair(question, system_prompt, bad_sql, erreur):
    """Appelle le modèle pour corriger un SQL fautif, en lui fournissant les
    colonnes RÉELLES des tables référencées (le message d'erreur PG seul le
    laisse re-deviner). Renvoie le SQL corrigé ou None (best-effort : toute
    erreur du modèle est absorbée)."""
    try:
        from services.ai_schema_retriever import schema_for_sql
        bloc = schema_for_sql(bad_sql)
        if bloc:
            erreur = (f"{erreur}\nSCHEMA REEL des tables utilisees "
                      f"(seules colonnes valides) :\n{bloc}")
    except Exception as e:
        logger.debug(f"Auto-correction : schéma réel indisponible ({e})")
    try:
        fix = repair_sql(question, system_prompt, bad_sql, erreur)
        sql = strip_technical_filters((fix or {}).get("sql") or "")
        return sql or None
    except (LLMBusyError, LLMUnavailableError, LLMError) as e:
        logger.warning(f"⚠️ Auto-correction indisponible : {e}")
        return None
    except Exception as e:
        logger.warning(f"⚠️ Auto-correction : échec inattendu : {e}")
        return None



# --------------------------------------------------------------------------- #
# Historique conversationnel (public.ai_conversations / public.ai_messages)
# --------------------------------------------------------------------------- #
def _resolve_conversation(cur, utilisateur, conversation_id, question):
    """Renvoie un id de conversation : l'existante (si elle appartient à
    l'utilisateur, date_maj rafraîchie) ou une nouvelle (titre = question)."""
    if conversation_id:
        cur.execute(
            "UPDATE public.ai_conversations SET date_maj = CURRENT_TIMESTAMP "
            "WHERE id = %s AND utilisateur = %s RETURNING id",
            (conversation_id, str(utilisateur)),
        )
        row = cur.fetchone()
        if row:
            return row[0]
    titre = (question or "Conversation").strip()[:80]
    cur.execute(
        "INSERT INTO public.ai_conversations (utilisateur, titre) VALUES (%s, %s) RETURNING id",
        (str(utilisateur), titre),
    )
    return cur.fetchone()[0]


def _persist_exchange(utilisateur, conversation_id, question, payload):
    """
    Persiste un échange (message utilisateur + message assistant) dans
    l'historique. Renvoie l'id de conversation, ou None si l'écriture échoue
    (non bloquant : l'historique ne doit jamais casser la réponse).
    """
    try:
        with get_db_connection() as conn:
            with conn.cursor() as cur:
                conv_id = _resolve_conversation(cur, utilisateur, conversation_id, question)
                cur.execute(
                    "INSERT INTO public.ai_messages (conversation_id, role, contenu) "
                    "VALUES (%s, 'user', %s)",
                    (conv_id, question),
                )
                lignes = payload.get("lignes")
                cur.execute(
                    """INSERT INTO public.ai_messages
                           (conversation_id, role, contenu, statut, sql_genere,
                            nb_lignes, tronque, duree_ms, id_log)
                       VALUES (%s, 'assistant', %s, %s, %s, %s, %s, %s, %s)""",
                    (
                        conv_id,
                        payload.get("explication") or payload.get("raison"),
                        payload.get("statut"),
                        payload.get("sql"),
                        len(lignes) if lignes is not None else payload.get("nb_lignes"),
                        payload.get("tronque"),
                        payload.get("duree_ms"),
                        payload.get("id_log"),
                    ),
                )
            conn.commit()
            return conv_id
    except Exception as e:
        logger.error(f"⚠️ Échec persistance historique chat : {e}")
        return None


# --------------------------------------------------------------------------- #
# Pipeline de traitement (exécuté par le worker d'arrière-plan)
# --------------------------------------------------------------------------- #
def process_question(utilisateur, question, conversation_id):
    """
    Pipeline complet d'une question : cache sémantique -> Ollama -> validation ->
    exécution -> journalisation -> persistance conversationnelle.

    Conçu pour être appelé par le worker d'arrière-plan (services.ai_job_worker) :
    ne dépend PAS du contexte de requête Flask. Renvoie ``(payload, conv_id)`` où
    ``payload`` reprend les mêmes clés que la réponse synchrone historique de
    ``/ask`` (statut, sql, colonnes, lignes, ...).
    """
    question = (question or "").strip()
    max_rows = int(getattr(Config, "AI_MAX_ROWS", 500))

    # Cache sémantique (B) : si une question passée à succès est sémantiquement
    # très proche, on réutilise son SQL sans rappeler Ollama. Le SQL repasse par
    # sql_guard et s'exécute via readonly_ai -> données fraîches et sûres.
    cache_hit = None
    try:
        cache_hit = ai_semantic_cache.lookup(question)
    except Exception as e:
        logger.warning(f"⚠️ Cache sémantique : lookup ignoré ({e}).")

    if cache_hit:
        payload, _status = _execute_and_pack(
            utilisateur, question, cache_hit["sql"],
            max_rows=max_rows,
            explication="Réponse réutilisée d'une question similaire (cache).",
        )
        if payload.get("statut") == "succes":
            payload["source"] = "cache"
            payload["cache_similarity"] = round(cache_hit["similarity"], 3)
            ai_semantic_cache.store(payload.get("id_log"), question,
                                    vector=cache_hit.get("vector"))
            conv_id = _persist_exchange(utilisateur, conversation_id, question, payload)
            return payload, conv_id
        # Le SQL caché ne passe plus (schéma modifié) : on régénère normalement.
        logger.info("Cache HIT invalide à l'exécution -> régénération via Ollama.")

    # Construction du prompt RAG (schéma ciblé + few-shots). Repli sur le prompt
    # statique si la construction échoue (ex. accès dictionnaire indisponible),
    # pour ne jamais casser l'assistant.
    try:
        system_prompt = build_dynamic_prompt(question)
    except Exception as e:
        logger.warning(f"⚠️ Prompt RAG indisponible, repli sur le prompt statique : {e}")
        system_prompt = get_system_prompt()

    # Génération du SQL par le modèle local
    try:
        gen = generate_sql(question, system_prompt)
    except LLMBusyError as e:
        payload = {"statut": "occupe", "raison": str(e)}
        conv_id = _persist_exchange(utilisateur, conversation_id, question, payload)
        return payload, conv_id
    except LLMUnavailableError as e:
        payload = {"statut": "indisponible", "raison": str(e)}
        _log_query(utilisateur, question, None, "erreur", raison_rejet=str(e))
        conv_id = _persist_exchange(utilisateur, conversation_id, question, payload)
        return payload, conv_id
    except LLMError as e:
        payload = {"statut": "erreur", "raison": str(e)}
        _log_query(utilisateur, question, None, "erreur", raison_rejet=str(e))
        conv_id = _persist_exchange(utilisateur, conversation_id, question, payload)
        return payload, conv_id

    # Filet de sécurité : le modèle ajoute parfois des filtres techniques SAP
    # (mandt/loevm/…) malgré le SOCLE -> erreur 42703. On les retire avant
    # validation/exécution (aligné sur la décision « SQL simple », cf. sql_filters).
    sql_genere = strip_technical_filters(gen["sql"])
    payload, _status = _execute_and_pack(
        utilisateur, question, sql_genere,
        max_rows=max_rows,
        explication=gen.get("explication", ""),
        system_prompt=system_prompt,
    )
    # Mémorise l'embedding de la question réussie pour alimenter le cache.
    if payload.get("statut") == "succes":
        ai_semantic_cache.store(payload.get("id_log"), question)
    conv_id = _persist_exchange(utilisateur, conversation_id, question, payload)
    return payload, conv_id


# --------------------------------------------------------------------------- #
# Routes
# --------------------------------------------------------------------------- #
@ai_blueprint.route("/ask", methods=["POST"])
@jwt_required()
def ask():
    """
    Enregistre la question comme job d'arrière-plan et renvoie son identifiant.

    Le traitement (génération Ollama, souvent long sur CPU) est effectué par le
    worker (services.ai_job_worker) : la requête HTTP retourne immédiatement
    (plus de timeout côté navigateur). Le client interroge ensuite
    ``GET /ai/jobs/<id>`` pour récupérer le résultat.
    """
    utilisateur = get_jwt_identity()
    body = request.get_json(silent=True) or {}
    question = (body.get("question") or "").strip()
    conversation_id = body.get("conversation_id")  # None => nouvelle conversation
    if not question:
        return jsonify({"statut": "erreur", "raison": "Question vide."}), 400

    try:
        with get_db_connection() as conn:
            with conn.cursor() as cur:
                cur.execute(
                    """INSERT INTO public.ai_jobs
                           (utilisateur, question, conversation_id, statut)
                       VALUES (%s, %s, %s, 'en_attente')
                       RETURNING id""",
                    (str(utilisateur), question, conversation_id),
                )
                job_id = cur.fetchone()[0]
            conn.commit()
    except Exception as e:
        logger.error(f"❌ Échec de création du job IA : {e}")
        return jsonify({"statut": "erreur",
                        "raison": "Impossible d'enregistrer la demande."}), 500

    return jsonify({
        "statut": "en_attente",
        "job_id": job_id,
        "conversation_id": conversation_id,
    }), 202


@ai_blueprint.route("/jobs/<int:job_id>", methods=["GET"])
@jwt_required()
def get_job(job_id):
    """
    État d'un job IA. Tant qu'il n'est pas terminé : statut 'en_attente' ou
    'en_cours'. Quand statut='termine', la clé 'resultat' contient le payload
    final (mêmes clés que l'ancienne réponse synchrone de /ask).
    """
    utilisateur = get_jwt_identity()
    try:
        with get_db_connection() as conn:
            with conn.cursor() as cur:
                cur.execute(
                    """SELECT id, statut, resultat, conversation_id, erreur,
                              date_creation, date_debut, date_fin
                       FROM public.ai_jobs
                       WHERE id = %s AND utilisateur = %s""",
                    (job_id, str(utilisateur)),
                )
                row = cur.fetchone()
    except Exception as e:
        return jsonify({"statut": "erreur", "raison": str(e)}), 500

    if not row:
        return jsonify({"statut": "erreur", "raison": "Job introuvable."}), 404

    cols = ["id", "statut", "resultat", "conversation_id", "erreur",
            "date_creation", "date_debut", "date_fin"]
    job = dict(zip(cols, row))
    for k in ("date_creation", "date_debut", "date_fin"):
        if isinstance(job.get(k), (datetime, date)):
            job[k] = job[k].isoformat()
    return jsonify(job), 200


@ai_blueprint.route("/jobs", methods=["GET"])
@jwt_required()
def list_jobs():
    """
    Jobs récents de l'utilisateur. Par défaut (``actifs=true``) : seulement ceux
    non terminés — sert à la reprise du suivi côté frontend après un
    rechargement de page.
    """
    utilisateur = get_jwt_identity()
    actifs = request.args.get("actifs", "true").lower() == "true"
    where = "WHERE utilisateur = %s"
    params = [str(utilisateur)]
    if actifs:
        where += " AND statut IN ('en_attente', 'en_cours')"
    try:
        with get_db_connection() as conn:
            with conn.cursor() as cur:
                cur.execute(
                    f"""SELECT id, question, statut, conversation_id, date_creation
                        FROM public.ai_jobs
                        {where}
                        ORDER BY date_creation DESC
                        LIMIT 50""",
                    params,
                )
                cols = [d[0] for d in cur.description]
                rows = [dict(zip(cols, r)) for r in cur.fetchall()]
    except Exception as e:
        return jsonify({"statut": "erreur", "raison": str(e)}), 500
    for r in rows:
        if isinstance(r.get("date_creation"), (datetime, date)):
            r["date_creation"] = r["date_creation"].isoformat()
    return jsonify({"jobs": rows}), 200


@ai_blueprint.route("/export", methods=["POST"])
@jwt_required()
def export():
    """
    Réexécute le SQL d'un log existant (re-validé par sql_guard, LIMIT élargi)
    et renvoie un fichier. Le format est choisi par le champ ``format`` du corps :
    'xlsx' (défaut) ou 'csv'.
    """
    body = request.get_json(silent=True) or {}
    id_log = body.get("id_log")
    fmt = (body.get("format") or "xlsx").lower()
    if fmt not in ("xlsx", "csv"):
        fmt = "xlsx"
    if not id_log:
        return jsonify({"statut": "erreur", "raison": "id_log requis."}), 400

    # Récupère le SQL d'origine depuis le journal (statut succès uniquement)
    try:
        with get_db_connection() as conn:
            with conn.cursor() as cur:
                cur.execute(
                    "SELECT sql_genere, statut FROM public.ai_query_log WHERE id = %s",
                    (id_log,),
                )
                row = cur.fetchone()
    except Exception as e:
        return jsonify({"statut": "erreur", "raison": str(e)}), 500

    if not row or not row[0]:
        return jsonify({"statut": "erreur", "raison": "Requête introuvable."}), 404
    raw_sql = row[0]

    export_max = int(getattr(Config, "AI_EXPORT_MAX_ROWS", 50000))
    try:
        safe_sql = validate_and_wrap(raw_sql, export_max)
        colonnes, lignes = run_readonly_query(safe_sql)
    except SqlGuardError as e:
        return jsonify({"statut": "rejete", "raison": str(e)}), 400
    except Exception as e:
        return jsonify({"statut": "erreur", "raison": str(e)}), 400

    df = pd.DataFrame(_sanitize_rows(lignes), columns=colonnes)
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")

    if fmt == "csv":
        # BOM UTF-8 pour qu'Excel ouvre correctement les accents ; séparateur ';'
        # (convention FR). Génération en mémoire.
        csv_text = df.to_csv(index=False, sep=";")
        data = ("\ufeff" + csv_text).encode("utf-8")
        filename = f"assistant_ia_export_{timestamp}.csv"
        response = make_response(data)
        response.headers["Content-Type"] = "text/csv; charset=utf-8"
        response.headers["Content-Disposition"] = f'attachment; filename="{filename}"'
        return response

    # Format Excel par défaut (pandas + openpyxl)
    buffer = io.BytesIO()
    with pd.ExcelWriter(buffer, engine="openpyxl") as writer:
        df.to_excel(writer, index=False, sheet_name="Résultats")
    buffer.seek(0)

    filename = f"assistant_ia_export_{timestamp}.xlsx"
    response = make_response(buffer.getvalue())
    response.headers["Content-Type"] = (
        "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
    )
    response.headers["Content-Disposition"] = f'attachment; filename="{filename}"'
    return response


@ai_blueprint.route("/history", methods=["GET"])
@jwt_required()
def history():
    """Historique paginé des questions depuis public.ai_query_log."""
    utilisateur = get_jwt_identity()
    try:
        page = max(1, int(request.args.get("page", 1)))
    except (TypeError, ValueError):
        page = 1
    par_utilisateur = request.args.get("par_utilisateur", "false").lower() == "true"
    page_size = 50
    offset = (page - 1) * page_size

    where = ""
    params = []
    if par_utilisateur:
        where = "WHERE utilisateur = %s"
        params.append(str(utilisateur))

    try:
        with get_db_connection() as conn:
            with conn.cursor() as cur:
                cur.execute(f"SELECT COUNT(*) FROM public.ai_query_log {where}", params)
                total = cur.fetchone()[0]
                cur.execute(
                    f"""
                    SELECT id, utilisateur, question, sql_genere, statut, raison_rejet,
                           template_id, duree_ms, nb_lignes, date_creation, feedback
                    FROM public.ai_query_log
                    {where}
                    ORDER BY date_creation DESC
                    LIMIT %s OFFSET %s
                    """,
                    params + [page_size, offset],
                )
                cols = [d[0] for d in cur.description]
                rows = [dict(zip(cols, r)) for r in cur.fetchall()]
    except Exception as e:
        return jsonify({"statut": "erreur", "raison": str(e)}), 500

    for r in rows:
        if isinstance(r.get("date_creation"), (datetime, date)):
            r["date_creation"] = r["date_creation"].isoformat()

    return jsonify({
        "total": total,
        "page": page,
        "page_size": page_size,
        "items": rows,
    }), 200


@ai_blueprint.route("/conversations", methods=["GET"])
@jwt_required()
def list_conversations():
    """Liste les conversations de l'utilisateur (non archivées), plus récentes d'abord."""
    utilisateur = get_jwt_identity()
    try:
        with get_db_connection() as conn:
            with conn.cursor() as cur:
                cur.execute(
                    """SELECT c.id, c.titre, c.date_creation, c.date_maj,
                              COUNT(m.id) FILTER (WHERE m.role = 'user') AS nb_questions
                       FROM public.ai_conversations c
                       LEFT JOIN public.ai_messages m ON m.conversation_id = c.id
                       WHERE c.utilisateur = %s AND c.archivee = false
                       GROUP BY c.id
                       ORDER BY c.date_maj DESC
                       LIMIT 200""",
                    (str(utilisateur),),
                )
                cols = [d[0] for d in cur.description]
                rows = [dict(zip(cols, r)) for r in cur.fetchall()]
    except Exception as e:
        return jsonify({"statut": "erreur", "raison": str(e)}), 500
    for r in rows:
        for k in ("date_creation", "date_maj"):
            if isinstance(r.get(k), (datetime, date)):
                r[k] = r[k].isoformat()
    return jsonify({"conversations": rows}), 200


@ai_blueprint.route("/conversations/<int:conversation_id>", methods=["GET"])
@jwt_required()
def get_conversation(conversation_id):
    """Renvoie une conversation et tous ses messages (pour la rouvrir)."""
    utilisateur = get_jwt_identity()
    try:
        with get_db_connection() as conn:
            with conn.cursor() as cur:
                cur.execute(
                    "SELECT id, titre, date_creation FROM public.ai_conversations "
                    "WHERE id = %s AND utilisateur = %s",
                    (conversation_id, str(utilisateur)),
                )
                conv = cur.fetchone()
                if not conv:
                    return jsonify({"statut": "erreur", "raison": "Conversation introuvable."}), 404
                cur.execute(
                    """SELECT id, role, contenu, statut, sql_genere, nb_lignes,
                              tronque, duree_ms, id_log, date_creation
                       FROM public.ai_messages
                       WHERE conversation_id = %s
                       ORDER BY date_creation, id""",
                    (conversation_id,),
                )
                cols = [d[0] for d in cur.description]
                messages = [dict(zip(cols, r)) for r in cur.fetchall()]
    except Exception as e:
        return jsonify({"statut": "erreur", "raison": str(e)}), 500
    for m in messages:
        if isinstance(m.get("date_creation"), (datetime, date)):
            m["date_creation"] = m["date_creation"].isoformat()
    return jsonify({
        "id": conv[0],
        "titre": conv[1],
        "date_creation": conv[2].isoformat() if isinstance(conv[2], (datetime, date)) else conv[2],
        "messages": messages,
    }), 200


@ai_blueprint.route("/conversations/<int:conversation_id>", methods=["DELETE"])
@jwt_required()
def delete_conversation(conversation_id):
    """Supprime une conversation et ses messages (ON DELETE CASCADE)."""
    utilisateur = get_jwt_identity()
    try:
        with get_db_connection() as conn:
            with conn.cursor() as cur:
                cur.execute(
                    "DELETE FROM public.ai_conversations WHERE id = %s AND utilisateur = %s",
                    (conversation_id, str(utilisateur)),
                )
                supprime = cur.rowcount
            conn.commit()
    except Exception as e:
        return jsonify({"statut": "erreur", "raison": str(e)}), 500
    if not supprime:
        return jsonify({"statut": "erreur", "raison": "Conversation introuvable."}), 404
    return jsonify({"statut": "succes"}), 200


@ai_blueprint.route("/rerun", methods=["POST"])
@jwt_required()
def rerun():
    """
    Ré-exécute le SQL d'un message d'historique (via son id_log) et renvoie les
    résultats JSON — pour réafficher une réponse passée sans repasser par le modèle.
    Le SQL est re-validé par sql_guard et exécuté sous le rôle readonly_ai.
    """
    body = request.get_json(silent=True) or {}
    id_log = body.get("id_log")
    if not id_log:
        return jsonify({"statut": "erreur", "raison": "id_log requis."}), 400

    try:
        with get_db_connection() as conn:
            with conn.cursor() as cur:
                cur.execute("SELECT sql_genere FROM public.ai_query_log WHERE id = %s", (id_log,))
                row = cur.fetchone()
    except Exception as e:
        return jsonify({"statut": "erreur", "raison": str(e)}), 500

    if not row or not row[0]:
        return jsonify({"statut": "erreur", "raison": "Requête introuvable."}), 404

    raw_sql = row[0]
    max_rows = int(getattr(Config, "AI_MAX_ROWS", 500))
    try:
        safe_sql = validate_and_wrap(raw_sql, max_rows)
        colonnes, lignes = run_readonly_query(safe_sql)
    except SqlGuardError as e:
        return jsonify({"statut": "rejete", "raison": str(e)}), 400
    except Exception as e:
        return jsonify({"statut": "erreur", "raison": _friendly_db_error(e)}), 400

    lignes = _sanitize_rows(lignes)
    return jsonify({
        "statut": "succes",
        "sql": raw_sql,
        "colonnes": colonnes,
        "lignes": lignes,
        "tronque": len(lignes) >= max_rows,
    }), 200


@ai_blueprint.route("/run-sql", methods=["POST"])
@jwt_required()
def run_sql():
    """
    Exécute un SQL FOURNI par l'utilisateur (édité depuis l'écran « Résultats IA »).

    Même chaîne de sécurité que le reste de l'assistant : validation sql_guard
    (SELECT/WITH only, LIMIT borné) puis exécution sous le rôle readonly_ai. La
    requête est journalisée dans ai_query_log via ``_execute_and_pack`` : l'édition
    est donc « enregistrée » et réapparaît dans l'historique. Renvoie le même
    payload que /ask (statut, sql, colonnes, lignes, id_log, ...).
    """
    utilisateur = get_jwt_identity()
    body = request.get_json(silent=True) or {}
    sql = (body.get("sql") or "").strip()
    question = (body.get("question") or "SQL édité manuellement").strip()
    if not sql:
        return jsonify({"statut": "erreur", "raison": "SQL vide."}), 400

    max_rows = int(getattr(Config, "AI_MAX_ROWS", 500))
    payload, status = _execute_and_pack(
        utilisateur, question, sql,
        max_rows=max_rows,
        explication="Requête éditée manuellement.",
    )

    # Capitalisation : une requête éditée à la main puis exécutée avec succès est,
    # de facto, une bonne réponse pour `question`. On la rend réutilisable :
    #  - store() écrit son embedding (sinon NULL -> jamais retenue comme few-shot
    #    vivant ni comme hit de cache, qui exigent tous deux embedding IS NOT NULL) ;
    #  - feedback='up' la promeut en few-shot vivant (ai_prompt_builder) et la fait
    #    préférer par le cache sémantique (lookup) pour les prochaines questions.
    if payload.get("statut") == "succes" and payload.get("id_log"):
        id_log = payload["id_log"]
        try:
            ai_semantic_cache.store(id_log, question)
        except Exception as e:
            logger.warning(f"⚠️ Embedding de la requête éditée non mémorisé : {e}")
        if _mark_feedback_up(id_log):
            payload["feedback"] = "up"

    return jsonify(payload), status


@ai_blueprint.route("/feedback", methods=["POST"])
@jwt_required()
def feedback():
    """
    Enregistre le vote utilisateur sur une réponse (pouce haut/bas) dans
    ai_query_log.feedback. 'up' rend la requête utilisable comme few-shot vivant
    (cf. ai_prompt_builder). vote='' (ou 'none') retire le vote.
    """
    body = request.get_json(silent=True) or {}
    id_log = body.get("id_log")
    vote = (body.get("vote") or "").strip().lower()
    if not id_log:
        return jsonify({"statut": "erreur", "raison": "id_log requis."}), 400
    if vote in ("none", "null"):
        vote = ""
    if vote not in ("up", "down", ""):
        return jsonify({"statut": "erreur", "raison": "vote doit valoir up, down ou vide."}), 400

    valeur = vote or None
    try:
        with get_db_connection() as conn:
            with conn.cursor() as cur:
                cur.execute(
                    """UPDATE public.ai_query_log
                       SET feedback = %s, feedback_date = CURRENT_TIMESTAMP
                       WHERE id = %s""",
                    (valeur, id_log),
                )
                touched = cur.rowcount
            conn.commit()
    except Exception as e:
        logger.error(f"❌ Échec d'enregistrement du feedback : {e}")
        return jsonify({"statut": "erreur", "raison": str(e)}), 500

    if not touched:
        return jsonify({"statut": "erreur", "raison": "Requête introuvable."}), 404
    return jsonify({"statut": "succes", "feedback": valeur}), 200


@ai_blueprint.route("/health", methods=["GET"])
@jwt_required()
def health():
    """Statut du service Ollama + présence du modèle configuré."""
    status = check_health()
    http = 200 if status.get("available") else 503
    return jsonify(status), http
