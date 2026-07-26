# -*- coding: utf-8 -*-
"""
eval_retrieval — Banc d'evaluation de la RECUPERATION DE TABLES de l'Assistant IA.

Mesure la qualite de `services.ai_schema_retriever.retrieve_tables()` (la vraie
cascade map curee -> embeddings pgvector -> repli FTS) avec les metriques IR
standard : precision@k, recall@k, MRR, NDCG@k + analyse des echecs.

Verite terrain AUTO, sans annotation manuelle : chaque exemple valide du dataset
few-shot (config/dataset_sap_ia.jsonl) associe une question a un SQL correct ;
les tables schema-qualifiees de ce SQL (FROM/JOIN) SONT les tables pertinentes.
Les alias de CTE ne sont jamais schema-qualifies -> pas de faux positifs.

METRIQUE PHARE = recall@7 (MAX_TABLES=7) : un rappel manque = la table n'est pas
injectee dans le prompt -> le modele ne PEUT PAS ecrire la bonne requete. La
precision est secondaire (retrieve_tables ramene legitimement des tables de
jointure/reference en plus : cout en tokens, pas en justesse).

Aucune fuite : retrieve_tables n'utilise PAS le dataset few-shot (il s'appuie sur
la map curee + embeddings de tables + FTS), donc l'evaluer sur ces questions est
propre.

Lancement (SUR LE SERVEUR, acces DB requis) :
    docker-compose exec backend python eval_retrieval.py
    docker-compose exec backend python eval_retrieval.py --k 1 3 5 7 -o eval_tables.json
    docker-compose exec backend python eval_retrieval.py --dataset config/dataset_sap_ia.jsonl
"""

import os
import re
import sys
import json
import math
import argparse
import logging

# --------------------------------------------------------------------------- #
# Verite terrain : (question, tables_attendues) depuis le dataset few-shot.
# --------------------------------------------------------------------------- #
_TABLE_RE = re.compile(r"\b(raw_data|clean_data|public)\.([a-zA-Z_][a-zA-Z0-9_]*)", re.I)

# Tables de REFERENCE / LIBELLE : jointes pour afficher un nom/texte (pays, groupe,
# site, designation, adresse...) ou referentiels secondaires. Un rappel manque sur
# l'une d'elles degrade l'affichage, PAS la justesse -> on les exclut du "rappel core"
# (la vraie porte de qualite). Une table CORE manquee = requete impossible a ecrire.
_REFERENCE_TABLES = {
    "raw_data.t005t", "raw_data.t023t", "raw_data.t001w", "raw_data.t024",
    "raw_data.makt", "raw_data.eqkt", "raw_data.iflotx",
    "raw_data.adrc", "raw_data.adr6", "raw_data.adr2", "raw_data.bnka",
    "raw_data.dd02t", "raw_data.dd02l",
}


def _tables_in_sql(sql: str) -> set:
    """Tables schema-qualifiees citees dans un SQL (FROM/JOIN/sous-requetes)."""
    return {f"{sch.lower()}.{tbl.lower()}" for sch, tbl in _TABLE_RE.findall(sql or "")}


def load_ground_truth(dataset_path: str) -> list:
    """
    Renvoie [(query_id, question, set(tables_attendues))] depuis le jsonl few-shot.
    Ignore les lignes dont le SQL ne cite aucune table schema-qualifiee.
    """
    items = []
    with open(dataset_path, encoding="utf-8") as fh:
        for i, ligne in enumerate(fh):
            ligne = ligne.strip()
            if not ligne:
                continue
            msgs = json.loads(ligne).get("messages", [])
            question = next((m["content"] for m in msgs if m.get("role") == "user"), None)
            answer = next((m["content"] for m in msgs if m.get("role") == "assistant"), None)
            if not question or not answer:
                continue
            try:
                sql = json.loads(answer).get("sql", "")
            except Exception:
                sql = answer  # certaines reponses peuvent etre du SQL brut
            tables = _tables_in_sql(sql)
            if tables:
                items.append((f"q{i:03d}", question.strip(), tables))
    return items


# --------------------------------------------------------------------------- #
# Metriques IR (adaptees de retrieval_evaluator.py de la skill rag-architect).
# --------------------------------------------------------------------------- #
def _precision_at_k(retrieved: list, relevant: set, k: int) -> float:
    topk = retrieved[:k]
    if not topk:
        return 0.0
    return len(set(topk) & relevant) / len(topk)


def _recall_at_k(retrieved: list, relevant: set, k: int) -> float:
    if not relevant:
        return 0.0
    return len(set(retrieved[:k]) & relevant) / len(relevant)


def _reciprocal_rank(retrieved: list, relevant: set) -> float:
    for i, t in enumerate(retrieved):
        if t in relevant:
            return 1.0 / (i + 1)
    return 0.0


def _ndcg_at_k(retrieved: list, relevant: set, k: int) -> float:
    topk = retrieved[:k]
    if not topk:
        return 0.0
    dcg = sum((1.0 if t in relevant else 0.0) / math.log2(i + 2) for i, t in enumerate(topk))
    ideal = min(len(relevant), k)
    idcg = sum(1.0 / math.log2(i + 2) for i in range(ideal))
    return dcg / idcg if idcg > 0 else 0.0


def _mean(xs: list) -> float:
    return sum(xs) / len(xs) if xs else 0.0


def evaluate(items: list, retrieve_fn, k_values: list, conn) -> dict:
    """Evalue retrieve_fn(question, conn) -> [tables ordonnees] sur la verite terrain."""
    per_query = []
    agg = {f"precision@{k}": [] for k in k_values}
    agg.update({f"recall@{k}": [] for k in k_values})
    agg.update({f"recall_core@{k}": [] for k in k_values})
    agg.update({f"ndcg@{k}": [] for k in k_values})
    rr = []

    for qid, question, relevant in items:
        retrieved = retrieve_fn(question, conn)  # liste ordonnee, schema-qualifiee
        core = relevant - _REFERENCE_TABLES      # tables indispensables a la justesse
        m = {}
        for k in k_values:
            p = _precision_at_k(retrieved, relevant, k)
            r = _recall_at_k(retrieved, relevant, k)
            rc = _recall_at_k(retrieved, core, k) if core else 1.0
            n = _ndcg_at_k(retrieved, relevant, k)
            m[f"precision@{k}"] = p
            m[f"recall@{k}"] = r
            m[f"recall_core@{k}"] = rc
            m[f"ndcg@{k}"] = n
            agg[f"precision@{k}"].append(p)
            agg[f"recall@{k}"].append(r)
            agg[f"recall_core@{k}"].append(rc)
            agg[f"ndcg@{k}"].append(n)
        m["reciprocal_rank"] = _reciprocal_rank(retrieved, relevant)
        rr.append(m["reciprocal_rank"])

        kmax = max(k_values)
        missing = sorted(relevant - set(retrieved[:kmax]))
        per_query.append({
            "query_id": qid,
            "question": question,
            "relevant": sorted(relevant),
            "retrieved": retrieved[:kmax],
            # tables attendues NON ramenees, taguees core/ref pour la priorisation
            "missing": [f"{t} [{'ref' if t in _REFERENCE_TABLES else 'CORE'}]"
                        for t in missing],
            "missing_core": [t for t in missing if t not in _REFERENCE_TABLES],
            "metrics": m,
        })

    aggregate = {f"mean_{key}": _mean(vals) for key, vals in agg.items()}
    aggregate["mean_reciprocal_rank"] = _mean(rr)

    kmax = max(k_values)
    misses = [r for r in per_query if r["missing"]]
    core_misses = [r for r in per_query if r["missing_core"]]
    # Frequence des tables manquees (ou la cascade rate le plus souvent).
    missed_counter = {}
    for r in misses:
        for t in r["missing"]:
            missed_counter[t] = missed_counter.get(t, 0) + 1
    missed_ranked = sorted(missed_counter.items(), key=lambda x: x[1], reverse=True)

    return {
        "n_queries": len(items),
        "k_values": k_values,
        "aggregate_metrics": aggregate,
        "failures": {
            "queries_with_missing_tables": len(misses),
            "queries_with_missing_CORE_tables": len(core_misses),
            "perfect_recall_queries": len(items) - len(misses),
            "perfect_core_recall_queries": len(items) - len(core_misses),
            f"recall@{kmax}": round(aggregate[f"mean_recall@{kmax}"], 3),
            f"recall_core@{kmax}": round(aggregate[f"mean_recall_core@{kmax}"], 3),
            "most_missed_tables": missed_ranked,
            # echecs CORE en tete : ce sont eux qui cassent vraiment les requetes
            "examples": sorted(misses, key=lambda r: not r["missing_core"])[:15],
        },
        "per_query": per_query,
    }


def _print_summary(res: dict) -> None:
    kmax = max(res["k_values"])
    a = res["aggregate_metrics"]
    print("\n" + "=" * 64)
    print(f"  EVALUATION RECUPERATION DE TABLES — {res['n_queries']} questions")
    print("=" * 64)
    hdr = (f"{'k':>4} | {'precision@k':>12} | {'recall@k':>10} | "
           f"{'recall_core@k':>13} | {'ndcg@k':>8}")
    print(hdr)
    print("-" * len(hdr))
    for k in res["k_values"]:
        print(f"{k:>4} | {a[f'mean_precision@{k}']:>12.3f} | "
              f"{a[f'mean_recall@{k}']:>10.3f} | {a[f'mean_recall_core@{k}']:>13.3f} | "
              f"{a[f'mean_ndcg@{k}']:>8.3f}")
    print(f"\nMRR : {a['mean_reciprocal_rank']:.3f}")

    f = res["failures"]
    print(f"\nRAPPEL @ k={kmax}        : {f[f'recall@{kmax}']:.3f}  (toutes tables, ref. incluses)")
    print(f"RAPPEL CORE @ k={kmax} : {f[f'recall_core@{kmax}']:.3f}  <- METRIQUE PHARE "
          f"(hors tables de libelle)")
    print(f"\nQuestions a rappel CORE parfait : "
          f"{f['perfect_core_recall_queries']}/{res['n_queries']}")
    print(f"Questions avec table CORE manquee : {f['queries_with_missing_CORE_tables']} "
          f"(toutes tables : {f['queries_with_missing_tables']})")
    if f["most_missed_tables"]:
        print("\nTables les plus souvent manquees (table : nb de questions) :")
        for t, n in f["most_missed_tables"][:12]:
            print(f"  - {t} : {n}")
    if f["examples"]:
        print("\nExemples d'echecs de rappel :")
        for r in f["examples"][:8]:
            print(f"  [{r['query_id']}] {r['question'][:70]}")
            print(f"       manque  : {r['missing']}")
            print(f"       ramene  : {r['retrieved']}")
    print("=" * 64)


def main() -> int:
    logging.basicConfig(level=logging.WARNING)  # silence les INFO de retrieve_tables
    ap = argparse.ArgumentParser(description="Eval recuperation de tables (Assistant IA)")
    here = os.path.dirname(os.path.abspath(__file__))
    ap.add_argument("--dataset", default=os.path.join(here, "config", "dataset_sap_ia.jsonl"))
    ap.add_argument("--k", nargs="+", type=int, default=[1, 3, 5, 7])
    ap.add_argument("-o", "--output", default=None, help="Fichier JSON resultats")
    args = ap.parse_args()

    # Imports tardifs : echouent proprement hors serveur (pas de DB / deps).
    try:
        from config.database import get_db_connection
        from services.ai_schema_retriever import retrieve_tables
    except Exception as e:
        print(f"Import impossible (a lancer sur le serveur, dans backend/) : {e}")
        return 1

    items = load_ground_truth(args.dataset)
    if not items:
        print(f"Aucune verite terrain extraite de {args.dataset}")
        return 1
    print(f"Verite terrain : {len(items)} questions avec tables attendues "
          f"(depuis {os.path.basename(args.dataset)})")

    with get_db_connection() as conn:
        res = evaluate(items, retrieve_tables, sorted(set(args.k)), conn)

    _print_summary(res)
    if args.output:
        with open(args.output, "w", encoding="utf-8") as fh:
            json.dump(res, fh, ensure_ascii=False, indent=2)
        print(f"\nResultats detailles -> {args.output}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
