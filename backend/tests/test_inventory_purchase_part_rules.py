"""
Regles metier des chargements inventory (2026-09-18, demandes explicites) :

1. clean_data.alimenter_purchase_part() : TOUS les articles SAP du catalogue
   (part_catalog ∩ raw_data.mara) deviennent des articles d'achat, y compris
   ceux sans type d'approvisionnement externe (marc.beskz vide ou 'E') et les
   articles de vente.
2. clean_data.alimenter_purchase_part_supplier() : un article a plusieurs
   fournisseurs mais UN SEUL fournisseur principal par (site, article) :
   primary_vendor_db = 'Y' sur une ligne, 'N' sur toutes les autres. Le
   principal est le fournisseur fixe de la liste de sources SAP (raw_data.eord,
   flifn = 'X') quand il fait partie des liens charges.

Vraie base, transaction jamais validee. Les fonctions du depot sont
recompilees dans la transaction (CREATE OR REPLACE) pour tester la version du
fichier, et les tables cibles rechargees dans cette meme transaction.
"""
import os
import sys

import psycopg2
import psycopg2.extras
import pytest

BACKEND = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SQL_DIR = os.path.join(os.path.dirname(BACKEND), 'sql', 'inventory')
if BACKEND not in sys.path:
    sys.path.insert(0, BACKEND)

PP = 'clean_data.purchase_part'
PPS = 'clean_data.purchase_part_supplier'


@pytest.fixture(scope='module')
def cur():
    try:
        try:
            from config.database import get_db_params
            params = get_db_params()
        except ImportError:
            # Hote sans pandas : memes variables d'environnement que le backend
            params = {'host': os.getenv('DB_HOST', '10.190.100.58'), 'port': os.getenv('DB_PORT', '5432'),
                      'database': os.getenv('DB_NAME', 'sap_migration_db'),
                      'user': os.getenv('DB_USER', 'postgres'), 'password': os.getenv('DB_PASSWORD', '')}
        conn = psycopg2.connect(**params)
    except Exception as exc:  # pragma: no cover
        pytest.skip(f'base injoignable : {exc}')
    try:
        cur = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
        cur.execute("SET statement_timeout = '600s'")
        for name in ('alimenter_purchase_part.sql', 'alimenter_purchase_part_supplier.sql'):
            with open(os.path.join(SQL_DIR, name), encoding='utf-8') as f:
                cur.execute(f.read())
        # purchase_part_supplier depend de purchase_part : rechargement dans l'ordre
        cur.execute("SELECT clean_data.alimenter_purchase_part()")
        cur.execute("SELECT clean_data.alimenter_purchase_part_supplier()")
        yield cur
    finally:
        conn.rollback()
        conn.close()


def _one(cur, sql, params=None):
    cur.execute(sql, params or [])
    return cur.fetchone()


# ---------------------------------------------------------------- purchase_part

def test_tout_article_sap_du_catalogue_est_un_article_achat(cur):
    r = _one(cur, f"""
        SELECT count(*) AS manquants
        FROM clean_data.part_catalog pc
        JOIN raw_data.mara m ON LTRIM(m.matnr, '0') = pc.part_no AND m.mandt = '700'
        WHERE (m.lvorm IS NULL OR m.lvorm = '')
          AND EXISTS (SELECT 1 FROM raw_data.marc c
                      WHERE c.matnr = m.matnr AND c.mandt = '700' AND c.werks IN ('9200', '9000'))
          AND NOT EXISTS (SELECT 1 FROM {PP} pp WHERE pp.part_no = pc.part_no)""")
    assert r['manquants'] == 0


def test_les_articles_de_vente_sont_aussi_des_articles_achat(cur):
    r = _one(cur, f"""
        SELECT count(*) AS n
        FROM {PP} pp
        WHERE EXISTS (SELECT 1 FROM raw_data.articles_vente_sap avs
                      WHERE LTRIM(TRIM(avs.article), '0') = pp.part_no)""")
    assert r['n'] > 0


def test_pas_de_doublon_site_article(cur):
    r = _one(cur, f"SELECT count(*) - count(DISTINCT (contract, part_no)) AS doublons FROM {PP}")
    assert r['doublons'] == 0


# ------------------------------------------------------- purchase_part_supplier

def test_un_seul_fournisseur_principal_par_site_article(cur):
    r = _one(cur, f"""
        SELECT count(*) FILTER (WHERE nb_y <> 1) AS anomalies, count(*) AS articles
        FROM (SELECT contract, part_no, count(*) FILTER (WHERE primary_vendor_db = 'Y') AS nb_y
              FROM {PPS} GROUP BY contract, part_no) t""")
    assert r['articles'] > 0
    assert r['anomalies'] == 0


def test_les_autres_fournisseurs_sont_a_n(cur):
    r = _one(cur, f"SELECT count(*) AS n FROM {PPS} WHERE primary_vendor_db NOT IN ('Y', 'N') OR primary_vendor_db IS NULL")
    assert r['n'] == 0


def test_le_fournisseur_fixe_sap_est_le_principal(cur):
    """Quand le fournisseur fixe EORD (division du site, valide a date) est parmi
    les liens de l'article, c'est lui qui porte le 'Y'."""
    r = _one(cur, f"""
        WITH fixe AS (
            SELECT LTRIM(e.matnr, '0') AS part_no,
                   CASE e.werks WHEN '9200' THEN 'SJ' ELSE 'CS' END AS contract,
                   sig.supplier_id AS vendor_no
            FROM raw_data.eord e
            JOIN clean_data.supplier_info_general sig
              ON LTRIM(TRIM(sig.supplier_legacy_sap_id), '0') = LTRIM(TRIM(e.lifnr), '0')
            WHERE e.mandt = '700' AND e.flifn = 'X' AND e.werks IN ('9200', '9000')
              AND COALESCE(NULLIF(e.vdatu, ''), '00000000') <= to_char(current_date, 'YYYYMMDD')
              AND COALESCE(NULLIF(e.bdatu, ''), '99991231') >= to_char(current_date, 'YYYYMMDD')
        )
        SELECT count(*) AS lies,
               count(*) FILTER (WHERE pps.primary_vendor_db = 'Y') AS principaux
        FROM fixe f
        JOIN {PPS} pps ON pps.contract = f.contract AND pps.part_no = f.part_no AND pps.vendor_no = f.vendor_no""")
    assert r['lies'] > 0
    assert r['principaux'] == r['lies']
