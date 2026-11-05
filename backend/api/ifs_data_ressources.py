"""Ecran Donnees IFS > Maintenance Ressource (/ifs-data/maintenance-ressources) : consultation des tables
clean_data de la categorie d'export 'maintenance' (module etl_maintenance_resource.py).

  GET  /api/v1/ifs-data/maintenance-ressources              onglet, table, search, page, page_size
  GET  /api/v1/ifs-data/maintenance-ressources/export.xlsx  onglet, search : une feuille par table de l'onglet

Lecture seule. Colonnes lues dans public.etl_export_queries, comme l'export, precedees de la ressource.
"""
from flask import Blueprint
from flask_jwt_extended import jwt_required

from .ifs_consultation import colonnes_catalogue, colonnes_export, exporter, lister
from .sap_articles import q

ifs_data_ressources_blueprint = Blueprint('ifs_data_ressources', __name__)

SYNC_KEY = 'ressources_ifs'  # jamais ecrite ici : l'ecran n'a pas de synchronisation

# table -> (colonne portant le N° de la ressource, libelle)
TABLES = {
    'resource_detail_file': ('resource_seq', 'Ressources'),
    'resource_connection': ('resource_seq', 'Connexions'),
    'resource_availability': ('resource_seq', 'Disponibilités'),
    'resource_parent': ('resource_seq', 'Hiérarchie'),
    'maint_person_resource': ('maint_resource_seq', 'Personnes de maintenance'),
}
_ATTENDUES = ['resource_connection', 'resource_availability', 'resource_parent']
_FILLES = [t for t in TABLES if t != 'resource_detail_file']
CONTROLES = [f'sans_{t}' for t in _ATTENDUES] + ['personne_sans_maintenance'] + [f'orph_{t}' for t in _FILLES] \
    + ['personne_sans_connexion']

ONGLETS = {
    'synthese': ['synthese'],
    'ressources': ['resource_detail_file'],
    'connexions': ['resource_connection'],
    'disponibilites': ['resource_availability'],
    'hierarchie': ['resource_parent'],
    'personnes': ['maint_person_resource'],
    'controles': CONTROLES,
}

_DETAIL = 'clean_data.resource_detail_file'
_RESSOURCE = [('d.resource_id', 'ressource', 'Ressource'), ('d.description', 'ressource_nom', 'Nom de la ressource')]
_RECHERCHE = ['d.resource_seq::text', 'd.resource_id', 'd.description']


def _source_table(table):
    cle, label = TABLES[table]
    cle_sql = f't.{q(cle)}'
    if table == 'resource_detail_file':
        return {'label': label, 'from': f'{_DETAIL} t', 'colonnes': colonnes_export(table),
                'recherche': [f'{cle_sql}::text', 't.resource_id', 't.description'],
                'cle': cle_sql, 'ordre': f'{cle_sql}, t.ctid'}
    colonnes = colonnes_export(table)
    # maint_person_resource n'exporte pas sa cle : sans elle, une ligne sans ressource serait inidentifiable
    if cle not in [c[1] for c in colonnes]:
        colonnes = colonnes_catalogue(table, [cle]) + colonnes
    return {
        'label': label,
        'from': f'clean_data.{q(table)} t LEFT JOIN {_DETAIL} d ON d.resource_seq = {cle_sql}',
        'colonnes': _RESSOURCE + colonnes,
        'recherche': [f'{cle_sql}::text', 'd.resource_id', 'd.description'],
        'cle': cle_sql,
        'ordre': f'{cle_sql}, t.ctid',
    }


def _source_synthese():
    def nombre(alias, table):
        cle = q(TABLES[table][0])
        return f'LEFT JOIN (SELECT {cle} AS k, count(*) AS n FROM clean_data.{q(table)} GROUP BY 1) {alias} ' \
               f'ON {alias}.k = d.resource_seq'
    return {
        'label': 'Synthèse',
        'from': f"""{_DETAIL} d
            LEFT JOIN (SELECT resource_seq, string_agg(DISTINCT company, ', ') AS societes,
                              string_agg(DISTINCT site, ', ') AS sites, min(primary_parent_resource_seq) AS parent_seq
                       FROM clean_data.resource_connection GROUP BY 1) c ON c.resource_seq = d.resource_seq
            LEFT JOIN {_DETAIL} p ON p.resource_seq = c.parent_seq
            {nombre('h', 'resource_parent')} {nombre('m', 'maint_person_resource')}""",
        'colonnes': _RESSOURCE + [('d.resource_seq', 'resource_seq', 'N° ressource'),
                                  ('d.resource_type_db', 'type', 'Type'),
                                  ('d.resource_category', 'categorie', 'Catégorie'),
                                  ('c.societes', 'societe', 'Société'),
                                  ('c.sites', 'site', 'Site'),
                                  ('d.calendar_id', 'calendrier', 'Calendrier'),
                                  ('p.resource_id', 'parent', 'Ressource parente'),
                                  ('d.used_in_maintenance_db', 'maintenance', 'Utilisée en maintenance'),
                                  ('COALESCE(h.n, 0)', 'nb_parents', 'Parents'),
                                  ('COALESCE(m.n, 0)', 'nb_personnes', 'Fiches maintenance')],
        'recherche': _RECHERCHE,
        'cle': 'd.resource_seq',
        'ordre': 'd.resource_id',
    }


def _absent(table, cle):
    return f'NOT EXISTS (SELECT 1 FROM clean_data.{table} x WHERE x.{cle} = t.resource_seq)'


def _source_controle(code):
    detail = _source_table('resource_detail_file')
    if code == 'personne_sans_maintenance':
        return {**detail, 'label': 'Personne sans fiche maintenance',
                'where': "t.resource_type_db = 'PERSON' AND " + _absent('maint_person_resource', 'maint_resource_seq')}
    if code == 'personne_sans_connexion':
        return {**_source_table('maint_person_resource'), 'label': 'Fiche maintenance sans connexion',
                'where': 'NOT EXISTS (SELECT 1 FROM clean_data.resource_connection x '
                         'WHERE x.resource_connection_seq = t.resource_connection_seq)'}
    if code.startswith('sans_'):
        table = code[len('sans_'):]
        return {**detail, 'label': f'Ressource sans : {TABLES[table][1]}',
                'where': _absent(table, TABLES[table][0])}
    table = code[len('orph_'):]
    return {**_source_table(table), 'label': f'Ressource inconnue : {TABLES[table][1]}', 'where': 'd.resource_seq IS NULL'}


def _source(key):
    if key == 'synthese':
        return _source_synthese()
    return _source_table(key) if key in TABLES else _source_controle(key)


@ifs_data_ressources_blueprint.route('', methods=['GET'])
@jwt_required()
def liste():
    return lister(ONGLETS, _source, SYNC_KEY)


@ifs_data_ressources_blueprint.route('/export.xlsx', methods=['GET'])
@jwt_required()
def export():
    return exporter(ONGLETS, _source, 'ressources_maintenance_ifs')
