# -*- coding: utf-8 -*-
"""
sql_filters — Filet de sécurité : retire les filtres techniques SAP du SQL
généré par le modèle AVANT validation/exécution.

Décision projet (2026-06-15) : les requêtes de l'Assistant IA sont « simples »,
SANS mandt / loevm / lvorm / loekz / stblg. Malgré cette consigne dans le SOCLE,
le modèle (qui connaît SAP par entraînement) ajoute parfois ces prédicats sur des
tables qui n'ont pas la colonne -> erreur PostgreSQL 42703 « column loevm does not
exist » (cf. ai_query_log). Plutôt que d'espérer que le modèle obéisse, on retire
ces prédicats de sa sortie : source-agnostique, aligné sur la décision projet.

Couvre les deux formes rencontrées : `col = '...'` (et <> / !=) et `col IS [NOT]
NULL`, en tête / milieu / seul dans le WHERE. N'altère RIEN d'autre (idempotent).
"""

import re

_FILTRES = r"(?:mandt|loevm|lvorm|loekz|stblg)"

# Un prédicat de filtre technique : la colonne suivie soit d'une comparaison à un
# littéral chaîne, soit d'un test IS [NOT] NULL.
_PRED = rf"{_FILTRES}\s*(?:(?:=|<>|!=)\s*'[^']*'|IS\s+(?:NOT\s+)?NULL)"

# Ordre important : retirer d'abord les prédicats en milieu de WHERE (`AND col…`
# puis `col… AND`), puis un éventuel WHERE réduit à un seul filtre technique.
_SUBSTITUTIONS = [
    (re.compile(rf"\s+AND\s+{_PRED}", re.I), ""),                     # … AND col = '…'
    (re.compile(rf"\b{_PRED}\s+AND\s+", re.I), ""),                   # col = '…' AND …
    (re.compile(rf"\s+WHERE\s+{_PRED}\s*(?=$|GROUP\s+BY|ORDER\s+BY|LIMIT\b|\))", re.I), " "),
]


def strip_technical_filters(sql: str) -> str:
    """Retire les prédicats de filtres techniques SAP d'une requête. Idempotent.
    Renvoie la requête inchangée si elle n'en contient pas."""
    out = sql or ""
    for regex, remplacement in _SUBSTITUTIONS:
        out = regex.sub(remplacement, out)
    return re.sub(r"\s{2,}", " ", out).strip()
