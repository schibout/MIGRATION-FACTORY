"""
API du referentiel IBAU editable (clean_data.ibau_article).

Demande metier : une liste avec SEULEMENT les IBAU, qui n'est PAS mise a jour
depuis SAP mais reste modifiable par les equipes (ajout, suppression,
modification). La table est alimentee une fois par la migration 030 (perimetre
structure IH02) puis vit sa propre vie : aucun endpoint ne relit raw_data.

Suppression = soft delete (is_active = FALSE) ; le code redevient disponible.
Unicite du code parmi les lignes actives (uq_ibau_article_code_active) -> 409.
"""
import csv
import io
import json

from flask import Blueprint, Response, current_app, jsonify, request
from flask_jwt_extended import get_jwt_identity
import psycopg2
import psycopg2.extras

from config.database import get_db_connection
from config.settings import Config
from services.cache_service import cache_get, cache_set, cache_invalidate

maintenance_ibau_blueprint = Blueprint('maintenance_ibau', __name__)

CACHE_PREFIX = 'maint:ibau:'

# Colonnes modifiables par l'ecran. matnr / source / audit ne se modifient pas.
EDITABLE_COLUMNS = ['code', 'description', 'matkl', 'matkl_label', 'meins', 'bismt', 'commentaire']

# Colonnes renvoyees par la liste / l'export.
COLUMNS = ['matnr', 'code', 'description', 'matkl', 'matkl_label', 'meins', 'bismt',
           'commentaire', 'source', 'created_at', 'created_by', 'updated_at', 'updated_by']

SEARCH_COLUMNS = ['code', 'description', 'matnr', 'bismt', 'matkl', 'commentaire']

ORDERABLE = {'code', 'description', 'matkl', 'source', 'updated_at', 'created_at', 'id'}


def _user() -> str:
    """Identite JWT pour la tracabilite (created_by / updated_by)."""
    try:
        return get_jwt_identity() or 'MIGFAC'
    except Exception:
        return 'MIGFAC'


def _build_where(args):
    """Clause WHERE commune (liste, export, stats). Retourne (sql, params)."""
    clauses = ["is_active"]
    params = []

    search = (args.get('search') or '').strip()
    if search:
        sp = f'%{search}%'
        ors = ' OR '.join(f"{c} ILIKE %s" for c in SEARCH_COLUMNS)
        clauses.append(f"({ors})")
        params.extend([sp] * len(SEARCH_COLUMNS))

    matkl = (args.get('matkl') or '').strip()
    if matkl:
        clauses.append("COALESCE(TRIM(matkl), '') = %s")
        params.append(matkl)

    source = (args.get('source') or '').strip().upper()
    if source in ('SAP', 'MANUAL'):
        clauses.append("source = %s")
        params.append(source)

    return "WHERE " + " AND ".join(clauses), params


def _filters_signature(args) -> str:
    return (f"search={(args.get('search') or '').strip()}"
            f"|matkl={(args.get('matkl') or '').strip()}"
            f"|source={(args.get('source') or '').strip()}")


@maintenance_ibau_blueprint.route('/ibau', methods=['GET'])
def list_ibau():
    """Liste paginee du referentiel IBAU + options de filtres."""
    try:
        page = max(1, request.args.get('page', 1, type=int))
        per_page = min(max(1, request.args.get('per_page', 25, type=int)), 200)
        order_by = request.args.get('order_by', 'code', type=str)
        order = request.args.get('order', 'asc', type=str)
        if order_by not in ORDERABLE:
            order_by = 'code'
        order_dir = 'DESC' if order.lower() == 'desc' else 'ASC'
        offset = (page - 1) * per_page

        where_sql, params = _build_where(request.args)

        cache_key = (f"{CACHE_PREFIX}list:{page}:{per_page}:{order_by}:{order_dir}:"
                     f"{_filters_signature(request.args)}")
        cached = cache_get(cache_key)
        if cached is not None:
            return Response(cached, mimetype='application/json')

        cols_sql = ', '.join(COLUMNS)

        with get_db_connection() as conn:
            cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)

            cursor.execute(f"SELECT COUNT(*) AS total FROM clean_data.ibau_article {where_sql}", params)
            total = cursor.fetchone()['total']

            cursor.execute(
                f"""
                SELECT id, {cols_sql}
                FROM clean_data.ibau_article
                {where_sql}
                ORDER BY {order_by} {order_dir} NULLS LAST, id ASC
                LIMIT %s OFFSET %s
                """,
                params + [per_page, offset]
            )
            rows = cursor.fetchall()

            cursor.execute("""
                SELECT DISTINCT TRIM(matkl) AS code,
                       COALESCE(MAX(matkl_label), '') AS label
                FROM clean_data.ibau_article
                WHERE is_active AND matkl IS NOT NULL AND TRIM(matkl) <> ''
                GROUP BY TRIM(matkl)
                ORDER BY 1
            """)
            matkl_options = cursor.fetchall()

            payload = json.dumps({
                'success': True,
                'data': rows,
                'total': total,
                'page': page,
                'per_page': per_page,
                'filter_options': {'matkl': matkl_options},
            }, default=str)
            cache_set(cache_key, payload, Config.MAINTENANCE_CACHE_TTL)
            return Response(payload, mimetype='application/json')

    except Exception as e:
        current_app.logger.error(f"Erreur liste ibau: {e}")
        return jsonify({'success': False, 'error': str(e)}), 500


@maintenance_ibau_blueprint.route('/ibau/stats', methods=['GET'])
def ibau_stats():
    """Compteurs de tete de page, calcules sur le perimetre filtre."""
    try:
        where_sql, params = _build_where(request.args)

        cache_key = f"{CACHE_PREFIX}stats:{_filters_signature(request.args)}"
        cached = cache_get(cache_key)
        if cached is not None:
            return Response(cached, mimetype='application/json')

        with get_db_connection() as conn:
            cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
            cursor.execute(f"""
                SELECT
                    COUNT(*) AS total,
                    COUNT(*) FILTER (WHERE source = 'SAP')    AS nb_sap,
                    COUNT(*) FILTER (WHERE source = 'MANUAL') AS nb_manuel,
                    COUNT(*) FILTER (WHERE updated_by IS NOT NULL) AS nb_modifies,
                    COUNT(DISTINCT NULLIF(TRIM(matkl), '')) AS nb_groupes
                FROM clean_data.ibau_article
                {where_sql}
            """, params)
            stats = cursor.fetchone()

            payload = json.dumps({'success': True, 'data': stats}, default=str)
            cache_set(cache_key, payload, Config.MAINTENANCE_CACHE_TTL)
            return Response(payload, mimetype='application/json')

    except Exception as e:
        current_app.logger.error(f"Erreur stats ibau: {e}")
        return jsonify({'success': False, 'error': str(e)}), 500


@maintenance_ibau_blueprint.route('/ibau/export', methods=['GET'])
def export_ibau():
    """Export CSV (';', BOM UTF-8 pour Excel) du perimetre filtre courant."""
    try:
        where_sql, params = _build_where(request.args)
        order_by = request.args.get('order_by', 'code', type=str)
        if order_by not in ORDERABLE:
            order_by = 'code'
        order_dir = 'DESC' if (request.args.get('order') or '').lower() == 'desc' else 'ASC'

        cols_sql = ', '.join(COLUMNS)
        with get_db_connection() as conn:
            cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
            cursor.execute(
                f"""
                SELECT {cols_sql}
                FROM clean_data.ibau_article
                {where_sql}
                ORDER BY {order_by} {order_dir} NULLS LAST, id ASC
                """,
                params
            )
            rows = cursor.fetchall()

        output = io.StringIO()
        writer = csv.DictWriter(output, fieldnames=COLUMNS, delimiter=';', extrasaction='ignore')
        writer.writeheader()
        for r in rows:
            writer.writerow({c: (r.get(c) if r.get(c) is not None else '') for c in COLUMNS})

        # BOM : sans lui Excel casse les accents des designations.
        body = '﻿' + output.getvalue()
        return Response(
            body,
            mimetype='text/csv',
            headers={
                'Content-Disposition': 'attachment; filename=ibau.csv',
                'Content-Type': 'text/csv; charset=utf-8',
            }
        )

    except Exception as e:
        current_app.logger.error(f"Erreur export ibau: {e}")
        return jsonify({'success': False, 'error': str(e)}), 500


@maintenance_ibau_blueprint.route('/ibau', methods=['POST'])
def create_ibau():
    """Creation d'un IBAU par l'equipe (source = MANUAL)."""
    try:
        data = request.get_json() or {}
        code = (data.get('code') or '').strip()
        if not code:
            return jsonify({'success': False, 'error': 'Le code est obligatoire'}), 400

        cols = ['code'] + [c for c in EDITABLE_COLUMNS
                           if c != 'code' and data.get(c) not in ('', None)]
        values = [code] + [data[c] for c in cols[1:]]

        with get_db_connection() as conn:
            cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
            try:
                cursor.execute(
                    f"""
                    INSERT INTO clean_data.ibau_article ({', '.join(cols)}, source, created_by)
                    VALUES ({', '.join(['%s'] * len(cols))}, 'MANUAL', %s)
                    RETURNING id
                    """,
                    values + [_user()]
                )
            except psycopg2.errors.UniqueViolation:
                conn.rollback()
                return jsonify({'success': False,
                                'error': f'Le code « {code} » existe déjà dans la liste'}), 409
            new_id = cursor.fetchone()['id']
            conn.commit()

        cache_invalidate(CACHE_PREFIX)
        return jsonify({'success': True, 'data': {'id': new_id}}), 201

    except Exception as e:
        current_app.logger.error(f"Erreur creation ibau: {e}")
        return jsonify({'success': False, 'error': str(e)}), 500


@maintenance_ibau_blueprint.route('/ibau/<int:row_id>', methods=['PUT'])
def update_ibau(row_id: int):
    """Mise a jour partielle d'une ligne (colonnes modifiables uniquement)."""
    try:
        data = request.get_json() or {}
        updates = []
        values = []
        for key, val in data.items():
            if key not in EDITABLE_COLUMNS:
                continue
            if key == 'code':
                val = (val or '').strip()
                if not val:
                    return jsonify({'success': False, 'error': 'Le code ne peut pas être vide'}), 400
            updates.append(f"{key} = %s")
            values.append(val if val not in ('', None) else None)

        if not updates:
            return jsonify({'success': False, 'error': 'Aucun champ a mettre a jour'}), 400

        updates += ["updated_at = NOW()", "updated_by = %s"]
        values.append(_user())

        with get_db_connection() as conn:
            cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
            try:
                cursor.execute(
                    f"UPDATE clean_data.ibau_article SET {', '.join(updates)} "
                    f"WHERE id = %s AND is_active",
                    values + [row_id]
                )
            except psycopg2.errors.UniqueViolation:
                conn.rollback()
                return jsonify({'success': False,
                                'error': 'Ce code existe déjà dans la liste'}), 409
            if cursor.rowcount == 0:
                conn.rollback()
                return jsonify({'success': False, 'error': 'Ligne non trouvee'}), 404
            conn.commit()

        cache_invalidate(CACHE_PREFIX)
        modified = [k for k in data.keys() if k in EDITABLE_COLUMNS]
        return jsonify({'success': True,
                        'message': f'{len(modified)} champ(s) mis a jour',
                        'modified': modified}), 200

    except Exception as e:
        current_app.logger.error(f"Erreur update ibau {row_id}: {e}")
        return jsonify({'success': False, 'error': str(e)}), 500


@maintenance_ibau_blueprint.route('/ibau/<int:row_id>', methods=['DELETE'])
def delete_ibau(row_id: int):
    """Suppression logique (is_active = FALSE) : le code redevient disponible."""
    try:
        with get_db_connection() as conn:
            cursor = conn.cursor()
            cursor.execute(
                "UPDATE clean_data.ibau_article "
                "SET is_active = FALSE, updated_at = NOW(), updated_by = %s "
                "WHERE id = %s AND is_active",
                [_user(), row_id]
            )
            if cursor.rowcount == 0:
                conn.rollback()
                return jsonify({'success': False, 'error': 'Ligne non trouvee'}), 404
            conn.commit()

        cache_invalidate(CACHE_PREFIX)
        return jsonify({'success': True, 'message': 'Ligne supprimee'}), 200

    except Exception as e:
        current_app.logger.error(f"Erreur suppression ibau {row_id}: {e}")
        return jsonify({'success': False, 'error': str(e)}), 500
