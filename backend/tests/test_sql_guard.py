"""Tests unitaires du garde SQL de l'Assistant IA."""
import re
import pytest

from services.sql_guard import validate_and_wrap, SqlGuardError


def _norm(s: str) -> str:
    """Normalise les espaces pour des assertions robustes."""
    return re.sub(r"\s+", " ", s).strip().lower()


# --------------------------------------------------------------------------- #
# Requêtes valides
# --------------------------------------------------------------------------- #
def test_select_simple_valide():
    out = validate_and_wrap("SELECT lifnr, name1 FROM raw_data.lfa1 WHERE mandt='700'", 500)
    assert _norm(out).startswith("select * from (")
    assert "limit 500" in _norm(out)


def test_with_cte_valide():
    sql = "WITH t AS (SELECT land1, count(*) c FROM raw_data.lfa1 GROUP BY land1) SELECT * FROM t"
    out = validate_and_wrap(sql, 500)
    assert "limit 500" in _norm(out)


def test_order_by_et_limit_existant_preserves():
    # Le wrapping ne doit pas casser un ORDER BY + LIMIT déjà présents.
    sql = "SELECT name1 FROM raw_data.lfa1 ORDER BY name1 LIMIT 10"
    out = validate_and_wrap(sql, 500)
    n = _norm(out)
    assert "order by name1 limit 10" in n
    assert n.endswith("as ai_sub limit 500")


def test_mot_interdit_dans_litteral_non_rejete():
    # "UPDATE" dans une chaîne ne doit PAS être rejeté.
    sql = "SELECT name1 FROM raw_data.lfa1 WHERE name1 = 'SOCIETE UPDATE SARL'"
    out = validate_and_wrap(sql, 500)
    assert "limit 500" in _norm(out)


def test_borne_personnalisee():
    out = validate_and_wrap("SELECT 1", 50000)
    assert _norm(out).endswith("limit 50000")


# --------------------------------------------------------------------------- #
# Requêtes rejetées
# --------------------------------------------------------------------------- #
@pytest.mark.parametrize("sql", [
    "UPDATE raw_data.lfa1 SET name1='x'",
    "DELETE FROM raw_data.lfa1",
    "DROP TABLE raw_data.lfa1",
    "INSERT INTO raw_data.lfa1 (lifnr) VALUES ('1')",
    "TRUNCATE raw_data.lfa1",
    "ALTER TABLE raw_data.lfa1 ADD COLUMN x int",
    "GRANT SELECT ON raw_data.lfa1 TO public",
])
def test_ecriture_rejetee(sql):
    with pytest.raises(SqlGuardError):
        validate_and_wrap(sql, 500)


def test_multi_statements_rejete():
    with pytest.raises(SqlGuardError):
        validate_and_wrap("SELECT 1; DROP TABLE raw_data.lfa1", 500)


def test_select_into_rejete():
    with pytest.raises(SqlGuardError):
        validate_and_wrap("SELECT lifnr INTO copie FROM raw_data.lfa1", 500)


def test_pg_sleep_rejete():
    with pytest.raises(SqlGuardError):
        validate_and_wrap("SELECT pg_sleep(10)", 500)


def test_acces_information_schema_rejete():
    with pytest.raises(SqlGuardError):
        validate_and_wrap("SELECT table_name FROM information_schema.tables", 500)


def test_acces_public_rejete():
    with pytest.raises(SqlGuardError):
        validate_and_wrap("SELECT * FROM public.users", 500)


def test_requete_vide_rejetee():
    with pytest.raises(SqlGuardError):
        validate_and_wrap("   ", 500)
