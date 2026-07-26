"""
Service de cache generique (chaines JSON).

Strategie "option Redis" :
  - Si Config.REDIS_URL est defini ET la lib redis est installee ET le serveur
    repond -> cache **Redis** (partage entre tous les workers gunicorn).
  - Sinon -> repli automatique en **cache memoire** (par worker, TTL respecte).

Le cache stocke des CHAINES deja serialisees (JSON) : les reponses HTTP mises
en cache sont ainsi renvoyees a l'octet pres, identiques a la version fraiche.

Desactivation globale : Config.CACHE_ENABLED = false.
"""
import logging
import threading
import time

from config.settings import Config

logger = logging.getLogger(__name__)

_redis_client = None
_redis_init = False
_lock = threading.Lock()

# Repli memoire : { key: (expiry_ts, value_str) }
_MEM: dict = {}


def _enabled() -> bool:
    return getattr(Config, 'CACHE_ENABLED', True)


def _get_redis():
    """Client Redis (singleton paresseux) ou None si indisponible."""
    global _redis_client, _redis_init
    if _redis_init:
        return _redis_client
    with _lock:
        if _redis_init:
            return _redis_client
        _redis_init = True
        url = getattr(Config, 'REDIS_URL', None)
        if not url:
            logger.info('Cache : REDIS_URL non defini -> repli cache memoire')
            _redis_client = None
            return None
        try:
            import redis  # dependance optionnelle
            client = redis.Redis.from_url(
                url, socket_connect_timeout=1, socket_timeout=1, decode_responses=True
            )
            client.ping()
            _redis_client = client
            logger.info('Cache Redis actif : %s', url)
        except Exception as e:
            logger.warning('Redis indisponible (%s) -> repli cache memoire', e)
            _redis_client = None
        return _redis_client


def cache_get(key: str):
    """Retourne la chaine mise en cache, ou None."""
    if not _enabled():
        return None
    r = _get_redis()
    if r is not None:
        try:
            return r.get(key)
        except Exception as e:
            logger.warning('cache_get Redis KO (%s) -> memoire', e)
    item = _MEM.get(key)
    if not item:
        return None
    expiry, val = item
    if expiry < time.time():
        _MEM.pop(key, None)
        return None
    return val


def cache_set(key: str, value: str, ttl: int = 300) -> None:
    if not _enabled():
        return
    r = _get_redis()
    if r is not None:
        try:
            r.setex(key, ttl, value)
            return
        except Exception as e:
            logger.warning('cache_set Redis KO (%s) -> memoire', e)
    _MEM[key] = (time.time() + ttl, value)


def cache_invalidate(prefix: str) -> None:
    """Supprime toutes les cles commencant par prefix (apres une modification)."""
    if not _enabled():
        return
    r = _get_redis()
    if r is not None:
        try:
            for k in r.scan_iter(match=f'{prefix}*', count=500):
                r.delete(k)
            return
        except Exception as e:
            logger.warning('cache_invalidate Redis KO (%s) -> memoire', e)
    for k in [k for k in list(_MEM.keys()) if k.startswith(prefix)]:
        _MEM.pop(k, None)


def cache_backend() -> str:
    """'redis' ou 'memory' (pour diagnostic)."""
    return 'redis' if _get_redis() is not None else 'memory'
