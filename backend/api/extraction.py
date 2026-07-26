from flask import Blueprint, request, jsonify, current_app
from flask_jwt_extended import jwt_required, get_jwt_identity

from services.extraction_service import extraction_service

extraction_blueprint = Blueprint('extraction', __name__)

# Au lieu d'utiliser before_app_first_request qui ne fonctionne pas avec les Blueprints
# nous allons utiliser une approche différente
def initialize_extraction_service():
    """Initialise le service d'extraction au démarrage de l'application"""
    current_app.logger.info("Initialisation du service d'extraction...")
    try:
        extraction_service.initialize()
        current_app.logger.info("Service d'extraction initialisé avec succès")
    except Exception as e:
        current_app.logger.error(f"Erreur lors de l'initialisation du service d'extraction: {str(e)}")

# Cette fonction sera appelée lorsque le Blueprint sera enregistré
@extraction_blueprint.record_once
def on_register(state):
    """Exécuté une fois lorsque le blueprint est enregistré"""
    # Accéder à l'application via state.app
    app = state.app
    with app.app_context():
        initialize_extraction_service()

@extraction_blueprint.route('/tables', methods=['GET'])
def get_available_tables():
    """Récupère la liste des tables disponibles pour extraction"""
    try:
        tables = extraction_service.get_available_tables()
        return jsonify(tables), 200
    except Exception as e:
        current_app.logger.exception("Erreur lors de la récupération des tables disponibles")
        return jsonify({"error": str(e)}), 500

@extraction_blueprint.route('/tables/available', methods=['GET'])
def available_tables():
    """Recherche les tables SAP transparentes non encore cataloguées.

    Query params : search, domaine, limit (défaut 100, max 1000), offset.
    Proxy vers le service SAP avec recherche/pagination côté serveur.
    """
    try:
        search = request.args.get('search', type=str)
        domaine = request.args.get('domaine', type=str)
        limit = request.args.get('limit', default=100, type=int)
        offset = request.args.get('offset', default=0, type=int)
        # Borne de sécurité conforme au contrat (max 1000)
        limit = max(1, min(limit, 1000))
        offset = max(0, offset)

        result = extraction_service.available_tables(
            search=search, domaine=domaine, limit=limit, offset=offset
        )
        return jsonify(result), 200
    except Exception as e:
        current_app.logger.exception("Erreur lors de la recherche des tables SAP disponibles")
        # 502 : problème en amont (service SAP / PostgreSQL)
        return jsonify({"error": str(e)}), 502

@extraction_blueprint.route('/metadata/extract', methods=['POST'])
@jwt_required(optional=True)
def extract_metadata():
    """Lance l'extraction des métadonnées SAP des tables choisies.

    Extrait la structure (sap_table_fields / sap_table_properties), cherche les
    relations et — avec add_to_config=true (défaut) — crée la table dans
    raw_data + l'ajoute à table_config.py. Job de fond : renvoie un
    metadata_job_id à suivre via GET /metadata/status/<job_id>.

    Body : { "tables": ["MARA", "EKKO"], "add_to_config": true,
             "batch_size": 50, "force": false, "find_relations": true }
    """
    try:
        data = request.get_json() or {}
        tables = data.get('tables', [])
        if not tables:
            return jsonify({"error": "Aucune table spécifiée"}), 400

        result = extraction_service.extract_metadata(
            tables,
            add_to_config=data.get('add_to_config', True),
            batch_size=data.get('batch_size', 50),
            force=data.get('force', False),
            find_relations=data.get('find_relations', True),
        )
        current_app.logger.info(
            f"Extraction de métadonnées demandée : {tables} "
            f"→ job {result.get('metadata_job_id')}"
        )
        return jsonify(result), 202  # 202 Accepted (job de fond)
    except Exception as e:
        current_app.logger.exception("Erreur lors de l'extraction des métadonnées SAP")
        # 502 : problème en amont (service SAP / PostgreSQL)
        return jsonify({"error": str(e)}), 502


@extraction_blueprint.route('/metadata/status/<job_id>', methods=['GET'])
def metadata_status(job_id):
    """Statut d'un job d'extraction de métadonnées SAP."""
    try:
        status = extraction_service.metadata_status(job_id)
        return jsonify(status), 200
    except Exception as e:
        current_app.logger.exception(
            f"Erreur lors de la récupération du statut métadonnées {job_id}"
        )
        return jsonify({"error": str(e)}), 502


@extraction_blueprint.route('/metadata/jobs', methods=['GET'])
def metadata_jobs():
    """Liste des jobs d'extraction de métadonnées."""
    try:
        limit = request.args.get('limit', default=30, type=int)
        return jsonify(extraction_service.metadata_jobs(limit)), 200
    except Exception as e:
        current_app.logger.exception("Erreur lors de la récupération des jobs métadonnées")
        return jsonify({"error": str(e)}), 502


@extraction_blueprint.route('/metadata/jobs/<job_id>/logs', methods=['GET'])
def metadata_job_logs(job_id):
    """Logs d'un job d'extraction de métadonnées."""
    try:
        limit = request.args.get('limit', default=200, type=int)
        return jsonify(extraction_service.metadata_logs(job_id, limit)), 200
    except Exception as e:
        current_app.logger.exception(f"Erreur logs métadonnées {job_id}")
        return jsonify({"error": str(e)}), 502


@extraction_blueprint.route('/metadata/jobs/<job_id>/cancel', methods=['POST'])
@jwt_required(optional=True)
def metadata_job_cancel(job_id):
    """Annule un job d'extraction de métadonnées."""
    try:
        return jsonify(extraction_service.cancel_metadata_job(job_id)), 200
    except Exception as e:
        current_app.logger.exception(f"Erreur annulation métadonnées {job_id}")
        return jsonify({"error": str(e)}), 502


@extraction_blueprint.route('/start', methods=['POST'])
@jwt_required(optional=True)
def start_extraction():
    """Démarre une extraction de données"""
    try:
        data = request.get_json()
        tables = data.get('tables', [])
        options = data.get('options', {})

        # Récupération de l'identité depuis le JWT (UUID utilisateur).
        # Si pas de token (mode demo / appels internes), fallback sur "demo_user".
        user_id = get_jwt_identity() or "demo_user"

        if not tables:
            return jsonify({"error": "Aucune table spécifiée pour l'extraction"}), 400

        result = extraction_service.start_extraction(tables, options, user_id)
        current_app.logger.info(
            f"Nouvelle extraction lancee : job_id={result.get('extraction_id')} "
            f"par user_id={user_id} sur {len(tables)} table(s)"
        )
        return jsonify(result), 202  # 202 Accepted

    except Exception as e:
        current_app.logger.error(f"Erreur lors du démarrage de l'extraction: {str(e)}")
        return jsonify({"error": str(e)}), 500

@extraction_blueprint.route('/status/<extraction_id>', methods=['GET'])
def get_extraction_status(extraction_id):
    """Récupère le statut d'une extraction"""
    try:
        status = extraction_service.get_extraction_status(extraction_id)
        return jsonify(status), 200
        
    except Exception as e:
        current_app.logger.error(f"Erreur lors de la récupération du statut de l'extraction {extraction_id}: {str(e)}")
        return jsonify({"error": str(e)}), 500

@extraction_blueprint.route('/stop/<extraction_id>', methods=['POST'])
def stop_extraction(extraction_id):
    """Arrête une extraction en cours"""
    try:
        reason = request.json.get('reason', 'Arrêt manuel')
        result = extraction_service.stop_extraction(extraction_id, reason)
        
        if result:
            return jsonify({"message": f"Extraction {extraction_id} arrêtée avec succès"}), 200
        else:
            return jsonify({"error": "Impossible d'arrêter l'extraction"}), 400
        
    except Exception as e:
        current_app.logger.error(f"Erreur lors de l'arrêt de l'extraction {extraction_id}: {str(e)}")
        return jsonify({"error": str(e)}), 500

@extraction_blueprint.route('/logs/<extraction_id>', methods=['GET'])
# Désactivation temporaire de l'authentification
# @jwt_required()
def get_extraction_logs(extraction_id):
    """Récupère les logs d'une extraction"""
    try:
        # Récupération du nombre de logs à récupérer
        limit = int(request.args.get('limit', 100))
        
        logs = extraction_service.get_extraction_logs(extraction_id, limit)
        
        return jsonify(logs), 200
        
    except Exception as e:
        current_app.logger.error(f"Erreur lors de la récupération des logs de l'extraction {extraction_id}: {str(e)}")
        return jsonify({"error": "Erreur lors de la récupération des logs"}), 500

@extraction_blueprint.route('/iflo-hierarchy', methods=['GET'])
def get_iflo_hierarchy():
    """Retourne la hiérarchie des postes techniques IFLO"""
    try:
        tree = extraction_service.get_iflo_hierarchy()
        return jsonify(tree), 200
    except Exception as e:
        current_app.logger.exception("Erreur lors de la récupération de la hiérarchie IFLO")
        return jsonify({"error": str(e)}), 500

@extraction_blueprint.route('/history', methods=['GET'])
def get_extraction_history():
    """Récupère l'historique des extractions"""
    try:
        limit = int(request.args.get('limit', 20))
        offset = int(request.args.get('offset', 0))
        
        history = extraction_service.get_extraction_history(limit, offset)
        return jsonify(history), 200
        
    except Exception as e:
        current_app.logger.exception("Erreur lors de la récupération de l'historique des extractions")
        return jsonify({"error": str(e)}), 500