"""Ecran Donnees IFS > Fournisseurs (/ifs-data/fournisseurs) : consultation des tables
clean_data chargees par le module ETL fournisseurs, regroupees par theme.

  GET  /api/v1/ifs-data/fournisseurs              onglet, table, search, page, page_size
  GET  /api/v1/ifs-data/fournisseurs/export.xlsx  onglet, search : une feuille par table de l'onglet
  GET  /api/v1/ifs-data/fournisseurs/sync         etat de la derniere synchronisation
  POST /api/v1/ifs-data/fournisseurs/sync         {"source": "mf"} module ETL seul (perimetre repris
                                                  tel quel) ; {"source": "sap"} extraction SAP,
                                                  recalcul du perimetre, puis module ETL

Lecture seule : un rechargement ecraserait toute modification faite dans ces tables.
Les noms de tables viennent de TABLES / CONTROLES, jamais de la requete.
"""
from flask import Blueprint, jsonify, request
from flask_jwt_extended import jwt_required
from sqlalchemy import text

from models import db

from .finance import (FOURN_SAP_TABLES, _envoyer, _feuille_tableau, _json, _read_status, _start_sync,
                      _sync_source, _write_status)
from .sap_articles import _charger_modules, q

ifs_fournisseurs_blueprint = Blueprint('ifs_fournisseurs', __name__)

SYNC_KEY = 'ifs_fournisseurs'
MODULE_ETL = 'etl_supplier_base.py'
AUDIT = {'created_timestamp', 'updated_timestamp', 'created_by', 'updated_by', 'is_deleted'}

# table -> (colonne portant le N° IFS du fournisseur, libelle de l'ecran d'export)
TABLES = {
    'supplier_info_general': ('supplier_id', 'Informations générales'),
    'supplier_info_our_id': ('supplier_id', 'Identifiants internes'),
    'supplier': ('vendor_no', 'Fournisseurs principaux'),
    'supplier_info_address': ('supplier_id', 'Adresses'),
    'supplier_info_address_type': ('supplier_id', "Types d'adresses"),
    'supplier_address': ('vendor_no', 'Adresses de livraison'),
    'comm_method': ('identity', 'Méthodes de communication'),
    'supplier_info_contact': ('supplier_id', 'Contacts'),
    'supplier_document_tax_info': ('supplier_id', 'Informations fiscales'),
    'supplier_tax_info': ('supplier_id', 'Informations fiscales avancées'),
    'supplier_delivery_tax_code': ('supplier_id', 'Codes fiscaux de livraison'),
    'supplier_addr_tax_number': ('supplier_id', 'Numéros fiscaux'),
    'identity_invoice_info': ('identity', 'Informations de facturation'),  # supplier_id y est toujours NULL
    'identity_pay_info': ('identity', 'Informations de paiement'),
    'payment_way_per_identity': ('identity', 'Modes de paiement'),
    'payment_address': ('identity', 'Adresses de paiement'),
    'purchase_part_supplier': ('vendor_no', 'Fournisseurs par article'),
}

# Un fournisseur charge doit figurer dans ces tables (contacts et articles restent facultatifs)
_ATTENDUES = [t for t in TABLES if t not in ('supplier_info_general', 'supplier_info_contact', 'purchase_part_supplier')]
CONTROLES = ['non_charge', 'hors_perimetre'] + [f'sans_{t}' for t in _ATTENDUES]

ONGLETS = {
    'synthese': ['synthese'],
    'general': ['supplier_info_general', 'supplier_info_our_id'],
    'achats': ['supplier'],
    'adresses': ['supplier_info_address', 'supplier_info_address_type', 'supplier_address'],
    'communication': ['comm_method', 'supplier_info_contact'],
    'fiscalite': ['supplier_document_tax_info', 'supplier_tax_info', 'supplier_delivery_tax_code',
                  'supplier_addr_tax_number'],
    'paiement': ['identity_invoice_info', 'identity_pay_info', 'payment_way_per_identity', 'payment_address'],
    'articles': ['purchase_part_supplier'],
    'controles': CONTROLES,
}

_GENERAL = 'clean_data.supplier_info_general g'
_ID_COLONNES = [('g.supplier_id', 'supplier_id', 'N° IFS'),
                ('g.supplier_legacy_sap_id', 'fournisseur_sap', 'N° SAP'),
                ('g.name', 'fournisseur_nom', 'Nom fournisseur')]
_ID_RECHERCHE = ['g.supplier_id', 'g.supplier_legacy_sap_id', 'g.name']


def _compteur(alias, table, cle):
    return f'LEFT JOIN (SELECT {q(cle)} AS c, count(*) AS n FROM clean_data.{q(table)} GROUP BY 1) {alias} ON {alias}.c = g.supplier_id'


def _source_synthese():
    return {
        'label': 'Synthèse',
        'from': f"""{_GENERAL}
            LEFT JOIN clean_data.supplier s ON s.vendor_no = g.supplier_id
            LEFT JOIN clean_data.ifs_fournisseurs f ON f.numero_compte_ifs = g.supplier_id
            LEFT JOIN clean_data.identity_invoice_info i ON i.identity = g.supplier_id
            {_compteur('a', 'supplier_info_address', 'supplier_id')}
            {_compteur('c', 'comm_method', 'identity')}
            {_compteur('x', 'supplier_addr_tax_number', 'supplier_id')}
            {_compteur('p', 'purchase_part_supplier', 'vendor_no')}""",
        'colonnes': _ID_COLONNES + [
            ('g.country_db', 'pays', 'Pays'),
            ('g.default_language_db', 'langue', 'Langue'),
            ('s.currency_code', 'devise', 'Devise'),
            ('s.buyer_code', 'acheteur', 'Acheteur'),
            ('i.pay_term_id', 'condition_paiement', 'Condition de paiement'),
            ('f.numero_compte_ifs IS NOT NULL', 'dans_perimetre', 'Dans le périmètre'),
            ('f.source', 'source', 'Source du périmètre'),
            ('COALESCE(a.n, 0)', 'nb_adresses', 'Adresses'),
            ('COALESCE(c.n, 0)', 'nb_communications', 'Communications'),
            ('COALESCE(x.n, 0)', 'nb_numeros_fiscaux', 'Numéros fiscaux'),
            ('COALESCE(p.n, 0)', 'nb_articles', 'Articles'),
        ],
        'recherche': _ID_RECHERCHE,
        'cle': 'g.supplier_id',
        'ordre': 'g.supplier_id',
    }


def _source_table(table):
    cle, label = TABLES[table]
    colonnes = [r[0] for r in db.session.execute(text(
        "SELECT column_name FROM information_schema.columns "
        "WHERE table_schema = 'clean_data' AND table_name = :t ORDER BY ordinal_position"), {'t': table})
                if r[0] not in AUDIT and r[0] != cle]
    if table == 'supplier_info_general':
        return {
            'label': label,
            'from': _GENERAL,
            'colonnes': _ID_COLONNES + [(f'g.{q(c)}', c, c) for c in colonnes
                                        if c not in ('supplier_legacy_sap_id', 'name')],
            'recherche': _ID_RECHERCHE,
            'cle': 'g.supplier_id',
            'ordre': 'g.supplier_id',
        }
    cle_sql = f't.{q(cle)}'
    return {
        'label': label,
        'from': f'clean_data.{q(table)} t LEFT JOIN {_GENERAL} ON g.supplier_id = {cle_sql}',
        'colonnes': [(cle_sql, cle, cle), _ID_COLONNES[1], _ID_COLONNES[2]]
                    + [(f't.{q(c)}', c, c) for c in colonnes],
        'recherche': [cle_sql, 'g.supplier_legacy_sap_id', 'g.name']
                     + (['t.part_no'] if table == 'purchase_part_supplier' else []),
        'cle': cle_sql,
        'ordre': f'{cle_sql}, t.ctid',
    }


def _source_controle(code):
    if code == 'non_charge':
        return {
            'label': 'Périmètre non chargé',
            'from': 'clean_data.ifs_fournisseurs f',
            'where': 'NOT EXISTS (SELECT 1 FROM clean_data.supplier_info_general g WHERE g.supplier_id = f.numero_compte_ifs)',
            'colonnes': [('f.numero_compte_ifs', 'supplier_id', 'N° IFS'),
                         ('f.numero_compte_fournisseur', 'fournisseur_sap', 'N° SAP'),
                         ('f.nom_1', 'fournisseur_nom', 'Nom fournisseur'),
                         ('f.source', 'source', 'Source du périmètre')],
            'recherche': ['f.numero_compte_ifs', 'f.numero_compte_fournisseur', 'f.nom_1'],
            'cle': 'f.numero_compte_ifs',
            'ordre': 'f.numero_compte_ifs',
        }
    if code == 'hors_perimetre':
        label = 'Chargé hors périmètre'
        where = 'NOT EXISTS (SELECT 1 FROM clean_data.ifs_fournisseurs f WHERE f.numero_compte_ifs = g.supplier_id)'
    else:
        table = code[len('sans_'):]
        label = f'Absent : {TABLES[table][1]}'
        where = f'NOT EXISTS (SELECT 1 FROM clean_data.{q(table)} x WHERE x.{q(TABLES[table][0])} = g.supplier_id)'
    return {
        'label': label,
        'from': _GENERAL,
        'where': where,
        'colonnes': _ID_COLONNES + [('g.country_db', 'pays', 'Pays')],
        'recherche': _ID_RECHERCHE,
        'cle': 'g.supplier_id',
        'ordre': 'g.supplier_id',
    }


def _source(key):
    if key == 'synthese':
        return _source_synthese()
    return _source_table(key) if key in TABLES else _source_controle(key)


def _filtre(src, search):
    """(FROM + WHERE, parametres) ; la recherche porte sur le N° IFS, le N° SAP et le nom."""
    clauses = [src['where']] if src.get('where') else []
    params = {}
    if search:
        clauses.append('(' + ' OR '.join(f'{e} ILIKE :search' for e in src['recherche']) + ')')
        params['search'] = f'%{search}%'
    return src['from'] + (' WHERE ' + ' AND '.join(clauses) if clauses else ''), params


def _colonnes_sql(src):
    return ', '.join(f'{e} AS {q(k)}' for e, k, _ in src['colonnes'])


def _onglet():
    onglet = request.args.get('onglet')
    return onglet if onglet in ONGLETS else 'synthese'


def _kind(cle):
    return 'bool' if cle == 'dans_perimetre' else 'text'


@ifs_fournisseurs_blueprint.route('', methods=['GET'])
@jwt_required()
def lister():
    page = max(int(request.args.get('page', 1)), 1)
    page_size = min(max(int(request.args.get('page_size', 50)), 1), 500)
    onglet = _onglet()
    search = (request.args.get('search') or '').strip()
    table = request.args.get('table')
    if table not in ONGLETS[onglet]:
        table = ONGLETS[onglet][0]

    sources = {k: _source(k) for k in ONGLETS[onglet]}
    tables = []
    for k, s in sources.items():
        corps, params = _filtre(s, search)
        tables.append({'key': k, 'label': s['label'],
                       'lignes': db.session.execute(text(f'SELECT count(*) FROM {corps}'), params).scalar()})

    src = sources[table]
    corps, params = _filtre(src, search)
    fournisseurs = db.session.execute(text(f"SELECT count(DISTINCT {src['cle']}) FROM {corps}"), params).scalar()
    rows = db.session.execute(
        text(f"SELECT {_colonnes_sql(src)} FROM {corps} ORDER BY {src['ordre']} LIMIT :limit OFFSET :offset"),
        {**params, 'limit': page_size, 'offset': (page - 1) * page_size}).mappings().all()

    return jsonify({
        'onglet': onglet,
        'table': table,
        'tables': tables,
        'rows': [{k: _json(v) for k, v in r.items()} for r in rows],
        'total': next(t['lignes'] for t in tables if t['key'] == table),
        'fournisseurs': fournisseurs,
        'colonnes': [{'key': k, 'label': l, 'kind': _kind(k)} for _, k, l in src['colonnes']],
        'sync': _read_status(SYNC_KEY),
    })


@ifs_fournisseurs_blueprint.route('/export.xlsx', methods=['GET'])
@jwt_required()
def exporter():
    from openpyxl import Workbook

    onglet = _onglet()
    search = (request.args.get('search') or '').strip()
    feuilles = []
    for key in ONGLETS[onglet]:
        src = _source(key)
        corps, params = _filtre(src, search)
        rows = db.session.execute(
            text(f"SELECT {_colonnes_sql(src)} FROM {corps} ORDER BY {src['ordre']}"), params).all()
        feuilles.append((key, [(k, l) for _, k, l in src['colonnes']], rows))
    db.session.commit()  # liberer la transaction de lecture avant la generation

    wb = Workbook()
    for i, (key, libelles, rows) in enumerate(feuilles):
        # La cle tient en 31 caracteres et reste unique, contrairement aux libelles
        _feuille_tableau(wb.active if i == 0 else wb.create_sheet(), key, libelles, rows, set())
    return _envoyer(wb, f'fournisseurs_ifs_{onglet}')


@ifs_fournisseurs_blueprint.route('/sync', methods=['GET'])
@jwt_required()
def etat_sync():
    return jsonify(_read_status(SYNC_KEY) or {'status': 'never'})


@ifs_fournisseurs_blueprint.route('/sync', methods=['POST'])
@jwt_required()
def lancer_sync():
    extraire = _sync_source() == 'sap'

    def load(conn):
        if extraire:
            _write_status(SYNC_KEY, step='Recalcul du périmètre', progress=90)
            # Transaction propre, validee AVANT le module : il lit ce perimetre sur sa propre
            # connexion et se bloquerait sur le verrou du TRUNCATE encore ouvert. La date d'arrete
            # en place est conservee (celle saisie dans Finance > Fournisseurs prime sur le defaut).
            with db.engine.begin() as perimetre:
                perimetre.execute(text(
                    'SELECT clean_data.alimenter_ifs_fournisseurs_perimetre('
                    '(SELECT max(date_arrete) FROM clean_data.ifs_fournisseurs_perimetre))'))
        _charger_modules(conn, SYNC_KEY, [MODULE_ETL])
        return conn.execute(text('SELECT count(*) FROM clean_data.supplier_info_general')).scalar()

    return _start_sync(SYNC_KEY, FOURN_SAP_TABLES, 'module ETL fournisseurs', load, extraire=extraire)
