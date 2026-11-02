"""Ecran Ressources > Detail des ressources (/ressources/detail-file) : liste filtrable,
modification, creation, suppression et import du fichier des ressources de maintenance.

On edite la SOURCE raw_data.resource_detail_file (fichier, pas une table SAP) :
clean_data.resource_detail_file est videe (TRUNCATE CASCADE) puis rechargee depuis elle
par clean_data.populate_resource_detail_file(), donc toute saisie dans clean_data serait
perdue au prochain chargement. « Recalculer » rejoue clean_data.populate_all_tables()
(tout le module ressources : connexions, disponibilites... sont videes par la CASCADE).
Seules les colonnes _db sont exposees (regle des couples <col>/<col>_db).

  GET    /api/v1/resource-detail-file                liste paginee
  GET    /api/v1/resource-detail-file/facettes       compteurs (chaque facette ignore son filtre)
  GET    /api/v1/resource-detail-file/export.xlsx    selection filtree (reimportable)
  POST   /api/v1/resource-detail-file                creation
  PUT    /api/v1/resource-detail-file/<seq>          modification
  DELETE /api/v1/resource-detail-file/<seq>          suppression (409 si referencee)
  POST   /api/v1/resource-detail-file/import         fichier xlsx / csv : mise a jour par
                                                     resource_seq (sinon resource_id), ajout sinon
  POST   /api/v1/resource-detail-file/recalculer     CALL clean_data.populate_all_tables()
"""
import csv
import io
from decimal import Decimal, InvalidOperation

from flask import Blueprint, jsonify, request
from flask_jwt_extended import jwt_required
from sqlalchemy import text

from models import db

resource_detail_file_blueprint = Blueprint('resource_detail_file', __name__)

VIDE = '__vide__'
BOOL, NUM, TXT = 'bool', 'num', 'txt'

# colonne -> (libelle, theme, type)
CHAMPS = {
    'resource_id': ('Identifiant ressource', 'Identification', TXT),
    'description': ('Description', 'Identification', TXT),
    'resource_type_db': ('Type de ressource', 'Identification', TXT),
    'resource_category': ('Catégorie', 'Identification', TXT),
    'note': ('Note', 'Identification', TXT),
    'note_id': ('N° de note', 'Identification', NUM),
    'used_in_maintenance_db': ('Utilisée en maintenance', 'Utilisation', BOOL),
    'used_in_manufacturing_db': ('Utilisée en production', 'Utilisation', BOOL),
    'used_in_projects_db': ('Utilisée en projets', 'Utilisation', BOOL),
    'used_in_service_db': ('Utilisée en service', 'Utilisation', BOOL),
    'ignore_scheduling_resource': ('Ignorée par la planification', 'Utilisation', BOOL),
    'calendar_id': ('Calendrier', 'Planification', TXT),
    'use_shift_pattern_db': ("Modèle d'équipes", 'Planification', BOOL),
    'use_hr_schedule_db': ('Planning RH', 'Planification', BOOL),
    'sched_capacity_db': ('Capacité planifiée', 'Planification', TXT),
    'capacity_calc_base_db': ('Base de calcul capacité', 'Planification', TXT),
    'utilization': ('Taux d\'utilisation (%)', 'Planification', NUM),
    'resource_origin_db': ('Origine', 'Origine', TXT),
    'origin_key1': ('Clé origine 1', 'Origine', TXT),
    'origin_key2': ('Clé origine 2', 'Origine', TXT),
    'origin_key3': ('Clé origine 3', 'Origine', TXT),
    'origin_key4': ('Clé origine 4', 'Origine', TXT),
    'companies': ('Sociétés', 'Organisation', TXT),
    'sites': ('Sites', 'Organisation', TXT),
    'service_organization_id': ('Organisation de service', 'Organisation', TXT),
    'service_delivery_unit': ('Unité de service', 'Organisation', TXT),
    'manuf_group_id': ('Groupe de production', 'Organisation', TXT),
    'manuf_group_desc': ('Libellé groupe de production', 'Organisation', TXT),
    'manuf_company': ('Société de production', 'Organisation', TXT),
    'manuf_contract': ('Site de production', 'Organisation', TXT),
}
TYPES_RESSOURCE = ['PERSON', 'PERSON_GROUP', 'EQUIPMENT']

# MATERIALIZED : find_person_id n'est appelee qu'une fois par ligne
BASE = """
WITH r AS MATERIALIZED (
    SELECT r.*,
           CASE WHEN r.resource_type_db = 'PERSON'
                THEN COALESCE(raw_data.find_person_id(r.resource_id), raw_data.find_person_id(r.description))
           END AS personne_trouvee
      FROM raw_data.resource_detail_file r
), base AS (
    SELECT r.*,
           -- meme regle que populate_resource_detail_file
           COALESCE(r.personne_trouvee, r.resource_id) AS resource_id_ifs,
           CASE WHEN r.resource_type_db <> 'PERSON' OR r.resource_type_db IS NULL THEN 'SANS_OBJET'
                WHEN r.personne_trouvee IS NULL THEN 'NON_TROUVEE'
                ELSE 'TROUVEE' END AS personne,
           c.resource_seq IS NULL OR r.updated_at > c.loaded_at
             OR c.resource_id IS DISTINCT FROM COALESCE(r.personne_trouvee, r.resource_id) AS a_recalculer,
           count(*) OVER (PARTITION BY upper(trim(r.resource_id))) > 1 AS doublon
      FROM r
      LEFT JOIN clean_data.resource_detail_file c ON c.resource_seq = r.resource_seq
)
"""

PERSONNES = {'TROUVEE': 'Personne IFS trouvée', 'NON_TROUVEE': 'Personne IFS non trouvée', 'SANS_OBJET': 'Pas une personne'}

# cle -> (colonne, titre)
FACETTES = {
    'type': ('resource_type_db', 'Type de ressource'),
    'personne': ('personne', 'Personne IFS'),
    'site': ('sites', 'Site'),
    'societe': ('companies', 'Société'),
    'calendrier': ('calendar_id', 'Calendrier'),
    'origine': ('resource_origin_db', 'Origine'),
}

ANOMALIES = {
    'personne_non_trouvee': ('Personne absente d\'IFS', "personne = 'NON_TROUVEE'"),
    'doublon': ('Identifiant en double', 'doublon'),
    'sans_description': ('Sans description', "NULLIF(TRIM(description), '') IS NULL"),
    'sans_site': ('Sans site', "NULLIF(TRIM(sites), '') IS NULL"),
    'a_recalculer': ('Modifiée, à recalculer', 'a_recalculer'),
}

TRI = ['resource_seq', 'resource_id_ifs', 'personne', *CHAMPS]


def _filtres(sauf=None):
    where, params = [], {}
    search = (request.args.get('search') or '').strip()
    if search:
        where.append('(resource_id ILIKE :s OR resource_id_ifs ILIKE :s OR description ILIKE :s '
                     'OR origin_key1 ILIKE :s OR resource_seq::text = :exact)')
        params.update(s=f'%{search}%', exact=search)
    for cle, (col, _) in FACETTES.items():
        brut = request.args.get(cle)
        if cle == sauf or not brut:
            continue
        valeurs = [v for v in brut.split(',') if v]
        autres = [v for v in valeurs if v != VIDE]
        conds = []
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


def _flags():
    return ', '.join(f'({sql}) IS TRUE AS {k}' for k, (_, sql) in ANOMALIES.items())


def _ligne(r):
    d = dict(r)
    d.pop('total_lignes', None)
    d.pop('personne_trouvee', None)
    d['anomalies'] = [k for k in ANOMALIES if d.pop(k, False)]
    for k, v in d.items():
        if isinstance(v, Decimal):
            d[k] = float(v)
    return d


@resource_detail_file_blueprint.route('', methods=['GET'])
@jwt_required()
def liste():
    page = max(int(request.args.get('page', 1)), 1)
    page_size = min(max(int(request.args.get('page_size', 50)), 1), 500)
    clause, params = _filtres()
    tri = request.args.get('sort') if request.args.get('sort') in TRI else 'resource_seq'
    sens = 'DESC' if request.args.get('dir') == 'desc' else 'ASC'
    rows = db.session.execute(text(
        f'{BASE} SELECT *, {_flags()}, count(*) OVER () AS total_lignes FROM base {clause} '
        f'ORDER BY {tri} {sens} NULLS LAST, resource_seq LIMIT :limit OFFSET :offset'),
        {**params, 'limit': page_size, 'offset': (page - 1) * page_size}).mappings().all()
    total = rows[0]['total_lignes'] if rows else 0
    return jsonify({'rows': [_ligne(r) for r in rows], 'total': total})


@resource_detail_file_blueprint.route('/facettes', methods=['GET'])
@jwt_required()
def facettes():
    db.session.execute(text(f'CREATE TEMP TABLE rdf_tmp ON COMMIT DROP AS {BASE} SELECT * FROM base'))
    resultat = {}
    for cle, (col, titre) in FACETTES.items():
        clause, params = _filtres(sauf=cle)
        valeurs = [{'code': r['code'] if r['code'] is not None else VIDE,
                    'libelle': PERSONNES.get(r['code']) if cle == 'personne' else None, 'nb': r['nb']}
                   for r in db.session.execute(text(
                       f'SELECT {col} AS code, count(*) AS nb FROM rdf_tmp {clause} GROUP BY 1 ORDER BY 2 DESC'),
                       params).mappings()]
        resultat[cle] = {'titre': titre, 'valeurs': valeurs}
    clause, params = _filtres()
    compteurs = db.session.execute(text(
        'SELECT count(*) AS total, '
        + ', '.join(f'count(*) FILTER (WHERE {sql}) AS {k}' for k, (_, sql) in ANOMALIES.items())
        + ', count(*) FILTER (WHERE ' + ' OR '.join(f'({s})' for _, s in ANOMALIES.values()) + ') AS toutes '
        f'FROM rdf_tmp {clause}'), params).mappings().one()
    total_general = db.session.execute(text('SELECT count(*) FROM rdf_tmp')).scalar()
    # Lignes supprimees de la source mais encore presentes dans clean_data
    supprimees = db.session.execute(text(
        'SELECT count(*) FROM clean_data.resource_detail_file c '
        'WHERE NOT EXISTS (SELECT 1 FROM raw_data.resource_detail_file r WHERE r.resource_seq = c.resource_seq)')).scalar()
    a_recalculer = db.session.execute(text('SELECT count(*) FROM rdf_tmp WHERE a_recalculer')).scalar()
    db.session.commit()
    return jsonify({
        'facettes': resultat,
        'total': compteurs['total'],
        'total_general': total_general,
        'anomalies': [{'cle': k, 'libelle': lib, 'nb': compteurs[k]} for k, (lib, _) in ANOMALIES.items()],
        'anomalies_total': compteurs['toutes'],
        'a_recalculer': a_recalculer + supprimees,
        'champs': [{'col': c, 'label': l, 'theme': t, 'type': ty} for c, (l, t, ty) in CHAMPS.items()],
        'types_ressource': TYPES_RESSOURCE,
    })


ENTETES = [('resource_seq', 'N° séquence'), *[(c, l) for c, (l, _, _) in CHAMPS.items()],
           ('resource_id_ifs', 'Identifiant IFS (calculé)'), ('personne', 'Personne IFS (calculé)'),
           ('anomalies', 'Anomalies (calculé)')]


@resource_detail_file_blueprint.route('/export.xlsx', methods=['GET'])
@jwt_required()
def export_excel():
    from openpyxl import Workbook

    from api.finance import _envoyer, _feuille_tableau

    clause, params = _filtres()
    rows = db.session.execute(text(f'{BASE} SELECT *, {_flags()} FROM base {clause} ORDER BY resource_seq'),
                              params).mappings().all()
    db.session.commit()
    lignes = []
    for r in rows:
        d = _ligne(r)
        d['personne'] = PERSONNES.get(d['personne'], d['personne'])
        d['anomalies'] = ', '.join(ANOMALIES[k][0] for k in d['anomalies'])
        lignes.append([d.get(c) for c, _ in ENTETES])
    wb = Workbook()
    _feuille_tableau(wb.active, 'Ressources', ENTETES, lignes, {'resource_seq', 'note_id', 'utilization'})
    return _envoyer(wb, 'ressources')


# ---------------------------------------------------------------------------
# Ecriture
# ---------------------------------------------------------------------------
def _valeur(col, v):
    """Valeur saisie -> valeur stockee ; ValueError avec un message lisible."""
    if v is None or (isinstance(v, str) and not v.strip()):
        return None
    if isinstance(v, bool):
        v = 'TRUE' if v else 'FALSE'
    typ = CHAMPS[col][2]
    if typ == NUM:
        try:
            return Decimal(str(v).strip().replace(',', '.'))
        except InvalidOperation:
            raise ValueError(f"{CHAMPS[col][0]} : « {v} » n'est pas un nombre")
    s = str(v).strip()
    if typ == BOOL:
        b = s.upper()
        b = {'VRAI': 'TRUE', 'OUI': 'TRUE', '1': 'TRUE', 'FAUX': 'FALSE', 'NON': 'FALSE', '0': 'FALSE'}.get(b, b)
        if b not in ('TRUE', 'FALSE'):
            raise ValueError(f"{CHAMPS[col][0]} : « {v} » n'est pas TRUE / FALSE")
        return b
    if col == 'resource_type_db':
        s = s.upper()
        if s not in TYPES_RESSOURCE:
            raise ValueError(f"Type de ressource « {v} » inconnu ({', '.join(TYPES_RESSOURCE)})")
    return s


def _seq(v):
    try:
        n = Decimal(str(v).strip())
    except InvalidOperation:
        raise ValueError(f"N° séquence « {v} » invalide")
    if n != n.to_integral_value() or n <= 0:
        raise ValueError(f"N° séquence « {v} » invalide")
    return n


def _ecrire(seq, valeurs, source=None):
    """UPDATE si la ligne existe, INSERT sinon. Retourne 'insert' ou 'update'."""
    existe = db.session.execute(text('SELECT 1 FROM raw_data.resource_detail_file WHERE resource_seq = :s'),
                                {'s': seq}).scalar()
    p = {**valeurs, 's': seq, 'src': source}
    if existe:
        if valeurs:
            sets = ', '.join(f'{c} = :{c}' for c in valeurs)
            db.session.execute(text(f'UPDATE raw_data.resource_detail_file SET {sets}, updated_at = now(), '
                                    'source_file = COALESCE(:src, source_file) WHERE resource_seq = :s'), p)
        return 'update'
    cols = ', '.join(valeurs)
    db.session.execute(text(
        f"INSERT INTO raw_data.resource_detail_file (resource_seq{', ' if cols else ''}{cols}, source_file) "
        f"VALUES (:s{', ' if cols else ''}{', '.join(':' + c for c in valeurs)}, COALESCE(:src, 'ECRAN'))"), p)
    return 'insert'


def _corps():
    data = request.get_json(silent=True) or {}
    try:
        return {c: _valeur(c, data[c]) for c in CHAMPS if c in data}, None
    except ValueError as e:
        return None, (jsonify({'error': str(e)}), 400)


def _controle(valeurs, seq):
    if 'resource_id' in valeurs and not valeurs['resource_id']:
        return "L'identifiant ressource est obligatoire"
    if valeurs.get('resource_id'):
        autre = db.session.execute(text(
            'SELECT resource_seq FROM raw_data.resource_detail_file '
            'WHERE upper(trim(resource_id)) = upper(:id) AND resource_seq <> :s LIMIT 1'),
            {'id': valeurs['resource_id'], 's': seq}).scalar()
        if autre is not None:
            return f"L'identifiant {valeurs['resource_id']} est déjà porté par la ressource n° {autre}"
    return None


@resource_detail_file_blueprint.route('', methods=['POST'])
@jwt_required()
def creer():
    valeurs, err = _corps()
    if err:
        return err
    if not valeurs.get('resource_id') or not valeurs.get('resource_type_db'):
        return jsonify({'error': "L'identifiant et le type de ressource sont obligatoires"}), 400
    seq = db.session.execute(text(
        'SELECT COALESCE(max(resource_seq), 0) + 1 FROM raw_data.resource_detail_file')).scalar()
    probleme = _controle(valeurs, seq)
    if probleme:
        return jsonify({'error': probleme}), 409
    _ecrire(seq, valeurs)
    db.session.commit()
    return jsonify({'resource_seq': int(seq)}), 201


@resource_detail_file_blueprint.route('/<seq>', methods=['PUT'])
@jwt_required()
def modifier(seq):
    try:
        seq = _seq(seq)
    except ValueError as e:
        return jsonify({'error': str(e)}), 400
    valeurs, err = _corps()
    if err:
        return err
    if not db.session.execute(text('SELECT 1 FROM raw_data.resource_detail_file WHERE resource_seq = :s'),
                              {'s': seq}).scalar():
        return jsonify({'error': 'Ressource introuvable'}), 404
    probleme = _controle(valeurs, seq)
    if probleme:
        return jsonify({'error': probleme}), 409
    _ecrire(seq, valeurs)
    db.session.commit()
    return jsonify({'resource_seq': int(seq)})


@resource_detail_file_blueprint.route('/<seq>', methods=['DELETE'])
@jwt_required()
def supprimer(seq):
    try:
        seq = _seq(seq)
    except ValueError as e:
        return jsonify({'error': str(e)}), 400
    # Les autres fichiers du module referencent la ressource : la supprimer ferait echouer
    # le recalcul (FK de clean_data.resource_connection en RESTRICT)
    refs = db.session.execute(text("""
        SELECT 'connexions' WHERE EXISTS (SELECT 1 FROM raw_data.resource_connection
                                           WHERE :s IN (resource_seq, primary_parent_resource_seq))
        UNION ALL
        SELECT 'disponibilités' WHERE EXISTS (SELECT 1 FROM raw_data.resource_availability
                                               WHERE :s IN (resource_seq, resource_parent_seq))
        UNION ALL
        SELECT 'parents' WHERE EXISTS (SELECT 1 FROM raw_data.resource_parent
                                        WHERE :s IN (resource_seq, resource_parent_seq))"""),
        {'s': seq}).scalars().all()
    if refs:
        return jsonify({'error': f"Ressource utilisée dans les fichiers : {', '.join(refs)}. "
                                 "Retirez-la d'abord de ces fichiers."}), 409
    n = db.session.execute(text('DELETE FROM raw_data.resource_detail_file WHERE resource_seq = :s'),
                           {'s': seq}).rowcount
    db.session.commit()
    return (jsonify({'ok': True}), 200) if n else (jsonify({'error': 'Ressource introuvable'}), 404)


# ---------------------------------------------------------------------------
# Import
# ---------------------------------------------------------------------------
def _norm(s):
    return ' '.join(str(s or '').strip().lower().split())


# en-tete accepte : nom technique ou libelle de l'export (l'export est reimportable)
COLONNE_PAR_ENTETE = {
    **{_norm(c): c for c in ['resource_seq', *CHAMPS]},
    **{_norm(l): c for c, l in ENTETES if c in CHAMPS or c == 'resource_seq'},
}


def lire_fichier(nom, contenu):
    """-> liste de lignes (listes de cellules), en-tete comprise."""
    if nom.lower().endswith(('.xlsx', '.xlsm')):
        from openpyxl import load_workbook
        ws = load_workbook(io.BytesIO(contenu), read_only=True, data_only=True).worksheets[0]
        return [list(r) for r in ws.iter_rows(values_only=True)]
    if nom.lower().endswith('.csv'):
        try:
            texte = contenu.decode('utf-8-sig')
        except UnicodeDecodeError:
            texte = contenu.decode('cp1252')
        premiere = texte.split('\n', 1)[0]
        sep = ';' if premiere.count(';') >= premiere.count(',') else ','
        return list(csv.reader(io.StringIO(texte), delimiter=sep))
    raise ValueError('Format non supporté : fichier .xlsx ou .csv attendu')


def preparer_import(lignes):
    """Lignes du fichier -> (colonnes reconnues, [(n° ligne, seq ou None, valeurs)], erreurs)."""
    if not lignes:
        raise ValueError('Fichier vide')
    entetes = [COLONNE_PAR_ENTETE.get(_norm(h)) for h in lignes[0]]
    if 'resource_seq' not in entetes and 'resource_id' not in entetes:
        raise ValueError("Colonne « N° séquence » (resource_seq) ou « Identifiant ressource » (resource_id) introuvable")
    reconnues = [c for c in entetes if c and c != 'resource_seq']
    a_ecrire, erreurs = [], []
    for i, cellules in enumerate(lignes[1:], start=2):
        if all(v is None or str(v).strip() == '' for v in cellules):
            continue
        brut = {c: v for c, v in zip(entetes, cellules) if c}
        try:
            seq = _seq(brut['resource_seq']) if str(brut.get('resource_seq') or '').strip() else None
            valeurs = {c: _valeur(c, brut.get(c)) for c in reconnues}
            if seq is None and not valeurs.get('resource_id'):
                raise ValueError('ni n° séquence ni identifiant ressource')
            a_ecrire.append((i, seq, valeurs))
        except ValueError as e:
            erreurs.append({'ligne': i, 'message': str(e)})
    if not a_ecrire and not erreurs:
        raise ValueError('Aucune ligne de données')
    return reconnues, a_ecrire, erreurs


@resource_detail_file_blueprint.route('/import', methods=['POST'])
@jwt_required()
def importer():
    f = request.files.get('file')
    if not f:
        return jsonify({'error': 'Aucun fichier reçu'}), 400
    try:
        colonnes, a_ecrire, erreurs = preparer_import(lire_fichier(f.filename or '', f.read()))
    except ValueError as e:
        return jsonify({'error': str(e)}), 400
    stats = {'inserees': 0, 'modifiees': 0}
    # Tout ou rien : une erreur sur une ligne annule l'import du fichier
    db.session.execute(text('LOCK TABLE raw_data.resource_detail_file IN SHARE ROW EXCLUSIVE MODE'))
    prochain = db.session.execute(text(
        'SELECT COALESCE(max(resource_seq), 0) + 1 FROM raw_data.resource_detail_file')).scalar()
    vus = set()
    for ligne, seq, valeurs in a_ecrire:
        if seq is None:
            seq = db.session.execute(text(
                'SELECT resource_seq FROM raw_data.resource_detail_file WHERE upper(trim(resource_id)) = upper(:id) '
                'ORDER BY resource_seq LIMIT 1'), {'id': valeurs['resource_id']}).scalar()
        if seq is None:
            seq, prochain = prochain, prochain + 1
            if not valeurs.get('resource_type_db'):
                erreurs.append({'ligne': ligne, 'message': 'nouvelle ressource sans type de ressource'})
                continue
        if seq in vus:
            erreurs.append({'ligne': ligne, 'message': f'ressource n° {seq} présente deux fois dans le fichier'})
            continue
        vus.add(seq)
        probleme = _controle(valeurs, seq)
        if probleme:
            erreurs.append({'ligne': ligne, 'message': probleme})
            continue
        if _ecrire(seq, valeurs, source=f.filename) == 'insert':
            stats['inserees'] += 1
        else:
            stats['modifiees'] += 1
    if erreurs:
        db.session.rollback()
        return jsonify({'error': f'{len(erreurs)} ligne(s) en erreur : fichier non importé',
                        'erreurs': sorted(erreurs, key=lambda e: e['ligne'])[:200]}), 400
    db.session.commit()
    return jsonify({**stats, 'colonnes': [CHAMPS[c][0] for c in colonnes]})


@resource_detail_file_blueprint.route('/recalculer', methods=['POST'])
@jwt_required()
def recalculer():
    try:
        db.session.execute(text('CALL clean_data.populate_all_tables()'))
        db.session.commit()
    except Exception as e:
        db.session.rollback()
        return jsonify({'error': f'Recalcul impossible : {e}'}), 500
    n = db.session.execute(text('SELECT count(*) FROM clean_data.resource_detail_file')).scalar()
    return jsonify({'lignes': n})
