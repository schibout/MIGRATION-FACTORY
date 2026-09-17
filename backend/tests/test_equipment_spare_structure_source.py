"""
clean_data.load_equipment_spare_structure : la structure kit -> composants
exportee vers IFS doit partir de la nomenclature matiere PREPAREE DANS IH02
(clean_data.maintenance_object, BOM_ITEM sous un ARTICLE), pas de raw_data
(mast/stko/stpo), sinon les modifications faites a l'ecran sur la nomenclature
d'un article n'atteignent jamais l'export.

Vraie base, transaction jamais validee. La procedure du depot est recompilee
dans la transaction (CREATE OR REPLACE) pour tester la version du fichier.
"""
import os
import sys

import psycopg2
import psycopg2.extras
import pytest

BACKEND = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PROC = os.path.join(os.path.dirname(BACKEND), 'sql', 'maintenance', 'proc_load_equipment_spare_structure.sql')
if BACKEND not in sys.path:
    sys.path.insert(0, BACKEND)

MO = 'clean_data.maintenance_object'
ESS = 'clean_data.equipment_spare_structure'


@pytest.fixture
def cur():
    try:
        from config.database import get_db_params
        conn = psycopg2.connect(**get_db_params())
    except Exception as exc:  # pragma: no cover
        pytest.skip(f'base injoignable : {exc}')
    try:
        cur = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
        if os.path.exists(PROC):
            with open(PROC, encoding='utf-8') as f:
                cur.execute(f.read())
        yield cur
    finally:
        conn.rollback()
        conn.close()


def _one(cur, sql, params=None):
    cur.execute(sql, params or [])
    return cur.fetchone()


@pytest.fixture
def racine(cur):
    """Une racine reelle : article rattache a un poste technique
    (equipment_object_spare.spare_id) qui a une nomenclature matiere dans IH02."""
    r = _one(cur, f"""
        SELECT a.id, a.code, MIN(c.code) AS composant_existant
        FROM clean_data.equipment_object_spare s
        JOIN {MO} a ON a.object_type = 'ARTICLE' AND a.is_active AND a.code = s.spare_id
        JOIN {MO} b ON b.parent_id = a.id AND b.object_type = 'BOM_ITEM' AND b.is_active AND b.category = 'L'
        JOIN {MO} c ON c.id = b.ref_object_id
        GROUP BY a.id, a.code LIMIT 1""")
    assert r, 'aucune racine avec nomenclature matiere dans IH02'
    return r


def _composant_test(cur):
    return _one(cur, f"""
        INSERT INTO {MO} (object_type, sap_key, code, designation, type_code, source)
        VALUES ('ARTICLE', 'ZZS-COMP', 'ZZS-COMP', 'composant de test', 'ERSA', 'MANUAL') RETURNING id""")['id']


def _lignes(cur, spare_id):
    cur.execute(f"SELECT component_spare_id, qty, spare_contract FROM {ESS} WHERE spare_id = %s ORDER BY 1", [spare_id])
    return {r['component_spare_id']: r for r in cur.fetchall()}


def test_un_composant_ajoute_dans_ih02_sort_dans_l_export(cur, racine):
    comp = _composant_test(cur)
    cur.execute(f"""
        INSERT INTO {MO} (object_type, sap_key, parent_id, ref_object_id, code, category, quantity, source)
        VALUES ('BOM_ITEM', 'ZZS-B1', %s, %s, 'ZZS-COMP', 'L', 3, 'MANUAL')""", [racine['id'], comp])
    cur.execute("CALL clean_data.load_equipment_spare_structure('FULL')")
    lignes = _lignes(cur, racine['code'])
    assert 'ZZS-COMP' in lignes, 'le composant ajoute a l ecran est absent de l export'
    assert lignes['ZZS-COMP']['qty'] == 3


def test_un_composant_supprime_dans_ih02_disparait_de_l_export(cur, racine):
    cur.execute("CALL clean_data.load_equipment_spare_structure('FULL')")
    assert racine['composant_existant'] in _lignes(cur, racine['code'])

    cur.execute(f"""UPDATE {MO} SET is_active = FALSE
                    WHERE object_type = 'BOM_ITEM' AND parent_id = %s
                      AND ref_object_id = (SELECT id FROM {MO} WHERE object_type = 'ARTICLE' AND code = %s)""",
                [racine['id'], racine['composant_existant']])
    cur.execute("CALL clean_data.load_equipment_spare_structure('FULL')")
    assert racine['composant_existant'] not in _lignes(cur, racine['code'])


def test_le_contrat_est_celui_de_la_racine(cur, racine):
    """Mono-site comme equipment_functional / equipment_object_spare : le
    contrat est herite de la racine (equipment_object_spare.contract) sur tout
    le sous-arbre, plus de la division SAP de la nomenclature (qui produisait
    des lignes CS dans une structure SJ)."""
    cur.execute("CALL clean_data.load_equipment_spare_structure('FULL')")
    cur.execute(f"""SELECT DISTINCT c FROM (
                        SELECT spare_contract AS c FROM {ESS}
                        UNION SELECT component_spare_contract FROM {ESS}) x
                    WHERE c NOT IN (SELECT DISTINCT contract FROM clean_data.equipment_object_spare)""")
    assert cur.fetchall() == [], 'contrat inconnu des racines'


def test_le_mode_delta_recharge_le_sous_arbre_depuis_ih02(cur, racine):
    cur.execute("CALL clean_data.load_equipment_spare_structure('FULL')")
    comp = _composant_test(cur)
    cur.execute(f"""
        INSERT INTO {MO} (object_type, sap_key, parent_id, ref_object_id, code, category, quantity, source)
        VALUES ('BOM_ITEM', 'ZZS-B2', %s, %s, 'ZZS-COMP', 'L', 1, 'MANUAL')""", [racine['id'], comp])
    cur.execute("CALL clean_data.load_equipment_spare_structure('DELTA', %s)", [racine['code']])
    assert 'ZZS-COMP' in _lignes(cur, racine['code'])
