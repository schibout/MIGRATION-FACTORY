# -*- coding: utf-8 -*-
"""Tests unitaires du cache sémantique (ai_semantic_cache)."""
from unittest.mock import patch, MagicMock

from services import ai_semantic_cache
from services.ai_embeddings import EMBED_DIM


def _mock_db(fetchone_row):
    """Construit un get_db_connection mocké renvoyant `fetchone_row`."""
    cur = MagicMock()
    cur.fetchone.return_value = fetchone_row
    cur_cm = MagicMock()
    cur_cm.__enter__.return_value = cur
    cur_cm.__exit__.return_value = False
    conn = MagicMock()
    conn.cursor.return_value = cur_cm
    conn_cm = MagicMock()
    conn_cm.__enter__.return_value = conn
    conn_cm.__exit__.return_value = False
    return MagicMock(return_value=conn_cm), cur


def test_lookup_desactive_retourne_none(monkeypatch):
    monkeypatch.setenv("AI_CACHE_ENABLED", "false")
    assert ai_semantic_cache.lookup("question") is None


def test_lookup_embeddings_indisponibles_retourne_none(monkeypatch):
    monkeypatch.setenv("AI_CACHE_ENABLED", "true")
    with patch.object(ai_semantic_cache, "embed", return_value=None):
        assert ai_semantic_cache.lookup("question") is None


def test_lookup_hit_au_dessus_du_seuil(monkeypatch):
    monkeypatch.setenv("AI_CACHE_ENABLED", "true")
    monkeypatch.setenv("AI_CACHE_THRESHOLD", "0.94")
    vecteur = [0.1] * EMBED_DIM
    # row = (id, question, sql, similarity)
    db, _ = _mock_db((42, "compte les fournisseurs", "SELECT 1", 0.97))
    with patch.object(ai_semantic_cache, "embed", return_value=vecteur), \
         patch.object(ai_semantic_cache, "get_db_connection", db):
        hit = ai_semantic_cache.lookup("nombre de fournisseurs")
    assert hit is not None
    assert hit["id_log"] == 42
    assert hit["sql"] == "SELECT 1"
    assert hit["similarity"] == 0.97
    assert hit["vector"] == vecteur


def test_lookup_miss_sous_le_seuil(monkeypatch):
    monkeypatch.setenv("AI_CACHE_ENABLED", "true")
    monkeypatch.setenv("AI_CACHE_THRESHOLD", "0.94")
    vecteur = [0.1] * EMBED_DIM
    db, _ = _mock_db((7, "autre question", "SELECT 2", 0.80))
    with patch.object(ai_semantic_cache, "embed", return_value=vecteur), \
         patch.object(ai_semantic_cache, "get_db_connection", db):
        assert ai_semantic_cache.lookup("question éloignée") is None


def test_lookup_aucune_ligne_retourne_none(monkeypatch):
    monkeypatch.setenv("AI_CACHE_ENABLED", "true")
    vecteur = [0.1] * EMBED_DIM
    db, _ = _mock_db(None)
    with patch.object(ai_semantic_cache, "embed", return_value=vecteur), \
         patch.object(ai_semantic_cache, "get_db_connection", db):
        assert ai_semantic_cache.lookup("question") is None


def test_store_ecrit_embedding(monkeypatch):
    monkeypatch.setenv("AI_CACHE_ENABLED", "true")
    vecteur = [0.3] * EMBED_DIM
    db, cur = _mock_db(None)
    with patch.object(ai_semantic_cache, "get_db_connection", db):
        ai_semantic_cache.store(99, "ma question", vector=vecteur)
    # UPDATE exécuté avec le vecteur formaté et l'id
    assert cur.execute.called
    args = cur.execute.call_args[0]
    assert "UPDATE public.ai_query_log" in args[0]
    assert args[1][1] == 99


def test_store_sans_id_ne_fait_rien(monkeypatch):
    monkeypatch.setenv("AI_CACHE_ENABLED", "true")
    db, cur = _mock_db(None)
    with patch.object(ai_semantic_cache, "get_db_connection", db):
        ai_semantic_cache.store(None, "ma question", vector=[0.3] * EMBED_DIM)
    db.assert_not_called()
