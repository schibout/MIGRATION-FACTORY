# -*- coding: utf-8 -*-
"""
prechauffe_ollama — Préchauffage explicite d'Ollama (à lancer après un déploiement).

Sur CPU, le 1er appel « à froid » paie le chargement du modèle en RAM PLUS
l'évaluation du préfixe système (~8 min observées). Ce script :
  1. charge le modèle de génération (qwen2.5-coder:7b) en RAM (keep_alive 24h) ET
     ÉVALUE le préfixe SOCLE réel (get_socle, cohérent avec AI_COT_ENABLED) -> il
     reste dans le cache KV d'Ollama, donc le 1er /ask évite l'éval à froid ;
  2. charge le modèle d'embeddings (bge-m3) en RAM.

À lancer dans le conteneur backend (accès Ollama + dépendances) :
    docker-compose exec backend python prechauffe_ollama.py

⚠️ Après ce préchauffage, laisser l'assistant tranquille : chaque /ask annule le
keep-warm en vol. Inutile de spammer « réessayer » sur un 1er timeout éventuel.
"""

import os
import sys
import time
import logging

import requests

from services.ollama_service import check_health
from services.llm_service import active_provider
from services.ai_prompt_builder import get_socle
from services.ai_embeddings import embed, is_enabled as embeddings_enabled

logger = logging.getLogger(__name__)


def _cfg() -> dict:
    to = int(os.getenv("AI_TIMEOUT_SECONDS", "0"))
    return {
        "url": os.getenv("OLLAMA_URL", "http://localhost:11434").rstrip("/"),
        "model": os.getenv("OLLAMA_MODEL", "qwen2.5-coder:7b"),
        "num_ctx": int(os.getenv("AI_NUM_CTX", "4096")),
        "keep_alive": os.getenv("AI_KEEPWARM_ALIVE", "24h"),
        "timeout": (to if to > 0 else None),  # 0 = aucun délai imparti
    }


def chauffe_generation(cfg: dict) -> float:
    """Charge le modèle SQL et évalue le préfixe SOCLE (num_predict=1 : on ne veut
    pas de génération, juste l'éval du préfixe en cache KV). Renvoie la durée (s)."""
    payload = {
        "model": cfg["model"],
        "messages": [
            {"role": "system", "content": get_socle()},
            {"role": "user", "content": "ping"},
        ],
        "stream": False,
        "format": "json",
        "keep_alive": cfg["keep_alive"],
        "options": {"temperature": 0, "num_ctx": cfg["num_ctx"], "num_predict": 1},
    }
    t0 = time.time()
    resp = requests.post(f"{cfg['url']}/api/chat", json=payload, timeout=cfg["timeout"])
    resp.raise_for_status()
    return time.time() - t0


def chauffe_embeddings() -> tuple:
    """Charge bge-m3 en RAM. Renvoie (durée_s, ok)."""
    t0 = time.time()
    vec = embed("prechauffage du modele d'embeddings")
    return time.time() - t0, (vec is not None)


def main() -> int:
    logging.basicConfig(level=logging.INFO, format="%(message)s")
    cfg = _cfg()

    # La génération SQL peut être déléguée à un modèle EXTERNE (AI_PROVIDER=openai).
    # Dans ce cas le modèle local qwen n'est plus sollicité : inutile (voire
    # impossible s'il n'est plus « pull ») de le préchauffer. On saute alors la
    # passe génération et on ne chauffe QUE les embeddings (bge-m3 reste local,
    # utilisé par l'indexation des knowledge cards et le RAG sémantique).
    provider = active_provider()

    if provider == "openai":
        logger.info("ℹ️ Fournisseur de génération EXTERNE (AI_PROVIDER=openai) — "
                    "préchauffage du modèle local de génération ignoré.")
    else:
        sante = check_health()
        if not sante.get("available"):
            logger.error(f"❌ Ollama indisponible : {sante.get('error')}")
            return 1
        if sante.get("model_present") is False:
            logger.warning(f"⚠️ Modèle {cfg['model']} absent — lancez : ollama pull {cfg['model']}")

        logger.info(f"🔥 Préchauffage de {cfg['model']} (préfixe SOCLE, num_ctx={cfg['num_ctx']})…")
        try:
            dt = chauffe_generation(cfg)
            logger.info(f"✅ Modèle SQL chaud en {dt:.1f}s — préfixe SOCLE en cache KV.")
        except requests.exceptions.RequestException as e:
            logger.error(f"❌ Préchauffage génération échoué : {e}")
            return 1

    if embeddings_enabled():
        logger.info("🔥 Préchauffage des embeddings (bge-m3)…")
        dte, ok = chauffe_embeddings()
        if ok:
            logger.info(f"✅ Embeddings chauds en {dte:.1f}s.")
        else:
            logger.warning("⚠️ Embeddings non chauffés (modèle indisponible).")
    else:
        logger.info("Embeddings désactivés (AI_EMBED_ENABLED=false) — non chauffés.")

    if provider == "openai":
        logger.info("Terminé. Génération externe : embeddings locaux prêts pour l'indexation / le RAG.")
    else:
        logger.info("Terminé. Le 1er /ask évitera l'évaluation à froid du préfixe.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
