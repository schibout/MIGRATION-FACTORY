"""Base commune des ecrans de consultation Donnees IFS (fournisseurs, articles) : une source
(table ou controle) est un dictionnaire label / from / where / colonnes / recherche / cle / ordre.
Les noms de tables viennent de la configuration de chaque ecran, jamais de la requete.
"""
from flask import jsonify, request
from sqlalchemy import text

from models import db

from .finance import _envoyer, _feuille_tableau, _json, _read_status
from .sap_articles import q

AUDIT = {'created_timestamp', 'updated_timestamp', 'created_by', 'updated_by', 'is_deleted'}
BOOLEENS = {'dans_perimetre', 'dans_sap', 'dans_fichier'}


def colonnes_table(table, *exclues):
    """Colonnes de clean_data.<table> dans l'ordre de la table, hors audit et hors `exclues`."""
    return [r[0] for r in db.session.execute(text(
        "SELECT column_name FROM information_schema.columns "
        "WHERE table_schema = 'clean_data' AND table_name = :t ORDER BY ordinal_position"), {'t': table})
            if r[0] not in AUDIT and r[0] not in exclues]


def colonnes_export(table, libelles={}):
    """(expression, cle, libelle) des colonnes de public.etl_export_queries pour clean_data.<table>, dans
    l'ordre du fichier d'export. Colonne declaree mais absente de la table : NULL, comme build_dynamic_query."""
    liste = db.session.execute(text(
        "SELECT column_list FROM public.etl_export_queries "
        "WHERE table_schema = 'clean_data' AND table_name = :t AND is_active"), {'t': table}).scalar() or ''
    reelles = {r[0] for r in db.session.execute(text(
        "SELECT column_name FROM information_schema.columns "
        "WHERE table_schema = 'clean_data' AND table_name = :t"), {'t': table})}
    # dict.fromkeys : une liste peut declarer deux fois la meme colonne (customer_info_contact.guid)
    noms = dict.fromkeys(c.strip().lower() for c in liste.split(',') if c.strip())
    return [(f't.{q(c)}' if c in reelles else 'NULL', c, libelles.get(c, c)) for c in noms]


def filtre(src, search):
    """(FROM + WHERE, parametres) ; la recherche porte sur les expressions de la source."""
    clauses = [src['where']] if src.get('where') else []
    params = {}
    if search:
        clauses.append('(' + ' OR '.join(f'{e} ILIKE :search' for e in src['recherche']) + ')')
        params['search'] = f'%{search}%'
    return src['from'] + (' WHERE ' + ' AND '.join(clauses) if clauses else ''), params


def colonnes_sql(src):
    return ', '.join(f'{e} AS {q(k)}' for e, k, _ in src['colonnes'])


def _onglet(onglets):
    onglet = request.args.get('onglet')
    return onglet if onglet in onglets else 'synthese'


def lister(onglets, source, sync_key):
    page = max(int(request.args.get('page', 1)), 1)
    page_size = min(max(int(request.args.get('page_size', 50)), 1), 500)
    onglet = _onglet(onglets)
    search = (request.args.get('search') or '').strip()
    table = request.args.get('table')
    if table not in onglets[onglet]:
        table = onglets[onglet][0]

    sources = {k: source(k) for k in onglets[onglet]}
    tables = []
    for k, s in sources.items():
        corps, params = filtre(s, search)
        tables.append({'key': k, 'label': s['label'],
                       'lignes': db.session.execute(text(f'SELECT count(*) FROM {corps}'), params).scalar()})

    src = sources[table]
    corps, params = filtre(src, search)
    entites = db.session.execute(text(f"SELECT count(DISTINCT {src['cle']}) FROM {corps}"), params).scalar()
    rows = db.session.execute(
        text(f"SELECT {colonnes_sql(src)} FROM {corps} ORDER BY {src['ordre']} LIMIT :limit OFFSET :offset"),
        {**params, 'limit': page_size, 'offset': (page - 1) * page_size}).mappings().all()

    return jsonify({
        'onglet': onglet,
        'table': table,
        'tables': tables,
        'rows': [{k: _json(v) for k, v in r.items()} for r in rows],
        'total': next(t['lignes'] for t in tables if t['key'] == table),
        'entites': entites,
        'colonnes': [{'key': k, 'label': l, 'kind': 'bool' if k in BOOLEENS else 'text'}
                     for _, k, l in src['colonnes']],
        'sync': _read_status(sync_key),
    })


def exporter(onglets, source, prefixe):
    from openpyxl import Workbook

    onglet = _onglet(onglets)
    search = (request.args.get('search') or '').strip()
    feuilles = []
    for key in onglets[onglet]:
        src = source(key)
        corps, params = filtre(src, search)
        rows = db.session.execute(
            text(f"SELECT {colonnes_sql(src)} FROM {corps} ORDER BY {src['ordre']}"), params).all()
        feuilles.append((key, [(k, l) for _, k, l in src['colonnes']], rows))
    db.session.commit()  # liberer la transaction de lecture avant la generation

    wb = Workbook()
    for i, (key, libelles, rows) in enumerate(feuilles):
        # La cle tient en 31 caracteres et reste unique, contrairement aux libelles
        _feuille_tableau(wb.active if i == 0 else wb.create_sheet(), key, libelles, rows, set())
    return _envoyer(wb, f'{prefixe}_{onglet}')
