"""
Liste des operations SAP -- blueprint /api/v1/maintenance/operations.

Meme perimetre que le module ETL Operations : operations (AFVC) des ordres
SAP NON clos (anti-jointure sur clean_data.v_sap_ordre_clos), en-tete d'ordre
AFKO obligatoire. ~6 000 lignes : renvoyees en une fois, filtrage et tri cote
ecran. Lecture seule sur raw_data.
"""
import psycopg2.extras
from flask import Blueprint, current_app, jsonify
from flask_jwt_extended import jwt_required

from config.database import get_db_connection

maintenance_operations_blueprint = Blueprint('maintenance_operations', __name__)


@maintenance_operations_blueprint.route('/operations', methods=['GET'])
@jwt_required()
def list_operations():
    try:
        with get_db_connection() as conn:
            cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
            # Le JIT coute ~7 s de compilation sur cette requete pour rien.
            cursor.execute("SET LOCAL jit = off")
            cursor.execute("""
                SELECT LTRIM(k.aufnr, '0')         AS ordre,
                       a.auart                     AS type_ordre,
                       a.ktext                     AS texte_ordre,
                       v.vornr                     AS operation,
                       v.ltxa1                     AS texte_operation,
                       v.werks                     AS division,
                       c.arbpl                     AS poste_travail,
                       l.tplnr                     AS poste_technique,
                       LTRIM(h.equnr, '0')         AS equipement,
                       NULLIF(k.gstrp, '00000000') AS debut_planifie,
                       NULLIF(k.gltrp, '00000000') AS fin_planifiee,
                       vv.arbei                    AS travail,
                       vv.arbeh                    AS unite_travail
                FROM raw_data.afvc v
                JOIN raw_data.afko k ON k.mandt = v.mandt AND k.aufpl = v.aufpl
                LEFT JOIN raw_data.aufk a ON a.mandt = k.mandt AND a.aufnr = k.aufnr
                LEFT JOIN raw_data.afih h ON h.mandt = k.mandt AND h.aufnr = k.aufnr
                LEFT JOIN raw_data.iloa l ON l.mandt = h.mandt AND l.iloan = h.iloan
                LEFT JOIN raw_data.crhd c ON c.mandt = v.mandt AND c.objid = v.arbid AND c.objty = 'A'
                LEFT JOIN raw_data.afvv vv ON vv.mandt = v.mandt AND vv.aufpl = v.aufpl AND vv.aplzl = v.aplzl
                WHERE NOT EXISTS (SELECT 1 FROM clean_data.v_sap_ordre_clos o
                                   WHERE o.mandt = k.mandt AND o.aufnr = k.aufnr)
                ORDER BY k.aufnr, v.vornr
            """)
            rows = cursor.fetchall()
            return jsonify({'success': True, 'data': rows, 'total': len(rows)}), 200
    except Exception as e:
        current_app.logger.error(f"Erreur liste des operations: {e}")
        return jsonify({'success': False, 'error': str(e)}), 500
