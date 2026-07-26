"""Tests des budgets RAG adaptatifs (profil compact Ollama / large externe)."""
from unittest.mock import patch

from services import ai_rag_budget


def _fake_config(valeurs):
    """get_config(key, default) simulé sur un dict."""
    return lambda key, default=None: valeurs.get(key, default)


def test_profil_compact_par_defaut_avec_ollama():
    with patch.object(ai_rag_budget, "get_config", _fake_config({"AI_PROVIDER": "ollama"})), \
         patch.object(ai_rag_budget, "get_config_int", lambda k, d=0: d):
        b = ai_rag_budget.get_budget()
    assert b["profil"] == "compact"
    assert b["max_tables"] == 7
    assert b["max_cols"] == 18
    assert b["nb_exemples"] == 3


def test_profil_large_avec_fournisseur_externe():
    with patch.object(ai_rag_budget, "get_config", _fake_config({"AI_PROVIDER": "openai"})), \
         patch.object(ai_rag_budget, "get_config_int", lambda k, d=0: d):
        b = ai_rag_budget.get_budget()
    assert b["profil"] == "large"
    assert b["max_tables"] == 14
    assert b["max_cols"] == 40
    assert b["nb_exemples"] == 6
    assert b["max_packs"] == 3
    assert b["max_edges"] == 20


def test_ai_rag_profile_force_le_profil():
    valeurs = {"AI_PROVIDER": "openai", "AI_RAG_PROFILE": "compact"}
    with patch.object(ai_rag_budget, "get_config", _fake_config(valeurs)), \
         patch.object(ai_rag_budget, "get_config_int", lambda k, d=0: d):
        b = ai_rag_budget.get_budget()
    assert b["profil"] == "compact"
    assert b["max_tables"] == 7


def test_surcharge_fine_par_cle():
    def fake_int(key, default=0):
        return 10 if key == "AI_RAG_MAX_TABLES" else default
    with patch.object(ai_rag_budget, "get_config", _fake_config({"AI_PROVIDER": "ollama"})), \
         patch.object(ai_rag_budget, "get_config_int", fake_int):
        b = ai_rag_budget.get_budget()
    assert b["max_tables"] == 10          # surchargé
    assert b["max_cols"] == 18            # valeur du profil
