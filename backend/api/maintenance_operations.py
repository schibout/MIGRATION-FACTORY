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


# Detail d'un ordre (ecran type IW33) : un bloc par onglet. Lecture seule.
_ENTETE = """
    SELECT LTRIM(a.aufnr, '0') AS ordre, a.auart AS type_ordre, a.ktext AS texte_ordre,
           a.objnr, h.obknr,
           -- Donn.en-t.
           h.priok AS priorite, pt.priokx AS priorite_texte,
           h.ilart AS type_activite, it.ilatx AS type_activite_texte, h.iwerk AS division_planif,
           h.ingpr AS groupe_planif, cr.arbpl AS poste_responsable, cr.werks AS poste_responsable_division,
           crt.ktext AS poste_responsable_texte, h.qmnum AS avis, h.revnr AS revision,
           LTRIM(h.bautl, '0') AS sous_ensemble,
           -- Planific.
           h.warpl AS plan_entretien, NULLIF(LTRIM(h.abnum, '0'), '') AS numero_appel, h.wapos AS poste_entretien,
           LTRIM(h.laufn, '0') AS dernier_ordre, k.plnty AS type_gamme, k.plnnr AS groupe_gammes,
           k.plnal AS compteur_groupe_gammes,
           -- Pilotage
           a.ernam AS cree_par, NULLIF(a.erdat, '00000000') AS cree_le,
           a.aenam AS modifie_par, NULLIF(a.aedat, '00000000') AS modifie_le,
           h.plknz AS code_planification, a.kalsm AS schema_calcul,
           k.klvarp AS variante_calcul_budget, k.klvari AS variante_couts_reels,
           NULLIF(k.gstrp, '00000000') AS debut_planifie, NULLIF(k.gltrp, '00000000') AS fin_planifiee,
           l.tplnr AS poste_technique, ft.pltxt AS poste_technique_texte,
           LTRIM(h.equnr, '0') AS equipement, et.eqktx AS equipement_texte
    FROM raw_data.aufk a
    LEFT JOIN raw_data.afih h ON h.mandt = a.mandt AND h.aufnr = a.aufnr
    LEFT JOIN raw_data.afko k ON k.mandt = a.mandt AND k.aufnr = a.aufnr
    LEFT JOIN raw_data.iloa l ON l.mandt = h.mandt AND l.iloan = h.iloan
    LEFT JOIN raw_data.crhd cr ON cr.mandt = h.mandt AND cr.objid = h.gewrk AND cr.objty = 'A'
    LEFT JOIN LATERAL (SELECT ktext FROM raw_data.crtx x WHERE x.mandt = cr.mandt AND x.objty = 'A'
                        AND x.objid = cr.objid ORDER BY (x.spras = 'F') DESC LIMIT 1) crt ON TRUE
    LEFT JOIN LATERAL (SELECT priokx FROM raw_data.t356_t x WHERE x.mandt = h.mandt AND x.artpr = h.artpr
                        AND x.priok = h.priok ORDER BY (x.spras = 'F') DESC LIMIT 1) pt ON TRUE
    LEFT JOIN LATERAL (SELECT ilatx FROM raw_data.t353i_t x WHERE x.mandt = h.mandt AND x.ilart = h.ilart
                        ORDER BY (x.spras = 'F') DESC LIMIT 1) it ON TRUE
    LEFT JOIN LATERAL (SELECT pltxt FROM raw_data.iflotx x WHERE x.mandt = l.mandt AND x.tplnr = l.tplnr
                        ORDER BY (x.spras = 'F') DESC LIMIT 1) ft ON TRUE
    LEFT JOIN LATERAL (SELECT eqktx FROM raw_data.eqkt x WHERE x.mandt = h.mandt AND x.equnr = h.equnr
                        ORDER BY (x.spras = 'F') DESC LIMIT 1) et ON TRUE
    WHERE a.aufnr = %(aufnr)s
    LIMIT 1
"""

_DONNEES_SUP = """
    SELECT a.bukrs AS societe, (SELECT butxt FROM raw_data.t001 t WHERE t.mandt = a.mandt AND t.bukrs = a.bukrs LIMIT 1) AS societe_texte,
           a.gsber AS domaine_activite, (SELECT gtext FROM raw_data.tgsbt t WHERE t.mandt = a.mandt AND t.gsber = a.gsber
                                          ORDER BY (t.spras = 'F') DESC LIMIT 1) AS domaine_activite_texte,
           a.kokrs AS perimetre_analytique,
           a.kostv AS centre_responsable, (SELECT ktext FROM raw_data.cskt t WHERE t.mandt = a.mandt AND t.kokrs = a.kokrs
                                            AND t.kostl = a.kostv ORDER BY (t.spras = 'F') DESC, t.datbi DESC LIMIT 1) AS centre_responsable_texte,
           LTRIM(a.prctr, '0') AS centre_profit, (SELECT ktext FROM raw_data.cepct t WHERE t.mandt = a.mandt AND t.kokrs = a.kokrs
                                                   AND t.prctr = a.prctr ORDER BY (t.spras = 'F') DESC, t.datbi DESC LIMIT 1) AS centre_profit_texte,
           a.func_area AS domaine_fonctionnel, a.abkrs AS groupe_traitement, NULLIF(a.pspel, '00000000') AS element_otp
    FROM raw_data.aufk a
    WHERE a.aufnr = %(aufnr)s
    LIMIT 1
"""

_LOCALISATION = """
    SELECT l.swerk AS division_localisation, w.name1 AS division_localisation_texte,
           l.stort AS emplacement, l.msgrp AS local, l.beber AS secteur_exploitation,
           l.abckz AS code_abc, l.eqfnr AS zone_tri, l.bukrs AS societe, l.gsber AS domaine_activite,
           l.kostl AS centre_couts
    FROM raw_data.afih h
    JOIN raw_data.iloa l ON l.mandt = h.mandt AND l.iloan = h.iloan
    LEFT JOIN raw_data.t001w w ON w.mandt = l.mandt AND w.werks = l.swerk
    WHERE h.aufnr = %(aufnr)s
    LIMIT 1
"""

# Liste d'objets (OBJK, cle AFIH.OBKNR).
_OBJETS = """
    SELECT o.sortf AS tri, LTRIM(o.matnr, '0') AS article,
           (SELECT maktx FROM raw_data.makt m WHERE m.mandt = o.mandt AND m.matnr = o.matnr
             ORDER BY (m.spras = 'F') DESC LIMIT 1) AS designation_article,
           LTRIM(o.equnr, '0') AS equipement,
           (SELECT eqktx FROM raw_data.eqkt x WHERE x.mandt = o.mandt AND x.equnr = o.equnr
             ORDER BY (x.spras = 'F') DESC LIMIT 1) AS designation_equipement,
           l.tplnr AS poste_technique,
           (SELECT pltxt FROM raw_data.iflotx x WHERE x.mandt = l.mandt AND x.tplnr = l.tplnr
             ORDER BY (x.spras = 'F') DESC LIMIT 1) AS designation_poste_technique,
           o.sernr AS numero_serie, LTRIM(o.ihnum, '0') AS avis
    FROM raw_data.objk o
    LEFT JOIN raw_data.iloa l ON l.mandt = o.mandt AND l.iloan = o.iloan
    WHERE o.obknr = %(obknr)s
    ORDER BY o.obzae
"""

# Couts de l'ordre par categorie de valeurs (PMCO, ecran Couts d'IW33) :
# plan = type de valeur 01, reel = 04 ; periodes 0 a 16 cumulees.
# ponytail: correspondance WRTTP -> colonnes SAP (estimes / pre-budget / reels) a
# confirmer sur des donnees PMCO reelles ; le libelle de categorie (ACPOS) reste en code.
_COUTS = """
    SELECT c.acpos AS categorie, c.cocur AS devise,
           SUM(CASE WHEN c.wrttp = '01' THEN t.montant ELSE 0 END) AS couts_planifies,
           SUM(CASE WHEN c.wrttp = '04' THEN t.montant ELSE 0 END) AS couts_reels
    FROM raw_data.pmco c
    CROSS JOIN LATERAL (SELECT SUM(COALESCE(NULLIF(trim(v), ''), '0')::numeric) AS montant
                        FROM unnest(ARRAY[c.wrt00, c.wrt01, c.wrt02, c.wrt03, c.wrt04, c.wrt05, c.wrt06,
                                          c.wrt07, c.wrt08, c.wrt09, c.wrt10, c.wrt11, c.wrt12,
                                          c.wrt13, c.wrt14, c.wrt15, c.wrt16]::text[]) v) t
    WHERE c.objnr = %(objnr)s AND c.wrttp IN ('01', '04')
    GROUP BY c.acpos, c.cocur
    ORDER BY c.acpos
"""

_OPERATIONS = """
    SELECT v.vornr AS operation, v.ltxa1 AS texte_operation, c.arbpl AS poste_travail, v.werks AS division,
           v.steus AS cle_commande, vv.arbei AS travail, vv.arbeh AS unite_travail,
           v.anzzl AS nombre, vv.dauno AS duree, vv.daune AS unite_duree
    FROM raw_data.afko k
    JOIN raw_data.afvc v ON v.mandt = k.mandt AND v.aufpl = k.aufpl
    LEFT JOIN raw_data.crhd c ON c.mandt = v.mandt AND c.objid = v.arbid AND c.objty = 'A'
    LEFT JOIN raw_data.afvv vv ON vv.mandt = v.mandt AND vv.aufpl = v.aufpl AND vv.aplzl = v.aplzl
    WHERE k.aufnr = %(aufnr)s
    ORDER BY v.vornr
"""

_COMPOSANTS = """
    SELECT r.posnr AS poste, LTRIM(r.matnr, '0') AS article,
           (SELECT maktx FROM raw_data.makt m WHERE m.mandt = r.mandt AND m.matnr = r.matnr
             ORDER BY (m.spras = 'F') DESC LIMIT 1) AS designation,
           r.bdmng AS quantite, r.meins AS unite, r.postp AS type_poste, r.vornr AS operation,
           r.werks AS division, r.lgort AS magasin, NULLIF(r.bdter, '00000000') AS date_besoin
    FROM raw_data.resb r
    WHERE r.aufnr = %(aufnr)s AND (r.xloek IS NULL OR r.xloek = '')
    ORDER BY r.posnr, r.rspos
"""


@maintenance_operations_blueprint.route('/orders/<ordre>', methods=['GET'])
@jwt_required()
def get_order(ordre):
    ordre = (ordre or '').strip()
    # AUFNR SAP : 12 caracteres, numeriques completes par des zeros.
    aufnr = ordre.zfill(12) if ordre.isdigit() else ordre
    params = {'aufnr': aufnr}
    try:
        with get_db_connection() as conn:
            cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
            cursor.execute(_ENTETE, params)
            entete = cursor.fetchone()
            if not entete:
                return jsonify({'success': False, 'error': f'Ordre {ordre} introuvable'}), 404

            # Statuts systeme actifs ; libelle via TJ02T quand elle est extraite, sinon le code brut.
            objnr, obknr = entete.pop('objnr'), entete.pop('obknr')
            cursor.execute("SELECT to_regclass('raw_data.tj02t') IS NOT NULL AS ok")
            libelles = cursor.fetchone()['ok']
            cursor.execute(f"""
                SELECT {"COALESCE((SELECT t.txt04 FROM raw_data.tj02t t WHERE t.istat = j.stat ORDER BY (t.spras = 'F') DESC LIMIT 1), j.stat)"
                        if libelles else "j.stat"} AS statut
                FROM raw_data.jest j
                WHERE j.objnr = %(objnr)s AND j.stat LIKE 'I%%' AND (j.inact IS NULL OR trim(j.inact) <> 'X')
                ORDER BY j.stat
            """, {'objnr': objnr})
            entete['statuts_systeme'] = [r['statut'] for r in cursor.fetchall()]

            cursor.execute(_DONNEES_SUP, params)
            donnees_sup = cursor.fetchone()
            cursor.execute(_LOCALISATION, params)
            localisation = cursor.fetchone()
            cursor.execute(_OPERATIONS, params)
            operations = cursor.fetchall()
            cursor.execute(_COMPOSANTS, params)
            composants = cursor.fetchall()
            objets = []
            if obknr and obknr.strip('0'):
                cursor.execute(_OBJETS, {'obknr': obknr})
                objets = cursor.fetchall()
            cursor.execute(_COUTS, {'objnr': objnr})
            couts = cursor.fetchall()
            return jsonify({'success': True, 'data': {
                'entete': entete, 'donnees_sup': donnees_sup, 'localisation': localisation,
                'operations': operations, 'composants': composants, 'objets': objets, 'couts': couts,
            }}), 200
    except Exception as e:
        current_app.logger.error(f"Erreur detail ordre {ordre}: {e}")
        return jsonify({'success': False, 'error': str(e)}), 500
