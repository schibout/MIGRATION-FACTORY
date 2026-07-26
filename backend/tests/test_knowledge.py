# -*- coding: utf-8 -*-
"""
Tests des Knowledge Cards (dérivées des packs) et du Knowledge Graph.

Hors-ligne : on force le repli lexical en neutralisant l'accès base (get_db_connection
qui lève), de sorte que retrieve_relevant_knowledge n'utilise que le recouvrement de
tables / mots-clés.
"""
import pytest

from services import knowledge_service
from services import ai_knowledge_graph


def _no_db(*args, **kwargs):
    raise RuntimeError("DB indisponible (test offline)")


def test_cards_derivees_des_packs():
    cards = knowledge_service.iter_cards()
    assert cards, "aucune card dérivée des packs"
    ids = set()
    for c in cards:
        assert c["type"] in knowledge_service.TYPES
        assert c["domain"] and c["content"]
        assert isinstance(c["tables"], list)
        assert c["id"] not in ids, "id de card dupliqué"
        ids.add(c["id"])


def test_retrieve_lexical_par_table(monkeypatch):
    monkeypatch.setattr(knowledge_service, "get_db_connection", _no_db)
    cards = knowledge_service.retrieve_relevant_knowledge(
        "liste des fournisseurs actifs", ["raw_data.lfa1"]
    )
    assert cards, "aucune card retrouvée pour fournisseurs/lfa1"
    assert any(c["domain"] == "fournisseurs" for c in cards)


def test_build_block_offline(monkeypatch):
    monkeypatch.setattr(knowledge_service, "get_db_connection", _no_db)
    bloc = knowledge_service.build_knowledge_block(
        "stock par article", ["raw_data.mara", "raw_data.mard"]
    )
    assert bloc and bloc.startswith("- [")
    # Hors domaine + aucune table -> aucun bloc.
    assert knowledge_service.build_knowledge_block("bonjour comment ca va", []) == ""


def test_graph_bare():
    assert ai_knowledge_graph._bare("raw_data.ekpo") == "ekpo"
    assert ai_knowledge_graph._bare("EKKO") == "ekko"


def test_subgraph_moins_de_deux_tables():
    # Pas de jointure possible avec < 2 tables -> '' sans toucher la base.
    assert ai_knowledge_graph.get_relevant_subgraph("x", ["raw_data.lfa1"]) == ""


def test_cooccurrence_extraction_tables():
    from build_cooccurrence import _tables_de
    sql = ("SELECT a.lifnr FROM raw_data.lfa1 a "
           "JOIN raw_data.lfbk k ON k.lifnr=a.lifnr "
           "LEFT JOIN clean_data.ifs_fournisseurs f ON f.lifnr=a.lifnr")
    assert _tables_de(sql) == {"lfa1", "lfbk", "ifs_fournisseurs"}
    assert _tables_de("SELECT 1") == set()
