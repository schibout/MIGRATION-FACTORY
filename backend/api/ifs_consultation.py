"""Base commune des ecrans de consultation Donnees IFS (fournisseurs, articles) : une source
(table ou controle) est un dictionnaire label / from / where / colonnes / recherche / cle / ordre.
Les noms de tables viennent de la configuration de chaque ecran, jamais de la requete.
"""
from flask import jsonify, request
from flask_jwt_extended import get_jwt_identity, jwt_required
from sqlalchemy import text

from models import db

from .finance import _envoyer, _feuille_tableau, _json, _read_status, _start_sync, _sync_source
from .sap_articles import _charger_modules, q

AUDIT = {'created_timestamp', 'updated_timestamp', 'created_by', 'updated_by', 'is_deleted'}
BOOLEENS = {'dans_perimetre', 'dans_sap', 'dans_fichier'}


def colonnes_table(table, *exclues):
    """Colonnes de clean_data.<table> dans l'ordre de la table, hors audit et hors `exclues`."""
    return [r[0] for r in db.session.execute(text(
        "SELECT column_name FROM information_schema.columns "
        "WHERE table_schema = 'clean_data' AND table_name = :t ORDER BY ordinal_position"), {'t': table})
            if r[0] not in AUDIT and r[0] not in exclues]


# Table clean_data dont l'entite du catalogue IFS (/ifs-data/catalog) porte un autre nom
ENTITES_CATALOGUE = {
    'cus_comm_method': 'COMM_METHOD',
    'cus_ident_invoice_info': 'IDENTITY_INVOICE_INFO',
    'cus_identity_pay_info': 'IDENTITY_PAY_INFO',
    'cus_payment_address': 'PAYMENT_ADDRESS',
    'cus_paym_way_per_ident': 'PAYMENT_WAY_PER_IDENTITY',
    'equipment_functional': 'EQUIPMENT_FUNCTIONAL_UIV',
    'equipment_serial': 'EQUIPMENT_FUNCTIONAL_UIV',
    'invent_part_plan': 'INVENTORY_PART_PLANNING',
    'project_activity': 'ACTIVITY',
    'project_activity_class': 'ACTIVITY',
    'resource_detail_file': 'RESOURCE_DETAIL',
    'supplier_addr_tax_number': 'CUSTOMER_ADDR_TAX_NUMBER',
}


def libelles_catalogue(table):
    """{colonne: libelle francais} de public.ifs_field_catalog : celui de l'entite de la table, sinon (spec sans
    libelle, comme ACTIVITY) le plus frequent du meme champ dans tout le catalogue. Les specs portent des libelles
    parasites (0, 93, #N/A, #REF!, *), ecartes : nombres, erreurs Excel et caracteres isoles."""
    return dict(db.session.execute(text(
        "SELECT DISTINCT ON (f) f, l FROM ("
        "  SELECT lower(field_name) AS f, trim(field_label_fr) AS l, upper(entity) AS e, lot_id, "
        "         count(*) OVER (PARTITION BY lower(field_name), trim(field_label_fr)) AS n "
        "  FROM public.ifs_field_catalog WHERE trim(field_label_fr) !~ '^([0-9]*|#.*|.)$') c "
        "ORDER BY f, (e = :e) DESC, n DESC, lot_id, l"),
        {'e': ENTITES_CATALOGUE.get(table, table).upper()}).all())


def libelle(colonne, catalogue):
    """Libelle du catalogue, sinon le nom technique. <col> et <col>_db y portent le meme libelle : on les distingue."""
    texte = catalogue.get(colonne)
    if not texte:
        return colonne
    return f'{texte} (code)' if colonne.endswith('_db') else texte


def colonnes_catalogue(table, noms, alias='t'):
    """(expression, cle, libelle) des colonnes `noms` de clean_data.<table>, libellees par le catalogue IFS."""
    catalogue = libelles_catalogue(table)
    return [(f'{alias}.{q(c)}', c, libelle(c, catalogue)) for c in noms]


def colonnes_export(table):
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
    catalogue = libelles_catalogue(table)
    return [(f't.{q(c)}' if c in reelles else 'NULL', c, libelle(c, catalogue)) for c in noms]


def source_export(table, label, recherche, cle, ordre):
    """Source d'une table montree telle qu'exportee ; `recherche` : expressions texte sur l'alias t."""
    return {
        'label': label,
        'from': f'clean_data.{q(table)} t',
        'colonnes': colonnes_export(table),
        'recherche': recherche,
        'cle': cle,
        'ordre': f'{ordre}, t.ctid',
    }


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


def routes_sync(blueprint, cle, module, comptage, tables_sap=None, avant_module=None, garde=None):
    """Declare GET et POST /sync d'un ecran et renvoie la vue POST. {"source": "mf"} (Calculer) lance le module ETL
    seul ; {"source": "sap"} (Synchroniser) renouvelle d'abord la source : extraction de `tables_sap`, ou
    `avant_module(cle, utilisateur)` si elle ne se resume pas a une extraction. Sans l'un ni l'autre, la source
    est un fichier : 400. `garde()` peut refuser le lancement en renvoyant une reponse."""

    @blueprint.route('/sync', methods=['GET'])
    @jwt_required()
    def etat_sync():
        return jsonify(_read_status(cle) or {'status': 'never'})

    @blueprint.route('/sync', methods=['POST'])
    @jwt_required()
    def lancer_sync():
        synchroniser = _sync_source() == 'sap'
        if synchroniser and not (tables_sap or avant_module):
            return jsonify({'error': 'La source de cet écran est un fichier : rien à synchroniser.'}), 400
        refus = garde() if garde else None
        if refus:
            return refus
        utilisateur = str(get_jwt_identity() or cle)

        def load(conn):
            if synchroniser and avant_module:
                avant_module(cle, utilisateur)
            _charger_modules(conn, cle, [module])
            return conn.execute(text(comptage)).scalar()

        return _start_sync(cle, tables_sap or [], f'module ETL {module}', load,
                           extraire=synchroniser and bool(tables_sap))

    return lancer_sync
