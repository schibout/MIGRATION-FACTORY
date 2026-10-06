"""Menu Finance : ecran des immobilisations (clean_data.immobilisation).

  GET  /api/v1/finance/immobilisations       liste paginee + filtres + stats
  POST /api/v1/finance/immobilisations/sync  re-extraction SAP des tables sources,
                                              puis clean_data.alimenter_immobilisation()
  GET  /api/v1/finance/immobilisations/sync  etat de la derniere synchronisation
"""
import json
import logging
import os
import tempfile
import threading
import time
from datetime import date, datetime
from decimal import Decimal

from flask import Blueprint, current_app, jsonify, request
from flask_jwt_extended import get_jwt_identity, jwt_required
from sqlalchemy import text

from models import db

finance_blueprint = Blueprint('finance', __name__)
logger = logging.getLogger(__name__)

# Tables lues par clean_data.alimenter_immobilisation
# (sql/immobilisation/02_alimenter_immobilisation.sql).
# Uniquement des tables transparentes : une vue SAP s'extrait vide.
IMMO_SAP_TABLES = ['ANLA', 'ANLB', 'ANLC', 'ANLZ', 'ANKT', 'T001', 'T095', 'T095T',
                   'T090NAT', 'CSKT', 'TGSBT']

EXTRACTION_TIMEOUT_SECONDS = 3600
EXTRACTION_POLL_SECONDS = 10

# gunicorn -w4 : l'etat est publie dans un fichier partage par les workers du
# conteneur (meme principe que api/etl.py).
# ponytail: un seul fichier = une seule synchro a la fois ; perdu au redeploiement
# (le bouton redevient simplement disponible).
_STATUS_FILE = os.path.join(tempfile.gettempdir(), 'immobilisation_sync.json')

COLONNES = [
    'societe_sap',
    'num_immobilisation',
    'sous_numero',
    'cle_immobilisation',
    'libelle',
    'libelle_complementaire',
    'classe_immo',
    'famille_immo',
    'indicateur_suppression',
    'numero_serie',
    'pays',
    'groupe_evaluation_1',
    'groupe_evaluation_2',
    'groupe_evaluation_3',
    'groupe_evaluation_4',
    'projet',
    'cle_comptes_immo',
    'libelle_cle_comptes_immo',
    'compte_immobilisation',
    'compte_amort_cumule',
    'compte_dotation_amort',
    'date_acquisition',
    'date_premiere_acquisition',
    'date_debut_amort',
    'date_fin_amort_estimee',
    'duree_amort_annees',
    'duree_amort_periodes',
    'duree_amort_totale_mois',
    'zone_amortissement',
    'type_amortissement',
    'libelle_type_amortissement',
    'taux_amort_estime',
    'centre_cout',
    'libelle_centre_cout',
    'site_sap',
    'secteur_sap',
    'libelle_secteur',
    'emplacement',
    'immo_origine',
    'sous_numero_origine',
    'date_origine',
    'numero_inventaire',
    'fabricant',
    'type_modele',
    'fournisseur',
    'quantite',
    'unite',
    'ordre_investissement',
    'zone_valorisation',
    'exercice_valorisation',
    'valeur_acq_debut_exercice',
    'mouvements_acq_exercice',
    'sorties_exercice',
    'valeur_acq_fin_exercice',
    'amort_cumules',
    'vnc',
    'dotation_annuelle',
    'blocage_comptabilisation',
    'date_sortie',
    'date_desactivation',
]


def _read_status():
    try:
        with open(_STATUS_FILE, encoding='utf-8') as f:
            return json.load(f)
    except (OSError, ValueError):
        return None


def _write_status(**fields):
    status = {**(_read_status() or {}), **fields}
    tmp = _STATUS_FILE + '.tmp'
    with open(tmp, 'w', encoding='utf-8') as f:
        json.dump(status, f, default=str)
    os.replace(tmp, _STATUS_FILE)
    return status


def _json(v):
    """date -> 'YYYY-MM-DD', Decimal -> float (jsonify ferait une date HTTP et une chaine)."""
    if isinstance(v, date):
        return v.isoformat()
    if isinstance(v, Decimal):
        return float(v)
    return v


def _now():
    return datetime.now().isoformat(timespec='seconds')


@finance_blueprint.route('/immobilisations', methods=['GET'])
@jwt_required()
def list_immobilisations():
    page = max(int(request.args.get('page', 1)), 1)
    page_size = min(max(int(request.args.get('page_size', 50)), 1), 500)
    search = (request.args.get('search') or '').strip()
    secteur = (request.args.get('secteur') or '').strip()
    statut = (request.args.get('statut') or '').strip()

    where, params = [], {}
    if search:
        where.append("(num_immobilisation ILIKE :s OR libelle ILIKE :s OR famille_immo ILIKE :s "
                     "OR centre_cout ILIKE :s OR numero_inventaire ILIKE :s "
                     "OR compte_immobilisation ILIKE :s)")
        params['s'] = f'%{search}%'
    if secteur:
        where.append('secteur_sap = :secteur')
        params['secteur'] = secteur
    if statut == 'actives':
        where.append('date_desactivation IS NULL')
    elif statut == 'desactivees':
        where.append('date_desactivation IS NOT NULL')
    clause = ('WHERE ' + ' AND '.join(where)) if where else ''

    total = db.session.execute(
        text(f'SELECT count(*) FROM clean_data.immobilisation {clause}'), params).scalar()
    rows = db.session.execute(text(
        f'SELECT {", ".join(COLONNES)} FROM clean_data.immobilisation {clause} '
        'ORDER BY num_immobilisation, sous_numero LIMIT :limit OFFSET :offset'
    ), {**params, 'limit': page_size, 'offset': (page - 1) * page_size}).mappings().all()

    # Totaux sur la selection filtree (valeurs statutaires a l'ouverture)
    stats = db.session.execute(text(
        'SELECT count(*) AS immobilisations, '
        'count(*) FILTER (WHERE date_desactivation IS NULL) AS actives, '
        'sum(valeur_acq_debut_exercice) AS valeur_acquisition, '
        'sum(amort_cumules) AS amort_cumules, sum(vnc) AS vnc, '
        'max(exercice_valorisation) AS exercice '
        f'FROM clean_data.immobilisation {clause}'), params).mappings().one()
    secteurs = [dict(r) for r in db.session.execute(text(
        'SELECT secteur_sap AS code, max(libelle_secteur) AS libelle '
        'FROM clean_data.immobilisation WHERE secteur_sap IS NOT NULL '
        'GROUP BY secteur_sap ORDER BY secteur_sap')).mappings()]

    return jsonify({
        'rows': [{k: _json(v) for k, v in r.items()} for r in rows],
        'total': total,
        'page': page,
        'page_size': page_size,
        'stats': {k: _json(v) for k, v in stats.items()},
        'secteurs': secteurs,
        'sync': _read_status(),
    })


@finance_blueprint.route('/immobilisations/sync', methods=['GET'])
@jwt_required()
def get_sync_status():
    return jsonify(_read_status() or {'status': 'never'})


@finance_blueprint.route('/immobilisations/sync', methods=['POST'])
@jwt_required()
def start_sync():
    current = _read_status()
    if current and current.get('status') == 'running':
        return jsonify({'error': 'Une synchronisation est deja en cours.', **current}), 409

    user = str(get_jwt_identity() or 'finance-sync')
    status = _write_status(
        status='running', step='Demarrage', progress=0, error=None, rows=None,
        started_at=_now(), finished_at=None, started_by=user, extraction_id=None,
    )
    app = current_app._get_current_object()
    threading.Thread(target=_run_sync, args=(app, user), daemon=True,
                     name='immobilisation-sync').start()
    return jsonify(status), 202


def _run_sync(app, user):
    with app.app_context():
        try:
            _extract(user)
            _write_status(step='Rechargement de clean_data.immobilisation', progress=90)
            with db.engine.begin() as conn:
                rows = conn.execute(text('SELECT clean_data.alimenter_immobilisation()')).scalar()
            _write_status(status='completed', step='Termine', progress=100,
                          rows=rows, finished_at=_now())
        except Exception as e:  # le thread ne doit jamais mourir en silence
            logger.error(f'Synchronisation immobilisations en echec : {e}')
            _write_status(status='failed', error=str(e), finished_at=_now())


def _extract(user):
    """Extraction SAP (differentielle) des tables sources, attente de la fin."""
    from services.extraction_service import extraction_service

    _write_status(step=f'Extraction SAP ({len(IMMO_SAP_TABLES)} tables)', progress=5)
    result = extraction_service.start_extraction(
        tables=IMMO_SAP_TABLES, options={'mode': 'standard'}, user_id=user)
    extraction_id = result.get('extraction_id')
    if not extraction_id:
        raise RuntimeError("Le conteneur d'extraction SAP n'a pas renvoye d'identifiant.")
    _write_status(extraction_id=extraction_id)

    deadline = time.time() + EXTRACTION_TIMEOUT_SECONDS
    while time.time() < deadline:
        time.sleep(EXTRACTION_POLL_SECONDS)
        try:
            payload = extraction_service.get_extraction_status(extraction_id)
        except Exception as e:
            logger.warning(f'Statut extraction {extraction_id} indisponible ({e}), nouvel essai.')
            continue
        status = (payload.get('status') or 'running').lower()
        if status in ('completed', 'success', 'done', 'finished'):
            return
        if status in ('failed', 'error'):
            raise RuntimeError(f"L'extraction SAP a echoue : {payload.get('error_message') or 'cause inconnue'}")
        if status in ('stopped', 'cancelled', 'canceled'):
            raise RuntimeError("L'extraction SAP a ete interrompue.")
        progress = payload.get('progress_percentage')
        if progress is not None:
            # L'extraction occupe la plage 5 % -> 85 %.
            _write_status(progress=5 + int(float(progress) * 0.8))
    raise RuntimeError(f"Extraction SAP non terminee apres {EXTRACTION_TIMEOUT_SECONDS // 60} min.")
