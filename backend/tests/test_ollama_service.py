"""Tests unitaires du service Ollama (parsing, retry, sémaphore)."""
from unittest.mock import patch, MagicMock

import pytest

from services import ollama_service
from services.ollama_service import (
    generate_sql,
    OllamaError,
    OllamaBusyError,
    _strip_json_fences,
    _extract_sql_payload,
)


def _fake_response(content: str, status=200):
    resp = MagicMock()
    resp.status_code = status
    resp.json.return_value = {"message": {"content": content}}
    resp.text = content
    return resp


# --------------------------------------------------------------------------- #
# Parsing
# --------------------------------------------------------------------------- #
def test_strip_fences():
    raw = '```json\n{"sql": "SELECT 1", "explication": "ok"}\n```'
    assert _strip_json_fences(raw).startswith("{")
    assert "```" not in _strip_json_fences(raw)


def test_extract_payload_sans_fence():
    out = _extract_sql_payload('{"sql": "SELECT 1", "explication": "ok"}')
    assert out["sql"] == "SELECT 1"
    assert out["explication"] == "ok"


def test_extract_payload_avec_fence():
    out = _extract_sql_payload('```json\n{"sql": "SELECT 2"}\n```')
    assert out["sql"] == "SELECT 2"


def test_extract_payload_invalide_leve_valueerror():
    with pytest.raises(ValueError):
        _extract_sql_payload("ceci n'est pas du json")


# --------------------------------------------------------------------------- #
# generate_sql : succès, retry, échec
# --------------------------------------------------------------------------- #
def test_generate_sql_succes_direct():
    with patch.object(ollama_service, "_call_chat", return_value='{"sql":"SELECT 1","explication":"e"}'):
        out = generate_sql("compte les fournisseurs", "system")
    assert out["sql"] == "SELECT 1"


def test_generate_sql_retry_puis_succes():
    # 1er appel : texte invalide ; 2e appel (retry) : JSON valide.
    calls = ["pas du json", '{"sql":"SELECT 2","explication":"e"}']
    with patch.object(ollama_service, "_call_chat", side_effect=calls):
        out = generate_sql("q", "system")
    assert out["sql"] == "SELECT 2"


def test_generate_sql_double_echec_leve_ollamaerror():
    with patch.object(ollama_service, "_call_chat", side_effect=["nope", "encore nope"]):
        with pytest.raises(OllamaError):
            generate_sql("q", "system")


def test_semaphore_occupe_leve_busy():
    # Simule un verrou déjà pris : l'acquisition non bloquante doit échouer.
    ollama_service._generation_lock.acquire(blocking=False)
    try:
        with pytest.raises(OllamaBusyError):
            generate_sql("q", "system")
    finally:
        ollama_service._generation_lock.release()


# --------------------------------------------------------------------------- #
# repair_sql : auto-correction d'une requête fautive
# --------------------------------------------------------------------------- #
def test_repair_sql_retourne_sql_corrige():
    corrige = '{"sql":"SELECT name1 FROM raw_data.lfa1","explication":"corrigé"}'
    with patch.object(ollama_service, "_call_chat", return_value=corrige):
        out = ollama_service.repair_sql(
            "liste des fournisseurs", "system",
            "SELECT nom FROM raw_data.lfa1", "colonne nom inexistante (42703)",
        )
    assert out["sql"] == "SELECT name1 FROM raw_data.lfa1"


def test_repair_sql_json_invalide_leve_ollamaerror():
    with patch.object(ollama_service, "_call_chat", return_value="pas du json"):
        with pytest.raises(OllamaError):
            ollama_service.repair_sql("q", "system", "SELECT x", "boom")


def test_repair_sql_semaphore_occupe_leve_busy():
    ollama_service._generation_lock.acquire(blocking=False)
    try:
        with pytest.raises(OllamaBusyError):
            ollama_service.repair_sql("q", "system", "SELECT x", "boom")
    finally:
        ollama_service._generation_lock.release()


# --------------------------------------------------------------------------- #
# Préchauffage (keep-warm) — coordination avec les requêtes utilisateur
# --------------------------------------------------------------------------- #
def test_compteur_utilisateur():
    assert ollama_service._user_busy() is False
    ollama_service._user_enter()
    assert ollama_service._user_busy() is True
    ollama_service._user_enter()           # deux requêtes concurrentes
    ollama_service._user_exit()
    assert ollama_service._user_busy() is True   # encore une active
    ollama_service._user_exit()
    assert ollama_service._user_busy() is False


def test_user_enter_annule_prechauffage_en_vol():
    # Une "réponse" factice doit être fermée quand un utilisateur arrive.
    closed = {"v": False}

    class FakeResp:
        def close(self):
            closed["v"] = True

    with ollama_service._warmup_inflight_lock:
        ollama_service._warmup_inflight_resp = FakeResp()
    try:
        ollama_service._user_enter()       # doit déclencher l'abandon
        assert closed["v"] is True
    finally:
        ollama_service._user_exit()
        with ollama_service._warmup_inflight_lock:
            ollama_service._warmup_inflight_resp = None


def test_generate_sql_signale_activite_utilisateur():
    # Pendant la génération, le compteur utilisateur est > 0 ; nul après.
    def fake_call(messages, cfg):
        assert ollama_service._user_busy() is True
        return '{"sql":"SELECT 1","explication":"e"}'

    with patch.object(ollama_service, "_call_chat", side_effect=fake_call):
        generate_sql("q", "system")
    assert ollama_service._user_busy() is False


def test_start_keepwarm_desactive(monkeypatch):
    monkeypatch.setenv("AI_KEEPWARM_ENABLED", "false")
    assert ollama_service.start_keepwarm(lambda: "sys") is False
