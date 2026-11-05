"""Ecran Donnees IFS > PM Actions (/ifs-data/pm-actions) : consultation des tables clean_data de la
categorie d'export 'PM Action' (module etl_pm_action.py).

  GET  /api/v1/ifs-data/pm-actions              onglet, table, search, page, page_size
  GET  /api/v1/ifs-data/pm-actions/export.xlsx  onglet, search : une feuille par table de l'onglet

Lecture seule. Colonnes lues dans public.etl_export_queries, comme l'export.
"""
from flask import Blueprint
from flask_jwt_extended import jwt_required

from .ifs_consultation import exporter, lister, source_export

ifs_data_pm_actions_blueprint = Blueprint('ifs_data_pm_actions', __name__)

SYNC_KEY = 'pm_actions_ifs'  # jamais ecrite ici : l'ecran n'a pas de synchronisation

# table -> (libelle, colonnes de recherche en plus du N° de plan)
TABLES = {
    'pm_action': ('Plans', ['description', 'mch_code']),
    'pm_action_work_step': ('Étapes de travail', ['description', 'mch_code']),
    'pm_action_resource': ('Ressources', ['resource_group', 'resource_id', 'resource_description']),
    'pm_action_role': ('Rôles', ['description', 'team_id']),
    'pm_action_job': ('Travaux', ['std_job_id', 'description']),
    'pm_action_planning': ('Planification', ['catalog_no']),
    'pm_action_spare_part': ('Pièces de rechange', ['part_no', 'catalog_no']),
}
_FILLES = [t for t in TABLES if t != 'pm_action']
# Tables alimentees par etl_pm_action.py : un plan charge doit y figurer
_ATTENDUES = ['pm_action_work_step', 'pm_action_resource', 'pm_action_role']
CONTROLES = ['objet_inconnu', 'piece_hors_catalogue'] + [f'sans_{t}' for t in _ATTENDUES] \
    + [f'orph_{t}' for t in _FILLES]

ONGLETS = {
    'synthese': ['synthese'],
    'plans': ['pm_action'],
    'etapes': ['pm_action_work_step'],
    'ressources': ['pm_action_resource'],
    'roles': ['pm_action_role'],
    'travaux': ['pm_action_job'],
    'planification': ['pm_action_planning'],
    'pieces': ['pm_action_spare_part'],
    'controles': CONTROLES,
}

LIBELLES = {'pm_no': 'N° plan', 'pm_revision': 'Révision', 'description': 'Description', 'mch_code': 'Objet',
            'mch_code_contract': 'Site objet', 'part_no': 'N° article', 'work_type_id': 'Type de travail'}
_MEME_PLAN = 'x.pm_no = {0}.pm_no AND x.pm_revision = {0}.pm_revision'


def _absent(table, condition):
    return f'NOT EXISTS (SELECT 1 FROM clean_data.{table} x WHERE {condition})'


def _source_table(table):
    label, recherche = TABLES[table]
    return source_export(table, label, ['t.pm_no::text'] + [f't.{c}' for c in recherche], 't.pm_no',
                         't.pm_no, t.pm_revision', LIBELLES)


def _source_synthese():
    def nombre(alias, table):
        return f'LEFT JOIN (SELECT pm_no, pm_revision, count(*) AS n FROM clean_data.{table} GROUP BY 1, 2) {alias} ' \
               f'ON {alias}.pm_no = p.pm_no AND {alias}.pm_revision = p.pm_revision'
    return {
        'label': 'Synthèse',
        'from': f"""clean_data.pm_action p {nombre('e', 'pm_action_work_step')}
            {nombre('r', 'pm_action_resource')} {nombre('o', 'pm_action_role')}
            {nombre('j', 'pm_action_job')} {nombre('s', 'pm_action_spare_part')}""",
        'colonnes': [('p.pm_no', 'pm_no', 'N° plan'),
                     ('p.pm_revision', 'pm_revision', 'Révision'),
                     ('p.description', 'description', 'Description'),
                     ('p.mch_code', 'mch_code', 'Objet'),
                     ('p.mch_code_contract', 'mch_code_contract', 'Site'),
                     ('p.action_code_id', 'action_code_id', 'Code action'),
                     ('p.work_type_id', 'work_type_id', 'Type de travail'),
                     ('p.org_code', 'org_code', 'Organisation'),
                     ('p.interval', 'interval', 'Intervalle'),
                     ('p.pm_interval_unit_db', 'pm_interval_unit_db', 'Unité'),
                     ('p.plan_hrs', 'plan_hrs', 'Heures prévues'),
                     ('p.state', 'state', 'État'),
                     ('COALESCE(e.n, 0)', 'nb_etapes', 'Étapes'),
                     ('COALESCE(r.n, 0)', 'nb_ressources', 'Ressources'),
                     ('COALESCE(o.n, 0)', 'nb_roles', 'Rôles'),
                     ('COALESCE(j.n, 0)', 'nb_travaux', 'Travaux'),
                     ('COALESCE(s.n, 0)', 'nb_pieces', 'Pièces')],
        'recherche': ['p.pm_no::text', 'p.description', 'p.mch_code'],
        'cle': 'p.pm_no',
        'ordre': 'p.pm_no, p.pm_revision',
    }


def _source_controle(code):
    if code == 'objet_inconnu':
        return {**_source_table('pm_action'), 'label': 'Objet absent de la structure',
                'where': 't.mch_code IS NOT NULL AND '
                         + _absent('equipment_functional', 'x.mch_code = t.mch_code') + ' AND '
                         + _absent('equipment_serial', 'x.mch_code = t.mch_code')}
    if code == 'piece_hors_catalogue':
        return {**_source_table('pm_action_spare_part'), 'label': 'Pièce hors catalogue',
                'where': 't.part_no IS NOT NULL AND ' + _absent('part_catalog', 'x.part_no = t.part_no')}
    if code.startswith('sans_'):
        table = code[len('sans_'):]
        return {**_source_table('pm_action'), 'label': f'Plan sans : {TABLES[table][0]}',
                'where': _absent(table, _MEME_PLAN.format('t'))}
    table = code[len('orph_'):]
    return {**_source_table(table), 'label': f'Plan inconnu : {TABLES[table][0]}',
            'where': _absent('pm_action', _MEME_PLAN.format('t'))}


def _source(key):
    if key == 'synthese':
        return _source_synthese()
    return _source_table(key) if key in TABLES else _source_controle(key)


@ifs_data_pm_actions_blueprint.route('', methods=['GET'])
@jwt_required()
def liste():
    return lister(ONGLETS, _source, SYNC_KEY)


@ifs_data_pm_actions_blueprint.route('/export.xlsx', methods=['GET'])
@jwt_required()
def export():
    return exporter(ONGLETS, _source, 'pm_actions_ifs')
