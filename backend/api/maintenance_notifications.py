"""
Avis de maintenance SAP -- blueprint /api/v1/maintenance/notifications.

Meme principe que l'ecran Operations : ecran de selection type IW29 filtre cote
serveur (periode, division, type, poste technique, numero) sur les SEULS avis
en cours, au plus
MAX_LIGNES lignes, puis filtres/tri cote ecran. Detail type IW23 (QMEL + QMIH,
postes QMFE, causes QMUR, mesures QMSM, actions QMMA). Lecture seule sur raw_data.
« En cours » = avis sans statut actif ACLO (I0072) ni TSUP (I0076).
"""
import re

import psycopg2.extras
from flask import Blueprint, current_app, jsonify, request
from flask_jwt_extended import jwt_required

from config.database import get_db_connection

maintenance_notifications_blueprint = Blueprint('maintenance_notifications', __name__)

MAX_LIGNES = 10000

# Statut principal affiche : le premier statut actif dans cet ordre.
_STATUTS_AVIS = ['I0076', 'I0072', 'I0070', 'I0068']

_LISTE = """
    SELECT x.*,
           (SELECT j.stat
              FROM raw_data.jest j
             WHERE j.mandt = x.mandt AND j.objnr = x.objnr AND j.stat = ANY(%(statuts)s)
               AND (j.inact IS NULL OR trim(j.inact) <> 'X')
             ORDER BY array_position(%(statuts)s::text[], j.stat::text) LIMIT 1) AS statut
    FROM (
        SELECT q.mandt, q.objnr,
               LTRIM(q.qmnum, '0')          AS avis,
               q.qmart                      AS type_avis,
               q.qmtxt                      AS texte,
               h.iwerk                      AS division,
               l.tplnr                      AS poste_technique,
               LTRIM(h.equnr, '0')          AS equipement,
               c.arbpl                      AS poste_responsable,
               q.priok                      AS priorite,
               NULLIF(q.qmdat, '00000000')  AS date_avis,
               NULLIF(q.strmn, '00000000')  AS debut_souhaite,
               NULLIF(q.ltrmn, '00000000')  AS fin_souhaitee,
               NULLIF(LTRIM(q.aufnr, '0'), '') AS ordre,
               q.qmnam                      AS auteur
        FROM raw_data.qmel q
        LEFT JOIN raw_data.qmih h ON h.mandt = q.mandt AND h.qmnum = q.qmnum
        LEFT JOIN raw_data.iloa l ON l.mandt = h.mandt AND l.iloan = h.iloan
        LEFT JOIN raw_data.crhd c ON c.mandt = q.mandt AND c.objid = q.arbpl AND c.objty = 'A'
        WHERE {where}
        ORDER BY q.qmnum DESC
        LIMIT %(limite)s
    ) x
"""

_CLOS = """EXISTS (SELECT 1 FROM raw_data.jest jc WHERE jc.mandt = q.mandt AND jc.objnr = q.objnr
           AND jc.stat IN ('I0072', 'I0076') AND (jc.inact IS NULL OR trim(jc.inact) <> 'X'))"""


def _date_sap(valeur):
    """'2026-01-31' (champ date HTML) -> '20260131' ; None si vide ou invalide."""
    valeur = (valeur or '').strip()
    return valeur.replace('-', '') if re.fullmatch(r'\d{4}-\d{2}-\d{2}', valeur) else None


def _qmnum(avis):
    """QMNUM SAP : 12 caracteres, numeriques completes par des zeros."""
    avis = (avis or '').strip()
    return avis.zfill(12) if avis.isdigit() else avis


@maintenance_notifications_blueprint.route('/notifications', methods=['GET'])
@jwt_required()
def list_notifications():
    args = request.args
    # Avis en cours uniquement (demande explicite) : les clotures ne sont jamais servis.
    where, params = ['NOT ' + _CLOS], {'statuts': _STATUTS_AVIS, 'limite': MAX_LIGNES + 1}
    # Dates SAP en texte YYYYMMDD : comparaison texte = comparaison chronologique.
    if _date_sap(args.get('date_debut')):
        where.append('q.qmdat >= %(date_debut)s')
        params['date_debut'] = _date_sap(args.get('date_debut'))
    if _date_sap(args.get('date_fin')):
        where.append("q.qmdat <= %(date_fin)s AND q.qmdat <> '00000000'")
        params['date_fin'] = _date_sap(args.get('date_fin'))
    for champ, colonne in (('division', 'h.iwerk'), ('type_avis', 'q.qmart'), ('poste_responsable', 'c.arbpl')):
        if (args.get(champ) or '').strip():
            where.append(f'{colonne} = %({champ})s')
            params[champ] = args[champ].strip()
    if (args.get('poste_technique') or '').strip():
        # Poste et toute sa descendance (le code SAP est hierarchique).
        where.append('l.tplnr LIKE %(poste_technique)s')
        params['poste_technique'] = args['poste_technique'].strip().replace('%', '') + '%'
    if (args.get('avis') or '').strip():
        where.append('q.qmnum = %(avis)s')
        params['avis'] = _qmnum(args['avis'])

    try:
        with get_db_connection() as conn:
            cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
            cursor.execute("SET LOCAL jit = off")
            # Meme piege que les operations : sans cela l'anti-jointure sur ~480 000 avis
            # clos part en jointure par fusion (tris texte en collation francaise, ~11 s).
            cursor.execute("SET LOCAL work_mem = '256MB'")
            cursor.execute("SET LOCAL enable_mergejoin = off")
            cursor.execute(_LISTE.format(where=' AND '.join(where)), params)
            rows = cursor.fetchall()
            cursor.execute("SELECT istat, txt04 FROM raw_data.tj02t WHERE spras = 'F'")
            libelles = {r['istat']: r['txt04'] for r in cursor.fetchall()}
            tronque = len(rows) > MAX_LIGNES
            rows = rows[:MAX_LIGNES]
            for r in rows:
                del r['mandt'], r['objnr']
                r['statut'] = libelles.get(r['statut'], r['statut'])
            return jsonify({'success': True, 'data': rows, 'total': len(rows),
                            'tronque': tronque, 'max': MAX_LIGNES}), 200
    except Exception as e:
        current_app.logger.error(f"Erreur liste des avis: {e}")
        return jsonify({'success': False, 'error': str(e)}), 500


@maintenance_notifications_blueprint.route('/notifications/choix', methods=['GET'])
@jwt_required()
def notification_choices():
    """Valeurs proposees par les listes de l'ecran de selection."""
    try:
        with get_db_connection() as conn:
            cursor = conn.cursor()
            cursor.execute("SELECT DISTINCT iwerk FROM raw_data.qmih WHERE iwerk <> '' ORDER BY 1")
            divisions = [r[0] for r in cursor.fetchall()]
            cursor.execute("SELECT DISTINCT qmart FROM raw_data.qmel WHERE qmart <> '' ORDER BY 1")
            types = [r[0] for r in cursor.fetchall()]
            cursor.execute("SELECT DISTINCT arbpl FROM raw_data.crhd WHERE objty = 'A' AND arbpl <> '' ORDER BY 1")
            postes = [r[0] for r in cursor.fetchall()]
            return jsonify({'success': True, 'data': {
                'divisions': divisions, 'types_avis': types, 'postes_responsables': postes}}), 200
    except Exception as e:
        current_app.logger.error(f"Erreur choix avis: {e}")
        return jsonify({'success': False, 'error': str(e)}), 500


# Detail d'un avis (ecran type IW23). Codes de catalogue (groupe/code) bruts : QPCT n'est pas extraite.
_ENTETE = """
    SELECT LTRIM(q.qmnum, '0') AS avis, q.qmart AS type_avis, q.qmtxt AS texte, q.objnr,
           q.priok AS priorite, pt.priokx AS priorite_texte,
           q.qmnam AS auteur, NULLIF(q.qmdat, '00000000') AS date_avis, q.mzeit AS heure_avis,
           NULLIF(q.strmn, '00000000') AS debut_souhaite, NULLIF(q.ltrmn, '00000000') AS fin_souhaitee,
           NULLIF(LTRIM(q.aufnr, '0'), '') AS ordre,
           q.qmkat AS catalogue, q.qmgrp AS groupe_codes, q.qmcod AS code,
           q.ernam AS cree_par, NULLIF(q.erdat, '00000000') AS cree_le,
           q.aenam AS modifie_par, NULLIF(q.aedat, '00000000') AS modifie_le,
           c.arbpl AS poste_responsable, q.arbplwerk AS poste_responsable_division,
           h.iwerk AS division_planif, h.ingrp AS groupe_planif,
           l.tplnr AS poste_technique, ft.pltxt AS poste_technique_texte,
           LTRIM(h.equnr, '0') AS equipement, et.eqktx AS equipement_texte,
           LTRIM(h.bautl, '0') AS sous_ensemble,
           h.msaus AS arret, NULLIF(h.ausvn, '00000000') AS debut_panne, h.auztv AS heure_debut_panne,
           NULLIF(h.ausbs, '00000000') AS fin_panne, h.auztb AS heure_fin_panne,
           h.auszt AS duree_panne, h.maueh AS unite_duree_panne,
           h.warpl AS plan_entretien, NULLIF(LTRIM(h.abnum, '0'), '') AS numero_appel, h.wapos AS poste_entretien
    FROM raw_data.qmel q
    LEFT JOIN raw_data.qmih h ON h.mandt = q.mandt AND h.qmnum = q.qmnum
    LEFT JOIN raw_data.iloa l ON l.mandt = h.mandt AND l.iloan = h.iloan
    LEFT JOIN raw_data.crhd c ON c.mandt = q.mandt AND c.objid = q.arbpl AND c.objty = 'A'
    LEFT JOIN LATERAL (SELECT priokx FROM raw_data.t356_t x WHERE x.mandt = q.mandt AND x.artpr = q.artpr
                        AND x.priok = q.priok ORDER BY (x.spras = 'F') DESC LIMIT 1) pt ON TRUE
    LEFT JOIN LATERAL (SELECT pltxt FROM raw_data.iflotx x WHERE x.mandt = l.mandt AND x.tplnr = l.tplnr
                        ORDER BY (x.spras = 'F') DESC LIMIT 1) ft ON TRUE
    LEFT JOIN LATERAL (SELECT eqktx FROM raw_data.eqkt x WHERE x.mandt = h.mandt AND x.equnr = h.equnr
                        ORDER BY (x.spras = 'F') DESC LIMIT 1) et ON TRUE
    WHERE q.qmnum = %(qmnum)s
    LIMIT 1
"""

_POSTES = """
    SELECT fenum AS poste, fetxt AS texte, otgrp AS groupe_partie_objet, oteil AS partie_objet,
           fegrp AS groupe_dommage, fecod AS dommage, LTRIM(bautl, '0') AS sous_ensemble
    FROM raw_data.qmfe
    WHERE qmnum = %(qmnum)s AND (kzloesch IS NULL OR kzloesch = '')
    ORDER BY fenum
"""

_CAUSES = """
    SELECT fenum AS poste, urnum AS cause, urtxt AS texte, urgrp AS groupe_codes, urcod AS code
    FROM raw_data.qmur
    WHERE qmnum = %(qmnum)s AND (kzloesch IS NULL OR kzloesch = '')
    ORDER BY fenum, urnum
"""

_MESURES = """
    SELECT manum AS mesure, matxt AS texte, mngrp AS groupe_codes, mncod AS code, parnr AS responsable,
           NULLIF(pster, '00000000') AS debut_planifie, NULLIF(peter, '00000000') AS fin_planifiee,
           NULLIF(erldat, '00000000') AS terminee_le, erlnam AS terminee_par
    FROM raw_data.qmsm
    WHERE qmnum = %(qmnum)s AND (kzloesch IS NULL OR kzloesch = '')
    ORDER BY manum
"""

_ACTIONS = """
    SELECT manum AS action, matxt AS texte, mngrp AS groupe_codes, mncod AS code,
           NULLIF(pster, '00000000') AS debut, NULLIF(peter, '00000000') AS fin, ernam AS cree_par
    FROM raw_data.qmma
    WHERE qmnum = %(qmnum)s AND (kzloesch IS NULL OR kzloesch = '')
    ORDER BY manum
"""


@maintenance_notifications_blueprint.route('/notifications/<avis>', methods=['GET'])
@jwt_required()
def get_notification(avis):
    params = {'qmnum': _qmnum(avis)}
    try:
        with get_db_connection() as conn:
            cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
            cursor.execute(_ENTETE, params)
            entete = cursor.fetchone()
            if not entete:
                return jsonify({'success': False, 'error': f'Avis {avis} introuvable'}), 404

            cursor.execute("""
                SELECT COALESCE((SELECT t.txt04 FROM raw_data.tj02t t WHERE t.istat = j.stat
                                  ORDER BY (t.spras = 'F') DESC LIMIT 1), j.stat) AS statut
                FROM raw_data.jest j
                WHERE j.objnr = %(objnr)s AND j.stat LIKE 'I%%' AND (j.inact IS NULL OR trim(j.inact) <> 'X')
                ORDER BY j.stat
            """, {'objnr': entete.pop('objnr')})
            entete['statuts_systeme'] = [r['statut'] for r in cursor.fetchall()]

            blocs = {}
            for cle, sql in (('postes', _POSTES), ('causes', _CAUSES), ('mesures', _MESURES), ('actions', _ACTIONS)):
                cursor.execute(sql, params)
                blocs[cle] = cursor.fetchall()
            return jsonify({'success': True, 'data': {'entete': entete, **blocs}}), 200
    except Exception as e:
        current_app.logger.error(f"Erreur detail avis {avis}: {e}")
        return jsonify({'success': False, 'error': str(e)}), 500
