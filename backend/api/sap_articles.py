"""Ecran Donnees SAP > Articles (/sap-data/articles) : lecture de
clean_data.v_article_sap (perimetre STJN + maintenance, une ligne par article,
cf. sql/articleSap/), enrichie de deux indicateurs calcules a la volee :
presence dans la structure de maintenance IH02 (maintenance_object) et dans le
catalogue IFS (clean_data.part_catalog).

  GET /api/v1/sap-data/articles              liste paginee (filtres, recherche, tri)
  GET /api/v1/sap-data/articles/facettes     compteurs par valeur de chaque filtre
                                              (chaque facette ignore son propre filtre)
                                              + compteurs d'anomalies
  GET /api/v1/sap-data/articles/groupes      regroupement par gestionnaire / groupe d'achat
  GET /api/v1/sap-data/articles/export.xlsx  selection filtree, toutes les colonnes
  GET /api/v1/sap-data/articles/<numero>     fiche article + usages en maintenance
  GET /api/v1/sap-data/articles/sync         etat de la derniere synchronisation
  POST /api/v1/sap-data/articles/sync        {"source": "sap"} extraction SAP puis modules ETL
                                              articles (part_catalog, tables IFS, article_sap) ;
                                              {"source": "mf"} modules ETL seuls

Filtres (query string) : search, une cle par facette (valeurs separees par des
virgules, VIDE = valeur absente), anomalie (une cle d'ANOMALIES ou 'toutes').
"""
import logging

from flask import Blueprint, jsonify, request
from flask_jwt_extended import jwt_required
from sqlalchemy import text

from models import db

sap_articles_blueprint = Blueprint('sap_articles', __name__)
logger = logging.getLogger(__name__)

VIDE = '__vide__'


def q(col):
    return '"' + col.replace('"', '""') + '"'


# cle -> (colonne code, colonne libelle ou None, titre)
FACETTES = {
    'site': ('Site', 'Site Description', 'Site'),
    'classe': ("Classe d'actifs", "Classe d'actifs Description", "Classe d'actifs"),
    'categorie': ('Catégorie article', 'Catégorie article Description', 'Catégorie'),
    'groupe_achat': ("Groupe d'achat", "Groupe d'achat Description", "Groupe d'achat"),
    'statut': ('Statut article', None, 'Statut'),
    'planification': ('Type de planification', None, 'Planification'),
    'gestionnaire': ('Gestionnaire', None, 'Gestionnaire'),
}

# cle -> (libelle, condition SQL sur la base)
ANOMALIES = {
    'sans_description': ('Sans description',
                         """ltrim("Description article", '0') = "N° article" """),
    'sans_groupe_achat': ("Sans groupe d'achat",
                          """"Catégorie article" <> 'IBAU' AND "Groupe d'achat" IS NULL"""),
    'sans_unite': ('Sans unité', '"U/M Stock" IS NULL'),
    'dormant': ('Inchangé depuis plus de 10 ans',
                """COALESCE(to_date("Date de dernière modification", 'DD/MM/YYYY'),
                            to_date("Date de création", 'DD/MM/YYYY'))
                   < current_date - interval '10 years'"""),
    'sans_stock': ('Stockable sans stock ni emplacement',
                   """("Classe d'actifs" = 'MAGASIN' OR "Catégorie article" = 'ERSA')
                      AND "EMPLACEMENT" IS NULL AND COALESCE("Qté en stock", '0')::numeric = 0"""),
}

GROUPEMENTS = {
    'gestionnaire': ('Gestionnaire', None),
    'groupe_achat': ("Groupe d'achat", "Groupe d'achat Description"),
}

# Vue + indicateurs calcules : nb_usages = lignes de nomenclature IH02 qui
# referencent l'article ; dans_structure = noeud ARTICLE actif ; dans_catalogue
# = present dans part_catalog (catalogue IFS).
BASE = f"""
WITH mo AS (
    SELECT ltrim(a.sap_key, '0') AS k, count(b.id) AS nb
      FROM clean_data.maintenance_object a
      LEFT JOIN clean_data.maintenance_object b
        ON b.ref_object_id = a.id AND b.object_type = 'BOM_ITEM' AND b.is_active
     WHERE a.object_type = 'ARTICLE' AND a.is_active
     GROUP BY 1
), pc AS (SELECT DISTINCT part_no FROM clean_data.part_catalog),
base AS (
    SELECT v.*,
           mo.k IS NOT NULL AS dans_structure,
           COALESCE(mo.nb, 0) AS nb_usages,
           pc.part_no IS NOT NULL AS dans_catalogue,
           {', '.join(f'({sql}) IS TRUE AS {k}' for k, (_, sql) in ANOMALIES.items())}
      FROM clean_data.v_article_sap v
      LEFT JOIN mo ON mo.k = v."N° article"
      LEFT JOIN pc ON pc.part_no = v."N° article"
)
"""

_colonnes_cache = []


def _colonnes():
    """Colonnes de la vue, dans son ordre (sert au tri et a l'export)."""
    if not _colonnes_cache:
        _colonnes_cache.extend(r[0] for r in db.session.execute(text(
            "SELECT column_name FROM information_schema.columns "
            "WHERE table_schema = 'clean_data' AND table_name = 'v_article_sap' "
            "ORDER BY ordinal_position")))
    return _colonnes_cache


def _filtres(sauf=None):
    """Clause WHERE + parametres ; `sauf` = facette dont on ignore le filtre."""
    where, params = [], {}
    search = (request.args.get('search') or '').strip()
    if search:
        where.append('("N° article" ILIKE :s OR "Description article" ILIKE :s '
                     'OR "Ancien numéro article" ILIKE :s OR "Texte de commande" ILIKE :s '
                     'OR "Note interne" ILIKE :s OR "Texte de base" ILIKE :s)')
        params['s'] = f'%{search}%'
    for cle, (col, _, _) in FACETTES.items():
        brut = request.args.get(cle)
        if cle == sauf or not brut:
            continue
        valeurs = [v for v in brut.split(',') if v]
        conds = []
        if VIDE in valeurs:
            conds.append(f'{q(col)} IS NULL')
        autres = [v for v in valeurs if v != VIDE]
        if autres:
            conds.append(f'{q(col)} = ANY(:f_{cle})')
            params[f'f_{cle}'] = autres
        where.append('(' + ' OR '.join(conds) + ')')
    anomalie = request.args.get('anomalie')
    if anomalie == 'toutes':
        where.append('(' + ' OR '.join(ANOMALIES) + ')')
    elif anomalie in ANOMALIES:
        where.append(anomalie)
    structure = request.args.get('structure')
    if structure == 'oui':
        where.append('dans_structure')
    elif structure == 'non':
        where.append('NOT dans_structure')
    return ('WHERE ' + ' AND '.join(where)) if where else '', params


def _ligne(r):
    d = dict(r)
    d['anomalies'] = [k for k in ANOMALIES if d.pop(k, False)]
    return d


@sap_articles_blueprint.route('', methods=['GET'])
@jwt_required()
def liste():
    page = max(int(request.args.get('page', 1)), 1)
    page_size = min(max(int(request.args.get('page_size', 50)), 1), 500)
    clause, params = _filtres()
    tri = request.args.get('sort') if request.args.get('sort') in _colonnes() else 'N° article'
    sens = 'DESC' if request.args.get('dir') == 'desc' else 'ASC'
    # Dates JJ/MM/AAAA et quantite stockees en texte : tri sur la valeur typee
    if tri.startswith('Date'):
        ordre = f"to_date({q(tri)}, 'DD/MM/YYYY')"
    elif tri in ('Qté en stock', 'Point de commande', "Délai d'achat"):
        ordre = f'{q(tri)}::numeric'
    else:
        ordre = q(tri)
    total = db.session.execute(text(f'{BASE} SELECT count(*) FROM base {clause}'), params).scalar()
    rows = db.session.execute(text(
        f'{BASE} SELECT * FROM base {clause} '
        f'ORDER BY {ordre} {sens} NULLS LAST, "N° article" LIMIT :limit OFFSET :offset'),
        {**params, 'limit': page_size, 'offset': (page - 1) * page_size}).mappings().all()
    return jsonify({'rows': [_ligne(r) for r in rows], 'total': total,
                    'colonnes': _colonnes()})


@sap_articles_blueprint.route('/facettes', methods=['GET'])
@jwt_required()
def facettes():
    resultat = {}
    for cle, (col, lib, titre) in FACETTES.items():
        clause, params = _filtres(sauf=cle)
        libelle = f'max({q(lib)})' if lib else 'NULL'
        rows = db.session.execute(text(
            f'{BASE} SELECT {q(col)} AS code, {libelle} AS libelle, count(*) AS nb '
            f'FROM base {clause} GROUP BY 1 ORDER BY 3 DESC'), params).mappings().all()
        resultat[cle] = {'titre': titre,
                         'valeurs': [{'code': r['code'] if r['code'] is not None else VIDE,
                                      'libelle': r['libelle'], 'nb': r['nb']} for r in rows]}
    clause, params = _filtres()
    compteurs = db.session.execute(text(
        f'{BASE} SELECT count(*) AS total, count(*) FILTER (WHERE dans_structure) AS structure, '
        'count(*) FILTER (WHERE dans_catalogue) AS catalogue, '
        + ', '.join(f'count(*) FILTER (WHERE {k}) AS {k}' for k in ANOMALIES)
        + f', count(*) FILTER (WHERE {" OR ".join(ANOMALIES)}) AS toutes '
        f'FROM base {clause}'), params).mappings().one()
    return jsonify({
        'facettes': resultat,
        'total': compteurs['total'],
        'structure': compteurs['structure'],
        'catalogue': compteurs['catalogue'],
        'anomalies': [{'cle': k, 'libelle': lib, 'nb': compteurs[k]}
                      for k, (lib, _) in ANOMALIES.items()],
        'anomalies_total': compteurs['toutes'],
    })


@sap_articles_blueprint.route('/groupes', methods=['GET'])
@jwt_required()
def groupes():
    par = request.args.get('par') if request.args.get('par') in GROUPEMENTS else 'gestionnaire'
    col, lib = GROUPEMENTS[par]
    clause, params = _filtres()
    rows = db.session.execute(text(
        f'{BASE} SELECT {q(col)} AS code, {f"max({q(lib)})" if lib else "NULL"} AS libelle, '
        'count(*) AS articles, '
        'count(*) FILTER (WHERE COALESCE("Qté en stock", \'0\')::numeric <> 0) AS en_stock, '
        'count(*) FILTER (WHERE dans_structure) AS en_maintenance, '
        f'count(*) FILTER (WHERE {" OR ".join(ANOMALIES)}) AS anomalies, '
        'string_agg(DISTINCT "Site", \', \') AS sites '
        f'FROM base {clause} GROUP BY 1 ORDER BY 3 DESC'), params).mappings().all()
    return jsonify({'par': par, 'groupes': [
        {**dict(r), 'code': r['code'] if r['code'] is not None else VIDE} for r in rows]})


@sap_articles_blueprint.route('/export.xlsx', methods=['GET'])
@jwt_required()
def export_excel():
    from openpyxl import Workbook

    from api.finance import _envoyer, _feuille_tableau

    clause, params = _filtres()
    cols = _colonnes()
    rows = db.session.execute(text(
        f'{BASE} SELECT * FROM base {clause} ORDER BY "N° article"'), params).mappings().all()
    db.session.commit()
    entetes = [(c, c) for c in cols] + [('dans_structure', 'Dans la structure IH02'),
                                        ('nb_usages', 'Lignes de nomenclature'),
                                        ('dans_catalogue', 'Dans part_catalog'),
                                        ('anomalies', 'Anomalies')]
    wb = Workbook()
    _feuille_tableau(wb.active, 'Articles SAP', entetes,
                     [[r[c] for c in cols] + [r['dans_structure'], r['nb_usages'], r['dans_catalogue'],
                                              ', '.join(ANOMALIES[k][0] for k in ANOMALIES if r[k])]
                      for r in rows], set())
    return _envoyer(wb, 'articles_sap')


# ---------------------------------------------------------------------------
# Synchronisation : (extraction SAP differentielle +) modules ETL articles dans
# l'ordre de l'ecran ETL. Meme mecanique que les ecrans Finance (thread, etat
# partage entre workers, une synchro a la fois -> 409).
# ---------------------------------------------------------------------------
# Tables SAP lues par la chaine articles (alimenter_ifs_article -> part_catalog ->
# inventory/purchase/sales_part, article_sap). Les textes longs (STXH/STXL)
# passent par l'ecran Extraction > Textes longs SAP.
ARTICLE_SAP_TABLES = ['MARA', 'MAKT', 'MARC', 'MARD', 'MBEW', 'MVKE', 'EINA', 'EINE', 'EORD',
                      'LFA1', 'T001W', 'T023T', 'T134', 'T134T', 'T025T', 'T024', 'T179T',
                      'T006A', 'USR21', 'ADRP']
# Modules ETL de etl_target_tables, executes par ordre d'execution : le module
# Article SAP vide part_catalog, PHL / Composants (ordre 12) le completent ensuite.
ARTICLE_MODULES = ('etl_inventory_part.py', 'etl_article_sap.py',
                   'etl_phl_article.py', 'etl_composant_article.py')


def _charger_modules(conn):
    import importlib.util
    import inspect
    import os

    from api.finance import _write_status

    modules = conn.execute(text(
        'SELECT display_name, python_module, module_params FROM public.etl_target_tables '
        'WHERE python_module = ANY(:m) AND is_active ORDER BY execution_order, id'),
        {'m': list(ARTICLE_MODULES)}).mappings().all()
    dossier = os.path.join(os.path.dirname(os.path.dirname(__file__)), 'etl_modules')
    for i, m in enumerate(modules, 1):
        _write_status('articles_sap', step=f"{i}/{len(modules)} {m['display_name']}",
                      progress=90 + int(9 * (i - 1) / len(modules)))
        spec = importlib.util.spec_from_file_location(m['python_module'][:-3],
                                                      os.path.join(dossier, m['python_module']))
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        params = m['module_params'] or {}
        accepte = inspect.signature(module.run_etl).parameters
        resultat = module.run_etl(**{k: v for k, v in params.items() if k in accepte})
        if not resultat.get('success'):
            raise RuntimeError(f"{m['display_name']} : {resultat.get('error', 'erreur inconnue')}")
    return conn.execute(text('SELECT count(*) FROM clean_data.article_sap')).scalar()


@sap_articles_blueprint.route('/sync', methods=['GET'])
@jwt_required()
def statut_sync():
    from api.finance import _read_status
    return jsonify(_read_status('articles_sap') or {'status': 'never'})


@sap_articles_blueprint.route('/sync', methods=['POST'])
@jwt_required()
def lancer_sync():
    """{"source": "sap"} (defaut) : extraction SAP puis modules ETL ; {"source": "mf"} :
    modules ETL seuls (recalcul depuis raw_data : part_catalog, tables IFS, article_sap)."""
    from api.finance import _start_sync, _sync_source
    return _start_sync('articles_sap', ARTICLE_SAP_TABLES, 'articles et catalogue IFS',
                       _charger_modules, extraire=_sync_source() == 'sap')


@sap_articles_blueprint.route('/<path:numero>', methods=['GET'])
@jwt_required()
def fiche(numero):
    r = db.session.execute(text(f'{BASE} SELECT * FROM base WHERE "N° article" = :n'),
                           {'n': numero}).mappings().first()
    if not r:
        return jsonify({'error': 'Article introuvable'}), 404
    # Postes techniques dont la nomenclature cite l'article (via ses lignes BOM_ITEM)
    usages = db.session.execute(text("""
        SELECT p.object_type, p.code, p.designation, count(*) AS lignes,
               sum(b.quantity) AS quantite
          FROM clean_data.maintenance_object a
          JOIN clean_data.maintenance_object b
            ON b.ref_object_id = a.id AND b.object_type = 'BOM_ITEM' AND b.is_active
          JOIN clean_data.maintenance_object p ON p.id = b.parent_id AND p.is_active
         WHERE a.object_type = 'ARTICLE' AND a.is_active AND ltrim(a.sap_key, '0') = :n
         GROUP BY 1, 2, 3 ORDER BY 2 LIMIT 50"""), {'n': numero}).mappings().all()
    return jsonify({'article': _ligne(r),
                    'anomalies_libelles': {k: lib for k, (lib, _) in ANOMALIES.items()},
                    'usages': [dict(u) for u in usages]})
