"""
API des listes de valeurs (LOV) de maintenance -- blueprint /api/v1/lov/*.

Sert public.maintenance_lov_type / maintenance_lov_value (migration 075) aux
combobox de l'ecran IH02 ("Facteur de Risque", "Zone").

Une valeur est retenue pour un site si son `contract` vaut ce site OU s'il est
NULL (valeur commune a tous les sites). Le tri met les valeurs specifiques au
site AVANT les valeurs communes, a code egal.

Lecture seule : l'alimentation des listes se fait en base (ou par un ecran
d'administration a venir), pas depuis l'ecran IH02.
"""
import psycopg2.extras
from psycopg2 import errors as pg_errors
from flask import Blueprint, current_app, jsonify, request

from config.database import get_db_connection

maintenance_lov_blueprint = Blueprint('maintenance_lov', __name__)


@maintenance_lov_blueprint.route('/types', methods=['GET'])
def get_lov_types():
    """Liste des listes de valeurs declarees."""
    try:
        with get_db_connection() as conn:
            cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
            cursor.execute("""
                SELECT t.code, t.libelle, t.ordre,
                       (SELECT COUNT(*) FROM public.maintenance_lov_value v
                         WHERE v.lov_type_id = t.id AND v.actif) AS nb_valeurs
                FROM public.maintenance_lov_type t
                ORDER BY COALESCE(t.ordre, 9999), t.code
            """)
            rows = cursor.fetchall()
            return jsonify({'success': True, 'data': rows, 'total': len(rows)}), 200
    except Exception as e:
        current_app.logger.error(f"Erreur liste des LOV: {e}")
        return jsonify({'success': False, 'error': str(e)}), 500


@maintenance_lov_blueprint.route('/types/<list_code>/values', methods=['GET'])
def get_lov_values(list_code):
    """
    Valeurs actives d'une liste, filtrees sur le site (`contract`).

    Sans parametre `contract`, on renvoie TOUTES les valeurs actives de la
    liste : c'est ce que veut un ecran mono-site ou un ecran d'administration.
    """
    try:
        contract = (request.args.get('contract') or '').strip() or None
        # L'ecran d'administration a besoin des valeurs DESACTIVEES aussi ;
        # les combobox, elles, ne doivent voir que les valeurs actives.
        inclure_inactives = request.args.get('all') in ('1', 'true', 'True')
        filtre_actif = '' if inclure_inactives else 'AND v.actif'

        with get_db_connection() as conn:
            cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
            cursor.execute(
                "SELECT id, libelle FROM public.maintenance_lov_type WHERE code = %s",
                [list_code],
            )
            lov_type = cursor.fetchone()
            if not lov_type:
                return jsonify({'success': False,
                                'error': f'Liste de valeurs "{list_code}" inconnue'}), 404

            if contract:
                cursor.execute(f"""
                    SELECT v.id, v.code, v.libelle, v.contract, v.ordre, v.actif
                    FROM public.maintenance_lov_value v
                    WHERE v.lov_type_id = %s {filtre_actif}
                      AND (v.contract = %s OR v.contract IS NULL)
                    -- Une valeur propre au site prime sur la valeur commune.
                    ORDER BY COALESCE(v.ordre, 9999),
                             (v.contract IS NULL),
                             v.code
                """, [lov_type['id'], contract])
            else:
                cursor.execute(f"""
                    SELECT v.id, v.code, v.libelle, v.contract, v.ordre, v.actif
                    FROM public.maintenance_lov_value v
                    WHERE v.lov_type_id = %s {filtre_actif}
                    ORDER BY COALESCE(v.ordre, 9999), v.code
                """, [lov_type['id']])

            values = cursor.fetchall()
            return jsonify({
                'success': True,
                'data': values,
                'total': len(values),
                'list_code': list_code,
                'list_label': lov_type['libelle'],
                'contract': contract,
            }), 200
    except Exception as e:
        current_app.logger.error(f"Erreur valeurs LOV {list_code}: {e}")
        return jsonify({'success': False, 'error': str(e)}), 500


# ---------------------------------------------------------------------------
# Administration des valeurs (ecran /maintenance/lov)
# ---------------------------------------------------------------------------

# Colonne de clean_data.maintenance_object alimentee par chaque liste. Sert au
# garde-fou de suppression : on refuse d'effacer une valeur encore portee par
# des postes techniques (l'ecran IH02 afficherait un code oriphelin).
COLONNE_PAR_LISTE = {
    'FACTEUR_RISQUE': 'risk_factor',
    'ZONE': 'zone',
}


def _resolve_type(cursor, list_code):
    cursor.execute(
        "SELECT id, code, libelle FROM public.maintenance_lov_type WHERE code = %s",
        [list_code],
    )
    return cursor.fetchone()


def _payload_valeur(data):
    """Champs communs a la creation et a la modification, normalises."""
    code = (data.get('code') or '').strip()
    libelle = (data.get('libelle') or '').strip()
    # '' -> NULL : une valeur sans site est commune a TOUS les sites.
    contract = (data.get('contract') or '').strip() or None
    ordre = data.get('ordre')
    ordre = int(ordre) if str(ordre or '').strip() not in ('', 'None') else None
    actif = data.get('actif')
    actif = True if actif is None else bool(actif)
    return code, libelle, contract, ordre, actif


@maintenance_lov_blueprint.route('/types/<list_code>/values', methods=['POST'])
def create_lov_value(list_code):
    """Ajoute une valeur a une liste."""
    try:
        data = request.get_json() or {}
        code, libelle, contract, ordre, actif = _payload_valeur(data)
        if not code:
            return jsonify({'success': False, 'error': 'Le code est obligatoire'}), 400
        if not libelle:
            return jsonify({'success': False, 'error': 'Le libellé est obligatoire'}), 400

        with get_db_connection() as conn:
            cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
            lov_type = _resolve_type(cursor, list_code)
            if not lov_type:
                return jsonify({'success': False,
                                'error': f'Liste de valeurs "{list_code}" inconnue'}), 404
            try:
                cursor.execute("""
                    INSERT INTO public.maintenance_lov_value
                        (lov_type_id, code, libelle, contract, ordre, actif)
                    VALUES (%s, %s, %s, %s, %s, %s)
                    RETURNING id, code, libelle, contract, ordre, actif
                """, [lov_type['id'], code, libelle, contract, ordre, actif])
            except pg_errors.UniqueViolation:
                conn.rollback()
                site = contract or 'tous sites'
                return jsonify({'success': False,
                                'error': f'Le code "{code}" existe déjà pour {site}'}), 409
            row = cursor.fetchone()
            conn.commit()
            return jsonify({'success': True, 'data': row,
                            'message': f'Valeur "{code}" ajoutée'}), 201
    except Exception as e:
        current_app.logger.error(f"Erreur creation valeur LOV {list_code}: {e}")
        return jsonify({'success': False, 'error': str(e)}), 500


@maintenance_lov_blueprint.route('/values/<int:value_id>', methods=['PUT'])
def update_lov_value(value_id):
    """Modifie une valeur (code, libelle, site, ordre, activation)."""
    try:
        data = request.get_json() or {}
        with get_db_connection() as conn:
            cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
            cursor.execute(
                "SELECT id, code, libelle, contract, ordre, actif "
                "FROM public.maintenance_lov_value WHERE id = %s", [value_id])
            actuelle = cursor.fetchone()
            if not actuelle:
                return jsonify({'success': False, 'error': 'Valeur non trouvée'}), 404

            # Modification partielle : ce qui n'est pas fourni ne bouge pas.
            fusion = dict(actuelle)
            fusion.update({k: v for k, v in data.items()
                           if k in ('code', 'libelle', 'contract', 'ordre', 'actif')})
            code, libelle, contract, ordre, actif = _payload_valeur(fusion)
            if not code:
                return jsonify({'success': False, 'error': 'Le code est obligatoire'}), 400
            if not libelle:
                return jsonify({'success': False, 'error': 'Le libellé est obligatoire'}), 400

            try:
                cursor.execute("""
                    UPDATE public.maintenance_lov_value
                    SET code = %s, libelle = %s, contract = %s, ordre = %s, actif = %s
                    WHERE id = %s
                    RETURNING id, code, libelle, contract, ordre, actif
                """, [code, libelle, contract, ordre, actif, value_id])
            except pg_errors.UniqueViolation:
                conn.rollback()
                site = contract or 'tous sites'
                return jsonify({'success': False,
                                'error': f'Le code "{code}" existe déjà pour {site}'}), 409
            row = cursor.fetchone()
            conn.commit()
            return jsonify({'success': True, 'data': row, 'message': 'Valeur mise à jour'}), 200
    except Exception as e:
        current_app.logger.error(f"Erreur modification valeur LOV {value_id}: {e}")
        return jsonify({'success': False, 'error': str(e)}), 500


@maintenance_lov_blueprint.route('/values/<int:value_id>', methods=['DELETE'])
def delete_lov_value(value_id):
    """
    Supprime une valeur, SAUF si des postes techniques la portent encore :
    l'effacer laisserait un code sans libelle dans l'ecran IH02. Dans ce cas on
    renvoie 409 avec le nombre de postes concernes ; la desactivation
    (actif = false) reste possible et retire la valeur des choix proposes sans
    toucher aux postes deja renseignes.
    """
    try:
        with get_db_connection() as conn:
            cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
            cursor.execute("""
                SELECT v.id, v.code, t.code AS list_code
                FROM public.maintenance_lov_value v
                JOIN public.maintenance_lov_type t ON t.id = v.lov_type_id
                WHERE v.id = %s
            """, [value_id])
            valeur = cursor.fetchone()
            if not valeur:
                return jsonify({'success': False, 'error': 'Valeur non trouvée'}), 404

            colonne = COLONNE_PAR_LISTE.get(valeur['list_code'])
            if colonne:
                cursor.execute(
                    f"""SELECT COUNT(*) AS nb FROM clean_data.maintenance_object
                        WHERE object_type = 'FUNC_LOC' AND is_active AND {colonne} = %s""",
                    [valeur['code']],
                )
                nb = cursor.fetchone()['nb']
                if nb:
                    return jsonify({
                        'success': False,
                        'error': f'"{valeur["code"]}" est utilisé par {nb} poste(s) technique(s). '
                                 f'Désactivez-le plutôt que de le supprimer.',
                        'data': {'usage_count': nb},
                    }), 409

            cursor.execute("DELETE FROM public.maintenance_lov_value WHERE id = %s", [value_id])
            conn.commit()
            return jsonify({'success': True,
                            'message': f'Valeur "{valeur["code"]}" supprimée'}), 200
    except Exception as e:
        current_app.logger.error(f"Erreur suppression valeur LOV {value_id}: {e}")
        return jsonify({'success': False, 'error': str(e)}), 500
