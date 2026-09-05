"""Paramétrage de l'écran Matrice Site × Famille (migration 067).

Deux référentiels édités depuis Configuration > Paramètres de la matrice :
  * les familles d'articles proposées en colonnes (code, libellé, description) ;
  * les tables cibles proposées dans le sélecteur.

Aucune procédure ETL ne lit ces tables : elles ne pilotent que l'écran.
"""
from flask import Blueprint, request, jsonify, current_app
from flask_jwt_extended import jwt_required, get_jwt_identity
from sqlalchemy import text
from sqlalchemy.exc import SQLAlchemyError, IntegrityError

from models import db, EtlPartFamily, EtlMatrixTargetTable, EtlDefaultValueMatrix

matrix_settings_blueprint = Blueprint('matrix_settings', __name__)


def _texte(valeur):
    """Chaîne vide venant du front -> None (colonne laissée vide en base)."""
    if valeur is None:
        return None
    valeur = str(valeur).strip()
    return valeur or None


def _familles_dans_les_donnees():
    """Codes famille réellement présents dans le fichier PHL chargé.

    Sert à signaler les familles livrées mais non déclarées. La vue applique
    déjà les exclusions de périmètre (famille 19 = lingots).
    """
    try:
        return [r[0] for r in db.session.execute(text(
            'SELECT DISTINCT NULLIF(TRIM("FAMILLE"), \'\') AS famille '
            'FROM raw_data.v_phl_article_retenu '
            'WHERE NULLIF(TRIM("FAMILLE"), \'\') IS NOT NULL ORDER BY 1'
        ))]
    except SQLAlchemyError:
        db.session.rollback()
        return []


# ===========================================================================
# Familles d'articles
# ===========================================================================
@matrix_settings_blueprint.route('/matrix/part-families', methods=['GET'])
@jwt_required()
def list_part_families():
    """Familles déclarées + codes vus dans les données (pour les signaler)."""
    try:
        rows = EtlPartFamily.query.order_by(
            EtlPartFamily.ordre, EtlPartFamily.code
        ).all()
        return jsonify({
            'part_families': [r.to_dict() for r in rows],
            'total': len(rows),
            'detectees': _familles_dans_les_donnees(),
        }), 200
    except SQLAlchemyError as e:
        db.session.rollback()
        current_app.logger.error(f"Erreur liste familles: {e}")
        return jsonify({"error": "Erreur lors de la récupération des familles"}), 500


@matrix_settings_blueprint.route('/matrix/part-families', methods=['POST'])
@jwt_required()
def create_part_family():
    data = request.get_json() or {}
    code = _texte(data.get('code'))
    if not code:
        return jsonify({"error": "Le code de la famille est obligatoire"}), 400
    try:
        famille = EtlPartFamily(
            code=code,
            libelle=_texte(data.get('libelle')),
            description=_texte(data.get('description')),
            ordre=int(data.get('ordre') or 100),
            is_active=bool(data.get('is_active', True)),
            created_by=get_jwt_identity(),
            updated_by=get_jwt_identity(),
        )
        db.session.add(famille)
        db.session.commit()
        return jsonify(famille.to_dict()), 201
    except IntegrityError:
        db.session.rollback()
        return jsonify({"error": f"La famille {code} est déjà déclarée"}), 409
    except (SQLAlchemyError, ValueError) as e:
        db.session.rollback()
        current_app.logger.error(f"Erreur création famille: {e}")
        return jsonify({"error": "Erreur lors de la création de la famille"}), 500


@matrix_settings_blueprint.route('/matrix/part-families/<int:family_id>', methods=['PUT'])
@jwt_required()
def update_part_family(family_id):
    """Le code n'est modifiable que tant qu'aucune règle ne l'utilise.

    etl_default_value_matrix.part_family stocke le code en clair, sans clé
    étrangère : renommer ici laisserait les règles pointer sur un code disparu.
    """
    famille = EtlPartFamily.query.get(family_id)
    if famille is None:
        return jsonify({"error": "Famille introuvable"}), 404
    data = request.get_json() or {}
    try:
        nouveau_code = _texte(data.get('code'))
        if nouveau_code and nouveau_code != famille.code:
            utilisee = EtlDefaultValueMatrix.query.filter_by(
                part_family=famille.code
            ).count()
            if utilisee:
                return jsonify({"error":
                    f"Impossible de renommer {famille.code} : {utilisee} règle(s) de la "
                    f"matrice l'utilisent. Supprimez-les d'abord, ou créez une nouvelle famille."
                }), 409
            famille.code = nouveau_code
        if 'libelle' in data:
            famille.libelle = _texte(data.get('libelle'))
        if 'description' in data:
            famille.description = _texte(data.get('description'))
        if 'ordre' in data:
            famille.ordre = int(data['ordre'] or 100)
        if 'is_active' in data:
            famille.is_active = bool(data['is_active'])
        famille.updated_by = get_jwt_identity()
        db.session.commit()
        return jsonify(famille.to_dict()), 200
    except IntegrityError:
        db.session.rollback()
        return jsonify({"error": "Ce code de famille est déjà utilisé"}), 409
    except (SQLAlchemyError, ValueError) as e:
        db.session.rollback()
        current_app.logger.error(f"Erreur update famille {family_id}: {e}")
        return jsonify({"error": "Erreur lors de la mise à jour de la famille"}), 500


@matrix_settings_blueprint.route('/matrix/part-families/<int:family_id>', methods=['DELETE'])
@jwt_required()
def delete_part_family(family_id):
    """Refus si des règles portent sur cette famille : elles deviendraient
    invisibles dans la grille tout en restant appliquées par l'ETL."""
    famille = EtlPartFamily.query.get(family_id)
    if famille is None:
        return jsonify({"error": "Famille introuvable"}), 404
    try:
        utilisee = EtlDefaultValueMatrix.query.filter_by(part_family=famille.code).count()
        if utilisee:
            return jsonify({"error":
                f"Impossible de supprimer {famille.code} : {utilisee} règle(s) de la matrice "
                f"l'utilisent. Désactivez la famille pour la retirer de la grille sans perdre les règles."
            }), 409
        db.session.delete(famille)
        db.session.commit()
        return jsonify({"message": "Famille supprimée"}), 200
    except SQLAlchemyError as e:
        db.session.rollback()
        current_app.logger.error(f"Erreur suppression famille {family_id}: {e}")
        return jsonify({"error": "Erreur lors de la suppression de la famille"}), 500


# ===========================================================================
# Tables cibles
# ===========================================================================
@matrix_settings_blueprint.route('/matrix/target-tables', methods=['GET'])
@jwt_required()
def list_target_tables():
    try:
        rows = EtlMatrixTargetTable.query.order_by(
            EtlMatrixTargetTable.ordre, EtlMatrixTargetTable.table_cible
        ).all()
        return jsonify({'target_tables': [r.to_dict() for r in rows], 'total': len(rows)}), 200
    except SQLAlchemyError as e:
        db.session.rollback()
        current_app.logger.error(f"Erreur liste tables cibles: {e}")
        return jsonify({"error": "Erreur lors de la récupération des tables cibles"}), 500


@matrix_settings_blueprint.route('/matrix/target-tables', methods=['POST'])
@jwt_required()
def create_target_table():
    data = request.get_json() or {}
    table_cible = _texte(data.get('table_cible'))
    if not table_cible:
        return jsonify({"error": "La table cible est obligatoire"}), 400
    try:
        cible = EtlMatrixTargetTable(
            table_cible=table_cible,
            libelle=_texte(data.get('libelle')),
            description=_texte(data.get('description')),
            ordre=int(data.get('ordre') or 100),
            is_active=bool(data.get('is_active', True)),
            created_by=get_jwt_identity(),
            updated_by=get_jwt_identity(),
        )
        db.session.add(cible)
        db.session.commit()
        return jsonify(cible.to_dict()), 201
    except IntegrityError:
        db.session.rollback()
        return jsonify({"error": f"La table {table_cible} est déjà déclarée"}), 409
    except (SQLAlchemyError, ValueError) as e:
        db.session.rollback()
        current_app.logger.error(f"Erreur création table cible: {e}")
        return jsonify({"error": "Erreur lors de la création de la table cible"}), 500


@matrix_settings_blueprint.route('/matrix/target-tables/<int:table_id>', methods=['PUT'])
@jwt_required()
def update_target_table(table_id):
    cible = EtlMatrixTargetTable.query.get(table_id)
    if cible is None:
        return jsonify({"error": "Table cible introuvable"}), 404
    data = request.get_json() or {}
    try:
        nouvelle = _texte(data.get('table_cible'))
        if nouvelle and nouvelle != cible.table_cible:
            utilisee = EtlDefaultValueMatrix.query.filter_by(table_cible=cible.table_cible).count()
            if utilisee:
                return jsonify({"error":
                    f"Impossible de changer {cible.table_cible} : {utilisee} règle(s) de la matrice "
                    f"portent dessus. Déclarez plutôt une nouvelle table."
                }), 409
            cible.table_cible = nouvelle
        if 'libelle' in data:
            cible.libelle = _texte(data.get('libelle'))
        if 'description' in data:
            cible.description = _texte(data.get('description'))
        if 'ordre' in data:
            cible.ordre = int(data['ordre'] or 100)
        if 'is_active' in data:
            cible.is_active = bool(data['is_active'])
        cible.updated_by = get_jwt_identity()
        db.session.commit()
        return jsonify(cible.to_dict()), 200
    except IntegrityError:
        db.session.rollback()
        return jsonify({"error": "Cette table cible est déjà déclarée"}), 409
    except (SQLAlchemyError, ValueError) as e:
        db.session.rollback()
        current_app.logger.error(f"Erreur update table cible {table_id}: {e}")
        return jsonify({"error": "Erreur lors de la mise à jour de la table cible"}), 500


@matrix_settings_blueprint.route('/matrix/target-tables/<int:table_id>', methods=['DELETE'])
@jwt_required()
def delete_target_table(table_id):
    cible = EtlMatrixTargetTable.query.get(table_id)
    if cible is None:
        return jsonify({"error": "Table cible introuvable"}), 404
    try:
        utilisee = EtlDefaultValueMatrix.query.filter_by(table_cible=cible.table_cible).count()
        if utilisee:
            return jsonify({"error":
                f"Impossible de supprimer {cible.table_cible} : {utilisee} règle(s) de la matrice "
                f"portent dessus. Désactivez-la pour la retirer du sélecteur sans perdre les règles."
            }), 409
        db.session.delete(cible)
        db.session.commit()
        return jsonify({"message": "Table cible supprimée"}), 200
    except SQLAlchemyError as e:
        db.session.rollback()
        current_app.logger.error(f"Erreur suppression table cible {table_id}: {e}")
        return jsonify({"error": "Erreur lors de la suppression de la table cible"}), 500
