"""Ecran Donnees IFS > Articles (/ifs-data/articles) : consultation des tables clean_data
exportees vers IFS par les modules ETL articles, regroupees par theme.

  GET  /api/v1/ifs-data/articles              onglet, table, search, page, page_size
  GET  /api/v1/ifs-data/articles/export.xlsx  onglet, search : une feuille par table de l'onglet
  GET  /api/v1/ifs-data/articles/sync         etat de la derniere synchronisation
  POST /api/v1/ifs-data/articles/sync         {"source": "mf"} modules ETL seuls ; {"source": "sap"}
                                              extraction SAP puis modules ETL

Lecture seule : un rechargement ecraserait toute modification faite dans ces tables. Le rechargement
est celui de Donnees SAP > Articles (meme etat, donc une seule synchronisation a la fois entre les
deux ecrans). article_perimetre (Finance > Articles) pilote le catalogue, donc ses tables filles ;
les articles de ifs_article_maitre hors perimetre apparaissent dans les controles.
"""
from flask import Blueprint, jsonify
from flask_jwt_extended import jwt_required

from .finance import _read_status, _start_sync, _sync_source
from .ifs_consultation import colonnes_catalogue, colonnes_table, exporter, lister
from .sap_articles import ARTICLE_SAP_TABLES, _charger_modules, q

ifs_data_articles_blueprint = Blueprint('ifs_data_articles', __name__)

SYNC_KEY = 'articles_sap'  # celle de Donnees SAP > Articles

TABLES = {
    'part_catalog': 'Catalogue',
    'inventory_part': 'Articles en stock',
    'invent_part_plan': 'Planification',
    'purchase_part': "Articles d'achat",
    'purchase_part_supplier': 'Fournisseurs par article',
    'sales_part': 'Articles de vente',
    'manuf_part_attribute': 'Attributs de fabrication',
}
# Recherche complementaire au numero et a la designation de l'article
_RECHERCHE = {'purchase_part_supplier': ['t.vendor_no'], 'sales_part': ['t.catalog_no', 't.catalog_desc']}

_FILLES = [t for t in TABLES if t != 'part_catalog']
CONTROLES = ['fichier_non_charge', 'hors_fichier', 'maitre_non_charge', 'stock_sans_plan', 'achat_sans_fournisseur',
             'fournisseur_inconnu'] + [f'orphelin_{t}' for t in _FILLES]

ONGLETS = {
    'synthese': ['synthese'],
    'catalogue': ['part_catalog'],
    'stock': ['inventory_part', 'invent_part_plan'],
    'achats': ['purchase_part', 'purchase_part_supplier'],
    'vente': ['sales_part'],
    'fabrication': ['manuf_part_attribute'],
    'controles': CONTROLES,
}

_CATALOGUE = 'clean_data.part_catalog g'
# ifs_article_maitre garde les zeros de tete SAP (000000000000101760), retires dans part_catalog (101760)
_NUMERO_MAITRE = "LTRIM(m.numero_article, '0')"
_ABSENT_CATALOGUE = 'NOT EXISTS (SELECT 1 FROM clean_data.part_catalog g WHERE g.part_no = {0})'
_ID_LIGNE = [('t.part_no', 'part_no', 'N° article'),
             ('g.description', 'article_designation', 'Désignation catalogue'),
             ('t.contract', 'contract', 'Site')]


def _sites(alias, table):
    return (f"LEFT JOIN (SELECT part_no AS c, string_agg(DISTINCT contract, ', ' ORDER BY contract) AS s "
            f"FROM clean_data.{q(table)} GROUP BY 1) {alias} ON {alias}.c = g.part_no")


def _source_synthese():
    return {
        'label': 'Synthèse',
        'from': f"""{_CATALOGUE}
            LEFT JOIN clean_data.ifs_article_maitre m ON {_NUMERO_MAITRE} = g.part_no
            LEFT JOIN clean_data.article_perimetre p ON p.numero_article = g.part_no
            {_sites('i', 'inventory_part')}
            {_sites('a', 'purchase_part')}
            {_sites('v', 'sales_part')}
            {_sites('f', 'manuf_part_attribute')}
            LEFT JOIN (SELECT part_no AS c, count(DISTINCT vendor_no) AS n
                       FROM clean_data.purchase_part_supplier GROUP BY 1) s ON s.c = g.part_no""",
        'colonnes': [
            ('g.part_no', 'part_no', 'N° article'),
            ('g.description', 'designation', 'Désignation'),
            ('g.unit_code', 'unite', 'Unité'),
            ('m.numero_article IS NOT NULL', 'dans_sap', 'Périmètre SAP'),
            ('p.numero_article IS NOT NULL', 'dans_fichier', 'Fichier validé'),
            ('i.s', 'sites_stock', 'Sites stock'),
            ('a.s', 'sites_achat', 'Sites achat'),
            ('v.s', 'sites_vente', 'Sites vente'),
            ('f.s', 'sites_fabrication', 'Sites fabrication'),
            ('COALESCE(s.n, 0)', 'nb_fournisseurs', 'Fournisseurs'),
        ],
        'recherche': ['g.part_no', 'g.description'],
        'cle': 'g.part_no',
        'ordre': 'g.part_no',
    }


def _source_table(table):
    if table == 'part_catalog':
        return {
            'label': TABLES[table],
            'from': _CATALOGUE,
            'colonnes': [('g.part_no', 'part_no', 'N° article'), ('g.description', 'description', 'Désignation')]
                        + colonnes_catalogue(table, colonnes_table(table, 'part_no', 'description'), 'g'),
            'recherche': ['g.part_no', 'g.description'],
            'cle': 'g.part_no',
            'ordre': 'g.part_no',
        }
    return {
        'label': TABLES[table],
        'from': f'clean_data.{q(table)} t LEFT JOIN {_CATALOGUE} ON g.part_no = t.part_no',
        'colonnes': _ID_LIGNE + colonnes_catalogue(table, colonnes_table(table, 'part_no', 'contract')),
        'recherche': ['t.part_no', 'g.description'] + _RECHERCHE.get(table, []),
        'cle': 't.part_no',
        'ordre': 't.part_no, t.contract, t.ctid',
    }


def _source_controle_ligne(label, table, where, *colonnes):
    return {
        'label': label,
        'from': f'clean_data.{q(table)} t LEFT JOIN {_CATALOGUE} ON g.part_no = t.part_no',
        'where': where,
        'colonnes': _ID_LIGNE + list(colonnes),
        'recherche': ['t.part_no', 'g.description'],
        'cle': 't.part_no',
        'ordre': 't.part_no, t.contract, t.ctid',
    }


def _source_controle(code):
    if code == 'fichier_non_charge':
        return {
            'label': 'Fichier validé non chargé',
            'from': 'clean_data.article_perimetre p LEFT JOIN clean_data.ifs_article_maitre m '
                    f'ON {_NUMERO_MAITRE} = p.numero_article',
            'where': "p.source = 'FICHIER' AND " + _ABSENT_CATALOGUE.format('p.numero_article'),
            'colonnes': [('p.numero_article', 'part_no', 'N° article'),
                         ('m.designation', 'designation', 'Désignation SAP'),
                         ('m.numero_article IS NOT NULL', 'dans_sap', 'Périmètre SAP')],
            'recherche': ['p.numero_article', 'm.designation'],
            'cle': 'p.numero_article',
            'ordre': 'p.numero_article',
        }
    if code == 'hors_fichier':
        return {
            'label': 'Chargé hors fichier validé',
            'from': f'{_CATALOGUE} LEFT JOIN clean_data.ifs_article_maitre m ON {_NUMERO_MAITRE} = g.part_no',
            'where': 'NOT EXISTS (SELECT 1 FROM clean_data.article_perimetre p WHERE p.numero_article = g.part_no)',
            'colonnes': [('g.part_no', 'part_no', 'N° article'), ('g.description', 'designation', 'Désignation'),
                         ('m.numero_article IS NOT NULL', 'dans_sap', 'Périmètre SAP')],
            'recherche': ['g.part_no', 'g.description'],
            'cle': 'g.part_no',
            'ordre': 'g.part_no',
        }
    if code == 'maitre_non_charge':
        return {
            'label': 'Périmètre SAP non chargé',
            'from': 'clean_data.ifs_article_maitre m',
            'where': _ABSENT_CATALOGUE.format(_NUMERO_MAITRE),
            'colonnes': [('m.numero_article', 'part_no', 'N° article'), ('m.designation', 'designation', 'Désignation SAP')],
            'recherche': ['m.numero_article', 'm.designation'],
            'cle': 'm.numero_article',
            'ordre': 'm.numero_article',
        }
    if code == 'stock_sans_plan':
        return _source_controle_ligne(
            'Stock sans planification', 'inventory_part',
            'NOT EXISTS (SELECT 1 FROM clean_data.invent_part_plan x '
            'WHERE x.part_no = t.part_no AND x.contract = t.contract)')
    if code == 'achat_sans_fournisseur':
        return _source_controle_ligne(
            'Achat sans fournisseur', 'purchase_part',
            'NOT EXISTS (SELECT 1 FROM clean_data.purchase_part_supplier x '
            'WHERE x.part_no = t.part_no AND x.contract = t.contract)')
    if code == 'fournisseur_inconnu':
        return _source_controle_ligne(
            'Fournisseur non chargé', 'purchase_part_supplier',
            'NOT EXISTS (SELECT 1 FROM clean_data.supplier x WHERE x.vendor_no = t.vendor_no)',
            ('t.vendor_no', 'vendor_no', 'N° fournisseur'))
    table = code[len('orphelin_'):]
    # sales_part.part_no peut etre vide (article de vente sans article stocke) : ce n'est pas un orphelin
    return _source_controle_ligne(f'Hors catalogue : {TABLES[table]}', table,
                                  't.part_no IS NOT NULL AND ' + _ABSENT_CATALOGUE.format('t.part_no'))


def _source(key):
    if key == 'synthese':
        return _source_synthese()
    return _source_table(key) if key in TABLES else _source_controle(key)


@ifs_data_articles_blueprint.route('', methods=['GET'])
@jwt_required()
def liste():
    return lister(ONGLETS, _source, SYNC_KEY)


@ifs_data_articles_blueprint.route('/export.xlsx', methods=['GET'])
@jwt_required()
def export():
    return exporter(ONGLETS, _source, 'articles_ifs')


@ifs_data_articles_blueprint.route('/sync', methods=['GET'])
@jwt_required()
def etat_sync():
    return jsonify(_read_status(SYNC_KEY) or {'status': 'never'})


@ifs_data_articles_blueprint.route('/sync', methods=['POST'])
@jwt_required()
def lancer_sync():
    return _start_sync(SYNC_KEY, ARTICLE_SAP_TABLES, 'articles et catalogue IFS', _charger_modules,
                       extraire=_sync_source() == 'sap')
