# -*- coding: utf-8 -*-
"""
API des contrats d'interface SAP -> IFS.

Remplace le classeur Excel fige : la base porte a la fois la definition
technique du mapping et l'etat de validation metier, l'export Excel devient une
generation a la demande et l'import un retour possible pour les relecteurs sans
compte applicatif.

Roles (models/user.py) :
  - lecture                      : tout utilisateur authentifie
  - validate_contracts (op+adm)  : valider, commenter, signer une table
  - manage_contracts   (admin)   : CRUD de la definition, import Excel,
                                   levee du masquage des donnees sensibles
"""

import io
from datetime import datetime

import psycopg2.extras
from flask import Blueprint, current_app, jsonify, request, send_file
from flask_jwt_extended import get_jwt_identity, jwt_required
from psycopg2 import sql
from sqlalchemy.exc import SQLAlchemyError

from config.database import get_db_connection
from models import (
    InterfaceContractColumn,
    InterfaceContractEvent,
    InterfaceContractTable,
    InterfaceContractValidation,
    User,
    db,
)
from models.interface_contract import EVENT_TYPES, ROW_TYPES, STATUTS
from services.interface_contract_excel import (
    build_contract_workbook,
    parse_contract_workbook,
)
from utils.auth_decorators import require_permission

interface_contracts_blueprint = Blueprint('interface_contracts', __name__)

# Nombre de valeurs distinctes remontees par l'apercu de donnees reelles.
TAILLE_ECHANTILLON = 20

# Colonnes dont l'echantillon est masque par defaut : donnees SAP bancaires ou
# fiscales (cf. proposition §7). Un admin peut lever le masquage (unmask=true).
MOTIFS_SENSIBLES = (
    'iban', 'bic', 'swift', 'bankn', 'bankl', 'compte_banc', 'account',
    'stcd', 'stceg', 'siret', 'siren', 'tax_id', 'tva', 'fiscal',
)

# Colonnes techniques d'audit : presentes dans toutes les tables cibles, elles
# ne relevent pas d'une validation metier et ne sont donc pas comptees comme
# « non documentees » dans l'ecart de couverture.
COLONNES_AUDIT = frozenset((
    'created_by', 'updated_by', 'created_timestamp', 'updated_timestamp',
    'is_deleted', 'rowversion', 'rowkey', 'rowstate',
))


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
def _maintenant():
    """Horodatage pris sur l'horloge de PostgreSQL, jamais sur celle de Python.

    L'obsolescence d'une validation se calcule en comparant
    interface_contract_column.updated_at (pose par un trigger PostgreSQL, donc
    CURRENT_TIMESTAMP du serveur) a validation.validated_at. Avec un
    datetime.utcnow() cote Python, le decalage de fuseau du serveur de base
    (UTC+2) suffisait a rendre TOUTE validation immediatement « obsolete ».
    Les deux dates doivent venir de la meme horloge.
    """
    return db.func.current_timestamp()


def _utilisateur_courant():
    return User.query.get(get_jwt_identity())


def _auteur():
    """Nom lisible de l'utilisateur courant (le JWT ne porte que son UUID).

    Les contrats sont relus par le metier : un UUID dans « validé par » ou dans
    le fil de discussion serait inexploitable.
    """
    utilisateur = _utilisateur_courant()
    return (utilisateur.username if utilisateur else str(get_jwt_identity()))[:50]


def _peut(permission):
    utilisateur = _utilisateur_courant()
    return bool(utilisateur and utilisateur.has_permission(permission))


def _colonnes_cibles(target_column):
    """« supplier_id / supplier_legacy_sap_id » -> ['supplier_id', ...].

    Le classeur regroupe sur une meme ligne les colonnes qui partagent la meme
    regle : la couverture et l'apercu doivent regarder chacune d'elles.
    """
    if not target_column:
        return []
    resolues = []
    for partie in (p.strip() for p in str(target_column).split('/')):
        if not partie:
            continue
        # « conditions_paiement_compta / _achats » : le classeur abrege la
        # seconde colonne en ne gardant que le suffixe qui la distingue.
        if partie.startswith('_') and resolues:
            partie = resolues[-1].rsplit('_', 1)[0] + partie
        resolues.append(partie)
    return resolues


def _est_sensible(nom_colonne):
    nom = (nom_colonne or '').lower()
    return any(motif in nom for motif in MOTIFS_SENSIBLES)


def _masquer(valeur):
    """Ne laisse que les 2 premiers et 2 derniers caracteres."""
    if valeur is None:
        return None
    texte = str(valeur)
    if len(texte) <= 4:
        return '*' * len(texte)
    return '%s%s%s' % (texte[:2], '*' * (len(texte) - 4), texte[-2:])


def _journaliser(colonne_id, event_type, auteur, ancien_statut=None,
                 nouveau_statut=None, commentaire=None):
    if event_type not in EVENT_TYPES:
        raise ValueError('event_type inconnu: %s' % event_type)
    db.session.add(InterfaceContractEvent(
        contract_column_id=colonne_id,
        event_type=event_type,
        ancien_statut=ancien_statut,
        nouveau_statut=nouveau_statut,
        commentaire=commentaire,
        auteur=auteur,
    ))


def _serialiser(row):
    """RealDictRow d'une vue -> dict JSON (dates ISO, Decimal -> float)."""
    resultat = {}
    for cle, valeur in row.items():
        if hasattr(valeur, 'isoformat'):
            resultat[cle] = valeur.isoformat()
        elif hasattr(valeur, 'quantize'):  # Decimal (pct_valide)
            resultat[cle] = float(valeur)
        else:
            resultat[cle] = valeur
    return resultat


def _colonnes_reelles(cursor, schema, table):
    cursor.execute(
        """
        SELECT column_name, data_type, character_maximum_length,
               numeric_precision, is_nullable
        FROM information_schema.columns
        WHERE table_schema = %s AND table_name = %s
        ORDER BY ordinal_position
        """,
        (schema, table),
    )
    return cursor.fetchall()


def _libelle_type(row):
    libelle = row['data_type']
    if row['character_maximum_length']:
        return '%s(%s)' % (libelle, row['character_maximum_length'])
    if row['numeric_precision'] and libelle == 'numeric':
        return '%s(%s)' % (libelle, row['numeric_precision'])
    return libelle


def _echantillon(cursor, schema, table, colonne, demasquer):
    """N valeurs distinctes non nulles d'une colonne, ou None si la colonne
    n'existe pas. Les identifiants sont valides contre information_schema AVANT
    d'etre injectes comme identifiants SQL (meme garde-fou que data_browser)."""
    cursor.execute(
        """
        SELECT 1 FROM information_schema.columns
        WHERE table_schema = %s AND table_name = %s AND column_name = %s
        """,
        (schema, table, colonne),
    )
    if cursor.fetchone() is None:
        return None

    requete = sql.SQL(
        'SELECT DISTINCT {col}::text AS valeur FROM {tbl} '
        'WHERE {col} IS NOT NULL ORDER BY 1 LIMIT %s'
    ).format(col=sql.Identifier(colonne),
             tbl=sql.SQL('{}.{}').format(sql.Identifier(schema), sql.Identifier(table)))
    cursor.execute(requete, (TAILLE_ECHANTILLON,))
    valeurs = [r['valeur'] for r in cursor.fetchall()]

    masque = _est_sensible(colonne) and not demasquer
    if masque:
        valeurs = [_masquer(v) for v in valeurs]
    return {
        'schema': schema,
        'table': table,
        'column': colonne,
        'values': valeurs,
        'masked': masque,
    }


def _valeurs_defaut(cursor, schema_cible, table_cible, variante):
    """Detail des valeurs par defaut resumees par une ligne CONFIG_SUMMARY."""
    cursor.execute(
        """
        SELECT colonne, variante, type_valeur, valeur, description, is_active
        FROM public.etl_default_values
        WHERE table_cible = %s
          AND (%s IS NULL OR variante = ANY (string_to_array(%s, '/')))
        ORDER BY colonne, variante
        """,
        ('%s.%s' % (schema_cible, table_cible), variante, variante),
    )
    return [dict(r) for r in cursor.fetchall()]


def _charger_colonne(colonne_id):
    colonne = InterfaceContractColumn.query.get(colonne_id)
    if colonne is None:
        return None, None
    return colonne, InterfaceContractTable.query.get(colonne.contract_table_id)


# ---------------------------------------------------------------------------
# Lecture
# ---------------------------------------------------------------------------
@interface_contracts_blueprint.route('/meta', methods=['GET'])
@jwt_required()
def meta():
    """Modules disponibles + droits de l'utilisateur courant (pilote l'UI)."""
    try:
        modules = [
            r[0] for r in db.session.query(InterfaceContractTable.module)
            .distinct().order_by(InterfaceContractTable.module)
        ]
        return jsonify({
            'modules': modules,
            'statuts': list(STATUTS),
            'row_types': list(ROW_TYPES),
            'can_validate': _peut('validate_contracts'),
            'can_manage': _peut('manage_contracts'),
        }), 200
    except SQLAlchemyError as exc:
        current_app.logger.error('Erreur meta contrats: %s', exc)
        return jsonify({'error': 'Erreur lors de la récupération des métadonnées'}), 500


@interface_contracts_blueprint.route('/tables', methods=['GET'])
@jwt_required()
def liste_tables():
    """Tableau de bord : une ligne par table avec ses compteurs de validation."""
    try:
        module = request.args.get('module')
        with get_db_connection() as conn:
            cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
            if module:
                cursor.execute(
                    'SELECT * FROM public.v_interface_contract_summary '
                    'WHERE module = %s ORDER BY module, ordre', (module,))
            else:
                cursor.execute(
                    'SELECT * FROM public.v_interface_contract_summary '
                    'ORDER BY module, ordre')
            tables = [_serialiser(r) for r in cursor.fetchall()]
        return jsonify({'tables': tables, 'total': len(tables)}), 200
    except Exception as exc:
        current_app.logger.error('Erreur liste tables contrats: %s', exc, exc_info=True)
        return jsonify({'error': 'Erreur lors de la récupération des contrats'}), 500


@interface_contracts_blueprint.route('/tables/<int:table_id>/columns', methods=['GET'])
@jwt_required()
def liste_colonnes(table_id):
    """Detail d'une table : les lignes du contrat + leur validation.

    Filtres : statut, section, row_type, obsolete=true, search.
    """
    try:
        conditions = [sql.SQL('contract_table_id = %s')]
        params = [table_id]
        if request.args.get('statut'):
            conditions.append(sql.SQL('statut = %s'))
            params.append(request.args['statut'])
        if request.args.get('section'):
            conditions.append(sql.SQL('section = %s'))
            params.append(request.args['section'])
        if request.args.get('row_type'):
            conditions.append(sql.SQL('row_type = %s'))
            params.append(request.args['row_type'])
        if request.args.get('obsolete') == 'true':
            conditions.append(sql.SQL('validation_obsolete'))
        if request.args.get('search'):
            conditions.append(sql.SQL(
                '(target_column ILIKE %s OR COALESCE(source_expression, %s) ILIKE %s'
                ' OR COALESCE(transformation_rule, %s) ILIKE %s)'))
            motif = '%' + request.args['search'] + '%'
            params.extend([motif, '', motif, '', motif])

        requete = sql.SQL(
            'SELECT * FROM public.v_interface_contract WHERE {} ORDER BY sort_order'
        ).format(sql.SQL(' AND ').join(conditions))

        with get_db_connection() as conn:
            cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
            cursor.execute(
                'SELECT * FROM public.v_interface_contract_summary '
                'WHERE contract_table_id = %s', (table_id,))
            entete = cursor.fetchone()
            if entete is None:
                return jsonify({'error': 'Contrat introuvable'}), 404
            cursor.execute(requete, params)
            colonnes = [_serialiser(r) for r in cursor.fetchall()]

            # types reels de la table cible : le contrat ne les stocke pas,
            # ils sont lus dans la base pour ne jamais diverger
            types = {
                r['column_name']: _libelle_type(r)
                for r in _colonnes_reelles(cursor, entete['schema_cible'],
                                           entete['table_cible'])
            }
        for ligne in colonnes:
            trouves = [types.get(nom) for nom in _colonnes_cibles(ligne['target_column'])]
            ligne['type_longueur'] = ' / '.join(t for t in trouves if t) or None

        return jsonify({
            'table': _serialiser(entete),
            'columns': colonnes,
            'total': len(colonnes),
        }), 200
    except Exception as exc:
        current_app.logger.error('Erreur colonnes contrat %s: %s', table_id, exc, exc_info=True)
        return jsonify({'error': 'Erreur lors de la récupération du contrat'}), 500


@interface_contracts_blueprint.route('/tables/<int:table_id>/coverage', methods=['GET'])
@jwt_required()
def couverture(table_id):
    """Ecart entre la table cible REELLE et ce que le contrat documente.

    Deux listes : les colonnes de la table absentes du contrat (trous de
    documentation) et les colonnes citees par le contrat qui n'existent plus
    (contrat perime). C'est ce qu'un classeur fige ne peut pas faire.
    """
    contrat = InterfaceContractTable.query.get(table_id)
    if contrat is None:
        return jsonify({'error': 'Contrat introuvable'}), 404
    try:
        documentees = set()
        variantes = []
        for ligne in InterfaceContractColumn.query.filter_by(contract_table_id=table_id):
            if ligne.row_type == 'NOTE':
                continue
            if ligne.row_type == 'CONFIG_SUMMARY':
                variantes.append(ligne.default_value_variante)
                continue
            documentees.update(nom.lower() for nom in _colonnes_cibles(ligne.target_column))

        with get_db_connection() as conn:
            cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
            reelles = _colonnes_reelles(cursor, contrat.schema_cible, contrat.table_cible)
            # une ligne CONFIG_SUMMARY documente en bloc toutes les colonnes
            # parametrables de sa/ses variante(s) : on les developpe ici
            for variante in variantes:
                for dv in _valeurs_defaut(cursor, contrat.schema_cible,
                                          contrat.table_cible, variante):
                    documentees.add((dv['colonne'] or '').lower())

        if not reelles:
            return jsonify({
                'table': contrat.to_dict(),
                'table_existe': False,
                'non_documentees': [],
                'obsoletes': sorted(documentees),
                'nb_colonnes_reelles': 0,
                'nb_colonnes_documentees': len(documentees),
            }), 200

        noms_reels = {r['column_name'].lower() for r in reelles}
        non_documentees = [
            {'column_name': r['column_name'], 'type': _libelle_type(r),
             'is_nullable': r['is_nullable']}
            for r in reelles
            if r['column_name'].lower() not in documentees
            and r['column_name'].lower() not in COLONNES_AUDIT
        ]
        obsoletes = sorted(nom for nom in documentees if nom not in noms_reels)

        return jsonify({
            'table': contrat.to_dict(),
            'table_existe': True,
            'non_documentees': non_documentees,
            'obsoletes': obsoletes,
            'nb_colonnes_reelles': len(reelles),
            'nb_colonnes_documentees': len(documentees & noms_reels),
        }), 200
    except Exception as exc:
        current_app.logger.error('Erreur couverture %s: %s', table_id, exc, exc_info=True)
        return jsonify({'error': 'Erreur lors du calcul de couverture'}), 500


@interface_contracts_blueprint.route('/columns/<int:column_id>/sample', methods=['GET'])
@jwt_required()
def echantillon(column_id):
    """Apercu de donnees REELLES : la colonne SAP source et la/les colonne(s)
    cible(s), cote a cote. C'est le geste qui manque le plus au classeur : le
    metier lit « lfa1.name1 tronque a 100 » et voit tout de suite quels
    fournisseurs sont concernes."""
    colonne, contrat = _charger_colonne(column_id)
    if colonne is None:
        return jsonify({'error': 'Ligne de contrat introuvable'}), 404
    demasquer = request.args.get('unmask') == 'true' and _peut('manage_contracts')
    try:
        with get_db_connection() as conn:
            cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
            source = None
            if colonne.source_schema and colonne.source_table and colonne.source_column:
                source = _echantillon(cursor, colonne.source_schema, colonne.source_table,
                                      colonne.source_column, demasquer)
            cibles = []
            for nom in _colonnes_cibles(colonne.target_column):
                apercu = _echantillon(cursor, contrat.schema_cible, contrat.table_cible,
                                      nom, demasquer)
                if apercu:
                    cibles.append(apercu)
            valeurs_defaut = []
            if colonne.row_type == 'CONFIG_SUMMARY':
                valeurs_defaut = _valeurs_defaut(cursor, contrat.schema_cible,
                                                 contrat.table_cible,
                                                 colonne.default_value_variante)
        return jsonify({
            'column': colonne.to_dict(),
            'source': source,
            'targets': cibles,
            'default_values': valeurs_defaut,
            'limit': TAILLE_ECHANTILLON,
            'can_unmask': _peut('manage_contracts'),
        }), 200
    except Exception as exc:
        current_app.logger.error('Erreur échantillon %s: %s', column_id, exc, exc_info=True)
        return jsonify({'error': "Erreur lors de la lecture de l'échantillon"}), 500


@interface_contracts_blueprint.route('/columns/<int:column_id>/events', methods=['GET'])
@jwt_required()
def evenements(column_id):
    """Fil de discussion + historique des statuts d'une ligne."""
    colonne = InterfaceContractColumn.query.get(column_id)
    if colonne is None:
        return jsonify({'error': 'Ligne de contrat introuvable'}), 404
    evts = (InterfaceContractEvent.query
            .filter_by(contract_column_id=column_id)
            .order_by(InterfaceContractEvent.created_at.asc(),
                      InterfaceContractEvent.id.asc())
            .all())
    return jsonify({'events': [e.to_dict() for e in evts], 'total': len(evts)}), 200


# ---------------------------------------------------------------------------
# Validation metier
# ---------------------------------------------------------------------------
@interface_contracts_blueprint.route('/columns/<int:column_id>/validation', methods=['PUT'])
@require_permission('validate_contracts')
def valider(column_id):
    """Pose le statut metier d'une ligne et journalise le changement."""
    colonne = InterfaceContractColumn.query.get(column_id)
    if colonne is None:
        return jsonify({'error': 'Ligne de contrat introuvable'}), 404
    if colonne.row_type == 'NOTE':
        return jsonify({'error': "Une note n'est pas validable"}), 400

    donnees = request.get_json() or {}
    statut = donnees.get('statut')
    if statut not in STATUTS:
        return jsonify({'error': 'statut doit être parmi %s' % ', '.join(STATUTS)}), 400

    try:
        auteur = _auteur()
        validation = InterfaceContractValidation.query.filter_by(
            contract_column_id=column_id).first()
        ancien = validation.statut if validation else 'A_VALIDER'
        if validation is None:
            validation = InterfaceContractValidation(contract_column_id=column_id)
            db.session.add(validation)

        validation.statut = statut
        if 'remarque_metier' in donnees:
            validation.remarque_metier = donnees['remarque_metier'] or None
        validation.validated_by = auteur
        validation.validated_at = _maintenant()

        _journaliser(column_id, 'STATUT', auteur, ancien_statut=ancien,
                     nouveau_statut=statut,
                     commentaire=donnees.get('remarque_metier') or None)
        db.session.commit()
        db.session.refresh(validation)
        return jsonify(validation.to_dict()), 200
    except SQLAlchemyError as exc:
        db.session.rollback()
        current_app.logger.error('Erreur validation %s: %s', column_id, exc)
        return jsonify({'error': 'Erreur lors de la validation'}), 500


@interface_contracts_blueprint.route('/columns/<int:column_id>/comments', methods=['POST'])
@require_permission('validate_contracts')
def commenter(column_id):
    """Ajoute un message au fil de discussion tech <-> metier (sans toucher au
    statut : les allers-retours ne doivent pas se perdre)."""
    if InterfaceContractColumn.query.get(column_id) is None:
        return jsonify({'error': 'Ligne de contrat introuvable'}), 404
    texte = (request.get_json() or {}).get('commentaire')
    if not texte or not str(texte).strip():
        return jsonify({'error': 'Commentaire vide'}), 400
    try:
        _journaliser(column_id, 'COMMENTAIRE', _auteur(), commentaire=str(texte).strip())
        db.session.commit()
        evt = (InterfaceContractEvent.query
               .filter_by(contract_column_id=column_id)
               .order_by(InterfaceContractEvent.id.desc()).first())
        return jsonify(evt.to_dict()), 201
    except SQLAlchemyError as exc:
        db.session.rollback()
        current_app.logger.error('Erreur commentaire %s: %s', column_id, exc)
        return jsonify({'error': "Erreur lors de l'ajout du commentaire"}), 500


@interface_contracts_blueprint.route('/tables/<int:table_id>/sign', methods=['PUT'])
@require_permission('validate_contracts')
def signer(table_id):
    """« Bon pour accord » global sur une table — distinct du pourcentage
    calcule ligne a ligne, qui ne le remplace pas. sign=false de-signe."""
    contrat = InterfaceContractTable.query.get(table_id)
    if contrat is None:
        return jsonify({'error': 'Contrat introuvable'}), 404
    donnees = request.get_json() or {}
    try:
        if donnees.get('sign') is False:
            contrat.signe_par = None
            contrat.signe_le = None
        else:
            contrat.signe_par = _auteur()
            contrat.signe_le = _maintenant()
        db.session.commit()
        db.session.refresh(contrat)
        return jsonify(contrat.to_dict()), 200
    except SQLAlchemyError as exc:
        db.session.rollback()
        current_app.logger.error('Erreur signature %s: %s', table_id, exc)
        return jsonify({'error': 'Erreur lors de la signature'}), 500


@interface_contracts_blueprint.route('/tables/<int:table_id>/pilotage', methods=['PUT'])
@require_permission('validate_contracts')
def pilotage(table_id):
    """Responsable metier de la relecture et echeance."""
    contrat = InterfaceContractTable.query.get(table_id)
    if contrat is None:
        return jsonify({'error': 'Contrat introuvable'}), 404
    donnees = request.get_json() or {}
    try:
        if 'owner_metier' in donnees:
            contrat.owner_metier = donnees['owner_metier'] or None
        if 'date_limite' in donnees:
            valeur = donnees['date_limite']
            contrat.date_limite = (
                datetime.strptime(valeur, '%Y-%m-%d').date() if valeur else None
            )
        db.session.commit()
        return jsonify(contrat.to_dict()), 200
    except ValueError:
        db.session.rollback()
        return jsonify({'error': 'date_limite doit être au format AAAA-MM-JJ'}), 400
    except SQLAlchemyError as exc:
        db.session.rollback()
        current_app.logger.error('Erreur pilotage %s: %s', table_id, exc)
        return jsonify({'error': 'Erreur lors de la mise à jour'}), 500


# ---------------------------------------------------------------------------
# CRUD de la definition (partie technique)
# ---------------------------------------------------------------------------
CHAMPS_TABLE = ('module', 'schema_cible', 'table_cible', 'libelle', 'description',
                'source_procedure', 'ordre', 'owner_metier', 'is_active')

CHAMPS_COLONNE = ('section', 'target_column', 'field_label', 'systeme_source',
                  'source_schema', 'source_table', 'source_column',
                  'source_expression', 'transformation_rule',
                  'condition_application', 'exemple_valeur', 'row_type',
                  'default_value_column', 'default_value_variante', 'sort_order')


def _designer_si_besoin(contrat):
    """Une modification de la definition apres signature retire la signature :
    meme logique que l'obsolescence ligne a ligne, pour qu'un « bon pour
    accord » ne couvre jamais un contrat qui a bouge depuis."""
    if contrat and contrat.signe_le is not None:
        contrat.signe_par = None
        contrat.signe_le = None
        return True
    return False


@interface_contracts_blueprint.route('/tables', methods=['POST'])
@require_permission('manage_contracts')
def creer_table():
    donnees = request.get_json() or {}
    manquants = [c for c in ('module', 'table_cible', 'libelle') if not donnees.get(c)]
    if manquants:
        return jsonify({'error': 'Champs obligatoires manquants : %s'
                                 % ', '.join(manquants)}), 400
    if InterfaceContractTable.query.filter_by(
            module=donnees['module'], table_cible=donnees['table_cible']).first():
        return jsonify({'error': 'Un contrat existe déjà pour cette table'}), 409
    try:
        contrat = InterfaceContractTable(
            **{c: donnees.get(c) for c in CHAMPS_TABLE if c in donnees})
        contrat.schema_cible = donnees.get('schema_cible') or 'clean_data'
        contrat.ordre = donnees.get('ordre') or 0
        db.session.add(contrat)
        db.session.commit()
        return jsonify(contrat.to_dict()), 201
    except SQLAlchemyError as exc:
        db.session.rollback()
        current_app.logger.error('Erreur création contrat: %s', exc)
        return jsonify({'error': 'Erreur lors de la création du contrat'}), 500


@interface_contracts_blueprint.route('/tables/<int:table_id>', methods=['PUT'])
@require_permission('manage_contracts')
def modifier_table(table_id):
    contrat = InterfaceContractTable.query.get(table_id)
    if contrat is None:
        return jsonify({'error': 'Contrat introuvable'}), 404
    donnees = request.get_json() or {}
    try:
        for champ in CHAMPS_TABLE:
            if champ in donnees:
                setattr(contrat, champ, donnees[champ])
        db.session.commit()
        return jsonify(contrat.to_dict()), 200
    except SQLAlchemyError as exc:
        db.session.rollback()
        if getattr(getattr(exc, 'orig', None), 'pgcode', None) == '23505':
            return jsonify({'error': 'Un contrat existe déjà pour ce module '
                                     'et cette table'}), 409
        current_app.logger.error('Erreur modification contrat %s: %s', table_id, exc)
        return jsonify({'error': 'Erreur lors de la modification'}), 500


@interface_contracts_blueprint.route('/tables/<int:table_id>', methods=['DELETE'])
@require_permission('manage_contracts')
def supprimer_table(table_id):
    """Desactivation (is_active=false) : la relecture metier deja faite ne doit
    jamais partir a la poubelle par un clic."""
    contrat = InterfaceContractTable.query.get(table_id)
    if contrat is None:
        return jsonify({'error': 'Contrat introuvable'}), 404
    try:
        contrat.is_active = False
        db.session.commit()
        return jsonify({'message': 'Contrat désactivé', 'id': table_id}), 200
    except SQLAlchemyError as exc:
        db.session.rollback()
        current_app.logger.error('Erreur suppression contrat %s: %s', table_id, exc)
        return jsonify({'error': 'Erreur lors de la suppression'}), 500


@interface_contracts_blueprint.route('/columns', methods=['POST'])
@require_permission('manage_contracts')
def creer_colonne():
    donnees = request.get_json() or {}
    table_id = donnees.get('contract_table_id')
    contrat = InterfaceContractTable.query.get(table_id) if table_id else None
    if contrat is None:
        return jsonify({'error': 'contract_table_id invalide'}), 400
    if not donnees.get('target_column'):
        return jsonify({'error': 'target_column est obligatoire'}), 400
    if donnees.get('row_type') and donnees['row_type'] not in ROW_TYPES:
        return jsonify({'error': 'row_type doit être parmi %s' % ', '.join(ROW_TYPES)}), 400
    try:
        colonne = InterfaceContractColumn(
            contract_table_id=table_id,
            **{c: donnees.get(c) for c in CHAMPS_COLONNE if c in donnees})
        colonne.row_type = donnees.get('row_type') or 'COLUMN'
        colonne.default_value_variante = donnees.get('default_value_variante') or 'STANDARD'
        colonne.sort_order = donnees.get('sort_order') or 0
        db.session.add(colonne)
        db.session.flush()
        _journaliser(colonne.id, 'DEFINITION', _auteur(),
                     commentaire='Création de la ligne « %s »' % colonne.target_column)
        _designer_si_besoin(contrat)
        db.session.commit()
        return jsonify(colonne.to_dict()), 201
    except SQLAlchemyError as exc:
        db.session.rollback()
        if getattr(getattr(exc, 'orig', None), 'pgcode', None) == '23505':
            return jsonify({'error': 'Cette colonne est déjà documentée dans '
                                     'cette section du contrat'}), 409
        current_app.logger.error('Erreur création ligne de contrat: %s', exc)
        return jsonify({'error': 'Erreur lors de la création de la ligne'}), 500


@interface_contracts_blueprint.route('/columns/<int:column_id>', methods=['PUT'])
@require_permission('manage_contracts')
def modifier_colonne(column_id):
    """Modification de la definition technique. N'EFFACE PAS la validation
    metier : la vue la signalera « validée mais règle modifiée depuis »
    (validation_obsolete), grace au trigger sur updated_at."""
    colonne, contrat = _charger_colonne(column_id)
    if colonne is None:
        return jsonify({'error': 'Ligne de contrat introuvable'}), 404
    donnees = request.get_json() or {}
    if donnees.get('row_type') and donnees['row_type'] not in ROW_TYPES:
        return jsonify({'error': 'row_type doit être parmi %s' % ', '.join(ROW_TYPES)}), 400
    try:
        modifies = []
        for champ in CHAMPS_COLONNE:
            if champ in donnees and getattr(colonne, champ) != donnees[champ]:
                setattr(colonne, champ, donnees[champ])
                modifies.append(champ)
        if not modifies:
            return jsonify(colonne.to_dict()), 200

        _journaliser(column_id, 'DEFINITION', _auteur(),
                     commentaire='Modification : %s' % ', '.join(modifies))
        _designer_si_besoin(contrat)
        db.session.commit()
        return jsonify(colonne.to_dict()), 200
    except SQLAlchemyError as exc:
        db.session.rollback()
        if getattr(getattr(exc, 'orig', None), 'pgcode', None) == '23505':
            return jsonify({'error': 'Cette colonne est déjà documentée dans '
                                     'cette section du contrat'}), 409
        current_app.logger.error('Erreur modification ligne %s: %s', column_id, exc)
        return jsonify({'error': 'Erreur lors de la modification'}), 500


@interface_contracts_blueprint.route('/columns/<int:column_id>', methods=['DELETE'])
@require_permission('manage_contracts')
def supprimer_colonne(column_id):
    colonne, contrat = _charger_colonne(column_id)
    if colonne is None:
        return jsonify({'error': 'Ligne de contrat introuvable'}), 404
    try:
        db.session.delete(colonne)
        _designer_si_besoin(contrat)
        db.session.commit()
        return jsonify({'message': 'Ligne supprimée', 'id': column_id}), 200
    except SQLAlchemyError as exc:
        db.session.rollback()
        current_app.logger.error('Erreur suppression ligne %s: %s', column_id, exc)
        return jsonify({'error': 'Erreur lors de la suppression'}), 500


# ---------------------------------------------------------------------------
# Export / import Excel
# ---------------------------------------------------------------------------
def _tables_pour_export(cursor, module=None, table_id=None):
    """Reconstruit la structure attendue par build_contract_workbook depuis les
    vues : l'export reflete l'etat REEL de la base a l'instant T."""
    conditions, params = [], []
    if module:
        conditions.append('module = %s')
        params.append(module)
    if table_id:
        conditions.append('contract_table_id = %s')
        params.append(table_id)
    where = ('WHERE ' + ' AND '.join(conditions)) if conditions else ''

    cursor.execute(
        'SELECT * FROM public.v_interface_contract_summary %s '
        'ORDER BY module, ordre' % where, params)
    entetes = cursor.fetchall()

    cursor.execute(
        'SELECT * FROM public.v_interface_contract %s ORDER BY table_ordre, sort_order'
        % where, params)
    lignes_par_table = {}
    for ligne in cursor.fetchall():
        lignes_par_table.setdefault(ligne['contract_table_id'], []).append(dict(ligne))

    tables = []
    for entete in entetes:
        table = dict(entete)
        table['sheet'] = '%02d_%s' % (table['ordre'] or 0,
                                      (table['table_cible'] or '').upper())
        table['rows'] = lignes_par_table.get(table['contract_table_id'], [])
        tables.append(table)
    return tables


@interface_contracts_blueprint.route('/export', methods=['GET'])
@jwt_required()
def exporter():
    """Regenere le classeur au format v3 depuis l'etat courant de la base."""
    module = request.args.get('module')
    table_id = request.args.get('table_id', type=int)
    try:
        with get_db_connection() as conn:
            cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
            tables = _tables_pour_export(cursor, module, table_id)
            if not tables:
                return jsonify({'error': 'Aucun contrat à exporter'}), 404

            types = {}
            for table in tables:
                for ligne in _colonnes_reelles(cursor, table['schema_cible'],
                                               table['table_cible']):
                    types[(table['schema_cible'], table['table_cible'],
                           ligne['column_name'])] = _libelle_type(ligne)

            qualifies = ['%s.%s' % (t['schema_cible'], t['table_cible']) for t in tables]
            cursor.execute(
                """
                SELECT module, table_cible, colonne, variante, type_valeur, valeur,
                       description, is_active
                FROM public.etl_default_values
                WHERE table_cible = ANY(%s)
                ORDER BY table_cible, colonne, variante
                """,
                (qualifies,),
            )
            valeurs_defaut = [dict(r) for r in cursor.fetchall()]

        wb = build_contract_workbook(tables, default_values=valeurs_defaut,
                                     types_colonnes=types)
        flux = io.BytesIO()
        wb.save(flux)
        flux.seek(0)
        nom = 'contrat_interface_%s_%s.xlsx' % (
            module or 'tous_modules', datetime.now().strftime('%Y%m%d_%H%M'))
        return send_file(
            flux, as_attachment=True, download_name=nom,
            mimetype='application/vnd.openxmlformats-officedocument.spreadsheetml.sheet')
    except Exception as exc:
        current_app.logger.error('Erreur export contrats: %s', exc, exc_info=True)
        return jsonify({'error': "Erreur lors de la génération du classeur"}), 500


@interface_contracts_blueprint.route('/import', methods=['POST'])
@require_permission('manage_contracts')
def importer():
    """Reprend les colonnes jaunes d'un classeur rempli hors ligne.

    Ne touche QUE la validation metier : la definition technique reste celle de
    la base (le relecteur n'a pas vocation a modifier le mapping depuis Excel).
    """
    fichier = request.files.get('file')
    if fichier is None or not fichier.filename:
        return jsonify({'error': 'Aucun fichier fourni'}), 400
    if not fichier.filename.lower().endswith(('.xlsx', '.xlsm')):
        return jsonify({'error': 'Format attendu : .xlsx'}), 400

    module = request.form.get('module', 'supplier')
    relecteur = (request.form.get('relecteur') or '').strip()[:50] or _auteur()

    try:
        tables = parse_contract_workbook(io.BytesIO(fichier.read()), module=module)
    except Exception as exc:
        current_app.logger.error('Classeur illisible: %s', exc)
        return jsonify({'error': 'Classeur illisible ou format inattendu'}), 400

    reprises, ignorees, introuvables = 0, 0, []
    try:
        for table in tables:
            contrat = InterfaceContractTable.query.filter_by(
                module=module, table_cible=table['table_cible']).first()
            if contrat is None:
                introuvables.append(table['table_cible'])
                continue
            for ligne in table['rows']:
                validation_excel = ligne.get('validation')
                if not validation_excel:
                    continue
                colonne = _retrouver_colonne(contrat.id, ligne)
                if colonne is None:
                    ignorees += 1
                    continue
                statut = validation_excel.get('statut')
                validation = InterfaceContractValidation.query.filter_by(
                    contract_column_id=colonne.id).first()
                ancien = validation.statut if validation else 'A_VALIDER'
                if validation is None:
                    validation = InterfaceContractValidation(contract_column_id=colonne.id)
                    db.session.add(validation)
                if statut:
                    validation.statut = statut
                if validation_excel.get('remarque_metier'):
                    validation.remarque_metier = validation_excel['remarque_metier']
                validation.validated_by = relecteur
                validation.validated_at = _maintenant()
                _journaliser(colonne.id, 'IMPORT_EXCEL', relecteur,
                             ancien_statut=ancien,
                             nouveau_statut=statut or ancien,
                             commentaire=validation_excel.get('remarque_metier'))
                reprises += 1
        db.session.commit()
    except SQLAlchemyError as exc:
        db.session.rollback()
        current_app.logger.error('Erreur import contrats: %s', exc)
        return jsonify({'error': "Erreur lors de la reprise du classeur"}), 500

    return jsonify({
        'reprises': reprises,
        'ignorees': ignorees,
        'tables_introuvables': introuvables,
        'relecteur': relecteur,
    }), 200


def _retrouver_colonne(contract_table_id, ligne):
    """Retrouve la ligne de contrat visee par une ligne du classeur.

    Cle naturelle complete d'abord (section + colonne cible), puis repli sur la
    seule colonne cible SI elle est unique dans la table : un classeur peut
    avoir ete regenere avant un renommage de section.
    """
    requete = InterfaceContractColumn.query.filter_by(
        contract_table_id=contract_table_id, target_column=ligne['target_column'])
    exacte = requete.filter(
        InterfaceContractColumn.section.is_(None) if ligne.get('section') is None
        else InterfaceContractColumn.section == ligne['section']).first()
    if exacte is not None:
        return exacte
    candidates = requete.all()
    return candidates[0] if len(candidates) == 1 else None
