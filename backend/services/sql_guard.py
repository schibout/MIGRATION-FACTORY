"""
sql_guard — Validation défensive du SQL généré par l'Assistant IA.

Le SQL produit par le modèle local (Ollama) ne doit JAMAIS être exécuté tel
quel. Ce module en est le premier rempart (le second étant le rôle PostgreSQL
`readonly_ai` qui ne possède que le droit SELECT).

Stratégie : analyse syntaxique via `sqlparse` (et non des regex artisanales)
pour inspecter les *tokens* de mots-clés, ce qui évite de rejeter à tort un
mot interdit présent dans un littéral de chaîne (ex. WHERE name1 = 'UPDATE SA').

API publique :
    validate_and_wrap(sql, max_rows) -> str   # SQL sûr, borné par LIMIT
    SqlGuardError                              # levée avec un motif lisible
"""

import re
import sqlparse
from sqlparse import tokens as T

import logging

logger = logging.getLogger(__name__)


class SqlGuardError(Exception):
    """Requête rejetée par le garde SQL. `args[0]` contient le motif (FR)."""
    pass


# Mots-clés interdits (DDL / DML d'écriture / contrôle). Comparaison sur les
# tokens de type Keyword uniquement.
FORBIDDEN_KEYWORDS = {
    "INSERT", "UPDATE", "DELETE", "DROP", "ALTER", "TRUNCATE", "CREATE",
    "GRANT", "REVOKE", "COPY", "EXECUTE", "DO", "CALL", "SET", "VACUUM",
    "REINDEX", "CLUSTER", "REFRESH", "LISTEN", "NOTIFY", "MERGE",
    "INTO",  # bloque SELECT ... INTO (création de table)
    # NB : REPLACE et ANALYZE sont volontairement absents (fonctions/usages
    # légitimes) ; une instruction d'écriture en tête est déjà bloquée par le
    # contrôle du premier mot-clé (SELECT/WITH uniquement).
}

# Fonctions / objets dangereux (accès fichiers, sommeil, liens externes...).
# Comparaison sur les tokens de type Name.
FORBIDDEN_NAMES = {
    "dblink", "dblink_exec", "pg_sleep", "pg_read_file", "pg_read_binary_file",
    "pg_ls_dir", "pg_stat_file", "current_setting", "set_config",
    "query_to_xml", "copy_from", "copy_to",
}

# Schémas / préfixes système interdits dans la requête.
FORBIDDEN_NAME_PREFIXES = ("pg_", "lo_")
FORBIDDEN_SCHEMAS = {"information_schema", "pg_catalog"}

# Le schéma `public` n'est PAS interdit en bloc : le system prompt expose des
# tables de référence (fournisseurs à migrer, dictionnaire des champs SAP). Mais
# seules ces tables non sensibles sont autorisées en lecture ; tout le reste de
# `public` (users, system_config, ai_query_log, tokens...) reste interdit.
# Doit rester cohérent avec les GRANT du rôle readonly_ai (migration 013).
ALLOWED_PUBLIC_TABLES = {
    "fournisseurs_a_conserver",
    "sap_table_properties",
    "sap_table_fields",
}

# Repère toute référence schéma-qualifiée à public.<table>.
_PUBLIC_REF_RE = re.compile(r'\bpublic\.\s*"?([a-zA-Z_][a-zA-Z0-9_$]*)"?', re.IGNORECASE)


def _iter_leaf_tokens(parsed):
    """Itère sur les tokens feuilles (après aplatissement des groupes)."""
    for tok in parsed.flatten():
        yield tok


def _reject(reason: str):
    logger.warning(f"🛑 SQL rejeté par sql_guard : {reason}")
    raise SqlGuardError(reason)


def validate_and_wrap(sql: str, max_rows: int) -> str:
    """
    Valide `sql` et renvoie une version sûre bornée à `max_rows` lignes.

    Lève SqlGuardError si la requête n'est pas un SELECT/WITH en lecture seule.

    Le bornage se fait en **enveloppant** la requête dans une sous-requête :
        SELECT * FROM ( <requête> ) AS ai_sub LIMIT <max_rows>
    Cela préserve un ORDER BY / LIMIT déjà présent et ne casse pas les
    commentaires de fin de ligne (contrairement à une concaténation de LIMIT).
    """
    if sql is None or not str(sql).strip():
        _reject("Requête vide.")

    raw = str(sql).strip()

    # 1) Un seul statement autorisé (anti multi-requêtes / injection par ';').
    statements = [s for s in sqlparse.split(raw) if s.strip()]
    if len(statements) == 0:
        _reject("Aucune requête exploitable.")
    if len(statements) > 1:
        _reject("Plusieurs requêtes détectées : une seule instruction SELECT est autorisée.")

    statement = statements[0].strip().rstrip(";").strip()
    if not statement:
        _reject("Aucune requête exploitable.")

    parsed = sqlparse.parse(statement)
    if not parsed:
        _reject("Requête SQL illisible.")
    stmt = parsed[0]

    # 2) Le premier mot-clé significatif doit être SELECT ou WITH. C'est le
    #    garde-fou principal : combiné au scan de la liste noire (étape 3), il
    #    garantit qu'aucune écriture ne peut passer. On ne s'appuie PAS sur
    #    stmt.get_type() seul, dont le résultat varie selon les versions de
    #    sqlparse pour les CTE (WITH ... SELECT) et les requêtes entre parenthèses.
    first_kw = None
    for tok in stmt.flatten():
        if tok.is_whitespace or tok.ttype in T.Comment:
            continue
        if tok.ttype in T.Keyword:  # couvre Keyword.DML, Keyword.CTE, etc.
            first_kw = tok.normalized.upper()
            break
        # Une parenthèse ouvrante en tête est tolérée : ex. (SELECT ...) UNION ...
        if tok.ttype in T.Punctuation and tok.value == "(":
            continue
        # Tout autre premier token non-blanc est suspect.
        break
    if first_kw not in ("SELECT", "WITH"):
        _reject("La requête doit commencer par SELECT ou WITH.")

    # 4) Parcours des tokens feuilles : mots-clés interdits + noms dangereux.
    for tok in _iter_leaf_tokens(stmt):
        ttype, value = tok.ttype, tok.value
        if ttype is None:
            continue

        # 4a. Mots-clés (toutes sous-catégories : Keyword, Keyword.DML, Keyword.DDL...)
        if ttype in T.Keyword:
            kw = value.upper().strip()
            if kw in FORBIDDEN_KEYWORDS:
                _reject(f"Mot-clé interdit détecté : « {kw} ». Seule la lecture (SELECT) est permise.")

        # 4b. Noms / identifiants : fonctions dangereuses, préfixes & schémas système
        if ttype in T.Name or ttype in T.Name.Builtin:
            name = value.lower().strip('"')
            if name in FORBIDDEN_NAMES:
                _reject(f"Fonction interdite détectée : « {name} ».")
            if name.startswith(FORBIDDEN_NAME_PREFIXES):
                _reject(f"Objet système interdit : « {name} ».")
            if name in FORBIDDEN_SCHEMAS:
                _reject(f"Accès au schéma « {name} » interdit (lecture limitée à raw_data / clean_data).")

    # 4c) Schéma public : seules les tables de référence en liste blanche sont
    #     autorisées (les tables sensibles users/system_config/... restent hors
    #     de portée, et readonly_ai n'a de toute façon aucun droit dessus).
    for m in _PUBLIC_REF_RE.finditer(statement):
        table = m.group(1).lower()
        if table not in ALLOWED_PUBLIC_TABLES:
            _reject(
                f"Accès à public.{table} interdit. Tables public autorisées : "
                + ", ".join(sorted(ALLOWED_PUBLIC_TABLES)) + "."
            )

    # 5) Bornage du nombre de lignes par enveloppement.
    safe_max = int(max_rows)
    if safe_max <= 0:
        safe_max = 500
    wrapped = f"SELECT * FROM (\n{statement}\n) AS ai_sub LIMIT {safe_max}"
    return wrapped
