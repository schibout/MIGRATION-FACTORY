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
import os
from datetime import date

from flask import Blueprint, Response, current_app, jsonify, request
from flask_jwt_extended import get_jwt_identity, jwt_required
import psycopg2.extras

from config.database import get_db_connection
from config.settings import Config
from services.cache_service import cache_get, cache_set, cache_invalidate
from services.pe_tools_import_service import PE_TOOLS_COLUMNS, parse_pe_tools_csv, parse_pe_tools_excel

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

# Colonnes renseignees par l'import de fichiers (migration 077). La table
# n'est ecrite QUE par l'import de fichiers (POST /pe-tools/import) : les
# gammes ne se modifient pas dans l'application.
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
ORDERABLE = set(COLUMNS) | set(COMPUTED_COLUMNS) | {'raw_id', 'date_derniere_execution', 'ifs_date_execution', 'groupe_ressources'}

# Colonnes d'audit ajoutees par la migration 029. Elles peuvent manquer si la
# migration n'a pas encore ete jouee, ou si la table a ete rechargee depuis le
# fichier source -> presence detectee une fois puis memorisee.
_audit_available = None

# Colonnes de la migration 077 (import par fichier). Meme logique de detection
# que pour l'audit : sans la migration, l'ecran fonctionne comme avant.
# Detection memorisee par worker : apres avoir joue la migration 077,
# redemarrer le backend (./deploybackend.sh).
_import_columns_available = None

# raw_id est-il attribue par la base (identite / valeur par defaut) ? Detecte
# une fois puis memorise, comme les colonnes ci-dessus.
_raw_id_auto = None


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


def _raw_id_is_auto(cursor) -> bool:
    """raw_id est une colonne d'identite GENERATED ALWAYS dans la base : lui
    passer une valeur explicite fait echouer l'INSERT (« cannot insert a
    non-DEFAULT value into column raw_id »), c'est donc a PostgreSQL de
    l'attribuer. La table est chargee hors application et peut etre recreee
    sans identite ni valeur par defaut -> detection une fois puis memorisee
    (apres un rechargement changeant la definition, redemarrer le backend).
    """
    global _raw_id_auto
    if _raw_id_auto is None:
        cursor.execute("""
            SELECT (is_identity = 'YES' OR column_default IS NOT NULL) AS auto
            FROM information_schema.columns
            WHERE table_schema = 'raw_data' AND table_name = 'pe_tools'
              AND column_name = 'raw_id'
        """)
        row = cursor.fetchone()
        _raw_id_auto = bool(row and row['auto'])
    return _raw_id_auto


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


# Colonnes DATE calculees, jamais saisies : 082 (derniere execution du plan, trigger
# depuis raw_data.plan_entretien_derniere_exec) et 083 (ifs_date_execution = derniere
# execution + frequence, colonne generee). Chacune n'est lue qu'une fois sa migration jouee.
DATE_COLUMNS = ['date_derniere_execution', 'ifs_date_execution']
# Colonne generee (087) : groupe de ressources IFS deduit du type, lecture seule.
DERIVED_COLUMNS = ['groupe_ressources']
_columns_present = {}


def _has_column(cursor, column: str, table: str = 'pe_tools') -> bool:
    """Presence d'une colonne d'une table raw_data, detectee une fois puis memorisee par worker."""
    if (table, column) not in _columns_present:
        cursor.execute("""
            SELECT COUNT(*) AS nb
            FROM information_schema.columns
            WHERE table_schema = 'raw_data' AND table_name = %s AND column_name = %s
        """, [table, column])
        _columns_present[(table, column)] = cursor.fetchone()['nb'] == 1
    return _columns_present[(table, column)]


def _has_date_exec_column(cursor) -> bool:
    return _has_column(cursor, 'date_derniere_execution')


def _selected_columns(cursor):
    """Colonnes lues par la liste, le detail et l'export : les colonnes
    calculees en tete (si les migrations 077 / 082 / 083 sont jouees) puis les colonnes metier."""
    columns = list(COMPUTED_COLUMNS) if _has_import_columns(cursor) else []
    columns += [c for c in DATE_COLUMNS + DERIVED_COLUMNS if _has_column(cursor, c)]
    return columns + COLUMNS


def _filter_columns(cursor):
    """Colonnes filtrables reellement presentes (les colonnes 077 ne le sont
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
            # jsonify rendrait une date au format HTTP (« Mon, 10 Aug 2026 00:00:00 GMT »).
            for c in ('date_derniere_execution', 'ifs_date_execution'):
                if row.get(c):
                    row[c] = row[c].isoformat()
            # Saisie manuelle en cours pour le plan (a defaut poste) de la gamme (migration 085).
            if _has_column(cursor, 'source', 'plan_entretien_derniere_exec'):
                id_type, identifiant = _cle_date_manuelle(cursor, raw_id) or (None, None)
                if id_type:
                    cursor.execute("""
                        SELECT left(date_derniere_execution, 10) AS date, saisi_par,
                               to_char(updated_at, 'YYYY-MM-DD HH24:MI') AS saisi_le
                        FROM raw_data.plan_entretien_derniere_exec
                        WHERE source = 'MANUEL' AND id_type = %s AND LTRIM(warpl, '0') = %s
                    """, [id_type, identifiant])
                    row['date_saisie_manuelle'] = cursor.fetchone()
                row['date_rattachement'] = {'id_type': id_type, 'identifiant': identifiant}
            return jsonify({'success': True, 'data': row}), 200

    except Exception as e:
        current_app.logger.error(f"Erreur detail pe_tools {raw_id}: {e}")
        return jsonify({'success': False, 'error': str(e)}), 500


def _import_one_file(conn, nom_fichier: str, content: bytes, user: str) -> dict:
    """Importe UN fichier PE Tools en mode "remplacer par fichier" : les lignes
    du meme fichier sont supprimees puis rechargees, les autres (autres
    fichiers, lignes historiques sans nom_fichier) ne bougent pas.

    "Remplacer par fichier" = par CODE de fichier (public.pe_tools_code_fichier) :
    "PeTool - 7.MCAR (1).csv" ou "petool - 7.mcar.csv" remplacent les lignes
    chargees sous "PeTool - 7.MCAR.csv". Un nom sans code reconnu est remplace
    a l'identique (WHERE nom_fichier = nom).

    Un fichier sans ligne de donnees est refuse AVANT tout SQL : il ne purge
    jamais les lignes existantes.

    Une transaction par fichier : commit en fin, rollback sur toute erreur
    (le resultat porte alors status='error'). Ne leve jamais."""
    resultat = {
        'fichier': nom_fichier,
        'status': 'ok',
        'code_fichier': None,
        'organisation_maintenance': None,
        'lignes_supprimees': 0,
        'lignes_inserees': 0,
        'avertissements': [],
    }
    try:
        extension = os.path.splitext(nom_fichier.lower())[1]
        if extension == '.csv':
            parsed = parse_pe_tools_csv(content)
        elif extension in ('.xlsx', '.xlsm'):
            parsed = parse_pe_tools_excel(content)
        else:
            raise ValueError('Extension attendue : .csv, .xlsx ou .xlsm')
        if not parsed.rows:
            raise ValueError('Aucune ligne de données')
        if parsed.missing_columns:
            resultat['avertissements'].append(
                'Colonne(s) absente(s) du fichier (valeurs NULL) : ' + ', '.join(parsed.missing_columns))
        if parsed.unknown_columns:
            resultat['avertissements'].append(
                'Colonne(s) ignorée(s), sans équivalent dans pe_tools : ' + ', '.join(parsed.unknown_columns))
        if parsed.repaired_lines:
            resultat['avertissements'].append(
                f'{parsed.repaired_lines} ligne(s) aux guillemets non fermés réparée(s)')

        cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
        # Verrou consultatif de transaction (libere au commit/rollback) :
        # serialise les imports, dont le DELETE + INSERT d'un meme code de
        # fichier, et le calcul MAX(raw_id) + 1 du repli sans identite.
        # 778812/778813 sont pris par le module maintenance.
        cursor.execute("SELECT pg_advisory_xact_lock(778814)")
        cursor.execute(
            "SELECT public.pe_tools_code_fichier(%s) AS code, public.pe_tools_org_code(%s) AS org",
            [nom_fichier, nom_fichier])
        r = cursor.fetchone()
        resultat['code_fichier'] = r['code']
        resultat['organisation_maintenance'] = r['org']
        if r['org'] is None:
            resultat['avertissements'].append(
                f"Code {r['code'] or '?'} absent de public.pe_tools_organisation : organisation non renseignée")

        if r['code'] is not None:
            cursor.execute(
                "DELETE FROM raw_data.pe_tools WHERE public.pe_tools_code_fichier(nom_fichier) = %s",
                [r['code']])
        else:
            cursor.execute("DELETE FROM raw_data.pe_tools WHERE nom_fichier = %s", [nom_fichier])
        resultat['lignes_supprimees'] = cursor.rowcount

        if parsed.rows:
            # raw_id est une identite GENERATED ALWAYS : la base l'attribue et
            # refuse toute valeur explicite. Le calcul MAX + 1 n'est conserve
            # que pour une table rechargee hors application sans identite.
            raw_id_auto = _raw_id_is_auto(cursor)
            next_id = None
            if not raw_id_auto:
                cursor.execute("SELECT COALESCE(MAX(raw_id), 0) AS max_id FROM raw_data.pe_tools")
                next_id = cursor.fetchone()['max_id'] + 1

            col_sql = [c for c, _ in PE_TOOLS_COLUMNS]
            cols = ([] if raw_id_auto else ['raw_id']) + col_sql \
                + ['nom_fichier', 'organisation_maintenance', 'imported_at']
            audit = _has_audit_columns(cursor)
            if audit:
                cols += ['updated_at', 'updated_by']

            # imported_at / updated_at sont des NOW() litteraux dans le template
            # (pas des parametres) : le tuple ne porte que les valeurs.
            nb_params = len(col_sql) + 2 + (0 if raw_id_auto else 1)
            template = '(' + ', '.join(['%s'] * nb_params) + ', NOW()'
            if audit:
                template += ', NOW(), %s'
            template += ')'

            rows_sql = []
            for i, row in enumerate(parsed.rows):
                t = ([] if raw_id_auto else [next_id + i]) \
                    + [row[c] for c in col_sql] + [nom_fichier, r['org']]
                if audit:
                    t.append(user)
                rows_sql.append(tuple(t))

            psycopg2.extras.execute_values(
                cursor,
                f"INSERT INTO raw_data.pe_tools ({', '.join(cols)}) VALUES %s",
                rows_sql,
                template=template,
                page_size=500,
            )
            resultat['lignes_inserees'] = len(rows_sql)

        conn.commit()
    except Exception as exc:
        try:
            conn.rollback()
        except Exception as rb:
            current_app.logger.error(f"Rollback impossible ({nom_fichier}): {rb}")
        # La suppression a ete annulee avec la transaction.
        resultat['lignes_supprimees'] = 0
        resultat['lignes_inserees'] = 0
        resultat['status'] = 'error'
        resultat['error'] = str(exc)
        current_app.logger.error(f"Import pe_tools {nom_fichier}: {exc}")
    return resultat


@maintenance_pe_tools_blueprint.route('/pe-tools/import', methods=['POST'])
@jwt_required()
def import_pe_tools():
    """Import multi-fichiers des CSV PE Tools (champ multipart `files`).

    Mode "remplacer par fichier" : voir _import_one_file. Un fichier en erreur
    n'annule pas les autres ; la reponse detaille chaque fichier."""
    try:
        fichiers = request.files.getlist('files')
        if not fichiers:
            return jsonify({'success': False, 'error': 'Aucun fichier fourni (champ multipart « files »)'}), 400

        user = _user()
        results = []
        with get_db_connection() as conn:
            cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
            if not _has_import_columns(cursor):
                return jsonify({
                    'success': False,
                    'error': 'Migration 077 non jouée : colonnes nom_fichier / organisation_maintenance absentes',
                }), 503
            for f in fichiers:
                # Certains navigateurs envoient un chemin (C:\fakepath\x.csv) :
                # seul le nom de base sert de cle nom_fichier.
                nom = os.path.basename((f.filename or '').replace('\\', '/')).strip()
                if not nom:
                    continue
                results.append(_import_one_file(conn, nom, f.read(), user))

        if not results:
            return jsonify({'success': False, 'error': 'Aucun fichier fourni'}), 400

        cache_invalidate(CACHE_PREFIX)
        return jsonify({
            'success': any(r['status'] == 'ok' for r in results),
            'results': results,
        }), 200

    except Exception as e:
        current_app.logger.error(f"Erreur import pe_tools: {e}")
        return jsonify({'success': False, 'error': str(e)}), 500


# Date de derniere execution par plan OU poste d'entretien (raw_data.plan_entretien_derniere_exec,
# id_type = PLAN | POSTE depuis la 084 ; ~1 300 lignes, liste complete filtree cote ecran).
# MPLA n'est pas extraite : designation, poste technique, frequence et organisation viennent
# des gammes PE Tools du meme plan (id_type PLAN) ou du meme poste d'entretien (POSTE).
_DERNIERE_EXEC = """
    SELECT p.id_type, p.identifiant, p.manuel,
           p.jour AS date_derniere_execution,
           CURRENT_DATE - p.jour AS jours_depuis,
           t.designation, t.poste_technique, t.frequence, t.organisation_maintenance, t.nb_gammes
    -- Une ligne par identifiant : saisie MANUEL (085) sinon date la plus recente du fichier
    -- (meme regle que pe_tools.date_derniere_execution).
    -- Date importee en texte 'YYYY-MM-DD hh:mm:ss' ; une valeur mal formee sort NULL au lieu de tout casser.
    FROM (SELECT id_type, identifiant,
                 COALESCE(max(jour) FILTER (WHERE source = 'MANUEL'), max(jour)) AS jour,
                 bool_or(source = 'MANUEL') AS manuel
          FROM (SELECT id_type, source, LTRIM(warpl, '0') AS identifiant,
                       CASE WHEN date_derniere_execution ~ '^\\d{4}-\\d{2}-\\d{2}'
                            THEN left(date_derniere_execution, 10)::date END AS jour
                FROM raw_data.plan_entretien_derniere_exec) d
          GROUP BY 1, 2) p
    LEFT JOIN LATERAL (
        SELECT min(x.designation) AS designation, min(x.poste_technique) AS poste_technique,
               min(x.frequence) AS frequence, min(x.organisation_maintenance) AS organisation_maintenance,
               count(*) AS nb_gammes
        FROM raw_data.pe_tools x
        WHERE LTRIM(CASE p.id_type WHEN 'POSTE' THEN x.poste_entretien ELSE x.plan_entretien END, '0')
              = p.identifiant
    ) t ON TRUE
    ORDER BY p.jour NULLS FIRST, 1, 2
"""


@maintenance_pe_tools_blueprint.route('/plans-derniere-execution', methods=['GET'])
@jwt_required()
def list_plans_derniere_execution():
    try:
        with get_db_connection() as conn:
            cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
            cursor.execute(_DERNIERE_EXEC)
            rows = cursor.fetchall()
            for r in rows:
                r['date_derniere_execution'] = r['date_derniere_execution'] and r['date_derniere_execution'].isoformat()
            return jsonify({'success': True, 'data': rows, 'total': len(rows)}), 200
    except Exception as e:
        current_app.logger.error(f"Erreur plans derniere execution: {e}")
        return jsonify({'success': False, 'error': str(e)}), 500


@maintenance_pe_tools_blueprint.route('/plans-derniere-execution/sync', methods=['POST'])
@jwt_required()
def sync_plans_derniere_execution():
    """Recopie la date de derniere execution dans pe_tools (plan, a defaut poste d'entretien : 084).
    Les triggers la tiennent deja a jour ; ce bouton rattrape une ecriture qui les aurait
    contournes (table rechargee hors application, triggers desactives...)."""
    try:
        with get_db_connection() as conn:
            cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
            if not _has_date_exec_column(cursor):
                return jsonify({'success': False,
                                'error': 'Migration 082 non jouée : colonne pe_tools.date_derniere_execution absente'}), 503
            cursor.execute("""
                UPDATE raw_data.pe_tools t
                   SET date_derniere_execution =
                       raw_data.pe_tools_date_derniere_execution(t.plan_entretien, t.poste_entretien)
                 WHERE t.date_derniere_execution IS DISTINCT FROM
                       raw_data.pe_tools_date_derniere_execution(t.plan_entretien, t.poste_entretien)
            """)
            maj = cursor.rowcount
            cursor.execute("SELECT count(date_derniere_execution) AS datees, count(*) AS total FROM raw_data.pe_tools")
            compte = cursor.fetchone()
            conn.commit()
        cache_invalidate(CACHE_PREFIX)
        return jsonify({'success': True, 'lignes_mises_a_jour': maj, **compte}), 200
    except Exception as e:
        current_app.logger.error(f"Erreur synchro date derniere execution pe_tools: {e}")
        return jsonify({'success': False, 'error': str(e)}), 500


def _cle_date_manuelle(cursor, raw_id):
    """(id_type, identifiant) portant la date de la gamme : son plan, a defaut son poste
    d'entretien (meme priorite que raw_data.pe_tools_date_derniere_execution). None si
    la gamme n'existe pas ; (None, None) si elle n'a ni plan ni poste."""
    cursor.execute("""
        SELECT NULLIF(LTRIM(btrim(plan_entretien), '0'), '') AS plan,
               NULLIF(LTRIM(btrim(poste_entretien), '0'), '') AS poste
        FROM raw_data.pe_tools WHERE raw_id = %s
    """, [raw_id])
    row = cursor.fetchone()
    if not row:
        return None
    if row['plan']:
        return 'PLAN', row['plan']
    if row['poste']:
        return 'POSTE', row['poste']
    return None, None


@maintenance_pe_tools_blueprint.route('/pe-tools/<int:raw_id>/date-derniere-execution', methods=['PUT'])
@jwt_required()
def set_date_derniere_execution(raw_id: int):
    """Saisie manuelle de la date de derniere execution d'une gamme (migration 085).

    Body : {"date": "YYYY-MM-DD"} pour saisir, {"date": null} ou "" pour revenir a la
    date du fichier. La saisie est enregistree pour le PLAN de la gamme (a defaut son
    POSTE d'entretien) dans raw_data.plan_entretien_derniere_exec (source MANUEL,
    prioritaire) : elle vaut donc pour toutes les gammes du meme plan, survit aux
    reimports, et les triggers recalculent date_derniere_execution / ifs_date_execution."""
    valeur = ((request.get_json(silent=True) or {}).get('date') or '').strip()
    if valeur:
        try:
            valeur = date.fromisoformat(valeur).isoformat()
        except ValueError:
            return jsonify({'success': False, 'error': f'Date invalide : {valeur} (attendu AAAA-MM-JJ)'}), 400
    try:
        with get_db_connection() as conn:
            cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
            if not _has_column(cursor, 'source', 'plan_entretien_derniere_exec'):
                return jsonify({'success': False,
                                'error': 'Migration 085 non jouée : saisie manuelle indisponible'}), 503
            cle = _cle_date_manuelle(cursor, raw_id)
            if cle is None:
                return jsonify({'success': False, 'error': 'Gamme non trouvée'}), 404
            id_type, identifiant = cle
            if not id_type:
                return jsonify({'success': False, 'error':
                                "Gamme sans plan ni poste d'entretien : la date ne peut pas être rattachée"}), 400

            if valeur:
                cursor.execute("""
                    INSERT INTO raw_data.plan_entretien_derniere_exec
                           (warpl, date_derniere_execution, id_type, source, saisi_par, created_at, updated_at)
                    VALUES (%(id)s, %(date)s || ' 00:00:00', %(type)s, 'MANUEL', %(user)s,
                            CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
                    ON CONFLICT (id_type, (LTRIM(warpl, '0'))) WHERE source = 'MANUEL'
                    DO UPDATE SET date_derniere_execution = EXCLUDED.date_derniere_execution,
                                  saisi_par = EXCLUDED.saisi_par, updated_at = CURRENT_TIMESTAMP
                """, {'id': identifiant, 'date': valeur, 'type': id_type, 'user': _user()})
            else:
                cursor.execute("""
                    DELETE FROM raw_data.plan_entretien_derniere_exec
                     WHERE source = 'MANUEL' AND id_type = %s AND LTRIM(warpl, '0') = %s
                """, [id_type, identifiant])

            cursor.execute("""
                SELECT date_derniere_execution::text AS date_derniere_execution,
                       ifs_date_execution::text AS ifs_date_execution
                FROM raw_data.pe_tools WHERE raw_id = %s
            """, [raw_id])
            resultat = cursor.fetchone()
            cursor.execute(f"""
                SELECT count(*) AS nb FROM raw_data.pe_tools
                WHERE LTRIM(btrim({'plan_entretien' if id_type == 'PLAN' else 'poste_entretien'}), '0') = %s
            """, [identifiant])
            nb_gammes = cursor.fetchone()['nb']
            conn.commit()
        cache_invalidate(CACHE_PREFIX)
        return jsonify({'success': True, **resultat, 'id_type': id_type, 'identifiant': identifiant,
                        'saisie_manuelle': bool(valeur), 'nb_gammes': nb_gammes}), 200
    except Exception as e:
        current_app.logger.error(f"Erreur saisie date derniere execution {raw_id}: {e}")
        return jsonify({'success': False, 'error': str(e)}), 500
