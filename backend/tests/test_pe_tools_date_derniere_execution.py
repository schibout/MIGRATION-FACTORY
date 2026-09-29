"""
pe_tools.date_derniere_execution : plan d'entretien, a defaut poste d'entretien (migration 084).

Le classeur « Date 7.M.xlsx » melange des plans (onglet 7.M) et des postes
d'entretien (onglet NRJ et MSGX) sous le meme intitule ; la colonne id_type
(PLAN | POSTE, PLAN par defaut) les distingue. Verifie sur la VRAIE base, dans
une transaction toujours annulee :
  * normalisation d'id_type (vide -> PLAN, « Poste d'entretien » -> POSTE),
    rejet d'une valeur inconnue ;
  * une ligne POSTE date la gamme par son poste d'entretien (triggers) ;
  * la date du plan prime sur celle du poste.
Saute si la base est injoignable ou la migration 084 pas jouee.
"""
import os
import sys

import psycopg2
import pytest

BACKEND = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
if BACKEND not in sys.path:
    sys.path.insert(0, BACKEND)

# Identifiants de test improbables (ni plan ni poste SAP).
PLAN_TEST, POSTE_TEST = '99999001', '99999002'


@pytest.fixture
def cur():
    try:
        from config.database import get_db_params
        conn = psycopg2.connect(**get_db_params())
    except Exception as exc:  # pragma: no cover - selon l'environnement
        pytest.skip(f'base injoignable : {exc}')
    cur = conn.cursor()
    cur.execute("""SELECT 1 FROM information_schema.columns WHERE table_schema = 'raw_data'
                   AND table_name = 'plan_entretien_derniere_exec' AND column_name = 'id_type'""")
    if not cur.fetchone():
        conn.close()
        pytest.skip('migration 084 non jouee')
    try:
        yield cur
    finally:
        conn.rollback()
        conn.close()


def _insere_date(cur, ident, date, id_type):
    cur.execute("""INSERT INTO raw_data.plan_entretien_derniere_exec (warpl, date_derniere_execution, id_type)
                   VALUES (%s, %s, %s) RETURNING id_type""", [ident, date, id_type])
    return cur.fetchone()[0]


def _gamme_de_test(cur):
    """Gamme existante detournee sur les identifiants de test (UPDATE annule au rollback)."""
    cur.execute("SELECT raw_id FROM raw_data.pe_tools ORDER BY raw_id LIMIT 1")
    raw_id = cur.fetchone()[0]
    cur.execute("UPDATE raw_data.pe_tools SET plan_entretien = %s, poste_entretien = %s WHERE raw_id = %s",
                [PLAN_TEST, POSTE_TEST, raw_id])
    return raw_id


def _date_gamme(cur, raw_id):
    cur.execute("SELECT date_derniere_execution::text FROM raw_data.pe_tools WHERE raw_id = %s", [raw_id])
    return cur.fetchone()[0]


def test_id_type_normalise(cur):
    assert _insere_date(cur, '99999010', '2026-01-01 00:00:00', None) == 'PLAN'
    assert _insere_date(cur, '99999011', '2026-01-01 00:00:00', '') == 'PLAN'
    assert _insere_date(cur, '99999012', '2026-01-01 00:00:00', "Plan d'entretien") == 'PLAN'
    assert _insere_date(cur, '99999013', '2026-01-01 00:00:00', " poste d'entretien ") == 'POSTE'


def test_id_type_inconnu_rejete(cur):
    cur.execute('SAVEPOINT s')
    with pytest.raises(psycopg2.Error):
        _insere_date(cur, '99999014', '2026-01-01 00:00:00', 'Equipement')
    cur.execute('ROLLBACK TO SAVEPOINT s')


def test_date_par_poste_puis_priorite_au_plan(cur):
    raw_id = _gamme_de_test(cur)
    assert _date_gamme(cur, raw_id) is None

    # Seul le poste d'entretien est connu : la gamme prend sa date (trigger cote fichier).
    _insere_date(cur, POSTE_TEST, '2026-05-10 00:00:00', "Poste d'entretien")
    assert _date_gamme(cur, raw_id) == '2026-05-10'

    # Un plan portant le MEME numero que le poste ne doit pas etre confondu avec lui...
    _insere_date(cur, POSTE_TEST, '2020-01-01 00:00:00', 'Plan')
    assert _date_gamme(cur, raw_id) == '2026-05-10'

    # ... mais la date du plan de la gamme prime, meme plus ancienne.
    _insere_date(cur, PLAN_TEST, '2025-03-02 00:00:00', 'Plan')
    assert _date_gamme(cur, raw_id) == '2025-03-02'

    # Le plan retire, la gamme revient a la date de son poste.
    cur.execute("DELETE FROM raw_data.plan_entretien_derniere_exec WHERE warpl = %s AND id_type = 'PLAN'", [PLAN_TEST])
    assert _date_gamme(cur, raw_id) == '2026-05-10'


def test_saisie_manuelle_prioritaire(cur):
    """085 : une saisie MANUEL prime sur le fichier, meme plus ancienne ; la retirer rend la date du fichier."""
    cur.execute("""SELECT 1 FROM information_schema.columns WHERE table_schema = 'raw_data'
                   AND table_name = 'plan_entretien_derniere_exec' AND column_name = 'source'""")
    if not cur.fetchone():
        pytest.skip('migration 085 non jouee')
    raw_id = _gamme_de_test(cur)
    _insere_date(cur, PLAN_TEST, '2026-06-01 00:00:00', 'Plan')
    assert _date_gamme(cur, raw_id) == '2026-06-01'

    cur.execute("""INSERT INTO raw_data.plan_entretien_derniere_exec (warpl, date_derniere_execution, id_type, source)
                   VALUES (%s, '2026-02-15 00:00:00', 'PLAN', 'MANUEL')""", [PLAN_TEST])
    assert _date_gamme(cur, raw_id) == '2026-02-15'

    # Une seule saisie manuelle par identifiant (index unique partiel, cible de l'upsert de l'API).
    cur.execute('SAVEPOINT s')
    with pytest.raises(psycopg2.errors.UniqueViolation):
        cur.execute("""INSERT INTO raw_data.plan_entretien_derniere_exec (warpl, date_derniere_execution, id_type, source)
                       VALUES (%s, '2026-03-01 00:00:00', 'PLAN', 'MANUEL')""", ['00' + PLAN_TEST])
    cur.execute('ROLLBACK TO SAVEPOINT s')

    cur.execute("DELETE FROM raw_data.plan_entretien_derniere_exec WHERE warpl = %s AND source = 'MANUEL'", [PLAN_TEST])
    assert _date_gamme(cur, raw_id) == '2026-06-01'
