from flask import Blueprint, request, jsonify, current_app, send_file
from sqlalchemy.exc import IntegrityError
from datetime import datetime
import io

from models import db, BusinessRule

business_rules_blueprint = Blueprint('business_rules', __name__)

# Utilisateur fixe en dev (aligné sur les autres blueprints du projet)
DEV_USER = "user_dev"

# Correspondance en-têtes de fichier (FR/EN, insensible à la casse) -> colonnes du modèle
COLUMN_ALIASES = {
    'business_object': ['objet metier', 'objet métier', 'objet', 'business_object', 'business object'],
    'rule_name': ['nom de la regle', 'nom de la règle', 'regle', 'règle', 'rule_name', 'rule', 'nom'],
    'source_table': ['table source', 'source_table', 'source table'],
    'source_field': ['champ source', 'source_field', 'source field', 'colonne source'],
    'transformation': ['transformation', 'regle de gestion', 'règle de gestion', 'transformation_rule'],
    'target_table': ['table cible', 'target_table', 'target table'],
    'target_field': ['champ cible', 'target_field', 'target field', 'colonne cible'],
    'description': ['description', 'commentaire', 'notes', 'detail', 'détail'],
    'is_active': ['active', 'actif', 'is_active', 'statut'],
}

# Ordre des colonnes pour l'export / le modèle Excel
TEMPLATE_COLUMNS = [
    ('business_object', 'Objet métier'),
    ('rule_name', 'Nom de la règle'),
    ('source_table', 'Table source'),
    ('source_field', 'Champ source'),
    ('transformation', 'Transformation'),
    ('target_table', 'Table cible'),
    ('target_field', 'Champ cible'),
    ('description', 'Description'),
    ('is_active', 'Active'),
]


def _normalize_header(value):
    """Normalise un en-tête de colonne pour la correspondance (minuscule, sans accents superflus)."""
    return str(value).strip().lower()


def _build_header_map(columns):
    """Construit un mapping {nom_colonne_fichier -> champ_modele} à partir des en-têtes du fichier."""
    header_map = {}
    for col in columns:
        norm = _normalize_header(col)
        for field, aliases in COLUMN_ALIASES.items():
            if norm in aliases:
                header_map[col] = field
                break
    return header_map


def _parse_bool(value, default=True):
    if value is None:
        return default
    if isinstance(value, bool):
        return value
    return str(value).strip().lower() in ('true', 'vrai', 'oui', 'yes', '1', 'actif', 'active')


@business_rules_blueprint.route('/business-rules', methods=['GET'])
def get_business_rules():
    """Liste les règles de gestion avec filtres (objet métier, statut, recherche)."""
    try:
        business_object = request.args.get('business_object', '')
        status = request.args.get('status', 'all')  # 'active' | 'inactive' | 'all'
        search = request.args.get('search', '')

        query = BusinessRule.query

        if business_object:
            query = query.filter(BusinessRule.business_object == business_object)
        if status == 'active':
            query = query.filter(BusinessRule.is_active == True)  # noqa: E712
        elif status == 'inactive':
            query = query.filter(BusinessRule.is_active == False)  # noqa: E712

        if search:
            term = f"%{search}%"
            query = query.filter(
                db.or_(
                    BusinessRule.business_object.ilike(term),
                    BusinessRule.rule_name.ilike(term),
                    BusinessRule.source_table.ilike(term),
                    BusinessRule.source_field.ilike(term),
                    BusinessRule.transformation.ilike(term),
                    BusinessRule.target_table.ilike(term),
                    BusinessRule.target_field.ilike(term),
                    BusinessRule.description.ilike(term),
                )
            )

        query = query.order_by(BusinessRule.business_object.asc(), BusinessRule.rule_name.asc())
        rules = [r.to_dict() for r in query.all()]

        return jsonify({'rules': rules, 'total': len(rules)}), 200

    except Exception as e:
        current_app.logger.error(f"Erreur lors de la récupération des règles de gestion: {str(e)}")
        return jsonify({"error": "Erreur lors de la récupération des règles de gestion"}), 500


@business_rules_blueprint.route('/business-rules/objects', methods=['GET'])
def get_business_objects():
    """Renvoie la liste des objets métier distincts (pour les filtres)."""
    try:
        rows = db.session.query(BusinessRule.business_object).distinct().all()
        objects = sorted({r[0] for r in rows if r[0]})
        return jsonify({'objects': objects}), 200
    except Exception as e:
        current_app.logger.error(f"Erreur lors de la récupération des objets métier: {str(e)}")
        return jsonify({"error": "Erreur lors de la récupération des objets métier"}), 500


@business_rules_blueprint.route('/business-rules/<int:rule_id>', methods=['GET'])
def get_business_rule(rule_id):
    """Récupère une règle de gestion par son ID."""
    try:
        rule = BusinessRule.query.get(rule_id)
        if not rule:
            return jsonify({"error": "Règle non trouvée"}), 404
        return jsonify(rule.to_dict()), 200
    except Exception as e:
        current_app.logger.error(f"Erreur lors de la récupération de la règle {rule_id}: {str(e)}")
        return jsonify({"error": "Erreur lors de la récupération de la règle"}), 500


@business_rules_blueprint.route('/business-rules', methods=['POST'])
def create_business_rule():
    """Crée une nouvelle règle de gestion."""
    try:
        data = request.get_json()
        if not data:
            return jsonify({"error": "Données manquantes"}), 400

        for field in ('business_object', 'rule_name'):
            if not data.get(field):
                return jsonify({"error": f"Le champ {field} est obligatoire"}), 400

        data['created_by'] = DEV_USER
        data['updated_by'] = DEV_USER

        rule = BusinessRule.from_dict(data)
        db.session.add(rule)
        db.session.commit()

        return jsonify(rule.to_dict()), 201

    except IntegrityError as e:
        db.session.rollback()
        current_app.logger.error(f"Erreur d'intégrité lors de la création de la règle: {str(e)}")
        return jsonify({"error": "Conflit lors de la création de la règle"}), 409
    except Exception as e:
        db.session.rollback()
        current_app.logger.error(f"Erreur lors de la création de la règle: {str(e)}")
        return jsonify({"error": "Erreur lors de la création de la règle"}), 500


@business_rules_blueprint.route('/business-rules/<int:rule_id>', methods=['PUT'])
def update_business_rule(rule_id):
    """Met à jour une règle de gestion existante."""
    try:
        rule = BusinessRule.query.get(rule_id)
        if not rule:
            return jsonify({"error": "Règle non trouvée"}), 404

        data = request.get_json()
        if not data:
            return jsonify({"error": "Données manquantes"}), 400

        data['updated_by'] = DEV_USER
        updated = BusinessRule.from_dict(data, existing_rule=rule)
        db.session.commit()

        return jsonify(updated.to_dict()), 200

    except Exception as e:
        db.session.rollback()
        current_app.logger.error(f"Erreur lors de la mise à jour de la règle {rule_id}: {str(e)}")
        return jsonify({"error": "Erreur lors de la mise à jour de la règle"}), 500


@business_rules_blueprint.route('/business-rules/<int:rule_id>', methods=['DELETE'])
def delete_business_rule(rule_id):
    """Supprime une règle de gestion."""
    try:
        rule = BusinessRule.query.get(rule_id)
        if not rule:
            return jsonify({"error": "Règle non trouvée"}), 404

        db.session.delete(rule)
        db.session.commit()
        return jsonify({"message": "Règle supprimée"}), 200

    except Exception as e:
        db.session.rollback()
        current_app.logger.error(f"Erreur lors de la suppression de la règle {rule_id}: {str(e)}")
        return jsonify({"error": "Erreur lors de la suppression de la règle"}), 500


@business_rules_blueprint.route('/business-rules/template', methods=['GET'])
def download_template():
    """Génère un modèle Excel (.xlsx) avec les en-têtes attendus et un exemple."""
    try:
        import pandas as pd

        headers = [label for _, label in TEMPLATE_COLUMNS]
        example = [
            'Client', 'Mapping numéro client', 'KNA1', 'KUNNR',
            'Concaténation préfixe + code', 'CUSTOMER_INFO', 'CUSTOMER_ID',
            'Identifiant unique du client IFS', 'Oui'
        ]
        df = pd.DataFrame([example], columns=headers)

        output = io.BytesIO()
        with pd.ExcelWriter(output, engine='openpyxl') as writer:
            df.to_excel(writer, index=False, sheet_name='Règles de gestion')
        output.seek(0)

        return send_file(
            output,
            mimetype='application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
            as_attachment=True,
            download_name='modele_regles_gestion.xlsx'
        )
    except Exception as e:
        current_app.logger.error(f"Erreur lors de la génération du modèle: {str(e)}")
        return jsonify({"error": "Erreur lors de la génération du modèle"}), 500


@business_rules_blueprint.route('/business-rules/import', methods=['POST'])
def import_business_rules():
    """Importe des règles de gestion depuis un fichier Excel (.xlsx/.xls) ou CSV."""
    try:
        import pandas as pd

        if 'file' not in request.files:
            return jsonify({"error": "Aucun fichier fourni"}), 400

        file = request.files['file']
        if not file or not file.filename:
            return jsonify({"error": "Aucun fichier fourni"}), 400

        filename = file.filename.lower()

        # Lecture du fichier dans un DataFrame
        if filename.endswith('.csv'):
            df = pd.read_csv(file, sep=None, engine='python', dtype=str)
        elif filename.endswith('.xlsx'):
            df = pd.read_excel(file, engine='openpyxl', dtype=str)
        elif filename.endswith('.xls'):
            df = pd.read_excel(file, dtype=str)
        else:
            return jsonify({"error": "Format non supporté (attendu: .xlsx, .xls ou .csv)"}), 400

        if df.empty:
            return jsonify({"error": "Le fichier ne contient aucune ligne"}), 400

        header_map = _build_header_map(df.columns)

        if 'business_object' not in header_map.values() or 'rule_name' not in header_map.values():
            return jsonify({
                "error": "Colonnes obligatoires manquantes: 'Objet métier' et 'Nom de la règle'"
            }), 400

        created, updated, failed = 0, 0, 0
        errors = []

        for idx, row in df.iterrows():
            try:
                data = {}
                for col, field in header_map.items():
                    value = row[col]
                    if pd.isna(value):
                        value = None
                    elif isinstance(value, str):
                        value = value.strip() or None
                    data[field] = value

                if 'is_active' in data:
                    data['is_active'] = _parse_bool(data.get('is_active'))

                if not data.get('business_object') or not data.get('rule_name'):
                    failed += 1
                    errors.append(f"Ligne {idx + 2}: 'Objet métier' et 'Nom de la règle' obligatoires")
                    continue

                existing = BusinessRule.query.filter_by(
                    business_object=data['business_object'],
                    rule_name=data['rule_name']
                ).first()

                if existing:
                    data['updated_by'] = DEV_USER
                    BusinessRule.from_dict(data, existing_rule=existing)
                    updated += 1
                else:
                    data['created_by'] = DEV_USER
                    data['updated_by'] = DEV_USER
                    db.session.add(BusinessRule.from_dict(data))
                    created += 1

            except Exception as row_error:
                failed += 1
                errors.append(f"Ligne {idx + 2}: {str(row_error)}")

        db.session.commit()

        return jsonify({
            "message": f"Import terminé : {created} créée(s), {updated} mise(s) à jour, {failed} échec(s)",
            "created": created,
            "updated": updated,
            "failed": failed,
            "errors": errors[:50],
        }), 200

    except Exception as e:
        db.session.rollback()
        current_app.logger.error(f"Erreur lors de l'import des règles de gestion: {str(e)}")
        return jsonify({"error": "Erreur lors de l'import des règles de gestion"}), 500
