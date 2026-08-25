from flask import Blueprint, request, jsonify, current_app
from flask_jwt_extended import jwt_required, get_jwt_identity
from sqlalchemy.exc import SQLAlchemyError

from models import db, EtlDefaultValue

default_values_blueprint = Blueprint('default_values', __name__)


@default_values_blueprint.route('/default-values', methods=['GET'])
@jwt_required()
def list_default_values():
    """Liste paginée + filtres module / table_cible / colonne (partiel) / is_active"""
    try:
        page = request.args.get('page', 1, type=int)
        per_page = min(request.args.get('per_page', 25, type=int), 100)
        query = EtlDefaultValue.query
        if request.args.get('module'):
            query = query.filter(EtlDefaultValue.module == request.args['module'])
        if request.args.get('table_cible'):
            query = query.filter(EtlDefaultValue.table_cible == request.args['table_cible'])
        if request.args.get('colonne'):
            query = query.filter(EtlDefaultValue.colonne.ilike(f"%{request.args['colonne']}%"))
        if request.args.get('is_active') in ('true', 'false'):
            query = query.filter(EtlDefaultValue.is_active == (request.args['is_active'] == 'true'))
        query = query.order_by(EtlDefaultValue.table_cible, EtlDefaultValue.colonne, EtlDefaultValue.variante)
        pagination = query.paginate(page=page, per_page=per_page, error_out=False)
        return jsonify({
            'default_values': [v.to_dict() for v in pagination.items],
            'total': pagination.total,
            'page': page,
            'per_page': per_page,
            'pages': pagination.pages,
        }), 200
    except SQLAlchemyError as e:
        current_app.logger.error(f"Erreur liste default-values: {e}")
        return jsonify({"error": "Erreur lors de la récupération des valeurs par défaut"}), 500


@default_values_blueprint.route('/default-values/meta', methods=['GET'])
@jwt_required()
def default_values_meta():
    """Modules et tables distincts pour alimenter les filtres de l'écran"""
    try:
        modules = [r[0] for r in db.session.query(EtlDefaultValue.module).distinct().order_by(EtlDefaultValue.module)]
        tables = [
            {'module': r[0], 'table_cible': r[1]}
            for r in db.session.query(EtlDefaultValue.module, EtlDefaultValue.table_cible)
            .distinct().order_by(EtlDefaultValue.module, EtlDefaultValue.table_cible)
        ]
        return jsonify({'modules': modules, 'tables': tables}), 200
    except SQLAlchemyError as e:
        current_app.logger.error(f"Erreur meta default-values: {e}")
        return jsonify({"error": "Erreur lors de la récupération des métadonnées"}), 500


@default_values_blueprint.route('/default-values/<int:value_id>', methods=['PUT'])
@jwt_required()
def update_default_value(value_id):
    """Champs modifiables : valeur, type_valeur, description, is_active. updated_by = identité JWT."""
    try:
        dv = EtlDefaultValue.query.get(value_id)
        if dv is None:
            return jsonify({"error": "Valeur par défaut introuvable"}), 404
        data = request.get_json() or {}
        if 'type_valeur' in data:
            if data['type_valeur'] not in ('CONSTANTE', 'NULL'):
                return jsonify({"error": "type_valeur doit être CONSTANTE ou NULL"}), 400
            dv.type_valeur = data['type_valeur']
        if 'valeur' in data:
            dv.valeur = None if dv.type_valeur == 'NULL' else data['valeur']
        if 'description' in data:
            dv.description = data['description']
        if 'is_active' in data:
            dv.is_active = bool(data['is_active'])
        dv.updated_by = get_jwt_identity()
        db.session.commit()
        return jsonify(dv.to_dict()), 200
    except SQLAlchemyError as e:
        db.session.rollback()
        current_app.logger.error(f"Erreur update default-value {value_id}: {e}")
        return jsonify({"error": "Erreur lors de la mise à jour"}), 500
