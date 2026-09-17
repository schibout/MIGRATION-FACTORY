"""
clean_data.classifier_ibau_article() : identification automatique des cas
d'IBAU (document « Migration des donnees », 15/09/2026, §3).

Regle, par article IBAU present dans la structure IH02 :
  - aucun enfant (pas de ligne de nomenclature sous lui)   -> ARTICLE         (rouge)
  - des enfants + une seule occurrence dans la structure   -> POSTE_TECHNIQUE (bleu)
  - des enfants + plusieurs occurrences                    -> CONSERVER       (jaune)
Occurrence = ligne de nomenclature qui reference l'IBAU + poste technique
dont il est le type de construction (raw_data.iflo.submt).

La fonction ecrit dans les DEUX tables : clean_data.maintenance_object (noeuds
ARTICLE, pour l'arbre) et clean_data.ibau_article (liste fixe, pour les
listes). Tests sur la vraie base, transaction jamais validee.
"""
import os
import sys

import psycopg2
import psycopg2.extras
import pytest

BACKEND = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
if BACKEND not in sys.path:
    sys.path.insert(0, BACKEND)

from tests.ibau_schema_helper import charger_migration_079  # noqa: E402

MO = 'clean_data.maintenance_object'


@pytest.fixture
def cur():
    try:
        from config.database import get_db_params
        conn = psycopg2.connect(**get_db_params())
    except Exception as exc:  # pragma: no cover
        pytest.skip(f'base injoignable : {exc}')
    try:
        cur = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
        charger_migration_079(cur)
        yield cur
    finally:
        conn.rollback()
        conn.close()


def _one(cur, sql, params=None):
    cur.execute(sql, params or [])
    return cur.fetchone()


def _ins_article(cur, key, mtart='IBAU'):
    return _one(cur, f"""
        INSERT INTO {MO} (object_type, sap_key, code, designation, type_code, source)
        VALUES ('ARTICLE', %s, %s, %s, %s, 'MANUAL') RETURNING id""",
        [key, key, 'test ' + key, mtart])['id']


def _ins_bom(cur, parent_id, article_id, key):
    _one(cur, f"""
        INSERT INTO {MO} (object_type, sap_key, parent_id, ref_object_id, code, source)
        VALUES ('BOM_ITEM', %s, %s, %s, 'x', 'MANUAL') RETURNING id""",
        [key, parent_id, article_id])


def _fl(cur, key):
    return _one(cur, f"SELECT id FROM {MO} WHERE object_type = 'FUNC_LOC' AND sap_key = %s", [key])['id']


@pytest.fixture
def jeu(cur):
    """Trois IBAU de test, un par cas, rattaches sous la racine T.

    ROUGE  : ZZI-ROUGE, aucun enfant, reference une fois
    BLEU   : ZZI-BLEU,  un enfant, reference une fois
    JAUNE  : ZZI-JAUNE, un enfant, reference deux fois (deux postes)
    + ZZI-HORS : dans la liste fixe mais absent de la structure -> NULL
    """
    racine = _fl(cur, 'T')
    autre = _one(cur, f"""SELECT id FROM {MO} WHERE object_type = 'FUNC_LOC' AND is_active
                          AND parent_id = %s ORDER BY sap_key LIMIT 1""", [racine])['id']
    composant = _ins_article(cur, 'ZZI-COMP', mtart='ERSA')
    ids = {}
    for key in ('ZZI-ROUGE', 'ZZI-BLEU', 'ZZI-JAUNE'):
        ids[key] = _ins_article(cur, key)
        cur.execute("""INSERT INTO clean_data.ibau_article (matnr, code, description, source)
                       VALUES (%s, %s, %s, 'MANUAL')""", [key, key, 'test'])
    cur.execute("""INSERT INTO clean_data.ibau_article (matnr, code, description, source)
                   VALUES ('ZZI-HORS', 'ZZI-HORS', 'test', 'MANUAL')""")

    _ins_bom(cur, racine, ids['ZZI-ROUGE'], 'ZZB-R1')
    _ins_bom(cur, racine, ids['ZZI-BLEU'], 'ZZB-B1')
    _ins_bom(cur, ids['ZZI-BLEU'], composant, 'ZZB-B2')      # enfant du bleu
    _ins_bom(cur, racine, ids['ZZI-JAUNE'], 'ZZB-J1')
    _ins_bom(cur, autre, ids['ZZI-JAUNE'], 'ZZB-J2')         # 2e occurrence
    _ins_bom(cur, ids['ZZI-JAUNE'], composant, 'ZZB-J3')     # enfant du jaune
    return ids


def _cas_mo(cur, key):
    return _one(cur, f"""SELECT cas_ibau, (attributes->>'ibau_nb_enfants')::int AS nb_enfants,
                                (attributes->>'ibau_nb_occurrences')::int AS nb_occurrences
                         FROM {MO} WHERE object_type = 'ARTICLE' AND sap_key = %s""", [key])


def _cas_liste(cur, key):
    return _one(cur, """SELECT cas_ibau, nb_enfants, nb_occurrences, cas_calcule_at
                        FROM clean_data.ibau_article WHERE matnr = %s""", [key])


def test_les_trois_cas_dans_la_structure(cur, jeu):
    cur.execute("SELECT * FROM clean_data.classifier_ibau_article()")
    assert _cas_mo(cur, 'ZZI-ROUGE') == {'cas_ibau': 'ARTICLE', 'nb_enfants': 0, 'nb_occurrences': 1}
    assert _cas_mo(cur, 'ZZI-BLEU') == {'cas_ibau': 'POSTE_TECHNIQUE', 'nb_enfants': 1, 'nb_occurrences': 1}
    assert _cas_mo(cur, 'ZZI-JAUNE') == {'cas_ibau': 'CONSERVER', 'nb_enfants': 1, 'nb_occurrences': 2}


def test_la_liste_fixe_recoit_les_memes_cas(cur, jeu):
    cur.execute("SELECT * FROM clean_data.classifier_ibau_article()")
    assert _cas_liste(cur, 'ZZI-ROUGE')['cas_ibau'] == 'ARTICLE'
    assert _cas_liste(cur, 'ZZI-BLEU')['cas_ibau'] == 'POSTE_TECHNIQUE'
    jaune = _cas_liste(cur, 'ZZI-JAUNE')
    assert (jaune['cas_ibau'], jaune['nb_enfants'], jaune['nb_occurrences']) == ('CONSERVER', 1, 2)
    assert jaune['cas_calcule_at'] is not None


def test_un_ibau_hors_structure_reste_sans_cas(cur, jeu):
    cur.execute("SELECT * FROM clean_data.classifier_ibau_article()")
    hors = _cas_liste(cur, 'ZZI-HORS')
    assert hors['cas_ibau'] is None
    assert hors['cas_calcule_at'] is not None, 'evalue, mais hors structure'


def test_un_article_non_ibau_n_est_pas_classe(cur, jeu):
    cur.execute("SELECT * FROM clean_data.classifier_ibau_article()")
    assert _cas_mo(cur, 'ZZI-COMP')['cas_ibau'] is None


def test_le_type_de_construction_compte_comme_occurrence(cur, jeu):
    """Un IBAU reference une fois en nomenclature ET type de construction
    (iflo.submt) d'un poste technique -> 2 occurrences -> CONSERVER."""
    ligne = _one(cur, """SELECT f.tplnr FROM raw_data.iflo f
                         JOIN clean_data.maintenance_object m
                           ON m.object_type = 'FUNC_LOC' AND m.is_active AND m.sap_key = f.tplnr
                         WHERE NULLIF(TRIM(f.submt), '') IS NOT NULL LIMIT 1""")
    cur.execute("UPDATE raw_data.iflo SET submt = 'ZZI-BLEU' WHERE tplnr = %s", [ligne['tplnr']])
    cur.execute("SELECT * FROM clean_data.classifier_ibau_article()")
    assert _cas_mo(cur, 'ZZI-BLEU') == {'cas_ibau': 'CONSERVER', 'nb_enfants': 1, 'nb_occurrences': 2}


def test_la_fonction_renvoie_les_compteurs(cur, jeu):
    cur.execute("SELECT cas, nb FROM clean_data.classifier_ibau_article() ORDER BY cas")
    compteurs = {r['cas']: r['nb'] for r in cur.fetchall()}
    assert set(compteurs) == {'ARTICLE', 'CONSERVER', 'POSTE_TECHNIQUE'}
    assert compteurs['ARTICLE'] >= 1 and compteurs['CONSERVER'] >= 1 and compteurs['POSTE_TECHNIQUE'] >= 1


def test_le_recalcul_suit_les_modifications(cur, jeu):
    """Apres transformation manuelle (l'enfant du bleu est supprime), le
    recalcul le fait passer en rouge : rien n'est fige."""
    cur.execute("SELECT * FROM clean_data.classifier_ibau_article()")
    cur.execute(f"UPDATE {MO} SET is_active = FALSE WHERE sap_key = 'ZZB-B2'")
    cur.execute("SELECT * FROM clean_data.classifier_ibau_article()")
    assert _cas_mo(cur, 'ZZI-BLEU')['cas_ibau'] == 'ARTICLE'
    assert _cas_liste(cur, 'ZZI-BLEU')['cas_ibau'] == 'ARTICLE'
