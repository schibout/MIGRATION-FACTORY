"""
ollama_service — Pont vers le modèle local Ollama (qwen2.5-coder:7b).

Rôle : transformer une question en français en une requête SQL, via l'API
native Ollama `POST /api/chat` avec `format=json` (sortie JSON garantie par
Ollama). Le modèle ne fait QUE générer du SQL ; il ne synthétise pas les
résultats (trop lent sur un 7B à ~2 tok/s).

Contraintes (cf. docs/AssistantIA.md) :
- Une seule génération à la fois (VM 4 cœurs) → threading.Semaphore(1),
  acquisition NON bloquante : si occupé, on lève OllamaBusyError (→ HTTP 429).
- Timeout requests en SECONDES (AI_TIMEOUT_SECONDS, défaut 120).
- Parsing tolérant : on retire d'éventuels fences markdown, puis json.loads ;
  en cas d'échec, un seul retry avec un message correctif ; au 2e échec, erreur.
"""

import os
import json
import socket
import threading
import logging

import requests

logger = logging.getLogger(__name__)


# --------------------------------------------------------------------------- #
# Exceptions
# --------------------------------------------------------------------------- #
class OllamaError(Exception):
    """Erreur générique de génération (réponse inexploitable)."""
    pass


class OllamaBusyError(Exception):
    """Une génération est déjà en cours (sémaphore occupé)."""
    pass


class OllamaUnavailableError(Exception):
    """Ollama injoignable (service arrêté, mauvaise URL, timeout réseau)."""
    pass


# Verrou global : une seule génération simultanée sur la VM.
_generation_lock = threading.Semaphore(1)

# --------------------------------------------------------------------------- #
# Coordination préchauffage <-> requêtes utilisateur
#
# Un compteur de requêtes utilisateur actives (et non un simple booléen) pour
# gérer correctement les /ask concurrents. Tant que le compteur > 0, le
# préchauffage se met en pause ; à chaque nouvelle requête utilisateur, on
# annule un éventuel préchauffage en vol (fermeture de la connexion HTTP ->
# Ollama abandonne la génération et libère son slot).
# --------------------------------------------------------------------------- #
_user_lock = threading.Lock()
_user_count = 0

_warmup_inflight_lock = threading.Lock()
_warmup_inflight_resp = None  # réponse HTTP du préchauffage en cours (pour l'abandonner)


def _abort_inflight_warmup():
    with _warmup_inflight_lock:
        resp = _warmup_inflight_resp
    if resp is not None:
        try:
            resp.close()
        except Exception:
            pass


def _user_enter():
    """Signale le début d'une requête utilisateur (annule le préchauffage en vol)."""
    global _user_count
    with _user_lock:
        _user_count += 1
    _abort_inflight_warmup()


def _user_exit():
    """Signale la fin d'une requête utilisateur."""
    global _user_count
    with _user_lock:
        _user_count = max(0, _user_count - 1)


def _user_busy() -> bool:
    with _user_lock:
        return _user_count > 0


def _config():
    """Lecture dynamique de la config (cohérent avec la page Paramètres)."""
    # AI_TIMEOUT_SECONDS <= 0 (ou absent) => aucun délai imparti (timeout=None).
    # La génération tourne en tâche de fond (worker), il n'y a pas de timeout
    # navigateur ; le seul garde-fou serveur reste le statement_timeout (30 s)
    # qui ne couvre QUE l'exécution SQL, pas la génération du modèle.
    _t = int(os.getenv("AI_TIMEOUT_SECONDS", "0"))
    # CoT (raisonnement avant SQL) -> plafond de sortie relevé sinon le SQL est
    # tronqué après le raisonnement.
    cot = os.getenv("AI_COT_ENABLED", "true").strip().lower() in ("1", "true", "yes", "on")
    num_predict = (int(os.getenv("AI_NUM_PREDICT_COT", "640")) if cot
                   else int(os.getenv("AI_NUM_PREDICT", "256")))
    return {
        "url": os.getenv("OLLAMA_URL", "http://localhost:11434").rstrip("/"),
        "model": os.getenv("OLLAMA_MODEL", "qwen2.5-coder:7b"),
        "timeout": (_t if _t > 0 else None),
        "num_ctx": int(os.getenv("AI_NUM_CTX", "4096")),
        "num_predict": num_predict,
        "cot": cot,
    }


def _strip_json_fences(text: str) -> str:
    """Retire d'éventuels fences markdown ```json ... ``` autour du JSON."""
    if not text:
        return ""
    cleaned = text.strip()
    if cleaned.startswith("```"):
        # Retire la première ligne de fence (``` ou ```json) et la dernière.
        lines = cleaned.splitlines()
        if lines and lines[0].startswith("```"):
            lines = lines[1:]
        if lines and lines[-1].strip().startswith("```"):
            lines = lines[:-1]
        cleaned = "\n".join(lines).strip()
    return cleaned


def _extract_sql_payload(content: str) -> dict:
    """
    Parse le contenu renvoyé par le modèle en dict {sql, explication}.
    Lève ValueError si le JSON est inexploitable.
    """
    cleaned = _strip_json_fences(content)
    data = json.loads(cleaned)  # peut lever ValueError/JSONDecodeError
    if not isinstance(data, dict) or "sql" not in data:
        raise ValueError("JSON sans champ 'sql'")
    return {
        "sql": str(data.get("sql", "")).strip(),
        "explication": str(data.get("explication", "")).strip(),
    }


def _call_chat(messages: list, cfg: dict) -> str:
    """Appel bas-niveau à /api/chat. Renvoie le contenu texte du message."""
    payload = {
        "model": cfg["model"],
        "messages": messages,
        "stream": False,
        "format": "json",
        "keep_alive": "24h",
        # num_predict borne la sortie : une requête SQL + une explication courte
        # tiennent largement dans ~256 tokens. Sur CPU (~3 tok/s) chaque token
        # coûte cher : plafonner bas réduit fortement le pire cas (timeout).
        # num_ctx aligné sur la taille réelle du prompt compacté.
        "options": {
            "temperature": 0,
            "num_ctx": int(cfg.get("num_ctx", 4096)),
            "num_predict": int(cfg.get("num_predict", 256)),
        },
    }
    try:
        resp = requests.post(
            f"{cfg['url']}/api/chat",
            json=payload,
            timeout=cfg["timeout"],
        )
    except requests.exceptions.Timeout:
        raise OllamaUnavailableError(
            f"Le modèle local n'a pas répondu dans le délai imparti ({cfg['timeout']}s)."
        )
    except requests.exceptions.RequestException as e:
        raise OllamaUnavailableError(f"Ollama injoignable : {e}")

    if resp.status_code != 200:
        raise OllamaUnavailableError(
            f"Ollama a répondu HTTP {resp.status_code} : {resp.text[:200]}"
        )

    body = resp.json()
    return (body.get("message") or {}).get("content", "")


def generate_sql(question: str, system_prompt: str) -> dict:
    """
    Génère une requête SQL à partir d'une question en français.

    Retour : {"sql": "...", "explication": "..."}.
    Exceptions :
        OllamaBusyError        — une génération est déjà en cours (→ 429)
        OllamaUnavailableError — service indisponible / timeout
        OllamaError            — réponse non parsable après retry
    """
    cfg = _config()

    # Signale une requête utilisateur : annule le préchauffage en vol et lui
    # interdit de redémarrer tant que l'utilisateur est servi (priorité user).
    _user_enter()
    try:
        # Acquisition NON bloquante : on ne fait pas la file d'attente.
        if not _generation_lock.acquire(blocking=False):
            raise OllamaBusyError("Une analyse est déjà en cours, réessayez dans un instant.")

        try:
            messages = [
                {"role": "system", "content": system_prompt},
                {"role": "user", "content": question},
            ]

            content = _call_chat(messages, cfg)
            try:
                return _extract_sql_payload(content)
            except ValueError:
                logger.warning("Réponse Ollama non-JSON, tentative de correction (retry unique).")

            # Retry unique avec message correctif (format aligné sur le mode CoT/direct).
            _fmt = ('{"raisonnement": "...", "sql": "...", "explication": "..."}'
                    if cfg.get("cot") else '{"sql": "...", "explication": "..."}')
            messages.append({"role": "assistant", "content": content})
            messages.append({
                "role": "user",
                "content": f"Réponds UNIQUEMENT le JSON demandé : {_fmt} "
                           "sans texte autour, sans markdown.",
            })
            content_retry = _call_chat(messages, cfg)
            try:
                return _extract_sql_payload(content_retry)
            except ValueError:
                raise OllamaError(
                    "Le modèle n'a pas renvoyé un JSON exploitable. Reformulez votre question."
                )
        finally:
            _generation_lock.release()
    finally:
        _user_exit()


def repair_sql(question: str, system_prompt: str, bad_sql: str, erreur: str) -> dict:
    """
    Tente UNE correction d'une requête SQL qui a échoué à l'exécution (colonne ou
    table inexistante, erreur de syntaxe). On renvoie au modèle sa requête fautive
    et le message d'erreur PostgreSQL, en lui demandant un JSON corrigé.

    Retour : {"sql": "...", "explication": "..."}.
    Exceptions : mêmes que generate_sql (Busy / Unavailable / Error).
    """
    cfg = _config()
    _user_enter()
    try:
        if not _generation_lock.acquire(blocking=False):
            raise OllamaBusyError("Une analyse est déjà en cours, réessayez dans un instant.")
        try:
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
                return _extract_sql_payload(content)
            except ValueError:
                raise OllamaError(
                    "Le modèle n'a pas renvoyé un JSON exploitable lors de la correction."
                )
        finally:
            _generation_lock.release()
    finally:
        _user_exit()


def check_health() -> dict:
    """
    Vérifie qu'Ollama est joignable et que le modèle configuré est présent.

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
    try:
        resp = requests.get(f"{cfg['url']}/api/tags", timeout=5)
        if resp.status_code != 200:
            result["error"] = f"HTTP {resp.status_code}"
            return result
        tags = resp.json().get("models", [])
        names = [m.get("name", "") for m in tags]
        result["available"] = True
        result["models"] = names
        # Le tag peut être 'qwen2.5-coder:7b' ; on tolère l'absence de suffixe ':latest'.
        result["model_present"] = any(
            n == cfg["model"] or n.split(":")[0] == cfg["model"].split(":")[0]
            for n in names
        )
    except requests.exceptions.RequestException as e:
        result["error"] = str(e)
    return result


# --------------------------------------------------------------------------- #
# Préchauffage périodique (keep-warm)
#
# Toutes les N secondes, on envoie au modèle une mini-génération (num_predict=1)
# précédée du *system prompt* réel. But : garder le préfixe (prompt système) en
# cache KV d'Ollama pour que les vraies questions sautent l'évaluation coûteuse
# du prompt (~plusieurs minutes à froid sur CPU). keep_alive=24h évite que le
# modèle soit déchargé de la RAM.
#
# Priorité utilisateur : le préchauffage saute son tour si une requête /ask est
# active, et toute requête /ask en cours annule un préchauffage en vol
# (cf. _user_enter / _abort_inflight_warmup).
#
# Singleton inter-workers : avec gunicorn -w N, un seul worker doit lancer la
# boucle. On s'appuie sur un bind de socket local : le 1er worker qui réussit le
# bind devient le « warmer » ; les autres abandonnent (et libèrent le port à leur
# mort, ce qui évite les verrous périmés).
# --------------------------------------------------------------------------- #
_keepwarm_thread = None
_keepwarm_socket = None
_keepwarm_stop = threading.Event()
_keepwarm_prompt_provider = None


def _warmup_once(cfg: dict, system_prompt: str):
    """Une passe de préchauffage, interruptible si un utilisateur arrive."""
    global _warmup_inflight_resp
    payload = {
        "model": cfg["model"],
        "messages": [
            {"role": "system", "content": system_prompt},
            {"role": "user", "content": "ping"},
        ],
        "stream": True,
        "format": "json",
        "keep_alive": "24h",
        "options": {"temperature": 0, "num_ctx": 4096, "num_predict": 1},
    }
    resp = None
    try:
        resp = requests.post(
            f"{cfg['url']}/api/chat", json=payload, stream=True, timeout=cfg["timeout"]
        )
        with _warmup_inflight_lock:
            _warmup_inflight_resp = resp
        # Un utilisateur est peut-être arrivé entre le check et l'envoi : on sort.
        if _user_busy():
            return
        # Consomme le flux ; s'arrête dès qu'un utilisateur devient actif.
        for _ in resp.iter_lines():
            if _user_busy():
                break
    except Exception:
        # Préchauffage best-effort : un échec (Ollama down, connexion fermée par
        # l'annulation utilisateur, timeout...) ne doit jamais remonter.
        pass
    finally:
        with _warmup_inflight_lock:
            _warmup_inflight_resp = None
        if resp is not None:
            try:
                resp.close()
            except Exception:
                pass


def _provider_is_ollama() -> bool:
    """True si le fournisseur actif est Ollama (lecture dynamique : la bascule
    AI_PROVIDER est prise en compte à chaud, sans redémarrage). Import local pour
    éviter un cycle d'import au chargement du module."""
    try:
        from services.config_service import get_config
        return (get_config("AI_PROVIDER", "ollama") or "ollama").strip().lower() != "openai"
    except Exception:
        return True  # en cas de doute, on garde le comportement local historique


def _keepwarm_loop(interval: int):
    # Première passe rapprochée pour chauffer dès le démarrage (sans bloquer).
    if not _keepwarm_stop.wait(5):
        while True:
            # En mode externe (AI_PROVIDER=openai), aucun cache KV CPU à entretenir :
            # le préchauffage est inutile, on saute la passe.
            if not _user_busy() and _provider_is_ollama():
                try:
                    cfg = _config()
                    sp = _keepwarm_prompt_provider() if _keepwarm_prompt_provider else None
                    if sp:
                        _warmup_once(cfg, sp)
                except Exception as e:
                    logger.debug(f"keep-warm: passe ignorée ({e})")
            if _keepwarm_stop.wait(interval):
                break


def start_keepwarm(prompt_provider, interval: int = None) -> bool:
    """
    Démarre la boucle de préchauffage (idempotent, un seul warmer par hôte).

    prompt_provider : callable renvoyant le system prompt (ex. get_system_prompt).
    Retourne True si CE process est devenu le warmer, False sinon.
    """
    global _keepwarm_thread, _keepwarm_socket, _keepwarm_prompt_provider

    if os.getenv("AI_KEEPWARM_ENABLED", "true").lower() != "true":
        logger.info("Keep-warm Ollama désactivé (AI_KEEPWARM_ENABLED=false).")
        return False
    if _keepwarm_thread is not None:
        return False

    # Verrou singleton inter-workers via bind d'un port localhost.
    lock_port = int(os.getenv("AI_KEEPWARM_LOCK_PORT", "5051"))
    sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    try:
        sock.bind(("127.0.0.1", lock_port))
    except OSError:
        sock.close()
        logger.info("Keep-warm Ollama : déjà actif dans un autre worker, on n'en relance pas.")
        return False

    _keepwarm_socket = sock  # conserver la référence pour garder le bind actif
    _keepwarm_prompt_provider = prompt_provider
    iv = int(interval or os.getenv("AI_KEEPWARM_SECONDS", "60"))
    _keepwarm_stop.clear()
    _keepwarm_thread = threading.Thread(
        target=_keepwarm_loop, args=(iv,), daemon=True, name="ollama-keepwarm"
    )
    _keepwarm_thread.start()
    logger.info(f"🔥 Keep-warm Ollama démarré (intervalle {iv}s).")
    return True


def stop_keepwarm():
    """Arrête proprement la boucle de préchauffage (tests / arrêt applicatif)."""
    global _keepwarm_thread, _keepwarm_socket
    _keepwarm_stop.set()
    if _keepwarm_socket is not None:
        try:
            _keepwarm_socket.close()
        except Exception:
            pass
        _keepwarm_socket = None
    _keepwarm_thread = None
