"""Tableau de bord : etat reel de la migration.

  GET  /api/v1/dashboard                      synthese ; relance les controles si la mesure a plus d'une heure
  POST /api/v1/dashboard/recalculer           lance le calcul des controles (202, ou 409 si deja en cours)
  GET  /api/v1/dashboard/historique/<ecran>   courbes des principaux controles d'un domaine

Les controles sont ceux des ecrans Donnees IFS (CONTROLES et _source de chaque module) : un controle ajoute a un
ecran apparait ici sans autre changement. Trop lents pour une requete (18 s), ils sont calcules dans un thread et
stockes dans public.dashboard_control_history, a la fois cache et historique.
"""
import logging
import threading

from flask import Blueprint, current_app, jsonify
from sqlalchemy import text

from models import db
from services.dashboard_synthese import mois_glissants, series_controles, statut_extraction, synthese
from utils.auth_decorators import require_permission

from . import (ifs_data_articles, ifs_data_clients, ifs_data_operations, ifs_data_pm_actions, ifs_data_projets,
               ifs_data_ressources, ifs_data_structure, ifs_fournisseurs)
from .finance import _json
from .ifs_consultation import filtre
from .sap_articles import q

dashboard_blueprint = Blueprint('dashboard', __name__)
logger = logging.getLogger(__name__)

# 778812 est le verrou du module Maintenance. Verrou de transaction : libere meme si le worker meurt.
VERROU_CALCUL = 778813
HISTORIQUE_JOURS = 90


def _domaine(cle, label, categorie, url, modules, ecran=None):
    return {'cle': cle, 'label': label, 'categorie': categorie, 'url': url, 'modules': modules, 'ecran': ecran}


DOMAINES = [
    _domaine('fournisseurs', 'Fournisseurs', 'supplier', '/ifs-data/fournisseurs?onglet=controles',
             ['etl_supplier_base.py'], ifs_fournisseurs),
    _domaine('clients', 'Clients', 'customer', '/ifs-data/clients?onglet=controles',
             ['etl_file_customer.py', 'etl_customer.py', 'etl_phl_customer.py'], ifs_data_clients),
    _domaine('articles', 'Articles', 'inventory', '/ifs-data/articles?onglet=controles',
             ['etl_article_sap.py', 'etl_inventory_part.py', 'etl_phl_article.py', 'etl_composant_article.py'],
             ifs_data_articles),
    _domaine('structure', 'Structure maintenance', 'Structure Maintenance', '/ifs-data/structure?onglet=controles',
             ['etl_equipment_functional.py'], ifs_data_structure),
    _domaine('projets', 'Projets', 'project', '/ifs-data/projets?onglet=controles', ['etl_project.py'],
             ifs_data_projets),
    _domaine('pm_actions', 'PM Actions', 'PM Action', '/ifs-data/pm-actions?onglet=controles', ['etl_pm_action.py'],
             ifs_data_pm_actions),
    _domaine('operations', 'Opérations', 'Operation', '/ifs-data/operations?onglet=controles', ['etl_operation.py'],
             ifs_data_operations),
    _domaine('ressources', 'Ressources', 'maintenance', '/ifs-data/maintenance-ressources?onglet=controles',
             ['etl_maintenance_resource.py'], ifs_data_ressources),
    _domaine('commandes', "Commandes d'achat", 'Commande Achat', '/finance/commandes-achat', ['etl_commande_achat.py']),
    _domaine('immobilisations', 'Immobilisations', 'Immobilisation', '/finance/immobilisations',
             ['etl_immobilisation.py']),
]
_AVEC_CONTROLES = [d for d in DOMAINES if d['ecran']]


def _mesurer(conn, domaine, code):
    """Une mesure ; un controle en panne donne NULL (savepoint) et n'interrompt pas les autres."""
    label = code
    try:
        src = domaine['ecran']._source(code)
        label = src['label']
        corps, params = filtre(src, '')
        with conn.begin_nested():
            anomalies = conn.execute(text(f'SELECT count(*) FROM {corps}'), params).scalar()
    except Exception as e:
        logger.error(f"Controle {domaine['cle']}/{code} non calculable : {e}")
        anomalies = None
    return {'ecran': domaine['cle'], 'code': code, 'label': label, 'anomalies': anomalies}


def _calculer(app):
    with app.app_context():
        try:
            with db.engine.begin() as conn:
                if not conn.execute(text('SELECT pg_try_advisory_xact_lock(:v)'), {'v': VERROU_CALCUL}).scalar():
                    return  # un autre worker calcule deja
                mesures = [_mesurer(conn, d, c) for d in _AVEC_CONTROLES for c in d['ecran'].CONTROLES]
                conn.execute(text(
                    'INSERT INTO public.dashboard_control_history (jour, ecran, code, label, anomalies) '
                    'VALUES (CURRENT_DATE, :ecran, :code, :label, :anomalies) '
                    'ON CONFLICT (jour, ecran, code) DO UPDATE SET label = EXCLUDED.label, '
                    'anomalies = EXCLUDED.anomalies, calculated_at = now()'), mesures)
        except Exception as e:  # le thread ne doit jamais mourir en silence
            logger.error(f'Calcul des controles du tableau de bord en echec : {e}')
        finally:
            db.session.remove()


def _lancer_calcul():
    threading.Thread(target=_calculer, args=(current_app._get_current_object(),), daemon=True,
                     name='dashboard-controles').start()


def _calcul_en_cours():
    return db.session.execute(text(
        f"SELECT EXISTS (SELECT 1 FROM pg_locks WHERE locktype = 'advisory' AND classid = 0 "
        f'AND objid = {VERROU_CALCUL} AND objsubid = 1 AND granted '
        f'AND database = (SELECT oid FROM pg_database WHERE datname = current_database()))')).scalar()


def _mesures():
    return [dict(r) for r in db.session.execute(text(
        'SELECT jour, ecran, code, label, anomalies FROM public.dashboard_control_history '
        'WHERE jour >= CURRENT_DATE - :j ORDER BY jour, ecran, code'), {'j': HISTORIQUE_JOURS}).mappings()]


def _volumes():
    """{categorie: (tables, tables remplies, lignes)} des tables d'export actives, en comptage exact."""
    tables = db.session.execute(text(
        'SELECT e.category, e.table_schema, i.table_name FROM public.etl_export_queries e '
        'LEFT JOIN information_schema.tables i ON i.table_schema = e.table_schema '
        '  AND lower(i.table_name) = lower(e.table_name) WHERE e.is_active ORDER BY e.id')).all()
    existantes = [t for t in tables if t.table_name]
    comptes = {}
    if existantes:
        # Noms lus dans information_schema, jamais dans la requete HTTP
        union = ' UNION ALL '.join(
            f'SELECT {i} AS i, count(*) AS n FROM {q(t.table_schema)}.{q(t.table_name)}'
            for i, t in enumerate(existantes))
        comptes = {existantes[r.i]: r.n for r in db.session.execute(text(union))}
    volumes = {}
    for t in tables:
        v = volumes.setdefault(t.category, [0, 0, 0])
        n = comptes.get(t, 0)
        v[0] += 1
        v[1] += n > 0
        v[2] += n
    return volumes


def _derniers_chargements():
    return {r.process_name: r for r in db.session.execute(text(
        'SELECT DISTINCT ON (process_name) process_name, end_time, status FROM public.etl_execution_log '
        'WHERE end_time IS NOT NULL ORDER BY process_name, end_time DESC'))}


def _extractions():
    aujourdhui = db.session.execute(text('SELECT CURRENT_DATE')).scalar()
    mois = mois_glissants(aujourdhui)
    par_mois = {m: {} for m in mois}
    jobs_30j = {}
    for r in db.session.execute(text(
            "SELECT to_char(started_at, 'YYYY-MM') AS mois, status, started_at < now() - interval '24 hours' AS ancien, "
            "started_at >= now() - interval '30 days' AS recent, count(*) AS n FROM public.extraction_history "
            "WHERE started_at >= date_trunc('month', now()) - interval '5 months' GROUP BY 1, 2, 3, 4")):
        statut = statut_extraction(r.status, r.ancien)
        compteur = par_mois.get(r.mois)
        if compteur is not None:
            compteur[statut] = compteur.get(statut, 0) + r.n
        if r.recent:
            jobs_30j[statut] = jobs_30j.get(statut, 0) + r.n

    dernier_etat = {}
    echecs = []
    for r in db.session.execute(text(
            "SELECT DISTINCT ON (lower(table_name)) table_name, status, start_time, error_message, "
            "start_time < now() - interval '24 hours' AS ancien FROM public.extraction_details "
            "ORDER BY lower(table_name), start_time DESC NULLS LAST")):
        statut = statut_extraction(r.status, bool(r.ancien))
        dernier_etat[statut] = dernier_etat.get(statut, 0) + 1
        if statut == 'echec':
            echecs.append({'table': r.table_name, 'date': _json(r.start_time), 'erreur': (r.error_message or '')[:200]})
    return {
        'jobs_30j': sum(jobs_30j.values()),
        'statuts_30j': jobs_30j,
        'par_mois': [{'mois': m, **par_mois[m]} for m in mois],
        'dernier_etat': dernier_etat,
        'echecs': sorted(echecs, key=lambda e: e['date'] or '', reverse=True),
    }


def _maintenance():
    job = db.session.execute(text(
        'SELECT status, created_at, finished_at, error_message FROM public.maintenance_jobs '
        "WHERE job_type = 'RELOAD' ORDER BY created_at DESC LIMIT 1")).first()
    if not job:
        return None
    return {'statut': job.status, 'date': _json(job.finished_at or job.created_at), 'erreur': job.error_message}


@dashboard_blueprint.route('', methods=['GET'])
@require_permission('view_dashboards')
def tableau_de_bord():
    calcule_le, perimee = db.session.execute(text(
        "SELECT max(calculated_at), COALESCE(max(calculated_at) < now() - interval '1 hour', true) "
        'FROM public.dashboard_control_history')).one()
    en_cours = _calcul_en_cours()
    if perimee and not en_cours:
        _lancer_calcul()
        en_cours = True

    mesures = _mesures()
    controles, a_traiter, historique = synthese(mesures)
    volumes = _volumes()
    chargements = _derniers_chargements()

    domaines = []
    for d in DOMAINES:
        tables, remplies, lignes = volumes.get(d['categorie'], (0, 0, 0))
        faits = [chargements[m] for m in d['modules'] if m in chargements]
        dernier = max(faits, key=lambda r: r.end_time, default=None)
        domaines.append({
            'cle': d['cle'], 'label': d['label'], 'url': d['url'], 'avec_controles': bool(d['ecran']),
            'tables': tables, 'tables_remplies': remplies, 'lignes': lignes,
            'dernier_chargement': {'date': _json(dernier.end_time), 'statut': dernier.status} if dernier else None,
            **(controles.get(d['cle']) or {}),
        })

    libelles = {d['cle']: (d['label'], d['url']) for d in DOMAINES}
    return jsonify({
        'calcul': {'en_cours': en_cours, 'calcule_le': _json(calcule_le),
                   'premier_jour': _json(mesures[0]['jour']) if mesures else None},
        'domaines': domaines,
        'a_traiter': [{**a, 'domaine': libelles[a['ecran']][0], 'url': libelles[a['ecran']][1]} for a in a_traiter],
        'historique': historique,
        'extractions': _extractions(),
        'maintenance': _maintenance(),
    })


@dashboard_blueprint.route('/recalculer', methods=['POST'])
@require_permission('view_dashboards')
def recalculer():
    if _calcul_en_cours():
        return jsonify({'error': 'Un calcul est déjà en cours.'}), 409
    _lancer_calcul()
    return jsonify({'en_cours': True}), 202


@dashboard_blueprint.route('/historique/<ecran>', methods=['GET'])
@require_permission('view_dashboards')
def historique_ecran(ecran):
    if ecran not in {d['cle'] for d in _AVEC_CONTROLES}:
        return jsonify({'error': 'Domaine inconnu'}), 404
    return jsonify(series_controles(_mesures(), ecran))
