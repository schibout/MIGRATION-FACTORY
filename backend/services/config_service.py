"""
Helper centralise pour lire les variables de configuration.

Ordre de resolution :
  1. Table public.system_config (modifiable via la page Parametres)
  2. Variable d'environnement (.env / os.environ)
  3. Valeur par defaut passee a get_config()

Exception : les cles listees dans CONFIG_ENV_PRIORITY inversent 1 et 2.
La base prime a raison en production (la page Parametres doit gagner), mais un
poste de developpement branche sur la base du serveur ne peut alors surcharger
aucune valeur : ecrire l'adresse locale dans system_config casserait le serveur.
Cette variable n'existe pas en production -> comportement inchange la-bas.

Toutes les valeurs sont retournees en str (ou None si vide et pas de default).
"""

import os
import logging
from typing import Optional

from config.database import get_db_connection

logger = logging.getLogger(__name__)


def _priorite_environnement(key: str) -> bool:
    """La cle figure-t-elle dans CONFIG_ENV_PRIORITY (liste separee par virgules) ?"""
    brut = os.environ.get('CONFIG_ENV_PRIORITY', '')
    if not brut:
        return False
    return key.strip().upper() in {c.strip().upper() for c in brut.split(',') if c.strip()}


def get_config(key: str, default: Optional[str] = None) -> Optional[str]:
    """Renvoie la valeur effective d'une cle de configuration."""
    # 0. Surcharge locale explicite : l'environnement passe devant la base.
    #    Valeur vide ignoree (une variable vide n'efface pas la config serveur).
    if _priorite_environnement(key):
        surcharge = os.environ.get(key)
        if surcharge not in (None, ''):
            return surcharge

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
