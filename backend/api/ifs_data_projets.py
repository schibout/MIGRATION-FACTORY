"""Ecran Donnees IFS > Projets (/ifs-data/projets) : consultation des tables clean_data de la
categorie d'export 'project' (module etl_project.py).

  GET  /api/v1/ifs-data/projets              onglet, table, search, page, page_size
  GET  /api/v1/ifs-data/projets/export.xlsx  onglet, search : une feuille par table de l'onglet
  GET  /api/v1/ifs-data/projets/sync         etat du dernier rechargement
  POST /api/v1/ifs-data/projets/sync         {"source": "mf"} module ETL seul ; {"source": "sap"} import ASAP puis module ETL

Lecture seule. Les colonnes viennent de public.etl_export_queries, comme l'export
(services/export_service.py) : l'ecran montre les colonnes du CSV, dans le meme ordre.
"""
from flask import Blueprint
from flask_jwt_extended import jwt_required

from .finance import _write_status
from .ifs_consultation import colonnes_export, exporter, lister, routes_sync
from .sap_articles import q

ifs_data_projets_blueprint = Blueprint('ifs_data_projets', __name__)

SYNC_KEY = 'projets_ifs'

TABLES = {
    'project_base': 'Projets',
    'project_site_ext': 'Sites',
    'sub_project': 'Sous-projets',
    'project_activity': 'Activités',
    'project_activity_class': "Classes d'activité",
    'project_role': 'Rôles',
    'project_role_assignment': 'Affectations',
}
CONTROLES = ['projet_sans_activite', 'sous_projet_sans_projet', 'parent_inconnu', 'activite_sans_sous_projet',
             'classe_sans_activite', 'affectation_sans_role']

ONGLETS = {
    'synthese': ['synthese'],
    'projets': ['project_base', 'project_site_ext'],
    'sous_projets': ['sub_project'],
    'activites': ['project_activity', 'project_activity_class'],
    'roles': ['project_role', 'project_role_assignment'],
    'controles': CONTROLES,
}

# Colonnes de recherche et tri de chaque table
_TABLES = {
    'project_base': (['project_id', 'name', 'description', 'manager'], 'project_id'),
    'project_site_ext': (['project_id', 'site'], 'project_id, site'),
    'sub_project': (['project_id', 'sub_project_id', 'description', 'manager'], 'project_id, sub_project_id'),
    'project_activity': (['project_id', 'sub_project_id', 'activity_no', 'description', 'activity_responsible'],
                         'project_id, sub_project_id, activity_no'),
    'project_activity_class': (['project_id', 'sub_project_id', 'activity_no', 'activity_class_id', 'value'],
                               'project_id, sub_project_id, activity_no, activity_class_id'),
    'project_role': (['project_id', 'role_id'], 'project_id, role_id'),
    'project_role_assignment': (['project_id', 'role_id', 'person_id'], 'project_id, role_id, person_id'),
}
_ABSENT = 'NOT EXISTS (SELECT 1 FROM clean_data.{0} x WHERE {1})'


def _source_table(table):
    recherche, ordre = _TABLES[table]
    return {
        'label': TABLES[table],
        'from': f'clean_data.{q(table)} t',
        'colonnes': colonnes_export(table),
        'recherche': [f't.{c}' for c in recherche],
        'cle': 't.project_id',
        'ordre': ', '.join(f't.{c.strip()}' for c in ordre.split(',')) + ', t.ctid',
    }


def _source_synthese():
    def nombre(alias, table):
        return f'LEFT JOIN (SELECT project_id, count(*) AS n FROM clean_data.{table} GROUP BY 1) {alias} ' \
               f'ON {alias}.project_id = p.project_id'
    return {
        'label': 'Synthèse',
        'from': f"""clean_data.project_base p
            {nombre('s', 'sub_project')} {nombre('a', 'project_activity')} {nombre('r', 'project_role')}
            LEFT JOIN (SELECT project_id, string_agg(site, ', ' ORDER BY site) AS sites
                       FROM clean_data.project_site_ext GROUP BY 1) e ON e.project_id = p.project_id""",
        'colonnes': [('p.project_id', 'project_id', 'Projet'),
                     ('p.name', 'name', 'Nom'),
                     ('p.company', 'company', 'Société'),
                     ('e.sites', 'sites', 'Sites'),
                     ('p.manager', 'manager', 'Responsable'),
                     ('p.customer_id', 'customer_id', 'Client'),
                     ('p.plan_start', 'plan_start', 'Début prévu'),
                     ('p.plan_finish', 'plan_finish', 'Fin prévue'),
                     ('p.actual_start', 'actual_start', 'Début réel'),
                     ('p.close_date', 'close_date', 'Clôture'),
                     ('COALESCE(s.n, 0)', 'nb_sous_projets', 'Sous-projets'),
                     ('COALESCE(a.n, 0)', 'nb_activites', 'Activités'),
                     ('COALESCE(r.n, 0)', 'nb_roles', 'Rôles')],
        'recherche': ['p.project_id', 'p.name', 'p.manager', 'e.sites'],
        'cle': 'p.project_id',
        'ordre': 'p.project_id',
    }


_MEME_SOUS_PROJET = 'x.project_id = t.project_id AND x.sub_project_id = t.sub_project_id'


def _source_controle(code):
    table, label, where = {
        'projet_sans_activite': ('project_base', 'Projet sans activité',
                                 _ABSENT.format('project_activity', 'x.project_id = t.project_id')),
        'sous_projet_sans_projet': ('sub_project', 'Sous-projet sans projet',
                                    _ABSENT.format('project_base', 'x.project_id = t.project_id')),
        'parent_inconnu': ('sub_project', 'Sous-projet parent absent',
                           't.parent_sub_project_id IS NOT NULL AND ' + _ABSENT.format(
                               'sub_project',
                               'x.project_id = t.project_id AND x.sub_project_id = t.parent_sub_project_id')),
        'activite_sans_sous_projet': ('project_activity', 'Activité sans sous-projet',
                                      _ABSENT.format('sub_project', _MEME_SOUS_PROJET)),
        # activity_seq n'est pas renseigne dans cette table : le lien passe par le N° d'activite
        'classe_sans_activite': ('project_activity_class', "Classe d'activité sans activité",
                                 _ABSENT.format('project_activity',
                                                f'{_MEME_SOUS_PROJET} AND x.activity_no = t.activity_no')),
        'affectation_sans_role': ('project_role_assignment', 'Affectation sans rôle',
                                  _ABSENT.format('project_role',
                                                 'x.project_id = t.project_id AND x.role_id = t.role_id')),
    }[code]
    return {**_source_table(table), 'label': label, 'where': where}


def _source(key):
    if key == 'synthese':
        return _source_synthese()
    return _source_table(key) if key in TABLES else _source_controle(key)


@ifs_data_projets_blueprint.route('', methods=['GET'])
@jwt_required()
def liste():
    return lister(ONGLETS, _source, SYNC_KEY)


@ifs_data_projets_blueprint.route('/export.xlsx', methods=['GET'])
@jwt_required()
def export():
    return exporter(ONGLETS, _source, 'projets_ifs')


def _service_asap():
    from services.sharepoint_service import SharePointService
    return SharePointService()


def _importer_asap(cle, _utilisateur):
    """Recharge depuis ASAP (SharePoint) les listes lues par les procedures du module, etats d'avancement compris
    (les activites viennent de clean_data.v_portes_detail). Un import rate arrete tout : le module repartirait
    sinon sur les anciennes donnees en affichant un succes."""
    service = _service_asap()
    etapes = [('Import des projets ASAP', service.import_projets_from_sharepoint, 5),
              ('Import des utilisateurs ASAP', service.import_users_from_sharepoint, 15),
              ('Import des projets à reprendre', service.import_projets_a_reprendre, 25),
              ("Import des états d'avancement ASAP", service.import_all_etats_avancement, 35)]
    for libelle, importer, progression in etapes:
        _write_status(cle, step=libelle, progress=progression)
        resultat = importer()
        # db_saved : ces imports repondent success=True quand seule l'ecriture en base a echoue
        if not resultat.get('success') or resultat.get('db_saved') is False:
            detail = resultat.get('error') or '; '.join(map(str, resultat.get('errors') or [])) or 'rien enregistré'
            raise RuntimeError(f'{libelle} : {detail}')
    _write_status(cle, step='Calcul du module ETL projets', progress=90)


lancer_sync = routes_sync(ifs_data_projets_blueprint, SYNC_KEY, 'etl_project.py',
                          'SELECT count(*) FROM clean_data.project_base', avant_module=_importer_asap)
