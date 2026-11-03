"""Menu Finance : ecrans Immobilisations (clean_data.immobilisation),
Commandes d'achat (clean_data.commande_achat_ifs) et Comptes (conversion des
comptes PCG SAP -> IFS, transcodification FA_ACCOUNT).

Pour chaque ecran <e> = immobilisations | commandes-achat :
  GET  /api/v1/finance/<e>              liste paginee + filtres + stats + definitions de colonnes
  GET  /api/v1/finance/<e>/export.xlsx  classeur Excel (memes filtres que la liste)
  POST /api/v1/finance/<e>/sync         rechargement de la table clean_data ; corps
                                         {"source": "sap"} (defaut : re-extraction SAP
                                         puis rechargement) ou {"source": "mf"}
                                         (rechargement seul depuis raw_data : applique
                                         les transcodifications / valeurs par defaut)
  GET  /api/v1/finance/<e>/sync         etat de la derniere synchronisation
Immobilisations :
  ?vue=immobilisations (defaut)         les 60 colonnes du fichier livre, toutes les fiches
  ?vue=travail                          onglet « Travail » du classeur metier : fiches a
                                         reprendre, date de sortie effacee, tri par date
                                         d'acquisition, OBJECT_GROUP_ID, comptes / site IFS, OTP
  GET  /api/v1/finance/immobilisations/synthese  KPI + sous-totaux, memes filtres
Commandes d'achat :
  GET  /api/v1/finance/commandes-achat/ifs/<table>  onglets IFS purchase_order /
                                         purchase_order_line_part / _line_nopart
                                         (export.xlsx?vue=<table> pour le classeur) ;
                                         /sync enchaine alimenter_purchase_order()
Historique des couts par projet (clean_data.historique_cout_projet, RPSCO) :
  GET  /api/v1/finance/historique-couts  ?vue=projet (defaut, une ligne par projet /
                                         annee / periode) | otp (par element d'OTP) ;
                                         filtres search, annee_debut, annee_fin ;
                                         reel_cumule = cumul depuis le debut de l'historique
  GET  /api/v1/finance/historique-couts/export.xlsx
  GET|POST /api/v1/finance/historique-couts/sync   (RPSCO, PRPS, PROJ)
  GET  /api/v1/finance/historique-couts/reprise?date_arrete=AAAA-MM-JJ (fin de mois)
                                         OD de reprise IFS par OTP a migrer + anomalies
  PUT  .../reprise/nature/<otp>          {nature: CAPEX|OPEX|null} (OTP sans suffixe IM/EX)
  PUT  .../reprise/projet/<n° projet>    {project_id_ifs, activity_seq_capex, activity_seq_opex}
  GET  .../reprise/export.xlsx           fichier OD, 409 tant qu'il reste une anomalie
  GET  /api/v1/finance/comptes          conversion des comptes (FA_ACCOUNT) + comptes des fiches
Fournisseurs (clean_data.ifs_fournisseurs_perimetre : fichier + crees dans SAP apres l'arrete) :
  GET  /api/v1/finance/fournisseurs     filtres search, source (FICHIER | SAP_NOUVEAU)
  GET  /api/v1/finance/fournisseurs/export.xlsx
  GET|POST /api/v1/finance/fournisseurs/sync   corps {source, date_arrete} (LFA1, LFB1,
                                         LFM1, LFBK, TIBAN, BNKA)
Articles (clean_data.article_perimetre : article_sap, SAP_NOUVEAU = crees apres l'arrete) :
  GET  /api/v1/finance/articles          filtres search, source ; colonnes de v_article_sap
  GET  /api/v1/finance/articles/export.xlsx
  GET|POST /api/v1/finance/articles/sync      corps {source, date_arrete}
  POST /api/v1/finance/articles/import/suggest-mapping|validate-mapping|execute
                                         import du fichier valide, formats de l'import generique
"""
import io
import json
import logging
import os
import re
import tempfile
import threading
import time
from datetime import date, datetime, timedelta
from decimal import Decimal

from flask import Blueprint, current_app, jsonify, request, send_file
from flask_jwt_extended import get_jwt_identity, jwt_required
from sqlalchemy import text

from models import db

finance_blueprint = Blueprint('finance', __name__)
logger = logging.getLogger(__name__)

# Tables lues par clean_data.alimenter_immobilisation
# (sql/immobilisation/02_alimenter_immobilisation.sql).
# Uniquement des tables transparentes : une vue SAP s'extrait vide.
# ANLP : date d'arrete (derniere periode d'amortissement comptabilisee).
IMMO_SAP_TABLES = ['ANLA', 'ANLB', 'ANLC', 'ANLZ', 'ANKT', 'T001', 'T095', 'T095T',
                   'T090NAT', 'CSKT', 'TGSBT', 'PRPS', 'PROJ', 'ANLP']

EXTRACTION_TIMEOUT_SECONDS = 3600
EXTRACTION_POLL_SECONDS = 10


# gunicorn -w4 : l'etat est publie dans un fichier partage par les workers du
# conteneur (meme principe que api/etl.py).
# ponytail: un fichier par ecran = une seule synchro a la fois par ecran ; perdu au
# redeploiement (le bouton redevient simplement disponible).
def _status_file(key):
    return os.path.join(tempfile.gettempdir(), f'{key}_sync.json')


# (colonne, libelle de l'extraction transmise aux metiers) : en-tetes de l'onglet
# « Immobilisations » du classeur, repris tels quels dans l'ecran et l'Excel.
LIBELLES = [
    ('societe_sap', 'Société SAP (ANLA-BUKRS)'),
    ('num_immobilisation', 'Numéro immobilisation (ANLA-ANLN1)'),
    ('sous_numero', 'Sous-numéro immobilisation (ANLA-ANLN2)'),
    ('cle_immobilisation', 'Clé immobilisation (ANLA-BUKRS/ANLN1/ANLN2)'),
    ('libelle', 'Libellé immobilisation (ANLA-TXT50)'),
    ('libelle_complementaire', 'Libellé immobilisation complémentaire (ANLA-TXA50)'),
    ('classe_immo', 'Classe immobilisation (ANLA-ANLKL)'),
    ('famille_immo', 'Famille immobilisation (ANKT)'),
    ('indicateur_suppression', 'Indicateur suppression (ANLA-XLOEV)'),
    ('numero_serie', 'Numéro de série (ANLA-SERNR)'),
    ('pays', 'Pays (ANLA-LAND1)'),
    ('groupe_evaluation_1', 'Groupe évaluation 1 (ANLA-ORD41)'),
    ('groupe_evaluation_2', 'Groupe évaluation 2 (ANLA-ORD42)'),
    ('groupe_evaluation_3', 'Groupe évaluation 3 (ANLA-ORD43)'),
    ('groupe_evaluation_4', 'Groupe évaluation 4 (ANLA-ORD44)'),
    ('projet', 'Projet (ANLA-PROJN)'),
    ('cle_comptes_immo', 'Clé détermination comptes immo SAP (ANLA-KTOGR)'),
    ('libelle_cle_comptes_immo', 'Libellé clé comptable immo SAP (T095T-KTGRTX)'),
    ('compte_immobilisation', 'Compte immobilisation SAP (T095-KTANSW, AFABE 02)'),
    ('compte_amort_cumule', 'Compte amortissement cumulé SAP (T095-KTANZA, AFABE 02)'),
    ('compte_dotation_amort', 'Compte dotation amortissement SAP (T095-KTAUFG, AFABE 02)'),
    ('date_acquisition', 'Date acquisition / capitalisation (ANLA-AKTIV)'),
    ('date_premiere_acquisition', 'Date première acquisition SAP (ANLA-ZUGDT)'),
    ('date_debut_amort', 'Date début amortissement (ANLB-AFABG)'),
    ('date_fin_amort_estimee', 'Date fin amortissement estimée (calcul ANLB/ANLC)'),
    ('duree_amort_annees', 'Durée amortissement années (ANLB-NDJAR)'),
    ('duree_amort_periodes', 'Durée amortissement mois / périodes (ANLB-NDPER)'),
    ('duree_amort_totale_mois', 'Durée amortissement totale mois (calcul ANLB)'),
    ('zone_amortissement', 'Zone amortissement retenue (ANLB-AFABE)'),
    ('type_amortissement', 'Type amortissement SAP (ANLB-AFASL)'),
    ('libelle_type_amortissement', 'Libellé type amortissement SAP (T090NAT-AFATXT)'),
    ('taux_amort_estime', 'Taux amortissement estimé % (calcul)'),
    ('centre_cout', 'Centre de coût amortissements (ANLZ-KOSTL)'),
    ('libelle_centre_cout', 'Libellé centre de coût (CSKT)'),
    ('site_sap', 'Site SAP (ANLZ-WERKS)'),
    ('secteur_sap', 'Secteur SAP (ANLZ-GSBER)'),
    ('libelle_secteur', 'Libellé secteur SAP (TGSBT)'),
    ('emplacement', 'Lieu / emplacement SAP (ANLZ-STORT)'),
    ('immo_origine', "Immobilisation d'origine principale (ANLA-AIBN1)"),
    ('sous_numero_origine', "Sous-numéro immobilisation d'origine (ANLA-AIBN2)"),
    ('date_origine', 'Date origine immobilisation (ANLA-AIBDT)'),
    ('numero_inventaire', 'Numéro inventaire (ANLA-INVNR)'),
    ('fabricant', 'Fabricant (ANLA-HERST)'),
    ('type_modele', 'Type / modèle (ANLA-TYPBZ)'),
    ('fournisseur', 'Fournisseur (ANLA-LIFNR)'),
    ('quantite', 'Quantité (ANLA-MENGE)'),
    ('unite', 'Unité (ANLA-MEINS)'),
    ('ordre_investissement', 'Ordre investissement (ANLA-EAUFN)'),
    ('zone_valorisation', 'Zone valorisation retenue (ANLC-AFABE)'),
    ('exercice_valorisation', 'Exercice de valorisation retenu (ANLC-GJAHR)'),
    ('valeur_acq_debut_exercice', 'Valeur acquisition début exercice (ANLC-KANSW)'),
    ('mouvements_acq_exercice', "Entrées de l'exercice à l'arrêté (ANLC-ANSWL > 0)"),
    ('sorties_exercice', "Sorties de l'exercice à l'arrêté (ANLC-ANSWL < 0)"),
    ('valeur_acq_fin_exercice', "Valeur acquisition à l'arrêté (ANLC-KANSW + ANLC-ANSWL)"),
    ('amort_cumules', "Amortissements cumulés à l'arrêté (ANLC-K*AFA + *AFAG + *AFAV + *AFAL)"),
    ('vnc', "VNC à l'arrêté (calcul)"),
    ('dotation_annuelle', "Dotation de l'exercice comptabilisée à l'arrêté (ANLC-*AFAG)"),
    ('blocage_comptabilisation', 'Blocage comptabilisation (ANLA-XSPEB)'),
    ('date_sortie', 'Date sortie (ANLA-ABGDT)'),
    ('date_desactivation', 'Date désactivation (ANLA-DEAKT)'),
    # Reprise IFS (migration 098, classeur metier du 18/08/2026)
    ('reprise_ifs', 'Reprise IFS'),
    ('motif_exclusion', "Motif d'exclusion"),
    ('compte_immobilisation_ifs', 'Compte immobilisation IFS'),
    ('compte_amort_cumule_ifs', 'Compte amortissement cumulé IFS'),
    ('object_group_id', 'OBJECT_GROUP_ID'),
    ('site_ifs', 'Site IFS'),
    ('element_otp', "Élément d'OTP (ANLA-POSNR -> PRPS-POSID)"),
    ('libelle_otp', 'Libellé OTP (PRPS-POST1)'),
    # migration 123
    ('numero_projet_sn', 'N° projet SN (PROJ-PSPID)'),
    ('projet_id', 'Projet Id (SharePoint / IFS)'),
]
LIBELLE = dict(LIBELLES)
COLONNES = [c for c, _ in LIBELLES]
_MONTANTS = {'valeur_acq_debut_exercice', 'mouvements_acq_exercice', 'sorties_exercice',
             'valeur_acq_fin_exercice', 'amort_cumules', 'vnc', 'dotation_annuelle'}

# Vue « immobilisations » = les 60 colonnes du fichier livre + projet SN / Id.
_PROJET = ['numero_projet_sn', 'projet_id']
COLONNES_IMMO = COLONNES[:60] + _PROJET
# Vue « travail » = onglet Travail du classeur : les 60 colonnes avec OBJECT_GROUP_ID
# insere apres la duree en annees (meme place que dans le classeur), puis les
# colonnes converties (comptes IFS, site, OTP) que la Methode demande de remplir.
_i = COLONNES[:60].index('duree_amort_annees') + 1
COLONNES_TRAVAIL = (COLONNES[:_i] + ['object_group_id'] + COLONNES[_i:60]
                    + ['compte_immobilisation_ifs', 'compte_amort_cumule_ifs', 'site_ifs',
                       'element_otp', 'libelle_otp'] + _PROJET)

# Etapes de l'onglet « Méthode » du classeur et leur automatisation (affichees
# dans l'onglet Travail de l'ecran).
METHODE = [
    ("1/ Vérifier dans l'extraction SAP le cumul des comptes immo brutes et le cumul des comptes "
     "d'amortissement par rapport à la balance générale.",
     "Synthèse > sous-totaux par compte (acquisition / amortissements) ; le rapprochement avec la balance reste manuel."),
    ("2/ Supprimer les immobilisations ayant une date de sortie antérieure ou égale à la date de bascule "
     "IFS ; reprendre celles sorties après la bascule en effaçant leur date de sortie.",
     "Colonne Reprise IFS (date de bascule = Valeurs par défaut) ; l'onglet Travail ne contient que les "
     "fiches à reprendre, date de sortie effacée."),
    ("3/ Convertir au format date les dates de désactivation.", "Dates typées au chargement."),
    ("4/ Recontrôler les totaux (valeurs brutes et amortissements), qui doivent rester identiques.",
     "Synthèse sur la vue Immobilisations et sur la vue Travail."),
    ("5/ Retrier les immobilisations restantes par date d'acquisition.", "Tri de l'onglet Travail."),
    ("6/ Mettre à blanc les dates en 00/01/1900.", "Dates SAP 00000000 chargées à NULL."),
    ("7/ Remplir les colonnes du gabarit : groupe objet, comptes PCG -> IFS, site SJ / CS.",
     "OBJECT_GROUP_ID (Transcodification FA_OBJECT_GROUP / FA_OBJECT_GROUP_IMMO), comptes IFS "
     "(FA_ACCOUNT, écran Finance > Comptes), Site IFS (division 9200 -> SJ, 9000 -> CS)."),
]


def _kind(col):
    if col == 'reprise_ifs':
        return 'bool'
    if col.startswith('date_'):
        return 'date'
    if col in _MONTANTS:
        return 'montant'
    if col in ('duree_amort_totale_mois', 'taux_amort_estime'):
        return 'nombre'
    return 'text'


def _defs(cols):
    return [{'key': c, 'label': LIBELLE[c], 'kind': _kind(c)} for c in cols]


def _read_status(key):
    try:
        with open(_status_file(key), encoding='utf-8') as f:
            return json.load(f)
    except (OSError, ValueError):
        return None


def _write_status(key, **fields):
    status = {**(_read_status(key) or {}), **fields}
    tmp = _status_file(key) + '.tmp'
    with open(tmp, 'w', encoding='utf-8') as f:
        json.dump(status, f, default=str)
    os.replace(tmp, _status_file(key))
    return status


def _json(v):
    """date -> 'YYYY-MM-DD', Decimal -> float (jsonify ferait une date HTTP et une chaine)."""
    if isinstance(v, date):
        return v.isoformat()
    if isinstance(v, Decimal):
        return float(v)
    return v


def _now():
    return datetime.now().isoformat(timespec='seconds')


# ---------------------------------------------------------------------------
# Immobilisations
# ---------------------------------------------------------------------------

def _vue():
    return 'travail' if request.args.get('vue') == 'travail' else 'immobilisations'


def _filtres(vue=None):
    """Clause WHERE + parametres a partir de la query string (liste, synthese, Excel)."""
    vue = vue or _vue()
    search = (request.args.get('search') or '').strip()
    secteur = (request.args.get('secteur') or '').strip()
    statut = (request.args.get('statut') or '').strip()
    reprise = 'a_reprendre' if vue == 'travail' else (request.args.get('reprise') or '').strip()

    where, params = [], {}
    if reprise == 'a_reprendre':
        where.append('reprise_ifs')
    elif reprise == 'exclues':
        where.append('NOT reprise_ifs')
    if search:
        where.append("(num_immobilisation ILIKE :s OR libelle ILIKE :s OR famille_immo ILIKE :s "
                     "OR centre_cout ILIKE :s OR numero_inventaire ILIKE :s "
                     "OR compte_immobilisation ILIKE :s OR numero_projet_sn ILIKE :s "
                     "OR projet_id ILIKE :s)")
        params['s'] = f'%{search}%'
    if secteur:
        where.append('secteur_sap = :secteur')
        params['secteur'] = secteur
    if statut == 'actives':
        where.append('date_desactivation IS NULL')
    elif statut == 'desactivees':
        where.append('date_desactivation IS NOT NULL')
    clause = ('WHERE ' + ' AND '.join(where)) if where else ''
    return clause, params


def _select_immo(vue, clause, params, limit=None):
    """Lignes d'une vue. Travail : date de sortie effacee (etape 2 de la Methode),
    tri par date d'acquisition (etape 5)."""
    cols = COLONNES_TRAVAIL if vue == 'travail' else COLONNES_IMMO
    exprs = ['NULL::date AS date_sortie' if vue == 'travail' and c == 'date_sortie' else c
             for c in cols]
    order = ('date_acquisition NULLS LAST, num_immobilisation, sous_numero' if vue == 'travail'
             else 'num_immobilisation, sous_numero')
    sql = f'SELECT {", ".join(exprs)} FROM clean_data.immobilisation {clause} ORDER BY {order}'
    if limit:
        sql += ' LIMIT :limit OFFSET :offset'
    return cols, db.session.execute(text(sql), params).mappings().all()


@finance_blueprint.route('/immobilisations', methods=['GET'])
@jwt_required()
def list_immobilisations():
    vue = _vue()
    page = max(int(request.args.get('page', 1)), 1)
    page_size = min(max(int(request.args.get('page_size', 50)), 1), 500)
    clause, params = _filtres(vue)

    total = db.session.execute(
        text(f'SELECT count(*) FROM clean_data.immobilisation {clause}'), params).scalar()
    cols, rows = _select_immo(vue, clause, {**params, 'limit': page_size,
                                            'offset': (page - 1) * page_size}, limit=True)

    # Totaux sur la selection filtree (valeurs statutaires a la date d'arrete)
    stats = db.session.execute(text(
        'SELECT count(*) AS immobilisations, '
        'count(*) FILTER (WHERE date_desactivation IS NULL) AS actives, '
        'count(*) FILTER (WHERE reprise_ifs) AS a_reprendre, '
        'count(*) FILTER (WHERE NOT reprise_ifs) AS exclues, '
        'count(*) FILTER (WHERE reprise_ifs AND compte_immobilisation IS NOT NULL '
        '                   AND compte_immobilisation_ifs IS NULL) AS sans_compte_ifs, '
        'count(*) FILTER (WHERE reprise_ifs AND object_group_id IS NULL) AS sans_groupe_objet, '
        'sum(valeur_acq_fin_exercice) AS valeur_acquisition, '
        'sum(amort_cumules) AS amort_cumules, sum(vnc) AS vnc, '
        'max(exercice_valorisation) AS exercice, max(date_arrete) AS date_arrete, '
        "public.get_default_value('clean_data.immobilisation', 'date_bascule_ifs', 'STANDARD') AS date_bascule "
        f'FROM clean_data.immobilisation {clause}'), params).mappings().one()
    secteurs = [dict(r) for r in db.session.execute(text(
        'SELECT secteur_sap AS code, max(libelle_secteur) AS libelle '
        'FROM clean_data.immobilisation WHERE secteur_sap IS NOT NULL '
        'GROUP BY secteur_sap ORDER BY secteur_sap')).mappings()]

    return jsonify({
        'vue': vue,
        'colonnes': _defs(cols),
        'methode': METHODE if vue == 'travail' else None,
        'rows': [{k: _json(v) for k, v in r.items()} for r in rows],
        'total': total,
        'page': page,
        'page_size': page_size,
        'stats': {k: _json(v) for k, v in stats.items()},
        'secteurs': secteurs,
        'sync': _read_status('immobilisation'),
    })


# Axes de la synthese : (cle json, colonne, titre de bloc) — memes blocs que
# l'onglet « Synthèse » du classeur metier, plus le compte pour le controle des
# cumuls par compte general (etapes 1 et 4 de la Methode).
_SYNTHESE_AXES = [
    ('par_type', 'libelle_type_amortissement', "Sous-totaux par type d'amortissement"),
    ('par_famille', 'famille_immo', 'Sous-totaux par famille'),
    ('par_secteur', 'libelle_secteur', 'Sous-totaux par secteur'),
    ('par_compte', 'compte_immobilisation', 'Sous-totaux par compte immobilisation (SAP -> IFS)'),
]


def _synthese(clause, params):
    """KPI + sous-totaux en une requete (GROUPING SETS), sur la selection filtree."""
    axes = [col for _, col, _ in _SYNTHESE_AXES]
    rows = db.session.execute(text(
        'SELECT ' + ', '.join(f'GROUPING({c}) AS g_{c}' for c in axes) + ', '
        + ', '.join(axes) + ', max(compte_immobilisation_ifs) AS compte_ifs, '
        'count(*) AS nombre, sum(valeur_acq_fin_exercice) AS acquisition, '
        'sum(amort_cumules) AS amortissements, sum(vnc) AS vnc, '
        'max(exercice_valorisation) AS exercice, max(date_arrete) AS date_arrete '
        f'FROM clean_data.immobilisation {clause} '
        'GROUP BY GROUPING SETS ((), ' + ', '.join(f'({c})' for c in axes) + ')'
    ), params).mappings().all()

    result = {'kpi': {}, **{k: [] for k, _, _ in _SYNTHESE_AXES}}
    for row in rows:
        mesures = {k: _json(row[k]) for k in ('nombre', 'acquisition', 'amortissements', 'vnc')}
        actifs = [c for c in axes if not row[f'g_{c}']]
        if not actifs:
            exercice = row['exercice']
            result['kpi'] = {
                **mesures, 'exercice': exercice,
                # Montants arretes a la derniere cloture : sans ANLP, date inconnue
                'date_situation': row['date_arrete'].strftime('%d/%m/%Y') if row['date_arrete'] else None,
                'zone': '02 - Amortissement statutaire CRC2002-10',
            }
            continue
        key = next(k for k, c, _ in _SYNTHESE_AXES if c == actifs[0])
        libelle = row[actifs[0]]
        if actifs[0] == 'compte_immobilisation' and libelle:
            libelle = f"{libelle} -> {row['compte_ifs'] or '(sans compte IFS)'}"
        result[key].append({'libelle': libelle or '(vide)', **mesures})
    for k, _, _ in _SYNTHESE_AXES:
        result[k].sort(key=lambda x: x['libelle'])
    return result


@finance_blueprint.route('/immobilisations/synthese', methods=['GET'])
@jwt_required()
def synthese_immobilisations():
    clause, params = _filtres()
    return jsonify(_synthese(clause, params))


@finance_blueprint.route('/immobilisations/export.xlsx', methods=['GET'])
@jwt_required()
def export_immobilisations_excel():
    """Classeur Excel a l'image du classeur metier : onglets Immobilisations (60
    colonnes), Travail, Conversion cpte général, TRansco comptes generaux et
    Synthèse. Les filtres de l'ecran (recherche, secteur, statut, reprise)
    s'appliquent a l'onglet Immobilisations et a la Synthese ; Travail ne
    retient que les fiches a reprendre."""
    from openpyxl import Workbook

    clause, params = _filtres('immobilisations')
    clause_t, params_t = _filtres('travail')
    wb = Workbook()
    # _select_immo renvoie des mappings : iterer une ligne donnerait les noms de colonnes
    cols, rows = _select_immo('immobilisations', clause, params)
    _feuille_tableau(wb.active, 'Immobilisations', [(c, LIBELLE[c]) for c in cols],
                     [[r[c] for c in cols] for r in rows], _MONTANTS)
    cols, rows = _select_immo('travail', clause_t, params_t)
    _feuille_tableau(wb.create_sheet('Travail'), 'Travail', [(c, LIBELLE[c]) for c in cols],
                     [[r[c] for c in cols] for r in rows], _MONTANTS)

    conv = _conversion_comptes()
    _feuille_tableau(wb.create_sheet('Conversion cpte général'), 'Conversion cpte général',
                     [('compte_sap', 'PCG US SAP'), ('pcg_fr', 'PCG FR SAP'),
                      ('compte_ifs', 'PCG IFS'), ('libelle', 'LIBELLE')],
                     [(c['compte_sap'], c['pcg_fr'], c['compte_ifs'], c['libelle']) for c in conv], set())
    transco = db.session.execute(text(
        'SELECT num_immobilisation, compte_immobilisation, compte_immobilisation_ifs '
        f'FROM clean_data.immobilisation {clause_t} '
        'ORDER BY date_acquisition NULLS LAST, num_immobilisation, sous_numero'), params_t).all()
    _feuille_tableau(wb.create_sheet('TRansco comptes generaux'), 'TRansco comptes generaux',
                     [('num', LIBELLE['num_immobilisation']), ('cpt', 'Cpt fiche'),
                      ('nv', 'Nv cpte fiche')], transco, set())
    synthese = _synthese(clause, params)
    # Lectures terminees : liberer la transaction (et ses verrous) avant de
    # construire le classeur, qui prend plusieurs secondes.
    db.session.commit()
    _feuille_synthese(wb.create_sheet('Synthèse'), synthese)
    return _envoyer(wb, 'immobilisations')


def _sync_source():
    """'sap' (defaut : extraction puis rechargement) ou 'mf' (rechargement seul)."""
    body = request.get_json(silent=True) or {}
    return 'mf' if body.get('source') == 'mf' else 'sap'


@finance_blueprint.route('/immobilisations/sync', methods=['GET'])
@jwt_required()
def get_sync_status():
    return jsonify(_read_status('immobilisation') or {'status': 'never'})


@finance_blueprint.route('/immobilisations/sync', methods=['POST'])
@jwt_required()
def start_sync():
    return _start_sync('immobilisation', IMMO_SAP_TABLES, 'clean_data.immobilisation',
                       lambda conn: conn.execute(
                           text('SELECT clean_data.alimenter_immobilisation()')).scalar(),
                       extraire=_sync_source() == 'sap')


# ---------------------------------------------------------------------------
# Comptes : conversion PCG SAP -> IFS (transcodification FA_ACCOUNT) et comptes
# portes par les fiches (onglets « Conversion cpte général » et « TRansco
# comptes generaux » du classeur)
# ---------------------------------------------------------------------------

# La description d'une ligne FA_ACCOUNT porte « LIBELLE (PCG FR nnn) » : le PCG
# francais n'a pas de colonne propre dans TranscodificationTable.
_PCG_FR = re.compile(r'\s*\(PCG FR ([^)]*)\)\s*$')


def _conversion_comptes():
    rows = db.session.execute(text(
        'SELECT id, source_value, target_value, description, is_active, updated_at '
        'FROM public."TranscodificationTable" '
        "WHERE category = 'FA_ACCOUNT' AND source_system = 'SAP' AND target_system = 'IFS' "
        'ORDER BY source_value')).mappings().all()
    out = []
    for r in rows:
        desc = r['description'] or ''
        m = _PCG_FR.search(desc)
        out.append({
            'id': r['id'], 'compte_sap': r['source_value'], 'compte_ifs': r['target_value'],
            'pcg_fr': m.group(1) if m else None,
            'libelle': _PCG_FR.sub('', desc).strip(),
            'is_active': r['is_active'], 'updated_at': _json(r['updated_at']),
        })
    return out


@finance_blueprint.route('/comptes', methods=['GET'])
@jwt_required()
def comptes():
    """Conversion des comptes + comptes reellement portes par les fiches, avec
    la conversion resolue EN DIRECT (une saisie est visible sans recharger ;
    les colonnes de la table, elles, suivent au prochain rechargement)."""
    fiches = db.session.execute(text(
        "SELECT role, compte_sap, "
        "       public.get_transcodification('FA_ACCOUNT', compte_sap, 'SAP', 'IFS') AS compte_ifs, "
        "       count(*) AS nb_fiches, count(*) FILTER (WHERE reprise_ifs) AS nb_reprises, "
        "       sum(valeur_acq_fin_exercice) AS acquisition, sum(amort_cumules) AS amortissements, "
        "       sum(vnc) AS vnc "
        "FROM (SELECT 'immobilisation' AS role, compte_immobilisation AS compte_sap, reprise_ifs, "
        "             valeur_acq_fin_exercice, amort_cumules, vnc FROM clean_data.immobilisation "
        "      UNION ALL "
        "      SELECT 'amortissement', compte_amort_cumule, reprise_ifs, "
        "             valeur_acq_fin_exercice, amort_cumules, vnc FROM clean_data.immobilisation) u "
        "WHERE compte_sap IS NOT NULL GROUP BY role, compte_sap ORDER BY role, compte_sap"
    )).mappings().all()
    return jsonify({
        'conversion': _conversion_comptes(),
        'fiches': [{k: _json(v) for k, v in r.items()} for r in fiches],
        'sync': _read_status('immobilisation'),
    })


# ---------------------------------------------------------------------------
# Commandes d'achat (clean_data.commande_achat_ifs, module sql/commandeAchat/)
# ---------------------------------------------------------------------------

# Tables lues par clean_data.alimenter_commande_achat_ifs
# (sql/commandeAchat/02_alimenter_commande_achat_ifs.sql).
CA_SAP_TABLES = ['EKKO', 'EKPO', 'EKBE', 'EKET', 'EKPA', 'EKKN', 'LFA1', 'T001W', 'ADRC', 'PRPS']

CA_LIBELLES = [
    ('site', 'Site'),
    ('societe_sap', 'Société SAP'),
    ('num_commande_sap', 'N° commande SAP'),
    ('num_ligne_sap', 'N° ligne SAP'),
    ('fournisseur_sap', 'Fournisseur SAP'),
    ('fournisseur_ifs', 'Fournisseur IFS'),
    ('nom_fournisseur', 'Nom fournisseur'),
    ('fournisseur_facturation_sap', 'Fournisseur facturation SAP'),
    ('fournisseur_facturation_ifs', 'Fournisseur facturation IFS'),
    ('type_ligne_ifs', 'Type ligne IFS'),
    ('article_sap', 'Article SAP'),
    ('designation', 'Désignation'),
    ('qte_commandee', 'Quantité commandée'),
    ('qte_restant_livrer', 'Quantité restant à livrer'),
    ('qte_restant_facturer', 'Quantité restant à facturer'),
    ('unite_achat', "Unité d'achat"),
    ('prix_net_unitaire', 'Prix net unitaire'),
    ('montant_restant_livrer', 'Montant restant à livrer'),
    ('montant_restant_facturer', 'Montant restant à facturer'),
    ('devise', 'Devise'),
    ('taux_change', 'Taux de change'),
    ('date_creation', 'Date création'),
    ('date_livraison_planifiee', 'Date livraison planifiée'),
    ('date_reception_souhaitee', 'Date réception souhaitée'),
    ('date_livraison_promise', 'Date livraison promise'),
    ('acheteur_sap', 'Acheteur SAP'),
    ('condition_paiement', 'Condition de paiement'),
    ('condition_livraison', 'Condition de livraison'),
    ('mode_expedition', "Mode d'expédition"),
    ('adresse_livraison', 'Adresse de livraison'),
    ('code_postal_livraison', 'Code postal livraison'),
    ('ville_livraison', 'Ville livraison'),
    ('pays_livraison', 'Pays livraison'),
    ('pre_imputation_projet', 'Pré-imputation projet'),
    ('element_otp', 'Élément OTP'),
    ('numero_projet', 'N° projet'),
]
CA_COLONNES = [c for c, _ in CA_LIBELLES]
_CA_MONTANTS = {'prix_net_unitaire', 'montant_restant_livrer', 'montant_restant_facturer'}
_CA_QUANTITES = {'qte_commandee', 'qte_restant_livrer', 'qte_restant_facturer'}
# Les dates de commande_achat_ifs sont du texte 'JJ/MM/AAAA' (type de la base reelle).
_CA_DATES = {'date_creation', 'date_livraison_planifiee', 'date_reception_souhaitee',
             'date_livraison_promise'}


def _ca_filtres():
    """Clause WHERE + parametres (liste et export Excel des commandes d'achat)."""
    search = (request.args.get('search') or '').strip()
    site = (request.args.get('site') or '').strip()

    where, params = [], {}
    if search:
        where.append("(num_commande_sap ILIKE :s OR nom_fournisseur ILIKE :s "
                     "OR fournisseur_sap ILIKE :s OR fournisseur_ifs ILIKE :s "
                     "OR article_sap ILIKE :s OR designation ILIKE :s)")
        params['s'] = f'%{search}%'
    if site:
        where.append('site = :site')
        params['site'] = site
    clause = ('WHERE ' + ' AND '.join(where)) if where else ''
    return clause, params


def _ca_date(v):
    """'JJ/MM/AAAA' -> date pour Excel (texte laisse tel quel si autre format)."""
    try:
        return datetime.strptime(v, '%d/%m/%Y').date() if v else v
    except (TypeError, ValueError):
        return v


@finance_blueprint.route('/commandes-achat', methods=['GET'])
@jwt_required()
def list_commandes_achat():
    page = max(int(request.args.get('page', 1)), 1)
    page_size = min(max(int(request.args.get('page_size', 50)), 1), 500)
    clause, params = _ca_filtres()

    total = db.session.execute(
        text(f'SELECT count(*) FROM clean_data.commande_achat_ifs {clause}'), params).scalar()
    rows = db.session.execute(text(
        f'SELECT {", ".join(CA_COLONNES)} FROM clean_data.commande_achat_ifs {clause} '
        'ORDER BY num_commande_sap, num_ligne_sap LIMIT :limit OFFSET :offset'
    ), {**params, 'limit': page_size, 'offset': (page - 1) * page_size}).mappings().all()

    # Totaux sur la selection filtree ; montants en EUR seulement (devises non converties)
    stats = db.session.execute(text(
        'SELECT count(*) AS lignes, count(DISTINCT num_commande_sap) AS commandes, '
        'count(DISTINCT fournisseur_sap) AS fournisseurs, '
        "sum(montant_restant_livrer) FILTER (WHERE devise = 'EUR') AS restant_livrer_eur, "
        "sum(montant_restant_facturer) FILTER (WHERE devise = 'EUR') AS restant_facturer_eur "
        f'FROM clean_data.commande_achat_ifs {clause}'), params).mappings().one()
    sites = [r[0] for r in db.session.execute(text(
        'SELECT DISTINCT site FROM clean_data.commande_achat_ifs '
        'WHERE site IS NOT NULL ORDER BY 1'))]

    return jsonify({
        'rows': [{k: _json(v) for k, v in r.items()} for r in rows],
        'total': total,
        'page': page,
        'page_size': page_size,
        'stats': {k: _json(v) for k, v in stats.items()},
        'sites': sites,
        'sync': _read_status('commande_achat'),
    })


# Objets de reprise IFS (Lot 11) alimentes par clean_data.alimenter_purchase_order() :
# onglet -> colonnes de recherche (en plus de order_no). Toutes les colonnes sont
# renvoyees (SELECT *), l'ecran choisit lesquelles afficher.
CA_IFS_TABLES = {
    'purchase_order': ['vendor_no', 'invoicing_supplier'],
    'purchase_order_line_part': ['part_no', 'description'],
    'purchase_order_line_nopart': ['description'],
}


def _ca_ifs_requete(table):
    """SELECT filtre (recherche, site = contract) d'un objet IFS, ou None si onglet inconnu."""
    if table not in CA_IFS_TABLES:
        return None
    search = (request.args.get('search') or '').strip()
    site = (request.args.get('site') or '').strip()
    where, params = [], {}
    if search:
        where.append('(' + ' OR '.join(f'{c} ILIKE :s' for c in ['order_no'] + CA_IFS_TABLES[table]) + ')')
        params['s'] = f'%{search}%'
    if site:
        where.append('contract = :site')
        params['site'] = site
    clause = ('WHERE ' + ' AND '.join(where)) if where else ''
    # line_no est du texte ('10', '100') : tri numerique par la longueur puis la valeur
    order = 'order_no' if table == 'purchase_order' else 'order_no, length(line_no), line_no'
    return f'FROM clean_data.{table} {clause}', order, params


@finance_blueprint.route('/commandes-achat/ifs/<table>', methods=['GET'])
@jwt_required()
def list_commandes_achat_ifs(table):
    requete = _ca_ifs_requete(table)
    if requete is None:
        return jsonify({'error': f'Onglet inconnu : {table}'}), 404
    source, order, params = requete
    page = max(int(request.args.get('page', 1)), 1)
    page_size = min(max(int(request.args.get('page_size', 50)), 1), 500)

    total = db.session.execute(text(f'SELECT count(*) {source}'), params).scalar()
    result = db.session.execute(text(f'SELECT * {source} ORDER BY {order} LIMIT :limit OFFSET :offset'),
                                {**params, 'limit': page_size, 'offset': (page - 1) * page_size})
    colonnes = list(result.keys())
    rows = [{k: _json(v) for k, v in r.items()} for r in result.mappings().all()]
    return jsonify({'colonnes': colonnes, 'rows': rows, 'total': total, 'page': page,
                    'page_size': page_size, 'sync': _read_status('commande_achat')})


@finance_blueprint.route('/commandes-achat/export.xlsx', methods=['GET'])
@jwt_required()
def export_commandes_achat_excel():
    from openpyxl import Workbook

    vue = request.args.get('vue') or ''
    if vue in CA_IFS_TABLES:
        colonnes, rows = _ca_lignes_ifs(vue)
        db.session.commit()
        wb = Workbook()
        # En-tetes = noms de colonnes IFS en majuscules, comme les fichiers modeles Lot11
        _feuille_tableau(wb.active, vue, [(c, c.upper()) for c in colonnes], rows, set())
        return _envoyer(wb, vue)

    rows = _ca_lignes_commandes()
    db.session.commit()  # liberer la transaction de lecture avant la generation
    wb = Workbook()
    _feuille_tableau(wb.active, "Commandes d'achat", CA_LIBELLES, rows, _CA_MONTANTS | _CA_QUANTITES)
    return _envoyer(wb, 'commandes_achat')


def _ca_lignes_commandes():
    """Lignes filtrees de commande_achat_ifs, dates texte converties pour Excel."""
    clause, params = _ca_filtres()
    rows = db.session.execute(text(
        f'SELECT {", ".join(CA_COLONNES)} FROM clean_data.commande_achat_ifs {clause} '
        'ORDER BY num_commande_sap, num_ligne_sap'), params).all()
    dates = [i for i, c in enumerate(CA_COLONNES) if c in _CA_DATES]
    return [[_ca_date(v) if i in dates else v for i, v in enumerate(r)] for r in rows]


def _ca_lignes_ifs(table):
    """(colonnes, lignes) filtrees d'un objet IFS, toutes les colonnes."""
    source, order, params = _ca_ifs_requete(table)
    result = db.session.execute(text(f'SELECT * {source} ORDER BY {order}'), params)
    return list(result.keys()), result.all()


def _csv_ifs(v):
    """Cellule au format des fichiers modeles Lot11 : dates JJ/MM/AAAA, virgule decimale."""
    if v is None:
        return ''
    if isinstance(v, (date, datetime)):
        return v.strftime('%d/%m/%Y')
    if isinstance(v, Decimal):
        return format(v.normalize(), 'f').replace('.', ',')
    if isinstance(v, float):
        return repr(v).replace('.', ',')
    return str(v)


@finance_blueprint.route('/commandes-achat/export.zip', methods=['GET'])
@jwt_required()
def export_commandes_achat_zip():
    """ZIP : classeur Excel des 4 onglets + les 3 CSV de reprise IFS (format Lot11_*_V2.csv :
    UTF-8 avec BOM, ';', en-tetes IFS en majuscules, fins de ligne CRLF). Filtres de l'ecran appliques."""
    import csv
    import zipfile
    from openpyxl import Workbook

    commandes = _ca_lignes_commandes()
    ifs = {t: _ca_lignes_ifs(t) for t in CA_IFS_TABLES}
    db.session.commit()

    wb = Workbook()
    _feuille_tableau(wb.active, "Commandes d'achat", CA_LIBELLES, commandes, _CA_MONTANTS | _CA_QUANTITES)
    for t, (colonnes, rows) in ifs.items():
        _feuille_tableau(wb.create_sheet(), t, [(c, c.upper()) for c in colonnes], rows, set())
    classeur = io.BytesIO()
    wb.save(classeur)

    horodatage = f'{datetime.now():%Y%m%d_%H%M}'
    buffer = io.BytesIO()
    with zipfile.ZipFile(buffer, 'w', zipfile.ZIP_DEFLATED) as z:
        z.writestr(f'commandes_achat_{horodatage}.xlsx', classeur.getvalue())
        for t, (colonnes, rows) in ifs.items():
            texte = io.StringIO()
            w = csv.writer(texte, delimiter=';', lineterminator='\r\n')
            w.writerow([c.upper() for c in colonnes])
            w.writerows([[_csv_ifs(v) for v in r] for r in rows])
            z.writestr(f'{t.upper()}.csv', texte.getvalue().encode('utf-8-sig'))
    buffer.seek(0)
    return send_file(buffer, as_attachment=True, mimetype='application/zip',
                     download_name=f'commandes_achat_{horodatage}.zip')


@finance_blueprint.route('/commandes-achat/sync', methods=['GET'])
@jwt_required()
def get_ca_sync_status():
    return jsonify(_read_status('commande_achat') or {'status': 'never'})


@finance_blueprint.route('/commandes-achat/sync', methods=['POST'])
@jwt_required()
def start_ca_sync():
    # Memes bornes que le module ETL : module_params de etl_target_tables
    # ({"date_debut", "date_fin"} sur la date de creation SAP).
    module_params = db.session.execute(text(
        "SELECT module_params FROM public.etl_target_tables "
        "WHERE python_module = 'etl_commande_achat.py' LIMIT 1")).scalar() or {}

    def load(conn):
        lignes = conn.execute(text(
            'SELECT clean_data.alimenter_commande_achat_ifs('
            'CAST(:d AS date), CAST(:f AS date), NULL)'),
            {'d': module_params.get('date_debut'), 'f': module_params.get('date_fin')}).scalar()
        # Puis dispatch vers purchase_order / _line_part / _line_nopart (onglets IFS)
        conn.execute(text('SELECT clean_data.alimenter_purchase_order()'))
        return lignes

    return _start_sync('commande_achat', CA_SAP_TABLES,
                       'clean_data.commande_achat_ifs puis purchase_order*', load,
                       extraire=_sync_source() == 'sap')


# ---------------------------------------------------------------------------
# Historique des couts par projet (clean_data.historique_cout_projet,
# module sql/historiqueCoutProjet/, reconstitution ZCOA requete 3 sur RPSCO)
# ---------------------------------------------------------------------------

# Tables lues par clean_data.alimenter_historique_cout_projet. Le n° projet vient
# en plus de raw_data.sharepoint_projets (liste SharePoint « Projets », importee
# avant le rechargement par « Synchroniser SAP ») et a_migrer de
# clean_data.project_base (projets repris dans IFS).
HCP_SAP_TABLES = ['RPSCO', 'PRPS', 'PROJ']

# Colonnes de regroupement par vue ; les mesures sont sommees. numero_projet ne
# depend que du projet (la cle de l'OTP et celle du projet ne divergent jamais),
# a_migrer non plus.
HCP_CLES = {
    'projet': ['projet', 'projet_libelle', 'responsable', 'numero_projet', 'a_migrer'],
    'otp': ['projet', 'projet_libelle', 'responsable', 'numero_projet', 'a_migrer',
            'element_otp', 'otp_libelle'],
}
HCP_MESURES = ['reel', 'reel_capex', 'reel_opex', 'reel_a_qualifier', 'reel_cumule', 'plan', 'budget_annuel', 'engag_cde', 'engag_da']
HCP_LIBELLE = {
    'projet': 'Projet (PROJ-PSPID)',
    'projet_libelle': 'Désignation projet',
    'responsable': 'Responsable',
    'numero_projet': 'N° projet',
    'a_migrer': 'À migrer',
    'element_otp': 'Élément OTP',
    'otp_libelle': 'Désignation OTP',
    'annee': 'Année',
    'periode': 'Période',
    'reel': 'Réel',
    'reel_capex': 'Réel CAPEX',
    'reel_opex': 'Réel OPEX',
    'reel_a_qualifier': 'Réel à qualifier',
    'reel_cumule': 'Réel cumulé',
    'plan': 'Plan',
    'budget_annuel': 'Budget annuel',
    'engag_cde': 'Commandes non réceptionnées',
    'engag_da': "Demandes d'achat",
}


def _hcp_vue():
    return 'otp' if request.args.get('vue') == 'otp' else 'projet'


def _hcp_colonnes(vue):
    return HCP_CLES[vue] + ['annee', 'periode'] + HCP_MESURES


def _hcp_requete(vue):
    """(SQL sans LIMIT, params) : lignes agregees au grain de la vue. Le cumul du reel
    est calcule sur TOUT l'historique du projet / de l'OTP, puis filtre par annee
    (sinon il repartirait de zero a l'annee de debut du filtre)."""
    search = (request.args.get('search') or '').strip()
    cles = ', '.join(HCP_CLES[vue])
    params = {}
    where = []
    if search:
        where.append('(projet ILIKE :s OR projet_libelle ILIKE :s OR responsable ILIKE :s '
                     'OR element_otp ILIKE :s OR numero_projet ILIKE :s)')
        params['s'] = f'%{search}%'
    migration = request.args.get('migration')
    if migration in ('oui', 'non'):
        where.append('a_migrer' if migration == 'oui' else 'NOT a_migrer')
    interne = ('WHERE ' + ' AND '.join(where)) if where else ''

    externe = []
    for borne, op in (('annee_debut', '>='), ('annee_fin', '<=')):
        v = request.args.get(borne) or ''
        if v.isdigit():
            externe.append(f'annee {op} :{borne}')
            params[borne] = int(v)
    clause_annee = ('WHERE ' + ' AND '.join(externe)) if externe else ''

    sql = (
        f'WITH agg AS ('
        f' SELECT {cles}, annee, periode, SUM(reel) AS reel,'
        f' SUM(reel_capex) AS reel_capex, SUM(reel_opex) AS reel_opex,'
        f' SUM(reel_a_qualifier) AS reel_a_qualifier,'
        f' SUM(SUM(reel)) OVER (PARTITION BY {cles} ORDER BY annee, periode) AS reel_cumule,'
        f' SUM(plan) AS plan, SUM(budget_annuel) AS budget_annuel,'
        f' SUM(engag_cde) AS engag_cde, SUM(engag_da) AS engag_da'
        f' FROM clean_data.v_historique_cout_projet {interne}'
        f' GROUP BY {cles}, annee, periode)'
        f' SELECT {", ".join(_hcp_colonnes(vue))} FROM agg {clause_annee}'
        f' ORDER BY {cles}, annee, periode'
    )
    return sql, params


@finance_blueprint.route('/historique-couts', methods=['GET'])
@jwt_required()
def list_historique_couts():
    page = max(int(request.args.get('page', 1)), 1)
    page_size = min(max(int(request.args.get('page_size', 50)), 1), 500)
    vue = _hcp_vue()
    sql, params = _hcp_requete(vue)

    rows = db.session.execute(
        text(f'{sql} LIMIT :limit OFFSET :offset'),
        {**params, 'limit': page_size, 'offset': (page - 1) * page_size}).mappings().all()
    # reel_cumule n'est pas sommable : les totaux portent sur les autres mesures
    stats = db.session.execute(text(
        'SELECT count(*) AS lignes, count(DISTINCT projet) AS projets, '
        'count(DISTINCT projet) FILTER (WHERE a_migrer) AS projets_a_migrer, '
        'sum(reel) AS reel, sum(reel_capex) AS reel_capex, sum(reel_opex) AS reel_opex, '
        'sum(reel_a_qualifier) AS reel_a_qualifier, sum(plan) AS plan, sum(budget_annuel) AS budget_annuel, '
        f'sum(engag_cde) AS engag_cde, sum(engag_da) AS engag_da FROM ({sql}) q'),
        params).mappings().one()
    annees = [r[0] for r in db.session.execute(text(
        'SELECT DISTINCT annee FROM clean_data.historique_cout_projet ORDER BY 1'))]

    return jsonify({
        'rows': [{k: _json(v) for k, v in r.items()} for r in rows],
        'total': stats['lignes'],
        'page': page,
        'page_size': page_size,
        'stats': {k: _json(v) for k, v in stats.items()},
        'annees': annees,
        'colonnes': [{'key': c, 'label': HCP_LIBELLE[c],
                      'kind': 'montant' if c in HCP_MESURES
                      else 'bool' if c == 'a_migrer' else 'text'}
                     for c in _hcp_colonnes(vue)],
        'sync': _read_status('historique_cout_projet'),
    })


@finance_blueprint.route('/historique-couts/export.xlsx', methods=['GET'])
@jwt_required()
def export_historique_couts_excel():
    from openpyxl import Workbook

    vue = _hcp_vue()
    sql, params = _hcp_requete(vue)
    rows = db.session.execute(text(sql), params).all()
    db.session.commit()  # liberer la transaction de lecture avant la generation
    wb = Workbook()
    _feuille_tableau(wb.active, 'Historique des coûts',
                     [(c, HCP_LIBELLE[c]) for c in _hcp_colonnes(vue)], rows, set(HCP_MESURES))
    return _envoyer(wb, f'historique_couts_{vue}')


@finance_blueprint.route('/historique-couts/sync', methods=['GET'])
@jwt_required()
def get_hcp_sync_status():
    return jsonify(_read_status('historique_cout_projet') or {'status': 'never'})


@finance_blueprint.route('/historique-couts/sync', methods=['POST'])
@jwt_required()
def start_hcp_sync():
    extraire = _sync_source() == 'sap'

    def load(conn):
        # « Synchroniser SAP » : la liste SharePoint des projets (n° projet) est
        # re-importee apres l'extraction SAP. Upsert sur sa propre connexion, donc
        # visible du rechargement. Echec non bloquant : le n° projet reste celui du
        # dernier import, signale dans l'etat de la synchro.
        if extraire:
            _write_status('historique_cout_projet', step='Import des projets SharePoint', progress=88)
            try:
                from services.sharepoint_service import SharePointService
                res = SharePointService().import_projets_from_sharepoint()
                avert = None if res.get('db_saved') else '; '.join(res.get('errors') or []) or 'non sauvegarde'
            except Exception as e:
                avert = str(e)
            _write_status('historique_cout_projet', warning=avert and
                          f'Projets SharePoint non re-importes ({avert}) : n° projet du dernier import')
        return conn.execute(text('SELECT clean_data.alimenter_historique_cout_projet()')).scalar()

    return _start_sync('historique_cout_projet', HCP_SAP_TABLES,
                       'clean_data.historique_cout_projet', load, extraire=extraire)


# Reprise IFS des couts historiques (OD) : clean_data.reprise_cout_projet(date_arrete),
# sql/historiqueCoutProjet/03_reprise_cout_projet.sql, saisies de la migration 126.
REPRISE_COLONNES = ['numero_projet', 'projet', 'projet_libelle', 'element_otp', 'otp_libelle',
                    'nature', 'nature_source', 'montant', 'project_id_ifs', 'project_id_source',
                    'activity_seq', 'anomalies', 'exporte']
# Fichier attendu par IFS. ponytail: le credit = element d'OTP SAP tel quel ('SN26052IM'),
# format a confirmer avec le modele d'import de l'OD.
REPRISE_OD = [('element_otp', 'Centre de coûts/crédit'), ('project_id_ifs', 'ID projet IFS'),
              ('montant', 'Montant'), ('activity_seq', "Séquence d'activité")]
REPRISE_ANOMALIES = {
    'NATURE_A_QUALIFIER': "OTP sans suffixe IM / EX ni qualification manuelle",
    'SEQUENCE_MANQUANTE': "Séquence d'activité IFS de reprise non saisie pour cette nature",
    'PROJET_IFS_INCONNU': 'ID projet IFS absent des projets IFS (project_base)',
    'SEQUENCE_INCONNUE': "Séquence d'activité absente des activités IFS du projet",
    'OTP_EN_DOUBLE': "Même élément d'OTP rattaché à plusieurs projets",
    'PROJET_IFS_PARTAGE': 'Même ID projet IFS pour plusieurs n° projet',
    'CUMUL_PARENT_ENFANTS': 'Montant du parent égal à la somme de ses enfants : cumul, double comptage',
}


def _reprise_arrete():
    """Date d'arrete (fin de mois) depuis ?date_arrete=YYYY-MM-DD ; ValueError sinon."""
    d = date.fromisoformat(request.args.get('date_arrete') or '')
    if (d.replace(day=28) + timedelta(days=4)).replace(day=1) - timedelta(days=1) != d:
        raise ValueError('Arrêté mensuel uniquement : RPSCO ne porte que des montants par période')
    return d


def _reprise_lignes(d):
    return db.session.execute(text(
        f'SELECT {", ".join(REPRISE_COLONNES)}, exercice, periode '
        'FROM clean_data.reprise_cout_projet(:d)'), {'d': d}).mappings().all()


@finance_blueprint.route('/historique-couts/reprise', methods=['GET'])
@jwt_required()
def get_reprise_couts():
    try:
        d = _reprise_arrete()
    except ValueError as e:
        return jsonify({'error': str(e)}), 400
    rows = _reprise_lignes(d)
    saisies = db.session.execute(text(
        'SELECT numero_projet, project_id_ifs, activity_seq_capex, activity_seq_opex, saisi_par, saisi_le '
        'FROM clean_data.reprise_cout_projet_ifs')).mappings().all()
    return jsonify({
        'saisies': {s['numero_projet']: {k: _json(v) for k, v in s.items()} for s in saisies},
        'arrete': {'date': d.isoformat(),
                   'exercice': rows[0]['exercice'] if rows else None,
                   'periode': rows[0]['periode'] if rows else None},
        'rows': [{k: _json(r[k]) for k in REPRISE_COLONNES} for r in rows],
        'libelles_anomalies': REPRISE_ANOMALIES,
    })


@finance_blueprint.route('/historique-couts/reprise/nature/<path:otp>', methods=['PUT'])
@jwt_required()
def put_reprise_nature(otp):
    """Qualification CAPEX / OPEX d'un OTP sans suffixe reconnu ; nature null = suppression."""
    body = request.get_json(silent=True) or {}
    nature = body.get('nature')
    if db.session.execute(text('SELECT clean_data.nature_suffixe_otp(:o)'), {'o': otp}).scalar():
        return jsonify({'error': 'Nature donnée par le suffixe IM / EX : non modifiable'}), 400
    if nature is None:
        db.session.execute(text('DELETE FROM clean_data.reprise_cout_otp_nature WHERE element_otp = :o'),
                           {'o': otp})
    elif nature in ('CAPEX', 'OPEX'):
        db.session.execute(text(
            'INSERT INTO clean_data.reprise_cout_otp_nature (element_otp, nature, commentaire, qualifie_par) '
            'VALUES (:o, :n, :c, :u) ON CONFLICT (element_otp) DO UPDATE SET nature = EXCLUDED.nature, '
            'commentaire = EXCLUDED.commentaire, qualifie_par = EXCLUDED.qualifie_par, '
            'qualifie_le = current_timestamp'),
            {'o': otp, 'n': nature, 'c': body.get('commentaire'), 'u': str(get_jwt_identity())})
    else:
        return jsonify({'error': 'nature attendue : CAPEX, OPEX ou null'}), 400
    db.session.commit()
    return jsonify({'ok': True})


@finance_blueprint.route('/historique-couts/reprise/projet/<path:numero_projet>', methods=['PUT'])
@jwt_required()
def put_reprise_projet(numero_projet):
    """Correspondance n° projet -> ID projet IFS / sequences de reprise (vide = non renseigne)."""
    body = request.get_json(silent=True) or {}
    try:
        seqs = {k: None if body.get(k) in (None, '') else Decimal(str(body[k]))
                for k in ('activity_seq_capex', 'activity_seq_opex')}
    except Exception:
        return jsonify({'error': "Séquence d'activité numérique attendue"}), 400
    db.session.execute(text(
        'INSERT INTO clean_data.reprise_cout_projet_ifs (numero_projet, project_id_ifs, activity_seq_capex, '
        'activity_seq_opex, commentaire, saisi_par) VALUES (:p, :i, :sc, :so, :c, :u) '
        'ON CONFLICT (numero_projet) DO UPDATE SET project_id_ifs = EXCLUDED.project_id_ifs, '
        'activity_seq_capex = EXCLUDED.activity_seq_capex, activity_seq_opex = EXCLUDED.activity_seq_opex, '
        'commentaire = EXCLUDED.commentaire, saisi_par = EXCLUDED.saisi_par, saisi_le = current_timestamp'),
        {'p': numero_projet, 'i': (body.get('project_id_ifs') or '').strip() or None,
         'sc': seqs['activity_seq_capex'], 'so': seqs['activity_seq_opex'],
         'c': body.get('commentaire'), 'u': str(get_jwt_identity())})
    db.session.commit()
    return jsonify({'ok': True})


@finance_blueprint.route('/historique-couts/reprise/export.xlsx', methods=['GET'])
@jwt_required()
def export_reprise_couts():
    """Fichier OD (lignes a montant non nul) ; refuse (409) tant qu'il reste une anomalie."""
    from openpyxl import Workbook

    try:
        d = _reprise_arrete()
    except ValueError as e:
        return jsonify({'error': str(e)}), 400
    rows = _reprise_lignes(d)
    db.session.commit()
    bloquantes = [r for r in rows if r['anomalies']]
    if bloquantes:
        return jsonify({'error': f'{len(bloquantes)} ligne(s) en anomalie : export refusé',
                        'anomalies': len(bloquantes)}), 409
    od = [r for r in rows if r['exporte']]
    wb = Workbook()
    _feuille_tableau(wb.active, 'OD reprise', REPRISE_OD,
                     [[r[c] for c, _ in REPRISE_OD] for r in od], {'montant'})
    detail = [('numero_projet', 'N° projet'), ('projet', 'Projet SAP'), ('element_otp', 'Élément OTP'),
              ('otp_libelle', 'Désignation OTP'), ('nature', 'Nature'), ('montant', 'Montant'),
              ('project_id_ifs', 'ID projet IFS'), ('activity_seq', "Séquence d'activité")]
    _feuille_tableau(wb.create_sheet(), f'Détail arrêté {d:%d-%m-%Y}', detail,
                     [[r[c] for c, _ in detail] for r in od], {'montant'})
    return _envoyer(wb, f'reprise_couts_projet_{d:%Y%m%d}')


# ---------------------------------------------------------------------------
# Fournisseurs (clean_data.ifs_fournisseurs_perimetre, sql/supplier/01b_*) :
# fichier de selection + fournisseurs crees dans SAP depuis la date d'arrete
# ---------------------------------------------------------------------------

# Tables SAP lues par clean_data.alimenter_ifs_fournisseurs_perimetre (le
# fichier de selection, raw_data.selection_fournisseurs_stg, s'importe a part).
FOURN_SAP_TABLES = ['LFA1', 'LFB1', 'LFM1', 'WYT3', 'ADRC', 'ADR2', 'ADR3', 'ADR4', 'ADR5', 'ADR6',
                    'LFBK', 'TIBAN', 'BNKA']

FOURN_LIBELLE = {
    'numero_compte_fournisseur': 'N° fournisseur SAP',
    'source': 'Source',
    'numero_compte_ifs': 'N° IFS',
    'nom_1': 'Nom',
    'rue': 'Rue',
    'complement_adresse': "Complément d'adresse",
    'code_postal': 'Code postal',
    'localite': 'Localité',
    'cle_pays': 'Pays',
    'date_creation_sap': 'Date de création SAP',
    'siret': 'SIRET',
    'numero_siren': 'SIREN',
    'tva': 'N° TVA',
    'code_tva_ifs': 'Code TVA IFS',
    'code_tva_sap': 'Code TVA SAP',
    'france_etranger': 'France / étranger',
    # Libelle du fichier valide par le metier : l'import retrouve la colonne par ce nom
    'id_societe_etrangere': 'Identifiant dans Pays Etranger',
    'company': 'Société IFS',
    'address_id': 'N° adresse',
    'societe': 'Sociétés SAP',
    'organisation_achats': 'Organisation achats',
    'conditions_paiement_compta': 'Conditions de paiement compta',
    'conditions_paiement_achats': 'Conditions de paiement achats',
    'condition_paiement_sap': 'Condition de paiement SAP',
    'mode_paiement': 'Mode de paiement',
    'incoterms_1': 'Incoterm',
    'incoterms_2': 'Lieu incoterm',
    'telephone_1': 'Téléphone 1',
    'telephone_2': 'Téléphone 2',
    'telephone_3': 'Téléphone 3',
    'email': 'E-mail',
    'critere_recherche': 'Critère de recherche',
    'langue': 'Langue (fichier)',
    'language_sap': 'Langue IFS',
    'destinataire_paiement': 'Destinataire du paiement',
    'iban_paiement': 'IBAN',
    'swift_bic': 'SWIFT / BIC',
    'nom_banque': 'Banque',
    'numero_compte_bancaire': 'N° de compte bancaire',
    'code_banque': 'Code banque',
    'pays_banque': 'Pays banque',
    'titulaire_compte': 'Titulaire du compte',
}

FOURN_ADRESSE_LIBELLE = {
    'numero_compte_fournisseur': 'N° fournisseur SAP',
    'numero_compte_ifs': 'N° IFS',
    'source': 'Source',
    'address_id': 'N° adresse',
    'adrnr_sap': 'N° adresse SAP',
    'fonction_libelle': 'Fonction',
    'partenaire_sap': 'Partenaire SAP',
    'nom': 'Nom',
    'rue': 'Rue',
    'complement_adresse': "Complément d'adresse",
    'boite_postale': 'Boîte postale',
    'code_postal': 'Code postal',
    'localite': 'Localité',
    'region': 'Région',
    'pays': 'Pays',
    'langue': 'Langue',
    'valide_du': 'Valide du',
    'valide_au': 'Valide au',
}

FOURN_COMM_LIBELLE = {
    'numero_compte_fournisseur': 'N° fournisseur SAP',
    'numero_compte_ifs': 'N° IFS',
    'source': 'Source',
    'address_id': 'N° adresse',
    'fonction_libelle': "Fonction de l'adresse",
    'methode': 'Méthode',
    'valeur': 'Valeur',
    'extension': 'Extension',
    'pays': 'Pays',
    'par_defaut': 'Par défaut',
}

# Onglets de l'ecran : table, libelles, colonnes de recherche, tri, titre de la feuille Excel
FOURN_VUES = {
    'fournisseurs': ('clean_data.ifs_fournisseurs_perimetre', FOURN_LIBELLE,
                     ('numero_compte_fournisseur', 'numero_compte_ifs', 'nom_1', 'localite',
                      'siret', 'tva', 'id_societe_etrangere', 'critere_recherche'),
                     'source, numero_compte_fournisseur', 'Fournisseurs'),
    'adresses': ('clean_data.ifs_fournisseurs_perimetre_adresse', FOURN_ADRESSE_LIBELLE,
                 ('numero_compte_fournisseur', 'numero_compte_ifs', 'nom', 'rue', 'localite',
                  'code_postal', 'partenaire_sap'),
                 'numero_compte_fournisseur, address_id', 'Adresses'),
    'communications': ('clean_data.ifs_fournisseurs_perimetre_communication', FOURN_COMM_LIBELLE,
                       ('numero_compte_fournisseur', 'numero_compte_ifs', 'valeur', 'address_id'),
                       'numero_compte_fournisseur, address_id, methode, par_defaut DESC, num_sequence',
                       'Méthodes de communication'),
}


def _fourn_vue():
    vue = request.args.get('vue')
    return FOURN_VUES[vue if vue in FOURN_VUES else 'fournisseurs']


def _fourn_filtres(recherche):
    where, params = [], {}
    search = (request.args.get('search') or '').strip()
    if search:
        where.append('(' + ' OR '.join(f'{c} ILIKE :s' for c in recherche) + ')')
        params['s'] = f'%{search}%'
    if request.args.get('source') in ('FICHIER', 'SAP_NOUVEAU'):
        where.append('source = :source')
        params['source'] = request.args['source']
    methode = request.args.get('methode')
    if methode and recherche is FOURN_VUES['communications'][2]:
        where.append('methode = :methode')
        params['methode'] = methode
    return ('WHERE ' + ' AND '.join(where)) if where else '', params


def _fourn_sql(table, libelles, clause, tri):
    return f'SELECT {", ".join(libelles)} FROM {table} {clause} ORDER BY {tri}'


def _fourn_kind(col):
    if col == 'par_defaut':
        return 'bool'
    return 'date' if col.startswith(('date_', 'valide_')) else 'text'


@finance_blueprint.route('/fournisseurs', methods=['GET'])
@jwt_required()
def list_fournisseurs():
    """?vue=fournisseurs (defaut) | adresses | communications ; filtres search, source
    (et methode pour les communications)."""
    page = max(int(request.args.get('page', 1)), 1)
    page_size = min(max(int(request.args.get('page_size', 50)), 1), 500)
    table, libelles, recherche, tri, _ = _fourn_vue()
    clause, params = _fourn_filtres(recherche)
    rows = db.session.execute(
        text(f'{_fourn_sql(table, libelles, clause, tri)} LIMIT :limit OFFSET :offset'),
        {**params, 'limit': page_size, 'offset': (page - 1) * page_size}).mappings().all()
    total = db.session.execute(text(f'SELECT count(*) FROM {table} {clause}'), params).scalar()
    # Date du dernier chargement, a defaut celle de l'ecran Valeurs par defaut
    stats = db.session.execute(text(
        "SELECT count(*) AS total, count(*) FILTER (WHERE source = 'FICHIER') AS fichier, "
        "count(*) FILTER (WHERE source = 'SAP_NOUVEAU') AS sap_nouveau, "
        "COALESCE(max(date_arrete), NULLIF(TRIM(public.get_default_value("
        "'clean_data.ifs_fournisseurs', 'date_arrete')), '')::date) AS date_arrete "
        "FROM clean_data.ifs_fournisseurs_perimetre")).mappings().one()
    methodes = [r[0] for r in db.session.execute(text(
        'SELECT DISTINCT methode FROM clean_data.ifs_fournisseurs_perimetre_communication ORDER BY 1'))]

    return jsonify({
        'rows': [{k: _json(v) for k, v in r.items()} for r in rows],
        'total': total,
        'page': page,
        'page_size': page_size,
        'stats': {k: _json(v) for k, v in stats.items()},
        'methodes': methodes,
        'colonnes': [{'key': c, 'label': libelles[c], 'kind': _fourn_kind(c)} for c in libelles],
        'sync': _read_status('fournisseurs'),
    })


@finance_blueprint.route('/fournisseurs/export.xlsx', methods=['GET'])
@jwt_required()
def export_fournisseurs_excel():
    """Classeur a 3 feuilles (Fournisseurs, Adresses, Méthodes de communication) :
    les fournisseurs filtres (search, source) puis leurs adresses et moyens de
    communication (filtre methode sur la derniere feuille)."""
    from openpyxl import Workbook

    table, libelles, recherche, tri, titre = FOURN_VUES['fournisseurs']
    clause, params = _fourn_filtres(recherche)
    feuilles = [(titre, libelles, db.session.execute(
        text(_fourn_sql(table, libelles, clause, tri)), params).all())]
    perimetre = f'numero_compte_fournisseur IN (SELECT numero_compte_fournisseur FROM {table} {clause})'
    for vue in ('adresses', 'communications'):
        t, lib, _, tr, ti = FOURN_VUES[vue]
        where, p = [perimetre], dict(params)
        if vue == 'communications' and request.args.get('methode'):
            where.append('methode = :methode')
            p['methode'] = request.args['methode']
        feuilles.append((ti, lib, db.session.execute(
            text(_fourn_sql(t, lib, 'WHERE ' + ' AND '.join(where), tr)), p).all()))
    db.session.commit()  # liberer la transaction de lecture avant la generation

    wb = Workbook()
    for i, (ti, lib, rows) in enumerate(feuilles):
        _feuille_tableau(wb.active if i == 0 else wb.create_sheet(), ti, list(lib.items()), rows, set())
    return _envoyer(wb, 'fournisseurs')


@finance_blueprint.route('/fournisseurs/sync', methods=['GET'])
@jwt_required()
def get_fourn_sync_status():
    return jsonify(_read_status('fournisseurs') or {'status': 'never'})


@finance_blueprint.route('/fournisseurs/sync', methods=['POST'])
@jwt_required()
def start_fourn_sync():
    """{"source": "sap"|"mf", "date_arrete": "YYYY-MM-DD"} : fournisseurs SAP crees
    a partir de date_arrete (absente = valeur de l'ecran Valeurs par defaut)."""
    saisie = (request.get_json(silent=True) or {}).get('date_arrete') or None
    try:
        date_arrete = date.fromisoformat(saisie) if saisie else None
    except (TypeError, ValueError):
        return jsonify({'error': f"Date d'arrêté invalide : {saisie}"}), 400

    return _start_sync('fournisseurs', FOURN_SAP_TABLES, 'clean_data.ifs_fournisseurs_perimetre',
                       lambda conn: conn.execute(
                           text('SELECT clean_data.alimenter_ifs_fournisseurs_perimetre(:d)'),
                           {'d': date_arrete}).scalar(),
                       extraire=_sync_source() == 'sap')


def _cellule(v):
    """Valeur Excel -> texte nettoye (Excel convertit 600001 en 600001.0)."""
    if v is None:
        return None
    if isinstance(v, float) and v.is_integer():
        v = int(v)
    return str(v).strip() or None


@finance_blueprint.route('/fournisseurs/import', methods=['POST'])
@jwt_required()
def import_fournisseurs_valides():
    """Fichier valide par le metier = l'export de l'ecran (onglet Fournisseurs),
    avec date_arrete (date de validation, obligatoire). Chaque fournisseur du
    fichier passe dans clean_data.ifs_fournisseurs_validation : il devient
    FICHIER, et son N° IFS / ID societe etrangere sont mis a jour quand la case
    est renseignee (case vide = valeur inchangee). Seules ces colonnes viennent
    du fichier. La date devient la date d'arrete par defaut, puis le perimetre
    est recalcule (comme le bouton Calculer)."""
    from openpyxl import load_workbook

    try:
        date_validation = date.fromisoformat(request.form.get('date_arrete') or '')
    except ValueError:
        return jsonify({'error': "Date d'arrêté (date de validation du fichier) obligatoire"}), 400
    fichier = request.files.get('file')
    if not fichier:
        return jsonify({'error': 'Aucun fichier'}), 400
    current = _read_status('fournisseurs')
    if current and current.get('status') == 'running':
        return jsonify({'error': 'Un calcul est deja en cours, reessayer a la fin.'}), 409

    try:
        wb = load_workbook(fichier, read_only=True, data_only=True)
    except Exception:
        return jsonify({'error': 'Fichier Excel (.xlsx) illisible'}), 400
    ws = wb['Fournisseurs'] if 'Fournisseurs' in wb.sheetnames else wb.active
    lignes = ws.iter_rows(values_only=True)
    entetes = [_cellule(h) for h in next(lignes, ())]
    index = {lib: entetes.index(lib) for lib in
             (FOURN_LIBELLE[c] for c in ('numero_compte_fournisseur', 'numero_compte_ifs', 'id_societe_etrangere'))
             if lib in entetes}
    cle = FOURN_LIBELLE['numero_compte_fournisseur']
    if cle not in index:
        return jsonify({'error': f"Colonne « {cle} » absente : importer le fichier exporté par l'écran"}), 400

    def lire(r, col):
        i = index.get(FOURN_LIBELLE[col])
        return _cellule(r[i]) if i is not None and i < len(r) else None

    saisies = {}
    for r in lignes:
        lifnr = lire(r, 'numero_compte_fournisseur')
        if lifnr:
            saisies[lifnr.zfill(10)] = {'ifs': lire(r, 'numero_compte_ifs'), 'etr': lire(r, 'id_societe_etrangere')}
    if not saisies:
        return jsonify({'error': 'Aucun fournisseur dans le fichier'}), 400

    inconnus = [r[0] for r in db.session.execute(
        text('SELECT k FROM unnest(CAST(:k AS text[])) k '
             'WHERE NOT EXISTS (SELECT 1 FROM raw_data.lfa1 a WHERE a.lifnr::text = k) ORDER BY k'),
        {'k': list(saisies)})]
    if inconnus:
        return jsonify({'error': f'{len(inconnus)} N° fournisseur SAP inconnus de SAP (LFA1) : '
                                 + ', '.join(inconnus[:20])}), 400

    user = str(get_jwt_identity() or 'finance-import')
    # Avant la mise a jour : ce que l'import change reellement (pour le compte rendu)
    avant = {r.numero_compte_fournisseur: r for r in db.session.execute(text(
        'SELECT numero_compte_fournisseur, source, numero_compte_ifs, id_societe_etrangere '
        'FROM clean_data.ifs_fournisseurs_perimetre WHERE numero_compte_fournisseur = ANY(:k)'),
        {'k': list(saisies)})}
    for lifnr, s in saisies.items():
        db.session.execute(text(
            'INSERT INTO clean_data.ifs_fournisseurs_validation AS v (numero_compte_fournisseur, '
            'numero_compte_ifs, id_societe_etrangere, date_validation, importe_par) '
            'VALUES (:k, :ifs, :etr, :d, :u) ON CONFLICT (numero_compte_fournisseur) DO UPDATE SET '
            'numero_compte_ifs = COALESCE(EXCLUDED.numero_compte_ifs, v.numero_compte_ifs), '
            'id_societe_etrangere = COALESCE(EXCLUDED.id_societe_etrangere, v.id_societe_etrangere), '
            'date_validation = EXCLUDED.date_validation, importe_le = CURRENT_TIMESTAMP, '
            'importe_par = EXCLUDED.importe_par'),
            {'k': lifnr, 'ifs': s['ifs'], 'etr': s['etr'], 'd': date_validation, 'u': user})

    # Un N° IFS ne designe qu'un fournisseur : refus (rien n'est ecrit) sinon
    doublons = db.session.execute(text(
        "SELECT ifs, string_agg(k, ', ' ORDER BY k) AS fournisseurs FROM ("
        " SELECT COALESCE(v.numero_compte_ifs, p.numero_compte_ifs) AS ifs,"
        "        COALESCE(v.numero_compte_fournisseur, p.numero_compte_fournisseur) AS k"
        "   FROM clean_data.ifs_fournisseurs_validation v"
        "   FULL JOIN clean_data.ifs_fournisseurs_perimetre p USING (numero_compte_fournisseur)) x"
        " WHERE ifs IS NOT NULL GROUP BY ifs HAVING count(*) > 1 ORDER BY ifs LIMIT 20")).all()
    if doublons:
        db.session.rollback()
        return jsonify({'error': 'Import refusé, N° IFS attribués à plusieurs fournisseurs : '
                                 + ' ; '.join(f'{d.ifs} ({d.fournisseurs})' for d in doublons)}), 400

    # La date de validation devient la date d'arrete par defaut (aussi lue par le script 01)
    db.session.execute(text(
        "INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, "
        "valeur, description, created_by, updated_by) VALUES ('supplier', 'clean_data.ifs_fournisseurs', "
        "'date_arrete', 'STANDARD', 'CONSTANTE', :d, 'Date d''arrete du fichier fournisseurs', :u, :u) "
        "ON CONFLICT (table_cible, colonne, variante) DO UPDATE SET valeur = EXCLUDED.valeur, "
        "type_valeur = 'CONSTANTE', is_active = TRUE, updated_at = CURRENT_TIMESTAMP, updated_by = :u"),
        {'d': date_validation.isoformat(), 'u': user})
    db.session.commit()

    resume = {
        'fournisseurs': len(saisies),
        'devenus_fichier': sum(1 for k in saisies if k in avant and avant[k].source == 'SAP_NOUVEAU'),
        'ifs_modifies': sum(1 for k, s in saisies.items()
                            if s['ifs'] and (k not in avant or avant[k].numero_compte_ifs != s['ifs'])),
        'id_etranger_modifies': sum(1 for k, s in saisies.items()
                                    if s['etr'] and (k not in avant or avant[k].id_societe_etrangere != s['etr'])),
        'date_arrete': date_validation.isoformat(),
    }
    reponse, code = _start_sync('fournisseurs', FOURN_SAP_TABLES, 'clean_data.ifs_fournisseurs_perimetre',
                                lambda conn: conn.execute(
                                    text('SELECT clean_data.alimenter_ifs_fournisseurs_perimetre(:d)'),
                                    {'d': date_validation}).scalar(),
                                extraire=False)
    return jsonify({'import': resume, 'sync': reponse.get_json()}), code


# ---------------------------------------------------------------------------
# Articles (clean_data.article_perimetre, sql/articleSap/article_perimetre.sql) :
# articles de article_sap, SAP_NOUVEAU = crees dans SAP depuis la date d'arrete.
# Colonnes affichees = clean_data.v_article_sap (ecran Donnees SAP > Articles).
# ---------------------------------------------------------------------------

ART_CLE = 'N° article'
ART_RECHERCHE = (ART_CLE, 'Description article', 'Ancien numéro article')
# Prefixe des colonnes du fichier valide (article_perimetre_validation.donnees)
ART_FICHIER = 'Fichier · '


def _art_colonnes():
    """[(cle, libelle, expression SQL)], params : Source, colonnes de v_article_sap,
    avec les colonnes du fichier valide inserees apres la description."""
    vue = [r[0] for r in db.session.execute(text(
        "SELECT column_name FROM information_schema.columns WHERE table_schema = 'clean_data' "
        "AND table_name = 'v_article_sap' ORDER BY ordinal_position"))]
    # ponytail: ordre alphabetique (jsonb ne garde pas l'ordre du fichier)
    fichier = [r[0] for r in db.session.execute(text(
        'SELECT DISTINCT k FROM clean_data.article_perimetre_validation, '
        'jsonb_object_keys(donnees) k ORDER BY 1'))]
    cols_vue = [(c, c, f'v."{c}"') for c in vue]
    cols_fichier = [(ART_FICHIER + n, ART_FICHIER + n, f'val.donnees ->> :f{i}') for i, n in enumerate(fichier)]
    i = vue.index('Description article') + 1 if 'Description article' in vue else len(vue)
    return ([('source', 'Source', 'p.source')] + cols_vue[:i] + cols_fichier + cols_vue[i:],
            {f'f{i}': n for i, n in enumerate(fichier)})


def _art_from():
    where, params = [], {}
    search = (request.args.get('search') or '').strip()
    if search:
        where.append('(' + ' OR '.join(f'v."{c}" ILIKE :s' for c in ART_RECHERCHE) + ')')
        params['s'] = f'%{search}%'
    if request.args.get('source') in ('FICHIER', 'SAP_NOUVEAU'):
        where.append('p.source = :source')
        params['source'] = request.args['source']
    clause = ('WHERE ' + ' AND '.join(where)) if where else ''
    return (f'FROM clean_data.article_perimetre p JOIN clean_data.v_article_sap v '
            f'ON v."{ART_CLE}" = p.numero_article '
            f'LEFT JOIN clean_data.article_perimetre_validation val ON val.numero_article = p.numero_article '
            f'{clause}'), params


def _art_charger(date_arrete):
    return lambda conn: conn.execute(
        text('SELECT clean_data.alimenter_article_perimetre(:d)'), {'d': date_arrete}).scalar()


@finance_blueprint.route('/articles', methods=['GET'])
@jwt_required()
def list_articles():
    """Filtres search (N°, description, ancien numero), source (FICHIER | SAP_NOUVEAU)."""
    page = max(int(request.args.get('page', 1)), 1)
    page_size = min(max(int(request.args.get('page_size', 50)), 1), 500)
    colonnes, cparams = _art_colonnes()
    sql_from, params = _art_from()
    rows = db.session.execute(
        text(f'SELECT {", ".join(e for _, _, e in colonnes)} {sql_from} '
             'ORDER BY p.source DESC, p.numero_article LIMIT :limit OFFSET :offset'),
        {**params, **cparams, 'limit': page_size, 'offset': (page - 1) * page_size}).all()
    total = db.session.execute(text(f'SELECT count(*) {sql_from}'), params).scalar()
    stats = db.session.execute(text(
        "SELECT count(*) AS total, count(*) FILTER (WHERE source = 'FICHIER') AS fichier, "
        "count(*) FILTER (WHERE source = 'SAP_NOUVEAU') AS sap_nouveau, "
        "COALESCE(max(date_arrete), NULLIF(TRIM(public.get_default_value("
        "'clean_data.article_perimetre', 'date_arrete')), '')::date) AS date_arrete "
        "FROM clean_data.article_perimetre")).mappings().one()
    return jsonify({
        'rows': [{c: _json(v) for (c, _, _), v in zip(colonnes, r)} for r in rows],
        'total': total,
        'page': page,
        'page_size': page_size,
        'stats': {k: _json(v) for k, v in stats.items()},
        'colonnes': [{'key': c, 'label': l, 'kind': 'text'} for c, l, _ in colonnes],
        'sync': _read_status('articles_perimetre'),
    })


@finance_blueprint.route('/articles/export.xlsx', methods=['GET'])
@jwt_required()
def export_articles_excel():
    from openpyxl import Workbook

    colonnes, cparams = _art_colonnes()
    sql_from, params = _art_from()
    rows = db.session.execute(
        text(f'SELECT {", ".join(e for _, _, e in colonnes)} {sql_from} '
             'ORDER BY p.source DESC, p.numero_article'), {**params, **cparams}).all()
    db.session.commit()  # liberer la transaction de lecture avant la generation
    wb = Workbook()
    _feuille_tableau(wb.active, 'Articles', [(c, l) for c, l, _ in colonnes], rows, set())
    return _envoyer(wb, 'articles')


@finance_blueprint.route('/articles/sync', methods=['GET'])
@jwt_required()
def get_art_sync_status():
    return jsonify(_read_status('articles_perimetre') or {'status': 'never'})


@finance_blueprint.route('/articles/sync', methods=['POST'])
@jwt_required()
def start_art_sync():
    """{"source": "sap"|"mf", "date_arrete": "YYYY-MM-DD"} ; 'sap' = extraction des
    tables articles + modules ETL articles (comme Donnees SAP > Articles) puis
    recalcul du perimetre ; 'mf' = recalcul du perimetre seul depuis article_sap."""
    from api.sap_articles import ARTICLE_SAP_TABLES, _charger_modules

    saisie = (request.get_json(silent=True) or {}).get('date_arrete') or None
    try:
        date_arrete = date.fromisoformat(saisie) if saisie else None
    except (TypeError, ValueError):
        return jsonify({'error': f"Date d'arrêté invalide : {saisie}"}), 400
    charger = _art_charger(date_arrete)
    if _sync_source() == 'sap':
        def load(conn):
            _charger_modules(conn, 'articles_perimetre')
            return charger(conn)
        return _start_sync('articles_perimetre', ARTICLE_SAP_TABLES, 'articles et périmètre', load)
    return _start_sync('articles_perimetre', [], 'clean_data.article_perimetre', charger, extraire=False)


# Import du fichier valide (page /finance/articles/import) : memes etapes et memes
# formats que l'import generique (api/import_generic.py), table cible imposee.
# Le fichier est analyse et stocke par /import-generic/analyze-file (fileId), puis
#   POST /articles/import/suggest-mapping   {fileId}            -> {mappings, targetColumns}
#   POST /articles/import/validate-mapping  {fileId, mappings}  -> {errors, warnings, previewData}
#   POST /articles/import/execute           {fileId, mappings, date_arrete} -> ImportResult
# Cibles : numero_article (cle, obligatoire) ; toute autre cible = une colonne du
# fichier conservee dans article_perimetre_validation.donnees sous ce nom.
ART_IMPORT_TABLE = 'clean_data.article_perimetre_validation'
ART_IMPORT_CLE = 'numero_article'


def _art_numero(v):
    """Cellule -> N° article tel que dans article_sap (sans zeros de tete s'il est numerique)."""
    import pandas as pd
    if v is None or (not isinstance(v, str) and pd.isna(v)):
        return None
    v = _cellule(v)
    return (v.lstrip('0') or '0') if v and v.isdigit() else v


def _art_fichier(file_id):
    from api.import_generic import temp_file_storage
    if not file_id or file_id not in temp_file_storage:
        return None
    return temp_file_storage[file_id]


def _art_controler(data):
    """Lit le fichier selon les mappings : (articles {numero: donnees}, rapport au format
    validate-mapping + compteurs), articles = None si le mapping est inutilisable."""
    import pandas as pd

    fichier = _art_fichier(data.get('fileId'))
    if fichier is None:
        return None, {'errors': [{'type': 'file', 'message': "Fichier introuvable ou expiré : recommencer l'import"}],
                      'warnings': [], 'previewData': []}
    df = fichier['dataframe']
    actifs = [m for m in data.get('mappings') or []
              if m.get('target') and not m.get('ignored') and m.get('source') in df.columns]
    cles = [m['source'] for m in actifs if m['target'] == ART_IMPORT_CLE]
    gardees = [(m['source'], m['target']) for m in actifs if m['target'] != ART_IMPORT_CLE]
    errors, warnings = [], []
    if len(cles) != 1:
        errors.append({'type': 'required', 'target': ART_IMPORT_CLE,
                       'message': f'Associer une et une seule colonne du fichier à « {ART_IMPORT_CLE} » (N° article)'})
        return None, {'errors': errors, 'warnings': warnings, 'previewData': []}

    articles, lignes, sans_numero, doublons = {}, [], 0, 0
    for i, (_, r) in enumerate(df.iterrows(), start=2):  # ligne 1 = en-tetes
        numero = _art_numero(r[cles[0]])
        if not numero:
            sans_numero += 1
            continue
        doublons += numero in articles
        # Derniere ligne gagnante ; cellule vide -> non stockee
        articles[numero] = {n: c for s, n in gardees
                            if (c := (None if pd.isna(r[s]) else _cellule(r[s]))) is not None}
        lignes.append((i, numero))
    connus = {r[0] for r in db.session.execute(text(
        f'SELECT a."{ART_CLE}" FROM clean_data.article_sap a WHERE a."{ART_CLE}" = ANY(:k)'),
        {'k': list(articles)})}
    inconnus = sorted(k for k in articles if k not in connus)
    if not articles:
        errors.append({'type': 'empty', 'message': 'Aucun N° article dans la colonne associée'})
    if inconnus:
        errors.append({'type': 'reference', 'source': cles[0], 'target': ART_IMPORT_CLE, 'count': len(inconnus),
                       'message': f'{len(inconnus)} N° article inconnus de la table des articles SAP : '
                                  + ', '.join(inconnus[:30]) + (' …' if len(inconnus) > 30 else '')})
    if sans_numero:
        warnings.append({'type': 'null', 'source': cles[0], 'count': sans_numero,
                         'message': f'{sans_numero} lignes sans N° article seront ignorées'})
    if doublons:
        warnings.append({'type': 'duplicate', 'source': cles[0], 'count': doublons,
                         'message': f"{doublons} lignes répètent un article déjà lu : la dernière l'emporte"})
    apercu = [{'rowNumber': i, 'data': {ART_IMPORT_CLE: k, **articles[k]},
               'errors': [] if k in connus else ['N° article inconnu de la table des articles SAP']}
              for i, k in lignes[:int(data.get('previewRows') or 10)]]
    return articles, {'errors': errors, 'warnings': warnings, 'previewData': apercu,
                      'nom_fichier': fichier['filename'], 'articles': len(articles)}


@finance_blueprint.route('/articles/import/suggest-mapping', methods=['POST'])
@jwt_required()
def suggerer_mapping_articles():
    """Mapping propose : la colonne « N° article » (a defaut celle dont le plus de
    valeurs sont des articles connus) -> numero_article ; les colonnes reprises de SAP
    par l'export de l'ecran (Source + v_article_sap) non mappees ; toutes les autres
    conservees sous leur nom d'en-tete."""
    fichier = _art_fichier((request.get_json(silent=True) or {}).get('fileId'))
    if fichier is None:
        return jsonify({'error': 'Fichier non trouvé ou expiré'}), 404
    df = fichier['dataframe']
    types = {c['name']: c.get('detectedType') for c in fichier.get('columns') or []}
    # + indicateurs calcules de l'export Donnees SAP > Articles (api/sap_articles.py)
    sap = {c for c, _, _ in _art_colonnes()[0] if not c.startswith(ART_FICHIER)} | {
        'Source', 'Dans la structure IH02', 'Lignes de nomenclature', 'Dans part_catalog', 'Anomalies'}

    reconnus = {}
    for col in df.columns:
        valeurs = list({n for n in (_art_numero(v) for v in df[col].head(2000)) if n})
        trouves = db.session.execute(text(
            f'SELECT count(*) FROM clean_data.article_sap WHERE "{ART_CLE}" = ANY(:k)'),
            {'k': valeurs}).scalar() if valeurs else 0
        reconnus[str(col)] = (trouves, len(valeurs))
    noms = [str(c) for c in df.columns]
    cle = ART_CLE if ART_CLE in noms else max(
        (c for c in noms if reconnus[c][0]), key=lambda c: reconnus[c][0], default=None)

    def nom_cible(col):
        return col[len(ART_FICHIER):] if col.startswith(ART_FICHIER) else col

    mappings = []
    for col in noms:
        if col == cle:
            trouves, total = reconnus[col]
            cible, confiance = ART_IMPORT_CLE, 100 if col == ART_CLE else round(100 * trouves / max(total, 1))
        elif col in sap:
            cible, confiance = None, 0
        else:
            cible, confiance = nom_cible(col), 100
        mappings.append({'source': col, 'sourceType': types.get(col) or 'text', 'target': cible,
                         'targetType': 'text' if cible else None, 'confidence': confiance,
                         'autoMapped': cible is not None, 'ignored': False})

    def colonne(nom, cle_primaire=False):
        return {'name': nom, 'data_type': 'text' if cle_primaire else 'text (donnees)',
                'is_nullable': 'NO' if cle_primaire else 'YES', 'column_default': None,
                'isRequired': cle_primaire, 'isPrimaryKey': cle_primaire,
                'constraints': ['PRIMARY KEY'] if cle_primaire else []}
    cibles = list(dict.fromkeys(nom_cible(c) for c in noms if c != cle))
    return jsonify({'mappings': mappings,
                    'targetColumns': [colonne(ART_IMPORT_CLE, True)] + [colonne(n) for n in cibles]})


@finance_blueprint.route('/articles/import/validate-mapping', methods=['POST'])
@jwt_required()
def valider_mapping_articles():
    _, rapport = _art_controler(request.get_json(silent=True) or {})
    return jsonify(rapport)


@finance_blueprint.route('/articles/import/execute', methods=['POST'])
@jwt_required()
def executer_import_articles():
    """Articles du fichier -> FICHIER (article_perimetre_validation, colonnes conservees
    fusionnees dans donnees), date de validation = date d'arrete par defaut, recalcul."""
    data = request.get_json(silent=True) or {}
    try:
        date_validation = date.fromisoformat(data.get('date_arrete') or '')
    except ValueError:
        return jsonify({'error': "Date d'arrêté (date de validation du fichier) obligatoire"}), 400
    current = _read_status('articles_perimetre')
    if current and current.get('status') == 'running':
        return jsonify({'error': 'Un calcul est deja en cours, reessayer a la fin.'}), 409
    articles, rapport = _art_controler(data)
    if rapport['errors']:
        return jsonify({'error': ' ; '.join(e['message'] for e in rapport['errors'])}), 400

    user = str(get_jwt_identity() or 'finance-import')
    existants = db.session.execute(text(
        f'SELECT count(*) FROM {ART_IMPORT_TABLE} WHERE numero_article = ANY(:k)'), {'k': list(articles)}).scalar()
    devenus_fichier = db.session.execute(text(
        "SELECT count(*) FROM clean_data.article_perimetre "
        "WHERE source = 'SAP_NOUVEAU' AND numero_article = ANY(:k)"), {'k': list(articles)}).scalar()
    db.session.execute(text(
        f'INSERT INTO {ART_IMPORT_TABLE} AS v '
        '(numero_article, donnees, nom_fichier, date_validation, importe_par) '
        'SELECT k, d::jsonb, :f, :dv, :u FROM unnest(CAST(:k AS text[]), CAST(:d AS text[])) AS t(k, d) '
        'ON CONFLICT (numero_article) DO UPDATE SET donnees = v.donnees || EXCLUDED.donnees, '
        'nom_fichier = EXCLUDED.nom_fichier, date_validation = EXCLUDED.date_validation, '
        'importe_le = CURRENT_TIMESTAMP, importe_par = EXCLUDED.importe_par'),
        {'k': list(articles), 'd': [json.dumps(d, ensure_ascii=False) for d in articles.values()],
         'f': rapport['nom_fichier'], 'dv': date_validation, 'u': user})
    db.session.execute(text(
        "INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, "
        "valeur, description, created_by, updated_by) VALUES ('articleSap', 'clean_data.article_perimetre', "
        "'date_arrete', 'STANDARD', 'CONSTANTE', :d, 'Date d''arrete du fichier articles', :u, :u) "
        "ON CONFLICT (table_cible, colonne, variante) DO UPDATE SET valeur = EXCLUDED.valeur, "
        "type_valeur = 'CONSTANTE', is_active = TRUE, updated_at = CURRENT_TIMESTAMP, updated_by = :u"),
        {'d': date_validation.isoformat(), 'u': user})
    db.session.commit()

    from api.import_generic import temp_file_storage
    del temp_file_storage[data['fileId']]
    reponse, _ = _start_sync('articles_perimetre', [], 'clean_data.article_perimetre',
                             _art_charger(date_validation), extraire=False)
    return jsonify({
        'success': True,
        'message': (f"{len(articles)} articles importés ({devenus_fichier} SAP_NOUVEAU passés en FICHIER). "
                    f"Date d'arrêté fixée au {date_validation:%d/%m/%Y}, recalcul du périmètre lancé."),
        'successCount': len(articles),
        'insertedCount': len(articles) - existants,
        'updatedCount': existants,
        'errorCount': 0,
        'errors': [],
        'targetTable': ART_IMPORT_TABLE,
        'mode': 'upsert',
        'sync': reponse.get_json(),
    })


# ---------------------------------------------------------------------------
# Communs : export Excel, synchronisation SAP
# ---------------------------------------------------------------------------

def _feuille_tableau(ws, title, libelles, rows, numeriques):
    """Feuille tableau : en-tetes metier, dates et nombres types, en-tete fige + filtres."""
    from openpyxl.cell.cell import ILLEGAL_CHARACTERS_RE
    from openpyxl.styles import Alignment, Font, PatternFill

    colonnes = [c for c, _ in libelles]
    ws.title = title[:31]
    ws.append([l for _, l in libelles])
    for cell in ws[1]:
        cell.font = Font(bold=True, color='FFFFFF')
        cell.fill = PatternFill('solid', fgColor='1F4E78')
        cell.alignment = Alignment(wrap_text=True, vertical='top')
    ws.row_dimensions[1].height = 45
    # ws.max_row / ws[n] parcourent toutes les cellules : indices tenus a la main,
    # sinon l'export est quadratique (7 748 x 60 cellules -> ne se termine pas).
    for i, r in enumerate(rows, 2):
        # Caracteres de controle (presents dans les textes longs SAP) refuses par
        # Excel : openpyxl leve IllegalCharacterError -> on les retire.
        ws.append([float(v) if isinstance(v, Decimal)
                   else ('Oui' if v else 'Non') if isinstance(v, bool)
                   else ILLEGAL_CHARACTERS_RE.sub('', v) if isinstance(v, str) else v
                   for v in r])
        for j in range(1, len(colonnes) + 1):
            cell = ws.cell(i, j)
            # Texte SAP commencant par '=' : openpyxl en ferait une formule -> forcer le texte
            if cell.data_type == 'f':
                cell.data_type = 's'
            elif isinstance(cell.value, (date, datetime)):
                cell.number_format = 'DD/MM/YYYY'

    for idx, col in enumerate(colonnes, 1):
        letter = ws.cell(1, idx).column_letter
        long = col.startswith(('libelle', 'designation', 'nom_', 'adresse'))
        ws.column_dimensions[letter].width = 34 if long else 16
        if col in numeriques:
            for (cell,) in ws.iter_rows(min_row=2, min_col=idx, max_col=idx):
                cell.number_format = '#,##0.00'
    ws.freeze_panes = 'C2'
    ws.auto_filter.ref = ws.dimensions


def _feuille_synthese(ws, synthese):
    """Feuille Synthese : en-tete, KPI, un bloc par axe (valeurs, pas de formules)."""
    from openpyxl.styles import Font, PatternFill

    titre = Font(bold=True, color='FFFFFF')
    fond = PatternFill('solid', fgColor='1F4E78')
    sous = PatternFill('solid', fgColor='5B9BD5')
    kpi = synthese['kpi']
    ws['A1'] = 'Synthèse des immobilisations statutaires'
    ws['A1'].font = Font(bold=True, size=14)
    for i, (k, v) in enumerate([('Société', 'STJN'), ('Date de situation', kpi.get('date_situation')),
                                ('Exercice SAP', kpi.get('exercice')), ('Zone retenue', kpi.get('zone'))], 2):
        ws.cell(i, 1, k)
        ws.cell(i, 2, v)
    ws.cell(7, 1, 'Indicateurs').font = titre
    ws.cell(7, 1).fill = fond
    for i, (k, v) in enumerate([("Nombre d'immobilisations", kpi.get('nombre')),
                                ("Valeur d'acquisition à l'arrêté", kpi.get('acquisition')),
                                ('Amortissements cumulés', kpi.get('amortissements')),
                                ('Valeur nette comptable', kpi.get('vnc'))], 8):
        ws.cell(i, 1, k)
        ws.cell(i, 2, v).number_format = '#,##0.00'
    ligne = 13
    for key, _, bloc in _SYNTHESE_AXES:
        for j, h in enumerate([bloc, 'Nombre', 'Acquisition', 'Amortissements cumulés', 'VNC'], 1):
            c = ws.cell(ligne, j, h)
            c.font = titre
            c.fill = sous
        for item in synthese[key]:
            ligne += 1
            ws.cell(ligne, 1, item['libelle'])
            ws.cell(ligne, 2, item['nombre'])
            for j, k in enumerate(('acquisition', 'amortissements', 'vnc'), 3):
                ws.cell(ligne, j, item[k]).number_format = '#,##0.00'
        ligne += 2
    for col, w in zip('ABCDE', (48, 14, 20, 24, 20)):
        ws.column_dimensions[col].width = w


def _envoyer(wb, prefix):
    buffer = io.BytesIO()
    wb.save(buffer)
    buffer.seek(0)
    return send_file(
        buffer, as_attachment=True,
        download_name=f'{prefix}_{datetime.now():%Y%m%d_%H%M}.xlsx',
        mimetype='application/vnd.openxmlformats-officedocument.spreadsheetml.sheet')


def _start_sync(key, tables, cible, load, extraire=True):
    """Lance (extraction SAP +) rechargement dans un thread ; 409 si deja en cours."""
    current = _read_status(key)
    if current and current.get('status') == 'running':
        return jsonify({'error': 'Une synchronisation est deja en cours.', **current}), 409

    user = str(get_jwt_identity() or 'finance-sync')
    status = _write_status(
        key, status='running', step='Demarrage', progress=0, error=None, rows=None, warning=None,
        source='sap' if extraire else 'mf',
        started_at=_now(), finished_at=None, started_by=user, extraction_id=None,
    )
    app = current_app._get_current_object()
    threading.Thread(target=_run_sync, args=(app, user, key, tables, cible, load, extraire),
                     daemon=True, name=f'{key}-sync').start()
    return jsonify(status), 202


def _run_sync(app, user, key, tables, cible, load, extraire):
    with app.app_context():
        try:
            if extraire:
                _extract(user, key, tables)
            _write_status(key, step=f'Rechargement de {cible}', progress=90)
            with db.engine.begin() as conn:
                rows = load(conn)
            _write_status(key, status='completed', step='Termine', progress=100,
                          rows=rows, finished_at=_now())
        except Exception as e:  # le thread ne doit jamais mourir en silence
            logger.error(f'Synchronisation {key} en echec : {e}')
            _write_status(key, status='failed', error=str(e), finished_at=_now())


def _extract(user, key, tables):
    """Extraction SAP (differentielle) des tables sources, attente de la fin."""
    from services.extraction_service import extraction_service

    _write_status(key, step=f'Extraction SAP ({len(tables)} tables)', progress=5)
    result = extraction_service.start_extraction(
        tables=tables, options={'mode': 'standard'}, user_id=user)
    extraction_id = result.get('extraction_id')
    if not extraction_id:
        raise RuntimeError("Le conteneur d'extraction SAP n'a pas renvoye d'identifiant.")
    _write_status(key, extraction_id=extraction_id)

    deadline = time.time() + EXTRACTION_TIMEOUT_SECONDS
    while time.time() < deadline:
        time.sleep(EXTRACTION_POLL_SECONDS)
        try:
            payload = extraction_service.get_extraction_status(extraction_id)
        except Exception as e:
            logger.warning(f'Statut extraction {extraction_id} indisponible ({e}), nouvel essai.')
            continue
        status = (payload.get('status') or 'running').lower()
        if status in ('completed', 'success', 'done', 'finished'):
            return
        if status in ('failed', 'error'):
            raise RuntimeError(f"L'extraction SAP a echoue : {payload.get('error_message') or 'cause inconnue'}")
        if status in ('stopped', 'cancelled', 'canceled'):
            raise RuntimeError("L'extraction SAP a ete interrompue.")
        progress = payload.get('progress_percentage')
        if progress is not None:
            # L'extraction occupe la plage 5 % -> 85 %.
            _write_status(key, progress=5 + int(float(progress) * 0.8))
    raise RuntimeError(f"Extraction SAP non terminee apres {EXTRACTION_TIMEOUT_SECONDS // 60} min.")
