"""
external_llm_service — Pont vers un modèle externe via une API
**OpenAI-compatible** (OpenAI, Azure OpenAI, Mistral, Groq, OpenRouter, vLLM…).

Rôle STRICTEMENT identique à ollama_service : transformer une question en
français en une requête SQL ``{sql, explication}``. Le prompt RAG est construit
en amont par ai_assistant (build_dynamic_prompt) et passé tel quel ici : ce
module ne contient AUCUNE logique de prompt, il ne fait que relayer le
``system_prompt`` reçu vers le modèle distant.

Contrat respecté pour rester interchangeable avec ollama_service :
- mêmes fonctions publiques : generate_sql / repair_sql / check_health ;
- mêmes exceptions levées (OllamaUnavailableError / OllamaError), réutilisées
  depuis ollama_service pour ne rien changer aux ``except`` d'ai_assistant ;
- même retry unique sur JSON non exploitable, aligné sur le mode CoT.

Différences avec Ollama : pas de sémaphore (le cloud encaisse la concurrence,
donc pas d'OllamaBusyError), pas de keep-warm, options OpenAI (max_tokens,
response_format) au lieu des options Ollama (num_ctx, num_predict).
"""

import re
import logging

import requests

from services.config_service import get_config, get_config_int, get_config_bool
# Réutilise les helpers de parsing JSON et les exceptions d'ollama_service :
# on garde un seul contrat de sortie et un seul jeu d'exceptions côté appelant.
from services.ollama_service import (
    _strip_json_fences,
    _extract_sql_payload,
    OllamaError,
    OllamaUnavailableError,
)

logger = logging.getLogger(__name__)

# Les modèles de raisonnement (Kimi, DeepSeek-R1, QwQ…) enrobent souvent leur
# réponse de raisonnement entre balises <think>…</think> dans `content`.
_THINK_RE = re.compile(r"<think>.*?</think>", re.DOTALL | re.IGNORECASE)


def _config() -> dict:
    """Lecture dynamique de la config externe (DB > env > défaut)."""
    cot = get_config_bool("AI_COT_ENABLED", True)
    # max_tokens : budget de sortie PROPRE au fournisseur externe — découplé du
    # budget Ollama (AI_NUM_PREDICT*, calibré pour un 7B CPU). Les modèles de
    # raisonnement (Kimi, R1…) consomment beaucoup de tokens AVANT le JSON :
    # un plafond généreux évite une réponse tronquée donc non parsable.
    max_tokens = get_config_int("AI_EXTERNAL_MAX_TOKENS", 2048)
    _t = get_config_int("AI_EXTERNAL_TIMEOUT_SECONDS", 60)
    return {
        "base_url": (get_config("AI_EXTERNAL_BASE_URL", "https://api.openai.com/v1") or "").rstrip("/"),
        "api_key": get_config("AI_EXTERNAL_API_KEY", "") or "",
        "model": get_config("AI_EXTERNAL_MODEL", "gpt-4o-mini") or "gpt-4o-mini",
        "timeout": (_t if _t > 0 else None),
        "max_tokens": max_tokens,
        "cot": cot,
    }


def _extract_json_block(text: str) -> str:
    """
    Isole le premier objet JSON ÉQUILIBRÉ d'une sortie potentiellement polluée
    par du raisonnement (<think>…</think>), du markdown ou de la prose — fréquent
    avec les modèles « reasoning » et les endpoints OpenAI-compatibles (NVIDIA
    NIM, OpenRouter…) qui n'honorent pas response_format.

    Le scan respecte les chaînes JSON (accolades entre guillemets ignorées), donc
    un raisonnement contenant « {a, b} » ne fausse pas la détection.
    """
    if not text:
        return text
    cleaned = _strip_json_fences(_THINK_RE.sub("", text)).strip()
    start = cleaned.find("{")
    if start == -1:
        return cleaned
    depth = 0
    in_str = False
    esc = False
    for i in range(start, len(cleaned)):
        c = cleaned[i]
        if in_str:
            if esc:
                esc = False
            elif c == "\\":
                esc = True
            elif c == '"':
                in_str = False
        elif c == '"':
            in_str = True
        elif c == "{":
            depth += 1
        elif c == "}":
            depth -= 1
            if depth == 0:
                return cleaned[start:i + 1]
    return cleaned[start:]  # accolade non fermée (tronqué) → json.loads échouera


def _parse_payload(content: str) -> dict:
    """Parse tolérant : tente le contenu direct, puis l'objet JSON isolé.
    Lève ValueError si rien d'exploitable (propagé aux appelants)."""
    try:
        return _extract_sql_payload(content)
    except ValueError:
        return _extract_sql_payload(_extract_json_block(content))


def _call_chat(messages: list, cfg: dict) -> str:
    """Appel bas-niveau à /chat/completions. Renvoie le contenu texte du message."""
    if not cfg["api_key"]:
        raise OllamaUnavailableError("Clé API externe non configurée (AI_EXTERNAL_API_KEY).")
    payload = {
        "model": cfg["model"],
        "messages": messages,
        "temperature": 0,
        "max_tokens": int(cfg["max_tokens"]),
        # Sortie JSON garantie côté serveurs compatibles ; le prompt demande de
        # toute façon un JSON, et le parsing reste tolérant (fences markdown).
        "response_format": {"type": "json_object"},
        "stream": False,
    }
    try:
        resp = requests.post(
            f"{cfg['base_url']}/chat/completions",
            json=payload,
            headers={
                "Authorization": f"Bearer {cfg['api_key']}",
                "Content-Type": "application/json",
            },
            timeout=cfg["timeout"],
        )
    except requests.exceptions.Timeout:
        raise OllamaUnavailableError(
            f"Le modèle externe n'a pas répondu dans le délai imparti ({cfg['timeout']}s)."
        )
    except requests.exceptions.RequestException as e:
        raise OllamaUnavailableError(f"Modèle externe injoignable : {e}")

    if resp.status_code in (401, 403):
        raise OllamaUnavailableError(
            f"Authentification refusée par le modèle externe (HTTP {resp.status_code}) — "
            "vérifiez la clé API."
        )
    if resp.status_code == 429:
        raise OllamaUnavailableError(
            "Le modèle externe a renvoyé HTTP 429 (quota ou limite de débit atteint)."
        )
    if resp.status_code == 404:
        # Modèle inexistant/retiré pour ce compte (ex. NVIDIA NIM « Function ...
        # Not found for account ») ou mauvais endpoint.
        raise OllamaUnavailableError(
            f"Modèle externe introuvable (HTTP 404) — vérifiez AI_EXTERNAL_MODEL "
            f"(« {cfg['model']} ») et AI_EXTERNAL_BASE_URL. Détail : {resp.text[:200]}"
        )
    if resp.status_code != 200:
        raise OllamaUnavailableError(
            f"Le modèle externe a répondu HTTP {resp.status_code} : {resp.text[:200]}"
        )

    try:
        body = resp.json()
        choice = body["choices"][0]
        msg = choice.get("message") or {}
        # Certains modèles de raisonnement laissent `content` vide et placent le
        # texte dans `reasoning_content` : on s'y rabat.
        content = msg.get("content") or msg.get("reasoning_content") or ""
        finish = choice.get("finish_reason")
    except (KeyError, IndexError, ValueError, TypeError) as e:
        raise OllamaError(f"Réponse du modèle externe inattendue : {e}")

    if finish == "length":
        # Sortie tronquée par max_tokens → le JSON est presque sûrement incomplet.
        logger.warning(
            "Modèle externe : sortie tronquée (finish_reason=length, max_tokens=%s). "
            "Augmentez AI_EXTERNAL_MAX_TOKENS.", cfg.get("max_tokens"),
        )
    return content


def generate_sql(question: str, system_prompt: str) -> dict:
    """
    Génère une requête SQL à partir d'une question (FR) via le modèle externe.

    Retour : {"sql": "...", "explication": "..."}.
    Exceptions :
        OllamaUnavailableError — service indisponible / timeout / clé invalide
        OllamaError            — réponse non parsable après retry
    """
    cfg = _config()
    messages = [
        {"role": "system", "content": system_prompt},
        {"role": "user", "content": question},
    ]

    content = _call_chat(messages, cfg)
    try:
        return _parse_payload(content)
    except ValueError:
        logger.warning(
            "Réponse modèle externe non-JSON, retry unique. Aperçu: %r",
            (content or "")[:500],
        )

    _fmt = ('{"raisonnement": "...", "sql": "...", "explication": "..."}'
            if cfg.get("cot") else '{"sql": "...", "explication": "..."}')
    messages.append({"role": "assistant", "content": content})
    messages.append({
        "role": "user",
        "content": f"Réponds UNIQUEMENT le JSON demandé : {_fmt} "
                   "sans texte autour, sans markdown, sans balises de raisonnement.",
    })
    content_retry = _call_chat(messages, cfg)
    try:
        return _parse_payload(content_retry)
    except ValueError:
        logger.warning(
            "Échec parsing modèle externe après retry. Aperçu: %r",
            (content_retry or "")[:500],
        )
        raise OllamaError(
            "Le modèle externe n'a pas renvoyé un JSON exploitable. Reformulez votre question."
        )


def repair_sql(question: str, system_prompt: str, bad_sql: str, erreur: str) -> dict:
    """
    Tente UNE correction d'un SQL fautif via le modèle externe (même contrat que
    ollama_service.repair_sql).

    Retour : {"sql": "...", "explication": "..."}.
    Exceptions : OllamaUnavailableError / OllamaError.
    """
    cfg = _config()
    correction = (
        "La requête SQL que tu as générée a échoué à l'exécution.\n"
        f"Question initiale : {question}\n"
        f"SQL fautif : {bad_sql}\n"
        f"Erreur PostgreSQL : {erreur}\n"
        "Corrige la requête en utilisant UNIQUEMENT des tables et colonnes "
        "réellement existantes du schéma fourni. Réponds UNIQUEMENT le JSON "
        '{"sql": "...", "explication": "..."} sans texte autour, sans markdown.'
    )
    messages = [
        {"role": "system", "content": system_prompt},
        {"role": "user", "content": correction},
    ]
    content = _call_chat(messages, cfg)
    try:
        return _parse_payload(content)
    except ValueError:
        raise OllamaError(
            "Le modèle externe n'a pas renvoyé un JSON exploitable lors de la correction."
        )


def check_health() -> dict:
    """
    Vérifie que l'API externe est joignable et que le modèle configuré est présent.

    Retour : {"available": bool, "model": str, "model_present": bool,
              "models": [..], "error": str|None}
    """
    cfg = _config()
    result = {
        "available": False,
        "model": cfg["model"],
        "model_present": False,
        "models": [],
        "error": None,
    }
    if not cfg["api_key"]:
        result["error"] = "Clé API externe non configurée."
        return result
    try:
        resp = requests.get(
            f"{cfg['base_url']}/models",
            headers={"Authorization": f"Bearer {cfg['api_key']}"},
            timeout=10,
        )
        if resp.status_code in (401, 403):
            result["error"] = f"Authentification refusée (HTTP {resp.status_code})."
            return result
        if resp.status_code != 200:
            result["error"] = f"HTTP {resp.status_code}"
            return result
        ids = [m.get("id", "") for m in (resp.json().get("data") or [])]
        result["available"] = True
        result["models"] = ids
        result["model_present"] = any(
            cfg["model"] == i or cfg["model"].split(":")[0] == i.split(":")[0]
            for i in ids
        ) if ids else True  # certains endpoints ne listent pas les modèles
    except requests.exceptions.RequestException as e:
        result["error"] = str(e)
    return result
