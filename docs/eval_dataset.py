# -*- coding: utf-8 -*-
"""
Évaluation du modèle local Ollama contre le dataset texte→SQL.
À exécuter sur la VM : python3 eval_dataset.py [--n 10] [--model qwen2.5-coder:7b]
Pour chaque question du dataset : interroge Ollama, vérifie que la sortie est un JSON
valide {sql, explication}, que le SQL est un SELECT/WITH schéma-qualifié, puis
(optionnel, --db) vérifie que le SQL s'exécute via EXPLAIN sur PostgreSQL.
"""
import argparse
import json
import sys
import time

import requests

OLLAMA_URL = "http://localhost:11434"


def charger_dataset(chemin: str):
    exemples = []
    with open(chemin, encoding="utf-8") as f:
        for ligne in f:
            d = json.loads(ligne)
            exemples.append({
                "system": d["messages"][0]["content"],
                "question": d["messages"][1]["content"],
                "sql_attendu": json.loads(d["messages"][2]["content"])["sql"],
            })
    return exemples


def interroger_ollama(model: str, system: str, question: str, timeout: int = 180):
    debut = time.time()
    r = requests.post(f"{OLLAMA_URL}/api/chat", json={
        "model": model,
        "format": "json",
        "stream": False,
        "options": {"temperature": 0, "num_ctx": 4096},
        "messages": [
            {"role": "system", "content": system},
            {"role": "user", "content": question},
        ],
    }, timeout=timeout)
    r.raise_for_status()
    duree = time.time() - debut
    return r.json()["message"]["content"], duree


def verifier_sortie(contenu: str):
    """Retourne (ok, sql, raison)."""
    try:
        rep = json.loads(contenu)
    except json.JSONDecodeError as e:
        return False, None, f"JSON invalide : {e}"
    if "sql" not in rep or "explication" not in rep:
        return False, None, f"Clés manquantes : {list(rep.keys())}"
    sql = rep["sql"].strip()
    haut = sql.upper()
    if not (haut.startswith("SELECT") or haut.startswith("WITH")):
        return False, sql, "Ne commence pas par SELECT/WITH"
    if not any(s in sql for s in ("raw_data.", "clean_data.", "public.")):
        return False, sql, "Tables non schéma-qualifiées"
    for interdit in ("INSERT ", "UPDATE ", "DELETE ", "DROP ", "ALTER ", "TRUNCATE "):
        if interdit in haut:
            return False, sql, f"Mot-clé interdit : {interdit.strip()}"
    return True, sql, "OK"


def verifier_execution(sql: str, dsn: str):
    """Vérifie que le SQL s'exécute (EXPLAIN) sur la base. Retourne (ok, message)."""
    try:
        import psycopg2
    except ImportError:
        return None, "psycopg2 non installé (pip install psycopg2-binary)"
    try:
        with psycopg2.connect(dsn) as conn:
            conn.set_session(readonly=True)
            with conn.cursor() as cur:
                cur.execute("SET statement_timeout = '15s'")
                cur.execute("EXPLAIN " + sql)
        return True, "exécutable"
    except Exception as e:
        return False, str(e).split("\n")[0]


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--dataset", default="dataset_sap_ia.jsonl")
    p.add_argument("--model", default="qwen2.5-coder:7b")
    p.add_argument("--n", type=int, default=10, help="nombre de questions à tester (0 = toutes)")
    p.add_argument("--db", default=None,
                   help="DSN PostgreSQL pour tester l'exécution, ex: postgresql://readonly_ai:mdp@10.190.100.58:5432/sap_migration")
    args = p.parse_args()

    exemples = charger_dataset(args.dataset)
    if args.n:
        exemples = exemples[:args.n]

    ok_format = ok_exec = 0
    durees = []
    for i, ex in enumerate(exemples, 1):
        print(f"\n[{i}/{len(exemples)}] {ex['question']}")
        try:
            contenu, duree = interroger_ollama(args.model, ex["system"], ex["question"])
        except Exception as e:
            print(f"  ECHEC appel Ollama : {e}")
            continue
        durees.append(duree)
        ok, sql, raison = verifier_sortie(contenu)
        statut = "OK" if ok else "KO"
        print(f"  Format : {statut} ({raison}) — {duree:.1f}s")
        if sql:
            print(f"  SQL    : {sql[:180]}{'...' if len(sql) > 180 else ''}")
        if ok:
            ok_format += 1
            if args.db:
                exec_ok, msg = verifier_execution(sql, args.db)
                if exec_ok is not None:
                    print(f"  Exec   : {'OK' if exec_ok else 'KO'} ({msg})")
                    ok_exec += 1 if exec_ok else 0

    print("\n" + "=" * 60)
    print(f"Format valide : {ok_format}/{len(exemples)}")
    if args.db:
        print(f"SQL exécutable : {ok_exec}/{ok_format}")
    if durees:
        print(f"Temps moyen : {sum(durees)/len(durees):.1f}s | min {min(durees):.1f}s | max {max(durees):.1f}s")
    sys.exit(0 if ok_format == len(exemples) else 1)


if __name__ == "__main__":
    main()
