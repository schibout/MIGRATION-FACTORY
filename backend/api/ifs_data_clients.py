"""Ecran Donnees IFS > Clients (/ifs-data/clients) : consultation des tables clean_data de la
categorie d'export 'customer' (modules etl_customer.py, etl_file_customer.py, etl_phl_customer.py).

  GET  /api/v1/ifs-data/clients              onglet, table, search, page, page_size
  GET  /api/v1/ifs-data/clients/export.xlsx  onglet, search : une feuille par table de l'onglet
  GET  /api/v1/ifs-data/clients/sync         etat du dernier rechargement
  POST /api/v1/ifs-data/clients/sync         {"source": "mf"} module ETL seul ; {"source": "sap"} extraction SAP puis module ETL

Lecture seule. Les colonnes viennent de public.etl_export_queries, comme l'export : chaque table
montre les colonnes du CSV, precedees du N° SAP et du nom du client.
"""
from flask import Blueprint
from flask_jwt_extended import jwt_required

from .ifs_consultation import colonnes_export, exporter, lister, routes_sync
from .sap_articles import q

ifs_data_clients_blueprint = Blueprint('ifs_data_clients', __name__)

SYNC_KEY = 'clients_ifs'

# table -> (colonne portant le N° IFS du client, libelle de l'ecran d'export)
TABLES = {
    'customer_info': ('customer_id', 'Informations générales'),
    'customer_info_address': ('customer_id', 'Adresses'),
    'customer_info_address_type': ('customer_id', "Types d'adresses"),
    'cus_comm_method': ('identity', 'Méthodes de communication'),
    'customer_info_contact': ('customer_id', 'Contacts'),
    'cust_ord_customer': ('customer_no', 'Client commande'),
    'cust_ord_customer_address': ('customer_no', 'Adresses de commande'),
    'customer_tax_info': ('customer_id', 'Informations fiscales'),
    'customer_delivery_tax_info': ('customer_id', 'Taxes de livraison'),
    'customer_delivery_fee_code': ('customer_id', 'Codes de frais de livraison'),
    'customer_tax_free_tax_code': ('customer_id', 'Codes hors taxes'),
    'customer_del_tax_exempt': ('customer_id', 'Exemptions fiscales de livraison'),
    'customer_document_tax_info': ('customer_id', 'Documents fiscaux'),
    'customer_addr_tax_number': ('customer_id', 'Numéros fiscaux'),
    'cus_ident_invoice_info': ('identity', 'Informations de facturation'),
    'customer_credit_info': ('identity', 'Informations de crédit'),
    'cus_identity_pay_info': ('identity', 'Informations de paiement'),
    'cus_paym_way_per_ident': ('identity', 'Modes de paiement'),
    'cus_payment_address': ('identity', 'Adresses de paiement'),
}

# Un client charge doit figurer dans ces tables (contacts et communications restent facultatifs)
_ATTENDUES = [t for t in TABLES if t not in ('customer_info', 'customer_info_contact', 'cus_comm_method')]
# Tables dont une meme cle peut revenir plusieurs fois : chaque ligne part dans le fichier d'export
_CLES_UNIQUES = {
    'customer_info': 'customer_id',
    'customer_info_address': 'customer_id, address_id',
    'customer_info_address_type': 'customer_id, address_id, address_type_code_db',  # address_type_code reste NULL
    'cus_comm_method': 'identity, comm_id',
    'cus_identity_pay_info': 'company, identity',
}
CONTROLES = [f'dbl_{t}' for t in _CLES_UNIQUES] + [f'sans_{t}' for t in _ATTENDUES]

ONGLETS = {
    'synthese': ['synthese'],
    'general': ['customer_info'],
    'adresses': ['customer_info_address', 'customer_info_address_type'],
    'communication': ['cus_comm_method', 'customer_info_contact'],
    'commandes': ['cust_ord_customer', 'cust_ord_customer_address'],
    'fiscalite': ['customer_tax_info', 'customer_delivery_tax_info', 'customer_delivery_fee_code',
                  'customer_tax_free_tax_code', 'customer_del_tax_exempt', 'customer_document_tax_info',
                  'customer_addr_tax_number'],
    'paiement': ['cus_ident_invoice_info', 'customer_credit_info', 'cus_identity_pay_info',
                 'cus_paym_way_per_ident', 'cus_payment_address'],
    'controles': CONTROLES,
}

# customer_info peut porter un client en double : une seule ligne par client pour les jointures
_CLIENT = """(SELECT DISTINCT ON (customer_id) customer_id, name, cf_legacy_customer_sap_id, country_db,
                     default_language_db
              FROM clean_data.customer_info ORDER BY customer_id, party_type NULLS LAST) c"""
_SAP = ('c.cf_legacy_customer_sap_id', 'client_sap', 'N° SAP')
_NOM = ('c.name', 'client_nom', 'Nom client')
_RECHERCHE = ['c.customer_id', 'c.cf_legacy_customer_sap_id', 'c.name']


def _compteur(alias, table):
    cle = q(TABLES[table][0])
    return f'LEFT JOIN (SELECT {cle} AS k, count(*) AS n FROM clean_data.{q(table)} GROUP BY 1) {alias} ' \
           f'ON {alias}.k = c.customer_id'


def _source_synthese():
    return {
        'label': 'Synthèse',
        'from': f"""{_CLIENT}
            LEFT JOIN clean_data.cust_ord_customer o ON o.customer_no = c.customer_id
            LEFT JOIN clean_data.cus_ident_invoice_info i ON i.identity = c.customer_id
            {_compteur('g', 'customer_info')}
            {_compteur('a', 'customer_info_address')}
            {_compteur('m', 'cus_comm_method')}
            {_compteur('x', 'customer_addr_tax_number')}""",
        'colonnes': [('c.customer_id', 'customer_id', 'N° IFS'), _SAP, _NOM,
                     ('c.country_db', 'pays', 'Pays'),
                     ('c.default_language_db', 'langue', 'Langue'),
                     ('o.currency_code', 'devise', 'Devise'),
                     ('o.cust_grp', 'groupe', 'Groupe client'),
                     ('i.pay_term_id', 'condition_paiement', 'Condition de paiement'),
                     ('COALESCE(g.n, 0)', 'nb_fiches', 'Fiches générales'),
                     ('COALESCE(a.n, 0)', 'nb_adresses', 'Adresses'),
                     ('COALESCE(m.n, 0)', 'nb_communications', 'Communications'),
                     ('COALESCE(x.n, 0)', 'nb_numeros_fiscaux', 'Numéros fiscaux')],
        'recherche': _RECHERCHE,
        'cle': 'c.customer_id',
        'ordre': 'c.customer_id',
    }


def _source_table(table):
    cle, label = TABLES[table]
    cle_sql = f't.{q(cle)}'
    autres = [c for c in colonnes_export(table) if c[1] != cle]
    return {
        'label': label,
        'from': f'clean_data.{q(table)} t LEFT JOIN {_CLIENT} ON c.customer_id = {cle_sql}',
        'colonnes': [(cle_sql, cle, 'N° IFS'), _SAP, _NOM] + autres,
        'recherche': [cle_sql, 'c.cf_legacy_customer_sap_id', 'c.name'],
        'cle': cle_sql,
        'ordre': f'{cle_sql}, t.ctid',
    }


def _source_controle(code):
    if code.startswith('dbl_'):
        table = code[len('dbl_'):]
        cles = _CLES_UNIQUES[table]
        # Fenetre plutot que GROUP BY ... IN : une cle partiellement NULL reste comparee
        return {**_source_table(table), 'label': f'En double : {TABLES[table][1]}',
                'where': f't.ctid IN (SELECT ctid FROM (SELECT ctid, count(*) OVER (PARTITION BY {cles}) AS n '
                         f'FROM clean_data.{q(table)}) d WHERE n > 1)'}
    table = code[len('sans_'):]
    return {
        'label': f'Absent : {TABLES[table][1]}',
        'from': _CLIENT,
        'where': f'NOT EXISTS (SELECT 1 FROM clean_data.{q(table)} x WHERE x.{q(TABLES[table][0])} = c.customer_id)',
        'colonnes': [('c.customer_id', 'customer_id', 'N° IFS'), _SAP, _NOM, ('c.country_db', 'pays', 'Pays')],
        'recherche': _RECHERCHE,
        'cle': 'c.customer_id',
        'ordre': 'c.customer_id',
    }


def _source(key):
    if key == 'synthese':
        return _source_synthese()
    return _source_table(key) if key in TABLES else _source_controle(key)


@ifs_data_clients_blueprint.route('', methods=['GET'])
@jwt_required()
def liste():
    return lister(ONGLETS, _source, SYNC_KEY)


@ifs_data_clients_blueprint.route('/export.xlsx', methods=['GET'])
@jwt_required()
def export():
    return exporter(ONGLETS, _source, 'clients_ifs')

# Tables SAP lues par les procedures sp_insert_* du module ; le fichier et les tables PHL viennent de l'import
_SAP_TABLES = ['KNA1', 'KNB1', 'KNVV', 'KNBK', 'ADRC', 'ADR2', 'ADR3', 'ADR6', 'T005T']

lancer_sync = routes_sync(ifs_data_clients_blueprint, SYNC_KEY, 'etl_file_customer.py',
                          'SELECT count(DISTINCT customer_id) FROM clean_data.customer_info', tables_sap=_SAP_TABLES)
