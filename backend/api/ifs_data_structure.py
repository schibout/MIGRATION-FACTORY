"""Ecran Donnees IFS > Structure (/ifs-data/structure) : consultation des tables clean_data de la
structure de maintenance exportees vers IFS (module etl_equipment_functional.py).

  GET  /api/v1/ifs-data/structure              onglet, table, search, page, page_size
  GET  /api/v1/ifs-data/structure/export.xlsx  onglet, search : une feuille par table de l'onglet
  GET  /api/v1/ifs-data/structure/sync         etat du dernier rechargement
  POST /api/v1/ifs-data/structure/sync         {"source": "mf"} module ETL seul ; {"source": "sap"} job de fusion maintenance puis module ETL

Lecture seule, sans rechargement : ces tables se rechargent depuis Chargement des donnees.
"""
import time

from flask import Blueprint, current_app
from flask_jwt_extended import jwt_required

from .finance import _write_status
from .ifs_consultation import colonnes_catalogue, colonnes_table, exporter, lister, routes_sync
from .sap_articles import q

ifs_data_structure_blueprint = Blueprint('ifs_data_structure', __name__)

SYNC_KEY = 'structure_maintenance'

TABLES = {
    'equipment_functional': 'Postes techniques',
    'equipment_serial': 'Équipements',
    'equipment_object_spare': 'Pièces de rechange',
    'equipment_spare_structure': 'Composition des kits',
}
CONTROLES = ['code_poste_en_double', 'parent_inconnu', 'piece_objet_inconnu', 'piece_hors_catalogue',
             'kit_hors_catalogue', 'article_equipement_inconnu']

ONGLETS = {
    'synthese': ['synthese'],
    'postes': ['equipment_functional'],
    'equipements': ['equipment_serial'],
    'pieces': ['equipment_object_spare'],
    'kits': ['equipment_spare_structure'],
    'controles': CONTROLES,
}

_FONCTIONNELS = "SELECT mch_code, mch_name, sup_mch_code, 1 AS rang, 'Poste technique' AS nature " \
                "FROM clean_data.equipment_functional"
_EQUIPEMENTS = "SELECT mch_code, mch_name, sup_mch_code, 2 AS rang, 'Équipement' AS nature " \
               "FROM clean_data.equipment_serial"
_OBJETS = f'({_FONCTIONNELS} UNION ALL {_EQUIPEMENTS})'
# Un code de poste peut exister sous deux parents : une seule ligne par code pour les jointures
_OBJET_UNIQUE = f'(SELECT DISTINCT ON (mch_code) mch_code, mch_name, nature FROM {_OBJETS} u ORDER BY mch_code, rang)'
_ABSENT_CATALOGUE = 'NOT EXISTS (SELECT 1 FROM clean_data.part_catalog x WHERE x.part_no = {0})'
_ABSENT_OBJET = f'NOT EXISTS (SELECT 1 FROM {_OBJETS} x WHERE x.mch_code = {{0}})'

_PIECE = {
    'from': f'clean_data.equipment_object_spare t LEFT JOIN {_OBJET_UNIQUE} o ON o.mch_code = t.equipment_object_seq '
            'LEFT JOIN clean_data.part_catalog g ON g.part_no = t.spare_id',
    'colonnes': [('t.equipment_object_seq', 'objet', 'Objet'),
                 ('o.nature', 'nature', 'Nature'),
                 ('o.mch_name', 'objet_designation', 'Désignation objet'),
                 ('t.contract', 'contract', 'Site'),
                 ('t.spare_id', 'spare_id', 'N° article'),
                 ('g.description', 'article_designation', 'Désignation article'),
                 ('t.qty', 'qty', 'Quantité')],
    'recherche': ['t.equipment_object_seq', 'o.mch_name', 't.spare_id', 'g.description'],
    'cle': 't.equipment_object_seq',
    'ordre': 't.equipment_object_seq, t.spare_id, t.ctid',
}
_KIT = {
    'from': 'clean_data.equipment_spare_structure t '
            'LEFT JOIN clean_data.part_catalog g ON g.part_no = t.spare_id '
            'LEFT JOIN clean_data.part_catalog c ON c.part_no = t.component_spare_id',
    'colonnes': [('t.spare_id', 'spare_id', 'N° article kit'),
                 ('g.description', 'kit_designation', 'Désignation kit'),
                 ('t.component_spare_id', 'component_spare_id', 'N° composant'),
                 ('c.description', 'composant_designation', 'Désignation composant'),
                 ('t.spare_contract', 'spare_contract', 'Site'),
                 ('t.qty', 'qty', 'Quantité')],
    'recherche': ['t.spare_id', 'g.description', 't.component_spare_id', 'c.description'],
    'cle': 't.spare_id',
    'ordre': 't.spare_id, t.component_spare_id, t.ctid',
}


def _source_objet(table):
    alias = [('t.mch_code', 'mch_code', 'Code'), ('t.mch_name', 'mch_name', 'Désignation'),
             ('t.sup_mch_code', 'sup_mch_code', 'Parent'), ('t.contract', 'contract', 'Site')]
    exclues = [k for _, k, _ in alias]
    return {
        'label': TABLES[table],
        'from': f'clean_data.{q(table)} t',
        'colonnes': alias + colonnes_catalogue(table, colonnes_table(table, *exclues)),
        'recherche': ['t.mch_code', 't.mch_name', 't.sup_mch_code'],
        'cle': 't.mch_code',
        'ordre': 't.mch_code, t.ctid',
    }


def _source_synthese():
    return {
        'label': 'Synthèse',
        'from': f"""{_OBJETS} o
            LEFT JOIN (SELECT sup_mch_code AS c, count(*) AS n
                       FROM clean_data.equipment_serial GROUP BY 1) e ON e.c = o.mch_code
            LEFT JOIN (SELECT equipment_object_seq AS c, count(*) AS n
                       FROM clean_data.equipment_object_spare GROUP BY 1) s ON s.c = o.mch_code""",
        'colonnes': [('o.mch_code', 'mch_code', 'Code'),
                     ('o.mch_name', 'mch_name', 'Désignation'),
                     ('o.nature', 'nature', 'Nature'),
                     ('o.sup_mch_code', 'sup_mch_code', 'Parent'),
                     ('COALESCE(e.n, 0)', 'nb_equipements', 'Équipements rattachés'),
                     ('COALESCE(s.n, 0)', 'nb_pieces', 'Pièces de rechange')],
        'recherche': ['o.mch_code', 'o.mch_name', 'o.sup_mch_code'],
        'cle': 'o.mch_code',
        'ordre': 'o.rang, o.mch_code, o.sup_mch_code',
    }


def _source_controle(code):
    if code == 'code_poste_en_double':
        return {**_source_objet('equipment_functional'), 'label': 'Code de poste en double',
                'where': 't.mch_code IN (SELECT mch_code FROM clean_data.equipment_functional '
                         'GROUP BY mch_code HAVING count(*) > 1)'}
    if code == 'parent_inconnu':
        return {
            'label': 'Parent absent de la structure',
            'from': f'{_OBJETS} o',
            'where': 'o.sup_mch_code IS NOT NULL AND ' + _ABSENT_OBJET.format('o.sup_mch_code'),
            'colonnes': [('o.mch_code', 'mch_code', 'Code'), ('o.mch_name', 'mch_name', 'Désignation'),
                         ('o.nature', 'nature', 'Nature'), ('o.sup_mch_code', 'sup_mch_code', 'Parent')],
            'recherche': ['o.mch_code', 'o.mch_name', 'o.sup_mch_code'],
            'cle': 'o.mch_code',
            'ordre': 'o.rang, o.mch_code',
        }
    if code == 'piece_objet_inconnu':
        return {**_PIECE, 'label': 'Pièce sur un objet absent',
                'where': _ABSENT_OBJET.format('t.equipment_object_seq')}
    if code == 'piece_hors_catalogue':
        return {**_PIECE, 'label': 'Pièce hors catalogue', 'where': _ABSENT_CATALOGUE.format('t.spare_id')}
    if code == 'kit_hors_catalogue':
        return {**_KIT, 'label': 'Kit ou composant hors catalogue',
                'where': f"({_ABSENT_CATALOGUE.format('t.spare_id')} "
                         f"OR {_ABSENT_CATALOGUE.format('t.component_spare_id')})"}
    return {**_source_objet('equipment_serial'), 'label': 'Article d’équipement hors catalogue',
            'where': 't.part_no IS NOT NULL AND ' + _ABSENT_CATALOGUE.format('t.part_no')}


def _source(key):
    if key == 'synthese':
        return _source_synthese()
    if key == 'equipment_object_spare':
        return {**_PIECE, 'label': TABLES[key]}
    if key == 'equipment_spare_structure':
        return {**_KIT, 'label': TABLES[key]}
    return _source_objet(key) if key in TABLES else _source_controle(key)


@ifs_data_structure_blueprint.route('', methods=['GET'])
@jwt_required()
def liste():
    return lister(ONGLETS, _source, SYNC_KEY)


@ifs_data_structure_blueprint.route('/export.xlsx', methods=['GET'])
@jwt_required()
def export():
    return exporter(ONGLETS, _source, 'structure_ifs')


def _jobs():
    from services import maintenance_reload_service
    return maintenance_reload_service


def _operation_en_cours():
    from .maintenance_snapshots import active_job_conflict
    return active_job_conflict()


def _recharger_maintenance(cle, utilisateur):
    """Passe par le job de fusion : snapshot prealable, saisies preservees (source MANUAL, updated_by), un seul
    job a la fois. Une extraction directe n'alimenterait pas clean_data.maintenance_object, lue par le module."""
    jobs = _jobs()
    job_id = jobs.create_job('RELOAD', {'mode': 'merge', 'with_extraction': True}, user=utilisateur)['id']
    jobs.start_job(current_app._get_current_object(), job_id)
    while True:
        time.sleep(5)
        job = jobs.get_job(job_id)
        _write_status(cle, step=job['current_step'], progress=int(0.85 * (job['progress'] or 0)))
        if job['status'] == 'DONE':
            break
        if job['status'] == 'ERROR':
            raise RuntimeError(f"Rechargement maintenance en échec : {job.get('error_message')}")
    _write_status(cle, step='Calcul du module ETL structure', progress=90)


lancer_sync = routes_sync(ifs_data_structure_blueprint, SYNC_KEY, 'etl_equipment_functional.py',
                          'SELECT count(*) FROM clean_data.equipment_functional',
                          avant_module=_recharger_maintenance, garde=_operation_en_cours)
