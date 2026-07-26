# -*- coding: utf-8 -*-
"""
ai_schema_retriever — Récupération RAG du schéma pertinent pour l'Assistant IA.

Au lieu d'un system prompt statique listant toutes les tables (impossible à
l'échelle des ~178 tables de raw_data, et qui sature num_ctx=4096), on sélectionne
PAR QUESTION les quelques tables utiles, puis on construit leur schéma à la volée
depuis le dictionnaire de données réel (public.sap_table_fields, libellés FR).

Stratégie de sélection (HYBRIDE — validée par test sur la base) :
  1. DOMAIN_TABLES : map d'alias curée (mots-clés métier -> tables sûres). Reprend la
     connaissance déjà encodée dans ai_system_prompt.py. Garantit que les questions
     fréquentes tapent TOUJOURS sur les bonnes tables (le FTS seul rate "facture" et
     "équipement").
  2. Repli FTS français sur le dictionnaire pour la longue traîne (questions non
     couvertes par la map) : OU des lexèmes + classement ts_rank.

Le schéma renvoyé ne contient QUE des colonnes réelles -> supprime par construction
les hallucinations de colonnes (erreur PostgreSQL 42703).

Module autonome : testable seul via `python -m services.ai_schema_retriever "ma question"`.
Pas encore branché dans le pipeline ; le câblage (build_dynamic_prompt) est l'incrément suivant.
"""

import re
import sys
import unicodedata
import logging

from config.database import get_db_connection
from services.ai_embeddings import embed, to_pgvector
from services.ai_config_store import get_domain_tables_db
from services.ai_rag_budget import get_budget

logger = logging.getLogger(__name__)

# Nombre de tables max injectées dans le prompt, et de colonnes max par table.
MAX_TABLES = 7
MAX_COLS_PAR_TABLE = 18

# Plus de colonnes épinglées : on ne force plus les filtres techniques SAP
# (mandt / loevm / lvorm / loekz / stblg) dans le schéma injecté. Les requêtes
# portent sur les principaux champs (clés + colonnes liées à la question + position).
PINNED_COLUMNS = set()

# --------------------------------------------------------------------------- #
# 1) Map d'alias curée : mots-clés -> tables cœur (noms SCHÉMA-qualifiés)
#    Tout mot-clé présent dans la question (après normalisation sans accents)
#    déclenche l'ajout de ses tables. L'ordre des entrées = priorité.
# --------------------------------------------------------------------------- #
# 3-uplets : (domain_id, déclencheurs, [tables]). Le domain_id sert à charger le
# « pack de connaissances » correspondant (backend/config/skills/<domain_id>.json)
# ET à garder cohérents tables retrouvées + pack injecté. Plusieurs entrées peuvent
# partager un même domain_id (ex. article/stock/valorisation -> articles_stock).
# REPLI : utilisé si la table éditable public.ai_domain_tables est vide/indispo.
_DOMAIN_TABLES_DEFAUT = [
    ("factures", {"facture", "factures", "invoice"},
     ["raw_data.rbkp", "raw_data.rseg", "raw_data.lfa1"]),
    ("banque", {"banque", "bancaire", "iban", "rib", "swift", "bic"},
     ["raw_data.lfbk", "raw_data.bnka", "raw_data.lfa1"]),
    ("achats", {"infoachat", "info-achat", "approvisionnement", "appro"},
     ["raw_data.eina", "raw_data.eine", "raw_data.eord"]),
    ("achats", {"commande", "commandes", "achat", "achats", "order"},
     ["raw_data.ekko", "raw_data.ekpo", "raw_data.ekbe", "raw_data.lfa1"]),
    ("fournisseurs", {"fournisseur", "fournisseurs", "vendeur", "supplier"},
     ["raw_data.lfa1", "raw_data.lfb1", "raw_data.lfm1"]),
    ("articles_stock", {"valorisation", "valeur", "prix", "pmp", "cout", "couts"},
     ["raw_data.mbew", "raw_data.mara"]),
    ("articles_stock", {"stock", "stocks", "magasin", "quantite", "quantites"},
     ["raw_data.mard", "raw_data.mara", "raw_data.marc"]),
    ("articles_stock", {"article", "articles", "matiere", "matieres", "produit", "produits"},
     ["raw_data.mara", "raw_data.makt", "raw_data.marc"]),
    ("clients", {"client", "clients", "customer"},
     ["raw_data.kna1"]),
    ("equipements", {"equipement", "equipements", "equipment", "materiel"},
     ["raw_data.equi"]),
    ("postes_techniques", {"poste", "postes", "technique", "techniques", "fonctionnel", "hierarchie"},
     ["raw_data.iflot"]),
    ("codification", {"codification", "codifie", "mapping"},
     ["clean_data.mapping_codification_articles", "raw_data.mara", "raw_data.makt"]),
    ("pays", {"pays", "region", "regions"},
     ["raw_data.t005t"]),
    ("dictionnaire", {"dictionnaire", "signification", "definition", "champ", "champs", "colonne"},
     ["public.sap_table_fields", "public.sap_table_properties"]),
]


def _normalize(texte: str) -> str:
    """Minuscule + suppression des accents (pas d'extension unaccent en base)."""
    if not texte:
        return ""
    nfkd = unicodedata.normalize("NFKD", texte.lower())
    return "".join(c for c in nfkd if not unicodedata.combining(c))


# Mots vides FR à ne pas utiliser pour le boost colonnes (sinon faux positifs,
# ex. "leur" est un sous-mot de "valeur"). Normalisés, sans accents.
_STOPWORDS = {
    "avec", "leur", "leurs", "pour", "dans", "cette", "votre", "notre", "sans",
    "sous", "elle", "donne", "donner", "donnez", "liste", "lister", "tous",
    "tout", "toute", "toutes", "quel", "quelle", "quels", "quelles", "combien",
    "plus", "moins", "entre", "depuis", "selon", "chaque", "ainsi", "dont",
    "mais", "comme", "fait", "faire", "montre", "montrer", "affiche", "afficher",
    "trouve", "trouver", "veux", "peux", "peut", "entre", "ayant", "entre",
}


def _question_tokens(question: str) -> list:
    """Préfixes de mots significatifs (>=4 lettres, hors mots vides), tronqués à 5
    pour absorber les variations morphologiques (facture/facturation -> 'factu')."""
    return [t[:5] for t in _normalize(question).replace("-", " ").split()
            if len(t) >= 4 and t not in _STOPWORDS]


def get_domain_tables() -> list:
    """Associations mot-clé->tables : base éditable (ai_domain_tables) en priorité,
    sinon repli sur le défaut codé. Format : [(domain_id, set(keywords), [tables])]."""
    db = get_domain_tables_db()
    return db if db else _DOMAIN_TABLES_DEFAUT


def _match_domain_tables(question: str) -> list:
    """Tables déclenchées par la map d'alias, dédupliquées en préservant l'ordre."""
    mots = set(_normalize(question).replace("-", " ").split())
    tables, vus = [], set()
    for _domain_id, declencheurs, tbls in get_domain_tables():
        if mots & declencheurs:
            for t in tbls:
                if t not in vus:
                    vus.add(t)
                    tables.append(t)
    return tables


def detect_domains(question: str) -> list:
    """
    Domaines déclenchés par les mots-clés DOMAIN_TABLES, dans l'ordre de priorité
    (ordre des entrées), dédupliqués. Sert à charger le(s) pack(s) de connaissances.
    Les keywords/synonymes propres aux packs sont une 2e source de déclenchement,
    appliquée côté ai_prompt_builder (phrases non présentes dans DOMAIN_TABLES).
    """
    mots = set(_normalize(question).replace("-", " ").split())
    domaines, vus = [], set()
    for domain_id, declencheurs, _tbls in get_domain_tables():
        if (mots & declencheurs) and domain_id not in vus:
            vus.add(domain_id)
            domaines.append(domain_id)
    return domaines


def _fts_fallback(question: str, conn, limit: int) -> list:
    """
    Repli plein-texte (français) sur le dictionnaire : renvoie des tables raw_data
    triées par pertinence. Utilisé quand la map d'alias ne couvre pas la question.
    """
    sql = """
        WITH dict AS (
          SELECT upper(p.table_name) AS tbl, p.description AS descr,
                 string_agg(coalesce(f.field_text,''), ' ') AS labels
          FROM public.sap_table_properties p
          LEFT JOIN public.sap_table_fields f ON upper(f.table_name)=upper(p.table_name)
          GROUP BY p.table_name, p.description
        ),
        doc AS (
          SELECT tbl,
                 setweight(to_tsvector('french', coalesce(descr,'')), 'A') ||
                 setweight(to_tsvector('french', coalesce(labels,'')), 'B') AS tsv
          FROM dict
        ),
        oq AS (
          SELECT nullif(replace(plainto_tsquery('french', %s)::text, '&', '|'), '')::tsquery AS query
        )
        SELECT lower(d.tbl)
        FROM doc d, oq
        WHERE oq.query IS NOT NULL AND d.tsv @@ oq.query
        ORDER BY ts_rank(d.tsv, oq.query) DESC
        LIMIT %s
    """
    with conn.cursor() as cur:
        cur.execute(sql, (question, limit))
        return ["raw_data." + r[0] for r in cur.fetchall()]


def _semantic_tables(question: str, conn, limit: int) -> list:
    """
    Complément SÉMANTIQUE : tables les plus proches de la question par similarité
    cosinus sur public.ai_embeddings (kind='table', cf. build_ai_index.py).

    Capte les reformulations que la map d'alias et le FTS ratent (« qui nous
    livre » -> fournisseur). Renvoie des noms déjà schéma-qualifiés (ref_id).
    Tolérant aux pannes : si les embeddings ou l'index sont indisponibles, renvoie
    [] et le pipeline retombe sur map + FTS (jamais de blocage).
    """
    vector = embed(question)
    if vector is None:
        return []
    try:
        with conn.cursor() as cur:
            cur.execute(
                """
                SELECT ref_id
                FROM public.ai_embeddings
                WHERE kind = 'table'
                ORDER BY embedding <=> %s::vector
                LIMIT %s
                """,
                (to_pgvector(vector), limit),
            )
            return [r[0] for r in cur.fetchall()]
    except Exception as e:
        logger.warning(f"⚠️ Recherche sémantique des tables indisponible : {e}")
        return []


def retrieve_tables(question: str, conn=None) -> list:
    """
    Sélectionne les tables pertinentes pour `question`. Stratégie en cascade :
      1. map d'alias curée (DOMAIN_TABLES) — priorité, garantit les bonnes tables
         sur les questions fréquentes (et couvre clean_data/public) ;
      2. complément SÉMANTIQUE (embeddings) pour les reformulations ;
      3. repli FTS si l'ensemble reste trop maigre (embeddings indisponibles).
    Renvoie des noms schéma-qualifiés. Ouvre sa propre connexion si besoin.
    """
    if conn is None:
        with get_db_connection() as c:
            return retrieve_tables(question, c)
    max_tables = get_budget()["max_tables"]
    tables = _match_domain_tables(question)
    # Complément sémantique (sans doublon, map prioritaire).
    for t in _semantic_tables(question, conn, max_tables):
        if t not in tables:
            tables.append(t)
    if len(tables) < 2:  # map + sémantique insuffisants -> repli FTS
        for t in _fts_fallback(question, conn, max_tables):
            if t not in tables:
                tables.append(t)
    logger.info(f"RAG tables pour «{question[:60]}» : {tables[:max_tables]}")
    return tables[:max_tables]


def _columns_from_dictionary(conn, table: str, qtokens=None) -> list:
    """
    Colonnes d'une table raw_data depuis sap_table_fields.
    Priorité : (0) clés, (1) colonnes dont le nom/libellé matche la question,
    (2) le reste par position. Plafonné à MAX_COLS_PAR_TABLE.
    Le boost question-aware fait remonter les colonnes métier tardives
    (ex. stcd1=SIRET, loevm) que le simple tri par position écarterait.
    """
    # abap_type = vrai type ABAP (CHAR/QUAN/CURR/DATS...), contrairement à data_type
    # qui porte souvent le data element (rollname). field_name/check_table sont
    # parfois paddés d'espaces dans le dictionnaire -> TRIM.
    sql = """
        SELECT lower(trim(field_name)), coalesce(field_text,''), key_flag, position,
               coalesce(abap_type,''), trim(coalesce(check_table,'')), coalesce(length,0)
        FROM public.sap_table_fields
        WHERE upper(table_name) = upper(%s)
        ORDER BY position
    """
    with conn.cursor() as cur:
        cur.execute(sql, (table,))
        rows = cur.fetchall()

    qtokens = qtokens or []

    def priorite(row):
        nom, txt, key_flag, _pos, _ab, _ck, _len = row
        if key_flag or nom in PINNED_COLUMNS:
            return 0
        hay = _normalize(nom + " " + txt)
        return 1 if any(tok in hay for tok in qtokens) else 2

    rows.sort(key=lambda r: (priorite(r), r[3]))
    # (nom, libellé, abap_type, check_table/FK, length) — type, FK et taille
    # servent au rendu compact (cast + jointure + largeur) dans build_schema_block.
    return [(nom, txt, ab, ck, lng)
            for nom, txt, _kf, _pos, ab, ck, lng in rows[:get_budget()["max_cols"]]]


def _columns_from_information_schema(conn, schema: str, table: str) -> list:
    """Repli pour clean_data/public (absentes du dictionnaire SAP) : noms +
    libellés issus de COMMENT ON COLUMN quand ils existent.
    Même forme de tuple que _columns_from_dictionary (type/FK/length vides)."""
    sql = """
        SELECT c.column_name,
               coalesce(col_description(pc.oid, c.ordinal_position), ''),
               '', '', 0
        FROM information_schema.columns c
        JOIN pg_catalog.pg_class pc ON pc.relname = c.table_name
        JOIN pg_catalog.pg_namespace n ON n.oid = pc.relnamespace
                                       AND n.nspname = c.table_schema
        WHERE c.table_schema = %s AND c.table_name = %s
        ORDER BY c.ordinal_position
        LIMIT %s
    """
    with conn.cursor() as cur:
        cur.execute(sql, (schema, table, get_budget()["max_cols"]))
        return cur.fetchall()


# Types ABAP « notables » : signalés au modèle car ils exigent un CAST (numériques :
# montants/quantités) ou un format particulier (dates YYYYMMDD). Les CHAR (cas par
# défaut) ne sont PAS annotés pour économiser des tokens. NUMC volontairement exclu
# (souvent des identifiants en chiffres, pas des valeurs à sommer).
_TYPE_HINTS = {
    "QUAN": "num", "CURR": "num", "DEC": "num", "FLTP": "num",
    "INT1": "num", "INT2": "num", "INT4": "num",
    "DATS": "date", "TIMS": "time",
}


def _type_hint(abap_type: str) -> str:
    """Indice court pour un type ABAP notable (num/date/time), '' sinon."""
    return _TYPE_HINTS.get((abap_type or "").upper(), "")


def _format_colonne(col) -> str:
    """
    Rendu compact d'une colonne : `nom (libellé) [type+taille ->check_table]`.
    La taille n'est affichée que là où elle est utile (numériques/dates, ou
    identifiants CHAR porteurs d'une FK) — les CHAR ordinaires restent nus pour
    économiser des tokens. Ex : `menge (Quantite) [num13]`, `lifnr (...) [c10 ->lfa1]`.
    """
    nom, txt, abap, ck, lng = col
    rendu = f"{nom} ({txt})" if txt else nom
    extras = []
    hint = _type_hint(abap)
    if hint:
        extras.append(f"{hint}{lng}" if lng else hint)
    elif ck:  # CHAR identifiant avec FK : la largeur aide (zéros de tête, jointures)
        extras.append(f"c{lng}" if lng else "c")
    if ck:
        extras.append(f"->{ck.lower()}")
    if extras:
        rendu += " [" + " ".join(extras) + "]"
    return rendu


def build_schema_block(question: str, conn=None, tables=None) -> str:
    """
    Construit le bloc « schéma ciblé » à injecter dans le prompt, pour les tables
    pertinentes à `question`. Une ligne par table :
        raw_data.ekpo : ebeln (Numéro du document d'achat) [c10 ->ekko], ...
    `tables` : si fourni (déjà retrouvé en amont), évite un nouvel appel à
    retrieve_tables (et donc un second embedding de la question).
    """
    if conn is None:
        with get_db_connection() as c:
            return build_schema_block(question, c, tables)
    if tables is None:
        tables = retrieve_tables(question, conn)
    qtokens = _question_tokens(question)
    lignes = []
    for qualifie in tables:
        schema, _, table = qualifie.partition(".")
        if schema == "raw_data":
            cols = _columns_from_dictionary(conn, table, qtokens)
        else:
            cols = _columns_from_information_schema(conn, schema, table)
        if not cols:
            continue
        rendu = ", ".join(_format_colonne(c) for c in cols)
        lignes.append(f"{qualifie} : {rendu}")
    return "\n".join(lignes)


# Références schéma-qualifiées dans un SQL généré (pour l'auto-correction).
_TABLE_REF_RE = re.compile(r"\b(raw_data|clean_data|public)\.([a-z0-9_]+)", re.IGNORECASE)

# Nombre max de tables re-décrites dans un prompt de réparation.
_MAX_TABLES_REPAIR = 4


def _tables_in_sql(sql: str) -> list:
    """Tables schéma-qualifiées référencées par un SQL, dédupliquées, en ordre."""
    tables = []
    for m in _TABLE_REF_RE.finditer(sql or ""):
        t = f"{m.group(1).lower()}.{m.group(2).lower()}"
        if t not in tables:
            tables.append(t)
    return tables


def schema_for_sql(sql: str, conn=None) -> str:
    """
    Bloc « schéma réel » des tables référencées par un SQL fautif, destiné au
    prompt d'auto-correction : le modèle corrige avec les VRAIES colonnes au
    lieu de re-deviner. '' si aucune table reconnue.
    """
    tables = _tables_in_sql(sql)[:_MAX_TABLES_REPAIR]
    if not tables:
        return ""
    return build_schema_block("", conn, tables=tables)


if __name__ == "__main__":
    # Test autonome (à lancer sur le serveur) :
    #   python -m services.ai_schema_retriever "donne moi une facture fournisseur"
    logging.basicConfig(level=logging.INFO)
    q = sys.argv[1] if len(sys.argv) > 1 else "donne moi une facture fournisseur"
    print(f"\n=== Question : {q}\n")
    print(build_schema_block(q))
