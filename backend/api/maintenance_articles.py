"""
API pour les articles de maintenance (MARA filtre MTART = HIBE / ERSA).
Sources: raw_data.mara, raw_data.makt, raw_data.marc, raw_data.mard
"""
import json

from flask import Blueprint, jsonify, request, current_app, Response
import psycopg2.extras
from config.database import get_db_connection
from config.settings import Config
from services.cache_service import cache_get, cache_set, cache_invalidate

maintenance_articles_blueprint = Blueprint('maintenance_articles', __name__)

CACHE_PREFIX = 'maint:articles:'

# Types d'articles consideres "maintenance" (SAP PM) :
#   ERSA = Pieces de rechange, IBAU = Sous-ensembles de maintenance,
#   NLAG = Article non gere en stock
ALLOWED_MTART = ('ERSA', 'IBAU', 'NLAG')

# Divisions du site cible St-Jean (werks). ERSA/NLAG y sont rattaches (marc).
ST_JEAN_WERKS = ('9200', '2200')
_WERKS_IN = ', '.join(f"'{w}'" for w in ST_JEAN_WERKS)


def _st_jean_scope_clause(alias='m'):
    """Clause SQL "perimetre St-Jean" appliquee a toutes les pages articles.

    Un article est dans le perimetre si :
      - IBAU (sous-ensembles, sans donnee de division) : present dans la structure
        IH02 (noeud ARTICLE rattache a une nomenclature, OU materiau d'un EQUIPMENT) ;
      - ERSA / NLAG : rattache a une division du site (marc.werks IN 9200/2200).

    `alias` = alias de raw_data.mara dans la requete appelante. Aucun parametre lie
    (constantes seulement) -> composable directement dans le WHERE.
    """
    return f"""
    (
        ({alias}.mtart = 'IBAU' AND (
            EXISTS (SELECT 1 FROM clean_data.maintenance_object mo
                    WHERE mo.object_type = 'ARTICLE' AND mo.is_active AND mo.sap_key = {alias}.matnr)
            OR EXISTS (SELECT 1 FROM clean_data.maintenance_object mo
                       WHERE mo.object_type = 'EQUIPMENT' AND mo.is_active
                         AND mo.attributes->>'matnr' = {alias}.matnr)
        ))
        OR ({alias}.mtart <> 'IBAU' AND EXISTS (
            SELECT 1 FROM raw_data.marc c
            WHERE c.matnr = {alias}.matnr AND TRIM(c.werks) IN ({_WERKS_IN})
        ))
    )
    """


@maintenance_articles_blueprint.route('/articles', methods=['GET'])
def list_articles():
    """Liste paginee des articles de maintenance avec filtres."""
    try:
        page = max(1, request.args.get('page', 1, type=int))
        per_page = min(max(1, request.args.get('per_page', 25, type=int)), 100)
        search = request.args.get('search', '', type=str).strip()
        mtart = request.args.get('mtart', '', type=str).strip().upper()
        matkl = request.args.get('matkl', '', type=str).strip()
        order_by = request.args.get('order_by', 'matnr', type=str)
        order = request.args.get('order', 'asc', type=str)
        st_jean = request.args.get('st_jean', '', type=str).strip().lower() in ('1', 'true', 'yes')

        offset = (page - 1) * per_page

        cache_key = (f"{CACHE_PREFIX}list:{page}:{per_page}:{order_by}:{order}:"
                     f"{search}:{mtart}:{matkl}:stjean={int(st_jean)}")
        cached = cache_get(cache_key)
        if cached is not None:
            return Response(cached, mimetype='application/json')

        where_clauses = ["m.mtart = ANY(%s)"]
        params = [list(ALLOWED_MTART)]

        if mtart and mtart in ALLOWED_MTART:
            where_clauses[0] = "m.mtart = %s"
            params = [mtart]

        if search:
            where_clauses.append("""
                (m.matnr ILIKE %s
                 OR k_fr.maktx ILIKE %s
                 OR k_any.maktx ILIKE %s
                 OR m.matkl ILIKE %s)
            """)
            sp = f'%{search}%'
            params.extend([sp, sp, sp, sp])

        if matkl:
            where_clauses.append("TRIM(m.matkl) = %s")
            params.append(matkl)

        # Exclure les articles inactifs (indicateur SAP de suppression lvorm='X')
        where_clauses.append("TRIM(COALESCE(m.lvorm, '')) <> 'X'")

        # Restreindre au perimetre St-Jean (IBAU via structure IH02, autres via division)
        if st_jean:
            where_clauses.append(_st_jean_scope_clause('m'))

        where_sql = "WHERE " + " AND ".join(where_clauses)

        order_mapping = {
            'matnr': 'm.matnr',
            'mtart': 'm.mtart',
            'matkl': 'm.matkl',
            'description': 'description',
        }
        order_col = order_mapping.get(order_by, 'm.matnr')
        order_dir = 'DESC' if order.lower() == 'desc' else 'ASC'

        joins_makt = """
            LEFT JOIN raw_data.makt k_fr
                ON k_fr.mandt = m.mandt AND k_fr.matnr = m.matnr AND k_fr.spras = 'F'
            LEFT JOIN LATERAL (
                SELECT maktx FROM raw_data.makt
                WHERE mandt = m.mandt AND matnr = m.matnr
                ORDER BY (CASE WHEN spras='F' THEN 0 WHEN spras='E' THEN 1 ELSE 2 END)
                LIMIT 1
            ) k_any ON TRUE
            LEFT JOIN LATERAL (
                SELECT wgbez FROM raw_data.t023t
                WHERE mandt = m.mandt AND matkl = m.matkl
                ORDER BY (CASE WHEN spras='F' THEN 0 WHEN spras='E' THEN 1 ELSE 2 END)
                LIMIT 1
            ) g ON TRUE
            LEFT JOIN LATERAL (
                SELECT mtbez FROM raw_data.t134t
                WHERE mandt = m.mandt AND mtart = m.mtart
                ORDER BY (CASE WHEN spras='F' THEN 0 WHEN spras='E' THEN 1 ELSE 2 END)
                LIMIT 1
            ) tt ON TRUE
        """

        with get_db_connection() as conn:
            cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)

            count_query = f"""
                SELECT COUNT(*) AS total
                FROM raw_data.mara m
                {joins_makt}
                {where_sql}
            """
            cursor.execute(count_query, params)
            total = cursor.fetchone()['total']

            data_query = f"""
                SELECT
                    m.matnr,
                    LTRIM(m.matnr, '0') AS matnr_short,
                    COALESCE(k_fr.maktx, k_any.maktx) AS description,
                    TRIM(m.mtart) AS mtart,
                    tt.mtbez AS mtart_label,
                    TRIM(m.matkl) AS matkl,
                    g.wgbez AS matkl_label,
                    TRIM(m.meins) AS meins,
                    TRIM(m.mbrsh) AS mbrsh,
                    TRIM(m.bismt) AS bismt,
                    m.brgew,
                    TRIM(m.gewei) AS gewei,
                    m.ntgew,
                    TRIM(m.lvorm) AS lvorm,
                    m.ersda,
                    TRIM(m.ernam) AS ernam
                FROM raw_data.mara m
                {joins_makt}
                {where_sql}
                ORDER BY {order_col} {order_dir} NULLS LAST, m.matnr ASC
                LIMIT %s OFFSET %s
            """
            cursor.execute(data_query, params + [per_page, offset])
            articles = cursor.fetchall()

            cursor.execute(
                """
                SELECT DISTINCT TRIM(m.mtart) AS mtart,
                       COALESCE(
                           (SELECT mtbez FROM raw_data.t134t
                            WHERE mandt = m.mandt AND mtart = m.mtart
                            ORDER BY (CASE WHEN spras='F' THEN 0 WHEN spras='E' THEN 1 ELSE 2 END)
                            LIMIT 1),
                           ''
                       ) AS label
                FROM raw_data.mara m
                WHERE m.mtart = ANY(%s)
                ORDER BY 1
                """,
                [list(ALLOWED_MTART)]
            )
            mtart_options = [
                {'code': r['mtart'], 'label': r['label']}
                for r in cursor.fetchall()
            ]

            cursor.execute(
                """
                SELECT DISTINCT TRIM(m.matkl) AS matkl,
                       COALESCE(
                           (SELECT wgbez FROM raw_data.t023t
                            WHERE mandt = m.mandt AND matkl = m.matkl
                            ORDER BY (CASE WHEN spras='F' THEN 0 WHEN spras='E' THEN 1 ELSE 2 END)
                            LIMIT 1),
                           ''
                       ) AS label
                FROM raw_data.mara m
                WHERE m.mtart = ANY(%s) AND m.matkl IS NOT NULL AND TRIM(m.matkl) <> ''
                ORDER BY 1
                """,
                [list(ALLOWED_MTART)]
            )
            matkl_options = [
                {'code': r['matkl'], 'label': r['label']}
                for r in cursor.fetchall()
            ]

            payload = json.dumps({
                'success': True,
                'data': articles,
                'total': total,
                'page': page,
                'per_page': per_page,
                'filter_options': {
                    'mtart': mtart_options,
                    'matkl': matkl_options,
                }
            }, default=str)
            cache_set(cache_key, payload, Config.MAINTENANCE_CACHE_TTL)
            return Response(payload, mimetype='application/json')

    except Exception as e:
        current_app.logger.error(f"Erreur liste articles maintenance: {e}")
        return jsonify({'success': False, 'error': str(e)}), 500


@maintenance_articles_blueprint.route('/articles/<matnr>/details', methods=['GET'])
def get_article_details(matnr: str):
    """Detail complet d'un article + stocks par division/magasin."""
    try:
        if not matnr:
            return jsonify({'success': False, 'error': 'matnr requis'}), 400

        matnr_padded = matnr.zfill(18) if matnr.isdigit() else matnr

        with get_db_connection() as conn:
            cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)

            cursor.execute("""
                SELECT
                    m.matnr,
                    LTRIM(m.matnr, '0') AS matnr_short,
                    COALESCE(k_fr.maktx, k_any.maktx) AS description,
                    k_fr.maktx AS description_fr,
                    TRIM(m.mtart) AS mtart,
                    tt.mtbez AS mtart_label,
                    TRIM(m.matkl) AS matkl,
                    g.wgbez AS matkl_label,
                    TRIM(m.meins) AS meins,
                    TRIM(m.bstme) AS bstme,
                    TRIM(m.mbrsh) AS mbrsh,
                    TRIM(m.bismt) AS bismt,
                    TRIM(m.spart) AS spart,
                    TRIM(m.extwg) AS extwg,
                    m.brgew, TRIM(m.gewei) AS gewei,
                    m.ntgew, m.volum, TRIM(m.voleh) AS voleh,
                    m.laeng, m.breit, m.hoehe, TRIM(m.meabm) AS meabm,
                    TRIM(m.groes) AS groes,
                    TRIM(m.wrkst) AS wrkst,
                    TRIM(m.normt) AS normt,
                    TRIM(m.ean11) AS ean11,
                    TRIM(m.lvorm) AS lvorm,
                    m.ersda, TRIM(m.ernam) AS ernam,
                    m.laeda, TRIM(m.aenam) AS aenam,
                    TRIM(m.mfrnr) AS mfrnr,
                    TRIM(m.mfrpn) AS mfrpn,
                    TRIM(m.zeinr) AS zeinr
                FROM raw_data.mara m
                LEFT JOIN raw_data.makt k_fr
                    ON k_fr.mandt = m.mandt AND k_fr.matnr = m.matnr AND k_fr.spras = 'F'
                LEFT JOIN LATERAL (
                    SELECT maktx FROM raw_data.makt
                    WHERE mandt = m.mandt AND matnr = m.matnr
                    ORDER BY (CASE WHEN spras='F' THEN 0 WHEN spras='E' THEN 1 ELSE 2 END)
                    LIMIT 1
                ) k_any ON TRUE
                LEFT JOIN LATERAL (
                    SELECT wgbez FROM raw_data.t023t
                    WHERE mandt = m.mandt AND matkl = m.matkl
                    ORDER BY (CASE WHEN spras='F' THEN 0 WHEN spras='E' THEN 1 ELSE 2 END)
                    LIMIT 1
                ) g ON TRUE
                LEFT JOIN LATERAL (
                    SELECT mtbez FROM raw_data.t134t
                    WHERE mandt = m.mandt AND mtart = m.mtart
                    ORDER BY (CASE WHEN spras='F' THEN 0 WHEN spras='E' THEN 1 ELSE 2 END)
                    LIMIT 1
                ) tt ON TRUE
                WHERE m.matnr = %s
                LIMIT 1
            """, [matnr_padded])
            article = cursor.fetchone()

            if not article:
                return jsonify({'success': False, 'error': 'Article non trouve'}), 404

            cursor.execute("""
                SELECT TRIM(spras) AS spras, maktx
                FROM raw_data.makt
                WHERE matnr = %s
                ORDER BY spras
            """, [matnr_padded])
            article['descriptions'] = cursor.fetchall()

            cursor.execute("""
                SELECT
                    TRIM(c.werks) AS werks,
                    TRIM(c.ekgrp) AS ekgrp,
                    TRIM(c.dispo) AS dispo,
                    TRIM(c.dismm) AS dismm,
                    TRIM(c.disls) AS disls,
                    c.minbe, c.eisbe, c.bstmi, c.bstma, c.bstrf, c.bstfe,
                    c.plifz, c.webaz,
                    TRIM(c.beskz) AS beskz,
                    TRIM(c.lvorm) AS lvorm,
                    TRIM(c.mmsta) AS mmsta,
                    TRIM(c.maabc) AS maabc
                FROM raw_data.marc c
                WHERE c.matnr = %s
                ORDER BY c.werks
            """, [matnr_padded])
            article['plants'] = cursor.fetchall()

            cursor.execute("""
                SELECT
                    TRIM(d.werks) AS werks,
                    TRIM(d.lgort) AS lgort,
                    d.labst, d.umlme, d.insme, d.einme, d.speme, d.retme,
                    TRIM(d.lvorm) AS lvorm
                FROM raw_data.mard d
                WHERE d.matnr = %s
                ORDER BY d.werks, d.lgort
            """, [matnr_padded])
            article['stocks'] = cursor.fetchall()

            return jsonify({'success': True, 'data': article}), 200

    except Exception as e:
        current_app.logger.error(f"Erreur details article maintenance {matnr}: {e}")
        return jsonify({'success': False, 'error': str(e)}), 500


@maintenance_articles_blueprint.route('/articles/stats', methods=['GET'])
def get_articles_stats():
    """Stats globales pour la page (compteurs par type).

    Parametres optionnels :
      - mtart   : restreint les compteurs a un type
      - st_jean : ne compte que les articles du perimetre St-Jean
                  (IBAU via structure IH02, ERSA/NLAG via division 9200/2200)
    """
    try:
        mtart = request.args.get('mtart', '', type=str).strip().upper()
        st_jean = request.args.get('st_jean', '', type=str).strip().lower() in ('1', 'true', 'yes')

        cache_key = f"{CACHE_PREFIX}stats:{mtart}:stjean={int(st_jean)}"
        cached = cache_get(cache_key)
        if cached is not None:
            return Response(cached, mimetype='application/json')

        if mtart and mtart in ALLOWED_MTART:
            type_clause, type_param = "m.mtart = %s", [mtart]
        else:
            type_clause, type_param = "m.mtart = ANY(%s)", [list(ALLOWED_MTART)]

        struct_sql = (" AND " + _st_jean_scope_clause('m')) if st_jean else ""

        with get_db_connection() as conn:
            cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
            cursor.execute(f"""
                SELECT TRIM(m.mtart) AS mtart, COUNT(*) AS nb
                FROM raw_data.mara m
                WHERE {type_clause}
                  AND TRIM(COALESCE(m.lvorm, '')) <> 'X'   -- exclut les inactifs (suppression SAP)
                  {struct_sql}
                GROUP BY m.mtart
                ORDER BY m.mtart
            """, type_param)
            by_type = cursor.fetchall()

            cursor.execute(f"""
                SELECT COUNT(DISTINCT TRIM(m.matkl)) AS nb
                FROM raw_data.mara m
                WHERE {type_clause} AND m.matkl IS NOT NULL AND TRIM(m.matkl) <> ''
                  AND TRIM(COALESCE(m.lvorm, '')) <> 'X'
                  {struct_sql}
            """, type_param)
            nb_matkl = cursor.fetchone()['nb']

            total = sum(int(r['nb']) for r in by_type)

            payload = json.dumps({
                'success': True,
                'data': {
                    'total': total,
                    'by_type': by_type,
                    'nb_groupes_articles': nb_matkl,
                }
            }, default=str)
            cache_set(cache_key, payload, Config.MAINTENANCE_CACHE_TTL)
            return Response(payload, mimetype='application/json')

    except Exception as e:
        current_app.logger.error(f"Erreur stats articles maintenance: {e}")
        return jsonify({'success': False, 'error': str(e)}), 500


# Mapping cle API -> (colonne SAP, table cible, longueur max SAP)
# - cle API = nom utilise par le frontend
# - table cible : 'mara' (master) ou 'makt' (description FR)
ARTICLE_FIELD_MAPPING = {
    'description': ('maktx', 'makt', 40),
    'matkl':       ('matkl', 'mara', 9),
    'meins':       ('meins', 'mara', 3),
    'bstme':       ('bstme', 'mara', 3),
    'mbrsh':       ('mbrsh', 'mara', 1),
    'bismt':       ('bismt', 'mara', 18),
    'spart':       ('spart', 'mara', 2),
    'extwg':       ('extwg', 'mara', 18),
    'brgew':       ('brgew', 'mara', 20),
    'ntgew':       ('ntgew', 'mara', 20),
    'gewei':       ('gewei', 'mara', 3),
    'volum':       ('volum', 'mara', 20),
    'voleh':       ('voleh', 'mara', 3),
    'laeng':       ('laeng', 'mara', 20),
    'breit':       ('breit', 'mara', 20),
    'hoehe':       ('hoehe', 'mara', 20),
    'meabm':       ('meabm', 'mara', 3),
    'groes':       ('groes', 'mara', 32),
    'wrkst':       ('wrkst', 'mara', 48),
    'normt':       ('normt', 'mara', 18),
    'ean11':       ('ean11', 'mara', 18),
    'mfrnr':       ('mfrnr', 'mara', 10),
    'mfrpn':       ('mfrpn', 'mara', 40),
    'zeinr':       ('zeinr', 'mara', 22),
    'lvorm':       ('lvorm', 'mara', 1),
}


@maintenance_articles_blueprint.route('/articles/<matnr>', methods=['PUT'])
def update_article(matnr: str):
    """Met a jour un article maintenance.
    Dispatche les UPDATE sur les tables sources :
      - makt : maktx (description) sur la ligne FR (sinon toutes langues)
      - mara : tous les autres champs master
    """
    try:
        data = request.get_json()
        if not data:
            return jsonify({'success': False, 'error': 'Aucune donnee fournie'}), 400

        matnr_padded = matnr.zfill(18) if matnr.isdigit() else matnr

        by_table = {'mara': [], 'makt': []}
        modified_fields = []
        errors = []

        for key, val in data.items():
            if key not in ARTICLE_FIELD_MAPPING:
                continue
            col, table, max_len = ARTICLE_FIELD_MAPPING[key]
            v = val if val not in ('', None) else None
            if v is not None and isinstance(v, str) and len(v) > max_len:
                errors.append(f'Champ "{key}" depasse {max_len} caracteres')
                continue
            by_table[table].append((col, v))
            modified_fields.append(key)

        if errors:
            return jsonify({'success': False, 'error': ' ; '.join(errors)}), 400
        if not modified_fields:
            return jsonify({'success': False, 'error': 'Aucun champ a mettre a jour'}), 400

        with get_db_connection() as conn:
            cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)

            cursor.execute(
                "SELECT matnr, mtart FROM raw_data.mara WHERE matnr = %s LIMIT 1",
                [matnr_padded]
            )
            row = cursor.fetchone()
            if not row:
                return jsonify({'success': False, 'error': f'Article {matnr} non trouve'}), 404
            if row['mtart'] not in ALLOWED_MTART:
                return jsonify({
                    'success': False,
                    'error': f'Article {matnr} (type {row["mtart"]}) hors perimetre maintenance'
                }), 403

            if by_table['mara']:
                cols = [f"{c} = %s" for c, _ in by_table['mara']]
                vals = [v for _, v in by_table['mara']] + [matnr_padded]
                cursor.execute(
                    f"UPDATE raw_data.mara SET {', '.join(cols)}, laeda = TO_CHAR(NOW(),'YYYYMMDD'), aenam = 'MIGFAC' "
                    f"WHERE matnr = %s",
                    vals
                )

            if by_table['makt']:
                cols = [f"{c} = %s" for c, _ in by_table['makt']]
                vals = [v for _, v in by_table['makt']] + [matnr_padded]
                cursor.execute(
                    f"UPDATE raw_data.makt SET {', '.join(cols)} WHERE matnr = %s AND spras = 'F'",
                    vals
                )
                if cursor.rowcount == 0:
                    cursor.execute(
                        f"UPDATE raw_data.makt SET {', '.join(cols)} WHERE matnr = %s",
                        vals
                    )
                    if cursor.rowcount == 0:
                        cursor.execute("SELECT mandt FROM raw_data.mara WHERE matnr = %s LIMIT 1", [matnr_padded])
                        mandt_row = cursor.fetchone()
                        mandt = mandt_row['mandt'] if mandt_row else '500'
                        ins_col = by_table['makt'][0][0]
                        ins_val = by_table['makt'][0][1]
                        cursor.execute(
                            f"INSERT INTO raw_data.makt (mandt, matnr, spras, {ins_col}) VALUES (%s, %s, 'F', %s)",
                            [mandt, matnr_padded, ins_val]
                        )

            conn.commit()

            # Invalide le cache des articles (liste + stats) apres modification
            cache_invalidate(CACHE_PREFIX)

            return jsonify({
                'success': True,
                'message': f'{len(modified_fields)} champ(s) mis a jour',
                'modified': modified_fields
            }), 200

    except Exception as e:
        current_app.logger.error(f"Erreur update article {matnr}: {e}")
        return jsonify({'success': False, 'error': str(e)}), 500
