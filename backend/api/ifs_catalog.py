"""API de consultation du catalogue de specs IFS (public.ifs_field_catalog).

Référentiel "Spec Factory" : une ligne = un champ d'une entité IFS d'un lot,
chargé depuis les classeurs Lot*.xlsx par docs/catalogIfs/spec2catalog.py.
Endpoints en lecture seule, consommés par la page "Catalogue IFS" du front.
"""
from flask import Blueprint, jsonify, request, current_app
from flask_jwt_extended import jwt_required
from services.data_service import get_data_service
from sqlalchemy.exc import SQLAlchemyError
from sqlalchemy import text
import json

ifs_catalog_blueprint = Blueprint('ifs_catalog', __name__)

# Colonnes renvoyées par /entities/<entity>/fields (ordre du SELECT)
FIELD_COLUMNS = [
    "catalog_id", "lot_id", "entity", "field_name", "field_label_fr",
    "data_type", "data_length", "sql_type", "mandatory", "primary_key",
    "insertable", "updatable", "lov", "default_value", "reference",
    "enumeration_values", "rnd_flags", "in_scope", "transformation_rules",
    "comments", "sort_order", "source_file", "loaded_at",
]


def _rows_to_dicts(result):
    return [dict(zip(result.keys(), row)) for row in result]


def _parse_enum(value):
    """enumeration_values arrive en list (JSONB) ou en str selon le driver."""
    if value is None or isinstance(value, list):
        return value
    try:
        return json.loads(value)
    except (TypeError, ValueError):
        return None


@ifs_catalog_blueprint.route('/ifs-catalog/lots', methods=['GET'])
@jwt_required()
def get_catalog_lots():
    """Liste des lots chargés dans le catalogue, avec agrégats."""
    try:
        data_service = get_data_service()
        query = """
            SELECT
                lot_id,
                COUNT(DISTINCT entity)            AS nb_entities,
                COUNT(*)                          AS nb_fields,
                MAX(source_file)                  AS source_file,
                MAX(loaded_at)                    AS loaded_at
            FROM public.ifs_field_catalog
            GROUP BY lot_id
            ORDER BY lot_id
        """
        with data_service.engine.connect() as connection:
            result = connection.execute(text(query))
            lots = []
            for row in _rows_to_dicts(result):
                row["loaded_at"] = row["loaded_at"].isoformat() if row["loaded_at"] else None
                lots.append(row)
            return jsonify(lots), 200
    except SQLAlchemyError as e:
        current_app.logger.error(f"Erreur SQL lors de la récupération des lots du catalogue IFS: {str(e)}")
        return jsonify({"error": "Erreur lors de la récupération des lots du catalogue IFS"}), 500


@ifs_catalog_blueprint.route('/ifs-catalog/entities', methods=['GET'])
@jwt_required()
def get_catalog_entities():
    """Entités d'un lot avec agrégats (nb champs, obligatoires, defaults...)."""
    try:
        data_service = get_data_service()
        lot_id = (request.args.get("lot") or "").strip()
        query = """
            SELECT
                lot_id,
                entity,
                COUNT(*)                                                    AS nb_fields,
                COUNT(*) FILTER (WHERE in_scope)                            AS nb_in_scope,
                COUNT(*) FILTER (WHERE mandatory AND in_scope)              AS nb_mandatory,
                COUNT(*) FILTER (WHERE default_value IS NOT NULL)           AS nb_defaults,
                COUNT(*) FILTER (WHERE enumeration_values IS NOT NULL)      AS nb_enums,
                COUNT(*) FILTER (WHERE reference IS NOT NULL)               AS nb_references,
                COUNT(*) FILTER (WHERE primary_key)                         AS nb_pk
            FROM public.ifs_field_catalog
            WHERE (:lot_id = '' OR lot_id = :lot_id)
            GROUP BY lot_id, entity
            ORDER BY lot_id, entity
        """
        with data_service.engine.connect() as connection:
            entities = _rows_to_dicts(connection.execute(text(query), {"lot_id": lot_id}))

            # Surcharge de domaine métier (résilient si la table 025 n'est pas encore créée)
            overrides = {}
            has_theme = connection.execute(
                text("SELECT to_regclass('public.ifs_entity_theme')")
            ).scalar()
            if has_theme:
                theme_rows = connection.execute(
                    text("SELECT lot_id, entity, theme FROM public.ifs_entity_theme "
                         "WHERE (:lot_id = '' OR lot_id = :lot_id)"),
                    {"lot_id": lot_id},
                )
                for r in _rows_to_dicts(theme_rows):
                    overrides[(r["lot_id"], r["entity"])] = r["theme"]

            for e in entities:
                e["theme"] = overrides.get((e["lot_id"], e["entity"]))
            return jsonify(entities), 200
    except SQLAlchemyError as e:
        current_app.logger.error(f"Erreur SQL lors de la récupération des entités du catalogue IFS: {str(e)}")
        return jsonify({"error": "Erreur lors de la récupération des entités du catalogue IFS"}), 500


@ifs_catalog_blueprint.route('/ifs-catalog/entities/<entity>/theme', methods=['PUT'])
@jwt_required()
def set_entity_theme(entity):
    """Définit (upsert) le domaine métier d'une entité pour un lot donné."""
    try:
        data = request.get_json() or {}
        lot_id = (request.args.get("lot") or data.get("lot") or "").strip()
        theme = (data.get("theme") or "").strip()
        if not lot_id or not theme:
            return jsonify({"error": "Paramètres 'lot' et 'theme' requis"}), 400

        query = """
            INSERT INTO public.ifs_entity_theme (lot_id, entity, theme, updated_at)
            VALUES (:lot_id, :entity, :theme, now())
            ON CONFLICT ON CONSTRAINT uq_ifs_entity_theme
            DO UPDATE SET theme = EXCLUDED.theme, updated_at = now()
        """
        data_service = get_data_service()
        with data_service.engine.connect() as connection:
            connection.execute(text(query), {"lot_id": lot_id, "entity": entity, "theme": theme})
            connection.commit()
        return jsonify({"lot_id": lot_id, "entity": entity, "theme": theme}), 200
    except SQLAlchemyError as e:
        current_app.logger.error(f"Erreur SQL lors de la mise à jour du domaine de {entity}: {str(e)}")
        return jsonify({"error": "Erreur lors de la mise à jour du domaine métier"}), 500


def _fetch_fields(connection, lot_id, entity=None):
    """Champs du catalogue pour un lot (et optionnellement une entité)."""
    query = f"""
        SELECT {', '.join(FIELD_COLUMNS)}
        FROM public.ifs_field_catalog
        WHERE (:lot_id = '' OR lot_id = :lot_id)
          AND (:entity = '' OR entity = :entity)
        ORDER BY entity, sort_order NULLS LAST, field_name
    """
    result = connection.execute(text(query), {"lot_id": lot_id, "entity": entity or ""})
    fields = []
    for row in _rows_to_dicts(result):
        row["enumeration_values"] = _parse_enum(row["enumeration_values"])
        row["loaded_at"] = row["loaded_at"].isoformat() if row["loaded_at"] else None
        fields.append(row)
    return fields


@ifs_catalog_blueprint.route('/ifs-catalog/entities/<entity>/fields', methods=['GET'])
@jwt_required()
def get_catalog_entity_fields(entity):
    """Détail des champs d'une entité (toutes les métadonnées de la spec)."""
    try:
        data_service = get_data_service()
        lot_id = (request.args.get("lot") or "").strip()
        with data_service.engine.connect() as connection:
            return jsonify(_fetch_fields(connection, lot_id, entity)), 200
    except SQLAlchemyError as e:
        current_app.logger.error(f"Erreur SQL lors de la récupération des champs de {entity}: {str(e)}")
        return jsonify({"error": f"Erreur lors de la récupération des champs de l'entité {entity}"}), 500


# Colonnes de curation modifiables via l'UI (décisions d'atelier : mapping,
# libellés, defaults...). La structure (data_type, sql_type, primary_key, lot_id,
# entity, field_name) reste pilotée par le classeur de spec et n'est PAS éditable ici.
EDITABLE_TEXT = {"field_label_fr", "default_value", "reference", "comments", "transformation_rules"}
EDITABLE_BOOL = {"mandatory", "in_scope", "insertable", "updatable", "lov"}
EDITABLE_INT = {"sort_order", "data_length"}


@ifs_catalog_blueprint.route('/ifs-catalog/fields/<int:catalog_id>', methods=['PATCH'])
@jwt_required()
def update_catalog_field(catalog_id):
    """Met à jour les métadonnées de curation d'un champ du catalogue."""
    try:
        data = request.get_json() or {}
        set_clauses, params = [], {"catalog_id": catalog_id}
        for key, value in data.items():
            if key in EDITABLE_TEXT:
                params[key] = None if value in (None, "") else str(value)
            elif key in EDITABLE_BOOL:
                params[key] = bool(value)
            elif key in EDITABLE_INT:
                params[key] = None if value in (None, "") else int(value)
            else:
                continue  # colonne non éditable : ignorée silencieusement
            set_clauses.append(f"{key} = :{key}")

        if not set_clauses:
            return jsonify({"error": "Aucun champ modifiable fourni"}), 400

        query = f"""
            UPDATE public.ifs_field_catalog
            SET {', '.join(set_clauses)}
            WHERE catalog_id = :catalog_id
            RETURNING {', '.join(FIELD_COLUMNS)}
        """
        data_service = get_data_service()
        with data_service.engine.connect() as connection:
            result = connection.execute(text(query), params)
            connection.commit()
            rows = _rows_to_dicts(result)
            if not rows:
                return jsonify({"error": "Champ introuvable"}), 404
            row = rows[0]
            row["enumeration_values"] = _parse_enum(row["enumeration_values"])
            row["loaded_at"] = row["loaded_at"].isoformat() if row["loaded_at"] else None
            return jsonify(row), 200
    except (ValueError, TypeError) as e:
        current_app.logger.warning(f"Données invalides pour la mise à jour du champ {catalog_id}: {str(e)}")
        return jsonify({"error": "Données invalides"}), 400
    except SQLAlchemyError as e:
        current_app.logger.error(f"Erreur SQL lors de la mise à jour du champ {catalog_id}: {str(e)}")
        return jsonify({"error": "Erreur lors de la mise à jour du champ"}), 500


@ifs_catalog_blueprint.route('/ifs-catalog/rules', methods=['GET'])
@jwt_required()
def get_catalog_rules():
    """Règles de gestion dérivées du catalogue (calcul live, mêmes règles que
    rules_LOT09.json de spec2catalog : NOT_NULL_ON_LOAD, DEFAULT,
    ENUM_DB_VALUES, FK_LOGICAL)."""
    try:
        data_service = get_data_service()
        lot_id = (request.args.get("lot") or "").strip()
        entity = (request.args.get("entity") or "").strip()
        with data_service.engine.connect() as connection:
            fields = _fetch_fields(connection, lot_id, entity)

        rules = []
        for f in fields:
            base = {"entity": f["entity"], "field": f["field_name"]}
            if f["mandatory"] and f["in_scope"]:
                rules.append({**base, "rule": "NOT_NULL_ON_LOAD"})
            if f["default_value"] is not None:
                rules.append({**base, "rule": "DEFAULT", "value": f["default_value"]})
            if f["enumeration_values"]:
                rules.append({**base, "rule": "ENUM_DB_VALUES",
                              "allowed": [p.get("db") for p in f["enumeration_values"]]})
            if f["reference"] is not None:
                rules.append({**base, "rule": "FK_LOGICAL", "target": f["reference"]})
        return jsonify(rules), 200
    except SQLAlchemyError as e:
        current_app.logger.error(f"Erreur SQL lors du calcul des règles du catalogue IFS: {str(e)}")
        return jsonify({"error": "Erreur lors du calcul des règles du catalogue IFS"}), 500


@ifs_catalog_blueprint.route('/ifs-catalog/stats', methods=['GET'])
@jwt_required()
def get_catalog_stats():
    """Agrégats d'un lot pour l'onglet Statistiques (globaux + par entité)."""
    try:
        data_service = get_data_service()
        lot_id = (request.args.get("lot") or "").strip()
        query = """
            SELECT
                COUNT(DISTINCT entity)                                      AS nb_entities,
                COUNT(*)                                                    AS nb_fields,
                COUNT(*) FILTER (WHERE in_scope)                            AS nb_in_scope,
                COUNT(*) FILTER (WHERE mandatory AND in_scope)              AS nb_mandatory,
                COUNT(*) FILTER (WHERE default_value IS NOT NULL)           AS nb_defaults,
                COUNT(*) FILTER (WHERE reference IS NOT NULL)               AS nb_references,
                COUNT(*) FILTER (WHERE enumeration_values IS NOT NULL)      AS nb_enums,
                COUNT(*) FILTER (WHERE transformation_rules IS NOT NULL)    AS nb_transformations,
                COUNT(*) FILTER (WHERE comments IS NOT NULL)                AS nb_comments
            FROM public.ifs_field_catalog
            WHERE (:lot_id = '' OR lot_id = :lot_id)
        """
        per_entity_query = """
            SELECT
                entity,
                COUNT(*)                                                    AS nb_fields,
                COUNT(*) FILTER (WHERE in_scope)                            AS nb_in_scope,
                COUNT(*) FILTER (WHERE mandatory AND in_scope)              AS nb_mandatory,
                COUNT(*) FILTER (WHERE default_value IS NOT NULL)           AS nb_defaults,
                COUNT(*) FILTER (WHERE enumeration_values IS NOT NULL)      AS nb_enums,
                COUNT(*) FILTER (WHERE reference IS NOT NULL)               AS nb_references
            FROM public.ifs_field_catalog
            WHERE (:lot_id = '' OR lot_id = :lot_id)
            GROUP BY entity
            ORDER BY entity
        """
        with data_service.engine.connect() as connection:
            stats = _rows_to_dicts(connection.execute(text(query), {"lot_id": lot_id}))[0]
            stats["per_entity"] = _rows_to_dicts(
                connection.execute(text(per_entity_query), {"lot_id": lot_id}))
            return jsonify(stats), 200
    except SQLAlchemyError as e:
        current_app.logger.error(f"Erreur SQL lors du calcul des statistiques du catalogue IFS: {str(e)}")
        return jsonify({"error": "Erreur lors du calcul des statistiques du catalogue IFS"}), 500
