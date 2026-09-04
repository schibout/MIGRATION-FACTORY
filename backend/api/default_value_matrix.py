"""Matrice conditionnelle Site x Famille (migration 052).

Deux volets, meme cle de resolution (contract, part_family) :
  * /config/matrix/values     -> public.etl_default_value_matrix
    valeur par defaut d'une colonne selon le site et la famille d'article,
    au-dessus de la constante de /config/default-values.
  * /config/matrix/part-types -> public.etl_part_type_matrix
    quelles tables creer pour un article (sales_part / purchase_part /
    manuf_part_attribute) selon son site et sa famille.

Un `contract` ou un `part_family` a NULL est un joker : il s'applique a toutes
les valeurs. La resolution prend la ligne la plus specifique
(site + famille > site > famille > joker), cf. public.get_default_value_ctx().
"""
from flask import Blueprint, request, jsonify, current_app
from flask_jwt_extended import jwt_required, get_jwt_identity
from sqlalchemy import text, cast, or_, Integer
from sqlalchemy.exc import SQLAlchemyError, IntegrityError

from models import db, EtlDefaultValue, EtlDefaultValueMatrix, EtlPartTypeMatrix

matrix_blueprint = Blueprint('default_value_matrix', __name__)

# Tables cibles du routage de creation (volet 2). Cette liste correspond aux
# gardes COALESCE(get_part_type_matrix(...), TRUE) presents dans les procedures
# sql/articlePhl/alimenter_*_phl.sql : y ajouter une table sans ajouter le garde
# correspondant cote SQL n'aurait aucun effet.
PART_TYPE_TABLES = [
    {'target_table': 'clean_data.sales_part', 'libelle': 'Article vendu (sales_part)'},
    {'target_table': 'clean_data.purchase_part', 'libelle': 'Article achete (purchase_part)'},
    {'target_table': 'clean_data.manuf_part_attribute', 'libelle': 'Article fabrique (manuf_part_attribute)'},
]

SITES_REPLI = ['SJ', 'CS']


def _nettoyer(valeur):
    """'' et 'null' venant du front -> None (joker)."""
    if valeur is None:
        return None
    valeur = str(valeur).strip()
    return valeur or None


def _erreur_sql(e, contexte, repli):
    """Le trigger de validation (22P02) et la violation d'unicite portent un
    message utile pour l'utilisateur : les remonter plutot qu'un 500 opaque."""
    pgcode = getattr(getattr(e, 'orig', None), 'pgcode', None)
    if pgcode == '22P02':
        diag = getattr(getattr(e, 'orig', None), 'diag', None)
        message = getattr(diag, 'message_primary', None) or str(e.orig)
        return jsonify({"error": message}), 400
    if pgcode == '23505':
        return jsonify({
            "error": "Une regle existe deja pour ce couple (site, famille) : modifiez-la au lieu d'en creer une seconde."
        }), 409
    current_app.logger.error(f"{contexte}: {e}")
    return jsonify({"error": repli}), 500


# ===========================================================================
# Metadonnees de l'ecran
# ===========================================================================
@matrix_blueprint.route('/matrix/meta', methods=['GET'])
@jwt_required()
def matrix_meta():
    """Sites, familles d'articles, tables/colonnes eligibles.

    Les sites et les familles sont lus dans les donnees reelles (et non
    codes en dur) pour que l'ecran suive le fichier PHL charge.
    """
    try:
        try:
            sites = [r[0] for r in db.session.execute(text(
                "SELECT DISTINCT contract FROM clean_data.inventory_part "
                "WHERE contract IS NOT NULL ORDER BY 1"
            ))]
        except SQLAlchemyError:
            db.session.rollback()
            sites = []
        if not sites:
            sites = SITES_REPLI

        try:
            # v_phl_article_retenu et non phl_article : la vue applique deja les
            # exclusions du perimetre (famille 19 = lingots, non reprise).
            familles = [r[0] for r in db.session.execute(text(
                'SELECT DISTINCT NULLIF(TRIM("FAMILLE"), \'\') AS famille '
                'FROM raw_data.v_phl_article_retenu '
                'WHERE NULLIF(TRIM("FAMILLE"), \'\') IS NOT NULL ORDER BY 1'
            ))]
        except SQLAlchemyError:
            db.session.rollback()
            familles = []

        # Colonnes eligibles : celles qui ont deja une constante parametree.
        # La matrice se pose au-dessus d'elles, elle n'introduit pas de
        # nouvelle colonne cible.
        cibles = [
            {'module': r[0], 'table_cible': r[1], 'colonne': r[2], 'variante': r[3]}
            for r in db.session.query(
                EtlDefaultValue.module, EtlDefaultValue.table_cible,
                EtlDefaultValue.colonne, EtlDefaultValue.variante
            ).distinct().order_by(
                EtlDefaultValue.table_cible, EtlDefaultValue.colonne, EtlDefaultValue.variante
            )
        ]

        return jsonify({
            'sites': sites,
            'familles': familles,
            'cibles': cibles,
            'part_type_tables': PART_TYPE_TABLES,
        }), 200
    except SQLAlchemyError as e:
        db.session.rollback()
        current_app.logger.error(f"Erreur meta matrice: {e}")
        return jsonify({"error": "Erreur lors de la recuperation des metadonnees de la matrice"}), 500


# ===========================================================================
# Volet 1 : valeurs par defaut site x famille
# ===========================================================================
@matrix_blueprint.route('/matrix/values', methods=['GET'])
@jwt_required()
def list_matrix_values():
    """Regles de la matrice, filtrables par table cible / colonne / variante."""
    try:
        query = EtlDefaultValueMatrix.query
        if request.args.get('table_cible'):
            query = query.filter(EtlDefaultValueMatrix.table_cible == request.args['table_cible'])
        if request.args.get('colonne'):
            query = query.filter(EtlDefaultValueMatrix.colonne == request.args['colonne'])
        if request.args.get('variante'):
            query = query.filter(EtlDefaultValueMatrix.variante == request.args['variante'])
        if request.args.get('module'):
            query = query.filter(EtlDefaultValueMatrix.module == request.args['module'])
        rows = query.order_by(
            EtlDefaultValueMatrix.table_cible,
            EtlDefaultValueMatrix.colonne,
            EtlDefaultValueMatrix.contract,
            EtlDefaultValueMatrix.part_family,
        ).all()
        return jsonify({'values': [r.to_dict() for r in rows], 'total': len(rows)}), 200
    except SQLAlchemyError as e:
        db.session.rollback()
        current_app.logger.error(f"Erreur liste matrice: {e}")
        return jsonify({"error": "Erreur lors de la recuperation de la matrice"}), 500


@matrix_blueprint.route('/matrix/values', methods=['POST'])
@jwt_required()
def create_matrix_value():
    """Cree une regle. Si la cellule (site, famille) existe deja, elle est
    mise a jour : l'ecran est une grille, l'utilisateur y voit une cellule,
    pas une ligne technique."""
    data = request.get_json() or {}
    for champ in ('table_cible', 'colonne'):
        if not data.get(champ):
            return jsonify({"error": f"Champ obligatoire manquant : {champ}"}), 400

    type_valeur = data.get('type_valeur', 'CONSTANTE')
    if type_valeur not in ('CONSTANTE', 'NULL'):
        return jsonify({"error": "type_valeur doit etre CONSTANTE ou NULL"}), 400

    contract = _nettoyer(data.get('contract'))
    part_family = _nettoyer(data.get('part_family'))
    variante = _nettoyer(data.get('variante')) or 'STANDARD'

    try:
        existante = EtlDefaultValueMatrix.query.filter_by(
            table_cible=data['table_cible'], colonne=data['colonne'],
            variante=variante, contract=contract, part_family=part_family
        ).first()

        if existante is not None:
            existante.type_valeur = type_valeur
            existante.valeur = None if type_valeur == 'NULL' else data.get('valeur')
            existante.description = data.get('description', existante.description)
            existante.is_active = bool(data.get('is_active', True))
            existante.updated_by = get_jwt_identity()
            db.session.commit()
            return jsonify(existante.to_dict()), 200

        regle = EtlDefaultValueMatrix(
            module=data.get('module') or 'articlePhl',
            table_cible=data['table_cible'],
            colonne=data['colonne'],
            contract=contract,
            part_family=part_family,
            variante=variante,
            type_valeur=type_valeur,
            valeur=None if type_valeur == 'NULL' else data.get('valeur'),
            description=data.get('description'),
            is_active=bool(data.get('is_active', True)),
            created_by=get_jwt_identity(),
        )
        db.session.add(regle)
        db.session.commit()
        return jsonify(regle.to_dict()), 201
    except (SQLAlchemyError, IntegrityError) as e:
        db.session.rollback()
        return _erreur_sql(e, "Erreur creation regle matrice", "Erreur lors de la creation de la regle")


@matrix_blueprint.route('/matrix/values/<int:value_id>', methods=['PUT'])
@jwt_required()
def update_matrix_value(value_id):
    """Champs modifiables : valeur, type_valeur, description, is_active.
    La cle (table, colonne, site, famille, variante) n'est pas modifiable :
    supprimer la regle et en creer une autre."""
    regle = EtlDefaultValueMatrix.query.get(value_id)
    if regle is None:
        return jsonify({"error": "Regle introuvable"}), 404

    data = request.get_json() or {}
    try:
        if 'type_valeur' in data:
            if data['type_valeur'] not in ('CONSTANTE', 'NULL'):
                return jsonify({"error": "type_valeur doit etre CONSTANTE ou NULL"}), 400
            regle.type_valeur = data['type_valeur']
        if 'valeur' in data:
            regle.valeur = None if regle.type_valeur == 'NULL' else data['valeur']
        if 'description' in data:
            regle.description = data['description']
        if 'is_active' in data:
            regle.is_active = bool(data['is_active'])
        regle.updated_by = get_jwt_identity()
        db.session.commit()
        return jsonify(regle.to_dict()), 200
    except SQLAlchemyError as e:
        db.session.rollback()
        return _erreur_sql(e, f"Erreur maj regle matrice {value_id}", "Erreur lors de la mise a jour")


@matrix_blueprint.route('/matrix/values/<int:value_id>', methods=['DELETE'])
@jwt_required()
def delete_matrix_value(value_id):
    """Supprime la regle : la cellule retombe sur la regle moins specifique,
    et in fine sur la constante de /config/default-values."""
    regle = EtlDefaultValueMatrix.query.get(value_id)
    if regle is None:
        return jsonify({"error": "Regle introuvable"}), 404
    try:
        db.session.delete(regle)
        db.session.commit()
        return jsonify({"deleted": value_id}), 200
    except SQLAlchemyError as e:
        db.session.rollback()
        current_app.logger.error(f"Erreur suppression regle matrice {value_id}: {e}")
        return jsonify({"error": "Erreur lors de la suppression"}), 500


@matrix_blueprint.route('/matrix/resolve', methods=['GET'])
@jwt_required()
def resolve_matrix_value():
    """Valeur effectivement appliquee par l'ETL pour un couple (site, famille),
    et d'ou elle vient. Sert a verifier une regle sans relancer un chargement."""
    table_cible = request.args.get('table_cible')
    colonne = request.args.get('colonne')
    if not table_cible or not colonne:
        return jsonify({"error": "table_cible et colonne sont obligatoires"}), 400
    contract = _nettoyer(request.args.get('contract'))
    part_family = _nettoyer(request.args.get('part_family'))
    variante = _nettoyer(request.args.get('variante')) or 'STANDARD'

    try:
        row = db.session.execute(text(
            "SELECT public.get_default_value_ctx(:t, :c, :s, :f, :v) AS valeur_effective, "
            "       public.get_default_value(:t, :c, :v)             AS constante"
        ), {'t': table_cible, 'c': colonne, 's': contract, 'f': part_family, 'v': variante}).mappings().first()

        regle = EtlDefaultValueMatrix.query.filter(
            EtlDefaultValueMatrix.table_cible == table_cible,
            EtlDefaultValueMatrix.colonne == colonne,
            EtlDefaultValueMatrix.variante == variante,
            EtlDefaultValueMatrix.is_active.is_(True),
            or_(EtlDefaultValueMatrix.contract.is_(None), EtlDefaultValueMatrix.contract == contract),
            or_(EtlDefaultValueMatrix.part_family.is_(None), EtlDefaultValueMatrix.part_family == part_family),
        ).order_by(
            # Meme ordre que la clause ORDER BY de public.get_default_value_ctx()
            # (site + famille > site > famille > joker) : les deux doivent
            # designer la meme ligne.
            (cast(EtlDefaultValueMatrix.contract.isnot(None), Integer)
             + cast(EtlDefaultValueMatrix.part_family.isnot(None), Integer)).desc(),
            cast(EtlDefaultValueMatrix.contract.isnot(None), Integer).desc(),
        ).first()

        return jsonify({
            'valeur_effective': row['valeur_effective'] if row else None,
            'constante': row['constante'] if row else None,
            'origine': 'MATRICE' if regle is not None else 'CONSTANTE',
            'regle': regle.to_dict() if regle is not None else None,
        }), 200
    except SQLAlchemyError as e:
        db.session.rollback()
        current_app.logger.error(f"Erreur resolution matrice: {e}")
        return jsonify({"error": "Erreur lors de la resolution de la valeur"}), 500


# ===========================================================================
# Volet 2 : routage de creation (sales_part / purchase_part / manuf_part_attribute)
# ===========================================================================
@matrix_blueprint.route('/matrix/part-types', methods=['GET'])
@jwt_required()
def list_part_types():
    try:
        query = EtlPartTypeMatrix.query
        if request.args.get('target_table'):
            query = query.filter(EtlPartTypeMatrix.target_table == request.args['target_table'])
        rows = query.order_by(
            EtlPartTypeMatrix.target_table,
            EtlPartTypeMatrix.contract,
            EtlPartTypeMatrix.part_family,
        ).all()
        return jsonify({
            'part_types': [r.to_dict() for r in rows],
            'total': len(rows),
            'tables': PART_TYPE_TABLES,
        }), 200
    except SQLAlchemyError as e:
        db.session.rollback()
        current_app.logger.error(f"Erreur liste routage: {e}")
        return jsonify({"error": "Erreur lors de la recuperation du routage"}), 500


@matrix_blueprint.route('/matrix/part-types', methods=['POST'])
@jwt_required()
def upsert_part_type():
    """Pose (ou remplace) le flag de creation d'une cellule (site, famille)."""
    data = request.get_json() or {}
    target_table = data.get('target_table')
    if not target_table:
        return jsonify({"error": "Champ obligatoire manquant : target_table"}), 400
    if target_table not in [t['target_table'] for t in PART_TYPE_TABLES]:
        return jsonify({
            "error": f"Table cible non geree par le routage : {target_table}. "
                     "Ajouter d'abord le garde get_part_type_matrix dans la procedure de chargement."
        }), 400
    if 'should_create' not in data:
        return jsonify({"error": "Champ obligatoire manquant : should_create"}), 400

    contract = _nettoyer(data.get('contract'))
    part_family = _nettoyer(data.get('part_family'))

    try:
        regle = EtlPartTypeMatrix.query.filter_by(
            target_table=target_table, contract=contract, part_family=part_family
        ).first()
        if regle is not None:
            regle.should_create = bool(data['should_create'])
            if 'description' in data:
                regle.description = data['description']
            if 'is_active' in data:
                regle.is_active = bool(data['is_active'])
            regle.updated_by = get_jwt_identity()
            db.session.commit()
            return jsonify(regle.to_dict()), 200

        regle = EtlPartTypeMatrix(
            target_table=target_table,
            contract=contract,
            part_family=part_family,
            should_create=bool(data['should_create']),
            description=data.get('description'),
            is_active=bool(data.get('is_active', True)),
            created_by=get_jwt_identity(),
        )
        db.session.add(regle)
        db.session.commit()
        return jsonify(regle.to_dict()), 201
    except (SQLAlchemyError, IntegrityError) as e:
        db.session.rollback()
        return _erreur_sql(e, "Erreur upsert routage", "Erreur lors de l'enregistrement du routage")


@matrix_blueprint.route('/matrix/part-types/<int:rule_id>', methods=['DELETE'])
@jwt_required()
def delete_part_type(rule_id):
    regle = EtlPartTypeMatrix.query.get(rule_id)
    if regle is None:
        return jsonify({"error": "Regle introuvable"}), 404
    try:
        db.session.delete(regle)
        db.session.commit()
        return jsonify({"deleted": rule_id}), 200
    except SQLAlchemyError as e:
        db.session.rollback()
        current_app.logger.error(f"Erreur suppression routage {rule_id}: {e}")
        return jsonify({"error": "Erreur lors de la suppression"}), 500
