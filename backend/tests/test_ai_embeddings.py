# -*- coding: utf-8 -*-
"""Tests unitaires du service d'embeddings (ai_embeddings)."""
from unittest.mock import patch, MagicMock

import pytest

from services import ai_embeddings
from services.ai_embeddings import embed, to_pgvector, EMBED_DIM


def _fake_response(vector, status=200):
    resp = MagicMock()
    resp.status_code = status
    resp.json.return_value = {"embedding": vector}
    resp.text = "ok"
    return resp


@pytest.fixture(autouse=True)
def _clear_cache():
    """Vide le cache LRU entre les tests pour éviter les interférences."""
    ai_embeddings._cache.clear()
    yield
    ai_embeddings._cache.clear()


def test_embed_retourne_vecteur(monkeypatch):
    monkeypatch.setenv("AI_EMBED_ENABLED", "true")
    vecteur = [0.1] * EMBED_DIM
    with patch.object(ai_embeddings.requests, "post", return_value=_fake_response(vecteur)):
        out = embed("combien de fournisseurs")
    assert out == vecteur


def test_embed_desactive_retourne_none(monkeypatch):
    monkeypatch.setenv("AI_EMBED_ENABLED", "false")
    with patch.object(ai_embeddings.requests, "post") as p:
        out = embed("question")
    assert out is None
    p.assert_not_called()  # aucun appel réseau si désactivé


def test_embed_dimension_invalide_retourne_none(monkeypatch):
    monkeypatch.setenv("AI_EMBED_ENABLED", "true")
    with patch.object(ai_embeddings.requests, "post", return_value=_fake_response([0.1, 0.2])):
        out = embed("question")
    assert out is None  # mauvaise dimension => None (pas d'index corrompu)


def test_embed_http_erreur_retourne_none(monkeypatch):
    monkeypatch.setenv("AI_EMBED_ENABLED", "true")
    with patch.object(ai_embeddings.requests, "post", return_value=_fake_response([], status=500)):
        out = embed("question")
    assert out is None


def test_embed_utilise_le_cache(monkeypatch):
    monkeypatch.setenv("AI_EMBED_ENABLED", "true")
    vecteur = [0.2] * EMBED_DIM
    with patch.object(ai_embeddings.requests, "post", return_value=_fake_response(vecteur)) as p:
        embed("même question")
        embed("même question")
    assert p.call_count == 1  # 2e appel servi par le cache LRU


def test_to_pgvector_format():
    assert to_pgvector([1, 2, 3]) == "[1.0,2.0,3.0]"


def test_to_pgvector_none_leve():
    with pytest.raises(ValueError):
        to_pgvector(None)
