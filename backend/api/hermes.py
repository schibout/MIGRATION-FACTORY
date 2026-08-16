# -*- coding: utf-8 -*-
"""
api/hermes.py — Proxy streaming vers l'agent Hermes (Nous Research).

Hermes expose une API OpenAI-compatible (Bearer {HERMES_API_KEY}) sur le même
serveur. Ce blueprint relaie le chat en STREAMING SSE de bout en bout : la clé
API ne quitte JAMAIS le backend — le frontend appelle ce proxy avec son JWT
Migration Factory habituel.

Ciblage de l'agent : le profil vit dans l'URL, `<racine>/p/{HERMES_PROFILE}/v1/
chat/completions`, jamais dans le champ `model` du corps (cf.
docs/APPEL_HERMES_PROFIL.md). HERMES_PROFILE vide -> agent Hermes par défaut et
URL historique `{HERMES_API_URL}/chat/completions`. Le gateway doit servir le
profil (`gateway.multiplex_profiles`), sinon toute route /p/… répond 404.

Contrat côté frontend :
    POST /api/v1/hermes/chat  (JWT requis)
    body : {"messages": [{"role","content"}...], "instructions"?: str, "stream"?: bool}
    - instructions = consigne persistante, injectée comme message system en tête ;
    - stream=true (défaut) -> réponse text/event-stream relayée telle quelle
      (chunks chat.completion.chunk, events hermes.tool.progress, [DONE]) ;
    - stream=false -> réponse JSON complète (utile pour tests).

Multi-tour : l'API Hermes est stateless — le frontend renvoie tout l'historique
à chaque requête (choix le plus simple, cf. hermes.md).
"""

import json
import logging
import threading
from urllib.parse import urlsplit, urlunsplit

import requests
from flask import Blueprint, Response, jsonify, request, stream_with_context
from flask_jwt_extended import jwt_required, get_jwt_identity
from psycopg2.extras import RealDictCursor

from config.database import get_db_connection
from services.config_service import get_config, get_config_int

logger = logging.getLogger(__name__)

hermes_blueprint = Blueprint('hermes', __name__)

_ALLOWED_ROLES = {'user', 'assistant', 'system'}

# Rôles persistables dans l'historique (le system = instructions, stocké à part).
_HISTORY_ROLES = {'user', 'assistant'}

# Création paresseuse du schéma (une fois par process) : l'historique fonctionne
# même si la migration 022 n'a pas été jouée.
_schema_lock = threading.Lock()
_schema_ready = False

_SCHEMA_SQL = [
    """CREATE TABLE IF NOT EXISTS public.hermes_conversations (
        id            BIGSERIAL PRIMARY KEY,
        utilisateur   VARCHAR(150) NOT NULL,
        titre         TEXT,
        instructions  TEXT NOT NULL DEFAULT '',
        date_creation TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
        date_maj      TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
    )""",
    """CREATE INDEX IF NOT EXISTS idx_hermes_conversations_user
        ON public.hermes_conversations (utilisateur, date_maj DESC)""",
    """CREATE TABLE IF NOT EXISTS public.hermes_messages (
        id              BIGSERIAL PRIMARY KEY,
        conversation_id BIGINT NOT NULL
                        REFERENCES public.hermes_conversations(id) ON DELETE CASCADE,
        role            VARCHAR(12) NOT NULL,
        contenu         TEXT,
        position        INTEGER NOT NULL DEFAULT 0,
        date_creation   TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
    )""",
    """CREATE INDEX IF NOT EXISTS idx_hermes_messages_conv
        ON public.hermes_messages (conversation_id, position, id)""",
    """CREATE TABLE IF NOT EXISTS public.hermes_job_results (
        id            BIGSERIAL PRIMARY KEY,
        utilisateur   VARCHAR(150) NOT NULL,
        job_id        VARCHAR(120),
        job_name      TEXT,
        prompt        TEXT,
        resultat      TEXT,
        statut        VARCHAR(20) NOT NULL DEFAULT 'ok',
        date_creation TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
    )""",
    """CREATE INDEX IF NOT EXISTS idx_hermes_job_results_user
        ON public.hermes_job_results (utilisateur, date_creation DESC)""",
]


def _ensure_schema():
    """Crée les tables d'historique si besoin (idempotent, une fois par process)."""
    global _schema_ready
    if _schema_ready:
        return
    with _schema_lock:
        if _schema_ready:
            return
        with get_db_connection() as conn:
            with conn.cursor() as cur:
                for ddl in _SCHEMA_SQL:
                    cur.execute(ddl)
            conn.commit()
        _schema_ready = True


def _hermes_config() -> dict:
    """Lecture dynamique (DB system_config > env > défaut) — même pattern que
    external_llm_service : la clé/URL/profil se changent sans redémarrage."""
    timeout = get_config_int('HERMES_TIMEOUT_SECONDS', 300)
    return {
        'base_url': (get_config('HERMES_API_URL', 'http://10.190.100.58:8642/v1') or '').rstrip('/'),
        'api_key': get_config('HERMES_API_KEY', '') or '',
        # Profil = l'agent ciblé sur le gateway (segment /p/<profil>/ de l'URL).
        # Défaut VIDE -> agent Hermes par défaut et URL historique : le profil
        # s'active explicitement (Paramètres > Profil Hermes), et se désactive en
        # vidant le champ. Un défaut non vide rendrait cette bascule impossible,
        # get_config traitant « valeur vide » comme « non configuré ».
        'profile': (get_config('HERMES_PROFILE', 'migration') or 'migration').strip().strip('/') or 'migration',
        # read timeout = silence max ENTRE deux chunks SSE, pas la durée totale.
        'read_timeout': (timeout if timeout > 0 else None),
    }


def _hermes_origin(cfg: dict) -> str:
    """Origine du serveur Hermes (http://host:port) SANS le suffixe /v1 : les
    endpoints Jobs sont sous {origin}/api/jobs (hors /v1). urlsplit >> rstrip('/v1')
    (qui retirerait des caractères, pas un segment)."""
    p = urlsplit(cfg['base_url'])
    return urlunsplit((p.scheme, p.netloc, '', '', ''))


def _chat_url(cfg: dict) -> str:
    """URL de complétion, profil compris.

    Le profil se sélectionne UNIQUEMENT par l'URL — `<racine>/p/<profil>/v1/…` —
    jamais par le champ `model` du corps : le gateway renvoie `model` tel quel et
    ne sélectionne rien, si bien qu'un profil ciblé par `model` donne un 404.
    Profil vide -> agent par défaut, URL historique `<base_url>/chat/completions`.
    """
    profil = (cfg.get('profile') or '').strip().strip('/')
    if not profil:
        return f"{cfg['base_url']}/chat/completions"
    return f"{_hermes_origin(cfg)}/p/{profil}/v1/chat/completions"


def _erreur_404(cfg: dict) -> str:
    """Message de diagnostic d'un 404 amont : la cause dépend du ciblage."""
    profil = (cfg.get('profile') or '').strip()
    if profil:
        return (f"Profil Hermes « {profil} » inconnu du gateway (404). "
                f"Vérifiez HERMES_PROFILE et que le gateway sert bien ce profil "
                f"(gateway.multiplex_profiles activé sur le profil par défaut).")
    return "Endpoint Hermes introuvable (404) : vérifiez HERMES_API_URL."


def _proxy(method: str, url: str, cfg: dict, json_body=None):
    """
    Relaie un appel JSON (non-stream) vers le serveur Hermes avec la clé Bearer.
    Renvoie (payload_flask, http_status). La clé ne quitte jamais le backend.
    """
    if not cfg['api_key']:
        return jsonify({'success': False,
                        'error': "Clé API Hermes non configurée (HERMES_API_KEY)."}), 500
    try:
        r = requests.request(
            method, url,
            json=json_body,
            headers={'Authorization': f"Bearer {cfg['api_key']}", 'Content-Type': 'application/json'},
            timeout=(10, cfg['read_timeout']),
        )
    except requests.exceptions.Timeout:
        return jsonify({'success': False, 'error': "Hermes n'a pas répondu à temps."}), 504
    except requests.exceptions.RequestException as e:
        logger.warning("Hermes injoignable (%s %s) : %s", method, url, e)
        return jsonify({'success': False, 'error': f'Agent injoignable : {e}'}), 502
    try:
        payload = r.json()
    except ValueError:
        # Réponse non-JSON = page d'erreur d'un intermédiaire (nginx, gateway) :
        # on ne la recopie pas au client, elle peut porter des détails internes.
        logger.warning("Réponse Hermes non-JSON (%s %s, HTTP %s) : %s",
                       method, url, r.status_code, r.text[:300])
        payload = {'success': False,
                   'error': f'Réponse Hermes illisible (HTTP {r.status_code}). '
                            f'Détail dans les journaux du backend.'}
    return jsonify(payload), r.status_code


_JOB_ACTIONS = {'pause', 'resume', 'run'}


def _build_messages(raw_messages: list, instructions: str) -> list:
    """Tableau messages envoyé à Hermes : les instructions utilisateur deviennent
    LE message system en tête. On retire tout system du tableau reçu (le champ
    instructions est la seule source de consigne, pas de doublon)."""
    messages = [m for m in raw_messages if m['role'] != 'system']
    if instructions:
        messages = [{'role': 'system', 'content': instructions}] + messages
    return messages


@hermes_blueprint.route('/chat', methods=['POST'])
@jwt_required()
def chat():
    data = request.get_json(silent=True) or {}
    raw_messages = data.get('messages')
    instructions = (data.get('instructions') or '').strip()
    stream = bool(data.get('stream', True))

    if (not isinstance(raw_messages, list) or not raw_messages
            or not all(isinstance(m, dict)
                       and m.get('role') in _ALLOWED_ROLES
                       and isinstance(m.get('content'), str)
                       for m in raw_messages)):
        return jsonify({'success': False,
                        'error': 'messages doit être une liste non vide de {role, content}.'}), 400

    cfg = _hermes_config()
    if not cfg['api_key']:
        # 500 explicite : clé absente = erreur de configuration serveur, pas d'appel.
        return jsonify({'success': False,
                        'error': "Clé API Hermes non configurée. Renseignez HERMES_API_KEY "
                                 "dans Paramètres > Assistant IA — Modèle (ou en variable "
                                 "d'environnement)."}), 500

    payload = {
        # Champ cosmétique : Hermes le renvoie tel quel et ne sélectionne rien
        # (c'est /p/<profil>/ dans l'URL qui choisit l'agent). On y met le nom du
        # profil par convention, pour que les journaux du gateway soient lisibles.
        'messages': _build_messages(raw_messages, instructions),
        'stream': stream,
    }
    headers = {
        'Authorization': f"Bearer {cfg['api_key']}",
        'Content-Type': 'application/json',
        'Accept': 'text/event-stream' if stream else 'application/json',
    }

    try:
        upstream = requests.post(
            _chat_url(cfg),
            json=payload, headers=headers, stream=stream,
            timeout=(10, cfg['read_timeout']),
        )
    except requests.exceptions.Timeout:
        return jsonify({'success': False,
                        'error': f"Hermes n'a pas répondu dans le délai imparti "
                                 f"({cfg['read_timeout']}s)."}), 504
    except requests.exceptions.RequestException as e:
        logger.warning("Hermes injoignable : %s", e)
        return jsonify({'success': False, 'error': f'Agent Hermes injoignable : {e}'}), 502

    if upstream.status_code in (401, 403):
        upstream.close()
        return jsonify({'success': False,
                        'error': 'Authentification refusée par Hermes — vérifiez HERMES_API_KEY.'}), 502
    if upstream.status_code == 404:
        # Cas le plus fréquent au branchement d'un profil : le corps amont
        # ("404: Not Found") n'apprend rien, on renvoie le diagnostic utile.
        upstream.close()
        logger.warning("Hermes 404 sur %s", _chat_url(cfg))
        return jsonify({'success': False, 'error': _erreur_404(cfg)}), 502
    if upstream.status_code != 200:
        # Le corps amont peut porter l'URL interne, la clé ou une trace : il part
        # au journal, jamais au client. Le statut, lui, est utile et sans risque.
        statut = upstream.status_code
        logger.warning("Hermes a répondu HTTP %s : %s", statut, upstream.text[:300])
        upstream.close()
        return jsonify({'success': False,
                        'error': f'Hermes a répondu HTTP {statut}. '
                                 f'Détail dans les journaux du backend.'}), 502

    if not stream:
        try:
            return jsonify(upstream.json()), 200
        finally:
            upstream.close()

    def relay():
        """Relaie les octets SSE TELS QUELS (framing event:/data: préservé, y
        compris hermes.tool.progress et [DONE]). Aucun re-parsing serveur."""
        try:
            for chunk in upstream.iter_content(chunk_size=None):
                if chunk:
                    yield chunk
        except requests.exceptions.RequestException as e:
            # Coupure EN COURS de stream : le 200 est déjà parti, on ne peut plus
            # changer le statut -> on émet un event d'erreur que le front sait lire.
            logger.warning("Flux Hermes interrompu : %s", e)
            err = json.dumps({'error': f'Flux Hermes interrompu : {e}'}, ensure_ascii=False)
            yield f'data: {err}\n\n'.encode('utf-8')
        finally:
            # Couvre aussi GeneratorExit (onglet fermé) : libère la connexion Hermes.
            upstream.close()

    resp = Response(stream_with_context(relay()), mimetype='text/event-stream')
    resp.headers['Cache-Control'] = 'no-cache'
    resp.headers['X-Accel-Buffering'] = 'no'   # nginx du repo : proxy_buffering on global
    return resp


# --------------------------------------------------------------------------- #
# Historique conversationnel (public.hermes_conversations / hermes_messages)
#
# Le streaming Hermes se fait côté client : le frontend RENVOIE la conversation
# complète après chaque échange (POST /conversations). On persiste par
# remplacement (delete + reinsert des messages), simple et idempotent.
# --------------------------------------------------------------------------- #
@hermes_blueprint.route('/conversations', methods=['GET'])
@jwt_required()
def list_conversations():
    """Conversations de l'utilisateur, plus récentes d'abord."""
    user = str(get_jwt_identity())
    try:
        _ensure_schema()
        with get_db_connection() as conn:
            with conn.cursor(cursor_factory=RealDictCursor) as cur:
                cur.execute(
                    """SELECT c.id, c.titre, c.date_maj,
                              COUNT(m.id) AS nb_messages
                       FROM public.hermes_conversations c
                       LEFT JOIN public.hermes_messages m ON m.conversation_id = c.id
                       WHERE c.utilisateur = %s
                       GROUP BY c.id
                       ORDER BY c.date_maj DESC
                       LIMIT 200""",
                    (user,),
                )
                rows = cur.fetchall()
    except Exception as e:
        logger.error("Historique Hermes (liste) indisponible : %s", e)
        return jsonify({'success': False, 'error': str(e)}), 500
    for r in rows:
        if r.get('date_maj') is not None:
            r['date_maj'] = r['date_maj'].isoformat()
    return jsonify({'conversations': rows}), 200


@hermes_blueprint.route('/conversations/<int:conv_id>', methods=['GET'])
@jwt_required()
def get_conversation(conv_id):
    """Une conversation + ses messages + ses instructions (pour la rouvrir)."""
    user = str(get_jwt_identity())
    try:
        _ensure_schema()
        with get_db_connection() as conn:
            with conn.cursor(cursor_factory=RealDictCursor) as cur:
                cur.execute(
                    "SELECT id, titre, instructions FROM public.hermes_conversations "
                    "WHERE id = %s AND utilisateur = %s",
                    (conv_id, user),
                )
                conv = cur.fetchone()
                if not conv:
                    return jsonify({'success': False, 'error': 'Conversation introuvable.'}), 404
                cur.execute(
                    "SELECT role, contenu FROM public.hermes_messages "
                    "WHERE conversation_id = %s ORDER BY position, id",
                    (conv_id,),
                )
                messages = [{'role': m['role'], 'content': m['contenu'] or ''} for m in cur.fetchall()]
    except Exception as e:
        logger.error("Historique Hermes (lecture) indisponible : %s", e)
        return jsonify({'success': False, 'error': str(e)}), 500
    return jsonify({
        'id': conv['id'],
        'titre': conv['titre'],
        'instructions': conv['instructions'] or '',
        'messages': messages,
    }), 200


@hermes_blueprint.route('/conversations', methods=['POST'])
@jwt_required()
def save_conversation():
    """
    Enregistre (crée ou met à jour) une conversation. Body :
        {conversation_id?: int, instructions?: str, messages: [{role, content}...]}
    Sémantique de remplacement : les messages existants sont remplacés. Renvoie
    l'id (à conserver côté client pour les sauvegardes suivantes du même fil).
    """
    user = str(get_jwt_identity())
    data = request.get_json(silent=True) or {}
    conv_id = data.get('conversation_id')
    instructions = (data.get('instructions') or '')
    raw_messages = data.get('messages')

    if not isinstance(raw_messages, list) or not raw_messages:
        return jsonify({'success': False, 'error': 'messages doit être une liste non vide.'}), 400
    messages = [
        (m['role'], m['content']) for m in raw_messages
        if isinstance(m, dict) and m.get('role') in _HISTORY_ROLES and isinstance(m.get('content'), str)
    ]
    if not messages:
        return jsonify({'success': False, 'error': 'Aucun message user/assistant valide.'}), 400

    titre = (next((c for r, c in messages if r == 'user'), '') or 'Conversation').strip()[:120]

    try:
        _ensure_schema()
        with get_db_connection() as conn:
            with conn.cursor() as cur:
                owned = False
                if conv_id:
                    cur.execute(
                        "SELECT 1 FROM public.hermes_conversations WHERE id = %s AND utilisateur = %s",
                        (conv_id, user),
                    )
                    owned = cur.fetchone() is not None
                if owned:
                    cur.execute(
                        "UPDATE public.hermes_conversations "
                        "SET titre = %s, instructions = %s, date_maj = CURRENT_TIMESTAMP "
                        "WHERE id = %s",
                        (titre, instructions, conv_id),
                    )
                    cur.execute("DELETE FROM public.hermes_messages WHERE conversation_id = %s", (conv_id,))
                else:
                    cur.execute(
                        "INSERT INTO public.hermes_conversations (utilisateur, titre, instructions) "
                        "VALUES (%s, %s, %s) RETURNING id",
                        (user, titre, instructions),
                    )
                    conv_id = cur.fetchone()[0]
                for pos, (role, contenu) in enumerate(messages):
                    cur.execute(
                        "INSERT INTO public.hermes_messages (conversation_id, role, contenu, position) "
                        "VALUES (%s, %s, %s, %s)",
                        (conv_id, role, contenu, pos),
                    )
            conn.commit()
    except Exception as e:
        logger.error("Historique Hermes (sauvegarde) échouée : %s", e)
        return jsonify({'success': False, 'error': str(e)}), 500
    return jsonify({'id': conv_id}), 200


@hermes_blueprint.route('/conversations/<int:conv_id>', methods=['DELETE'])
@jwt_required()
def delete_conversation(conv_id):
    """Supprime une conversation et ses messages (ON DELETE CASCADE)."""
    user = str(get_jwt_identity())
    try:
        _ensure_schema()
        with get_db_connection() as conn:
            with conn.cursor() as cur:
                cur.execute(
                    "DELETE FROM public.hermes_conversations WHERE id = %s AND utilisateur = %s",
                    (conv_id, user),
                )
                supprime = cur.rowcount
            conn.commit()
    except Exception as e:
        logger.error("Historique Hermes (suppression) échouée : %s", e)
        return jsonify({'success': False, 'error': str(e)}), 500
    if not supprime:
        return jsonify({'success': False, 'error': 'Conversation introuvable.'}), 404
    return jsonify({'success': True}), 200


# --------------------------------------------------------------------------- #
# Jobs planifiés (cron) — proxy vers {origin}/api/jobs du serveur Hermes.
# La clé reste côté backend ; le front appelle /api/v1/hermes/jobs* avec son JWT.
# --------------------------------------------------------------------------- #
@hermes_blueprint.route('/jobs', methods=['GET'])
@jwt_required()
def list_jobs():
    cfg = _hermes_config()
    return _proxy('GET', f"{_hermes_origin(cfg)}/api/jobs", cfg)


@hermes_blueprint.route('/jobs', methods=['POST'])
@jwt_required()
def create_job():
    body = request.get_json(silent=True) or {}
    if not isinstance(body, dict) or not (body.get('prompt') and body.get('schedule')):
        return jsonify({'success': False,
                        'error': 'Un job requiert au moins « prompt » et « schedule ».'}), 400
    cfg = _hermes_config()
    return _proxy('POST', f"{_hermes_origin(cfg)}/api/jobs", cfg, json_body=body)


@hermes_blueprint.route('/jobs/<job_id>', methods=['GET'])
@jwt_required()
def get_job(job_id):
    cfg = _hermes_config()
    return _proxy('GET', f"{_hermes_origin(cfg)}/api/jobs/{job_id}", cfg)


@hermes_blueprint.route('/jobs/<job_id>', methods=['PATCH'])
@jwt_required()
def update_job(job_id):
    body = request.get_json(silent=True) or {}
    if not isinstance(body, dict) or not body:
        return jsonify({'success': False, 'error': 'Corps de mise à jour vide.'}), 400
    cfg = _hermes_config()
    return _proxy('PATCH', f"{_hermes_origin(cfg)}/api/jobs/{job_id}", cfg, json_body=body)


@hermes_blueprint.route('/jobs/<job_id>', methods=['DELETE'])
@jwt_required()
def delete_job(job_id):
    cfg = _hermes_config()
    return _proxy('DELETE', f"{_hermes_origin(cfg)}/api/jobs/{job_id}", cfg)


@hermes_blueprint.route('/jobs/<job_id>/<action>', methods=['POST'])
@jwt_required()
def job_action(job_id, action):
    if action not in _JOB_ACTIONS:
        return jsonify({'success': False,
                        'error': f'Action invalide : {action} (pause|resume|run).'}), 400
    cfg = _hermes_config()
    return _proxy('POST', f"{_hermes_origin(cfg)}/api/jobs/{job_id}/{action}", cfg)


# --------------------------------------------------------------------------- #
# Exécution « à la demande » d'un job + stockage/consultation des résultats.
#
# Hermes ne sait pas relivrer un résultat de cron vers notre app (deliver=origin
# échoue en mode api_server, pas de webhook sortant). On exécute donc le PROMPT
# du job via /chat/completions (qui renvoie le texte), on le stocke et on
# l'affiche dans l'app (table public.hermes_job_results, isolée par utilisateur).
# --------------------------------------------------------------------------- #
@hermes_blueprint.route('/jobs/<job_id>/execute', methods=['POST'])
@jwt_required()
def execute_job(job_id):
    user = str(get_jwt_identity())
    cfg = _hermes_config()
    if not cfg['api_key']:
        return jsonify({'success': False,
                        'error': "Clé API Hermes non configurée (HERMES_API_KEY)."}), 500
    origin = _hermes_origin(cfg)
    headers = {'Authorization': f"Bearer {cfg['api_key']}", 'Content-Type': 'application/json'}

    # 1) Récupérer le prompt courant du job.
    try:
        jr = requests.get(f"{origin}/api/jobs/{job_id}", headers=headers, timeout=(10, 15))
    except requests.exceptions.RequestException as e:
        return jsonify({'success': False, 'error': f'Agent injoignable : {e}'}), 502
    if jr.status_code != 200:
        return jsonify({'success': False,
                        'error': f'Job introuvable (HTTP {jr.status_code}).'}), 502
    try:
        jd = jr.json()
        job = jd.get('job', jd) if isinstance(jd, dict) else {}
        prompt = str(job.get('prompt') or '').strip()
        job_name = str(job.get('name') or job_id)
    except ValueError:
        return jsonify({'success': False, 'error': 'Réponse job inexploitable.'}), 502
    if not prompt:
        return jsonify({'success': False, 'error': 'Ce job n’a pas de prompt exécutable.'}), 400

    # 2) Exécuter le prompt (non-stream) -> texte.
    try:
        cr = requests.post(
            _chat_url(cfg),
            json={'messages': [{'role': 'user', 'content': prompt}], 'stream': False},
            headers=headers, timeout=(10, cfg['read_timeout']),
        )
    except requests.exceptions.Timeout:
        return jsonify({'success': False, 'error': "L'agent n'a pas répondu à temps."}), 504
    except requests.exceptions.RequestException as e:
        return jsonify({'success': False, 'error': f'Agent injoignable : {e}'}), 502
    if cr.status_code == 404:
        return jsonify({'success': False, 'error': _erreur_404(cfg)}), 502
    if cr.status_code != 200:
        # Corps amont au journal uniquement (cf. chat()).
        logger.warning("Exécution job %s refusée par Hermes (HTTP %s) : %s",
                       job_id, cr.status_code, cr.text[:200])
        return jsonify({'success': False,
                        'error': f'Exécution refusée (HTTP {cr.status_code}). '
                                 f'Détail dans les journaux du backend.'}), 502
    try:
        text = str(cr.json()['choices'][0]['message']['content'] or '')
    except (KeyError, IndexError, ValueError, TypeError):
        return jsonify({'success': False, 'error': 'Réponse de l’agent inexploitable.'}), 502
    if not text.strip():
        # Un contenu vide est une erreur, pas un résultat : le stocker ferait
        # apparaître un job « ok » sans contenu dans l'onglet Résultats.
        logger.warning("Job %s : réponse vide de l'agent", job_id)
        return jsonify({'success': False, 'error': 'L’agent a renvoyé une réponse vide.'}), 502

    # 3) Stocker (best-effort : on renvoie le résultat même si le stockage échoue).
    result = {'id': None, 'job_id': str(job_id), 'job_name': job_name,
              'resultat': text, 'statut': 'ok', 'date_creation': None}
    try:
        _ensure_schema()
        with get_db_connection() as conn:
            with conn.cursor() as cur:
                cur.execute(
                    "INSERT INTO public.hermes_job_results (utilisateur, job_id, job_name, prompt, resultat) "
                    "VALUES (%s, %s, %s, %s, %s) RETURNING id, date_creation",
                    (user, str(job_id), job_name, prompt, text),
                )
                rid, dt = cur.fetchone()
            conn.commit()
        result['id'] = rid
        result['date_creation'] = dt.isoformat()
    except Exception as e:
        logger.error("Stockage résultat job échoué : %s", e)
    return jsonify(result), 200


@hermes_blueprint.route('/job-results', methods=['GET'])
@jwt_required()
def list_job_results():
    """Résultats stockés de l'utilisateur, plus récents d'abord."""
    user = str(get_jwt_identity())
    try:
        _ensure_schema()
        with get_db_connection() as conn:
            with conn.cursor(cursor_factory=RealDictCursor) as cur:
                cur.execute(
                    "SELECT id, job_id, job_name, statut, resultat, date_creation "
                    "FROM public.hermes_job_results WHERE utilisateur = %s "
                    "ORDER BY date_creation DESC LIMIT 100",
                    (user,),
                )
                rows = cur.fetchall()
    except Exception as e:
        logger.error("Liste résultats jobs indisponible : %s", e)
        return jsonify({'success': False, 'error': str(e)}), 500
    for r in rows:
        if r.get('date_creation') is not None:
            r['date_creation'] = r['date_creation'].isoformat()
    return jsonify({'results': rows}), 200


@hermes_blueprint.route('/job-results/<int:rid>', methods=['DELETE'])
@jwt_required()
def delete_job_result(rid):
    user = str(get_jwt_identity())
    try:
        _ensure_schema()
        with get_db_connection() as conn:
            with conn.cursor() as cur:
                cur.execute(
                    "DELETE FROM public.hermes_job_results WHERE id = %s AND utilisateur = %s",
                    (rid, user),
                )
                supprime = cur.rowcount
            conn.commit()
    except Exception as e:
        return jsonify({'success': False, 'error': str(e)}), 500
    if not supprime:
        return jsonify({'success': False, 'error': 'Résultat introuvable.'}), 404
    return jsonify({'success': True}), 200


# --------------------------------------------------------------------------- #
# État de l'agent : capabilities (/v1/capabilities) + santé (/health/detailed).
# --------------------------------------------------------------------------- #
@hermes_blueprint.route('/agent-status', methods=['GET'])
@jwt_required()
def agent_status():
    cfg = _hermes_config()
    if not cfg['api_key']:
        return jsonify({'success': False,
                        'error': "Clé API Hermes non configurée (HERMES_API_KEY)."}), 500
    origin = _hermes_origin(cfg)
    headers = {'Authorization': f"Bearer {cfg['api_key']}"}

    def _get(url):
        try:
            r = requests.get(url, headers=headers, timeout=(10, 15))
            return r.json() if r.status_code == 200 else None
        except (requests.exceptions.RequestException, ValueError):
            return None

    capabilities = _get(f"{cfg['base_url']}/capabilities")
    health = _get(f"{origin}/health/detailed")
    reachable = capabilities is not None or health is not None
    return jsonify({'reachable': reachable, 'capabilities': capabilities, 'health': health}), 200
