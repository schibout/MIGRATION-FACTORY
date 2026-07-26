"""Tests de l'extraction des tables d'un SQL fautif pour l'auto-correction."""
from unittest.mock import patch

from services import ai_schema_retriever
from services.ai_schema_retriever import _tables_in_sql


def test_extrait_tables_qualifiees_dedupliquees():
    sql = ("SELECT a.lifnr FROM raw_data.lfa1 a "
           "JOIN raw_data.lfb1 b ON b.lifnr = a.lifnr "
           "JOIN raw_data.lfa1 c ON c.lifnr = a.lifnr")
    assert _tables_in_sql(sql) == ["raw_data.lfa1", "raw_data.lfb1"]


def test_extrait_clean_data_et_public():
    sql = "SELECT * FROM clean_data.part_catalog p JOIN public.sap_table_fields f ON true"
    assert _tables_in_sql(sql) == ["clean_data.part_catalog", "public.sap_table_fields"]


def test_sql_sans_table_renvoie_vide():
    assert _tables_in_sql("SELECT 1") == []


def test_schema_for_sql_delegue_a_build_schema_block():
    with patch.object(ai_schema_retriever, "build_schema_block",
                      return_value="raw_data.lfa1 : lifnr, name1") as bsb:
        bloc = ai_schema_retriever.schema_for_sql("SELECT nom FROM raw_data.lfa1", conn="fake")
    assert "lfa1" in bloc
    bsb.assert_called_once_with("", "fake", tables=["raw_data.lfa1"])
