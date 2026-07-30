"""
API IH02 (postes techniques SAP) — implementation TABLE UNIQUE.

Toutes les donnees (postes techniques, equipements, articles, liens de
nomenclature) vivent dans clean_data.maintenance_object (voir
sql/maintenance/create_maintenance_object.sql). raw_data redevient lecture seule.

Les identifiants exposes restent les cles SAP (tplnr / equnr / idnrk) ;
l'id bigint interne n'est jamais expose.

`sap_key` est la cle SAP d'origine, IMMUABLE (reference API + tracabilite).
`code` est l'identifiant AFFICHE, modifiable depuis l'ecran ; son unicite parmi
les freres est garantie par l'index uq_mo_code_sibling (migration 028).
Un renommage est ISOLE : les descendants gardent leur propre code.

Historique : jusqu'au 2026-07-30 cet ecran etait servi par un second blueprint
qui lisait et ECRIVAIT directement raw_data, selectionne par le flag
Config.IH02_USE_MAINTENANCE_OBJECT. Ce blueprint et ce flag ont ete supprimes ;
raw_data est desormais en lecture seule pour cet ecran.

Referentiels lecture seule conserves sur raw_data (pick-lists, non stockes ici) :
  - /work-centers        (crhd + crtx)
  - /search-equipment    (catalogue equipements complet)
  - /search-article      (catalogue articles complet)
Un article choisi via une pick-list et reellement rattache est materialise a
l'ecriture dans maintenance_object (_ensure_article).
"""
import csv
import io
import json

import psycopg2.extras
from psycopg2 import errors as pg_errors
from flask import Blueprint, Response, current_app, jsonify, request

from config.database import get_db_connection

ih02_hierarchy_blueprint = Blueprint('ih02_hierarchy', __name__)

MO = 'clean_data.maintenance_object'


@ih02_hierarchy_blueprint.before_request
def _block_writes_during_maintenance_job():
    """
    Pendant une restauration ou un rechargement SAP, toute ecriture concurrente
    serait perdue (les tables sont reecrites) : on renvoie 409 sur les methodes
    mutantes. La lecture reste autorisee.
    """
    if request.method in ('POST', 'PUT', 'PATCH', 'DELETE'):
        from api.maintenance_snapshots import active_job_conflict
        return active_job_conflict()


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def _current_user():
    """Identite JWT (best-effort) pour l'audit created_by / updated_by."""
    try:
        from flask_jwt_extended import get_jwt_identity, verify_jwt_in_request
        verify_jwt_in_request(optional=True)
        return get_jwt_identity()
    except Exception:
        return None


def _resolve_id(cursor, object_type, sap_key):
    """id interne d'un objet a partir de (type, cle SAP)."""
    cursor.execute(
        f"SELECT id FROM {MO} WHERE object_type = %s AND sap_key = %s LIMIT 1",
        [object_type, sap_key],
    )
    row = cursor.fetchone()
    return row['id'] if row else None


def _normalize_sap_matnr(raw: str) -> str:
    """Numeriques -> 18 zeros a gauche, sinon tel quel (aligne sur l'ancien code)."""
    matnr = (raw or '').strip().upper()
    if not matnr:
        return ''
    return matnr.zfill(18) if matnr.isdigit() else matnr


def _node_level(cursor, node_id) -> int:
    """Profondeur (distance a la racine) d'un noeud via remontee parent_id."""
    cursor.execute(
        f"""
        WITH RECURSIVE up AS (
            SELECT id, parent_id, 0 AS lvl FROM {MO} WHERE id = %s
            UNION ALL
            SELECT m.id, m.parent_id, up.lvl + 1
            FROM {MO} m JOIN up ON m.id = up.parent_id
        )
        SELECT COALESCE(MAX(lvl), 0) AS lvl FROM up
        """,
        [node_id],
    )
    r = cursor.fetchone()
    return r['lvl'] if r else 0


def _ensure_article(cursor, matnr_norm, user):
    """Retourne l'id de l'ARTICLE ; le cree depuis raw_data.mara/makt si absent."""
    aid = _resolve_id(cursor, 'ARTICLE', matnr_norm)
    if aid:
        return aid

    cursor.execute(
        """
        SELECT m.matnr, m.mtart, m.meins, m.mbrsh, m.matkl, m.mandt,
               (SELECT maktx FROM raw_data.makt
                WHERE matnr = m.matnr AND mandt = m.mandt
                ORDER BY (CASE WHEN spras='F' THEN 0 WHEN spras='E' THEN 1 ELSE 2 END)
                LIMIT 1) AS maktx
        FROM raw_data.mara m WHERE m.matnr = %s LIMIT 1
        """,
        [matnr_norm],
    )
    m = cursor.fetchone()
    code = matnr_norm.lstrip('0') or matnr_norm
    attrs = {'matnr_long': matnr_norm}
    designation = None
    type_code = None
    if m:
        designation = m['maktx']
        type_code = m['mtart']
        attrs.update({k: m[k] for k in ('mtart', 'mbrsh', 'matkl', 'mandt') if m[k]})
        if m['meins']:
            attrs['meins_base'] = m['meins']

    cursor.execute(
        f"""
        INSERT INTO {MO} (object_type, sap_key, code, designation, type_code,
                          attributes, source, created_by, updated_by)
        VALUES ('ARTICLE', %s, %s, %s, %s, %s::jsonb, 'MANUAL', %s, %s)
        ON CONFLICT (object_type, sap_key) DO UPDATE SET updated_at = now()
        RETURNING id
        """,
        [matnr_norm, code, designation, type_code, json.dumps(attrs), user, user],
    )
    return cursor.fetchone()['id']


def _resolve_work_center(cursor, arbpl):
    """Valide un poste de travail (crhd werks=9200) et renvoie (objid, ktext)."""
    cursor.execute(
        """
        SELECT cr.objid, ctx.ktext
        FROM raw_data.crhd cr
        LEFT JOIN raw_data.crtx ctx ON ctx.objid = cr.objid AND ctx.spras = 'F'
        WHERE cr.arbpl = %s AND cr.werks = '9200' LIMIT 1
        """,
        [arbpl],
    )
    return cursor.fetchone()


# Colonnes SELECT contractuelles pour un poste technique (FUNC_LOC)
def _loc_select(level_expr):
    return f"""
        o.sap_key AS row_id,
        o.sap_key AS node_id,
        o.code    AS display_name,
        COALESCE(o.designation, o.code) AS designation,
        o.type_code AS type_poste,
        o.category  AS structure_indicator,
        o.cost_center AS centre_couts,
        o.work_center AS poste_travail_resp_maintenance,
        o.attributes->>'art_type_construction' AS art_type_construction,
        o.quantity::text AS quantite,
        o.unit AS unite,
        {level_expr} AS level,
        (SELECT COUNT(*) FROM {MO} c
          WHERE c.parent_id = o.id AND c.object_type IN ('FUNC_LOC','EQUIPMENT')
            AND c.is_active) AS children_count
    """


def _equipment_select():
    return f"""
        o.sap_key AS equnr,
        o.code    AS equnr_short,
        COALESCE(o.designation, 'Équipement ' || o.code) AS designation,
        o.type_code AS type_poste,
        o.attributes->>'herst' AS manufacturer,
        o.attributes->>'typbz' AS model,
        o.attributes->>'sernr' AS serial_number,
        o.attributes->>'inbdt' AS start_date,
        o.cost_center AS centre_couts,
        o.plant       AS maintenance_plant,
        o.planner_group AS planner_group,
        o.attributes->>'matnr' AS material_number,
        pfl.sap_key AS parent_tplnr,
        peq.sap_key AS parent_equnr,
        o.attributes->>'gewrk' AS gewrk,
        o.work_center AS arbpl,
        o.work_center_txt AS poste_travail_texte,
        (SELECT COUNT(*) FROM {MO} c
          WHERE c.parent_id = o.id AND c.object_type = 'EQUIPMENT' AND c.is_active) AS children_count
    """


# ---------------------------------------------------------------------------
# Postes techniques (locations)
# ---------------------------------------------------------------------------

@ih02_hierarchy_blueprint.route('/root-nodes', methods=['GET'])
def get_root_nodes():
    try:
        with get_db_connection() as conn:
            cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
            cursor.execute(f"""
                SELECT {_loc_select('0')}
                FROM {MO} o
                WHERE o.object_type = 'FUNC_LOC' AND o.parent_id IS NULL AND o.is_active
                ORDER BY o.sap_key
            """)
            nodes = cursor.fetchall()
            return jsonify({'success': True, 'data': nodes, 'total': len(nodes)}), 200
    except Exception as e:
        current_app.logger.error(f"Erreur racines IH02: {e}")
        return jsonify({'success': False, 'error': str(e)}), 500


@ih02_hierarchy_blueprint.route('/children', methods=['GET'])
def get_children():
    try:
        parent_level = request.args.get('parent_level', type=int)
        parent_id = request.args.get('parent_id', type=str)
        if parent_level is None or not parent_id:
            return jsonify({'success': False, 'error': 'parent_level et parent_id requis'}), 400
        child_level = parent_level + 1

        with get_db_connection() as conn:
            cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
            pid = _resolve_id(cursor, 'FUNC_LOC', parent_id)
            if pid is None:
                return jsonify({'success': True, 'data': {'locations': [], 'equipment': []}, 'total': 0}), 200

            cursor.execute(f"""
                SELECT {_loc_select('%s')}
                FROM {MO} o
                WHERE o.object_type = 'FUNC_LOC' AND o.parent_id = %s AND o.is_active
                ORDER BY o.sap_key
            """, [child_level, pid])
            children = cursor.fetchall()

            cursor.execute(f"""
                SELECT {_equipment_select()}
                FROM {MO} o
                LEFT JOIN {MO} pfl ON pfl.id = o.parent_id AND pfl.object_type = 'FUNC_LOC'
                LEFT JOIN {MO} peq ON peq.id = o.parent_id AND peq.object_type = 'EQUIPMENT'
                WHERE o.object_type = 'EQUIPMENT' AND o.parent_id = %s AND o.is_active
                ORDER BY o.sap_key
            """, [pid])
            equipment = cursor.fetchall()

            return jsonify({
                'success': True,
                'data': {'locations': children, 'equipment': equipment},
                'total': len(children) + len(equipment),
            }), 200
    except Exception as e:
        current_app.logger.error(f"Erreur enfants IH02: {e}")
        return jsonify({'success': False, 'error': str(e)}), 500


@ih02_hierarchy_blueprint.route('/node-details', methods=['GET'])
def get_node_details():
    try:
        tplnr = request.args.get('row_id', type=str) or request.args.get('node_id', type=str)
        if not tplnr:
            return jsonify({'success': False, 'error': 'row_id ou node_id requis'}), 400

        with get_db_connection() as conn:
            cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
            cursor.execute(f"""
                SELECT
                    o.id,
                    o.sap_key AS row_id,
                    o.sap_key AS node_id,
                    o.code    AS display_name,
                    COALESCE(p.code, p.sap_key) AS display_parent,
                    COALESCE(o.designation, o.code) AS designation,
                    o.type_code AS type_poste,
                    o.category  AS structure_indicator,
                    o.cost_center AS centre_couts,
                    o.work_center AS poste_travail_resp_maintenance,
                    o.work_center_txt AS poste_resp_texte,
                    o.attributes->>'art_type_construction' AS art_type_construction,
                    o.quantity::text AS quantite,
                    o.unit AS unite,
                    p.sap_key AS parent_node_id,
                    o.attributes->>'gewrk' AS gewrk,
                    (SELECT COUNT(*) FROM {MO} c
                       WHERE c.parent_id = o.id AND c.object_type = 'EQUIPMENT' AND c.is_active)
                       AS equipment_count,
                    o.source AS source,
                    o.updated_by AS updated_by,
                    to_char(o.updated_at, 'YYYY-MM-DD HH24:MI') AS updated_at
                FROM {MO} o
                LEFT JOIN {MO} p ON p.id = o.parent_id
                WHERE o.object_type = 'FUNC_LOC' AND o.sap_key = %s
                LIMIT 1
            """, [tplnr])
            node = cursor.fetchone()
            if not node:
                return jsonify({'success': False, 'error': 'Noeud non trouvé'}), 404

            node['level'] = _node_level(cursor, node['id'])

            # Poste de travail herite : remonter la hierarchie parent_id
            cursor.execute(f"""
                WITH RECURSIVE up AS (
                    SELECT id, parent_id, work_center, work_center_txt, 0 AS lvl
                    FROM {MO} WHERE id = %s
                    UNION ALL
                    SELECT m.id, m.parent_id, m.work_center, m.work_center_txt, up.lvl + 1
                    FROM {MO} m JOIN up ON m.id = up.parent_id
                )
                SELECT work_center, work_center_txt FROM up
                WHERE work_center IS NOT NULL AND TRIM(work_center) <> ''
                ORDER BY lvl LIMIT 1
            """, [node['id']])
            pt = cursor.fetchone()
            node['poste_travail'] = pt['work_center'] if pt else None
            node['poste_travail_texte'] = pt['work_center_txt'] if pt else None

            node.pop('id', None)
            return jsonify({'success': True, 'data': node}), 200
    except Exception as e:
        current_app.logger.error(f"Erreur détails noeud IH02: {e}")
        return jsonify({'success': False, 'error': str(e)}), 500


@ih02_hierarchy_blueprint.route('/search', methods=['GET'])
def search_nodes():
    try:
        q = request.args.get('q', '', type=str)
        if not q or len(q) < 2:
            return jsonify({'success': False, 'error': 'Min 2 caractères'}), 400

        with get_db_connection() as conn:
            cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
            pattern = f'%{q}%'

            cursor.execute(f"""
                WITH RECURSIVE tree AS (
                    SELECT id, 0 AS lvl FROM {MO}
                    WHERE object_type = 'FUNC_LOC' AND parent_id IS NULL AND is_active
                    UNION ALL
                    SELECT c.id, t.lvl + 1 FROM {MO} c JOIN tree t ON c.parent_id = t.id
                    WHERE c.object_type = 'FUNC_LOC' AND c.is_active
                )
                SELECT
                    o.sap_key AS row_id,
                    o.sap_key AS node_id,
                    o.code    AS display_name,
                    COALESCE(t.lvl, 0) AS level,
                    COALESCE(o.designation, o.code) AS designation,
                    o.type_code AS type_poste,
                    o.category  AS structure_indicator,
                    o.cost_center AS centre_couts,
                    o.work_center AS poste_travail_resp_maintenance,
                    o.attributes->>'art_type_construction' AS art_type_construction,
                    o.quantity::text AS quantite,
                    o.unit AS unite
                FROM {MO} o
                LEFT JOIN tree t ON t.id = o.id
                WHERE o.object_type = 'FUNC_LOC' AND o.is_active
                  AND (o.sap_key ILIKE %s OR o.code ILIKE %s OR o.designation ILIKE %s)
                ORDER BY o.code
                LIMIT 100
            """, [pattern, pattern, pattern])
            location_results = cursor.fetchall()

            cursor.execute(f"""
                SELECT
                    o.sap_key AS equnr,
                    o.code    AS equnr_short,
                    COALESCE(o.designation, 'Équipement ' || o.code) AS designation,
                    o.type_code AS type_poste,
                    o.attributes->>'herst' AS fabricant,
                    o.cost_center AS centre_couts,
                    pfl.sap_key AS poste_technique,
                    o.plant AS division_maintenance,
                    'equipment' AS node_type
                FROM {MO} o
                LEFT JOIN {MO} pfl ON pfl.id = o.parent_id AND pfl.object_type = 'FUNC_LOC'
                WHERE o.object_type = 'EQUIPMENT' AND o.is_active
                  AND (o.sap_key ILIKE %s OR o.code ILIKE %s OR o.designation ILIKE %s
                       OR o.attributes->>'herst' ILIKE %s)
                ORDER BY o.sap_key
                LIMIT 50
            """, [pattern, pattern, pattern, pattern])
            equipment_results = cursor.fetchall()

            # Articles (pieces de rechange). Ils ne sont pas des noeuds de l'arbre :
            # on renvoie pour chacun ses porteurs (postes techniques via BOM stlty='T',
            # articles parents via BOM stlty='M') pour permettre la navigation.
            cursor.execute(f"""
                WITH matched AS (
                    SELECT a.id, a.sap_key, a.code, a.designation, a.type_code
                    FROM {MO} a
                    WHERE a.object_type = 'ARTICLE' AND a.is_active
                      AND (a.sap_key ILIKE %s OR a.code ILIKE %s OR a.designation ILIKE %s)
                    ORDER BY a.code
                    LIMIT 50
                )
                SELECT
                    m.sap_key AS idnrk,
                    m.code    AS matnr_short,
                    COALESCE(m.designation, m.code) AS designation,
                    m.type_code AS material_type,
                    COALESCE(c.n, 0) AS usage_count,
                    COALESCE(u.used_in, '[]'::json) AS used_in
                FROM matched m
                LEFT JOIN LATERAL (
                    SELECT COUNT(DISTINCT b.parent_id) AS n
                    FROM {MO} b
                    WHERE b.object_type = 'BOM_ITEM' AND b.is_active
                      AND b.ref_object_id = m.id
                ) c ON TRUE
                LEFT JOIN LATERAL (
                    SELECT json_agg(s.j) AS used_in FROM (
                        SELECT DISTINCT ON (p.id)
                            CASE WHEN p.object_type = 'FUNC_LOC' THEN
                                json_build_object(
                                    'node_type', 'location',
                                    'row_id', p.sap_key, 'node_id', p.sap_key,
                                    'display_name', p.code,
                                    'designation', COALESCE(p.designation, p.code),
                                    'level', 0)
                            ELSE
                                json_build_object(
                                    'node_type', 'article',
                                    'idnrk', p.sap_key, 'matnr_short', p.code,
                                    'designation', COALESCE(p.designation, p.code))
                            END AS j
                        FROM {MO} b
                        JOIN {MO} p ON p.id = b.parent_id
                        WHERE b.object_type = 'BOM_ITEM' AND b.is_active
                          AND b.ref_object_id = m.id
                        ORDER BY p.id, p.code
                        LIMIT 25
                    ) s
                ) u ON TRUE
                ORDER BY m.code
            """, [pattern, pattern, pattern])
            article_results = cursor.fetchall()

            # Profondeur reelle des postes techniques porteurs (remontee parent_id,
            # batchee : le CTE descendant complet coute ~170 ms par appel).
            carrier_keys = sorted({
                p['row_id']
                for a in article_results
                for p in (a['used_in'] or [])
                if p.get('node_type') == 'location'
            })
            if carrier_keys:
                cursor.execute(f"""
                    WITH RECURSIVE up AS (
                        SELECT id, parent_id, id AS root_of, 0 AS lvl
                        FROM {MO}
                        WHERE object_type = 'FUNC_LOC' AND sap_key = ANY(%s)
                        UNION ALL
                        SELECT m.id, m.parent_id, up.root_of, up.lvl + 1
                        FROM {MO} m JOIN up ON m.id = up.parent_id
                    )
                    SELECT o.sap_key, MAX(up.lvl) AS lvl
                    FROM up JOIN {MO} o ON o.id = up.root_of
                    GROUP BY o.sap_key
                """, [carrier_keys])
                levels = {r['sap_key']: r['lvl'] for r in cursor.fetchall()}
                for a in article_results:
                    for p in (a['used_in'] or []):
                        if p.get('node_type') == 'location':
                            p['level'] = levels.get(p['row_id'], 0)

            return jsonify({
                'success': True,
                'data': {
                    'locations': location_results,
                    'equipment': equipment_results,
                    'articles': article_results,
                },
                'total': len(location_results) + len(equipment_results) + len(article_results),
            }), 200
    except Exception as e:
        current_app.logger.error(f"Erreur recherche IH02: {e}")
        return jsonify({'success': False, 'error': str(e)}), 500


@ih02_hierarchy_blueprint.route('/update-location', methods=['PUT'])
def update_location():
    try:
        data = request.get_json()
        tplnr = data.get('row_id') or data.get('node_id')
        if not tplnr:
            return jsonify({'success': False, 'error': 'row_id (tplnr) requis'}), 400

        user = _current_user()
        with get_db_connection() as conn:
            cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
            nid = _resolve_id(cursor, 'FUNC_LOC', tplnr)
            if nid is None:
                return jsonify({'success': False, 'error': f'Poste technique "{tplnr}" non trouvé'}), 404

            sets, params, modified = [], [], []
            attr_patch = {}

            # Parent CIBLE : le nouveau s'il est fourni dans la meme requete
            # (l'ecran permet de changer code et parent d'un coup), sinon l'actuel.
            # L'unicite du code se juge parmi les FRERES de ce parent — meme
            # perimetre que l'index uq_mo_code_sibling.
            if 'parent_node_id' in data:
                new_parent = data['parent_node_id']
                target_pid = None
                if new_parent:
                    target_pid = _resolve_id(cursor, 'FUNC_LOC', new_parent)
                    if target_pid is None:
                        return jsonify({'success': False, 'error': f'Parent "{new_parent}" non trouvé'}), 404
            else:
                cursor.execute(f"SELECT parent_id FROM {MO} WHERE id = %s", [nid])
                target_pid = cursor.fetchone()['parent_id']

            # Identifiant structure (code affiche). sap_key reste immuable
            # (cle SAP d'origine = reference API + tracabilite).
            if 'code' in data and (data.get('code') or '').strip():
                new_code = data['code'].strip()
                # IS NOT DISTINCT FROM : traite correctement les racines (parent NULL).
                cursor.execute(
                    f"""SELECT 1 FROM {MO}
                        WHERE object_type = 'FUNC_LOC' AND code = %s AND id <> %s AND is_active
                          AND parent_id IS NOT DISTINCT FROM %s
                        LIMIT 1""",
                    [new_code, nid, target_pid],
                )
                if cursor.fetchone():
                    return jsonify({'success': False,
                                    'error': f'Identifiant "{new_code}" déjà utilisé par un poste technique de même niveau'}), 409
                sets.append('code = %s'); params.append(new_code); modified.append('Identifiant')

            if 'designation' in data:
                sets.append('designation = %s'); params.append(data['designation']); modified.append('Désignation')
            if 'type_poste' in data:
                sets.append('type_code = %s'); params.append(data['type_poste'] or None); modified.append('Type de poste')
            if 'centre_couts' in data:
                sets.append('cost_center = %s'); params.append(data['centre_couts'] or None); modified.append('Centre de coûts')
            if 'quantite' in data:
                sets.append('quantity = %s'); params.append(data['quantite'] or None); modified.append('Quantité')
            if 'unite' in data:
                sets.append('unit = %s'); params.append(data['unite'] or None); modified.append('Unité')
            if 'art_type_construction' in data:
                attr_patch['art_type_construction'] = data['art_type_construction']; modified.append('Art / Type construction')

            # Poste de travail (valide contre crhd 9200) -> work_center + work_center_txt
            wc = data.get('poste_travail')
            if wc is None:
                wc = data.get('poste_travail_resp_maintenance')
            if wc is not None:
                if wc == '':
                    sets.append('work_center = NULL'); sets.append('work_center_txt = NULL')
                    modified.append('Poste de travail (vidé)')
                else:
                    cr = _resolve_work_center(cursor, wc)
                    if not cr:
                        return jsonify({'success': False, 'error': f'Poste de travail "{wc}" invalide'}), 400
                    sets.append('work_center = %s'); params.append(wc)
                    sets.append('work_center_txt = %s'); params.append(cr['ktext'])
                    modified.append(f'Poste de travail → {wc}')

            # Changement de parent (deja resolu plus haut en target_pid)
            if 'parent_node_id' in data:
                sets.append('parent_id = %s'); params.append(target_pid); modified.append('Parent')

            if attr_patch:
                sets.append('attributes = attributes || %s::jsonb'); params.append(json.dumps(attr_patch))

            if not sets:
                return jsonify({'success': False, 'error': 'Aucun champ modifiable fourni'}), 400

            sets.append('updated_by = %s'); params.append(user)
            params.append(nid)
            try:
                cursor.execute(f"UPDATE {MO} SET {', '.join(sets)} WHERE id = %s", params)
                conn.commit()
            except pg_errors.UniqueViolation:
                # Le pre-controle ci-dessus ne couvre pas la course entre deux
                # renommages simultanes : l'index uq_mo_code_sibling tranche.
                conn.rollback()
                return jsonify({
                    'success': False,
                    'error': 'Cet identifiant vient d\'être pris par un poste technique de même niveau',
                }), 409
            return jsonify({'success': True, 'message': f'{len(modified)} champ(s) mis à jour', 'modified': modified}), 200
    except Exception as e:
        current_app.logger.error(f"Erreur update location IH02: {e}")
        return jsonify({'success': False, 'error': f'Erreur serveur: {str(e)}'}), 500


@ih02_hierarchy_blueprint.route('/stats', methods=['GET'])
def get_stats():
    try:
        with get_db_connection() as conn:
            cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
            cursor.execute(f"""
                WITH RECURSIVE tree AS (
                    SELECT id, type_code, cost_center, 0 AS lvl FROM {MO}
                    WHERE object_type = 'FUNC_LOC' AND parent_id IS NULL AND is_active
                    UNION ALL
                    SELECT c.id, c.type_code, c.cost_center, t.lvl + 1
                    FROM {MO} c JOIN tree t ON c.parent_id = t.id
                    WHERE c.object_type = 'FUNC_LOC' AND c.is_active
                )
                SELECT
                    COUNT(*) AS total_nodes,
                    COUNT(DISTINCT type_code) FILTER (WHERE type_code IS NOT NULL AND TRIM(type_code) <> '') AS distinct_types,
                    COUNT(DISTINCT cost_center) FILTER (WHERE cost_center IS NOT NULL AND TRIM(cost_center) <> '') AS distinct_cost_centers,
                    COUNT(*) FILTER (WHERE lvl = 0) AS level_0,
                    COUNT(*) FILTER (WHERE lvl = 1) AS level_1,
                    COUNT(*) FILTER (WHERE lvl = 2) AS level_2,
                    COUNT(*) FILTER (WHERE lvl = 3) AS level_3,
                    COUNT(*) FILTER (WHERE lvl = 4) AS level_4,
                    COUNT(*) FILTER (WHERE lvl = 5) AS level_5,
                    COUNT(*) FILTER (WHERE lvl >= 6) AS level_6_plus
                FROM tree
            """)
            return jsonify({'success': True, 'data': cursor.fetchone()}), 200
    except Exception as e:
        current_app.logger.error(f"Erreur stats IH02: {e}")
        return jsonify({'success': False, 'error': str(e)}), 500


@ih02_hierarchy_blueprint.route('/export-structures', methods=['GET'])
def export_structures():
    try:
        with get_db_connection() as conn:
            cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
            cursor.execute(f"""
                WITH RECURSIVE tree AS (
                    SELECT id, 0 AS lvl FROM {MO}
                    WHERE object_type = 'FUNC_LOC' AND parent_id IS NULL AND is_active
                    UNION ALL
                    SELECT c.id, t.lvl + 1 FROM {MO} c JOIN tree t ON c.parent_id = t.id
                    WHERE c.object_type = 'FUNC_LOC' AND c.is_active
                )
                SELECT
                    o.sap_key AS tplnr,
                    o.code    AS structured_id,
                    p.sap_key AS parent,
                    COALESCE(p.code, p.sap_key) AS parent_structured,
                    COALESCE(t.lvl, 0) AS niveau,
                    COALESCE(o.designation, '') AS designation,
                    COALESCE(o.type_code, '') AS type_poste,
                    COALESCE(o.category, '') AS structure_indicator,
                    COALESCE(o.plant, '') AS division_maintenance,
                    COALESCE(o.planner_group, '') AS groupe_planification,
                    COALESCE(o.work_center, '') AS poste_travail
                FROM {MO} o
                LEFT JOIN tree t ON t.id = o.id
                LEFT JOIN {MO} p ON p.id = o.parent_id
                WHERE o.object_type = 'FUNC_LOC' AND o.is_active
                ORDER BY o.code
            """)
            rows = cursor.fetchall()
            if not rows:
                return jsonify({'success': False, 'error': 'Aucune donnée'}), 404
            output = io.StringIO()
            writer = csv.DictWriter(output, fieldnames=rows[0].keys(), delimiter=';')
            writer.writeheader()
            writer.writerows(rows)
            return Response(output.getvalue(), mimetype='text/csv',
                            headers={'Content-Disposition': 'attachment; filename=ih02_postes_techniques.csv'})
    except Exception as e:
        current_app.logger.error(f"Erreur export structures IH02: {e}")
        return jsonify({'success': False, 'error': str(e)}), 500


@ih02_hierarchy_blueprint.route('/move-node', methods=['PUT'])
def move_node():
    try:
        data = request.get_json()
        tplnr = data.get('row_id') or data.get('node_id')
        new_parent_id = data.get('new_parent_id')
        if not tplnr or not new_parent_id:
            return jsonify({'success': False, 'error': 'row_id/node_id et new_parent_id requis'}), 400

        with get_db_connection() as conn:
            cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
            nid = _resolve_id(cursor, 'FUNC_LOC', tplnr)
            if nid is None:
                return jsonify({'success': False, 'error': 'Noeud non trouvé'}), 404
            new_pid = _resolve_id(cursor, 'FUNC_LOC', new_parent_id)
            if new_pid is None:
                return jsonify({'success': False, 'error': f'Parent "{new_parent_id}" non trouvé'}), 404

            # Anti-cycle : le nouveau parent ne doit pas etre un descendant du noeud
            cursor.execute(f"""
                WITH RECURSIVE d AS (
                    SELECT id FROM {MO} WHERE id = %s
                    UNION ALL SELECT c.id FROM {MO} c JOIN d ON c.parent_id = d.id
                )
                SELECT 1 FROM d WHERE id = %s
            """, [nid, new_pid])
            if cursor.fetchone():
                return jsonify({'success': False, 'error': 'Impossible de déplacer un noeud sous un de ses descendants'}), 400

            cursor.execute(f"""
                WITH RECURSIVE d AS (
                    SELECT id FROM {MO} WHERE id = %s
                    UNION ALL SELECT c.id FROM {MO} c JOIN d ON c.parent_id = d.id
                )
                SELECT COUNT(*) AS cnt FROM d
            """, [nid])
            desc_count = cursor.fetchone()['cnt']

            try:
                cursor.execute(f"UPDATE {MO} SET parent_id = %s, updated_by = %s WHERE id = %s",
                               [new_pid, _current_user(), nid])
                conn.commit()
            except pg_errors.UniqueViolation:
                # Le noeud deplace porterait le meme code qu'un futur frere
                # (uq_mo_code_sibling) : le renommer avant de le deplacer.
                conn.rollback()
                return jsonify({
                    'success': False,
                    'error': f'"{new_parent_id}" contient déjà un poste technique portant cet identifiant',
                }), 409
            return jsonify({'success': True, 'message': f'Noeud et {desc_count - 1} descendant(s) déplacés'}), 200
    except Exception as e:
        current_app.logger.error(f"Erreur déplacement noeud IH02: {e}")
        return jsonify({'success': False, 'error': str(e)}), 500


@ih02_hierarchy_blueprint.route('/descendants-count', methods=['GET'])
def descendants_count():
    try:
        node_id = request.args.get('node_id', type=str)
        if not node_id:
            return jsonify({'success': False, 'error': 'node_id requis'}), 400
        with get_db_connection() as conn:
            cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
            nid = _resolve_id(cursor, 'FUNC_LOC', node_id)
            if nid is None:
                return jsonify({'success': True, 'data': {'count': 0, 'node_id': node_id}}), 200
            cursor.execute(f"""
                WITH RECURSIVE d AS (
                    SELECT id FROM {MO} WHERE id = %s
                    UNION ALL SELECT c.id FROM {MO} c JOIN d ON c.parent_id = d.id
                    WHERE c.object_type = 'FUNC_LOC'
                )
                SELECT COUNT(*) AS count FROM d
            """, [nid])
            return jsonify({'success': True, 'data': {'count': cursor.fetchone()['count'], 'node_id': node_id}}), 200
    except Exception as e:
        current_app.logger.error(f"Erreur comptage descendants IH02: {e}")
        return jsonify({'success': False, 'error': str(e)}), 500


@ih02_hierarchy_blueprint.route('/bulk-update', methods=['PUT'])
def bulk_update():
    """Modifications en masse sur un noeud FUNC_LOC et ses descendants."""
    try:
        data = request.get_json()
        node_id = data.get('node_id')
        updates = data.get('updates', [])
        if not node_id or not updates:
            return jsonify({'success': False, 'error': 'node_id et updates requis'}), 400

        col_map = {
            'designation': 'designation', 'type_poste': 'type_code',
            'centre_couts': 'cost_center', 'quantite': 'quantity', 'unite': 'unit',
        }
        attr_fields = {'art_type_construction', 'poste_travail_resp_maintenance'}

        with get_db_connection() as conn:
            cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
            nid = _resolve_id(cursor, 'FUNC_LOC', node_id)
            if nid is None:
                return jsonify({'success': False, 'error': 'Noeud non trouvé'}), 404

            sets, params = [], []
            for u in updates:
                f, v = u.get('field'), u.get('value')
                if f in col_map:
                    sets.append(f'{col_map[f]} = %s'); params.append(v if v != '' else None)
                elif f == 'poste_travail_resp_maintenance':
                    sets.append('work_center = %s'); params.append(v if v != '' else None)
                elif f in attr_fields:
                    sets.append('attributes = attributes || %s::jsonb'); params.append(json.dumps({f: v}))

            if not sets:
                return jsonify({'success': True, 'message': 'Aucun champ modifiable', 'data': {'updated_count': 0}}), 200

            sets.append('updated_by = %s'); params.append(_current_user())
            cursor.execute(f"""
                WITH RECURSIVE d AS (
                    SELECT id FROM {MO} WHERE id = %s
                    UNION ALL SELECT c.id FROM {MO} c JOIN d ON c.parent_id = d.id
                    WHERE c.object_type = 'FUNC_LOC'
                )
                UPDATE {MO} SET {', '.join(sets)}
                WHERE id IN (SELECT id FROM d)
            """, [nid] + params)
            updated_count = cursor.rowcount
            conn.commit()
            return jsonify({'success': True, 'message': f'{updated_count} noeud(s) mis à jour',
                            'data': {'updated_count': updated_count}}), 200
    except Exception as e:
        current_app.logger.error(f"Erreur bulk-update IH02: {e}")
        return jsonify({'success': False, 'error': str(e)}), 500


@ih02_hierarchy_blueprint.route('/add-node', methods=['POST'])
def add_node():
    try:
        data = request.get_json()
        parent_id = (data.get('parent_id') or '').strip()
        node_id = (data.get('node_id') or '').strip()
        designation = (data.get('designation') or '').strip()
        if not parent_id:
            return jsonify({'success': False, 'error': 'parent_id requis'}), 400
        if not node_id:
            return jsonify({'success': False, 'error': 'node_id (identifiant) requis'}), 400
        if not designation:
            return jsonify({'success': False, 'error': 'designation requis'}), 400

        user = _current_user()
        with get_db_connection() as conn:
            cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
            pid = _resolve_id(cursor, 'FUNC_LOC', parent_id)
            if pid is None:
                return jsonify({'success': False, 'error': f'Parent "{parent_id}" non trouvé'}), 404
            if _resolve_id(cursor, 'FUNC_LOC', node_id) is not None:
                return jsonify({'success': False, 'error': f'L\'identifiant "{node_id}" existe déjà'}), 409

            attrs = {'tplma_sap': parent_id}
            try:
                cursor.execute(f"""
                    INSERT INTO {MO} (object_type, sap_key, code, designation, type_code,
                                      cost_center, parent_id, plant, attributes, source, created_by, updated_by)
                    VALUES ('FUNC_LOC', %s, %s, %s, %s, %s, %s, '9200', %s::jsonb, 'MANUAL', %s, %s)
                    RETURNING id
                """, [node_id, node_id, designation, data.get('type_poste') or None,
                      data.get('centre_couts') or None, pid, json.dumps(attrs), user, user])
            except pg_errors.UniqueViolation:
                # sap_key est libre (verifie plus haut) mais un frere porte deja ce
                # CODE — cas possible des qu'un poste a ete renomme (uq_mo_code_sibling).
                conn.rollback()
                return jsonify({
                    'success': False,
                    'error': f'Un poste technique de même niveau porte déjà l\'identifiant "{node_id}"',
                }), 409
            new_id = cursor.fetchone()['id']
            level = _node_level(cursor, new_id)
            conn.commit()
            return jsonify({'success': True, 'message': f'Poste technique "{node_id}" créé',
                            'data': {'row_id': node_id, 'node_id': node_id, 'level': level}}), 201
    except Exception as e:
        current_app.logger.error(f"Erreur ajout noeud IH02: {e}")
        return jsonify({'success': False, 'error': str(e)}), 500


@ih02_hierarchy_blueprint.route('/delete-node', methods=['DELETE'])
def delete_node():
    """Soft delete d'un poste technique et de tout son sous-arbre (is_active=false)."""
    try:
        tplnr = request.args.get('row_id', type=str) or request.args.get('node_id', type=str)
        if not tplnr:
            return jsonify({'success': False, 'error': 'row_id ou node_id requis'}), 400
        with get_db_connection() as conn:
            cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
            nid = _resolve_id(cursor, 'FUNC_LOC', tplnr)
            if nid is None:
                return jsonify({'success': False, 'error': 'Noeud non trouvé'}), 404
            cursor.execute(f"""
                WITH RECURSIVE d AS (
                    SELECT id FROM {MO} WHERE id = %s
                    UNION ALL SELECT c.id FROM {MO} c JOIN d ON c.parent_id = d.id
                )
                UPDATE {MO} SET is_active = FALSE, updated_by = %s
                WHERE id IN (SELECT id FROM d)
                  AND object_type IN ('FUNC_LOC','EQUIPMENT','BOM_ITEM')
            """, [nid, _current_user()])
            count = cursor.rowcount
            conn.commit()
            return jsonify({'success': True, 'message': f'"{tplnr}" et descendant(s) supprimés',
                            'data': {'deleted_count': count}}), 200
    except Exception as e:
        current_app.logger.error(f"Erreur suppression noeud IH02: {e}")
        return jsonify({'success': False, 'error': str(e)}), 500


# ---------------------------------------------------------------------------
# Equipements
# ---------------------------------------------------------------------------

@ih02_hierarchy_blueprint.route('/equipment-details', methods=['GET'])
def get_equipment_details():
    try:
        equnr = request.args.get('equnr', type=str)
        if not equnr:
            return jsonify({'success': False, 'error': 'equnr requis'}), 400
        with get_db_connection() as conn:
            cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
            cursor.execute(f"""
                SELECT
                    o.sap_key AS equnr,
                    o.code    AS equnr_short,
                    COALESCE(o.designation, 'Équipement ' || o.code) AS designation,
                    o.type_code AS type_equipement,
                    o.category  AS categorie,
                    o.attributes->>'herst' AS fabricant,
                    o.attributes->>'herld' AS pays_fabricant,
                    o.attributes->>'typbz' AS modele,
                    o.attributes->>'sernr' AS numero_serie,
                    o.attributes->>'invnr' AS numero_inventaire,
                    o.attributes->>'groes' AS taille,
                    o.attributes->>'brgew' AS poids,
                    o.attributes->>'gewei' AS unite_poids,
                    o.attributes->>'answt' AS valeur_acquisition,
                    o.attributes->>'waers' AS devise,
                    o.attributes->>'ansdt' AS date_acquisition,
                    o.attributes->>'baujj' AS annee_construction,
                    o.attributes->>'baumm' AS mois_construction,
                    o.attributes->>'inbdt' AS date_mise_service,
                    o.attributes->>'erdat' AS date_creation,
                    o.attributes->>'ernam' AS cree_par,
                    o.attributes->>'aedat' AS date_modification,
                    o.attributes->>'aenam' AS modifie_par,
                    o.attributes->>'lvorm' AS indicateur_suppression,
                    o.attributes->>'gwlen' AS duree_garantie,
                    o.attributes->>'gwldt' AS fin_garantie,
                    o.attributes->>'elief' AS fournisseur,
                    o.attributes->>'matnr' AS numero_article,
                    o.cost_center AS centre_couts,
                    o.attributes->>'bukrs' AS societe,
                    o.attributes->>'gsber' AS domaine_activite,
                    o.plant AS division_maintenance,
                    o.planner_group AS groupe_planification,
                    o.attributes->>'swerk' AS division,
                    o.attributes->>'stort' AS emplacement,
                    o.attributes->>'beber' AS section,
                    pfl.sap_key AS poste_technique,
                    peq.sap_key AS equipement_superieur,
                    o.attributes->>'warpl' AS plan_maintenance,
                    o.attributes->>'gewrk' AS gewrk,
                    o.work_center AS arbpl,
                    o.work_center_txt AS poste_travail_texte,
                    (SELECT COUNT(*) FROM {MO} c
                       WHERE c.parent_id = o.id AND c.object_type = 'EQUIPMENT' AND c.is_active) AS children_count,
                    o.source AS source,
                    o.updated_by AS updated_by,
                    to_char(o.updated_at, 'YYYY-MM-DD HH24:MI') AS updated_at
                FROM {MO} o
                LEFT JOIN {MO} pfl ON pfl.id = o.parent_id AND pfl.object_type = 'FUNC_LOC'
                LEFT JOIN {MO} peq ON peq.id = o.parent_id AND peq.object_type = 'EQUIPMENT'
                WHERE o.object_type = 'EQUIPMENT' AND o.sap_key = %s
                LIMIT 1
            """, [equnr])
            eq = cursor.fetchone()
            if not eq:
                return jsonify({'success': False, 'error': 'Équipement non trouvé'}), 404
            return jsonify({'success': True, 'data': eq}), 200
    except Exception as e:
        current_app.logger.error(f"Erreur détails équipement IH02: {e}")
        return jsonify({'success': False, 'error': str(e)}), 500


@ih02_hierarchy_blueprint.route('/equipment-children', methods=['GET'])
def get_equipment_children():
    try:
        parent_equnr = request.args.get('parent_equnr', type=str)
        if not parent_equnr:
            return jsonify({'success': False, 'error': 'parent_equnr requis'}), 400
        with get_db_connection() as conn:
            cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
            pid = _resolve_id(cursor, 'EQUIPMENT', parent_equnr)
            if pid is None:
                return jsonify({'success': True, 'data': [], 'total': 0}), 200
            cursor.execute(f"""
                SELECT {_equipment_select()}
                FROM {MO} o
                LEFT JOIN {MO} pfl ON pfl.id = o.parent_id AND pfl.object_type = 'FUNC_LOC'
                LEFT JOIN {MO} peq ON peq.id = o.parent_id AND peq.object_type = 'EQUIPMENT'
                WHERE o.object_type = 'EQUIPMENT' AND o.parent_id = %s AND o.is_active
                ORDER BY o.sap_key
            """, [pid])
            children = cursor.fetchall()
            return jsonify({'success': True, 'data': children, 'total': len(children)}), 200
    except Exception as e:
        current_app.logger.error(f"Erreur enfants équipement IH02: {e}")
        return jsonify({'success': False, 'error': str(e)}), 500


@ih02_hierarchy_blueprint.route('/update-equipment', methods=['PUT'])
def update_equipment():
    try:
        data = request.get_json()
        if not data or 'equnr' not in data:
            return jsonify({'success': False, 'error': 'equnr requis'}), 400
        equnr = data['equnr']

        col_map = {
            'designation': 'designation', 'type_equipement': 'type_code',
            'categorie': 'category', 'centre_couts': 'cost_center',
            'division_maintenance': 'plant', 'groupe_planification': 'planner_group',
        }
        attr_map = {
            'fabricant': 'herst', 'pays_fabricant': 'herld', 'modele': 'typbz',
            'numero_serie': 'sernr', 'numero_inventaire': 'invnr', 'taille': 'groes',
            'poids': 'brgew', 'unite_poids': 'gewei', 'valeur_acquisition': 'answt',
            'devise': 'waers', 'date_acquisition': 'ansdt', 'annee_construction': 'baujj',
            'mois_construction': 'baumm', 'date_mise_service': 'inbdt', 'fournisseur': 'elief',
            'numero_article': 'matnr', 'societe': 'bukrs', 'domaine_activite': 'gsber',
            'division': 'swerk', 'emplacement': 'stort', 'section': 'beber',
            'plan_maintenance': 'warpl',
        }

        sets, params, modified, attr_patch = [], [], [], {}
        for key, col in col_map.items():
            if key in data:
                sets.append(f'{col} = %s'); params.append(data[key] if data[key] != '' else None); modified.append(key)
        for key, akey in attr_map.items():
            if key in data:
                attr_patch[akey] = data[key] if data[key] != '' else None; modified.append(key)

        if not modified:
            return jsonify({'success': False, 'error': 'Aucun champ à mettre à jour'}), 400

        with get_db_connection() as conn:
            cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
            eid = _resolve_id(cursor, 'EQUIPMENT', equnr)
            if eid is None:
                return jsonify({'success': False, 'error': f'Équipement {equnr} non trouvé'}), 404
            if attr_patch:
                sets.append('attributes = attributes || %s::jsonb'); params.append(json.dumps(attr_patch))
            sets.append('updated_by = %s'); params.append(_current_user())
            params.append(eid)
            cursor.execute(f"UPDATE {MO} SET {', '.join(sets)} WHERE id = %s", params)
            conn.commit()
            return jsonify({'success': True, 'message': f'{len(modified)} champ(s) mis à jour', 'modified': modified}), 200
    except Exception as e:
        current_app.logger.error(f"Erreur update équipement IH02: {e}")
        return jsonify({'success': False, 'error': f'Erreur serveur: {str(e)}'}), 500


@ih02_hierarchy_blueprint.route('/add-equipment', methods=['POST'])
def add_equipment():
    try:
        data = request.get_json()
        parent_tplnr = (data.get('parent_tplnr') or '').strip()
        designation = (data.get('designation') or '').strip()
        if not parent_tplnr:
            return jsonify({'success': False, 'error': 'parent_tplnr requis'}), 400
        if not designation:
            return jsonify({'success': False, 'error': 'designation requis'}), 400
        if len(designation) > 40:
            return jsonify({'success': False, 'error': 'designation max 40 caractères'}), 400

        user = _current_user()
        with get_db_connection() as conn:
            cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
            pid = _resolve_id(cursor, 'FUNC_LOC', parent_tplnr)
            if pid is None:
                return jsonify({'success': False, 'error': f'Poste technique "{parent_tplnr}" non trouvé'}), 404

            # Nouveau equnr = max(sap_key numerique) + 1, sur 18 zeros
            cursor.execute(f"""
                SELECT COALESCE(MAX(CAST(sap_key AS BIGINT)), 0) AS max_eq
                FROM {MO} WHERE object_type = 'EQUIPMENT' AND sap_key ~ '^[0-9]+$'
            """)
            new_equnr = str(cursor.fetchone()['max_eq'] + 1).zfill(18)
            code = new_equnr.lstrip('0') or new_equnr

            attrs = {
                'equnr_long': new_equnr, 'tplnr_sap': parent_tplnr,
                'herst': data.get('herst') or None, 'typbz': data.get('typbz') or None,
                'sernr': data.get('sernr') or None, 'invnr': data.get('invnr') or None,
                'matnr': data.get('matnr') or None, 'inbdt': data.get('inbdt') or None,
                'ernam': 'MIGFAC',
            }
            attrs = {k: v for k, v in attrs.items() if v is not None}
            cursor.execute(f"""
                INSERT INTO {MO} (object_type, sap_key, code, designation, type_code,
                                  cost_center, plant, planner_group, parent_id,
                                  attributes, source, created_by, updated_by)
                VALUES ('EQUIPMENT', %s, %s, %s, %s, %s, %s, %s, %s, %s::jsonb, 'MANUAL', %s, %s)
            """, [new_equnr, code, designation, data.get('eqart') or None,
                  data.get('kostl') or None, data.get('iwerk') or '9200',
                  data.get('ingrp') or None, pid, json.dumps(attrs), user, user])
            conn.commit()
            return jsonify({'success': True, 'message': f'Équipement créé sous "{parent_tplnr}"',
                            'data': {'equnr': new_equnr, 'linked_to_tplnr': True,
                                     'kostl': data.get('kostl')}}), 201
    except Exception as e:
        current_app.logger.error(f"Erreur ajout équipement IH02: {e}")
        return jsonify({'success': False, 'error': str(e)}), 500


@ih02_hierarchy_blueprint.route('/delete-equipment', methods=['DELETE'])
def delete_equipment():
    try:
        equnr = request.args.get('equnr', type=str)
        if not equnr:
            return jsonify({'success': False, 'error': 'equnr requis'}), 400
        with get_db_connection() as conn:
            cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
            eid = _resolve_id(cursor, 'EQUIPMENT', equnr)
            if eid is None:
                return jsonify({'success': False, 'error': 'Équipement non trouvé'}), 404
            cursor.execute(f"""
                WITH RECURSIVE d AS (
                    SELECT id FROM {MO} WHERE id = %s
                    UNION ALL SELECT c.id FROM {MO} c JOIN d ON c.parent_id = d.id
                    WHERE c.object_type = 'EQUIPMENT'
                )
                UPDATE {MO} SET is_active = FALSE, updated_by = %s
                WHERE id IN (SELECT id FROM d) AND object_type = 'EQUIPMENT'
            """, [eid, _current_user()])
            deleted = cursor.rowcount
            conn.commit()
            return jsonify({'success': True, 'message': f'Équipement et {deleted - 1} sous-équipement(s) supprimés',
                            'data': {'deleted_count': deleted}}), 200
    except Exception as e:
        current_app.logger.error(f"Erreur suppression équipement IH02: {e}")
        return jsonify({'success': False, 'error': str(e)}), 500


# ---------------------------------------------------------------------------
# Nomenclatures (BOM)
# ---------------------------------------------------------------------------

@ih02_hierarchy_blueprint.route('/bom/<path:tplnr>', methods=['GET'])
def get_fl_bom(tplnr):
    """Nomenclature (BOM stlty=T) d'un poste technique."""
    try:
        if not tplnr:
            return jsonify({'success': False, 'error': 'tplnr requis'}), 400
        with get_db_connection() as conn:
            cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
            cursor.execute(f"""
                SELECT
                    fl.sap_key AS tplnr,
                    fl.code    AS tplnr_display,
                    COALESCE(fl.designation, fl.code) AS fl_designation,
                    b.attributes->>'stlnr' AS stlnr,
                    b.attributes->>'stlal' AS stlal,
                    b.attributes->>'stlkn' AS stlkn,
                    b.attributes->>'stlan' AS stlan,
                    b.attributes->>'base_quantity' AS base_quantity,
                    b.attributes->>'base_unit' AS base_unit,
                    b.attributes->>'posnr' AS posnr,
                    b.attributes->>'potx1' AS potx1,
                    b.attributes->>'potx2' AS potx2,
                    a.sap_key AS idnrk,
                    a.code    AS matnr_short,
                    b.category AS item_category,
                    b.quantity::text AS quantity,
                    b.unit,
                    a.type_code AS material_type,
                    COALESCE(a.designation, a.code) AS designation
                FROM {MO} b
                JOIN {MO} fl ON fl.id = b.parent_id AND fl.object_type = 'FUNC_LOC'
                JOIN {MO} a  ON a.id  = b.ref_object_id AND a.object_type = 'ARTICLE'
                WHERE b.object_type = 'BOM_ITEM' AND b.is_active
                  AND b.attributes->>'stlty' = 'T'
                  AND fl.sap_key = %s
                ORDER BY b.sort_order
            """, [tplnr])
            rows = cursor.fetchall()
            return jsonify({'success': True, 'data': rows, 'total': len(rows), 'tplnr': tplnr}), 200
    except Exception as e:
        current_app.logger.error(f"Erreur BOM IH02 ({tplnr}): {e}")
        return jsonify({'success': False, 'error': str(e)}), 500


@ih02_hierarchy_blueprint.route('/bom-counts', methods=['GET'])
def get_fl_bom_counts():
    try:
        tplnrs = request.args.get('tplnrs', '').strip()
        if not tplnrs:
            return jsonify({'success': True, 'data': {}}), 200
        tplnr_list = [t.strip() for t in tplnrs.split(',') if t.strip()]
        if not tplnr_list:
            return jsonify({'success': True, 'data': {}}), 200
        with get_db_connection() as conn:
            cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
            cursor.execute(f"""
                SELECT fl.sap_key AS tplnr, COUNT(*) AS nb
                FROM {MO} b
                JOIN {MO} fl ON fl.id = b.parent_id AND fl.object_type = 'FUNC_LOC'
                WHERE b.object_type = 'BOM_ITEM' AND b.is_active
                  AND b.attributes->>'stlty' = 'T'
                  AND fl.sap_key = ANY(%s)
                GROUP BY fl.sap_key
            """, [tplnr_list])
            counts = {row['tplnr']: row['nb'] for row in cursor.fetchall()}
            return jsonify({'success': True, 'data': counts}), 200
    except Exception as e:
        current_app.logger.error(f"Erreur BOM counts IH02: {e}")
        return jsonify({'success': False, 'error': str(e)}), 500


@ih02_hierarchy_blueprint.route('/article-bom/<path:matnr>', methods=['GET'])
def get_article_bom(matnr):
    """Nomenclature matiere (BOM stlty=M) d'un article — hierarchie recursive."""
    try:
        norm = _normalize_sap_matnr(matnr)
        if not norm:
            return jsonify({'success': False, 'error': 'matnr requis'}), 400
        with get_db_connection() as conn:
            cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
            aid = _resolve_id(cursor, 'ARTICLE', norm)
            if aid is None:
                return jsonify({'success': True, 'data': [], 'total': 0, 'matnr': norm}), 200
            cursor.execute(f"""
                SELECT
                    b.attributes->>'stlnr' AS stlnr,
                    b.attributes->>'stlal' AS stlal,
                    b.attributes->>'stlkn' AS stlkn,
                    b.attributes->>'posnr' AS posnr,
                    b.attributes->>'potx1' AS potx1,
                    b.attributes->>'potx2' AS potx2,
                    a.sap_key AS idnrk,
                    a.code    AS matnr_short,
                    b.category AS item_category,
                    b.quantity::text AS quantity,
                    b.unit,
                    a.type_code AS material_type,
                    COALESCE(a.designation, a.code) AS designation,
                    (SELECT COUNT(*) FROM {MO} cb
                       WHERE cb.object_type = 'BOM_ITEM' AND cb.is_active
                         AND cb.parent_id = a.id) AS children_count
                FROM {MO} b
                JOIN {MO} a ON a.id = b.ref_object_id AND a.object_type = 'ARTICLE'
                WHERE b.object_type = 'BOM_ITEM' AND b.is_active
                  AND b.attributes->>'stlty' = 'M'
                  AND b.parent_id = %s
                ORDER BY b.sort_order, b.attributes->>'stlkn'
            """, [aid])
            rows = cursor.fetchall()
            stlnr = rows[0]['stlnr'] if rows else None
            return jsonify({'success': True, 'data': rows, 'total': len(rows),
                            'matnr': norm, 'stlnr': stlnr}), 200
    except Exception as e:
        current_app.logger.error(f"Erreur BOM article IH02 ({matnr}): {e}")
        return jsonify({'success': False, 'error': str(e)}), 500


@ih02_hierarchy_blueprint.route('/article-bom-counts', methods=['GET'])
def get_article_bom_counts():
    try:
        matnrs = request.args.get('matnrs', '').strip()
        if not matnrs:
            return jsonify({'success': True, 'data': {}}), 200
        mat_list = [m.strip() for m in matnrs.split(',') if m.strip()]
        if not mat_list:
            return jsonify({'success': True, 'data': {}}), 200
        with get_db_connection() as conn:
            cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
            cursor.execute(f"""
                SELECT a.sap_key AS matnr, COUNT(*) AS nb
                FROM {MO} b
                JOIN {MO} a ON a.id = b.parent_id AND a.object_type = 'ARTICLE'
                WHERE b.object_type = 'BOM_ITEM' AND b.is_active
                  AND b.attributes->>'stlty' = 'M'
                  AND a.sap_key = ANY(%s)
                GROUP BY a.sap_key
            """, [mat_list])
            counts = {row['matnr']: row['nb'] for row in cursor.fetchall() if row['nb']}
            return jsonify({'success': True, 'data': counts}), 200
    except Exception as e:
        current_app.logger.error(f"Erreur counts BOM article IH02: {e}")
        return jsonify({'success': False, 'error': str(e)}), 500


def _apply_bom_line_update(cursor, row_id, data, user):
    """Applique les champs editables d'une ligne de nomenclature (commun T/M).

    Champs de la LIGNE uniquement (option B — la fiche article partagee n'est pas
    modifiee ici, hormis le choix de l'article pointe / ref_object_id) :
      idnrk (article), menge (quantite), meins (unite), category (postp),
      posnr (position), potx1/potx2 (textes composant).
    """
    idnrk = _normalize_sap_matnr((data.get('idnrk') or '').strip())
    art_id = _ensure_article(cursor, idnrk, user)

    sets = ['ref_object_id = %s', 'quantity = %s', 'unit = %s']
    params = [art_id, str(data.get('menge')), (data.get('meins') or '').strip()]
    attr_patch = {}

    if 'category' in data:
        val = (data.get('category') or None)
        sets.append('category = %s'); params.append(val)
        attr_patch['postp'] = val
    if 'posnr' in data and str(data.get('posnr') or '').strip() != '':
        posnr = str(data.get('posnr')).strip()
        digits = ''.join(ch for ch in posnr if ch.isdigit())
        sets.append('sort_order = %s'); params.append(int(digits) if digits else None)
        attr_patch['posnr'] = posnr
    if 'potx1' in data:
        attr_patch['potx1'] = (data.get('potx1') or None)
    if 'potx2' in data:
        attr_patch['potx2'] = (data.get('potx2') or None)

    if attr_patch:
        sets.append('attributes = attributes || %s::jsonb'); params.append(json.dumps(attr_patch))
    sets.append('updated_by = %s'); params.append(user)
    params.append(row_id)
    cursor.execute(f"UPDATE {MO} SET {', '.join(sets)} WHERE id = %s", params)


@ih02_hierarchy_blueprint.route('/bom-component', methods=['PUT'])
def update_bom_component():
    """Met a jour un composant BOM de poste technique (stlty=T).

    Localise la ligne par stlkn (identifiant de position stable) -> posnr devient
    editable. Fallback posnr si stlkn absent (retro-compat).
    """
    try:
        data = request.get_json() or {}
        tplnr = (data.get('tplnr') or '').strip()
        stlnr = (data.get('stlnr') or '').strip()
        stlkn = (data.get('stlkn') or '').strip()
        posnr = (data.get('posnr') or '').strip()
        idnrk = _normalize_sap_matnr((data.get('idnrk') or '').strip())
        menge = data.get('menge')
        meins = (data.get('meins') or '').strip()

        if not tplnr or not stlnr or not (stlkn or posnr):
            return jsonify({'success': False, 'error': 'tplnr, stlnr et (stlkn ou posnr) requis'}), 400
        if not idnrk:
            return jsonify({'success': False, 'error': 'idnrk (article) requis'}), 400
        if menge is None or meins == '':
            return jsonify({'success': False, 'error': 'menge et meins requis'}), 400

        user = _current_user()
        with get_db_connection() as conn:
            cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
            fl_id = _resolve_id(cursor, 'FUNC_LOC', tplnr)
            if fl_id is None:
                return jsonify({'success': False, 'error': 'Poste technique introuvable'}), 404

            if stlkn:
                locate_sql = "AND attributes->>'stlkn' = %s"
                locate_params = [fl_id, stlnr, stlkn]
            else:
                locate_sql = "AND TRIM(attributes->>'posnr') = TRIM(%s)"
                locate_params = [fl_id, stlnr, posnr]
            cursor.execute(f"""
                SELECT id FROM {MO}
                WHERE object_type = 'BOM_ITEM' AND parent_id = %s
                  AND attributes->>'stlty' = 'T'
                  AND attributes->>'stlnr' = %s
                  {locate_sql}
                LIMIT 1
            """, locate_params)
            row = cursor.fetchone()
            if not row:
                return jsonify({'success': False, 'error': 'Ligne de nomenclature non trouvée'}), 404

            _apply_bom_line_update(cursor, row['id'], data, user)
            conn.commit()
            return jsonify({'success': True, 'message': 'Composant BOM mis à jour'}), 200
    except Exception as e:
        current_app.logger.error(f'Erreur update BOM IH02: {e}', exc_info=True)
        return jsonify({'success': False, 'error': str(e)}), 500


@ih02_hierarchy_blueprint.route('/article-bom-component', methods=['PUT'])
def update_article_bom_component():
    """Met a jour un composant de nomenclature matiere (stlty=M), identifie par stlnr+stlkn."""
    try:
        data = request.get_json() or {}
        stlnr = (data.get('stlnr') or '').strip()
        stlkn = (data.get('stlkn') or '').strip()
        idnrk = _normalize_sap_matnr((data.get('idnrk') or '').strip())
        menge = data.get('menge')
        meins = (data.get('meins') or '').strip()

        if not stlnr or not stlkn:
            return jsonify({'success': False, 'error': 'stlnr et stlkn requis'}), 400
        if not idnrk:
            return jsonify({'success': False, 'error': 'idnrk (article) requis'}), 400
        if menge is None or meins == '':
            return jsonify({'success': False, 'error': 'menge et meins requis'}), 400

        user = _current_user()
        with get_db_connection() as conn:
            cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
            cursor.execute(f"""
                SELECT id FROM {MO}
                WHERE object_type = 'BOM_ITEM' AND attributes->>'stlty' = 'M'
                  AND attributes->>'stlnr' = %s AND attributes->>'stlkn' = %s
                LIMIT 1
            """, [stlnr, stlkn])
            row = cursor.fetchone()
            if not row:
                return jsonify({'success': False, 'error': 'Ligne de nomenclature matière introuvable (stlnr/stlkn)'}), 404

            _apply_bom_line_update(cursor, row['id'], data, user)
            conn.commit()
            return jsonify({'success': True, 'message': 'Composant nomenclature matière mis à jour'}), 200
    except Exception as e:
        current_app.logger.error(f'Erreur update BOM article IH02: {e}', exc_info=True)
        return jsonify({'success': False, 'error': str(e)}), 500


@ih02_hierarchy_blueprint.route('/article-master', methods=['PUT'])
def update_article_master():
    """Renomme le code d'un article (fiche PARTAGEE — s'applique partout).

    L'article est localise par idnrk (sap_key, immuable) ; seul `code` change.
    La colonne code denormalisee des BOM_ITEM referencant l'article est resynchronisee.
    """
    try:
        data = request.get_json() or {}
        idnrk = _normalize_sap_matnr((data.get('idnrk') or '').strip())
        new_code = (data.get('code') or '').strip()

        if not idnrk:
            return jsonify({'success': False, 'error': 'idnrk (article) requis'}), 400
        if not new_code:
            return jsonify({'success': False, 'error': 'code requis'}), 400

        user = _current_user()
        with get_db_connection() as conn:
            cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
            aid = _resolve_id(cursor, 'ARTICLE', idnrk)
            if aid is None:
                return jsonify({'success': False, 'error': f'Article "{idnrk}" non trouvé'}), 404

            cursor.execute(
                f"""SELECT 1 FROM {MO}
                    WHERE object_type = 'ARTICLE' AND code = %s AND id <> %s AND is_active
                    LIMIT 1""",
                [new_code, aid],
            )
            if cursor.fetchone():
                return jsonify({'success': False,
                                'error': f'Code article "{new_code}" déjà utilisé'}), 409

            try:
                cursor.execute(f"UPDATE {MO} SET code = %s, updated_by = %s WHERE id = %s",
                               [new_code, user, aid])
                # Resynchronise le code denormalise des lignes de nomenclature
                # (BOM_ITEM est hors de uq_mo_code_sibling : un article s'y repete
                # legitimement, aucune violation possible sur cette seconde requete).
                cursor.execute(
                    f"""UPDATE {MO} SET code = %s, updated_by = %s
                        WHERE object_type = 'BOM_ITEM' AND ref_object_id = %s""",
                    [new_code, user, aid],
                )
                nb_bom = cursor.rowcount
                conn.commit()
            except pg_errors.UniqueViolation:
                conn.rollback()
                return jsonify({
                    'success': False,
                    'error': f'Le code article "{new_code}" vient d\'être pris',
                }), 409
            return jsonify({'success': True,
                            'message': f'Code article renommé ({nb_bom} ligne(s) de nomenclature synchronisée(s))'}), 200
    except Exception as e:
        current_app.logger.error(f'Erreur renommage article IH02: {e}', exc_info=True)
        return jsonify({'success': False, 'error': str(e)}), 500


# ---------------------------------------------------------------------------
# Referentiels lecture seule (pick-lists) — conserves sur raw_data
# ---------------------------------------------------------------------------

@ih02_hierarchy_blueprint.route('/work-centers', methods=['GET'])
def get_work_centers():
    try:
        with get_db_connection() as conn:
            cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
            cursor.execute("""
                SELECT DISTINCT cr.arbpl AS code, cr.objid, ctx.ktext AS designation
                FROM raw_data.crhd cr
                LEFT JOIN raw_data.crtx ctx ON ctx.objid = cr.objid AND ctx.spras = 'F'
                WHERE cr.werks = '9200'
                ORDER BY cr.arbpl
            """)
            return jsonify({'success': True, 'data': cursor.fetchall()}), 200
    except Exception as e:
        current_app.logger.error(f"Erreur postes de travail IH02: {e}")
        return jsonify({'success': False, 'error': str(e)}), 500


@ih02_hierarchy_blueprint.route('/search-equipment', methods=['GET'])
def search_equipment():
    """Catalogue equipements (autocompletion) — lecture seule raw_data."""
    try:
        q = request.args.get('q', '', type=str).strip()
        limit = min(request.args.get('limit', 20, type=int), 50)
        base_query = """
            SELECT DISTINCT ON (e.equnr)
                TRIM(e.equnr) AS equnr,
                LTRIM(TRIM(e.equnr), '0') AS equnr_short,
                TRIM(COALESCE(kf.eqktx, kn.eqktx, kx.eqktx, '')) AS designation,
                TRIM(COALESCE(e.eqart, '')) AS eqart,
                TRIM(COALESCE(e.herst, '')) AS herst,
                TRIM(COALESCE(e.typbz, '')) AS typbz,
                TRIM(COALESCE(e.matnr, '')) AS matnr
            FROM raw_data.equi e
            LEFT JOIN raw_data.eqkt kf ON e.equnr = kf.equnr AND e.mandt = kf.mandt AND kf.spras = 'F'
            LEFT JOIN raw_data.eqkt kn ON e.equnr = kn.equnr AND e.mandt = kn.mandt AND kn.spras = 'N'
            LEFT JOIN raw_data.eqkt kx ON e.equnr = kx.equnr AND e.mandt = kx.mandt
        """
        with get_db_connection() as conn:
            cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
            if q:
                pattern = f'%{q}%'
                cursor.execute(base_query + """
                    WHERE e.equnr ILIKE %s OR kf.eqktx ILIKE %s OR kn.eqktx ILIKE %s OR kx.eqktx ILIKE %s
                    ORDER BY e.equnr LIMIT %s
                """, [pattern, pattern, pattern, pattern, limit])
            else:
                cursor.execute(base_query + " ORDER BY e.equnr LIMIT %s", [limit])
            return jsonify({'success': True, 'data': cursor.fetchall()}), 200
    except Exception as e:
        current_app.logger.error(f"Erreur recherche équipement IH02: {e}")
        return jsonify({'success': False, 'error': str(e)}), 500


@ih02_hierarchy_blueprint.route('/search-article', methods=['GET'])
def search_article():
    """Catalogue articles (autocompletion) — lecture seule raw_data."""
    try:
        q = request.args.get('q', '', type=str).strip()
        limit = min(request.args.get('limit', 20, type=int), 50)
        base_query = """
            SELECT DISTINCT ON (m.matnr)
                TRIM(m.matnr) AS matnr,
                LTRIM(TRIM(m.matnr), '0') AS matnr_short,
                TRIM(COALESCE(kf.maktx, kn.maktx, ke.maktx, kx.maktx, '')) AS designation,
                TRIM(COALESCE(m.mtart, '')) AS mtart,
                TRIM(COALESCE(m.meins, '')) AS meins,
                TRIM(COALESCE(m.extwg, '')) AS extwg
            FROM raw_data.mara m
            LEFT JOIN raw_data.makt kf ON m.matnr = kf.matnr AND kf.spras = 'F'
            LEFT JOIN raw_data.makt kn ON m.matnr = kn.matnr AND kn.spras = 'N'
            LEFT JOIN raw_data.makt ke ON m.matnr = ke.matnr AND ke.spras = 'E'
            LEFT JOIN raw_data.makt kx ON m.matnr = kx.matnr
            WHERE (m.lvorm IS NULL OR TRIM(m.lvorm) = '')
        """
        with get_db_connection() as conn:
            cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
            if q:
                pattern = f'%{q}%'
                cursor.execute(base_query + """
                    AND (m.matnr ILIKE %s OR kf.maktx ILIKE %s OR kn.maktx ILIKE %s
                         OR ke.maktx ILIKE %s OR kx.maktx ILIKE %s)
                    ORDER BY m.matnr LIMIT %s
                """, [pattern, pattern, pattern, pattern, pattern, limit])
            else:
                cursor.execute(base_query + " ORDER BY m.matnr LIMIT %s", [limit])
            return jsonify({'success': True, 'data': cursor.fetchall()}), 200
    except Exception as e:
        current_app.logger.error(f"Erreur recherche article IH02: {e}")
        return jsonify({'success': False, 'error': str(e)}), 500


@ih02_hierarchy_blueprint.route('/export-equipment', methods=['GET'])
def export_equipment():
    try:
        with get_db_connection() as conn:
            cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
            cursor.execute(f"""
                SELECT
                    o.sap_key AS equnr,
                    o.code    AS equnr_short,
                    o.designation AS designation,
                    o.type_code AS type_equipement,
                    o.category  AS categorie,
                    pfl.sap_key AS poste_technique,
                    peq.sap_key AS equipement_superieur,
                    o.attributes->>'herst' AS fabricant,
                    o.attributes->>'herld' AS pays_fabricant,
                    o.attributes->>'typbz' AS modele,
                    o.attributes->>'sernr' AS numero_serie,
                    o.attributes->>'invnr' AS numero_inventaire,
                    o.attributes->>'groes' AS taille,
                    o.attributes->>'brgew' AS poids,
                    o.attributes->>'gewei' AS unite_poids,
                    o.attributes->>'answt' AS valeur_acquisition,
                    o.attributes->>'waers' AS devise,
                    o.attributes->>'ansdt' AS date_acquisition,
                    o.attributes->>'baujj' AS annee_construction,
                    o.attributes->>'baumm' AS mois_construction,
                    o.attributes->>'inbdt' AS date_mise_service,
                    o.cost_center AS centre_couts,
                    o.attributes->>'bukrs' AS societe,
                    o.attributes->>'gsber' AS domaine_activite,
                    o.plant AS division_maintenance,
                    o.planner_group AS groupe_planification,
                    o.attributes->>'swerk' AS division,
                    o.attributes->>'stort' AS emplacement,
                    o.attributes->>'beber' AS section,
                    o.attributes->>'matnr' AS numero_article,
                    o.attributes->>'elief' AS fournisseur,
                    o.attributes->>'warpl' AS plan_maintenance
                FROM {MO} o
                LEFT JOIN {MO} pfl ON pfl.id = o.parent_id AND pfl.object_type = 'FUNC_LOC'
                LEFT JOIN {MO} peq ON peq.id = o.parent_id AND peq.object_type = 'EQUIPMENT'
                WHERE o.object_type = 'EQUIPMENT' AND o.is_active
                ORDER BY o.sap_key
            """)
            rows = cursor.fetchall()
            if not rows:
                return jsonify({'success': False, 'error': 'Aucune donnée'}), 404
            output = io.StringIO()
            writer = csv.DictWriter(output, fieldnames=rows[0].keys(), delimiter=';')
            writer.writeheader()
            writer.writerows(rows)
            return Response(output.getvalue(), mimetype='text/csv',
                            headers={'Content-Disposition': 'attachment; filename=ih02_equipements.csv'})
    except Exception as e:
        current_app.logger.error(f"Erreur export équipements IH02: {e}")
        return jsonify({'success': False, 'error': str(e)}), 500
