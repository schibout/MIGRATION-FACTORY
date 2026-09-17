"""
Parametrage des organisations de maintenance PE Tools (migration 077).

Une regle = un code de fichier ("PeTool - 7.<CODE>.csv") -> une organisation
de maintenance IFS. `public.pe_tools_org_code()` lit cette table a chaque
import de fichier et l'ETL PM Actions reprend la valeur dans
`clean_data.pm_action.org_code`. Un code absent de la table donne une
organisation NULL : aucun repli generique, on veut voir le trou.

L'organisation n'est posee sur une ligne qu'AU MOMENT de l'import : modifier
une regle ne change pas les lignes deja chargees, d'ou la route de recalcul
(`POST /pe-tools-organisations/recalculer`), qui rejoue
`public.pe_tools_org_code(nom_fichier)` sur les lignes importees.
"""
import re

from flask import Blueprint, current_app, jsonify, request
from flask_jwt_extended import get_jwt_identity, jwt_required
import psycopg2.extras

from config.database import get_db_connection

pe_tools_organisation_blueprint = Blueprint('pe_tools_organisation', __name__)

# `clean_data.pm_action.org_code` est un varchar(8) : une organisation plus
# longue passerait l'ecran mais ferait echouer l'ETL PM Actions. La migration
# 077 pose le meme plafond en CHECK cote base.
ORG_CODE_MAX = 8

# Jeu de caracteres reconnu par public.pe_tools_code_fichier() dans le nom de
# fichier : un code contenant autre chose ne serait jamais retrouve.
CODE_FICHIER_RE = re.compile(r'^[A-Za-z0-9_-]+$')


def _texte(valeur):
    """Chaine vide venant du front -> None (colonne laissee vide en base)."""
    if valeur is None:
        return None
    valeur = str(valeur).strip()
    return valeur or None


def valider_regle(data: dict):
    """Normalise et controle une regle saisie a l'ecran.

    Retourne (regle, None) ou (None, message d'erreur). Fonction pure : aucune
    base, aucun contexte Flask (cf. tests/test_pe_tools_organisation.py).
    """
    code = _texte((data or {}).get('code_fichier'))
    if not code:
        return None, 'Le code de fichier est obligatoire'
    code = code.upper()
    if not CODE_FICHIER_RE.match(code):
        return None, ("Le code de fichier ne peut contenir que des lettres, chiffres, "
                      "tiret et souligne (segment « 7.<CODE>.csv » du nom de fichier)")

    org = _texte((data or {}).get('org_code'))
    if not org:
        return None, "L'organisation de maintenance IFS est obligatoire"
    org = org.upper()
    if len(org) > ORG_CODE_MAX:
        return None, (f"L'organisation de maintenance est limitee a {ORG_CODE_MAX} caracteres "
                      f"(cible IFS clean_data.pm_action.org_code)")

    return {
        'code_fichier': code,
        'org_code': org,
        'description': _texte((data or {}).get('description')),
        'is_active': bool((data or {}).get('is_active', True)),
    }, None


def _user() -> str:
    try:
        return get_jwt_identity() or 'MIGFAC'
    except Exception:
        return 'MIGFAC'


def _lignes_par_code(cursor) -> dict:
    """Nombre de lignes deja importees dans raw_data.pe_tools, par code de
    fichier. Sert a avertir avant un renommage / une suppression, et a montrer
    ce qu'un recalcul toucherait."""
    cursor.execute("""
        SELECT public.pe_tools_code_fichier(nom_fichier) AS code,
               COUNT(*) AS nb,
               COUNT(*) FILTER (WHERE organisation_maintenance IS NULL) AS nb_sans_organisation
        FROM raw_data.pe_tools
        WHERE nom_fichier IS NOT NULL
        GROUP BY 1
    """)
    return {r['code']: {'lignes': r['nb'], 'lignes_sans_organisation': r['nb_sans_organisation']}
            for r in cursor.fetchall() if r['code'] is not None}


@pe_tools_organisation_blueprint.route('/pe-tools-organisations', methods=['GET'])
@jwt_required()
def list_organisations():
    """Regles declarees + volumetrie importee + codes importes sans regle."""
    try:
        with get_db_connection() as conn:
            cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
            cursor.execute("""
                SELECT code_fichier, org_code, description, is_active, updated_at, updated_by
                FROM public.pe_tools_organisation
                ORDER BY code_fichier
            """)
            regles = [dict(r) for r in cursor.fetchall()]
            volumetrie = _lignes_par_code(cursor)

        declares = {r['code_fichier'] for r in regles}
        for regle in regles:
            info = volumetrie.get(regle['code_fichier'], {})
            regle['lignes_importees'] = info.get('lignes', 0)
            regle['updated_at'] = regle['updated_at'].isoformat() if regle['updated_at'] else None

        # Codes presents dans les fichiers importes mais sans regle : leurs
        # lignes portent une organisation NULL, invisible ailleurs.
        manquants = [
            {'code_fichier': code, 'lignes_importees': info['lignes']}
            for code, info in sorted(volumetrie.items()) if code not in declares
        ]

        return jsonify({
            'success': True,
            'data': regles,
            'total': len(regles),
            'codes_sans_regle': manquants,
            'lignes_sans_organisation': sum(v['lignes_sans_organisation'] for v in volumetrie.values()),
        }), 200
    except Exception as e:
        current_app.logger.error(f"Erreur liste pe_tools_organisation: {e}")
        return jsonify({'success': False, 'error': str(e)}), 500


@pe_tools_organisation_blueprint.route('/pe-tools-organisations', methods=['POST'])
@jwt_required()
def create_organisation():
    regle, erreur = valider_regle(request.get_json() or {})
    if erreur:
        return jsonify({'success': False, 'error': erreur}), 400
    try:
        with get_db_connection() as conn:
            cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
            cursor.execute(
                "SELECT 1 FROM public.pe_tools_organisation WHERE code_fichier = %s",
                [regle['code_fichier']])
            if cursor.fetchone():
                return jsonify({'success': False,
                                'error': f"Le code {regle['code_fichier']} est deja parametre"}), 409
            cursor.execute("""
                INSERT INTO public.pe_tools_organisation
                    (code_fichier, org_code, description, is_active, updated_at, updated_by)
                VALUES (%s, %s, %s, %s, now(), %s)
                RETURNING code_fichier
            """, [regle['code_fichier'], regle['org_code'], regle['description'],
                  regle['is_active'], _user()])
            conn.commit()
        return jsonify({'success': True, 'data': regle}), 201
    except Exception as e:
        current_app.logger.error(f"Erreur creation pe_tools_organisation: {e}")
        return jsonify({'success': False, 'error': str(e)}), 500


@pe_tools_organisation_blueprint.route('/pe-tools-organisations/<code>', methods=['PUT'])
@jwt_required()
def update_organisation(code: str):
    """Modification, renommage du code compris : les lignes deja importees
    gardent l'organisation figee a leur import jusqu'au recalcul (l'ecran
    avertit avec le nombre de lignes concernees)."""
    regle, erreur = valider_regle(request.get_json() or {})
    if erreur:
        return jsonify({'success': False, 'error': erreur}), 400
    ancien = (code or '').strip().upper()
    try:
        with get_db_connection() as conn:
            cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
            if regle['code_fichier'] != ancien:
                cursor.execute(
                    "SELECT 1 FROM public.pe_tools_organisation WHERE code_fichier = %s",
                    [regle['code_fichier']])
                if cursor.fetchone():
                    return jsonify({'success': False,
                                    'error': f"Le code {regle['code_fichier']} est deja parametre"}), 409
            cursor.execute("""
                UPDATE public.pe_tools_organisation
                   SET code_fichier = %s, org_code = %s, description = %s,
                       is_active = %s, updated_at = now(), updated_by = %s
                 WHERE code_fichier = %s
            """, [regle['code_fichier'], regle['org_code'], regle['description'],
                  regle['is_active'], _user(), ancien])
            if cursor.rowcount == 0:
                conn.rollback()
                return jsonify({'success': False, 'error': f'Code {ancien} introuvable'}), 404
            conn.commit()
        return jsonify({'success': True, 'data': regle}), 200
    except Exception as e:
        current_app.logger.error(f"Erreur modification pe_tools_organisation {code}: {e}")
        return jsonify({'success': False, 'error': str(e)}), 500


@pe_tools_organisation_blueprint.route('/pe-tools-organisations/<code>', methods=['DELETE'])
@jwt_required()
def delete_organisation(code: str):
    """Suppression autorisee meme si des lignes importees portent le code :
    elles gardent leur organisation jusqu'au recalcul, qui la remettra a NULL."""
    ancien = (code or '').strip().upper()
    try:
        with get_db_connection() as conn:
            cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
            cursor.execute(
                "DELETE FROM public.pe_tools_organisation WHERE code_fichier = %s", [ancien])
            if cursor.rowcount == 0:
                conn.rollback()
                return jsonify({'success': False, 'error': f'Code {ancien} introuvable'}), 404
            conn.commit()
        return jsonify({'success': True, 'message': f'Regle {ancien} supprimee'}), 200
    except Exception as e:
        current_app.logger.error(f"Erreur suppression pe_tools_organisation {code}: {e}")
        return jsonify({'success': False, 'error': str(e)}), 500


@pe_tools_organisation_blueprint.route('/pe-tools-organisations/recalculer', methods=['POST'])
@jwt_required()
def recalculer_organisations():
    """Rejoue le parametrage sur les lignes DEJA importees.

    Les lignes historiques (nom_fichier NULL, chargement hors application) ne
    sont jamais touchees. Un code dont la regle a ete supprimee ou desactivee
    repasse a NULL : c'est le parametrage courant qui fait foi.
    """
    try:
        with get_db_connection() as conn:
            cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
            cursor.execute("SELECT pg_advisory_xact_lock(778814)")
            cursor.execute("""
                UPDATE raw_data.pe_tools
                   SET organisation_maintenance = public.pe_tools_org_code(nom_fichier)
                 WHERE nom_fichier IS NOT NULL
                   AND organisation_maintenance IS DISTINCT FROM public.pe_tools_org_code(nom_fichier)
            """)
            modifiees = cursor.rowcount
            cursor.execute("""
                SELECT COUNT(*) AS nb
                FROM raw_data.pe_tools
                WHERE nom_fichier IS NOT NULL AND organisation_maintenance IS NULL
            """)
            sans_organisation = cursor.fetchone()['nb']
            conn.commit()
        return jsonify({
            'success': True,
            'lignes_modifiees': modifiees,
            'lignes_sans_organisation': sans_organisation,
            'message': f'{modifiees} ligne(s) mise(s) a jour',
        }), 200
    except Exception as e:
        current_app.logger.error(f"Erreur recalcul organisations pe_tools: {e}")
        return jsonify({'success': False, 'error': str(e)}), 500
