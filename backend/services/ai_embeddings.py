# -*- coding: utf-8 -*-
"""
ai_embeddings — Génération d'embeddings LOCAUX pour l'Assistant IA.

Produit le vecteur sémantique d'un texte (question, description de table, exemple)
via Ollama (`POST /api/embeddings`, modèle bge-m3 par défaut, 1024 dimensions).
Aucune dépendance lourde (torch / sentence-transformers) : tout passe par le
service Ollama déjà utilisé pour la génération SQL.

Principe de robustesse : si les embeddings sont désactivés (AI_EMBED_ENABLED=false)
ou si Ollama est indisponible, `embed()` renvoie None. Les appelants (RAG
sémantique, cache) DOIVENT alors retomber sur le comportement lexical existant :
la recherche sémantique est un bonus, jamais un point de défaillance.
"""

import os
import threading
import logging
from collections import OrderedDict

import requests

logger = logging.getLogger(__name__)

# Dimension du modèle bge-m3. Doit correspondre à vector(N) de la migration 015.
EMBED_DIM = 1024

# Plafond de caractères envoyés au modèle. Filet de sécurité indépendant des
# appelants : évite l'erreur Ollama « input length exceeds the context length »
# sur les très longs textes (tables SAP à nombreuses colonnes). ~6000 caractères
# ≈ 1500 tokens, très en deçà du contexte de bge-m3, et largement suffisant pour
# capter la sémantique.
MAX_INPUT_CHARS = 6000

# Maintient le modèle d'embeddings chargé en RAM entre les appels : sans cela,
# Ollama peut le décharger et chaque appel « à froid » dépasse le timeout sur CPU.
# 24h (= comme qwen) pour garder les DEUX modèles chargés en permanence ;
# nécessite OLLAMA_MAX_LOADED_MODELS>=2 côté serveur pour ne pas s'éjecter.
EMBED_KEEP_ALIVE = os.getenv("AI_EMBED_KEEP_ALIVE", "24h")

# Cache LRU en mémoire (texte -> vecteur) : évite de ré-embedder les questions /
# descriptions identiques (le keep-warm et les questions répétées en profitent).
_CACHE_MAX = 512
_cache = OrderedDict()
_cache_lock = threading.Lock()


def _config() -> dict:
    """Lecture dynamique de la config (cohérent avec ollama_service)."""
    return {
        "url": os.getenv("OLLAMA_URL", "http://localhost:11434").rstrip("/"),
        "model": os.getenv("AI_EMBED_MODEL", "bge-m3"),
        "timeout": int(os.getenv("AI_EMBED_TIMEOUT_SECONDS", "30")),
        "enabled": os.getenv("AI_EMBED_ENABLED", "true").lower() == "true",
    }


def is_enabled() -> bool:
    return _config()["enabled"]


def _cache_get(key: str):
    with _cache_lock:
        if key in _cache:
            _cache.move_to_end(key)
            return _cache[key]
    return None


def _cache_put(key: str, value: list):
    with _cache_lock:
        _cache[key] = value
        _cache.move_to_end(key)
        while len(_cache) > _CACHE_MAX:
            _cache.popitem(last=False)


def embed(text: str):
    """
    Renvoie le vecteur (list[float], dimension EMBED_DIM) du texte, ou None si les
    embeddings sont désactivés / indisponibles (l'appelant doit alors basculer en
    mode lexical).
    """
    cfg = _config()
    if not cfg["enabled"]:
        return None
    text = (text or "").strip()
    if not text:
        return None
    # Plafond de sécurité : empêche l'erreur Ollama « input length exceeds the
    # context length » quel que soit l'appelant.
    if len(text) > MAX_INPUT_CHARS:
        text = text[:MAX_INPUT_CHARS]

    cached = _cache_get(text)
    if cached is not None:
        return cached

    payload = {"model": cfg["model"], "prompt": text, "keep_alive": EMBED_KEEP_ALIVE}

    # Un essai + un retry : le premier appel « à froid » (chargement du modèle en
    # RAM) peut dépasser le timeout ; le second trouve le modèle déjà chaud.
    resp = None
    for tentative in (1, 2):
        try:
            resp = requests.post(
                f"{cfg['url']}/api/embeddings",
                json=payload,
                timeout=cfg["timeout"],
            )
            break
        except requests.exceptions.Timeout:
            if tentative == 1:
                logger.info("⏳ Embeddings : 1er appel lent (modèle en chauffe), nouvelle tentative…")
                continue
            logger.warning("⚠️ Embeddings indisponibles : délai dépassé (modèle trop lent).")
            return None
        except requests.exceptions.RequestException as e:
            logger.warning(f"⚠️ Embeddings indisponibles (Ollama injoignable) : {e}")
            return None

    if resp.status_code != 200:
        logger.warning(
            f"⚠️ Embeddings : Ollama a répondu HTTP {resp.status_code} : {resp.text[:200]}"
        )
        return None

    vector = (resp.json() or {}).get("embedding")
    if not vector or not isinstance(vector, list):
        logger.warning("⚠️ Embeddings : réponse Ollama sans champ 'embedding' exploitable.")
        return None
    if len(vector) != EMBED_DIM:
        logger.warning(
            f"⚠️ Embeddings : dimension inattendue {len(vector)} (attendu {EMBED_DIM}). "
            f"Vérifiez AI_EMBED_MODEL (={cfg['model']}) et la migration 015."
        )
        return None

    _cache_put(text, vector)
    return vector


def to_pgvector(vector) -> str:
    """
    Formate un vecteur Python en littéral pgvector ('[0.1,0.2,...]') destiné à un
    cast SQL `%s::vector`. Évite d'exiger l'adaptateur psycopg2 de pgvector.
    """
    if vector is None:
        raise ValueError("Vecteur None : impossible de le formater en pgvector.")
    return "[" + ",".join(repr(float(x)) for x in vector) + "]"


def check_embeddings_health() -> dict:
    """Diagnostic léger : modèle configuré + capacité à produire un vecteur."""
    cfg = _config()
    if not cfg["enabled"]:
        return {"enabled": False, "model": cfg["model"], "ok": False,
                "error": "Embeddings désactivés (AI_EMBED_ENABLED=false)."}
    vec = embed("test de disponibilité des embeddings")
    return {
        "enabled": True,
        "model": cfg["model"],
        "ok": vec is not None,
        "dim": len(vec) if vec else None,
        "error": None if vec else "Modèle d'embeddings injoignable ou réponse invalide.",
    }


if __name__ == "__main__":
    # Test autonome (sur le serveur) :
    #   python -m services.ai_embeddings "combien de fournisseurs actifs"
    import sys
    logging.basicConfig(level=logging.INFO)
    q = sys.argv[1] if len(sys.argv) > 1 else "combien de fournisseurs actifs"
    v = embed(q)
    if v is None:
        print("Embeddings indisponibles (voir logs / config).")
    else:
        print(f"OK — dimension {len(v)} — extrait : {v[:5]}")
