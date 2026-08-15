"""
API de gestion des paramètres système (page /parametres).

Stocke et retourne les variables d'environnement modifiables :
connexions DB / SAP / SharePoint / SMTP, sécurité, backup, etc.

Les valeurs sont stockées dans public.system_config et surchargent
les valeurs du fichier .env (via os.environ) au runtime.
"""

import os
import smtplib
import logging
from flask import Blueprint, jsonify, request
from flask_jwt_extended import jwt_required
from psycopg2.extras import RealDictCursor

from config.database import get_db_connection
from utils.auth_decorators import admin_required

logger = logging.getLogger(__name__)

settings_blueprint = Blueprint('settings', __name__)

MASK = '••••••••'

# Catalogue des variables exposées dans la page Paramètres.
# - key      : nom de la variable d'environnement
# - label    : libellé affiché
# - type     : text | password | number | boolean | url
# - secret   : True si la valeur doit être masquée
# - default  : valeur par défaut si rien dans .env / DB
# - requires_restart : informationnel pour l'UI
SETTINGS_CATALOG = [
    # ---------- Base de données PostgreSQL ----------
    {'key': 'DB_HOST',          'category': 'database', 'label': 'Hôte PostgreSQL',         'type': 'text',     'secret': False, 'default': '10.190.100.58',   'requires_restart': True},
    {'key': 'DB_PORT',          'category': 'database', 'label': 'Port PostgreSQL',         'type': 'number',   'secret': False, 'default': '5432',            'requires_restart': True},
    {'key': 'DB_NAME',          'category': 'database', 'label': 'Nom de la base',          'type': 'text',     'secret': False, 'default': 'sap_migration_db','requires_restart': True},
    {'key': 'DB_USER',          'category': 'database', 'label': 'Utilisateur',             'type': 'text',     'secret': False, 'default': 'postgres',        'requires_restart': True},
    {'key': 'DB_PASSWORD',      'category': 'database', 'label': 'Mot de passe',            'type': 'password', 'secret': True,  'default': '',                'requires_restart': True},
    {'key': 'PG_SCHEMA',        'category': 'database', 'label': 'Schéma par défaut',       'type': 'text',     'secret': False, 'default': 'clean_data',      'requires_restart': True},
    {'key': 'DB_POOL_SIZE',     'category': 'database', 'label': 'Pool size',               'type': 'number',   'secret': False, 'default': '10',              'requires_restart': True},
    {'key': 'DB_MAX_OVERFLOW',  'category': 'database', 'label': 'Pool max overflow',       'type': 'number',   'secret': False, 'default': '20',              'requires_restart': True},
    {'key': 'DB_POOL_TIMEOUT',  'category': 'database', 'label': 'Pool timeout (s)',        'type': 'number',   'secret': False, 'default': '30',              'requires_restart': True},
    {'key': 'DB_POOL_RECYCLE',  'category': 'database', 'label': 'Pool recycle (s)',        'type': 'number',   'secret': False, 'default': '1800',            'requires_restart': True},

    # ---------- SAP Extraction ----------
    {'key': 'SAP_EXTRACTION_API_URL', 'category': 'sap', 'label': 'URL API SAP Extraction', 'type': 'url',      'secret': False, 'default': 'http://10.190.100.58:8000', 'requires_restart': False},
    {'key': 'SAP_EXTRACTION_PATH',    'category': 'sap', 'label': 'Répertoire d\'extraction', 'type': 'text',   'secret': False, 'default': '/opt/sap_extraction',       'requires_restart': True},
    {'key': 'SAP_API_TIMEOUT',        'category': 'sap', 'label': 'Timeout API (s)',        'type': 'number',   'secret': False, 'default': '10',                         'requires_restart': False},

    # ---------- SharePoint / ASAP ----------
    {'key': 'SHAREPOINT_BASE_URL', 'category': 'sharepoint', 'label': 'URL SharePoint',     'type': 'url',      'secret': False, 'default': 'http://asap.stjn.local', 'requires_restart': False},
    {'key': 'SHAREPOINT_USER',     'category': 'sharepoint', 'label': 'Utilisateur NTLM',   'type': 'text',     'secret': False, 'default': '',                       'requires_restart': False},
    {'key': 'SHAREPOINT_PASSWORD', 'category': 'sharepoint', 'label': 'Mot de passe NTLM',  'type': 'password', 'secret': True,  'default': '',                       'requires_restart': False},

    # ---------- SMTP ----------
    {'key': 'SMTP_SERVER',          'category': 'smtp', 'label': 'Serveur SMTP',           'type': 'text',     'secret': False, 'default': '',                  'requires_restart': False},
    {'key': 'SMTP_PORT',            'category': 'smtp', 'label': 'Port',                   'type': 'number',   'secret': False, 'default': '587',               'requires_restart': False},
    {'key': 'SMTP_USE_TLS',         'category': 'smtp', 'label': 'Activer TLS',            'type': 'boolean',  'secret': False, 'default': 'true',              'requires_restart': False},
    {'key': 'SMTP_USERNAME',        'category': 'smtp', 'label': 'Utilisateur',            'type': 'text',     'secret': False, 'default': '',                  'requires_restart': False},
    {'key': 'SMTP_PASSWORD',        'category': 'smtp', 'label': 'Mot de passe',           'type': 'password', 'secret': True,  'default': '',                  'requires_restart': False},
    {'key': 'SMTP_FROM_EMAIL',      'category': 'smtp', 'label': 'Email expéditeur',       'type': 'text',     'secret': False, 'default': '',                  'requires_restart': False},
    {'key': 'SMTP_FROM_NAME',       'category': 'smtp', 'label': 'Nom expéditeur',         'type': 'text',     'secret': False, 'default': 'Migration Factory', 'requires_restart': False},
    {'key': 'PASSWORD_RESET_EXPIRY','category': 'smtp', 'label': 'Expiration lien (s)',    'type': 'number',   'secret': False, 'default': '3600',              'requires_restart': False},
    {'key': 'FRONTEND_URL',         'category': 'smtp', 'label': 'URL frontend',           'type': 'url',      'secret': False, 'default': 'http://localhost:3000', 'requires_restart': False},

    # ---------- Sécurité ----------
    {'key': 'SECRET_KEY',     'category': 'security', 'label': 'Flask SECRET_KEY',        'type': 'password', 'secret': True, 'default': '', 'requires_restart': True},
    {'key': 'JWT_SECRET_KEY', 'category': 'security', 'label': 'JWT SECRET_KEY',          'type': 'password', 'secret': True, 'default': '', 'requires_restart': True},

    # ---------- Backup automatique ----------
    {'key': 'BACKUP_ENABLED',         'category': 'backup', 'label': 'Backup activé',     'type': 'boolean', 'secret': False, 'default': 'true',     'requires_restart': True},
    {'key': 'BACKUP_DIR',             'category': 'backup', 'label': 'Répertoire',        'type': 'text',    'secret': False, 'default': '/backups', 'requires_restart': True},
    {'key': 'BACKUP_HOUR',            'category': 'backup', 'label': 'Heure (0-23)',      'type': 'number',  'secret': False, 'default': '2',        'requires_restart': True},
    {'key': 'BACKUP_MINUTE',          'category': 'backup', 'label': 'Minute (0-59)',     'type': 'number',  'secret': False, 'default': '0',        'requires_restart': True},
    {'key': 'BACKUP_RETENTION_DAYS',  'category': 'backup', 'label': 'Rétention (jours)', 'type': 'number',  'secret': False, 'default': '30',       'requires_restart': True},

    # ---------- Redis & Rate limit ----------
    {'key': 'REDIS_URL',          'category': 'redis', 'label': 'URL Redis',              'type': 'url',  'secret': False, 'default': '',                  'requires_restart': True},
    {'key': 'RATE_LIMIT_DEFAULT', 'category': 'redis', 'label': 'Rate limit défaut',      'type': 'text', 'secret': False, 'default': '200/day;50/hour', 'requires_restart': True},

    # ---------- CORS & Logs ----------
    {'key': 'CORS_ORIGINS',      'category': 'cors', 'label': 'Origines autorisées',     'type': 'text', 'secret': False, 'default': '*',           'requires_restart': True},
    {'key': 'MAX_EXPORT_ROWS',   'category': 'logs', 'label': 'Lignes max par export',   'type': 'number', 'secret': False, 'default': '100000',    'requires_restart': True},
    {'key': 'EXPORT_CHUNK_SIZE', 'category': 'logs', 'label': 'Taille chunk export',     'type': 'number', 'secret': False, 'default': '5000',      'requires_restart': True},
    {'key': 'LOG_LEVEL',         'category': 'logs', 'label': 'Niveau de logs',          'type': 'text',   'secret': False, 'default': 'INFO',      'requires_restart': False},

    # ---------- Flask ----------
    {'key': 'FLASK_ENV', 'category': 'flask', 'label': 'Environnement Flask',  'type': 'text',   'secret': False, 'default': 'production', 'requires_restart': True},
    {'key': 'PORT',      'category': 'flask', 'label': 'Port backend',         'type': 'number', 'secret': False, 'default': '5000',        'requires_restart': True},

    # ---------- Assistant IA — Modèle ----------
    # Bascule local (Ollama) / distant (API OpenAI-compatible). La génération SQL
    # passe par le fournisseur actif ; tout le reste (RAG, sql_guard, readonly_ai)
    # est inchangé. requires_restart=False : lecture dynamique via config_service.
    {'key': 'AI_PROVIDER',                 'category': 'ai', 'label': 'Fournisseur actif (ollama | openai)', 'type': 'text',     'secret': False, 'default': 'ollama',                      'requires_restart': False},
    {'key': 'AI_EXTERNAL_BASE_URL',        'category': 'ai', 'label': 'URL API externe (OpenAI-compatible)', 'type': 'url',      'secret': False, 'default': 'https://api.openai.com/v1',    'requires_restart': False},
    {'key': 'AI_EXTERNAL_API_KEY',         'category': 'ai', 'label': 'Clé API externe',                     'type': 'password', 'secret': True,  'default': '',                            'requires_restart': False},
    {'key': 'AI_EXTERNAL_MODEL',           'category': 'ai', 'label': 'Modèle externe',                      'type': 'text',     'secret': False, 'default': 'gpt-4o-mini',                  'requires_restart': False},
    {'key': 'AI_EXTERNAL_TIMEOUT_SECONDS', 'category': 'ai', 'label': 'Timeout API externe (s)',             'type': 'number',   'secret': False, 'default': '60',                          'requires_restart': False},
    {'key': 'AI_EXTERNAL_MAX_TOKENS',      'category': 'ai', 'label': 'Max tokens sortie (externe)',         'type': 'number',   'secret': False, 'default': '2048',                        'requires_restart': False},
    {'key': 'AI_RAG_PROFILE',              'category': 'ai', 'label': 'Profil RAG (auto | compact | large)',  'type': 'text',     'secret': False, 'default': 'auto',                        'requires_restart': False},

    # ---------- Assistant Hermes (agent Nous Research, API OpenAI-compatible) ----------
    {'key': 'HERMES_API_URL',              'category': 'ai', 'label': 'URL API Hermes (OpenAI-compatible)',   'type': 'url',      'secret': False, 'default': 'http://10.190.100.58:8642/v1', 'requires_restart': False},
    {'key': 'HERMES_API_KEY',              'category': 'ai', 'label': 'Clé API Hermes',                       'type': 'password', 'secret': True,  'default': '',                            'requires_restart': False},
    {'key': 'HERMES_TIMEOUT_SECONDS',      'category': 'ai', 'label': 'Timeout Hermes (s)',                   'type': 'number',   'secret': False, 'default': '300',                         'requires_restart': False},
    # Profil = agent cible sur le gateway, insere dans l'URL (/p/<profil>/v1/...).
    # Defaut vide = agent Hermes par defaut (comportement historique) : n'activer
    # un profil qu'une fois le gateway configure pour le servir
    # (gateway.multiplex_profiles), sinon toute route /p/... repond 404.
    {'key': 'HERMES_PROFILE',              'category': 'ai', 'label': "Profil Hermes (ex. migration ; vide = agent par défaut)", 'type': 'text', 'secret': False, 'default': '',        'requires_restart': False},
]


CATEGORY_LABELS = {
    'database':   'Base de données PostgreSQL',
    'sap':        'SAP Extraction',
    'sharepoint': 'SharePoint / ASAP',
    'smtp':       'SMTP (mot de passe oublié)',
    'security':   'Sécurité (JWT / Secrets)',
    'backup':     'Backup automatique',
    'redis':      'Redis & Rate limiting',
    'cors':       'CORS',
    'logs':       'Logs & Limites',
    'flask':      'Flask / Runtime',
    'ai':         'Assistant IA — Modèle',
}


def _read_db_overrides():
    """Retourne {key: value} des surcharges stockées en base."""
    try:
        with get_db_connection() as conn:
            with conn.cursor(cursor_factory=RealDictCursor) as cur:
                cur.execute("SELECT key, value FROM public.system_config")
                return {row['key']: row['value'] for row in cur.fetchall()}
    except Exception as e:
        logger.warning(f"Lecture system_config impossible: {e}")
        return {}


def _resolve_value(meta, db_overrides):
    """Ordre de résolution : DB > env > default."""
    if meta['key'] in db_overrides and db_overrides[meta['key']] is not None:
        return db_overrides[meta['key']]
    env_value = os.environ.get(meta['key'])
    if env_value is not None and env_value != '':
        return env_value
    return meta['default']


@settings_blueprint.route('', methods=['GET'])
@settings_blueprint.route('/', methods=['GET'])
@jwt_required()
def get_settings():
    """Retourne toutes les variables groupées par catégorie."""
    db_overrides = _read_db_overrides()
    grouped = {}
    for meta in SETTINGS_CATALOG:
        value = _resolve_value(meta, db_overrides)
        # Masquer les secrets quand une valeur existe
        display_value = MASK if (meta['secret'] and value) else value
        item = {
            'key': meta['key'],
            'label': meta['label'],
            'type': meta['type'],
            'secret': meta['secret'],
            'value': display_value,
            'has_value': bool(value),
            'requires_restart': meta.get('requires_restart', False),
        }
        grouped.setdefault(meta['category'], []).append(item)

    categories = [
        {'key': cat, 'label': CATEGORY_LABELS.get(cat, cat), 'items': items}
        for cat, items in grouped.items()
    ]
    # Tri stable selon l'ordre du dict CATEGORY_LABELS
    order = list(CATEGORY_LABELS.keys())
    categories.sort(key=lambda c: order.index(c['key']) if c['key'] in order else 999)

    return jsonify({'success': True, 'data': categories}), 200


@settings_blueprint.route('', methods=['PUT'])
@settings_blueprint.route('/', methods=['PUT'])
@admin_required
def update_settings():
    """
    Met à jour les paramètres.
    Body: { "values": { "DB_HOST": "...", "SMTP_PASSWORD": "...", ... } }

    Une valeur égale au masque '••••••••' ou vide pour un secret est ignorée
    (conservation de la valeur existante).
    """
    payload = request.get_json(silent=True) or {}
    values = payload.get('values') or {}
    if not isinstance(values, dict):
        return jsonify({'success': False, 'error': 'Le champ "values" doit être un objet'}), 400

    catalog_by_key = {m['key']: m for m in SETTINGS_CATALOG}

    updated = []
    ignored = []
    user = (request.headers.get('X-User') or 'system').strip()[:100]

    try:
        with get_db_connection() as conn:
            with conn.cursor() as cur:
                for key, raw_value in values.items():
                    meta = catalog_by_key.get(key)
                    if not meta:
                        ignored.append(key)
                        continue
                    # Ignorer si secret et valeur masquée / vide
                    if meta['secret'] and (raw_value is None or raw_value == '' or raw_value == MASK):
                        ignored.append(key)
                        continue

                    value_str = '' if raw_value is None else str(raw_value)

                    cur.execute(
                        """
                        INSERT INTO public.system_config (key, value, category, is_secret, updated_at, updated_by)
                        VALUES (%s, %s, %s, %s, CURRENT_TIMESTAMP, %s)
                        ON CONFLICT (key) DO UPDATE
                          SET value = EXCLUDED.value,
                              category = EXCLUDED.category,
                              is_secret = EXCLUDED.is_secret,
                              updated_at = CURRENT_TIMESTAMP,
                              updated_by = EXCLUDED.updated_by
                        """,
                        (key, value_str, meta['category'], meta['secret'], user)
                    )
                    # Appliquer aussi à os.environ pour les modules qui lisent dynamiquement
                    os.environ[key] = value_str
                    updated.append(key)
            conn.commit()
    except Exception as e:
        logger.exception("Erreur lors de la sauvegarde des paramètres")
        return jsonify({'success': False, 'error': str(e)}), 500

    return jsonify({
        'success': True,
        'updated': updated,
        'ignored': ignored,
        'message': f"{len(updated)} paramètre(s) sauvegardé(s)."
    }), 200


# =====================================================
# Test de connexion par type
# =====================================================
def _effective(key):
    """Renvoie la valeur effective d'une variable (DB > env > default catalogue)."""
    db_overrides = _read_db_overrides()
    meta = next((m for m in SETTINGS_CATALOG if m['key'] == key), None)
    if not meta:
        return os.environ.get(key, '')
    return _resolve_value(meta, db_overrides)


@settings_blueprint.route('/test/database', methods=['POST'])
@admin_required
def test_database():
    """Teste la connexion PostgreSQL avec les valeurs courantes."""
    import psycopg2
    try:
        conn = psycopg2.connect(
            host=_effective('DB_HOST'),
            port=int(_effective('DB_PORT') or 5432),
            dbname=_effective('DB_NAME'),
            user=_effective('DB_USER'),
            password=_effective('DB_PASSWORD'),
            connect_timeout=5,
        )
        with conn.cursor() as cur:
            cur.execute("SELECT version()")
            version = cur.fetchone()[0]
        conn.close()
        return jsonify({'success': True, 'message': 'Connexion OK', 'details': version}), 200
    except Exception as e:
        return jsonify({'success': False, 'error': str(e)}), 200


@settings_blueprint.route('/test/sap', methods=['POST'])
@admin_required
def test_sap():
    """Teste l'accessibilité de l'API SAP Extraction (/health ou racine)."""
    import requests
    url = _effective('SAP_EXTRACTION_API_URL') or ''
    if not url:
        return jsonify({'success': False, 'error': 'SAP_EXTRACTION_API_URL non défini'}), 200
    timeout = int(_effective('SAP_API_TIMEOUT') or 10)
    try:
        for path in ('/health', '/'):
            try:
                r = requests.get(url.rstrip('/') + path, timeout=timeout)
                if r.status_code < 500:
                    return jsonify({
                        'success': True,
                        'message': f"API SAP atteinte ({r.status_code})",
                        'details': f"GET {url}{path} → {r.status_code}"
                    }), 200
            except requests.RequestException:
                continue
        return jsonify({'success': False, 'error': 'Aucun endpoint /health ni / accessible'}), 200
    except Exception as e:
        return jsonify({'success': False, 'error': str(e)}), 200


@settings_blueprint.route('/test/sharepoint', methods=['POST'])
@admin_required
def test_sharepoint():
    """Teste l'authentification NTLM SharePoint."""
    import requests
    from requests_ntlm import HttpNtlmAuth
    base_url = _effective('SHAREPOINT_BASE_URL') or ''
    user = _effective('SHAREPOINT_USER') or ''
    password = _effective('SHAREPOINT_PASSWORD') or ''
    if not (base_url and user and password):
        return jsonify({'success': False, 'error': 'URL/utilisateur/mot de passe SharePoint manquants'}), 200
    try:
        r = requests.get(
            base_url.rstrip('/') + '/_api/web',
            auth=HttpNtlmAuth(user, password),
            headers={'Accept': 'application/json;odata=verbose'},
            timeout=10,
            verify=False,
        )
        if r.status_code in (200, 301, 302):
            return jsonify({'success': True, 'message': f'Authentification OK ({r.status_code})'}), 200
        return jsonify({'success': False, 'error': f'HTTP {r.status_code}', 'details': r.text[:200]}), 200
    except Exception as e:
        return jsonify({'success': False, 'error': str(e)}), 200


@settings_blueprint.route('/test/ai', methods=['POST'])
@admin_required
def test_ai():
    """
    Teste l'accès au modèle externe (API OpenAI-compatible) avec les valeurs
    courantes : GET {base_url}/models en Bearer. Valide URL + clé + joignabilité.
    """
    import requests
    base_url = (_effective('AI_EXTERNAL_BASE_URL') or '').rstrip('/')
    api_key = _effective('AI_EXTERNAL_API_KEY') or ''
    model = _effective('AI_EXTERNAL_MODEL') or ''
    timeout = int(_effective('AI_EXTERNAL_TIMEOUT_SECONDS') or 60)
    if not base_url:
        return jsonify({'success': False, 'error': 'AI_EXTERNAL_BASE_URL non défini'}), 200
    if not api_key:
        return jsonify({'success': False, 'error': 'AI_EXTERNAL_API_KEY non définie'}), 200
    try:
        r = requests.get(
            base_url + '/models',
            headers={'Authorization': f'Bearer {api_key}'},
            timeout=min(timeout, 15),
        )
        if r.status_code in (401, 403):
            return jsonify({'success': False, 'error': f'Authentification refusée (HTTP {r.status_code}) — vérifiez la clé API'}), 200
        if r.status_code >= 400:
            return jsonify({'success': False, 'error': f'HTTP {r.status_code}', 'details': r.text[:200]}), 200
        # Tente de confirmer la présence du modèle configuré (best-effort).
        details = f"Endpoint joignable ({r.status_code})"
        try:
            ids = [m.get('id', '') for m in (r.json().get('data') or [])]
            if model and ids:
                present = any(model == i or model.split(':')[0] == i.split(':')[0] for i in ids)
                details += f" — modèle « {model} » " + ('présent' if present else 'introuvable dans la liste')
        except Exception:
            pass
        return jsonify({'success': True, 'message': 'Connexion OK', 'details': details}), 200
    except Exception as e:
        return jsonify({'success': False, 'error': str(e)}), 200


@settings_blueprint.route('/test/smtp', methods=['POST'])
@admin_required
def test_smtp():
    """Teste la connexion SMTP (login uniquement)."""
    server = _effective('SMTP_SERVER') or ''
    port = int(_effective('SMTP_PORT') or 587)
    use_tls = (_effective('SMTP_USE_TLS') or 'true').lower() == 'true'
    username = _effective('SMTP_USERNAME') or ''
    password = _effective('SMTP_PASSWORD') or ''
    if not server:
        return jsonify({'success': False, 'error': 'SMTP_SERVER non défini'}), 200
    try:
        with smtplib.SMTP(server, port, timeout=10) as s:
            s.ehlo()
            if use_tls:
                s.starttls()
                s.ehlo()
            if username:
                s.login(username, password)
        return jsonify({'success': True, 'message': f'Connexion SMTP OK ({server}:{port})'}), 200
    except Exception as e:
        return jsonify({'success': False, 'error': str(e)}), 200
