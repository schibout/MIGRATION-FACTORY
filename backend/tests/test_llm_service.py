"""Tests de la façade d'aiguillage llm_service (local Ollama / externe OpenAI)."""
from unittest.mock import patch

from services import llm_service


def test_active_provider_defaut_ollama():
    with patch.object(llm_service, "get_config", return_value="ollama"):
        assert llm_service.active_provider() == "ollama"


def test_active_provider_openai():
    with patch.object(llm_service, "get_config", return_value="openai"):
        assert llm_service.active_provider() == "openai"


def test_active_provider_valeur_inconnue_retombe_sur_ollama():
    with patch.object(llm_service, "get_config", return_value="autre"):
        assert llm_service.active_provider() == "ollama"


def test_generate_sql_route_vers_ollama():
    with patch.object(llm_service, "active_provider", return_value="ollama"), \
         patch.object(llm_service.ollama_service, "generate_sql", return_value={"sql": "L"}) as loc, \
         patch.object(llm_service.external_llm_service, "generate_sql", return_value={"sql": "X"}) as ext:
        out = llm_service.generate_sql("q", "sys")
    assert out["sql"] == "L"
    loc.assert_called_once()
    ext.assert_not_called()


def test_generate_sql_route_vers_externe():
    with patch.object(llm_service, "active_provider", return_value="openai"), \
         patch.object(llm_service.ollama_service, "generate_sql", return_value={"sql": "L"}) as loc, \
         patch.object(llm_service.external_llm_service, "generate_sql", return_value={"sql": "X"}) as ext:
        out = llm_service.generate_sql("q", "sys")
    assert out["sql"] == "X"
    ext.assert_called_once()
    loc.assert_not_called()


def test_check_health_ajoute_provider():
    with patch.object(llm_service, "active_provider", return_value="openai"), \
         patch.object(llm_service.external_llm_service, "check_health",
                      return_value={"available": True, "model": "gpt-4o-mini"}):
        out = llm_service.check_health()
    assert out["provider"] == "openai"
    assert out["available"] is True


def test_repair_sql_route_vers_externe():
    with patch.object(llm_service, "active_provider", return_value="openai"), \
         patch.object(llm_service.external_llm_service, "repair_sql", return_value={"sql": "FIX"}) as ext:
        out = llm_service.repair_sql("q", "sys", "bad", "err")
    assert out["sql"] == "FIX"
    ext.assert_called_once()
