"""
API pour la hiérarchie IH02 (postes techniques SAP)
Données issues des tables standard SAP :
  - iflot  / iflotx : hiérarchie des postes techniques (tplma = parent)
  - iflo   : affectation PM (ppsid = poste de travail) — optionnelle si la table n'est pas en raw_data
  - itob   : vue équipements (equi + eqkt + equz + iloa)
  - equi, eqkt, equz, iloa : tables maîtres équipements (pour mutations)
  - crhd, crtx : postes de travail
  - mara, makt : articles
"""
from flask import Blueprint, jsonify, request, current_app, Response
import psycopg2.extras
import csv
import io
from config.database import get_db_connection

ih02_hierarchy_blueprint = Blueprint('ih02_hierarchy', __name__)

def _raw_table_exists(cursor, table_name: str) -> bool:
    cursor.execute(
        """
        SELECT 1 FROM information_schema.tables
        WHERE table_schema = 'raw_data' AND table_name = %s
        LIMIT 1
        """,
        (table_name.lower(),),
    )
    return cursor.fetchone() is not None


def _iflo_available(cursor) -> bool:
    """SAP IFLO (poste de travail PM par tplnr) — absent si non extrait dans raw_data."""
    return _raw_table_exists(cursor, 'iflo')


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

_DESCENDANTS_CTE = """
WITH RECURSIVE descendants AS (
    SELECT tplnr FROM raw_data.iflot WHERE tplnr = %s
    UNION ALL
    SELECT c.tplnr
    FROM raw_data.iflot c
    JOIN descendants d ON c.tplma = d.tplnr
)
"""

_LEVEL_CTE = """
WITH RECURSIVE tree AS (
    SELECT tplnr, 0 AS lvl
    FROM raw_data.iflot
    WHERE tplma IS NULL OR TRIM(tplma) = ''
    UNION ALL
    SELECT c.tplnr, t.lvl + 1
    FROM raw_data.iflot c
    JOIN tree t ON c.tplma = t.tplnr
)
"""

_ROOT_FILTER = "(i.tplma IS NULL OR TRIM(i.tplma) = '')"


def _location_columns(level_expr, extra=''):
    """Colonnes standard pour un poste technique (mode SAP IH01)."""
    cols = f"""
        i.tplnr  AS row_id,
        i.tplnr  AS node_id,
        COALESCE(NULLIF(TRIM(s.strno), ''), i.tplnr) AS display_name,
        CASE
            WHEN xf.pltxt IS NOT NULL AND TRIM(xf.pltxt) <> '' AND LOWER(TRIM(xf.pltxt)) <> 'vide'
                THEN xf.pltxt
            WHEN xe.pltxt IS NOT NULL AND TRIM(xe.pltxt) <> '' AND LOWER(TRIM(xe.pltxt)) <> 'vide'
                THEN xe.pltxt
            WHEN xa.pltxt IS NOT NULL AND TRIM(xa.pltxt) <> '' AND LOWER(TRIM(xa.pltxt)) <> 'vide'
                THEN xa.pltxt
            ELSE COALESCE(NULLIF(TRIM(s.strno), ''), i.tplnr)
        END AS designation,
        i.fltyp  AS type_poste,
        s.tplkz  AS structure_indicator,
        NULL::text AS centre_couts,
        cr_r.arbpl AS poste_travail_resp_maintenance,
        NULL::text AS art_type_construction,
        NULL::text AS quantite,
        NULL::text AS unite,
        {level_expr} AS level
    """
    if extra:
        cols += ', ' + extra
    return cols


def _location_joins(iflo_ok: bool):
    """Jointures : IFLOS (STRNO/TPLKZ comme SAP IH01) + IFLOTX (F/E/any) + IFLO (PM)."""
    base = """
        LEFT JOIN raw_data.iflos s
            ON s.tplnr = i.tplnr AND s.mandt = i.mandt
        LEFT JOIN raw_data.iflotx xf
            ON xf.tplnr = i.tplnr AND xf.mandt = i.mandt AND xf.spras = 'F'
        LEFT JOIN raw_data.iflotx xe
            ON xe.tplnr = i.tplnr AND xe.mandt = i.mandt AND xe.spras = 'E'
        LEFT JOIN LATERAL (
            SELECT pltxt FROM raw_data.iflotx
            WHERE tplnr = i.tplnr AND mandt = i.mandt
              AND pltxt IS NOT NULL AND TRIM(pltxt) <> ''
              AND LOWER(TRIM(pltxt)) <> 'vide'
            LIMIT 1
        ) xa ON TRUE
    """
    if iflo_ok:
        return base + """
        LEFT JOIN raw_data.iflo fl
            ON fl.tplnr = i.tplnr AND fl.mandt = i.mandt AND fl.spras = 'F'
        LEFT JOIN raw_data.crhd cr_r
            ON cr_r.objid = fl.ppsid AND fl.ppsid != '00000000'
    """
    return base + """
        LEFT JOIN raw_data.crhd cr_r ON FALSE
    """


def _node_details_joins(iflo_ok: bool):
    """Jointures détails noeud (IFLOS + IFLOTX + IFLO/CRHD/CRTX)."""
    base = """
                LEFT JOIN raw_data.iflos s
                    ON s.tplnr = i.tplnr AND s.mandt = i.mandt
                LEFT JOIN raw_data.iflos ps
                    ON ps.tplnr = i.tplma AND ps.mandt = i.mandt
                LEFT JOIN raw_data.iflotx xf
                    ON xf.tplnr = i.tplnr AND xf.mandt = i.mandt AND xf.spras = 'F'
                LEFT JOIN raw_data.iflotx xe
                    ON xe.tplnr = i.tplnr AND xe.mandt = i.mandt AND xe.spras = 'E'
                LEFT JOIN LATERAL (
                    SELECT pltxt FROM raw_data.iflotx
                    WHERE tplnr = i.tplnr AND mandt = i.mandt
                      AND pltxt IS NOT NULL AND TRIM(pltxt) <> ''
                      AND LOWER(TRIM(pltxt)) <> 'vide'
                    LIMIT 1
                ) xa ON TRUE
    """
    if iflo_ok:
        return base + """
                LEFT JOIN raw_data.iflo fl
                    ON fl.tplnr = i.tplnr AND fl.mandt = i.mandt AND fl.spras = 'F'
                LEFT JOIN raw_data.crhd cr_r
                    ON cr_r.objid = fl.ppsid AND fl.ppsid != '00000000'
                LEFT JOIN raw_data.crtx ctx_r
                    ON ctx_r.objid = cr_r.objid AND ctx_r.spras = 'F'
        """
    return base + """
                LEFT JOIN raw_data.crhd cr_r ON FALSE
                LEFT JOIN raw_data.crtx ctx_r ON FALSE
    """


def _get_mandt(cursor):
    cursor.execute("SELECT mandt FROM raw_data.iflot LIMIT 1")
    row = cursor.fetchone()
    return row['mandt'] if row else '500'


# ---------------------------------------------------------------------------
# Routes : postes techniques (locations)
# ---------------------------------------------------------------------------

@ih02_hierarchy_blueprint.route('/root-nodes', methods=['GET'])
def get_root_nodes():
    """Postes techniques racines (tplma vide)."""
    try:
        with get_db_connection() as conn:
            cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
            ifa = _iflo_available(cursor)
            query = f"""
                WITH children_counts AS (
                    SELECT tplma, COUNT(*) AS cnt
                    FROM raw_data.iflot
                    WHERE tplma IS NOT NULL AND TRIM(tplma) != ''
                    GROUP BY tplma
                )
                SELECT
                    {_location_columns('0', 'COALESCE(cc.cnt, 0) AS children_count')}
                FROM raw_data.iflot i
                {_location_joins(ifa)}
                LEFT JOIN children_counts cc ON cc.tplma = i.tplnr
                WHERE {_ROOT_FILTER}
                ORDER BY i.tplnr
            """
            cursor.execute(query)
            nodes = cursor.fetchall()
            return jsonify({'success': True, 'data': nodes, 'total': len(nodes)}), 200
    except Exception as e:
        current_app.logger.error(f"Erreur récupération racines IH02: {e}")
        return jsonify({'success': False, 'error': str(e)}), 500


@ih02_hierarchy_blueprint.route('/children', methods=['GET'])
def get_children():
    """Enfants directs : sous-postes techniques (iflot.tplma) + équipements (itob)."""
    try:
        parent_level = request.args.get('parent_level', type=int)
        parent_id = request.args.get('parent_id', type=str)
        if parent_level is None or not parent_id:
            return jsonify({'success': False, 'error': 'parent_level et parent_id requis'}), 400

        child_level = parent_level + 1

        with get_db_connection() as conn:
            cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
            ifa = _iflo_available(cursor)

            loc_query = f"""
                WITH children_counts AS (
                    SELECT tplma, COUNT(*) AS cnt
                    FROM raw_data.iflot
                    WHERE tplma IS NOT NULL AND TRIM(tplma) != ''
                    GROUP BY tplma
                )
                SELECT
                    {_location_columns('%s', 'COALESCE(cc.cnt, 0) AS children_count')}
                FROM raw_data.iflot i
                {_location_joins(ifa)}
                LEFT JOIN children_counts cc ON cc.tplma = i.tplnr
                WHERE i.tplma = %s
                ORDER BY i.tplnr
            """
            cursor.execute(loc_query, [child_level, parent_id])
            children = cursor.fetchall()

            eq_query = """
                SELECT
                    t.equnr,
                    LTRIM(t.equnr, '0') AS equnr_short,
                    COALESCE(t.eqktx, 'Équipement ' || LTRIM(t.equnr, '0')) AS designation,
                    t.eqart  AS type_poste,
                    t.herst  AS manufacturer,
                    t.typbz  AS model,
                    t.sernr  AS serial_number,
                    t.inbdt  AS start_date,
                    t.kostl  AS centre_couts,
                    t.iwerk  AS maintenance_plant,
                    t.ingrp  AS planner_group,
                    t.matnr  AS material_number,
                    t.tplnr  AS parent_tplnr,
                    ez.gewrk,
                    cr.arbpl,
                    ctx.ktext AS poste_travail_texte,
                    COALESCE((SELECT COUNT(*) FROM raw_data.itob c WHERE c.hequi = t.equnr), 0) AS children_count
                FROM raw_data.itob t
                LEFT JOIN raw_data.equz ez ON ez.equnr = t.equnr AND ez.datbi = '99991231'
                LEFT JOIN raw_data.crhd cr  ON cr.objid  = ez.gewrk
                LEFT JOIN raw_data.crtx ctx ON ctx.objid = cr.objid AND ctx.spras = 'F'
                WHERE t.tplnr = %s
                  AND (t.hequi IS NULL OR t.hequi = '' OR t.hequi = '000000000000000000')
                ORDER BY t.equnr
            """
            cursor.execute(eq_query, [parent_id])
            equipment = cursor.fetchall()

            return jsonify({
                'success': True,
                'data': {'locations': children, 'equipment': equipment},
                'total': len(children) + len(equipment),
            }), 200
    except Exception as e:
        current_app.logger.error(f"Erreur récupération enfants IH02: {e}")
        return jsonify({'success': False, 'error': str(e)}), 500


@ih02_hierarchy_blueprint.route('/node-details', methods=['GET'])
def get_node_details():
    """Détails d'un poste technique identifié par row_id (= tplnr) ou node_id."""
    try:
        tplnr = request.args.get('row_id', type=str) or request.args.get('node_id', type=str)
        if not tplnr:
            return jsonify({'success': False, 'error': 'row_id ou node_id requis'}), 400

        with get_db_connection() as conn:
            cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
            ifa = _iflo_available(cursor)

            # Déterminer le niveau via CTE récursif
            cursor.execute(f"""
                {_LEVEL_CTE}
                SELECT
                    i.tplnr  AS row_id,
                    i.tplnr  AS node_id,
                    COALESCE(NULLIF(TRIM(s.strno), ''), i.tplnr) AS display_name,
                    COALESCE(NULLIF(TRIM(ps.strno), ''), i.tplma) AS display_parent,
                    CASE
                        WHEN xf.pltxt IS NOT NULL AND TRIM(xf.pltxt) <> '' AND LOWER(TRIM(xf.pltxt)) <> 'vide'
                            THEN xf.pltxt
                        WHEN xe.pltxt IS NOT NULL AND TRIM(xe.pltxt) <> '' AND LOWER(TRIM(xe.pltxt)) <> 'vide'
                            THEN xe.pltxt
                        WHEN xa.pltxt IS NOT NULL AND TRIM(xa.pltxt) <> '' AND LOWER(TRIM(xa.pltxt)) <> 'vide'
                            THEN xa.pltxt
                        ELSE COALESCE(NULLIF(TRIM(s.strno), ''), i.tplnr)
                    END AS designation,
                    i.fltyp  AS type_poste,
                    s.tplkz  AS structure_indicator,
                    NULL::text AS centre_couts,
                    cr_r.arbpl AS poste_travail_resp_maintenance,
                    NULL::text AS art_type_construction,
                    NULL::text AS quantite,
                    NULL::text AS unite,
                    COALESCE(t.lvl, 0) AS level,
                    i.tplma  AS parent_node_id,
                    (SELECT COUNT(*) FROM raw_data.itob it WHERE it.tplnr = i.tplnr) AS equipment_count,
                    cr_r.objid AS gewrk,
                    ctx_r.ktext AS poste_resp_texte
                FROM raw_data.iflot i
                LEFT JOIN tree t ON t.tplnr = i.tplnr
                {_node_details_joins(ifa)}
                WHERE i.tplnr = %s
                LIMIT 1
            """, [tplnr])
            node = cursor.fetchone()
            if not node:
                return jsonify({'success': False, 'error': 'Noeud non trouvé'}), 404

            # Poste de travail hérité : remonter la hiérarchie tplma
            node['poste_travail'] = None
            node['poste_travail_texte'] = None
            walk = tplnr
            while walk and ifa:
                cursor.execute("""
                    SELECT DISTINCT cr.arbpl, ctx.ktext
                    FROM raw_data.iflo fl
                    JOIN raw_data.crhd cr ON cr.objid = fl.ppsid
                    LEFT JOIN raw_data.crtx ctx ON ctx.objid = cr.objid AND ctx.spras = 'F'
                    WHERE fl.tplnr = %s AND fl.ppsid != '00000000'
                    LIMIT 1
                """, [walk])
                result = cursor.fetchone()
                if result:
                    node['poste_travail'] = result['arbpl']
                    node['poste_travail_texte'] = result['ktext']
                    break
                cursor.execute("SELECT tplma FROM raw_data.iflot WHERE tplnr = %s", [walk])
                parent = cursor.fetchone()
                if parent and parent['tplma'] and parent['tplma'].strip():
                    walk = parent['tplma']
                else:
                    break

            return jsonify({'success': True, 'data': node}), 200
    except Exception as e:
        current_app.logger.error(f"Erreur détails noeud IH02: {e}")
        return jsonify({'success': False, 'error': str(e)}), 500


@ih02_hierarchy_blueprint.route('/search', methods=['GET'])
def search_nodes():
    """Recherche dans la hiérarchie : postes techniques (iflot/iflotx) + équipements (itob)."""
    try:
        q = request.args.get('q', '', type=str)
        if not q or len(q) < 2:
            return jsonify({'success': False, 'error': 'Min 2 caractères'}), 400

        with get_db_connection() as conn:
            cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
            ifa = _iflo_available(cursor)
            pattern = f'%{q}%'

            loc_query = f"""
                {_LEVEL_CTE}
                SELECT
                    i.tplnr  AS row_id,
                    i.tplnr  AS node_id,
                    COALESCE(NULLIF(TRIM(s.strno), ''), i.tplnr) AS display_name,
                    COALESCE(t.lvl, 0) AS level,
                    CASE
                        WHEN xf.pltxt IS NOT NULL AND TRIM(xf.pltxt) <> '' AND LOWER(TRIM(xf.pltxt)) <> 'vide'
                            THEN xf.pltxt
                        WHEN xe.pltxt IS NOT NULL AND TRIM(xe.pltxt) <> '' AND LOWER(TRIM(xe.pltxt)) <> 'vide'
                            THEN xe.pltxt
                        WHEN xa.pltxt IS NOT NULL AND TRIM(xa.pltxt) <> '' AND LOWER(TRIM(xa.pltxt)) <> 'vide'
                            THEN xa.pltxt
                        ELSE COALESCE(NULLIF(TRIM(s.strno), ''), i.tplnr)
                    END AS designation,
                    i.fltyp  AS type_poste,
                    s.tplkz  AS structure_indicator,
                    NULL::text AS centre_couts,
                    cr_r.arbpl AS poste_travail_resp_maintenance,
                    NULL::text AS art_type_construction,
                    NULL::text AS quantite,
                    NULL::text AS unite
                FROM raw_data.iflot i
                LEFT JOIN tree t ON t.tplnr = i.tplnr
                {_location_joins(ifa)}
                WHERE i.tplnr ILIKE %s
                   OR s.strno ILIKE %s
                   OR xf.pltxt ILIKE %s
                   OR xe.pltxt ILIKE %s
                ORDER BY COALESCE(NULLIF(TRIM(s.strno), ''), i.tplnr)
                LIMIT 100
            """
            cursor.execute(loc_query, [pattern, pattern, pattern, pattern])
            location_results = cursor.fetchall()

            eq_query = """
                SELECT
                    t.equnr,
                    LTRIM(t.equnr, '0') AS equnr_short,
                    COALESCE(t.eqktx, 'Équipement ' || LTRIM(t.equnr, '0')) AS designation,
                    t.eqart  AS type_poste,
                    t.herst  AS fabricant,
                    t.kostl  AS centre_couts,
                    t.tplnr  AS poste_technique,
                    t.iwerk  AS division_maintenance
                FROM raw_data.itob t
                WHERE t.eqktx ILIKE %s
                   OR t.equnr ILIKE %s
                   OR LTRIM(t.equnr, '0') ILIKE %s
                   OR t.herst ILIKE %s
                ORDER BY t.equnr
                LIMIT 50
            """
            cursor.execute(eq_query, [pattern] * 4)
            eq_rows = cursor.fetchall()
            equipment_results = [
                {**row, 'node_type': 'equipment'} for row in eq_rows
            ]

            return jsonify({
                'success': True,
                'data': {'locations': location_results, 'equipment': equipment_results},
                'total': len(location_results) + len(equipment_results),
            }), 200
    except Exception as e:
        current_app.logger.error(f"Erreur recherche IH02: {e}")
        return jsonify({'success': False, 'error': str(e)}), 500


@ih02_hierarchy_blueprint.route('/update-location', methods=['PUT'])
def update_location():
    """Met à jour un poste technique dans iflot / iflotx / iflo."""
    try:
        data = request.get_json()
        tplnr = data.get('row_id') or data.get('node_id')
        if not tplnr:
            return jsonify({'success': False, 'error': 'row_id (tplnr) requis'}), 400

        poste_travail_code = data.get('poste_travail')

        # Validation poste_travail_resp_maintenance
        if data.get('poste_travail_resp_maintenance'):
            with get_db_connection() as chk:
                cur = chk.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
                cur.execute("SELECT 1 FROM raw_data.crhd WHERE arbpl = %s AND werks = '9200' LIMIT 1",
                            [data['poste_travail_resp_maintenance']])
                if not cur.fetchone():
                    return jsonify({'success': False, 'error': f'Poste responsable "{data["poste_travail_resp_maintenance"]}" invalide'}), 400

        if poste_travail_code and poste_travail_code != '':
            with get_db_connection() as chk:
                cur = chk.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
                cur.execute("SELECT 1 FROM raw_data.crhd WHERE arbpl = %s AND werks = '9200' LIMIT 1",
                            [poste_travail_code])
                if not cur.fetchone():
                    return jsonify({'success': False, 'error': f'Poste de travail "{poste_travail_code}" invalide'}), 400

        with get_db_connection() as conn:
            cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
            modified = []
            iflo_ok = _iflo_available(cursor)

            cursor.execute("SELECT tplnr, mandt FROM raw_data.iflot WHERE tplnr = %s LIMIT 1", [tplnr])
            row = cursor.fetchone()
            if not row:
                return jsonify({'success': False, 'error': f'Poste technique "{tplnr}" non trouvé'}), 404
            mandt = row['mandt']

            # 1) Désignation → iflotx.pltxt
            if 'designation' in data:
                cursor.execute("""
                    UPDATE raw_data.iflotx SET pltxt = %s
                    WHERE tplnr = %s AND spras = 'F'
                """, [data['designation'], tplnr])
                if cursor.rowcount == 0:
                    cursor.execute("""
                        INSERT INTO raw_data.iflotx (mandt, tplnr, spras, pltxt)
                        VALUES (%s, %s, 'F', %s)
                    """, [mandt, tplnr, data['designation']])
                modified.append('Désignation')

            # 2) Changement de parent → iflot.tplma
            if 'parent_node_id' in data:
                new_parent = data['parent_node_id']
                if new_parent:
                    cursor.execute("SELECT 1 FROM raw_data.iflot WHERE tplnr = %s", [new_parent])
                    if not cursor.fetchone():
                        conn.rollback()
                        return jsonify({'success': False, 'error': f'Parent "{new_parent}" non trouvé'}), 404
                cursor.execute(
                    "UPDATE raw_data.iflot SET tplma = %s WHERE tplnr = %s",
                    [new_parent if new_parent else None, tplnr]
                )
                modified.append('Parent')

            # 3) Poste de travail → iflo.ppsid
            if poste_travail_code is not None:
                if not iflo_ok:
                    conn.rollback()
                    return jsonify({
                        'success': False,
                        'error': 'Table raw_data.iflo absente : impossible de persister le poste de travail. Extrayez la table SAP IFLO dans raw_data.',
                    }), 400
                if poste_travail_code == '':
                    cursor.execute("""
                        UPDATE raw_data.iflo SET ppsid = '00000000'
                        WHERE tplnr = %s
                    """, [tplnr])
                    modified.append('Poste de travail (vidé)')
                else:
                    cursor.execute("""
                        SELECT objid FROM raw_data.crhd
                        WHERE arbpl = %s AND werks = '9200' LIMIT 1
                    """, [poste_travail_code])
                    cr = cursor.fetchone()
                    if not cr:
                        conn.rollback()
                        return jsonify({'success': False, 'error': f'Poste de travail "{poste_travail_code}" introuvable dans CRHD'}), 400
                    cursor.execute("UPDATE raw_data.iflo SET ppsid = %s WHERE tplnr = %s",
                                   [cr['objid'], tplnr])
                    modified.append(f'Poste de travail → {poste_travail_code}')

            if not modified and poste_travail_code is None:
                return jsonify({'success': False, 'error': 'Aucun champ modifiable fourni'}), 400

            conn.commit()
            msg = f'{len(modified)} champ(s) mis à jour' if modified else 'Poste technique mis à jour'
            return jsonify({'success': True, 'message': msg, 'modified': modified}), 200
    except Exception as e:
        current_app.logger.error(f"Erreur mise à jour location IH02: {e}")
        return jsonify({'success': False, 'error': f'Erreur serveur: {str(e)}'}), 500


@ih02_hierarchy_blueprint.route('/stats', methods=['GET'])
def get_stats():
    """Statistiques globales de la hiérarchie."""
    try:
        with get_db_connection() as conn:
            cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
            cursor.execute(f"""
                {_LEVEL_CTE}
                SELECT
                    COUNT(*) AS total_nodes,
                    COUNT(DISTINCT f.fltyp) FILTER (WHERE f.fltyp IS NOT NULL AND TRIM(f.fltyp) != '') AS distinct_types,
                    0 AS distinct_cost_centers,
                    COUNT(*) FILTER (WHERE t.lvl = 0) AS level_0,
                    COUNT(*) FILTER (WHERE t.lvl = 1) AS level_1,
                    COUNT(*) FILTER (WHERE t.lvl = 2) AS level_2,
                    COUNT(*) FILTER (WHERE t.lvl = 3) AS level_3,
                    COUNT(*) FILTER (WHERE t.lvl = 4) AS level_4,
                    COUNT(*) FILTER (WHERE t.lvl = 5) AS level_5,
                    COUNT(*) FILTER (WHERE t.lvl >= 6) AS level_6_plus
                FROM tree t
                JOIN raw_data.iflot f ON f.tplnr = t.tplnr
            """)
            stats = cursor.fetchone()
            return jsonify({'success': True, 'data': stats}), 200
    except Exception as e:
        current_app.logger.error(f"Erreur stats IH02: {e}")
        return jsonify({'success': False, 'error': str(e)}), 500


@ih02_hierarchy_blueprint.route('/export-structures', methods=['GET'])
def export_structures():
    """Export CSV des postes techniques (iflot / iflotx)."""
    try:
        with get_db_connection() as conn:
            cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
            ifa = _iflo_available(cursor)
            cursor.execute(f"""
                {_LEVEL_CTE}
                SELECT
                    i.tplnr,
                    COALESCE(NULLIF(TRIM(s.strno), ''), i.tplnr) AS structured_id,
                    i.tplma AS parent,
                    COALESCE(NULLIF(TRIM(ps.strno), ''), i.tplma) AS parent_structured,
                    t.lvl   AS niveau,
                    CASE
                        WHEN xf.pltxt IS NOT NULL AND TRIM(xf.pltxt) <> '' AND LOWER(TRIM(xf.pltxt)) <> 'vide'
                            THEN xf.pltxt
                        WHEN xe.pltxt IS NOT NULL AND TRIM(xe.pltxt) <> '' AND LOWER(TRIM(xe.pltxt)) <> 'vide'
                            THEN xe.pltxt
                        WHEN xa.pltxt IS NOT NULL AND TRIM(xa.pltxt) <> '' AND LOWER(TRIM(xa.pltxt)) <> 'vide'
                            THEN xa.pltxt
                        ELSE ''
                    END AS designation,
                    COALESCE(i.fltyp, '') AS type_poste,
                    COALESCE(s.tplkz, '') AS structure_indicator,
                    COALESCE(i.iwerk, '') AS division_maintenance,
                    COALESCE(i.ingrp, '') AS groupe_planification,
                    COALESCE(cr_r.arbpl, '') AS poste_travail
                FROM tree t
                JOIN raw_data.iflot i ON i.tplnr = t.tplnr
                LEFT JOIN raw_data.iflos ps ON ps.tplnr = i.tplma AND ps.mandt = i.mandt
                {_location_joins(ifa)}
                ORDER BY COALESCE(NULLIF(TRIM(s.strno), ''), i.tplnr)
            """)
            rows = cursor.fetchall()
            if not rows:
                return jsonify({'success': False, 'error': 'Aucune donnée'}), 404

            output = io.StringIO()
            writer = csv.DictWriter(output, fieldnames=rows[0].keys(), delimiter=';')
            writer.writeheader()
            writer.writerows(rows)
            return Response(
                output.getvalue(),
                mimetype='text/csv',
                headers={'Content-Disposition': 'attachment; filename=ih02_postes_techniques.csv'},
            )
    except Exception as e:
        current_app.logger.error(f"Erreur export structures IH02: {e}")
        return jsonify({'success': False, 'error': str(e)}), 500


@ih02_hierarchy_blueprint.route('/move-node', methods=['PUT'])
def move_node():
    """Déplace un poste technique sous un nouveau parent (UPDATE tplma)."""
    try:
        data = request.get_json()
        tplnr = data.get('row_id') or data.get('node_id')
        new_parent_id = data.get('new_parent_id')

        if not tplnr or not new_parent_id:
            return jsonify({'success': False, 'error': 'row_id/node_id et new_parent_id requis'}), 400

        with get_db_connection() as conn:
            cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)

            cursor.execute("SELECT tplnr FROM raw_data.iflot WHERE tplnr = %s", [tplnr])
            if not cursor.fetchone():
                return jsonify({'success': False, 'error': 'Noeud non trouvé'}), 404

            cursor.execute("SELECT tplnr FROM raw_data.iflot WHERE tplnr = %s", [new_parent_id])
            if not cursor.fetchone():
                return jsonify({'success': False, 'error': f'Parent "{new_parent_id}" non trouvé'}), 404

            # Vérifier que le nouveau parent n'est pas un descendant du noeud déplacé
            cursor.execute(f"""
                {_DESCENDANTS_CTE}
                SELECT 1 FROM descendants WHERE tplnr = %s
            """, [tplnr, new_parent_id])
            if cursor.fetchone():
                return jsonify({'success': False, 'error': 'Impossible de déplacer un noeud sous un de ses descendants'}), 400

            # Compter les descendants pour le message
            cursor.execute(f"""
                {_DESCENDANTS_CTE}
                SELECT COUNT(*) AS cnt FROM descendants
            """, [tplnr])
            desc_count = cursor.fetchone()['cnt']

            cursor.execute("UPDATE raw_data.iflot SET tplma = %s WHERE tplnr = %s", [new_parent_id, tplnr])
            conn.commit()

            return jsonify({
                'success': True,
                'message': f'Noeud et {desc_count - 1} descendant(s) déplacés',
            }), 200
    except Exception as e:
        current_app.logger.error(f"Erreur déplacement noeud IH02: {e}")
        return jsonify({'success': False, 'error': str(e)}), 500


@ih02_hierarchy_blueprint.route('/descendants-count', methods=['GET'])
def descendants_count():
    """Nombre de descendants d'un noeud (lui-même inclus)."""
    try:
        node_id = request.args.get('node_id', type=str)
        if not node_id:
            return jsonify({'success': False, 'error': 'node_id requis'}), 400

        with get_db_connection() as conn:
            cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
            cursor.execute(f"""
                {_DESCENDANTS_CTE}
                SELECT COUNT(*) AS count FROM descendants
            """, [node_id])
            result = cursor.fetchone()
            return jsonify({
                'success': True,
                'data': {'count': result['count'], 'node_id': node_id},
            }), 200
    except Exception as e:
        current_app.logger.error(f"Erreur comptage descendants IH02: {e}")
        return jsonify({'success': False, 'error': str(e)}), 500


@ih02_hierarchy_blueprint.route('/bulk-update', methods=['PUT'])
def bulk_update():
    """Modifications en masse sur un noeud et tous ses descendants."""
    try:
        data = request.get_json()
        node_id = data.get('node_id')
        updates = data.get('updates', [])

        if not node_id or not updates:
            return jsonify({'success': False, 'error': 'node_id et updates requis'}), 400

        # Seule la désignation est modifiable en masse via iflotx
        designation_update = None
        for u in updates:
            if u.get('field') == 'designation':
                designation_update = u.get('value')

        if designation_update is None:
            return jsonify({
                'success': True,
                'message': 'Aucun champ modifiable dans les tables standard',
                'data': {'updated_count': 0},
            }), 200

        with get_db_connection() as conn:
            cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)

            cursor.execute("SELECT tplnr FROM raw_data.iflot WHERE tplnr = %s", [node_id])
            if not cursor.fetchone():
                return jsonify({'success': False, 'error': 'Noeud non trouvé'}), 404

            cursor.execute(f"""
                {_DESCENDANTS_CTE}
                UPDATE raw_data.iflotx
                SET pltxt = %s
                WHERE tplnr IN (SELECT tplnr FROM descendants)
                  AND spras = 'F'
            """, [node_id, designation_update])
            updated_count = cursor.rowcount
            conn.commit()

            return jsonify({
                'success': True,
                'message': f'{updated_count} noeud(s) mis à jour',
                'data': {'updated_count': updated_count},
            }), 200
    except Exception as e:
        current_app.logger.error(f"Erreur modification en masse IH02: {e}")
        return jsonify({'success': False, 'error': str(e)}), 500


@ih02_hierarchy_blueprint.route('/add-node', methods=['POST'])
def add_node():
    """Ajoute un nouveau poste technique sous un parent."""
    try:
        data = request.get_json()
        parent_id = data.get('parent_id', '').strip()
        node_id = data.get('node_id', '').strip()
        designation = data.get('designation', '').strip()

        if not parent_id:
            return jsonify({'success': False, 'error': 'parent_id requis'}), 400
        if not node_id:
            return jsonify({'success': False, 'error': 'node_id (identifiant) requis'}), 400
        if not designation:
            return jsonify({'success': False, 'error': 'designation requis'}), 400

        with get_db_connection() as conn:
            cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)

            cursor.execute("SELECT tplnr FROM raw_data.iflot WHERE tplnr = %s", [parent_id])
            if not cursor.fetchone():
                return jsonify({'success': False, 'error': f'Parent "{parent_id}" non trouvé'}), 404

            cursor.execute("SELECT tplnr FROM raw_data.iflot WHERE tplnr = %s", [node_id])
            if cursor.fetchone():
                return jsonify({'success': False, 'error': f'L\'identifiant "{node_id}" existe déjà'}), 409

            mandt = _get_mandt(cursor)

            # Déterminer le niveau du parent pour le retour
            cursor.execute(f"""
                {_LEVEL_CTE}
                SELECT lvl FROM tree WHERE tplnr = %s
            """, [parent_id])
            parent_row = cursor.fetchone()
            parent_level = parent_row['lvl'] if parent_row else 0

            cursor.execute("""
                INSERT INTO raw_data.iflot (mandt, tplnr, tplma, fltyp, iwerk)
                VALUES (%s, %s, %s, %s, '9200')
            """, [mandt, node_id, parent_id, data.get('type_poste') or ''])

            cursor.execute("""
                INSERT INTO raw_data.iflotx (mandt, tplnr, spras, pltxt)
                VALUES (%s, %s, 'F', %s)
            """, [mandt, node_id, designation])

            conn.commit()
            return jsonify({
                'success': True,
                'message': f'Poste technique "{node_id}" créé',
                'data': {'row_id': node_id, 'node_id': node_id, 'level': parent_level + 1},
            }), 201
    except Exception as e:
        current_app.logger.error(f"Erreur ajout noeud IH02: {e}")
        return jsonify({'success': False, 'error': str(e)}), 500


@ih02_hierarchy_blueprint.route('/delete-node', methods=['DELETE'])
def delete_node():
    """Supprime un poste technique et tous ses descendants."""
    try:
        tplnr = request.args.get('row_id', type=str) or request.args.get('node_id', type=str)
        if not tplnr:
            return jsonify({'success': False, 'error': 'row_id ou node_id requis'}), 400

        with get_db_connection() as conn:
            cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)

            cursor.execute("SELECT tplnr FROM raw_data.iflot WHERE tplnr = %s", [tplnr])
            if not cursor.fetchone():
                return jsonify({'success': False, 'error': 'Noeud non trouvé'}), 404

            iflo_ok = _iflo_available(cursor)

            # Compter avant suppression
            cursor.execute(f"""
                {_DESCENDANTS_CTE}
                SELECT COUNT(*) AS cnt FROM descendants
            """, [tplnr])
            count = cursor.fetchone()['cnt']

            # Supprimer les textes
            cursor.execute(f"""
                {_DESCENDANTS_CTE}
                DELETE FROM raw_data.iflotx WHERE tplnr IN (SELECT tplnr FROM descendants)
            """, [tplnr])

            # Supprimer les données PM
            if iflo_ok:
                cursor.execute(f"""
                    {_DESCENDANTS_CTE}
                    DELETE FROM raw_data.iflo WHERE tplnr IN (SELECT tplnr FROM descendants)
                """, [tplnr])

            # Supprimer les postes techniques (feuilles d'abord via CTE)
            cursor.execute(f"""
                {_DESCENDANTS_CTE}
                DELETE FROM raw_data.iflot WHERE tplnr IN (SELECT tplnr FROM descendants)
            """, [tplnr])

            conn.commit()
            return jsonify({
                'success': True,
                'message': f'"{tplnr}" et {count - 1} descendant(s) supprimés',
                'data': {'deleted_count': count},
            }), 200
    except Exception as e:
        current_app.logger.error(f"Erreur suppression noeud IH02: {e}")
        return jsonify({'success': False, 'error': str(e)}), 500


# ---------------------------------------------------------------------------
# Routes : équipements (inchangées — déjà basées sur tables standard)
# ---------------------------------------------------------------------------

@ih02_hierarchy_blueprint.route('/equipment-details', methods=['GET'])
def get_equipment_details():
    """Récupère les détails complets d'un équipement depuis itob"""
    try:
        equnr = request.args.get('equnr', type=str)
        if not equnr:
            return jsonify({'success': False, 'error': 'equnr requis'}), 400

        with get_db_connection() as conn:
            cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)

            cursor.execute("""
                SELECT
                    t.equnr,
                    LTRIM(t.equnr, '0') as equnr_short,
                    COALESCE(t.eqktx, 'Équipement ' || LTRIM(t.equnr, '0')) as designation,
                    t.eqart as type_equipement,
                    t.eqtyp as categorie,
                    t.herst as fabricant,
                    t.herld as pays_fabricant,
                    t.typbz as modele,
                    t.sernr as numero_serie,
                    t.invnr as numero_inventaire,
                    t.groes as taille,
                    t.brgew as poids,
                    t.gewei as unite_poids,
                    t.answt as valeur_acquisition,
                    t.waers as devise,
                    t.ansdt as date_acquisition,
                    t.baujj as annee_construction,
                    t.baumm as mois_construction,
                    t.inbdt as date_mise_service,
                    t.erdat as date_creation,
                    t.ernam as cree_par,
                    t.aedat as date_modification,
                    t.aenam as modifie_par,
                    t.lvorm as indicateur_suppression,
                    t.gwlen as duree_garantie,
                    t.gwldt as fin_garantie,
                    t.elief as fournisseur,
                    t.matnr as numero_article,
                    t.begru as groupe_autorisation,
                    t.kostl as centre_couts,
                    t.bukrs as societe,
                    t.gsber as domaine_activite,
                    t.iwerk as division_maintenance,
                    t.ingrp as groupe_planification,
                    t.swerk as division,
                    t.stort as emplacement,
                    t.beber as section,
                    t.tplnr as poste_technique,
                    t.hequi as equipement_superieur,
                    t.warpl as plan_maintenance,
                    ez.gewrk as gewrk,
                    cr.arbpl as arbpl,
                    ctx.ktext as poste_travail_texte,
                    COALESCE((SELECT COUNT(*) FROM raw_data.itob c WHERE c.hequi = t.equnr), 0) as children_count
                FROM raw_data.itob t
                LEFT JOIN raw_data.equz ez ON ez.equnr = t.equnr AND ez.datbi = '99991231'
                LEFT JOIN raw_data.crhd cr ON cr.objid = ez.gewrk
                LEFT JOIN raw_data.crtx ctx ON ctx.objid = cr.objid AND ctx.spras = 'F'
                WHERE t.equnr = %s
                LIMIT 1
            """, [equnr])
            equipment = cursor.fetchone()

            if not equipment:
                return jsonify({'success': False, 'error': 'Équipement non trouvé'}), 404

            return jsonify({'success': True, 'data': equipment}), 200
    except Exception as e:
        current_app.logger.error(f"Erreur détails équipement IH02: {e}")
        return jsonify({'success': False, 'error': str(e)}), 500


@ih02_hierarchy_blueprint.route('/bom/<path:tplnr>', methods=['GET'])
def get_fl_bom(tplnr):
    """Nomenclature (BOM) d'un poste technique via clean_data.v_fl_nomenclature."""
    try:
        if not tplnr:
            return jsonify({'success': False, 'error': 'tplnr requis'}), 400

        with get_db_connection() as conn:
            cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
            cursor.execute(
                """
                SELECT
                    tplnr,
                    tplnr_display,
                    fl_designation,
                    stlnr,
                    stlal,
                    stlan,
                    base_quantity,
                    base_unit,
                    posnr,
                    idnrk,
                    matnr_short,
                    item_category,
                    quantity,
                    unit,
                    material_type,
                    designation
                FROM clean_data.v_fl_nomenclature
                WHERE tplnr = %s
                ORDER BY sort_order
                """,
                [tplnr],
            )
            rows = cursor.fetchall()

            return jsonify({
                'success': True,
                'data': rows,
                'total': len(rows),
                'tplnr': tplnr,
            }), 200
    except Exception as e:
        current_app.logger.error(f"Erreur BOM IH02 ({tplnr}): {e}")
        return jsonify({'success': False, 'error': str(e)}), 500


def _normalize_sap_matnr(raw: str) -> str:
    """Aligné sur maintenance_articles: numériques → 18 zéros à gauche, sinon tel quel."""
    matnr = (raw or '').strip().upper()
    if not matnr:
        return ''
    if matnr.isdigit():
        return matnr.zfill(18)
    return matnr


@ih02_hierarchy_blueprint.route('/bom-component', methods=['PUT'])
def update_bom_component():
    """Met à jour une ligne de nomenclature FL (STPO) : article (IDNRK), quantité, unité + MAKT optionnel."""
    try:
        data = request.get_json() or {}
        tplnr = (data.get('tplnr') or '').strip()
        stlnr = (data.get('stlnr') or '').strip()
        stlal = (data.get('stlal') or '01').strip() or '01'
        posnr = (data.get('posnr') or '').strip()
        idnrk_raw = (data.get('idnrk') or '').strip()
        idnrk = _normalize_sap_matnr(idnrk_raw)
        menge = data.get('menge')
        meins = (data.get('meins') or '').strip()
        maktx = data.get('maktx')

        if not tplnr or not stlnr or not posnr:
            return jsonify({'success': False, 'error': 'tplnr, stlnr et posnr requis'}), 400
        if not idnrk:
            return jsonify({'success': False, 'error': 'idnrk (article) requis'}), 400
        if menge is None or meins is None or meins == '':
            return jsonify({'success': False, 'error': 'menge et meins requis'}), 400

        with get_db_connection() as conn:
            cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)

            cursor.execute(
                'SELECT mandt FROM raw_data.tpst WHERE tplnr = %s AND stlnr = %s LIMIT 1',
                [tplnr, stlnr],
            )
            lk = cursor.fetchone()
            if not lk:
                return jsonify({'success': False, 'error': 'Lien TPST introuvable pour ce poste / BOM'}), 404

            mandt = lk['mandt']

            cursor.execute(
                """
                UPDATE raw_data.stpo p
                SET idnrk = %s, menge = %s, meins = %s
                WHERE p.mandt = %s AND p.stlty = 'T' AND p.stlnr = %s AND TRIM(p.stlal) = TRIM(%s)
                  AND TRIM(p.posnr) = TRIM(%s)
                """,
                [idnrk, str(menge), meins, mandt, stlnr, stlal, posnr],
            )
            if cursor.rowcount == 0:
                conn.rollback()
                return jsonify({'success': False, 'error': 'Ligne STPO non trouvée (stlty=T, stlnr, stlal, posnr)'}), 404

            if maktx is not None and idnrk:
                mt = str(maktx).strip()
                if len(mt) > 40:
                    conn.rollback()
                    return jsonify({'success': False, 'error': 'maktx max 40 caractères (SAP)'}), 400
                cursor.execute(
                    """
                    UPDATE raw_data.makt SET maktx = %s
                    WHERE mandt = %s AND matnr = %s AND spras = 'F'
                    """,
                    [mt, mandt, idnrk],
                )
                if cursor.rowcount == 0:
                    try:
                        cursor.execute(
                            """
                            INSERT INTO raw_data.makt (mandt, matnr, spras, maktx)
                            VALUES (%s, %s, 'F', %s)
                            """,
                            [mandt, idnrk, mt],
                        )
                    except Exception as ins_err:
                        current_app.logger.warning('makt insert: %s', ins_err)

            try:
                cursor.execute('REFRESH MATERIALIZED VIEW clean_data.v_fl_nomenclature')
            except Exception as ref_err:
                current_app.logger.warning(f'REFRESH v_fl_nomenclature: {ref_err}')

            conn.commit()
            return jsonify({'success': True, 'message': 'Composant BOM mis à jour'}), 200
    except Exception as e:
        current_app.logger.error(f'Erreur update BOM IH02: {e}', exc_info=True)
        return jsonify({'success': False, 'error': str(e)}), 500


@ih02_hierarchy_blueprint.route('/bom-counts', methods=['GET'])
def get_fl_bom_counts():
    """Nombre de composants BOM par TPLNR (pour decorer l'arbre)."""
    try:
        tplnrs = request.args.get('tplnrs', '').strip()
        if not tplnrs:
            return jsonify({'success': True, 'data': {}}), 200

        tplnr_list = [t.strip() for t in tplnrs.split(',') if t.strip()]
        if not tplnr_list:
            return jsonify({'success': True, 'data': {}}), 200

        with get_db_connection() as conn:
            cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
            cursor.execute(
                """
                SELECT tplnr, COUNT(*) AS nb
                FROM clean_data.v_fl_nomenclature
                WHERE tplnr = ANY(%s)
                GROUP BY tplnr
                """,
                [tplnr_list],
            )
            counts = {row['tplnr']: row['nb'] for row in cursor.fetchall()}
            return jsonify({'success': True, 'data': counts}), 200
    except Exception as e:
        current_app.logger.error(f"Erreur BOM counts IH02: {e}")
        return jsonify({'success': False, 'error': str(e)}), 500


@ih02_hierarchy_blueprint.route('/article-bom/<path:matnr>', methods=['GET'])
def get_article_bom(matnr):
    """Nomenclature matière (BOM stlty='M') d'un article, via MAST -> STKO/STPO.

    Un article peut être composé d'autres articles (hiérarchie récursive multi-niveaux).
    Si plusieurs nomenclatures existent (par werks/stlal), on privilégie celle du site 9200.
    Chaque sous-composant renvoie children_count : nb de composants de SA propre BOM
    préférée (pour savoir s'il est lui-même dépliable).
    """
    try:
        norm = _normalize_sap_matnr(matnr)
        if not norm:
            return jsonify({'success': False, 'error': 'matnr requis'}), 400

        with get_db_connection() as conn:
            cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)

            # Nomenclature matière préférée de cet article
            cursor.execute(
                """
                SELECT m.stlnr, m.stlal, m.werks, m.mandt
                FROM raw_data.mast m
                WHERE m.matnr = %s
                ORDER BY (CASE WHEN m.werks = '9200' THEN 0 ELSE 1 END), m.stlal, m.stlnr
                LIMIT 1
                """,
                [norm],
            )
            bom = cursor.fetchone()
            if not bom:
                return jsonify({'success': True, 'data': [], 'total': 0, 'matnr': norm}), 200

            cursor.execute(
                """
                SELECT
                    %s::text AS stlnr,
                    %s::text AS stlal,
                    p.stlkn,
                    p.posnr,
                    p.idnrk,
                    LTRIM(p.idnrk, '0')                                AS matnr_short,
                    p.postp                                            AS item_category,
                    p.menge                                            AS quantity,
                    p.meins                                            AS unit,
                    ma.mtart                                           AS material_type,
                    COALESCE(mk.maktx, NULLIF(TRIM(p.potx1), ''), NULLIF(TRIM(p.potx2), '')) AS designation,
                    COALESCE((
                        SELECT COUNT(*) FROM raw_data.stpo cp
                        WHERE cp.stlty = 'M' AND cp.stlnr = bestc.stlnr AND cp.mandt = bestc.mandt
                          AND cp.idnrk IS NOT NULL AND TRIM(cp.idnrk) <> ''
                    ), 0)                                              AS children_count
                FROM raw_data.stpo p
                LEFT JOIN raw_data.mara ma ON ma.matnr = p.idnrk AND ma.mandt = p.mandt
                LEFT JOIN LATERAL (
                    SELECT maktx FROM raw_data.makt
                    WHERE matnr = p.idnrk AND mandt = p.mandt
                    ORDER BY (CASE WHEN spras = 'F' THEN 0 WHEN spras = 'E' THEN 1 ELSE 2 END)
                    LIMIT 1
                ) mk ON TRUE
                LEFT JOIN LATERAL (
                    SELECT cm.stlnr, cm.mandt FROM raw_data.mast cm
                    WHERE cm.matnr = p.idnrk
                    ORDER BY (CASE WHEN cm.werks = '9200' THEN 0 ELSE 1 END), cm.stlal, cm.stlnr
                    LIMIT 1
                ) bestc ON TRUE
                WHERE p.stlty = 'M' AND p.stlnr = %s AND p.mandt = %s
                  AND p.idnrk IS NOT NULL AND TRIM(p.idnrk) <> ''
                ORDER BY p.posnr, p.stlkn
                """,
                [bom['stlnr'], bom['stlal'], bom['stlnr'], bom['mandt']],
            )
            rows = cursor.fetchall()
            return jsonify({
                'success': True,
                'data': rows,
                'total': len(rows),
                'matnr': norm,
                'stlnr': bom['stlnr'],
            }), 200
    except Exception as e:
        current_app.logger.error(f"Erreur BOM article IH02 ({matnr}): {e}")
        return jsonify({'success': False, 'error': str(e)}), 500


@ih02_hierarchy_blueprint.route('/article-bom-counts', methods=['GET'])
def get_article_bom_counts():
    """Nb de composants de la nomenclature matière préférée, par article (idnrk complet).

    Utilisé pour décorer les composants d'une BOM avec un indicateur de dépliage.
    """
    try:
        matnrs = request.args.get('matnrs', '').strip()
        if not matnrs:
            return jsonify({'success': True, 'data': {}}), 200

        mat_list = [m.strip() for m in matnrs.split(',') if m.strip()]
        if not mat_list:
            return jsonify({'success': True, 'data': {}}), 200

        with get_db_connection() as conn:
            cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
            cursor.execute(
                """
                WITH best AS (
                    SELECT DISTINCT ON (m.matnr) m.matnr, m.stlnr, m.mandt
                    FROM raw_data.mast m
                    WHERE m.matnr = ANY(%s)
                    ORDER BY m.matnr, (CASE WHEN m.werks = '9200' THEN 0 ELSE 1 END), m.stlal, m.stlnr
                )
                SELECT b.matnr,
                       (SELECT COUNT(*) FROM raw_data.stpo p
                        WHERE p.stlty = 'M' AND p.stlnr = b.stlnr AND p.mandt = b.mandt
                          AND p.idnrk IS NOT NULL AND TRIM(p.idnrk) <> '') AS nb
                FROM best b
                """,
                [mat_list],
            )
            counts = {row['matnr']: row['nb'] for row in cursor.fetchall() if row['nb']}
            return jsonify({'success': True, 'data': counts}), 200
    except Exception as e:
        current_app.logger.error(f"Erreur counts BOM article IH02: {e}")
        return jsonify({'success': False, 'error': str(e)}), 500


@ih02_hierarchy_blueprint.route('/article-bom-component', methods=['PUT'])
def update_article_bom_component():
    """Met à jour une ligne de nomenclature matière (STPO stlty='M').

    La ligne est identifiée par (stlnr, stlkn) — stlkn est le seul identifiant unique
    d'une position dans STPO (posnr peut être dupliqué). Met aussi à jour MAKT (optionnel).
    """
    try:
        data = request.get_json() or {}
        stlnr = (data.get('stlnr') or '').strip()
        stlkn = (data.get('stlkn') or '').strip()
        idnrk = _normalize_sap_matnr((data.get('idnrk') or '').strip())
        menge = data.get('menge')
        meins = (data.get('meins') or '').strip()
        maktx = data.get('maktx')

        if not stlnr or not stlkn:
            return jsonify({'success': False, 'error': 'stlnr et stlkn requis'}), 400
        if not idnrk:
            return jsonify({'success': False, 'error': 'idnrk (article) requis'}), 400
        if menge is None or meins == '':
            return jsonify({'success': False, 'error': 'menge et meins requis'}), 400

        with get_db_connection() as conn:
            cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)

            cursor.execute(
                "SELECT mandt FROM raw_data.stpo WHERE stlty = 'M' AND stlnr = %s AND stlkn = %s LIMIT 1",
                [stlnr, stlkn],
            )
            lk = cursor.fetchone()
            if not lk:
                return jsonify({'success': False, 'error': 'Ligne STPO matière introuvable (stlnr/stlkn)'}), 404
            mandt = lk['mandt']

            cursor.execute(
                """
                UPDATE raw_data.stpo
                SET idnrk = %s, menge = %s, meins = %s
                WHERE mandt = %s AND stlty = 'M' AND stlnr = %s AND stlkn = %s
                """,
                [idnrk, str(menge), meins, mandt, stlnr, stlkn],
            )
            if cursor.rowcount == 0:
                conn.rollback()
                return jsonify({'success': False, 'error': 'Aucune ligne mise à jour'}), 404

            if maktx is not None and idnrk:
                mt = str(maktx).strip()
                if len(mt) > 40:
                    conn.rollback()
                    return jsonify({'success': False, 'error': 'maktx max 40 caractères (SAP)'}), 400
                cursor.execute(
                    """
                    UPDATE raw_data.makt SET maktx = %s
                    WHERE mandt = %s AND matnr = %s AND spras = 'F'
                    """,
                    [mt, mandt, idnrk],
                )
                if cursor.rowcount == 0:
                    try:
                        cursor.execute(
                            """
                            INSERT INTO raw_data.makt (mandt, matnr, spras, maktx)
                            VALUES (%s, %s, 'F', %s)
                            """,
                            [mandt, idnrk, mt],
                        )
                    except Exception as ins_err:
                        current_app.logger.warning('makt insert: %s', ins_err)

            conn.commit()
            return jsonify({'success': True, 'message': 'Composant nomenclature matière mis à jour'}), 200
    except Exception as e:
        current_app.logger.error(f'Erreur update BOM article IH02: {e}', exc_info=True)
        return jsonify({'success': False, 'error': str(e)}), 500


@ih02_hierarchy_blueprint.route('/equipment-children', methods=['GET'])
def get_equipment_children():
    """Récupère les équipements enfants d'un équipement parent (via hequi)"""
    try:
        parent_equnr = request.args.get('parent_equnr', type=str)
        if not parent_equnr:
            return jsonify({'success': False, 'error': 'parent_equnr requis'}), 400

        with get_db_connection() as conn:
            cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)

            cursor.execute("""
                SELECT
                    t.equnr as equnr,
                    LTRIM(t.equnr, '0') as equnr_short,
                    COALESCE(t.eqktx, 'Équipement ' || LTRIM(t.equnr, '0')) as designation,
                    t.eqart as type_poste,
                    t.herst as manufacturer,
                    t.typbz as model,
                    t.sernr as serial_number,
                    t.inbdt as start_date,
                    t.kostl as centre_couts,
                    t.iwerk as maintenance_plant,
                    t.ingrp as planner_group,
                    t.matnr as material_number,
                    t.tplnr as parent_tplnr,
                    t.hequi as parent_equnr,
                    ez.gewrk as gewrk,
                    cr.arbpl as arbpl,
                    ctx.ktext as poste_travail_texte,
                    COALESCE((SELECT COUNT(*) FROM raw_data.itob c WHERE c.hequi = t.equnr), 0) as children_count
                FROM raw_data.itob t
                LEFT JOIN raw_data.equz ez ON ez.equnr = t.equnr AND ez.datbi = '99991231'
                LEFT JOIN raw_data.crhd cr ON cr.objid = ez.gewrk
                LEFT JOIN raw_data.crtx ctx ON ctx.objid = cr.objid AND ctx.spras = 'F'
                WHERE t.hequi = %s
                ORDER BY t.equnr
            """, [parent_equnr])
            children = cursor.fetchall()

            return jsonify({'success': True, 'data': children, 'total': len(children)}), 200
    except Exception as e:
        current_app.logger.error(f"Erreur récupération enfants équipement IH02: {e}")
        return jsonify({'success': False, 'error': str(e)}), 500


@ih02_hierarchy_blueprint.route('/update-equipment', methods=['PUT'])
def update_equipment():
    """Met à jour un équipement.
    raw_data.itob est une vue : on dispatche les UPDATE sur les tables sources :
      - eqkt  : eqktx (description)
      - equi  : champs master (eqart, herst, typbz, sernr, invnr, matnr, ...)
      - equz  : champs temporels (iwerk, ingrp) sur le record courant (datbi='99991231')
      - iloa  : champs localisation (kostl, swerk, stort, beber, bukrs, gsber)
                via la jointure equz.iloan = iloa.iloan
    """
    try:
        data = request.get_json()
        if not data or 'equnr' not in data:
            return jsonify({'success': False, 'error': 'equnr requis'}), 400

        equnr = data['equnr']

        field_mapping = {
            'designation': ('eqktx', 'eqkt'),
            'type_equipement': ('eqart', 'equi'),
            'categorie': ('eqtyp', 'equi'),
            'fabricant': ('herst', 'equi'),
            'pays_fabricant': ('herld', 'equi'),
            'modele': ('typbz', 'equi'),
            'numero_serie': ('sernr', 'equi'),
            'numero_inventaire': ('invnr', 'equi'),
            'taille': ('groes', 'equi'),
            'poids': ('brgew', 'equi'),
            'unite_poids': ('gewei', 'equi'),
            'valeur_acquisition': ('answt', 'equi'),
            'devise': ('waers', 'equi'),
            'date_acquisition': ('ansdt', 'equi'),
            'annee_construction': ('baujj', 'equi'),
            'mois_construction': ('baumm', 'equi'),
            'date_mise_service': ('inbdt', 'equi'),
            'fournisseur': ('elief', 'equi'),
            'numero_article': ('matnr', 'equi'),
            'division_maintenance': ('iwerk', 'equz'),
            'groupe_planification': ('ingrp', 'equz'),
            'centre_couts': ('kostl', 'iloa'),
            'societe': ('bukrs', 'iloa'),
            'domaine_activite': ('gsber', 'iloa'),
            'division': ('swerk', 'iloa'),
            'emplacement': ('stort', 'iloa'),
            'section': ('beber', 'iloa'),
        }

        by_table = {'equi': [], 'eqkt': [], 'equz': [], 'iloa': []}
        modified_fields = []
        for key, (col, table) in field_mapping.items():
            if key in data:
                val = data[key] if data[key] != '' else None
                by_table[table].append((col, val))
                modified_fields.append(key)

        if not modified_fields:
            return jsonify({'success': False, 'error': 'Aucun champ à mettre à jour'}), 400

        with get_db_connection() as conn:
            cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)

            cursor.execute("SELECT equnr FROM raw_data.equi WHERE equnr = %s LIMIT 1", [equnr])
            if not cursor.fetchone():
                return jsonify({'success': False, 'error': f'Équipement {equnr} non trouvé'}), 404

            if by_table['equi']:
                cols = [f"{c} = %s" for c, _ in by_table['equi']]
                vals = [v for _, v in by_table['equi']] + [equnr]
                cursor.execute(f"UPDATE raw_data.equi SET {', '.join(cols)} WHERE equnr = %s", vals)

            if by_table['eqkt']:
                cols = [f"{c} = %s" for c, _ in by_table['eqkt']]
                vals = [v for _, v in by_table['eqkt']] + [equnr]
                cursor.execute(f"UPDATE raw_data.eqkt SET {', '.join(cols)} WHERE equnr = %s AND spras = 'F'", vals)
                if cursor.rowcount == 0:
                    cursor.execute(f"UPDATE raw_data.eqkt SET {', '.join(cols)} WHERE equnr = %s", vals)

            if by_table['equz']:
                cols = [f"{c} = %s" for c, _ in by_table['equz']]
                vals = [v for _, v in by_table['equz']] + [equnr]
                cursor.execute(f"UPDATE raw_data.equz SET {', '.join(cols)} WHERE equnr = %s AND datbi = '99991231'", vals)

            if by_table['iloa']:
                cursor.execute("SELECT iloan FROM raw_data.equz WHERE equnr = %s AND datbi = '99991231' LIMIT 1", [equnr])
                row = cursor.fetchone()
                if row and row['iloan']:
                    cols = [f"{c} = %s" for c, _ in by_table['iloa']]
                    vals = [v for _, v in by_table['iloa']] + [row['iloan']]
                    cursor.execute(f"UPDATE raw_data.iloa SET {', '.join(cols)} WHERE iloan = %s", vals)

            conn.commit()
            return jsonify({
                'success': True,
                'message': f'{len(modified_fields)} champ(s) mis à jour',
                'modified': modified_fields,
            }), 200
    except Exception as e:
        current_app.logger.error(f"Erreur mise à jour équipement IH02: {e}")
        return jsonify({'success': False, 'error': f'Erreur serveur: {str(e)}'}), 500


@ih02_hierarchy_blueprint.route('/work-centers', methods=['GET'])
def get_work_centers():
    """Liste les postes de travail disponibles depuis CRHD + CRTX"""
    try:
        with get_db_connection() as conn:
            cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
            cursor.execute("""
                SELECT DISTINCT cr.arbpl as code, cr.objid, ctx.ktext as designation
                FROM raw_data.crhd cr
                LEFT JOIN raw_data.crtx ctx ON ctx.objid = cr.objid AND ctx.spras = 'F'
                WHERE cr.werks = '9200'
                ORDER BY cr.arbpl
            """)
            rows = cursor.fetchall()
            return jsonify({'success': True, 'data': rows}), 200
    except Exception as e:
        current_app.logger.error(f"Erreur récupération postes de travail: {e}")
        return jsonify({'success': False, 'error': str(e)}), 500


@ih02_hierarchy_blueprint.route('/export-equipment', methods=['GET'])
def export_equipment():
    """Export CSV des équipements (itob)"""
    try:
        with get_db_connection() as conn:
            cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)

            cursor.execute("""
                SELECT
                    t.equnr,
                    LTRIM(t.equnr, '0') as equnr_short,
                    t.eqktx as designation,
                    t.eqart as type_equipement,
                    t.eqtyp as categorie,
                    t.tplnr as poste_technique,
                    t.hequi as equipement_superieur,
                    t.herst as fabricant,
                    t.herld as pays_fabricant,
                    t.typbz as modele,
                    t.sernr as numero_serie,
                    t.invnr as numero_inventaire,
                    t.groes as taille,
                    t.brgew as poids,
                    t.gewei as unite_poids,
                    t.answt as valeur_acquisition,
                    t.waers as devise,
                    t.ansdt as date_acquisition,
                    t.baujj as annee_construction,
                    t.baumm as mois_construction,
                    t.inbdt as date_mise_service,
                    t.kostl as centre_couts,
                    t.bukrs as societe,
                    t.gsber as domaine_activite,
                    t.iwerk as division_maintenance,
                    t.ingrp as groupe_planification,
                    t.swerk as division,
                    t.stort as emplacement,
                    t.beber as section,
                    t.matnr as numero_article,
                    t.elief as fournisseur,
                    t.warpl as plan_maintenance
                FROM raw_data.itob t
                ORDER BY t.equnr
            """)
            rows = cursor.fetchall()

            if not rows:
                return jsonify({'success': False, 'error': 'Aucune donnée'}), 404

            output = io.StringIO()
            writer = csv.DictWriter(output, fieldnames=rows[0].keys(), delimiter=';')
            writer.writeheader()
            writer.writerows(rows)
            return Response(
                output.getvalue(),
                mimetype='text/csv',
                headers={'Content-Disposition': 'attachment; filename=ih02_equipements.csv'},
            )
    except Exception as e:
        current_app.logger.error(f"Erreur export équipements IH02: {e}")
        return jsonify({'success': False, 'error': str(e)}), 500


@ih02_hierarchy_blueprint.route('/search-equipment', methods=['GET'])
def search_equipment():
    """Recherche d'équipements existants pour autocomplétion."""
    try:
        q = request.args.get('q', '', type=str).strip()
        limit = min(request.args.get('limit', 20, type=int), 50)

        base_query = """
            SELECT DISTINCT ON (e.equnr)
                TRIM(e.equnr) as equnr,
                LTRIM(TRIM(e.equnr), '0') as equnr_short,
                TRIM(COALESCE(kf.eqktx, kn.eqktx, kx.eqktx, '')) as designation,
                TRIM(COALESCE(e.eqart, '')) as eqart,
                TRIM(COALESCE(e.herst, '')) as herst,
                TRIM(COALESCE(e.typbz, '')) as typbz,
                TRIM(COALESCE(e.matnr, '')) as matnr,
                TRIM(COALESCE(l.kostl, '')) as kostl,
                TRIM(COALESCE(z.iwerk, '')) as iwerk,
                TRIM(COALESCE(z.ingrp, '')) as ingrp
            FROM raw_data.equi e
            LEFT JOIN raw_data.eqkt kf ON e.equnr = kf.equnr AND e.mandt = kf.mandt AND kf.spras = 'F'
            LEFT JOIN raw_data.eqkt kn ON e.equnr = kn.equnr AND e.mandt = kn.mandt AND kn.spras = 'N'
            LEFT JOIN raw_data.eqkt kx ON e.equnr = kx.equnr AND e.mandt = kx.mandt
            LEFT JOIN raw_data.equz z  ON e.equnr = z.equnr AND e.mandt = z.mandt AND z.datbi = '99991231'
            LEFT JOIN raw_data.iloa l  ON z.iloan = l.iloan AND z.mandt = l.mandt
        """

        with get_db_connection() as conn:
            cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
            if q:
                pattern = f'%{q}%'
                cursor.execute(base_query + """
                    WHERE e.equnr ILIKE %s
                       OR kf.eqktx ILIKE %s
                       OR kn.eqktx ILIKE %s
                       OR kx.eqktx ILIKE %s
                    ORDER BY e.equnr
                    LIMIT %s
                """, [pattern, pattern, pattern, pattern, limit])
            else:
                cursor.execute(base_query + " ORDER BY e.equnr LIMIT %s", [limit])

            return jsonify({'success': True, 'data': cursor.fetchall()}), 200
    except Exception as e:
        current_app.logger.error(f"Erreur recherche équipement IH02: {e}")
        return jsonify({'success': False, 'error': str(e)}), 500


@ih02_hierarchy_blueprint.route('/search-article', methods=['GET'])
def search_article():
    """Recherche d'articles existants pour autocomplétion."""
    try:
        q = request.args.get('q', '', type=str).strip()
        limit = min(request.args.get('limit', 20, type=int), 50)

        with get_db_connection() as conn:
            cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)

            base_query = """
                SELECT DISTINCT ON (m.matnr)
                    TRIM(m.matnr) as matnr,
                    LTRIM(TRIM(m.matnr), '0') as matnr_short,
                    TRIM(COALESCE(kf.maktx, kn.maktx, ke.maktx, kx.maktx, '')) as designation,
                    TRIM(COALESCE(m.mtart, '')) as mtart,
                    TRIM(COALESCE(m.meins, '')) as meins,
                    TRIM(COALESCE(m.extwg, '')) as extwg
                FROM raw_data.mara m
                LEFT JOIN raw_data.makt kf ON m.matnr = kf.matnr AND kf.spras = 'F'
                LEFT JOIN raw_data.makt kn ON m.matnr = kn.matnr AND kn.spras = 'N'
                LEFT JOIN raw_data.makt ke ON m.matnr = ke.matnr AND ke.spras = 'E'
                LEFT JOIN raw_data.makt kx ON m.matnr = kx.matnr
                WHERE (m.lvorm IS NULL OR TRIM(m.lvorm) = '')
            """

            if q:
                pattern = f'%{q}%'
                cursor.execute(base_query + """
                    AND (m.matnr ILIKE %s
                         OR kf.maktx ILIKE %s
                         OR kn.maktx ILIKE %s
                         OR ke.maktx ILIKE %s
                         OR kx.maktx ILIKE %s)
                    ORDER BY m.matnr
                    LIMIT %s
                """, [pattern, pattern, pattern, pattern, pattern, limit])
            else:
                cursor.execute(base_query + " ORDER BY m.matnr LIMIT %s", [limit])

            return jsonify({'success': True, 'data': cursor.fetchall()}), 200
    except Exception as e:
        current_app.logger.error(f"Erreur recherche article IH02: {e}")
        return jsonify({'success': False, 'error': str(e)}), 500


@ih02_hierarchy_blueprint.route('/add-equipment', methods=['POST'])
def add_equipment():
    """Ajoute un équipement sous un poste technique."""
    try:
        data = request.get_json()
        parent_tplnr = data.get('parent_tplnr', '').strip()
        designation = data.get('designation', '').strip()

        if not parent_tplnr:
            return jsonify({'success': False, 'error': 'parent_tplnr requis'}), 400
        if not designation:
            return jsonify({'success': False, 'error': 'designation requis'}), 400
        if len(designation) > 40:
            return jsonify({'success': False, 'error': 'designation max 40 caractères'}), 400

        with get_db_connection() as conn:
            cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)

            cursor.execute("SELECT mandt FROM raw_data.equi LIMIT 1")
            row = cursor.fetchone()
            mandt = row['mandt'] if row else '500'

            cursor.execute("SELECT MAX(CAST(equnr AS BIGINT)) AS max_eq FROM raw_data.equi")
            result = cursor.fetchone()
            max_eq = result['max_eq'] if result and result['max_eq'] else 0
            new_equnr = str(max_eq + 1).zfill(18)

            cursor.execute("""
                SELECT iloan, kostl, swerk, stort, beber
                FROM raw_data.iloa
                WHERE tplnr = %s AND mandt = %s
                LIMIT 1
            """, [parent_tplnr, mandt])
            iloa_row = cursor.fetchone()
            iloan = iloa_row['iloan'] if iloa_row else None
            kostl_iloa = iloa_row['kostl'] if iloa_row else None
            swerk_iloa = iloa_row['swerk'] if iloa_row else None

            cursor.execute("""
                INSERT INTO raw_data.equi (
                    mandt, equnr, eqart, herst, typbz, sernr, invnr, matnr,
                    inbdt, erdat, ernam
                ) VALUES (
                    %s, %s, %s, %s, %s, %s, %s, %s,
                    %s, TO_CHAR(NOW(), 'YYYYMMDD'), 'MIGFAC'
                )
            """, [
                mandt, new_equnr,
                data.get('eqart') or '',
                data.get('herst') or '',
                data.get('typbz') or '',
                data.get('sernr') or '',
                data.get('invnr') or '',
                data.get('matnr') or '',
                data.get('inbdt') or '',
            ])

            cursor.execute("""
                INSERT INTO raw_data.eqkt (mandt, equnr, spras, eqktx)
                VALUES (%s, %s, 'F', %s)
            """, [mandt, new_equnr, designation])

            cursor.execute("""
                INSERT INTO raw_data.equz (
                    mandt, equnr, eqlfn, datbi, datab, hequi, iloan, iwerk, ingrp
                ) VALUES (
                    %s, %s, '0001', '99991231', TO_CHAR(NOW(), 'YYYYMMDD'), %s, %s, %s, %s
                )
            """, [
                mandt, new_equnr,
                data.get('hequi') or '',
                iloan or '',
                data.get('iwerk') or (swerk_iloa or '9200'),
                data.get('ingrp') or '',
            ])

            conn.commit()
            return jsonify({
                'success': True,
                'message': f'Équipement créé sous "{parent_tplnr}"',
                'data': {
                    'equnr': new_equnr,
                    'linked_to_tplnr': bool(iloan),
                    'kostl': data.get('kostl') or kostl_iloa,
                },
            }), 201
    except Exception as e:
        current_app.logger.error(f"Erreur ajout équipement IH02: {e}")
        return jsonify({'success': False, 'error': str(e)}), 500


@ih02_hierarchy_blueprint.route('/delete-equipment', methods=['DELETE'])
def delete_equipment():
    """Supprime un équipement et ses sous-équipements"""
    try:
        equnr = request.args.get('equnr', type=str)
        if not equnr:
            return jsonify({'success': False, 'error': 'equnr requis'}), 400

        with get_db_connection() as conn:
            cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)

            cursor.execute("SELECT equnr FROM raw_data.equi WHERE equnr = %s", [equnr])
            if not cursor.fetchone():
                return jsonify({'success': False, 'error': 'Équipement non trouvé'}), 404

            deleted = _delete_equipment_recursive(cursor, equnr)
            conn.commit()

            return jsonify({
                'success': True,
                'message': f'Équipement et {deleted - 1} sous-équipement(s) supprimés',
                'data': {'deleted_count': deleted},
            }), 200
    except Exception as e:
        current_app.logger.error(f"Erreur suppression équipement IH02: {e}")
        return jsonify({'success': False, 'error': str(e)}), 500


def _delete_equipment_recursive(cursor, equnr):
    """Supprime récursivement un équipement et ses sous-équipements (hequi dans equz)."""
    cursor.execute("SELECT DISTINCT equnr FROM raw_data.equz WHERE hequi = %s", [equnr])
    children = cursor.fetchall()
    count = 0
    for child in children:
        count += _delete_equipment_recursive(cursor, child['equnr'])
    cursor.execute("DELETE FROM raw_data.equz WHERE equnr = %s", [equnr])
    cursor.execute("DELETE FROM raw_data.eqkt WHERE equnr = %s", [equnr])
    cursor.execute("DELETE FROM raw_data.equi WHERE equnr = %s", [equnr])
    return count + 1
