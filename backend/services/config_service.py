"""
Helper centralise pour lire les variables de configuration.

Ordre de resolution :
  1. Table public.system_config (modifiable via la page Parametres)
  2. Variable d'environnement (.env / os.environ)
  3. Valeur par defaut passee a get_config()

Toutes les valeurs sont retournees en str (ou None si vide et pas de default).
"""

import os
import logging
from typing import Optional

from config.database import get_db_connection

logger = logging.getLogger(__name__)


def get_config(key: str, default: Optional[str] = None) -> Optional[str]:
    """Renvoie la valeur effective d'une cle de configuration."""
    # 1. system_config (DB)
    try:
        with get_db_connection() as conn:
            with conn.cursor() as cur:
                cur.execute(
                    "SELECT value FROM public.system_config WHERE key = %s",
                    (key,)
                )
                row = cur.fetchone()
                if row and row[0] not in (None, ''):
                    return row[0]
    except Exception as e:
        logger.debug(f"Lecture system_config({key}) impossible: {e}")

    # 2. Variable d'environnement
    env_value = os.environ.get(key)
    if env_value not in (None, ''):
        return env_value

    # 3. Default
    return default


def get_config_int(key: str, default: int = 0) -> int:
    """Version entiere de get_config (silencieuse si valeur non numerique)."""
    raw = get_config(key)
    if raw is None or raw == '':
        return default
    try:
        return int(raw)
    except (TypeError, ValueError):
        return default


def get_config_bool(key: str, default: bool = False) -> bool:
    """Version booleenne (true/1/yes/on -> True)."""
    raw = get_config(key)
    if raw is None or raw == '':
        return default
    return str(raw).strip().lower() in ('true', '1', 'yes', 'on')
