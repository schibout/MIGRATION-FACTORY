"""Ecran Maintenance > Equipements (/maintenance/equipment) : liste filtrable des
equipements SAP (raw_data.equi, segment courant de equz, description eqkt F > N >
autre), enrichie de la structure IH02 (clean_data.maintenance_object), de l'article
(equi.matnr) et du type de construction (equz.submt) lus dans clean_data.article_sap,
des statuts systeme actifs (jest + tj02t) et du poste de travail (crhd / crtx).
La fiche, la creation, la modification et la suppression restent dans
api/maintenance_hierarchy.py (/maintenance/equipment...).

  GET /api/v1/maintenance/equipment-browser                 liste paginee
  GET /api/v1/maintenance/equipment-browser/facettes        compteurs par valeur
                                                             (chaque facette ignore son filtre)
  GET /api/v1/maintenance/equipment-browser/export.xlsx     selection filtree
  GET /api/v1/maintenance/equipment-browser/<equnr>/structure  chemin dans l'arbre + fils

Filtres : search, une cle par facette (valeurs separees par des virgules, VIDE =
valeur absente), anomalie (cle d'ANOMALIES ou 'toutes').
"""
from flask import Blueprint, jsonify, request
from flask_jwt_extended import jwt_required
from sqlalchemy import text

from models import db

equipment_browser_blueprint = Blueprint('equipment_browser', __name__)

VIDE = '__vide__'

# MATERIALIZED : sans lui PostgreSQL deplie les CTE dans la requete et choisit des
# boucles imbriquees sur les tables SAP (liste 15 s, facettes 105 s).
BASE = """
WITH z AS MATERIALIZED (
    SELECT DISTINCT ON (equnr) equnr, NULLIF(TRIM(iwerk), '') AS iwerk, NULLIF(TRIM(gewrk), '') AS gewrk,
           NULLIF(LTRIM(TRIM(submt), '0'), '') AS construction
      FROM raw_data.equz WHERE mandt = '700'
     ORDER BY equnr, datbi DESC
), d AS MATERIALIZED (
    SELECT DISTINCT ON (equnr) equnr, TRIM(eqktx) AS eqktx, spras
      FROM raw_data.eqkt WHERE mandt = '700'
     ORDER BY equnr, CASE spras WHEN 'F' THEN 1 WHEN 'N' THEN 2 ELSE 3 END
), st AS MATERIALIZED (
    -- jest porte les statuts de TOUS les objets SAP (4,1 M lignes) : partir des equipements
    SELECT q.objnr, array_agg(j.stat ORDER BY j.stat) AS statuts
      FROM raw_data.equi q
      JOIN raw_data.jest j ON j.mandt = q.mandt AND j.objnr = q.objnr
     WHERE q.mandt = '700' AND j.stat LIKE 'I%' AND (j.inact IS NULL OR j.inact = '')
     GROUP BY q.objnr
), mo AS MATERIALIZED (
    SELECT e.sap_key, e.id AS mo_id, p.object_type AS parent_type, p.code AS parent_code,
           p.designation AS parent_designation
      FROM clean_data.maintenance_object e
      LEFT JOIN clean_data.maintenance_object p ON p.id = e.parent_id
     WHERE e.object_type = 'EQUIPMENT' AND e.is_active
), refs AS MATERIALIZED (
    -- Numeros d'article portes par les equipements (n° article + type de construction)
    SELECT NULLIF(LTRIM(TRIM(matnr), '0'), '') AS k FROM raw_data.equi
     WHERE mandt = '700' AND NULLIF(TRIM(matnr), '') IS NOT NULL
    UNION
    SELECT construction FROM z WHERE construction IS NOT NULL
), ref AS MATERIALIZED (
    -- Recherche elargie aux articles hors perimetre (supprimes, etc.) : designation
    -- SAP + statut expliquant pourquoi l'article n'est pas dans article_sap.
    SELECT DISTINCT ON (r.k) r.k,
           COALESCE(a."Description article", NULLIF(TRIM(mk.maktx), '')) AS description,
           COALESCE(a."Catégorie article", NULLIF(TRIM(m.mtart), '')) AS categorie,
           CASE WHEN a."N° article" IS NOT NULL THEN 'CATALOGUE'
                WHEN m.matnr IS NULL THEN 'INEXISTANT'
                WHEN COALESCE(m.lvorm, '') <> '' THEN 'SUPPRIME'
                WHEN EXISTS (SELECT 1 FROM raw_data.marc c WHERE c.mandt = '700' AND c.matnr = m.matnr
                                AND c.werks IN ('9200', '9000') AND COALESCE(c.lvorm, '') <> '')
                  OR (EXISTS (SELECT 1 FROM raw_data.marc c WHERE c.mandt = '700' AND c.matnr = m.matnr)
                      AND NOT EXISTS (SELECT 1 FROM raw_data.marc c WHERE c.mandt = '700' AND c.matnr = m.matnr
                                         AND COALESCE(c.lvorm, '') = ''))
                  THEN 'SUPPRIME_DIVISION'
                ELSE 'HORS_PERIMETRE' END AS statut
      FROM refs r
      LEFT JOIN clean_data.article_sap a ON a."N° article" = r.k
      -- egalite simple (jointure par hachage) : un IN (k, lpad(k)) faisait 10 s
      LEFT JOIN raw_data.mara m ON m.mandt = '700' AND ltrim(m.matnr, '0') = r.k
      LEFT JOIN raw_data.makt mk ON mk.mandt = '700' AND mk.matnr = m.matnr AND mk.spras = 'F'
     ORDER BY r.k, mk.maktx NULLS LAST
), base AS MATERIALIZED (
    SELECT e.equnr AS id,
           LTRIM(e.equnr, '0') AS numero,
           COALESCE(d.eqktx, 'Équipement ' || LTRIM(e.equnr, '0')) AS description,
           d.spras AS langue_description,
           NULLIF(TRIM(e.eqtyp), '') AS categorie,
           NULLIF(TRIM(e.eqart), '') AS type_objet,
           NULLIF(LTRIM(TRIM(e.matnr), '0'), '') AS article,
           ra.description AS article_description,
           ra.categorie AS article_categorie,
           ra.statut AS article_statut,
           z.construction,
           rc.description AS construction_description,
           rc.categorie AS construction_categorie,
           rc.statut AS construction_statut,
           COALESCE(ra.statut, rc.statut, 'AUCUN') AS statut_article,
           CASE WHEN NULLIF(TRIM(e.matnr), '') IS NOT NULL THEN 'ARTICLE'
                WHEN z.construction IS NOT NULL THEN 'CONSTRUCTION'
                ELSE 'AUCUN' END AS lien_article,
           NULLIF(TRIM(e.herst), '') AS fabricant,
           NULLIF(TRIM(e.typbz), '') AS modele,
           NULLIF(TRIM(e.sernr), '') AS numero_serie,
           NULLIF(TRIM(e.invnr), '') AS numero_inventaire,
           z.iwerk AS division,
           w.name1 AS division_description,
           c.arbpl AS poste_travail,
           ct.ktext AS poste_travail_description,
           COALESCE(st.statuts, '{}') AS statuts,
           CASE WHEN mo.sap_key IS NULL THEN 'HORS_STRUCTURE'
                WHEN mo.parent_type IS NULL THEN 'SANS_PARENT'
                ELSE mo.parent_type END AS position,
           mo.parent_code, mo.parent_designation
      FROM raw_data.equi e
      LEFT JOIN z ON z.equnr = e.equnr
      LEFT JOIN d ON d.equnr = e.equnr
      LEFT JOIN st ON st.objnr = e.objnr
      LEFT JOIN mo ON mo.sap_key = e.equnr
      LEFT JOIN ref ra ON ra.k = NULLIF(LTRIM(TRIM(e.matnr), '0'), '')
      LEFT JOIN ref rc ON rc.k = z.construction
      LEFT JOIN raw_data.t001w w ON w.mandt = '700' AND w.werks = z.iwerk
      LEFT JOIN raw_data.crhd c ON c.mandt = '700' AND c.objty = 'A' AND c.objid = z.gewrk
      LEFT JOIN raw_data.crtx ct ON ct.mandt = '700' AND ct.objty = 'A' AND ct.objid = z.gewrk AND ct.spras = 'F'
     WHERE e.mandt = '700'
)
"""

POSITIONS = {
    'FUNC_LOC': 'Sous un poste technique',
    'EQUIPMENT': 'Sous un équipement',
    'SANS_PARENT': 'Sans parent',
    'HORS_STRUCTURE': 'Hors structure IH02',
}
# Statut de l'article lie (n° article, a defaut type de construction)
STATUTS_ARTICLE = {
    'CATALOGUE': 'Au catalogue',
    'SUPPRIME': 'Supprimé dans SAP',
    'SUPPRIME_DIVISION': 'Supprimé en division',
    'HORS_PERIMETRE': 'Hors périmètre',
    'INEXISTANT': 'Inexistant dans SAP',
    'AUCUN': 'Sans article',
}
LIENS = {
    'ARTICLE': 'Avec n° article',
    'CONSTRUCTION': 'Type de construction seul',
    'AUCUN': 'Sans article',
}

# cle -> (colonne, expression du libelle ou None, titre). 'statut' est un tableau.
FACETTES = {
    'position': ('position', None, 'Position dans la structure'),
    'categorie': ('categorie', None, "Catégorie d'équipement"),
    'division': ('division', 'division_description', 'Division'),
    'poste_travail': ('poste_travail', 'poste_travail_description', 'Poste de travail'),
    'statut': ('statuts', None, 'Statut SAP'),
    'type_objet': ('type_objet', None, "Type d'objet"),
    'lien_article': ('lien_article', None, 'Article'),
    'statut_article': ('statut_article', None, "Statut de l'article"),
}

ANOMALIES = {
    'sans_parent': ('Sans parent dans la structure', "position = 'SANS_PARENT'"),
    'hors_structure': ('Hors structure IH02', "position = 'HORS_STRUCTURE'"),
    'sans_article': ('Sans article ni type de construction', "lien_article = 'AUCUN'"),
    'article_inconnu': ('Article hors catalogue (supprimé, inexistant…)',
                        "(article IS NOT NULL AND article_statut <> 'CATALOGUE') "
                        "OR (construction IS NOT NULL AND construction_statut <> 'CATALOGUE')"),
    'sans_description_fr': ('Sans description FR', "langue_description IS DISTINCT FROM 'F'"),
    'inactif': ('Inactif ou marqué pour suppression', "statuts && ARRAY['I0320', 'I0076']::varchar[]"),
}

COLONNES = ['numero', 'description', 'article', 'construction', 'categorie', 'type_objet',
            'position', 'parent_code', 'division', 'poste_travail', 'fabricant', 'modele',
            'numero_serie', 'numero_inventaire']


def _statut_libelles():
    return {r[0]: f'{r[1]} — {r[2]}' for r in db.session.execute(text(
        "SELECT istat, txt04, txt30 FROM raw_data.tj02t WHERE spras = 'F' AND istat LIKE 'I%'"))}


def _filtres(sauf=None):
    where, params = [], {}
    search = (request.args.get('search') or '').strip()
    if search:
        where.append('(numero ILIKE :s OR description ILIKE :s OR article ILIKE :s '
                     'OR construction ILIKE :s OR modele ILIKE :s OR numero_serie ILIKE :s '
                     'OR numero_inventaire ILIKE :s OR parent_code ILIKE :s)')
        params['s'] = f'%{search}%'
    for cle, (col, _, _) in FACETTES.items():
        brut = request.args.get(cle)
        if cle == sauf or not brut:
            continue
        valeurs = [v for v in brut.split(',') if v]
        autres = [v for v in valeurs if v != VIDE]
        conds = []
        if cle == 'statut':
            if VIDE in valeurs:
                conds.append('cardinality(statuts) = 0')
            if autres:
                conds.append('statuts && CAST(:f_statut AS varchar[])')
                params['f_statut'] = autres
        else:
            if VIDE in valeurs:
                conds.append(f'{col} IS NULL')
            if autres:
                conds.append(f'{col} = ANY(:f_{cle})')
                params[f'f_{cle}'] = autres
        where.append('(' + ' OR '.join(conds) + ')')
    anomalie = request.args.get('anomalie')
    if anomalie == 'toutes':
        where.append('(' + ' OR '.join(f'({sql})' for _, sql in ANOMALIES.values()) + ')')
    elif anomalie in ANOMALIES:
        where.append(f'({ANOMALIES[anomalie][1]})')
    return ('WHERE ' + ' AND '.join(where)) if where else '', params


def _ligne(r, libelles):
    d = dict(r)
    d['statuts'] = [{'code': s, 'libelle': libelles.get(s, s)} for s in (d['statuts'] or [])]
    return d


def _flags():
    return ', '.join(f'({sql}) IS TRUE AS {k}' for k, (_, sql) in ANOMALIES.items())


@equipment_browser_blueprint.route('', methods=['GET'])
@jwt_required()
def liste():
    page = max(int(request.args.get('page', 1)), 1)
    page_size = min(max(int(request.args.get('page_size', 50)), 1), 500)
    clause, params = _filtres()
    tri = request.args.get('sort') if request.args.get('sort') in COLONNES else 'numero'
    sens = 'DESC' if request.args.get('dir') == 'desc' else 'ASC'
    # Numeros (equipement, article) : tri numerique quand la valeur est un nombre
    ordre = (f"(CASE WHEN {tri} ~ '^[0-9]+$' THEN lpad({tri}, 18, '0') ELSE {tri} END)"
             if tri in ('numero', 'article', 'construction') else tri)
    total = db.session.execute(text(f'{BASE} SELECT count(*) FROM base {clause}'), params).scalar()
    rows = db.session.execute(text(
        f'{BASE} SELECT *, {_flags()} FROM base {clause} '
        f'ORDER BY {ordre} {sens} NULLS LAST, id LIMIT :limit OFFSET :offset'),
        {**params, 'limit': page_size, 'offset': (page - 1) * page_size}).mappings().all()
    libelles = _statut_libelles()
    out = []
    for r in rows:
        d = _ligne(r, libelles)
        d['anomalies'] = [k for k in ANOMALIES if d.pop(k, False)]
        out.append(d)
    return jsonify({'rows': out, 'total': total})


@equipment_browser_blueprint.route('/facettes', methods=['GET'])
@jwt_required()
def facettes():
    libelles = _statut_libelles()
    # 8 requetes sur la meme base : calculee une fois (table temporaire de la transaction)
    db.session.execute(text(f'CREATE TEMP TABLE base_tmp ON COMMIT DROP AS {BASE} SELECT * FROM base'))
    resultat = {}
    for cle, (col, lib, titre) in FACETTES.items():
        clause, params = _filtres(sauf=cle)
        if cle == 'statut':
            sql = ('SELECT s AS code, count(*) AS nb FROM base_tmp '
                   f'LEFT JOIN LATERAL unnest(statuts) s ON TRUE {clause} GROUP BY 1 ORDER BY 2 DESC')
        else:
            sql = (f'SELECT {col} AS code, {f"max({lib})" if lib else "NULL"} AS libelle, '
                   f'count(*) AS nb FROM base_tmp {clause} GROUP BY 1 ORDER BY 3 DESC')
        valeurs = []
        for r in db.session.execute(text(sql), params).mappings():
            code = r['code']
            libelle = (libelles.get(code) if cle == 'statut'
                       else POSITIONS.get(code) if cle == 'position'
                       else LIENS.get(code) if cle == 'lien_article'
                       else STATUTS_ARTICLE.get(code) if cle == 'statut_article'
                       else r.get('libelle'))
            valeurs.append({'code': code if code is not None else VIDE, 'libelle': libelle, 'nb': r['nb']})
        resultat[cle] = {'titre': titre, 'valeurs': valeurs}
    clause, params = _filtres()
    compteurs = db.session.execute(text(
        'SELECT count(*) AS total, '
        + ', '.join(f'count(*) FILTER (WHERE {sql}) AS {k}' for k, (_, sql) in ANOMALIES.items())
        + ', count(*) FILTER (WHERE ' + ' OR '.join(f'({s})' for _, s in ANOMALIES.values()) + ') AS toutes '
        f'FROM base_tmp {clause}'), params).mappings().one()
    db.session.commit()
    return jsonify({
        'facettes': resultat,
        'total': compteurs['total'],
        'anomalies': [{'cle': k, 'libelle': lib, 'nb': compteurs[k]} for k, (lib, _) in ANOMALIES.items()],
        'anomalies_total': compteurs['toutes'],
    })


@equipment_browser_blueprint.route('/export.xlsx', methods=['GET'])
@jwt_required()
def export_excel():
    from openpyxl import Workbook

    from api.finance import _envoyer, _feuille_tableau

    clause, params = _filtres()
    rows = db.session.execute(text(
        f"{BASE} SELECT *, {_flags()} FROM base {clause} "
        "ORDER BY lpad(numero, 18, '0')"), params).mappings().all()
    db.session.commit()
    libelles = _statut_libelles()
    entetes = [('numero', 'N° équipement'), ('description', 'Description'),
               ('article', 'N° article'), ('article_description', 'Désignation article'),
               ('article_categorie', 'Catégorie article'), ('article_statut', 'Statut article'),
               ('construction', 'Type de construction'), ('construction_description', 'Désignation type de construction'),
               ('construction_categorie', 'Catégorie type de construction'),
               ('construction_statut', 'Statut type de construction'),
               ('categorie', "Catégorie d'équipement"), ('type_objet', "Type d'objet"),
               ('position', 'Position dans la structure'), ('parent_code', 'Parent'),
               ('parent_designation', 'Désignation parent'), ('division', 'Division'),
               ('poste_travail', 'Poste de travail'), ('poste_travail_description', 'Libellé poste de travail'),
               ('statuts', 'Statuts SAP'), ('fabricant', 'Fabricant'), ('modele', 'Modèle'),
               ('numero_serie', 'N° de série'), ('numero_inventaire', "N° d'inventaire"),
               ('anomalies', 'Anomalies')]
    lignes = []
    for r in rows:
        d = dict(r)
        d['position'] = POSITIONS.get(d['position'], d['position'])
        for c in ('article_statut', 'construction_statut'):
            d[c] = STATUTS_ARTICLE.get(d[c], d[c])
        d['statuts'] = ', '.join(libelles.get(s, s) for s in d['statuts'] or [])
        d['anomalies'] = ', '.join(lib for k, (lib, _) in ANOMALIES.items() if d[k])
        lignes.append([d[c] for c, _ in entetes])
    wb = Workbook()
    _feuille_tableau(wb.active, 'Equipements', entetes, lignes, set())
    return _envoyer(wb, 'equipements')


@equipment_browser_blueprint.route('/<equnr>/structure', methods=['GET'])
@jwt_required()
def structure(equnr):
    """Ligne de la liste + chemin depuis la racine + fils directs dans IH02."""
    cle = equnr.zfill(18) if equnr.isdigit() else equnr
    r = db.session.execute(text(f'{BASE} SELECT *, {_flags()} FROM base WHERE id = :id'),
                           {'id': cle}).mappings().first()
    if not r:
        return jsonify({'error': 'Équipement introuvable'}), 404
    ligne = _ligne(r, _statut_libelles())
    ligne['anomalies'] = [k for k in ANOMALIES if ligne.pop(k, False)]
    chemin = db.session.execute(text("""
        WITH RECURSIVE up AS (
            SELECT id, parent_id, object_type, code, designation, 0 AS niveau
              FROM clean_data.maintenance_object
             WHERE object_type = 'EQUIPMENT' AND is_active AND sap_key = :id
            UNION ALL
            SELECT p.id, p.parent_id, p.object_type, p.code, p.designation, up.niveau + 1
              FROM clean_data.maintenance_object p JOIN up ON p.id = up.parent_id
             WHERE up.niveau < 30
        )
        SELECT object_type, code, designation FROM up ORDER BY niveau DESC"""), {'id': cle}).mappings().all()
    fils = db.session.execute(text("""
        SELECT f.object_type, f.code, f.designation, f.quantity
          FROM clean_data.maintenance_object e
          JOIN clean_data.maintenance_object f ON f.parent_id = e.id AND f.is_active
         WHERE e.object_type = 'EQUIPMENT' AND e.is_active AND e.sap_key = :id
         ORDER BY f.object_type, f.sort_order, f.code LIMIT 200"""), {'id': cle}).mappings().all()
    return jsonify({'equipement': ligne,
                    'anomalies_libelles': {k: lib for k, (lib, _) in ANOMALIES.items()},
                    'positions': POSITIONS,
                    'statuts_article': STATUTS_ARTICLE,
                    'chemin': [dict(c) for c in chemin],
                    'fils': [dict(f) for f in fils]})
