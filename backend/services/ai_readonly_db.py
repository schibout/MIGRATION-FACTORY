"""
ai_readonly_db — Engine SQLAlchemy pour l'exécution du SQL généré par l'IA.

⚠️ SÉCURITÉ (décision explicite du 2026-07-07) : l'Assistant IA utilise
désormais le compte PRINCIPAL `postgres` (SUPERUSER) et NON plus le rôle
restreint `readonly_ai`. Conséquence : le garde-fou « rôle en lecture seule »
est RETIRÉ — la seule barrière restante contre les requêtes destructives est
`sql_guard` (SELECT/WITH uniquement, blacklist DDL/DML, blacklist de fonctions
dangereuses). Tout SQL qui franchit sql_guard s'exécute avec les pleins droits.

Le `statement_timeout` de 30 s était auparavant porté par le rôle `readonly_ai`
(`ALTER ROLE ... SET statement_timeout=30s`) ; `postgres` ne l'a pas. On le
réinjecte ici au niveau de CHAQUE connexion pour conserver ce garde-fou.
"""

import os
import threading
import logging

import pandas as pd
from sqlalchemy import create_engine

logger = logging.getLogger(__name__)

_engine = None
_engine_lock = threading.Lock()

# statement_timeout (ms) appliqué à chaque connexion de cet engine : conserve le
# garde-fou « requête trop longue » que portait le rôle readonly_ai.
_STATEMENT_TIMEOUT_MS = int(os.getenv("AI_STATEMENT_TIMEOUT_MS", "30000"))


def _build_uri() -> str:
    # Compte principal postgres (superuser) : on réutilise la MÊME source
    # d'identifiants que l'app (config.database.get_db_params) — dont le défaut
    # de mot de passe qui fonctionne sans .env. On IGNORE volontairement
    # AI_DB_USER/AI_DB_PASSWORD (qui pointaient sur readonly_ai).
    from config.database import get_db_params
    p = get_db_params()
    return (f"postgresql+psycopg2://{p['user']}:{p['password']}"
            f"@{p['host']}:{p['port']}/{p['database']}")


def get_readonly_engine():
    """Renvoie (en le créant à la demande) l'engine partagé de l'IA.
    NB : le nom conserve « readonly » pour compat, mais l'engine utilise
    désormais le compte postgres (cf. avertissement en tête de module)."""
    global _engine
    if _engine is None:
        with _engine_lock:
            if _engine is None:
                logger.info("🔓 Initialisation de l'engine SQLAlchemy IA (compte postgres, statement_timeout=%sms)",
                            _STATEMENT_TIMEOUT_MS)
                _engine = create_engine(
                    _build_uri(),
                    pool_size=2,
                    max_overflow=1,
                    pool_pre_ping=True,
                    pool_recycle=900,
                    connect_args={"options": f"-c statement_timeout={_STATEMENT_TIMEOUT_MS}"},
                )
    return _engine


def run_readonly_query(sql: str):
    """
    Exécute `sql` (déjà validé/borné par sql_guard) via le rôle readonly_ai.

    Retour : (colonnes: list[str], lignes: list[dict]).
    Lève l'exception d'origine en cas d'erreur (timeout, droits...).

    On passe par un curseur psycopg2 BRUT, exécuté SANS argument de paramètres :
    c'est le seul cas où psycopg2 ne tente aucune substitution, donc les « % »
    littéraux (LIKE '%x%') et les casts « ::type » passent tels quels.
    (exec_driver_sql / text() fournissent un immutabledict vide à psycopg2, qui
    traite alors les « % » comme des placeholders -> « immutabledict is not a
    sequence ».)
    """
    engine = get_readonly_engine()
    raw = engine.raw_connection()   # connexion du pool, proxy fairy
    try:
        cur = raw.cursor()
        try:
            cur.execute(sql)        # AUCUN 2e argument -> pas d'interpolation %
            colonnes = [d[0] for d in cur.description]
            rows = cur.fetchall()
        finally:
            cur.close()
    finally:
        raw.close()                 # rend la connexion au pool (rollback auto)
    df = pd.DataFrame(rows, columns=colonnes)
    lignes = df.to_dict("records")
    return colonnes, lignes
