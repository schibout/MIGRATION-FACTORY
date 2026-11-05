"""Ecran Donnees IFS > Operations de maintenance (/ifs-data/operations) : consultation des tables
clean_data de la categorie d'export 'Operation' (module etl_operation.py).

  GET  /api/v1/ifs-data/operations              onglet, table, search, page, page_size
  GET  /api/v1/ifs-data/operations/export.xlsx  onglet, search : une feuille par table de l'onglet

Lecture seule. Colonnes lues dans public.etl_export_queries, comme l'export.
"""
from flask import Blueprint
from flask_jwt_extended import jwt_required

from .ifs_consultation import exporter, lister, source_export

ifs_data_operations_blueprint = Blueprint('ifs_data_operations', __name__)

SYNC_KEY = 'operations_ifs'  # jamais ecrite ici : l'ecran n'a pas de synchronisation

# table -> (libelle, expressions de recherche)
TABLES = {
    'jt_task': ('Opérations', ['t.task_seq::text', 't.wo_no::text', 't.description', 't.mach_code']),
    'jt_task_resource': ('Ressources', ['t.task_seq::text', 't.wo_no::text', 't.resource_seq']),
    'maint_material_req_line': ('Besoins matière', ['t.task_seq::text', 't.wo_no::text', 't.part_no']),
}
CONTROLES = ['objet_inconnu', 'sans_ressource', 'ressource_sans_operation', 'besoin_sans_operation',
             'article_hors_catalogue']

ONGLETS = {
    'synthese': ['synthese'],
    'operations': ['jt_task'],
    'ressources': ['jt_task_resource'],
    'besoins': ['maint_material_req_line'],
    'controles': CONTROLES,
}

LIBELLES = {'task_seq': 'N° opération', 'wo_no': 'N° bon de travail', 'order_no': 'N° ordre', 'site': 'Site',
            'description': 'Description', 'mach_code': 'Objet', 'part_no': 'N° article',
            'work_type_id': 'Type de travail'}
_ABSENTE = 'NOT EXISTS (SELECT 1 FROM clean_data.{0} x WHERE x.{1} = t.{1})'


def _source_table(table):
    label, recherche = TABLES[table]
    return source_export(table, label, recherche, 't.task_seq', 't.task_seq', LIBELLES)


def _source_synthese():
    def nombre(alias, table):
        return f'LEFT JOIN (SELECT task_seq, count(*) AS n FROM clean_data.{table} GROUP BY 1) {alias} ' \
               f'ON {alias}.task_seq = p.task_seq'
    return {
        'label': 'Synthèse',
        'from': f"clean_data.jt_task p {nombre('r', 'jt_task_resource')} {nombre('m', 'maint_material_req_line')}",
        'colonnes': [('p.task_seq', 'task_seq', 'N° opération'),
                     ('p.wo_no', 'wo_no', 'N° bon de travail'),
                     ('p.site', 'site', 'Site'),
                     ('p.description', 'description', 'Description'),
                     ('p.mach_code', 'mach_code', 'Objet'),
                     ('p.work_type_id', 'work_type_id', 'Type de travail'),
                     ('p.organization_id', 'organization_id', 'Organisation'),
                     ('p.planned_start', 'planned_start', 'Début prévu'),
                     ('p.planned_finish', 'planned_finish', 'Fin prévue'),
                     ('p.actual_start', 'actual_start', 'Début réel'),
                     ('p.duration', 'duration', 'Durée'),
                     ('COALESCE(r.n, 0)', 'nb_ressources', 'Ressources'),
                     ('COALESCE(m.n, 0)', 'nb_besoins', 'Besoins matière')],
        'recherche': ['p.task_seq::text', 'p.wo_no::text', 'p.description', 'p.mach_code'],
        'cle': 'p.task_seq',
        'ordre': 'p.task_seq',
    }


def _source_controle(code):
    table, label, where = {
        'objet_inconnu': ('jt_task', 'Objet absent de la structure',
                          "t.mach_code IS NOT NULL "
                          "AND NOT EXISTS (SELECT 1 FROM clean_data.equipment_functional x WHERE x.mch_code = t.mach_code) "
                          "AND NOT EXISTS (SELECT 1 FROM clean_data.equipment_serial x WHERE x.mch_code = t.mach_code)"),
        'sans_ressource': ('jt_task', 'Opération sans ressource', _ABSENTE.format('jt_task_resource', 'task_seq')),
        'ressource_sans_operation': ('jt_task_resource', 'Ressource sans opération',
                                     _ABSENTE.format('jt_task', 'task_seq')),
        'besoin_sans_operation': ('maint_material_req_line', 'Besoin matière sans opération',
                                  _ABSENTE.format('jt_task', 'task_seq')),
        'article_hors_catalogue': ('maint_material_req_line', 'Article hors catalogue',
                                   't.part_no IS NOT NULL AND ' + _ABSENTE.format('part_catalog', 'part_no')),
    }[code]
    return {**_source_table(table), 'label': label, 'where': where}


def _source(key):
    if key == 'synthese':
        return _source_synthese()
    return _source_table(key) if key in TABLES else _source_controle(key)


@ifs_data_operations_blueprint.route('', methods=['GET'])
@jwt_required()
def liste():
    return lister(ONGLETS, _source, SYNC_KEY)


@ifs_data_operations_blueprint.route('/export.xlsx', methods=['GET'])
@jwt_required()
def export():
    return exporter(ONGLETS, _source, 'operations_ifs')
