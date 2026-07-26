"""Tests du filet de sécurité : retrait des filtres techniques SAP du SQL généré."""
from services.sql_filters import strip_technical_filters


def test_retire_mandt_en_tete_de_where():
    sql = "SELECT lifnr FROM raw_data.lfa1 WHERE mandt = '700' AND land1 = 'FR'"
    assert strip_technical_filters(sql) == "SELECT lifnr FROM raw_data.lfa1 WHERE land1 = 'FR'"


def test_retire_loevm_en_fin_de_where():
    sql = "SELECT lifnr FROM raw_data.lfa1 WHERE land1 = 'FR' AND loevm = ''"
    assert strip_technical_filters(sql) == "SELECT lifnr FROM raw_data.lfa1 WHERE land1 = 'FR'"


def test_retire_where_entier_si_seul_filtre_technique():
    sql = "SELECT lifnr FROM raw_data.lfa1 WHERE mandt = '700' ORDER BY lifnr LIMIT 10"
    assert strip_technical_filters(sql) == "SELECT lifnr FROM raw_data.lfa1 ORDER BY lifnr LIMIT 10"


def test_retire_where_entier_en_fin_de_requete():
    sql = "SELECT count(*) FROM raw_data.mara WHERE lvorm = ''"
    assert strip_technical_filters(sql) == "SELECT count(*) FROM raw_data.mara"


def test_conserve_sql_sans_filtre_technique():
    sql = "SELECT matnr, maktx FROM raw_data.makt WHERE spras = 'F'"
    assert strip_technical_filters(sql) == sql


def test_enchaine_mandt_et_loevm():
    sql = ("SELECT lifnr FROM raw_data.lfa1 "
           "WHERE mandt = '700' AND loevm = '' AND land1 = 'FR'")
    assert strip_technical_filters(sql) == "SELECT lifnr FROM raw_data.lfa1 WHERE land1 = 'FR'"


def test_retire_forme_is_null():
    sql = "SELECT lifnr FROM raw_data.lfa1 WHERE loevm IS NULL AND land1 = 'FR'"
    assert strip_technical_filters(sql) == "SELECT lifnr FROM raw_data.lfa1 WHERE land1 = 'FR'"


def test_retire_forme_is_not_null_seule():
    sql = "SELECT count(*) FROM raw_data.mara WHERE lvorm IS NOT NULL"
    assert strip_technical_filters(sql) == "SELECT count(*) FROM raw_data.mara"


def test_idempotent():
    sql = "SELECT lifnr FROM raw_data.lfa1 WHERE mandt = '700' AND land1 = 'FR'"
    une_passe = strip_technical_filters(sql)
    assert strip_technical_filters(une_passe) == une_passe
