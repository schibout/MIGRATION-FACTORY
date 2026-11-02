"""Ecrans Ressources (/ressources/*) : liste filtrable, modification, creation,
suppression et import des 6 fichiers du module ressources de maintenance, sur le
modele de Maintenance > Equipements. Une configuration par fichier (TABLES).

On edite les SOURCES raw_data.<table> (fichiers, pas des tables SAP) : les procedures
clean_data.populate_* vident clean_data.<table> (TRUNCATE) avant de la recharger,
donc une saisie dans clean_data serait perdue au prochain chargement. « Recalculer »
rejoue clean_data.populate_all_tables() (tout le module, dans l'ordre des FK).
Seules les colonnes _db sont exposees (regle des couples <col>/<col>_db).

  GET    /api/v1/resource-files/<fichier>                liste paginee
  GET    /api/v1/resource-files/<fichier>/facettes       compteurs + description de l'ecran
  GET    /api/v1/resource-files/<fichier>/export.xlsx    selection filtree (reimportable)
  POST   /api/v1/resource-files/<fichier>                creation
  PUT    /api/v1/resource-files/<fichier>/<id>           modification (id = cle, '~' si composee)
  DELETE /api/v1/resource-files/<fichier>/<id>           suppression (409 si referencee)
  POST   /api/v1/resource-files/<fichier>/import         xlsx / csv : mise a jour par cle
                                                         (sinon cle naturelle), ajout sinon
  POST   /api/v1/resource-files/recalculer               CALL clean_data.populate_all_tables()
"""
import csv
import io
from datetime import date, datetime
from decimal import Decimal, InvalidOperation

from flask import Blueprint, abort, jsonify, request
from flask_jwt_extended import jwt_required
from sqlalchemy import text

from models import db

resource_files_blueprint = Blueprint('resource_files', __name__)

VIDE = '__vide__'
BOOL, NUM, TXT, DATE = 'bool', 'num', 'txt', 'date'
TYPES_RESSOURCE = ['PERSON', 'PERSON_GROUP', 'EQUIPMENT']
OUI_NON = ['Yes', 'No']


def champ(label, theme, typ=TXT, options=None, ref=None, obligatoire=False):
    return {'label': label, 'theme': theme, 'type': typ, 'options': options, 'ref': ref, 'obligatoire': obligatoire}


# Cibles des colonnes de reference : (table raw_data, colonne, libelle)
REFS = {
    'ressource': ('resource_detail_file', 'resource_seq', 'Ressource'),
    'connexion': ('resource_connection', 'resource_connection_seq', 'Connexion'),
}

# Statut de la personne IFS (resource_id des PERSON resolu par raw_data.find_person_id)
PERSONNE_SQL = """CASE WHEN r.resource_type_db IS DISTINCT FROM 'PERSON' THEN 'SANS_OBJET'
                       WHEN r.personne_trouvee IS NULL THEN 'NON_TROUVEE' ELSE 'TROUVEE' END"""
PERSONNE = {'label': 'Personne IFS', 'statuts': {
    'TROUVEE': ('Trouvée', 'success'), 'NON_TROUVEE': ('Non trouvée', 'error'), 'SANS_OBJET': ('—', 'default')}}
PERSONNE_LIBELLES = {'TROUVEE': 'Personne IFS trouvée', 'NON_TROUVEE': 'Personne IFS non trouvée',
                     'SANS_OBJET': 'Pas une personne'}
TYPE_LIBELLES = {'PERSON': 'Personne', 'PERSON_GROUP': 'Groupe de personnes', 'EQUIPMENT': 'Équipement'}

# Libelle d'une ressource du fichier detail : « resource_id — description »
def _lib(alias):
    return f"NULLIF(concat_ws(' — ', {alias}.resource_id, {alias}.description), '')"


ORGANISATION = {
    'company': champ('Société', 'Organisation'),
    'site': champ('Site', 'Organisation'),
}

TABLES = {
    'detail-file': {
        'table': 'resource_detail_file', 'cle': ['resource_seq'], 'auto': True, 'naturelle': 'resource_id',
        'titre': 'resource_id', 'sous_titre': 'description',
        'clean': 'c.resource_seq = r.resource_seq',
        'prepa': """CASE WHEN r.resource_type_db = 'PERSON' THEN COALESCE(raw_data.find_person_id(r.resource_id),
                                                                  raw_data.find_person_id(r.description)) END""",
        'recalcul': 'c.resource_id IS DISTINCT FROM COALESCE(r.personne_trouvee, r.resource_id)',
        'champs': {
            'resource_id': champ('Identifiant ressource', 'Identification', obligatoire=True),
            'description': champ('Description', 'Identification'),
            'resource_type_db': champ('Type de ressource', 'Identification', options=TYPES_RESSOURCE, obligatoire=True),
            'resource_category': champ('Catégorie', 'Identification'),
            'note': champ('Note', 'Identification'),
            'note_id': champ('N° de note', 'Identification', NUM),
            'used_in_maintenance_db': champ('Utilisée en maintenance', 'Utilisation', BOOL),
            'used_in_manufacturing_db': champ('Utilisée en production', 'Utilisation', BOOL),
            'used_in_projects_db': champ('Utilisée en projets', 'Utilisation', BOOL),
            'used_in_service_db': champ('Utilisée en service', 'Utilisation', BOOL),
            'ignore_scheduling_resource': champ('Ignorée par la planification', 'Utilisation', BOOL),
            'calendar_id': champ('Calendrier', 'Planification'),
            'use_shift_pattern_db': champ("Modèle d'équipes", 'Planification', BOOL),
            'use_hr_schedule_db': champ('Planning RH', 'Planification', BOOL),
            'sched_capacity_db': champ('Capacité planifiée', 'Planification'),
            'capacity_calc_base_db': champ('Base de calcul capacité', 'Planification'),
            'utilization': champ("Taux d'utilisation (%)", 'Planification', NUM),
            'resource_origin_db': champ('Origine', 'Origine'),
            'origin_key1': champ('Clé origine 1', 'Origine'),
            'origin_key2': champ('Clé origine 2', 'Origine'),
            'origin_key3': champ('Clé origine 3', 'Origine'),
            'origin_key4': champ('Clé origine 4', 'Origine'),
            'companies': champ('Sociétés', 'Organisation'),
            'sites': champ('Sites', 'Organisation'),
            'service_organization_id': champ('Organisation de service', 'Organisation'),
            'service_delivery_unit': champ('Unité de service', 'Organisation'),
            'manuf_group_id': champ('Groupe de production', 'Organisation'),
            'manuf_group_desc': champ('Libellé groupe de production', 'Organisation'),
            'manuf_company': champ('Société de production', 'Organisation'),
            'manuf_contract': champ('Site de production', 'Organisation'),
        },
        'calculees': {
            'resource_id_ifs': ('COALESCE(r.personne_trouvee, r.resource_id)', {'label': 'Identifiant IFS (calculé)'}),
            'personne': (PERSONNE_SQL, PERSONNE),
            'doublon': ('count(*) OVER (PARTITION BY upper(trim(r.resource_id))) > 1', None),
        },
        'facettes': {'type': ('resource_type_db', 'Type de ressource'), 'personne': ('personne', 'Personne IFS'),
                     'site': ('sites', 'Site'), 'societe': ('companies', 'Société'),
                     'calendrier': ('calendar_id', 'Calendrier'), 'origine': ('resource_origin_db', 'Origine')},
        'libelles': {'type': TYPE_LIBELLES, 'personne': PERSONNE_LIBELLES},
        'barres': ['type', 'personne'],
        'anomalies': {
            'personne_non_trouvee': ("Personne absente d'IFS", "personne = 'NON_TROUVEE'"),
            'doublon': ('Identifiant en double', 'doublon'),
            'sans_description': ('Sans description', "NULLIF(TRIM(description), '') IS NULL"),
            'sans_site': ('Sans site', "NULLIF(TRIM(sites), '') IS NULL"),
        },
        'recherche': ['resource_id', 'resource_id_ifs', 'description', 'origin_key1'],
        'essentiel': ['resource_seq', 'resource_id', 'resource_id_ifs', 'description', 'resource_type_db', 'personne',
                      'sites', 'calendar_id'],
        'defauts': {'resource_type_db': 'PERSON', 'used_in_maintenance_db': 'TRUE', 'used_in_manufacturing_db': 'FALSE',
                    'used_in_projects_db': 'FALSE', 'used_in_service_db': 'FALSE', 'use_shift_pattern_db': 'FALSE',
                    'ignore_scheduling_resource': 'FALSE', 'calendar_id': '*', 'companies': 'TRIMET', 'sites': 'SJ'},
        # FK RESTRICT de clean_data.resource_connection : le recalcul echouerait
        'utilisee_par': [('connexions', 'resource_connection', ['resource_seq', 'primary_parent_resource_seq']),
                         ('disponibilités', 'resource_availability', ['resource_seq', 'resource_parent_seq']),
                         ('parents', 'resource_parent', ['resource_seq', 'resource_parent_seq'])],
    },
    'connection': {
        'table': 'resource_connection', 'cle': ['resource_connection_seq'], 'auto': True,
        'titre': 'resource_id', 'sous_titre': 'ressource_libelle',
        'clean': 'c.resource_connection_seq = r.resource_connection_seq',
        'prepa': """CASE WHEN r.resource_type_db = 'PERSON' THEN COALESCE(raw_data.find_person_id(r.resource_id),
                                                                  raw_data.find_person_id(r.res_id)) END""",
        'recalcul': 'c.resource_id IS DISTINCT FROM COALESCE(r.personne_trouvee, r.resource_id)',
        'jointures': """LEFT JOIN raw_data.resource_detail_file d ON d.resource_seq = r.resource_seq
                        LEFT JOIN raw_data.resource_detail_file pd ON pd.resource_seq = r.primary_parent_resource_seq""",
        'champs': {
            'resource_seq': champ('N° ressource', 'Ressource', NUM, ref='ressource', obligatoire=True),
            'resource_id': champ('Identifiant ressource', 'Ressource'),
            'res_id': champ('Identifiant ressource (fichier)', 'Ressource'),
            'resource_type_db': champ('Type de ressource', 'Ressource', options=TYPES_RESSOURCE),
            'primary_parent_resource_seq': champ('N° ressource parente principale', 'Ressource', NUM, ref='ressource'),
            'parent_resource_id': champ('Identifiant ressource parente', 'Ressource'),
            'connection_type_db': champ('Type de connexion', 'Connexion'),
            **ORGANISATION,
            'employee_id': champ('N° employé', 'Connexion'),
            'org_code': champ('Code organisation', 'Connexion'),
            'calendar_id': champ('Calendrier', 'Connexion'),
            'quantity': champ('Quantité', 'Connexion', NUM),
            'sched_capacity_db': champ('Capacité planifiée', 'Planification'),
            'capacity_calc_base_db': champ('Base de calcul capacité', 'Planification'),
            'primary_scheduling_db': champ('Planification principale', 'Planification', BOOL),
        },
        'calculees': {
            'resource_id_ifs': ('COALESCE(r.personne_trouvee, r.resource_id)', {'label': 'Identifiant IFS (calculé)'}),
            'personne': (PERSONNE_SQL, PERSONNE),
            'ressource_libelle': (_lib('d'), {'label': 'Ressource'}),
            'parent_libelle': (_lib('pd'), {'label': 'Ressource parente'}),
            'ressource_inconnue': ('d.resource_seq IS NULL', None),
            'parent_inconnu': ('r.primary_parent_resource_seq IS NOT NULL AND pd.resource_seq IS NULL', None),
        },
        'facettes': {'type': ('resource_type_db', 'Type de ressource'), 'personne': ('personne', 'Personne IFS'),
                     'parent': ('primary_parent_resource_seq', 'Ressource parente', 'parent_libelle'),
                     'site': ('site', 'Site'), 'societe': ('company', 'Société'),
                     'capacite': ('capacity_calc_base_db', 'Base de calcul capacité')},
        'libelles': {'type': TYPE_LIBELLES, 'personne': PERSONNE_LIBELLES},
        'barres': ['type', 'personne'],
        'anomalies': {
            'ressource_inconnue': ('Ressource absente du fichier détail', 'ressource_inconnue'),
            'parent_inconnu': ('Parent absent du fichier détail', 'parent_inconnu'),
            'personne_non_trouvee': ("Personne absente d'IFS", "personne = 'NON_TROUVEE'"),
            'sans_parent': ('Sans ressource parente', 'primary_parent_resource_seq IS NULL'),
        },
        'recherche': ['resource_id', 'resource_id_ifs', 'res_id', 'ressource_libelle', 'parent_libelle', 'employee_id'],
        'essentiel': ['resource_connection_seq', 'resource_seq', 'ressource_libelle', 'resource_id_ifs', 'personne',
                      'resource_type_db', 'primary_parent_resource_seq', 'parent_libelle', 'site'],
        'defauts': {'resource_type_db': 'PERSON', 'company': 'TRIMET', 'site': 'SJ', 'sched_capacity_db': 'I',
                    'primary_scheduling_db': 'TRUE'},
        'utilisee_par': [('ressources de maintenance par personne', 'maint_person_resource', ['resource_connection_seq'])],
    },
    'availability': {
        'table': 'resource_availability', 'cle': ['resource_availability_seq'], 'auto': True,
        'titre': 'ressource_libelle', 'sous_titre': 'parent_libelle',
        'clean': 'c.resource_availability_seq = r.resource_availability_seq',
        'jointures': """LEFT JOIN raw_data.resource_detail_file d ON d.resource_seq = r.resource_seq
                        LEFT JOIN raw_data.resource_detail_file pd ON pd.resource_seq = r.resource_parent_seq""",
        'champs': {
            'resource_seq': champ('N° ressource', 'Ressource', NUM, ref='ressource', obligatoire=True),
            'resource_id': champ('Identifiant ressource', 'Ressource'),
            'resource_parent_seq': champ('N° ressource parente', 'Ressource', NUM, ref='ressource'),
            'resource_parent_id': champ('Identifiant ressource parente', 'Ressource'),
            **{k: champ(v['label'], 'Disponibilité') for k, v in ORGANISATION.items()},
            'start_date': champ('Date de début', 'Disponibilité', DATE),
            'end_date': champ('Date de fin', 'Disponibilité', DATE),
            'available_percentage': champ('Disponibilité (%)', 'Disponibilité', NUM),
            'efficiency': champ('Efficacité (%)', 'Disponibilité', NUM),
        },
        'calculees': {
            'ressource_libelle': (_lib('d'), {'label': 'Ressource'}),
            'parent_libelle': (_lib('pd'), {'label': 'Ressource parente'}),
            'ressource_inconnue': ('d.resource_seq IS NULL', None),
            'parent_inconnu': ('r.resource_parent_seq IS NOT NULL AND pd.resource_seq IS NULL', None),
            'periode': ("CASE WHEN r.start_date IS NULL THEN 'SANS_DATE' WHEN r.end_date < current_date THEN 'PASSEE' "
                        "WHEN r.start_date > current_date THEN 'FUTURE' ELSE 'EN_COURS' END",
                        {'label': 'Période', 'statuts': {'EN_COURS': ('En cours', 'success'), 'PASSEE': ('Passée', 'default'),
                                                         'FUTURE': ('Future', 'info'), 'SANS_DATE': ('Sans date', 'warning')}}),
        },
        'facettes': {'periode': ('periode', 'Période'),
                     'parent': ('resource_parent_seq', 'Ressource parente', 'parent_libelle'),
                     'site': ('site', 'Site'), 'societe': ('company', 'Société'),
                     'debut': ('start_date', 'Date de début')},
        'libelles': {'periode': {'EN_COURS': 'En cours', 'PASSEE': 'Passée', 'FUTURE': 'Future', 'SANS_DATE': 'Sans date'}},
        'barres': ['periode', 'parent'],
        'anomalies': {
            'ressource_inconnue': ('Ressource absente du fichier détail', 'ressource_inconnue'),
            'parent_inconnu': ('Parent absent du fichier détail', 'parent_inconnu'),
            'dates': ('Fin avant le début', 'end_date < start_date'),
            'pourcentage': ('Disponibilité hors 0-100', 'available_percentage NOT BETWEEN 0 AND 100'),
            'efficacite': ('Efficacité négative', 'efficiency < 0'),
        },
        'recherche': ['ressource_libelle', 'parent_libelle', 'resource_id', 'resource_parent_id'],
        'essentiel': ['resource_availability_seq', 'resource_seq', 'ressource_libelle', 'parent_libelle', 'start_date',
                      'end_date', 'periode', 'available_percentage', 'efficiency', 'site'],
        'defauts': {'company': 'TRIMET', 'site': 'SJ', 'efficiency': '100'},
        # CHECK de clean_data.resource_availability : refuse a la saisie plutot qu'au recalcul
        'verifs': [
            lambda l: 'La date de fin précède la date de début'
            if l.get('start_date') and l.get('end_date') and l['end_date'] < l['start_date'] else None,
            lambda l: 'La disponibilité doit être comprise entre 0 et 100'
            if l.get('available_percentage') is not None and not 0 <= l['available_percentage'] <= 100 else None,
            lambda l: "L'efficacité ne peut pas être négative"
            if l.get('efficiency') is not None and l['efficiency'] < 0 else None,
        ],
    },
    'parent': {
        'table': 'resource_parent', 'cle': ['resource_parent_seq', 'resource_seq'], 'auto': False,
        'titre': 'ressource_libelle', 'sous_titre': 'parent_libelle',
        'clean': 'c.resource_parent_seq = r.resource_parent_seq AND c.resource_seq = r.resource_seq',
        'jointures': """LEFT JOIN raw_data.resource_detail_file d ON d.resource_seq = r.resource_seq
                        LEFT JOIN raw_data.resource_detail_file pd ON pd.resource_seq = r.resource_parent_seq""",
        'champs': {
            'resource_parent_seq': champ('N° ressource parente', 'Rattachement', NUM, ref='ressource', obligatoire=True),
            'resource_seq': champ('N° ressource', 'Rattachement', NUM, ref='ressource', obligatoire=True),
            'resource_parent_id': champ('Identifiant ressource parente', 'Rattachement'),
            'resource_id': champ('Identifiant ressource', 'Rattachement'),
            'scheduling_proficiency': champ('Compétence de planification', 'Rattachement', NUM),
        },
        'calculees': {
            'ressource_libelle': (_lib('d'), {'label': 'Ressource'}),
            'parent_libelle': (_lib('pd'), {'label': 'Ressource parente'}),
            'ressource_inconnue': ('d.resource_seq IS NULL', None),
            'parent_inconnu': ('pd.resource_seq IS NULL', None),
            'type_ressource': ('d.resource_type_db', {'label': 'Type de ressource'}),
        },
        'facettes': {'parent': ('resource_parent_seq', 'Ressource parente', 'parent_libelle'),
                     'type': ('type_ressource', 'Type de ressource')},
        'libelles': {'type': TYPE_LIBELLES},
        'barres': ['parent', 'type'],
        'anomalies': {
            'ressource_inconnue': ('Ressource absente du fichier détail', 'ressource_inconnue'),
            'parent_inconnu': ('Parent absent du fichier détail', 'parent_inconnu'),
            'boucle': ('Ressource parente d\'elle-même', 'resource_seq = resource_parent_seq'),
        },
        'recherche': ['ressource_libelle', 'parent_libelle', 'resource_id', 'resource_parent_id'],
        'essentiel': ['resource_parent_seq', 'parent_libelle', 'resource_seq', 'ressource_libelle', 'type_ressource',
                      'scheduling_proficiency'],
        'defauts': {},
    },
    'maint-person': {
        'table': 'maint_person_resource', 'cle': ['maint_resource_seq'], 'auto': True,
        'titre': 'ressource_libelle', 'sous_titre': 'org_code',
        'clean': 'c.maint_resource_seq = r.maint_resource_seq',
        'jointures': """LEFT JOIN raw_data.resource_connection rc ON rc.resource_connection_seq = r.resource_connection_seq
                        LEFT JOIN raw_data.resource_detail_file d ON d.resource_seq = rc.resource_seq""",
        'champs': {
            'resource_connection_seq': champ('N° connexion', 'Ressource', NUM, ref='connexion', obligatoire=True),
            'company': champ('Société', 'Organisation'),
            'contract': champ('Site', 'Organisation'),
            'connection_type_db': champ('Type de connexion', 'Organisation', options=['SITE', 'COMPANY']),
            'org_code': champ('Code organisation', 'Organisation'),
            'primary_contract_db': champ('Site principal', 'Organisation', BOOL),
            'primary_resource_db': champ('Ressource principale', 'Organisation', BOOL),
            'avail_for_scheduling_db': champ('Disponible en planification', 'Planification', BOOL),
            'default_time_type': champ('Type de temps par défaut', 'Planification'),
            'default_travel_time_type': champ('Type de temps de trajet', 'Planification'),
            'travel_resource_group_seq': champ('Groupe de ressources trajet', 'Planification', NUM),
            'disable_operation_costs': champ('Coûts opérationnels désactivés', 'Planification', BOOL),
            'crew_time_invoicing_db': champ("Facturation du temps d'équipe", 'Planification', BOOL),
            'mob_user_db': champ('Utilisateur mobile', 'Mobilité', BOOL),
            'mob_user_type_db': champ("Type d'utilisateur mobile", 'Mobilité'),
            'disable_transfer_mobile_db': champ('Transfert mobile désactivé', 'Mobilité', BOOL),
            'secondment_company': champ('Société de détachement', 'Divers'),
            'secondment_employee': champ('Employé détaché', 'Divers'),
            'vendor_no': champ('N° fournisseur', 'Divers'),
            'filter_id': champ('Filtre', 'Divers'),
            'remark': champ('Remarque', 'Divers'),
        },
        'calculees': {
            'ressource_libelle': (_lib('d'), {'label': 'Ressource'}),
            'type_ressource': ('d.resource_type_db', {'label': 'Type de ressource'}),
            'connexion_inconnue': ('rc.resource_connection_seq IS NULL', None),
        },
        'facettes': {'site': ('contract', 'Site'), 'organisation': ('org_code', 'Code organisation'),
                     'connexion': ('connection_type_db', 'Type de connexion'),
                     'principale': ('primary_resource_db', 'Ressource principale'),
                     'type': ('type_ressource', 'Type de ressource')},
        'libelles': {'type': TYPE_LIBELLES, 'principale': {'TRUE': 'Oui', 'FALSE': 'Non'}},
        'barres': ['site', 'organisation'],
        'anomalies': {
            'connexion_inconnue': ('Connexion absente du fichier', 'connexion_inconnue'),
            'sans_organisation': ('Sans code organisation', "NULLIF(TRIM(org_code), '') IS NULL"),
        },
        'recherche': ['ressource_libelle', 'org_code', 'contract', 'vendor_no', 'remark'],
        'essentiel': ['maint_resource_seq', 'resource_connection_seq', 'ressource_libelle', 'contract',
                      'connection_type_db', 'org_code', 'primary_resource_db', 'avail_for_scheduling_db'],
        'defauts': {'company': 'TRIMET', 'contract': 'SJ', 'connection_type_db': 'SITE', 'primary_resource_db': 'TRUE',
                    'avail_for_scheduling_db': 'TRUE', 'primary_contract_db': 'TRUE', 'disable_transfer_mobile_db': 'FALSE'},
    },
    'ifs-person': {
        'table': 'ifs_person', 'cle': ['id'], 'auto': True, 'naturelle': 'person_id',
        'titre': 'person_id', 'sous_titre': 'internal_display_name',
        # clean_data.ifs_person.id est une sequence propre : rapprochement par person_id
        'clean': 'c.person_id = r.person_id', 'clean_cle': 'person_id',
        'champs': {
            'person_id': champ('Identifiant personne', 'Identité', obligatoire=True),
            'first_name': champ('Prénom', 'Identité'),
            'middle_name': champ('Deuxième prénom', 'Identité'),
            'last_name': champ('Nom', 'Identité'),
            'prefix': champ('Préfixe', 'Identité'),
            'title': champ('Civilité', 'Identité'),
            'initials': champ('Initiales', 'Identité'),
            'alias': champ('Alias', 'Identité'),
            'internal_display_name': champ('Nom affiché (interne)', 'Identité'),
            'external_display_name': champ('Nom affiché (externe)', 'Identité'),
            'currently_employed': champ('Employé actuellement', 'Situation', options=OUI_NON),
            'protected': champ('Protégée', 'Situation', options=OUI_NON),
            'have_children': champ('A des enfants', 'Situation', options=OUI_NON),
            'gender': champ('Genre', 'Situation'),
            'marital_status': champ('Situation familiale', 'Situation'),
            'date_of_birth': champ('Date de naissance', 'Situation', DATE),
            'birth_name': champ('Nom de naissance', 'Situation', DATE),
            'place_of_birth': champ('Lieu de naissance', 'Situation', DATE),
            'blood_type': champ('Groupe sanguin', 'Situation'),
            'ssn': champ('N° de sécurité sociale', 'Situation'),
        },
        'calculees': {
            # ressources du fichier detail rattachees a cette personne (apres recalcul)
            'nb_ressources': ('(SELECT count(*) FROM clean_data.resource_detail_file x WHERE x.resource_id = r.person_id)',
                              {'label': 'Ressources rattachées'}),
            'doublon': ('count(*) OVER (PARTITION BY upper(trim(r.person_id))) > 1', None),
            'utilisee': ("CASE WHEN EXISTS (SELECT 1 FROM clean_data.resource_detail_file x WHERE x.resource_id = r.person_id) "
                         "THEN 'OUI' ELSE 'NON' END", None),
        },
        'facettes': {'employe': ('currently_employed', 'Employé actuellement'),
                     'utilisee': ('utilisee', 'Rattachée à une ressource'),
                     'protegee': ('protected', 'Protégée')},
        'libelles': {'employe': {'Yes': 'Employé', 'No': 'Non employé'},
                     'utilisee': {'OUI': 'Rattachée à une ressource', 'NON': 'Sans ressource'}},
        'barres': ['employe', 'utilisee'],
        'anomalies': {
            'doublon': ('Identifiant en double', 'doublon'),
            'sans_nom': ('Sans nom', "NULLIF(TRIM(last_name), '') IS NULL"),
            'externe': ('Compte externe (EXT-)', "person_id LIKE 'EXT-%'"),
        },
        'recherche': ['person_id', 'first_name', 'last_name', 'internal_display_name', 'external_display_name'],
        'essentiel': ['id', 'person_id', 'first_name', 'last_name', 'internal_display_name', 'currently_employed',
                      'nb_ressources'],
        'defauts': {'currently_employed': 'Yes', 'protected': 'No', 'have_children': 'No'},
    },
}


def _cfg(fichier):
    cfg = TABLES.get(fichier)
    if not cfg:
        abort(404)
    return cfg


def _base(cfg):
    """CTE base : ligne du fichier + colonnes calculees + a_recalculer."""
    calc = ''.join(f',\n           {sql} AS {col}' for col, (sql, _) in cfg.get('calculees', {}).items())
    recalcul = f" OR {cfg['recalcul']}" if cfg.get('recalcul') else ''
    # MATERIALIZED : find_person_id n'est appelee qu'une fois par ligne
    return f"""
WITH r AS MATERIALIZED (
    SELECT r.*, {cfg.get('prepa', 'NULL::text')} AS personne_trouvee FROM raw_data.{cfg['table']} r
), base AS (
    SELECT r.*{calc},
           array_to_string(ARRAY[{', '.join(f'r.{k}::text' for k in cfg['cle'])}], '~') AS _id,
           (c.{cfg.get('clean_cle', cfg['cle'][0])} IS NULL
            OR r.updated_at > c.loaded_at{recalcul}) IS TRUE AS a_recalculer
      FROM r
      -- LATERAL LIMIT 1 : une cle de rapprochement en double (person_id) ne doit pas multiplier les lignes
      LEFT JOIN LATERAL (SELECT * FROM clean_data.{cfg['table']} c WHERE {cfg['clean']} LIMIT 1) c ON TRUE
      {cfg.get('jointures', '')}
)
"""


def _anomalies(cfg):
    return {**cfg['anomalies'], 'a_recalculer': ('Modifiée, à recalculer', 'a_recalculer')}


def _filtres(cfg, sauf=None):
    where, params = [], {}
    search = (request.args.get('search') or '').strip()
    if search:
        cols = [*cfg['recherche'], *[f'{k}::text' for k in cfg['cle']]]
        where.append('(' + ' OR '.join(f'{c} ILIKE :s' for c in cols) + ')')
        params['s'] = f'%{search}%'
    for cle, (col, *_) in cfg['facettes'].items():
        brut = request.args.get(cle)
        if cle == sauf or not brut:
            continue
        valeurs = [v for v in brut.split(',') if v]
        autres = [v for v in valeurs if v != VIDE]
        conds = []
        if VIDE in valeurs:
            conds.append(f'{col} IS NULL')
        if autres:
            conds.append(f'{col}::text = ANY(:f_{cle})')
            params[f'f_{cle}'] = autres
        where.append('(' + ' OR '.join(conds) + ')')
    anomalies = _anomalies(cfg)
    anomalie = request.args.get('anomalie')
    if anomalie == 'toutes':
        where.append('(' + ' OR '.join(f'({sql})' for k, (_, sql) in anomalies.items() if k != 'a_recalculer') + ')')
    elif anomalie in anomalies:
        where.append(f'({anomalies[anomalie][1]})')
    return ('WHERE ' + ' AND '.join(where)) if where else '', params


def _flags(cfg):
    return ', '.join(f'({sql}) IS TRUE AS _a_{k}' for k, (_, sql) in _anomalies(cfg).items())


def _json(v):
    if isinstance(v, Decimal):
        return int(v) if v == v.to_integral_value() else float(v)
    if isinstance(v, (date, datetime)):
        return v.isoformat()[:10]
    return v


def _ligne(r):
    d = {}
    anomalies = []
    for k, v in dict(r).items():
        if k.startswith('_a_'):
            if v and k != '_a_a_recalculer':
                anomalies.append(k[3:])
        elif k not in ('total_lignes', 'personne_trouvee'):
            d[k] = _json(v)
    d['anomalies'] = anomalies
    return d


@resource_files_blueprint.route('/<fichier>', methods=['GET'])
@jwt_required()
def liste(fichier):
    cfg = _cfg(fichier)
    page = max(int(request.args.get('page', 1)), 1)
    page_size = min(max(int(request.args.get('page_size', 50)), 1), 500)
    clause, params = _filtres(cfg)
    tri_ok = [*cfg['cle'], *cfg['champs'], *[c for c, (_, m) in cfg.get('calculees', {}).items() if m]]
    tri = request.args.get('sort') if request.args.get('sort') in tri_ok else cfg['cle'][0]
    sens = 'DESC' if request.args.get('dir') == 'desc' else 'ASC'
    rows = db.session.execute(text(
        f'{_base(cfg)} SELECT *, {_flags(cfg)}, count(*) OVER () AS total_lignes FROM base {clause} '
        f"ORDER BY {tri} {sens} NULLS LAST, {', '.join(cfg['cle'])} LIMIT :limit OFFSET :offset"),
        {**params, 'limit': page_size, 'offset': (page - 1) * page_size}).mappings().all()
    return jsonify({'rows': [_ligne(r) for r in rows], 'total': rows[0]['total_lignes'] if rows else 0})


def _description(cfg):
    """Ce que la page affiche : champs saisissables, colonnes calculees, facettes en barre..."""
    cles = [] if not cfg['auto'] else [
        {'col': k, 'label': 'N°', 'theme': 'Identification', 'type': NUM} for k in cfg['cle']]
    calculees = [{'col': c, 'label': m['label'], 'theme': 'Calculé', 'type': 'statut' if m.get('statuts') else TXT,
                  'statuts': {k: {'libelle': l, 'couleur': co} for k, (l, co) in (m.get('statuts') or {}).items()}}
                 for c, (_, m) in cfg.get('calculees', {}).items() if m]
    return {
        'cle': cfg['cle'], 'auto': cfg['auto'], 'titre': cfg['titre'], 'sous_titre': cfg['sous_titre'],
        'champs': [{'col': c, **m, 'ref': REFS[m['ref']][2] if m['ref'] else None} for c, m in cfg['champs'].items()],
        'colonnes': [*cles, *calculees],
        'barres': cfg['barres'], 'essentiel': cfg['essentiel'], 'defauts': cfg['defauts'],
    }


@resource_files_blueprint.route('/<fichier>/facettes', methods=['GET'])
@jwt_required()
def facettes(fichier):
    cfg = _cfg(fichier)
    db.session.execute(text(f'CREATE TEMP TABLE rf_tmp ON COMMIT DROP AS {_base(cfg)} SELECT * FROM base'))
    resultat = {}
    for cle, (col, titre, *lib) in cfg['facettes'].items():
        clause, params = _filtres(cfg, sauf=cle)
        libelles = cfg.get('libelles', {}).get(cle, {})
        sql = (f"SELECT {col}::text AS code, {f'max({lib[0]})' if lib else 'NULL'} AS libelle, count(*) AS nb "
               f'FROM rf_tmp {clause} GROUP BY 1 ORDER BY 3 DESC, 1')
        resultat[cle] = {'titre': titre, 'valeurs': [
            {'code': r['code'] if r['code'] is not None else VIDE,
             'libelle': libelles.get(r['code']) or r['libelle'], 'nb': r['nb']}
            for r in db.session.execute(text(sql), params).mappings()]}
    clause, params = _filtres(cfg)
    anomalies = _anomalies(cfg)
    compteurs = db.session.execute(text(
        'SELECT count(*) AS total, '
        + ', '.join(f'count(*) FILTER (WHERE {sql}) AS {k}' for k, (_, sql) in anomalies.items())
        + ', count(*) FILTER (WHERE ' + ' OR '.join(f'({s})' for k, (_, s) in anomalies.items() if k != 'a_recalculer')
        + f') AS toutes FROM rf_tmp {clause}'), params).mappings().one()
    total_general, a_recalculer = db.session.execute(text(
        'SELECT count(*), count(*) FILTER (WHERE a_recalculer) FROM rf_tmp')).one()
    # Lignes supprimees de la source mais encore presentes dans clean_data
    supprimees = db.session.execute(text(
        f"SELECT count(*) FROM clean_data.{cfg['table']} c WHERE NOT EXISTS "
        f"(SELECT 1 FROM raw_data.{cfg['table']} r WHERE {cfg['clean']})")).scalar()
    db.session.commit()
    return jsonify({
        'facettes': resultat,
        'total': compteurs['total'],
        'total_general': total_general,
        'anomalies': [{'cle': k, 'libelle': lib, 'nb': compteurs[k]} for k, (lib, _) in anomalies.items()],
        'anomalies_total': compteurs['toutes'],
        'a_recalculer': a_recalculer + supprimees,
        **_description(cfg),
    })


def _entetes(cfg):
    cles = [(k, 'N°' if cfg['auto'] else cfg['champs'][k]['label']) for k in cfg['cle']]
    champs = [(c, m['label']) for c, m in cfg['champs'].items() if c not in cfg['cle']]
    calculees = [(c, f"{m['label']} (calculé)") for c, (_, m) in cfg.get('calculees', {}).items() if m]
    return [*cles, *champs, *calculees, ('anomalies', 'Anomalies (calculé)')]


@resource_files_blueprint.route('/<fichier>/export.xlsx', methods=['GET'])
@jwt_required()
def export_excel(fichier):
    from openpyxl import Workbook

    from api.finance import _envoyer, _feuille_tableau

    cfg = _cfg(fichier)
    clause, params = _filtres(cfg)
    rows = db.session.execute(text(f"{_base(cfg)} SELECT *, {_flags(cfg)} FROM base {clause} "
                                   f"ORDER BY {', '.join(cfg['cle'])}"), params).mappings().all()
    db.session.commit()
    entetes = _entetes(cfg)
    libelles = {k: lib for k, (lib, _) in _anomalies(cfg).items()}
    statuts = {c: dict((k, l) for k, (l, _) in (m.get('statuts') or {}).items())
               for c, (_, m) in cfg.get('calculees', {}).items() if m}
    lignes = []
    for r in rows:
        d = dict(r)
        d['anomalies'] = ', '.join(libelles[k[3:]] for k, v in d.items() if k.startswith('_a_') and v)
        lignes.append([statuts.get(c, {}).get(d.get(c), d.get(c)) for c, _ in entetes])
    numeriques = {c for c, m in cfg['champs'].items() if m['type'] == NUM} | set(cfg['cle'])
    wb = Workbook()
    _feuille_tableau(wb.active, 'Ressources', entetes, lignes, numeriques)
    return _envoyer(wb, cfg['table'])


# ---------------------------------------------------------------------------
# Ecriture
# ---------------------------------------------------------------------------
def _valeur(cfg, col, v):
    """Valeur saisie -> valeur stockee ; ValueError avec un message lisible."""
    if v is None or (isinstance(v, str) and not v.strip()):
        return None
    m = cfg['champs'][col]
    if isinstance(v, bool):
        v = 'TRUE' if v else 'FALSE'
    if m['type'] == NUM:
        try:
            return Decimal(str(v).strip().replace(',', '.').replace(' ', '').replace(' ', ''))
        except InvalidOperation:
            raise ValueError(f"{m['label']} : « {v} » n'est pas un nombre")
    if m['type'] == DATE:
        if isinstance(v, datetime):
            return v.date()
        if isinstance(v, date):
            return v
        s = str(v).strip()[:10]
        for fmt in ('%Y-%m-%d', '%d/%m/%Y'):
            try:
                return datetime.strptime(s, fmt).date()
            except ValueError:
                pass
        raise ValueError(f"{m['label']} : « {v} » n'est pas une date (JJ/MM/AAAA)")
    s = str(v).strip()
    if m['type'] == BOOL:
        b = s.upper()
        b = {'VRAI': 'TRUE', 'OUI': 'TRUE', '1': 'TRUE', 'FAUX': 'FALSE', 'NON': 'FALSE', '0': 'FALSE'}.get(b, b)
        if b not in ('TRUE', 'FALSE'):
            raise ValueError(f"{m['label']} : « {v} » n'est pas TRUE / FALSE")
        return b
    if m['options']:
        trouve = next((o for o in m['options'] if o.upper() == s.upper()), None)
        if trouve is None:
            raise ValueError(f"{m['label']} : « {v} » inconnu ({', '.join(m['options'])})")
        return trouve
    return s


def _entier(v, label='N°'):
    try:
        n = Decimal(str(v).strip())
    except InvalidOperation:
        raise ValueError(f'{label} « {v} » invalide')
    if n != n.to_integral_value() or n <= 0:
        raise ValueError(f'{label} « {v} » invalide')
    return n


def _id(cfg, brut):
    morceaux = str(brut).split('~')
    if len(morceaux) != len(cfg['cle']):
        raise ValueError('Identifiant invalide')
    return {k: _entier(v) for k, v in zip(cfg['cle'], morceaux)}


def _where(cfg, prefixe='k_'):
    return ' AND '.join(f'{k} = :{prefixe}{k}' for k in cfg['cle'])


def _existante(cfg, cle):
    r = db.session.execute(text(f"SELECT * FROM raw_data.{cfg['table']} WHERE {_where(cfg)}"),
                           {f'k_{k}': v for k, v in cle.items()}).mappings().first()
    return dict(r) if r else None


def _controle(cfg, ligne, cle_avant):
    """Ligne complete (existante + saisie) -> message d'erreur ou None."""
    for c, m in cfg['champs'].items():
        if m['obligatoire'] and ligne.get(c) in (None, ''):
            return f"{m['label']} : valeur obligatoire"
    for c, m in cfg['champs'].items():
        if m['ref'] and ligne.get(c) is not None:
            table, col, lib = REFS[m['ref']]
            if not db.session.execute(text(f'SELECT 1 FROM raw_data.{table} WHERE {col} = :v'), {'v': ligne[c]}).scalar():
                return f"{m['label']} : {lib.lower()} n° {_json(ligne[c])} inconnue"
    nat = cfg.get('naturelle')
    if nat and ligne.get(nat):
        autre = db.session.execute(text(
            f"SELECT {cfg['cle'][0]} FROM raw_data.{cfg['table']} WHERE upper(trim({nat})) = upper(:v) "
            f"AND NOT ({_where(cfg)}) LIMIT 1"),
            {'v': ligne[nat], **{f'k_{k}': (cle_avant or {}).get(k, -1) for k in cfg['cle']}}).scalar()
        if autre is not None:
            return f"{cfg['champs'][nat]['label']} {ligne[nat]} déjà porté par la ligne n° {_json(autre)}"
    for verif in cfg.get('verifs', []):
        probleme = verif(ligne)
        if probleme:
            return probleme
    return None


def _ecrire(cfg, cle_avant, valeurs, source=None):
    """UPDATE de la ligne cle_avant, INSERT si cle_avant est None. valeurs peut porter la cle."""
    p = {**{f'v_{c}': v for c, v in valeurs.items()}, 'src': source}
    if cle_avant:
        p.update({f'k_{k}': v for k, v in cle_avant.items()})
        sets = ''.join(f'{c} = :v_{c}, ' for c in valeurs)
        db.session.execute(text(f"UPDATE raw_data.{cfg['table']} SET {sets}updated_at = now(), "
                                f"source_file = COALESCE(:src, source_file) WHERE {_where(cfg)}"), p)
        return
    cols = list(valeurs)
    db.session.execute(text(
        f"INSERT INTO raw_data.{cfg['table']} ({', '.join(cols + ['source_file'])}) "
        f"VALUES ({', '.join(f':v_{c}' for c in cols)}, :src)"), {**p, 'src': source or 'ECRAN'})


def _prochain(cfg):
    return db.session.execute(text(
        f"SELECT COALESCE(max({cfg['cle'][0]}), 0) + 1 FROM raw_data.{cfg['table']}")).scalar()


def _corps(cfg):
    data = request.get_json(silent=True) or {}
    return {c: _valeur(cfg, c, data[c]) for c in cfg['champs'] if c in data}


def _conflit_cle(cfg, cle, cle_avant=None):
    if cle != cle_avant and _existante(cfg, cle):
        return 'Une ligne porte déjà cette clé (' + ', '.join(f'{k} = {_json(v)}' for k, v in cle.items()) + ')'
    return None


@resource_files_blueprint.route('/<fichier>', methods=['POST'])
@jwt_required()
def creer(fichier):
    cfg = _cfg(fichier)
    try:
        valeurs = _corps(cfg)
        if cfg['auto']:
            valeurs[cfg['cle'][0]] = _prochain(cfg)
        cle = {k: valeurs.get(k) for k in cfg['cle']}
        if any(v is None for v in cle.values()):
            raise ValueError('La clé est obligatoire')
    except ValueError as e:
        return jsonify({'error': str(e)}), 400
    probleme = _conflit_cle(cfg, cle) or _controle(cfg, valeurs, None)
    if probleme:
        return jsonify({'error': probleme}), 409
    _ecrire(cfg, None, valeurs)
    db.session.commit()
    return jsonify({'_id': '~'.join(str(_json(v)) for v in cle.values())}), 201


@resource_files_blueprint.route('/<fichier>/<ident>', methods=['PUT'])
@jwt_required()
def modifier(fichier, ident):
    cfg = _cfg(fichier)
    try:
        cle_avant = _id(cfg, ident)
        valeurs = _corps(cfg)
    except ValueError as e:
        return jsonify({'error': str(e)}), 400
    existante = _existante(cfg, cle_avant)
    if not existante:
        return jsonify({'error': 'Ligne introuvable'}), 404
    ligne = {**existante, **valeurs}
    cle = {k: ligne.get(k) for k in cfg['cle']}
    probleme = _conflit_cle(cfg, cle, cle_avant) or _controle(cfg, ligne, cle_avant)
    if probleme:
        return jsonify({'error': probleme}), 409
    if valeurs:
        _ecrire(cfg, cle_avant, valeurs)
    db.session.commit()
    return jsonify({'_id': '~'.join(str(_json(v)) for v in cle.values())})


@resource_files_blueprint.route('/<fichier>/<ident>', methods=['DELETE'])
@jwt_required()
def supprimer(fichier, ident):
    cfg = _cfg(fichier)
    try:
        cle = _id(cfg, ident)
    except ValueError as e:
        return jsonify({'error': str(e)}), 400
    # Lignes des autres fichiers qui citent celle-ci : la supprimer ferait echouer le recalcul
    utilisee = [lib for lib, table, cols in cfg.get('utilisee_par', [])
                if db.session.execute(text(f"SELECT 1 FROM raw_data.{table} WHERE :v IN ({', '.join(cols)}) LIMIT 1"),
                                      {'v': cle[cfg['cle'][0]]}).scalar()]
    if utilisee:
        return jsonify({'error': f"Ligne utilisée dans : {', '.join(utilisee)}. Retirez-la d'abord de ces fichiers."}), 409
    n = db.session.execute(text(f"DELETE FROM raw_data.{cfg['table']} WHERE {_where(cfg)}"),
                           {f'k_{k}': v for k, v in cle.items()}).rowcount
    db.session.commit()
    return (jsonify({'ok': True}), 200) if n else (jsonify({'error': 'Ligne introuvable'}), 404)


# ---------------------------------------------------------------------------
# Import
# ---------------------------------------------------------------------------
def _norm(s):
    return ' '.join(str(s or '').strip().lower().split())


def lire_fichier(nom, contenu):
    """-> liste de lignes (listes de cellules), en-tete comprise."""
    if nom.lower().endswith(('.xlsx', '.xlsm')):
        from openpyxl import load_workbook
        ws = load_workbook(io.BytesIO(contenu), read_only=True, data_only=True).worksheets[0]
        return [list(r) for r in ws.iter_rows(values_only=True)]
    if nom.lower().endswith('.csv'):
        try:
            texte = contenu.decode('utf-8-sig')
        except UnicodeDecodeError:
            texte = contenu.decode('cp1252')
        premiere = texte.split('\n', 1)[0]
        sep = ';' if premiere.count(';') >= premiere.count(',') else ','
        return list(csv.reader(io.StringIO(texte), delimiter=sep))
    raise ValueError('Format non supporté : fichier .xlsx ou .csv attendu')


def preparer_import(cfg, lignes):
    """Lignes du fichier -> (colonnes reconnues, [(n° ligne, cle ou None, valeurs)], erreurs).
    En-tete accepte : nom technique ou libelle de l'export (l'export est reimportable)."""
    if not lignes:
        raise ValueError('Fichier vide')
    par_entete = {_norm(c): c for c in [*cfg['cle'], *cfg['champs']]}
    par_entete.update({_norm(l): c for c, l in _entetes(cfg) if c in cfg['cle'] or c in cfg['champs']})
    entetes = [par_entete.get(_norm(h)) for h in lignes[0]]
    cle_lue = all(k in entetes for k in cfg['cle'])
    nat = cfg.get('naturelle')
    if not cle_lue and not (nat and nat in entetes):
        attendu = ' + '.join(_entetes(cfg)[i][1] for i in range(len(cfg['cle'])))
        raise ValueError(f'Colonne(s) clé introuvable(s) : {attendu}'
                         + (f" ou {cfg['champs'][nat]['label']}" if nat else ''))
    reconnues = [c for c in dict.fromkeys(entetes) if c in cfg['champs']]
    a_ecrire, erreurs = [], []
    for i, cellules in enumerate(lignes[1:], start=2):
        if all(v is None or str(v).strip() == '' for v in cellules):
            continue
        brut = {c: v for c, v in zip(entetes, cellules) if c}
        try:
            cle = None
            if cle_lue and all(str(brut.get(k) or '').strip() for k in cfg['cle']):
                cle = {k: _entier(brut[k]) for k in cfg['cle']}
            valeurs = {c: _valeur(cfg, c, brut.get(c)) for c in reconnues}
            if cle is None and not (nat and valeurs.get(nat)) and not cfg['auto']:
                raise ValueError('clé absente')
            a_ecrire.append((i, cle, valeurs))
        except ValueError as e:
            erreurs.append({'ligne': i, 'message': str(e)})
    if not a_ecrire and not erreurs:
        raise ValueError('Aucune ligne de données')
    return reconnues, a_ecrire, erreurs


@resource_files_blueprint.route('/<fichier>/import', methods=['POST'])
@jwt_required()
def importer(fichier):
    cfg = _cfg(fichier)
    f = request.files.get('file')
    if not f:
        return jsonify({'error': 'Aucun fichier reçu'}), 400
    try:
        colonnes, a_ecrire, erreurs = preparer_import(cfg, lire_fichier(f.filename or '', f.read()))
    except ValueError as e:
        return jsonify({'error': str(e)}), 400
    stats = {'inserees': 0, 'modifiees': 0}
    # Tout ou rien : une erreur sur une ligne annule l'import du fichier
    db.session.execute(text(f"LOCK TABLE raw_data.{cfg['table']} IN SHARE ROW EXCLUSIVE MODE"))
    prochain = _prochain(cfg) if cfg['auto'] else None
    nat = cfg.get('naturelle')
    vues = set()
    for ligne, cle, valeurs in a_ecrire:
        if cle is None and nat and valeurs.get(nat):
            trouve = db.session.execute(text(
                f"SELECT {cfg['cle'][0]} FROM raw_data.{cfg['table']} WHERE upper(trim({nat})) = upper(:v) "
                f"ORDER BY 1 LIMIT 1"), {'v': valeurs[nat]}).scalar()
            cle = {cfg['cle'][0]: trouve} if trouve is not None else None
        existante = _existante(cfg, cle) if cle else None
        if cle is None:
            cle = {cfg['cle'][0]: prochain}
        if cfg['auto'] and cle[cfg['cle'][0]] >= prochain:
            prochain = cle[cfg['cle'][0]] + 1
        marque = tuple(cle.values())
        if marque in vues:
            erreurs.append({'ligne': ligne, 'message': 'même ligne présente deux fois dans le fichier'})
            continue
        vues.add(marque)
        complete = {**(existante or {}), **valeurs, **cle}
        probleme = _controle(cfg, complete, cle if existante else None)
        if probleme:
            erreurs.append({'ligne': ligne, 'message': probleme})
            continue
        if existante:
            _ecrire(cfg, cle, valeurs, source=f.filename)
            stats['modifiees'] += 1
        else:
            _ecrire(cfg, None, {**valeurs, **cle}, source=f.filename)
            stats['inserees'] += 1
    if erreurs:
        db.session.rollback()
        return jsonify({'error': f'{len(erreurs)} ligne(s) en erreur : fichier non importé',
                        'erreurs': sorted(erreurs, key=lambda e: e['ligne'])[:200]}), 400
    db.session.commit()
    return jsonify({**stats, 'colonnes': [cfg['champs'][c]['label'] for c in colonnes]})


@resource_files_blueprint.route('/recalculer', methods=['POST'])
@jwt_required()
def recalculer():
    try:
        db.session.execute(text('CALL clean_data.populate_all_tables()'))
        db.session.commit()
    except Exception as e:
        db.session.rollback()
        return jsonify({'error': f'Recalcul impossible : {e}'}), 500
    return jsonify({t['table']: db.session.execute(text(f"SELECT count(*) FROM clean_data.{t['table']}")).scalar()
                    for t in TABLES.values()})
