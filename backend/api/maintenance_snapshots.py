# -*- coding: utf-8 -*-
"""
API des etats sauvegardes du module Maintenance (prefixe /api/v1/maintenance).

  POST   /snapshots                 cree un etat nomme a partir de l'etat courant
  GET    /snapshots                 liste les etats sauvegardes
  DELETE /snapshots/<id>            supprime un etat
  POST   /snapshots/<id>/restore    restaure un etat (job asynchrone)
  POST   /reload                    recharge depuis SAP (job asynchrone)
  GET    /jobs                      historique des operations
  GET    /jobs/<id>                 suivi d'une operation (polling)
  GET    /jobs/active               operation en cours, ou null

Les operations longues (restauration, rechargement) renvoient immediatement un
``job_id`` : le suivi se fait par polling sur /jobs/<id>. Une seule operation
maintenance peut tourner a la fois (HTTP 409 sinon).
"""

from flask import Blueprint, current_app, jsonify, request
from flask_jwt_extended import get_jwt_identity, jwt_required

from services import maintenance_reload_service as jobs
from services import maintenance_snapshot_service as snapshots

maintenance_snapshots_blueprint = Blueprint('maintenance_snapshots', __name__)


def _user():
    """Identite JWT pour l'attribution (created_by)."""
    try:
        return get_jwt_identity()
    except Exception:
        return None


# ---------------------------------------------------------------------------
# Garde-fou reutilisable par les autres blueprints maintenance
# ---------------------------------------------------------------------------

def active_job_conflict():
    """
    Renvoie une reponse (payload, 409) si une operation maintenance est en cours,
    sinon None. A appeler en tete des endpoints qui MODIFIENT les donnees
    maintenance : pendant une restauration ou un rechargement, toute ecriture
    concurrente serait perdue ou incoherente.
    """
    try:
        # Lecture legere d'abord (une requete) : le cas nominal est « aucun job ».
        if not jobs.peek_active_job():
            return None
        # Un job semble actif : verification complete (nettoie les orphelins).
        active = jobs.get_active_job()
    except Exception as e:  # ne jamais bloquer l'UI sur une panne du garde-fou
        current_app.logger.warning(f"Verification du job maintenance impossible : {e}")
        return None
    if not active:
        return None
    return jsonify({
        'error': 'Operation maintenance en cours',
        'message': (
            "Une operation est en cours ("
            f"{active.get('current_step') or active.get('job_type')}). "
            "Les modifications sont temporairement suspendues."
        ),
        'job': active,
    }), 409


# ---------------------------------------------------------------------------
# Etats sauvegardes
# ---------------------------------------------------------------------------

@maintenance_snapshots_blueprint.route('/snapshots', methods=['GET'])
@jwt_required()
def list_snapshots():
    try:
        return jsonify({'success': True, 'data': snapshots.list_snapshots()}), 200
    except Exception as e:
        current_app.logger.error(f"Liste des etats maintenance : {e}")
        return jsonify({'error': "Impossible de lister les etats sauvegardes"}), 500


@maintenance_snapshots_blueprint.route('/snapshots', methods=['POST'])
@jwt_required()
def create_snapshot():
    data = request.get_json() or {}
    name = (data.get('name') or '').strip()
    if not name:
        return jsonify({'error': "Le nom de l'etat est obligatoire"}), 400

    conflict = active_job_conflict()
    if conflict:
        return conflict

    try:
        snapshot = snapshots.create_snapshot(
            name=name,
            description=data.get('description'),
            kind='MANUAL',
            user=_user(),
        )
        return jsonify({'success': True, 'data': snapshot}), 201
    except snapshots.SnapshotError as e:
        return jsonify({'error': str(e)}), 400
    except Exception as e:
        current_app.logger.error(f"Creation d'un etat maintenance : {e}")
        return jsonify({'error': "Impossible de creer l'etat sauvegarde"}), 500


@maintenance_snapshots_blueprint.route('/snapshots/<int:snapshot_id>', methods=['DELETE'])
@jwt_required()
def delete_snapshot(snapshot_id):
    try:
        snapshots.delete_snapshot(snapshot_id)
        return jsonify({'success': True}), 200
    except snapshots.SnapshotError as e:
        return jsonify({'error': str(e)}), 400
    except Exception as e:
        current_app.logger.error(f"Suppression de l'etat #{snapshot_id} : {e}")
        return jsonify({'error': "Impossible de supprimer l'etat sauvegarde"}), 500


@maintenance_snapshots_blueprint.route('/snapshots/<int:snapshot_id>/restore', methods=['POST'])
@jwt_required()
def restore_snapshot(snapshot_id):
    """Restaure un etat (asynchrone). L'etat courant est sauvegarde au prealable."""
    snapshot = snapshots.get_snapshot(snapshot_id)
    if not snapshot:
        return jsonify({'error': f"Etat #{snapshot_id} introuvable"}), 404
    if snapshot['status'] != 'READY':
        return jsonify({
            'error': f"L'etat « {snapshot['name']} » n'est pas exploitable "
                     f"(statut {snapshot['status']})"
        }), 400

    try:
        job = jobs.create_job('RESTORE', {'snapshot_id': snapshot_id}, user=_user())
    except jobs.JobConflictError as e:
        return jsonify({'error': 'Operation maintenance en cours', 'message': str(e)}), 409
    except jobs.JobError as e:
        return jsonify({'error': str(e)}), 400

    jobs.start_job(current_app._get_current_object(), job['id'])
    return jsonify({'success': True, 'data': job}), 202


# ---------------------------------------------------------------------------
# Rechargement depuis SAP
# ---------------------------------------------------------------------------

@maintenance_snapshots_blueprint.route('/reload', methods=['POST'])
@jwt_required()
def reload_from_sap():
    """
    Recharge le module maintenance depuis SAP (asynchrone).

    Corps : {"mode": "merge"|"reset", "with_extraction": true|false}
      - merge : conserve les lignes modifiees dans l'UI et les ajouts manuels ;
      - reset : reconstruit integralement la partie SAP.
    Un etat AUTO_PRE_RELOAD est systematiquement sauvegarde avant l'operation.
    """
    data = request.get_json() or {}
    mode = (data.get('mode') or 'merge').lower()
    if mode not in ('merge', 'reset'):
        return jsonify({'error': "Mode invalide : attendu 'merge' ou 'reset'"}), 400

    params = {
        'mode': mode,
        'with_extraction': bool(data.get('with_extraction', True)),
    }

    try:
        job = jobs.create_job('RELOAD', params, user=_user())
    except jobs.JobConflictError as e:
        return jsonify({'error': 'Operation maintenance en cours', 'message': str(e)}), 409
    except jobs.JobError as e:
        return jsonify({'error': str(e)}), 400

    jobs.start_job(current_app._get_current_object(), job['id'])
    return jsonify({'success': True, 'data': job}), 202


# ---------------------------------------------------------------------------
# Suivi des operations
# ---------------------------------------------------------------------------

@maintenance_snapshots_blueprint.route('/jobs/active', methods=['GET'])
@jwt_required()
def get_active_job():
    try:
        return jsonify({'success': True, 'data': jobs.get_active_job()}), 200
    except Exception as e:
        current_app.logger.error(f"Lecture du job maintenance actif : {e}")
        return jsonify({'error': "Impossible de lire l'operation en cours"}), 500


@maintenance_snapshots_blueprint.route('/jobs/<int:job_id>', methods=['GET'])
@jwt_required()
def get_job(job_id):
    try:
        job = jobs.get_job(job_id)
        if not job:
            return jsonify({'error': f"Operation #{job_id} introuvable"}), 404
        return jsonify({'success': True, 'data': job}), 200
    except Exception as e:
        current_app.logger.error(f"Lecture du job maintenance #{job_id} : {e}")
        return jsonify({'error': "Impossible de lire l'operation"}), 500


@maintenance_snapshots_blueprint.route('/jobs', methods=['GET'])
@jwt_required()
def list_jobs():
    try:
        limit = min(int(request.args.get('limit', 20)), 100)
    except (TypeError, ValueError):
        limit = 20
    try:
        return jsonify({'success': True, 'data': jobs.list_jobs(limit)}), 200
    except Exception as e:
        current_app.logger.error(f"Historique des jobs maintenance : {e}")
        return jsonify({'error': "Impossible de lire l'historique"}), 500
