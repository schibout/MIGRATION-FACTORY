"""Tests unitaires du client modèle externe (OpenAI-compatible)."""
from unittest.mock import patch, MagicMock

import pytest

from services import external_llm_service
from services.external_llm_service import generate_sql, repair_sql
from services.ollama_service import OllamaError, OllamaUnavailableError


_CFG = {
    "base_url": "https://api.test/v1",
    "api_key": "sk-test",
    "model": "gpt-4o-mini",
    "timeout": 60,
    "max_tokens": 256,
    "cot": False,
}


def _openai_response(content: str, status=200):
    """Réponse façon /chat/completions OpenAI."""
    resp = MagicMock()
    resp.status_code = status
    resp.json.return_value = {"choices": [{"message": {"content": content}}]}
    resp.text = content
    return resp


# --------------------------------------------------------------------------- #
# generate_sql : succès, retry, échec
# --------------------------------------------------------------------------- #
def test_generate_sql_succes_direct():
    with patch.object(external_llm_service, "_config", return_value=_CFG), \
         patch.object(external_llm_service, "_call_chat",
                      return_value='{"sql":"SELECT 1","explication":"e"}'):
        out = generate_sql("compte les fournisseurs", "system")
    assert out["sql"] == "SELECT 1"
    assert out["explication"] == "e"


def test_generate_sql_retry_puis_succes():
    calls = ["pas du json", '{"sql":"SELECT 2","explication":"e"}']
    with patch.object(external_llm_service, "_config", return_value=_CFG), \
         patch.object(external_llm_service, "_call_chat", side_effect=calls):
        out = generate_sql("q", "system")
    assert out["sql"] == "SELECT 2"


# --------------------------------------------------------------------------- #
# Robustesse parsing : modèles "reasoning" (Kimi/NIM) qui enrobent le JSON de
# raisonnement (<think>…</think>) ou de prose, et sorties fenced/mixtes.
# Doivent réussir DÈS le 1er appel (sans retry).
# --------------------------------------------------------------------------- #
def test_generate_sql_contenu_avec_balises_think():
    contenu = '<think>L\'utilisateur veut compter les fournisseurs.</think>\n{"sql":"SELECT 1","explication":"ok"}'
    with patch.object(external_llm_service, "_config", return_value=_CFG), \
         patch.object(external_llm_service, "_call_chat", return_value=contenu) as cc:
        out = generate_sql("q", "system")
    assert out["sql"] == "SELECT 1"
    assert cc.call_count == 1  # pas de retry nécessaire


def test_generate_sql_contenu_avec_prose_autour():
    contenu = 'Voici la requête demandée :\n```json\n{"sql":"SELECT 2","explication":"e"}\n```\nVoilà.'
    with patch.object(external_llm_service, "_config", return_value=_CFG), \
         patch.object(external_llm_service, "_call_chat", return_value=contenu):
        out = generate_sql("q", "system")
    assert out["sql"] == "SELECT 2"


def test_generate_sql_braces_dans_le_raisonnement():
    # Le raisonnement contient lui-même des accolades : le scan équilibré doit
    # quand même isoler le bon objet JSON.
    contenu = '<think>on considère l\'ensemble {a, b} des tables</think>{"sql":"SELECT 3","explication":"e"}'
    with patch.object(external_llm_service, "_config", return_value=_CFG), \
         patch.object(external_llm_service, "_call_chat", return_value=contenu):
        out = generate_sql("q", "system")
    assert out["sql"] == "SELECT 3"


def test_extract_json_block_isole_objet():
    src = 'blabla {"sql":"SELECT 1","explication":"e"} fin'
    assert external_llm_service._extract_json_block(src) == '{"sql":"SELECT 1","explication":"e"}'


def test_generate_sql_double_echec_leve_llmerror():
    with patch.object(external_llm_service, "_config", return_value=_CFG), \
         patch.object(external_llm_service, "_call_chat", side_effect=["nope", "encore nope"]):
        with pytest.raises(OllamaError):
            generate_sql("q", "system")


def test_repair_sql_retourne_sql_corrige():
    corrige = '{"sql":"SELECT name1 FROM raw_data.lfa1","explication":"corrigé"}'
    with patch.object(external_llm_service, "_config", return_value=_CFG), \
         patch.object(external_llm_service, "_call_chat", return_value=corrige):
        out = repair_sql("liste des fournisseurs", "system",
                         "SELECT nom FROM raw_data.lfa1", "colonne nom inexistante (42703)")
    assert out["sql"] == "SELECT name1 FROM raw_data.lfa1"


# --------------------------------------------------------------------------- #
# _call_chat : mapping des erreurs HTTP -> exceptions
# --------------------------------------------------------------------------- #
def test_call_chat_401_leve_unavailable():
    with patch.object(external_llm_service.requests, "post",
                      return_value=_openai_response("unauthorized", status=401)):
        with pytest.raises(OllamaUnavailableError):
            external_llm_service._call_chat([{"role": "user", "content": "x"}], _CFG)


def test_call_chat_429_leve_unavailable():
    with patch.object(external_llm_service.requests, "post",
                      return_value=_openai_response("rate limited", status=429)):
        with pytest.raises(OllamaUnavailableError):
            external_llm_service._call_chat([{"role": "user", "content": "x"}], _CFG)


def test_call_chat_404_modele_introuvable():
    resp = _openai_response(
        '{"status":404,"detail":"Function \'x\': Not found for account"}', status=404)
    with patch.object(external_llm_service.requests, "post", return_value=resp):
        with pytest.raises(OllamaUnavailableError) as exc:
            external_llm_service._call_chat([{"role": "user", "content": "x"}], _CFG)
    assert "AI_EXTERNAL_MODEL" in str(exc.value)


def test_call_chat_sans_cle_leve_unavailable():
    cfg = dict(_CFG, api_key="")
    with pytest.raises(OllamaUnavailableError):
        external_llm_service._call_chat([{"role": "user", "content": "x"}], cfg)


def test_call_chat_reponse_malformee_leve_llmerror():
    bad = MagicMock()
    bad.status_code = 200
    bad.json.return_value = {"unexpected": True}
    bad.text = "{}"
    with patch.object(external_llm_service.requests, "post", return_value=bad):
        with pytest.raises(OllamaError):
            external_llm_service._call_chat([{"role": "user", "content": "x"}], _CFG)


# --------------------------------------------------------------------------- #
# check_health
# --------------------------------------------------------------------------- #
def test_check_health_modele_present():
    resp = MagicMock()
    resp.status_code = 200
    resp.json.return_value = {"data": [{"id": "gpt-4o-mini"}, {"id": "gpt-4o"}]}
    with patch.object(external_llm_service, "_config", return_value=_CFG), \
         patch.object(external_llm_service.requests, "get", return_value=resp):
        out = external_llm_service.check_health()
    assert out["available"] is True
    assert out["model_present"] is True


def test_check_health_sans_cle():
    cfg = dict(_CFG, api_key="")
    with patch.object(external_llm_service, "_config", return_value=cfg):
        out = external_llm_service.check_health()
    assert out["available"] is False
    assert out["error"]
