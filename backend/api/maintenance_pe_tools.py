"""
API pour les gammes de maintenance preventive (source : raw_data.pe_tools).

Un enregistrement = une ligne du fichier PE Tools : un poste technique, un plan
d'entretien et sa gamme (groupe + compteur), avec sa frequence et sa charge.

La table n'a pas de cle SAP : `raw_id` (unique) sert de cle technique pour
l'edition. Toutes les colonnes metier sont en `text` cote base -> aucune
conversion de type n'est faite ici, on stocke ce que l'utilisateur saisit.
"""
import csv
import io
import json

from flask import Blueprint, Response, current_app, jsonify, request
from flask_jwt_extended import get_jwt_identity
import psycopg2.extras

from config.database import get_db_connection
from config.settings import Config
from services.cache_service import cache_get, cache_set, cache_invalidate

maintenance_pe_tools_blueprint = Blueprint('maintenance_pe_tools', __name__)

CACHE_PREFIX = 'maint:petools:'

# Colonnes metier de raw_data.pe_tools, dans l'ordre d'affichage / d'export.
# `raw_id` est exclu : cle technique, jamais modifiable.
COLUMNS = [
    'localisation_classement',
    'gamme_en_dms',
    'poste_technique',
    'niveau_sap',
    'plan_entretien',
    'poste_entretien',
    'groupe_de_gamme',
    'compteur_de_gamme',
    'frequence',
    'designation',
    'type',
    'criticite',
    'parite_semaine',
    'jour',
    'decalage',
    'date_validation',
    'lien_fichier_gamme_source',
    'lien_fichier_dms_sap_pdf',
    'dms_sap',
    'charge',
    'nb_intervenants',
    'date_rev',
    'nb_jours_depuis_derniere_rev',
]

# Colonnes renseignees par l'import de fichiers (migration 075). Jamais
# editables : PUT/POST les ignorent, seul l'import de fichiers
# (POST /pe-tools/import, a venir) les ecrit.
COMPUTED_COLUMNS = [
    'nom_fichier',
    'organisation_maintenance',
]

# Colonnes proposees en liste deroulante (cardinalite faible / usage de filtre).
FILTER_COLUMNS = [
    'localisation_classement',
    'poste_technique',
    'type',
    'frequence',
    'criticite',
    'gamme_en_dms',
    'nom_fichier',
    'organisation_maintenance',
]

# Colonnes fouillees par la recherche libre.
SEARCH_COLUMNS = [
    'designation',
    'poste_technique',
    'niveau_sap',
    'plan_entretien',
    'poste_entretien',
    'groupe_de_gamme',
    'localisation_classement',
    'type',
]

# Tris autorises (liste blanche : le nom de colonne est interpole dans le SQL).
ORDERABLE = set(COLUMNS) | set(COMPUTED_COLUMNS) | {'raw_id'}

# Colonnes d'audit ajoutees par la migration 029. Elles peuvent manquer si la
# migration n'a pas encore ete jouee, ou si la table a ete rechargee depuis le
# fichier source -> presence detectee une fois puis memorisee.
_audit_available = None

# Colonnes de la migration 075 (import par fichier). Meme logique de detection
# que pour l'audit : sans la migration, l'ecran fonctionne comme avant.
# Detection memorisee par worker : apres avoir joue la migration 075,
# redemarrer le backend (./deploybackend.sh).
_import_columns_available = None


def _user() -> str:
    """Identite JWT pour la tracabilite (updated_by)."""
    try:
        return get_jwt_identity() or 'MIGFAC'
    except Exception:
        return 'MIGFAC'


def _has_audit_columns(cursor) -> bool:
    global _audit_available
    if _audit_available is None:
        cursor.execute("""
            SELECT COUNT(*) AS nb
            FROM information_schema.columns
            WHERE table_schema = 'raw_data' AND table_name = 'pe_tools'
              AND column_name IN ('updated_at', 'updated_by')
        """)
        _audit_available = cursor.fetchone()['nb'] == 2
    return _audit_available


def _has_import_columns(cursor) -> bool:
    global _import_columns_available
    if _import_columns_available is None:
        cursor.execute("""
            SELECT COUNT(*) AS nb
            FROM information_schema.columns
            WHERE table_schema = 'raw_data' AND table_name = 'pe_tools'
              AND column_name IN ('nom_fichier', 'organisation_maintenance', 'imported_at')
        """)
        _import_columns_available = cursor.fetchone()['nb'] == 3
    return _import_columns_available


def _selected_columns(cursor):
    """Colonnes lues par la liste, le detail et l'export : les colonnes
    calculees en tete (si la migration 075 est jouee) puis les colonnes metier."""
    if _has_import_columns(cursor):
        return COMPUTED_COLUMNS + COLUMNS
    return list(COLUMNS)


def _filter_columns(cursor):
    """Colonnes filtrables reellement presentes (les colonnes 075 ne le sont
    qu'apres la migration)."""
    if _has_import_columns(cursor):
        return FILTER_COLUMNS
    return [c for c in FILTER_COLUMNS if c not in COMPUTED_COLUMNS]


def _build_where(args, filter_columns):
    """Construit la clause WHERE commune (liste, export, stats) a partir des
    parametres de query string. Retourne (sql, params)."""
    clauses = []
    params = []

    search = (args.get('search') or '').strip()
    if search:
        sp = f'%{search}%'
        ors = ' OR '.join(f"{c} ILIKE %s" for c in SEARCH_COLUMNS)
        clauses.append(f"({ors})")
        params.extend([sp] * len(SEARCH_COLUMNS))

    for col in filter_columns:
        val = (args.get(col) or '').strip()
        if val:
            clauses.append(f"COALESCE(TRIM({col}), '') = %s")
            params.append(val)

    where_sql = ("WHERE " + " AND ".join(clauses)) if clauses else ""
    return where_sql, params


def _filters_signature(args) -> str:
    """Cle de cache : lue AVANT la connexion, donc sur la liste statique
    FILTER_COLUMNS (un parametre ignore ne cree qu'une entree distincte)."""
    parts = [f"search={(args.get('search') or '').strip()}"]
    parts += [f"{c}={(args.get(c) or '').strip()}" for c in FILTER_COLUMNS]
    return '|'.join(parts)


@maintenance_pe_tools_blueprint.route('/pe-tools', methods=['GET'])
def list_pe_tools():
    """Liste paginee des gammes PE Tools + options de filtres."""
    try:
        page = max(1, request.args.get('page', 1, type=int))
        per_page = min(max(1, request.args.get('per_page', 25, type=int)), 200)
        order_by = request.args.get('order_by', 'poste_technique', type=str)
        order = request.args.get('order', 'asc', type=str)
        if order_by not in ORDERABLE:
            order_by = 'poste_technique'
        order_dir = 'DESC' if order.lower() == 'desc' else 'ASC'
        offset = (page - 1) * per_page

        # Cache lu avant d'ouvrir une connexion (pas de pool : chaque
        # get_db_connection() est un psycopg2.connect).
        cache_key = (f"{CACHE_PREFIX}list:{page}:{per_page}:{order_by}:{order_dir}:"
                     f"{_filters_signature(request.args)}")
        cached = cache_get(cache_key)
        if cached is not None:
            return Response(cached, mimetype='application/json')

        with get_db_connection() as conn:
            cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
            filter_columns = _filter_columns(cursor)
            columns = _selected_columns(cursor)
            if order_by not in columns and order_by != 'raw_id':
                order_by = 'poste_technique'

            where_sql, params = _build_where(request.args, filter_columns)
            cols_sql = ', '.join(columns)

            cursor.execute(f"SELECT COUNT(*) AS total FROM raw_data.pe_tools {where_sql}", params)
            total = cursor.fetchone()['total']

            cursor.execute(
                f"""
                SELECT raw_id, {cols_sql}
                FROM raw_data.pe_tools
                {where_sql}
                ORDER BY {order_by} {order_dir} NULLS LAST, raw_id ASC
                LIMIT %s OFFSET %s
                """,
                params + [per_page, offset]
            )
            rows = cursor.fetchall()

            # Options de filtres : valeurs distinctes sur l'ensemble de la table
            # (independantes des filtres courants, pour rester selectionnables).
            filter_options = {}
            for col in filter_columns:
                cursor.execute(f"""
                    SELECT DISTINCT TRIM({col}) AS value
                    FROM raw_data.pe_tools
                    WHERE {col} IS NOT NULL AND TRIM({col}) <> ''
                    ORDER BY 1
                """)
                filter_options[col] = [r['value'] for r in cursor.fetchall()]

            payload = json.dumps({
                'success': True,
                'data': rows,
                'total': total,
                'page': page,
                'per_page': per_page,
                'columns': columns,
                'filter_options': filter_options,
            }, default=str)
            cache_set(cache_key, payload, Config.MAINTENANCE_CACHE_TTL)
            return Response(payload, mimetype='application/json')

    except Exception as e:
        current_app.logger.error(f"Erreur liste pe_tools: {e}")
        return jsonify({'success': False, 'error': str(e)}), 500


@maintenance_pe_tools_blueprint.route('/pe-tools/stats', methods=['GET'])
def pe_tools_stats():
    """Compteurs de tete de page, calcules sur le perimetre filtre."""
    try:
        cache_key = f"{CACHE_PREFIX}stats:{_filters_signature(request.args)}"
        cached = cache_get(cache_key)
        if cached is not None:
            return Response(cached, mimetype='application/json')

        with get_db_connection() as conn:
            cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
            where_sql, params = _build_where(request.args, _filter_columns(cursor))

            cursor.execute(f"""
                SELECT
                    COUNT(*) AS total,
                    COUNT(DISTINCT NULLIF(TRIM(poste_technique), '')) AS nb_postes_techniques,
                    COUNT(DISTINCT NULLIF(TRIM(plan_entretien), ''))  AS nb_plans_entretien,
                    COUNT(DISTINCT NULLIF(TRIM(groupe_de_gamme), '')) AS nb_gammes,
                    COALESCE(SUM(
                        CASE WHEN TRIM(COALESCE(charge, '')) ~ '^[0-9]+([.,][0-9]+)?$'
                             THEN REPLACE(TRIM(charge), ',', '.')::numeric END
                    ), 0) AS charge_totale
                FROM raw_data.pe_tools
                {where_sql}
            """, params)
            stats = cursor.fetchone()

            cursor.execute(f"""
                SELECT COALESCE(NULLIF(TRIM(frequence), ''), '(vide)') AS frequence,
                       COUNT(*) AS nb
                FROM raw_data.pe_tools
                {where_sql}
                GROUP BY 1
                ORDER BY nb DESC, 1
                LIMIT 12
            """, params)
            by_frequence = cursor.fetchall()

            payload = json.dumps({
                'success': True,
                'data': {**stats, 'by_frequence': by_frequence},
            }, default=str)
            cache_set(cache_key, payload, Config.MAINTENANCE_CACHE_TTL)
            return Response(payload, mimetype='application/json')

    except Exception as e:
        current_app.logger.error(f"Erreur stats pe_tools: {e}")
        return jsonify({'success': False, 'error': str(e)}), 500


@maintenance_pe_tools_blueprint.route('/pe-tools/export', methods=['GET'])
def export_pe_tools():
    """Export CSV (';', BOM UTF-8 pour Excel) du perimetre filtre courant."""
    try:
        order_by = request.args.get('order_by', 'poste_technique', type=str)
        if order_by not in ORDERABLE:
            order_by = 'poste_technique'
        order_dir = 'DESC' if (request.args.get('order') or '').lower() == 'desc' else 'ASC'

        with get_db_connection() as conn:
            cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
            columns = _selected_columns(cursor)
            if order_by not in columns and order_by != 'raw_id':
                order_by = 'poste_technique'
            where_sql, params = _build_where(request.args, _filter_columns(cursor))
            cols_sql = ', '.join(columns)
            cursor.execute(
                f"""
                SELECT {cols_sql}
                FROM raw_data.pe_tools
                {where_sql}
                ORDER BY {order_by} {order_dir} NULLS LAST, raw_id ASC
                """,
                params
            )
            rows = cursor.fetchall()

        output = io.StringIO()
        writer = csv.DictWriter(output, fieldnames=columns, delimiter=';', extrasaction='ignore')
        writer.writeheader()
        for r in rows:
            writer.writerow({c: (r.get(c) if r.get(c) is not None else '') for c in columns})

        # BOM : sans lui Excel casse les accents des designations.
        body = '\ufeff' + output.getvalue()
        return Response(
            body,
            mimetype='text/csv',
            headers={
                'Content-Disposition': 'attachment; filename=pe_tools.csv',
                'Content-Type': 'text/csv; charset=utf-8',
            }
        )

    except Exception as e:
        current_app.logger.error(f"Erreur export pe_tools: {e}")
        return jsonify({'success': False, 'error': str(e)}), 500


@maintenance_pe_tools_blueprint.route('/pe-tools/<int:raw_id>', methods=['GET'])
def get_pe_tool(raw_id: int):
    """Detail d'une ligne."""
    try:
        with get_db_connection() as conn:
            cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
            cols_sql = ', '.join(_selected_columns(cursor))
            audit_sql = ', updated_at, updated_by' if _has_audit_columns(cursor) else ''
            if _has_import_columns(cursor):
                audit_sql += ', imported_at'
            cursor.execute(
                f"SELECT raw_id, {cols_sql}{audit_sql} FROM raw_data.pe_tools WHERE raw_id = %s LIMIT 1",
                [raw_id]
            )
            row = cursor.fetchone()
            if not row:
                return jsonify({'success': False, 'error': 'Ligne non trouvee'}), 404
            return jsonify({'success': True, 'data': row}), 200

    except Exception as e:
        current_app.logger.error(f"Erreur detail pe_tools {raw_id}: {e}")
        return jsonify({'success': False, 'error': str(e)}), 500


@maintenance_pe_tools_blueprint.route('/pe-tools/<int:raw_id>', methods=['PUT'])
def update_pe_tool(raw_id: int):
    """Mise a jour d'une ligne (colonnes metier uniquement)."""
    try:
        data = request.get_json() or {}
        updates = []
        values = []
        for key, val in data.items():
            if key not in COLUMNS:
                continue
            updates.append(f"{key} = %s")
            values.append(val if val not in ('', None) else None)

        if not updates:
            return jsonify({'success': False, 'error': 'Aucun champ a mettre a jour'}), 400

        with get_db_connection() as conn:
            cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
            if _has_audit_columns(cursor):
                updates.append("updated_at = NOW()")
                updates.append("updated_by = %s")
                values.append(_user())

            cursor.execute(
                f"UPDATE raw_data.pe_tools SET {', '.join(updates)} WHERE raw_id = %s",
                values + [raw_id]
            )
            if cursor.rowcount == 0:
                conn.rollback()
                return jsonify({'success': False, 'error': 'Ligne non trouvee'}), 404
            conn.commit()

        cache_invalidate(CACHE_PREFIX)
        modified = [k for k in data.keys() if k in COLUMNS]
        return jsonify({
            'success': True,
            'message': f'{len(modified)} champ(s) mis a jour',
            'modified': modified,
        }), 200

    except Exception as e:
        current_app.logger.error(f"Erreur update pe_tools {raw_id}: {e}")
        return jsonify({'success': False, 'error': str(e)}), 500


@maintenance_pe_tools_blueprint.route('/pe-tools', methods=['POST'])
def create_pe_tool():
    """Creation d'une ligne (raw_id attribue = max + 1)."""
    try:
        data = request.get_json() or {}
        cols = [k for k in data.keys() if k in COLUMNS]
        if not cols:
            return jsonify({'success': False, 'error': 'Aucun champ fourni'}), 400

        values = [data[c] if data[c] not in ('', None) else None for c in cols]

        with get_db_connection() as conn:
            cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
            audit_cols = []
            audit_vals = []
            if _has_audit_columns(cursor):
                audit_cols = ['updated_at', 'updated_by']
                audit_vals = ['NOW()', '%s']
                values.append(_user())

            all_cols = ['raw_id'] + cols + audit_cols
            placeholders = ['(SELECT COALESCE(MAX(raw_id), 0) + 1 FROM raw_data.pe_tools)'] \
                + ['%s'] * len(cols) + audit_vals

            cursor.execute(
                f"INSERT INTO raw_data.pe_tools ({', '.join(all_cols)}) "
                f"VALUES ({', '.join(placeholders)}) RETURNING raw_id",
                values
            )
            new_id = cursor.fetchone()['raw_id']
            conn.commit()

        cache_invalidate(CACHE_PREFIX)
        return jsonify({'success': True, 'data': {'raw_id': new_id}}), 201

    except Exception as e:
        current_app.logger.error(f"Erreur creation pe_tools: {e}")
        return jsonify({'success': False, 'error': str(e)}), 500


@maintenance_pe_tools_blueprint.route('/pe-tools/<int:raw_id>', methods=['DELETE'])
def delete_pe_tool(raw_id: int):
    """Suppression definitive d'une ligne (la table n'a pas d'indicateur d'etat)."""
    try:
        with get_db_connection() as conn:
            cursor = conn.cursor()
            cursor.execute("DELETE FROM raw_data.pe_tools WHERE raw_id = %s", [raw_id])
            if cursor.rowcount == 0:
                conn.rollback()
                return jsonify({'success': False, 'error': 'Ligne non trouvee'}), 404
            conn.commit()

        cache_invalidate(CACHE_PREFIX)
        return jsonify({'success': True, 'message': 'Ligne supprimee'}), 200

    except Exception as e:
        current_app.logger.error(f"Erreur suppression pe_tools {raw_id}: {e}")
        return jsonify({'success': False, 'error': str(e)}), 500
