# -*- coding: utf-8 -*-
"""
clean_dataset_filters — Migration ponctuelle du dataset few-shot.

Retire des SQL d'exemple (champ assistant de config/dataset_sap_ia.jsonl) les
filtres techniques SAP devenus indésirables : `mandt='700'` et les filtres
d'enregistrements actifs `(loevm|lvorm|loekz|stblg) IS NULL OR ... = ''`.

But : les few-shots étant le signal le plus fort pour le modèle 7B, ils doivent
cesser de montrer ces filtres pour que l'assistant génère des requêtes simples
sur les principaux champs (cf. simplification décidée 2026-06-15).

Ne touche QUE le SQL des réponses assistant. Les questions, explications et le
bloc système (non utilisé à l'exécution) sont laissés intacts. Chaque SQL nettoyé
est validé (parenthèses équilibrées, commence par SELECT/WITH, pas de WHERE/AND
ballant) ; en cas d'échec de validation, l'exemple est laissé tel quel et signalé.

Usage (transformation pure stdlib, sans DB) :
    python clean_dataset_filters.py                 # nettoie sur place (backup .bak)
    python clean_dataset_filters.py --dry-run       # montre l'effet sans écrire
"""

import re
import os
import sys
import json
import argparse

_ALIAS = r"(?:[A-Za-z_]\w*\.)?"          # préfixe d'alias optionnel : « l. », « m. »
_ACTIVE = r"(?:loevm|lvorm|loekz|stblg)"

# Filtre « actif » entre parenthèses : (x.loevm IS NULL OR x.loevm = '')
_PAREN_ACTIVE = (
    r"\(\s*" + _ALIAS + _ACTIVE + r"\s+IS\s+NULL\s+OR\s+"
    + _ALIAS + _ACTIVE + r"\s*=\s*''\s*\)"
)
_MANDT = _ALIAS + r"mandt\s*=\s*'700'"

# Ordre IMPORTANT : on retire d'abord les formes « ... AND <filtre> » et
# « <filtre> AND ... » (collage booléen), puis les formes seules après WHERE.
_MANDT_JOIN = _ALIAS + r"mandt\s*=\s*" + _ALIAS + r"mandt"  # ex. p.mandt = k.mandt
_SUBS = [
    (re.compile(r"\s+AND\s+" + _PAREN_ACTIVE, re.I), ""),       # ... AND (actif)
    (re.compile(_PAREN_ACTIVE + r"\s+AND\s+", re.I), ""),       # (actif) AND ...
    (re.compile(r"\s+AND\s+" + _MANDT_JOIN, re.I), ""),         # ... AND x.mandt = y.mandt (jointure)
    (re.compile(_MANDT_JOIN + r"\s+AND\s+", re.I), ""),         # x.mandt = y.mandt AND ...
    (re.compile(r"\s+AND\s+" + _MANDT, re.I), ""),              # ... AND mandt = '700'
    (re.compile(_MANDT + r"\s+AND\s+", re.I), ""),              # mandt = '700' AND ...
    # Formes restées seules juste après WHERE (rien d'autre dans le WHERE) :
    (re.compile(r"\bWHERE\s+" + _MANDT + r"\s*(?=GROUP|ORDER|LIMIT|\)|$)", re.I), ""),
    (re.compile(r"\bWHERE\s+" + _PAREN_ACTIVE + r"\s*(?=GROUP|ORDER|LIMIT|\)|$)", re.I), ""),
]

_LEFTOVER = re.compile(r"(loevm|lvorm|loekz|stblg|mandt)", re.I)


def clean_sql(sql: str) -> str:
    """Retire les filtres techniques et recolle la syntaxe. Idempotent."""
    out = sql
    for _ in range(4):  # plusieurs passes : filtres chaînés
        avant = out
        for rx, repl in _SUBS:
            out = rx.sub(repl, out)
        if out == avant:
            break
    out = re.sub(r"\s{2,}", " ", out).strip()  # espaces multiples laissés par les coupes
    return out


def validate(sql: str) -> list:
    """Renvoie la liste des problèmes détectés ([] = SQL sain)."""
    pbs = []
    if sql.count("(") != sql.count(")"):
        pbs.append("parentheses desequilibrees")
    if not re.match(r"^\s*(SELECT|WITH)\b", sql, re.I):
        pbs.append("ne commence pas par SELECT/WITH")
    if re.search(r"\bWHERE\s+(GROUP|ORDER|LIMIT)\b", sql, re.I):
        pbs.append("WHERE vide suivi de GROUP/ORDER/LIMIT")
    if re.search(r"\bWHERE\s*$", sql, re.I) or re.search(r"\bAND\s*$", sql, re.I):
        pbs.append("WHERE/AND ballant en fin")
    if re.search(r"\bAND\s+AND\b", sql, re.I):
        pbs.append("AND AND")
    if re.search(r"\bWHERE\s+AND\b", sql, re.I):
        pbs.append("WHERE AND")
    return pbs


def main() -> int:
    ap = argparse.ArgumentParser()
    here = os.path.dirname(os.path.abspath(__file__))
    ap.add_argument("--path", default=os.path.join(here, "config", "dataset_sap_ia.jsonl"))
    ap.add_argument("--dry-run", action="store_true")
    args = ap.parse_args()

    with open(args.path, encoding="utf-8") as fh:
        lignes = [l for l in fh]

    sorties, modifies, echecs, restes = [], 0, [], 0
    for i, ligne in enumerate(lignes):
        s = ligne.strip()
        if not s:
            sorties.append(ligne)
            continue
        obj = json.loads(s)
        for m in obj.get("messages", []):
            if m.get("role") != "assistant":
                continue
            try:
                rep = json.loads(m["content"])
            except Exception:
                continue
            sql = rep.get("sql")
            if not sql:
                continue
            propre = clean_sql(sql)
            if propre == sql:
                continue
            pbs = validate(propre)
            if pbs:
                echecs.append((i, pbs, sql, propre))
                continue  # on NE modifie PAS un SQL douteux
            rep["sql"] = propre
            m["content"] = json.dumps(rep, ensure_ascii=False)
            modifies += 1
            if _LEFTOVER.search(propre):
                restes += 1
        sorties.append(json.dumps(obj, ensure_ascii=False) + "\n")

    print(f"Exemples : {len([l for l in lignes if l.strip()])}")
    print(f"SQL nettoyes : {modifies}")
    print(f"Nettoyes contenant encore mandt/loevm/... (a verifier) : {restes}")
    print(f"Echecs de validation (laisses intacts) : {len(echecs)}")
    for i, pbs, avant, apres in echecs[:10]:
        print(f"  - ligne {i} : {pbs}\n      avant: {avant[:120]}\n      apres: {apres[:120]}")

    if args.dry_run:
        print("\n[dry-run] aucune ecriture.")
        return 0

    bak = args.path + ".bak"
    if not os.path.exists(bak):
        os.replace(args.path, bak) if False else None
        with open(bak, "w", encoding="utf-8") as fh:
            fh.writelines(lignes)
        print(f"\nSauvegarde : {bak}")
    with open(args.path, "w", encoding="utf-8") as fh:
        fh.writelines(sorties)
    print(f"Ecrit : {args.path}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
