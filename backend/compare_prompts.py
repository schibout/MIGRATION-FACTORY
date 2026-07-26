# -*- coding: utf-8 -*-
"""
compare_prompts — Banc A/B : prompt statique (config/ai_system_prompt.py) vs prompt
RAG dynamique (services/ai_prompt_builder.py).

Pour chaque question du dataset, génère le SQL avec CHAQUE prompt via Ollama, le
valide (sql_guard) puis teste son exécutabilité par EXPLAIN sous le rôle readonly_ai.
Objectif : chiffrer le gain (SQL exécutables en plus) et DÉTECTER LES RÉGRESSIONS
avant de déployer.

⚠️ Long : 61 questions × 2 générations sur CPU ≈ 60-90 min. À lancer hors usage.
   Limiter avec --n. Résultats écrits au fil de l'eau dans --out (reprenable à l'œil).

Usage (dans le conteneur backend) :
    docker-compose exec backend python compare_prompts.py --n 10
    docker-compose exec backend python compare_prompts.py            # tout le dataset
"""

import os
import json
import argparse
import logging

from services.ollama_service import (
    generate_sql, OllamaError, OllamaBusyError, OllamaUnavailableError,
)
from services.ai_prompt_builder import build_dynamic_prompt
from config.ai_system_prompt import get_system_prompt
from services.sql_guard import validate_and_wrap, SqlGuardError
from services.ai_readonly_db import get_readonly_engine

logging.basicConfig(level=logging.WARNING)  # silence les logs verbeux pendant le run


def charger_questions(path: str) -> list:
    """Extrait les questions utilisateur du dataset jsonl."""
    questions = []
    with open(path, encoding="utf-8") as fh:
        for ligne in fh:
            ligne = ligne.strip()
            if not ligne:
                continue
            msgs = json.loads(ligne).get("messages", [])
            q = next((m["content"] for m in msgs if m.get("role") == "user"), None)
            if q:
                questions.append(q)
    return questions


def sql_executable(raw_sql: str):
    """(ok: bool, raison: str) — passe sql_guard puis EXPLAIN sous readonly_ai."""
    if not raw_sql:
        return False, "sql vide"
    try:
        safe = validate_and_wrap(raw_sql, 1)
    except SqlGuardError as e:
        return False, f"guard: {e}"
    try:
        with get_readonly_engine().connect() as conn:
            conn.exec_driver_sql("EXPLAIN " + safe)
        return True, ""
    except Exception as e:
        orig = getattr(e, "orig", None)
        code = getattr(orig, "pgcode", None)
        return False, f"db[{code}]: {str(e).splitlines()[0][:140]}"


def generer(question: str, system_prompt: str):
    """(raw_sql, erreur) — appelle Ollama, gère les exceptions du service."""
    try:
        return generate_sql(question, system_prompt).get("sql", ""), None
    except (OllamaError, OllamaBusyError, OllamaUnavailableError) as e:
        return "", str(e)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--n", type=int, default=0, help="limiter au N premières questions (0 = toutes)")
    ap.add_argument("--dataset", default=os.path.join(os.path.dirname(__file__), "config", "dataset_sap_ia.jsonl"))
    ap.add_argument("--out", default="compare_prompts_resultats.jsonl")
    args = ap.parse_args()

    questions = charger_questions(args.dataset)
    if args.n > 0:
        questions = questions[: args.n]

    n = len(questions)
    old_ok = new_ok = 0
    corriges, regressions = [], []

    print(f"Comparaison sur {n} questions. Écriture au fil de l'eau dans {args.out}\n")
    with open(args.out, "w", encoding="utf-8") as out:
        for i, q in enumerate(questions, 1):
            sql_old, err_old = generer(q, get_system_prompt())
            ok_old, r_old = (False, err_old) if err_old else sql_executable(sql_old)

            try:
                prompt_rag = build_dynamic_prompt(q)
            except Exception as e:
                prompt_rag = get_system_prompt()
                logging.warning(f"RAG prompt KO ({e}) -> repli statique")
            sql_new, err_new = generer(q, prompt_rag)
            ok_new, r_new = (False, err_new) if err_new else sql_executable(sql_new)

            old_ok += ok_old
            new_ok += ok_new
            if ok_new and not ok_old:
                corriges.append(q)
            if ok_old and not ok_new:
                regressions.append(q)

            statut = "=" if ok_old == ok_new else ("＋" if ok_new else "－RÉGRESSION")
            print(f"[{i}/{n}] old={'OK' if ok_old else 'KO'} new={'OK' if ok_new else 'KO'} {statut}  {q[:60]}")

            out.write(json.dumps({
                "question": q,
                "old": {"ok": ok_old, "raison": r_old, "sql": sql_old},
                "new": {"ok": ok_new, "raison": r_new, "sql": sql_new},
            }, ensure_ascii=False) + "\n")
            out.flush()

    print("\n" + "=" * 60)
    print(f"PROMPT STATIQUE : {old_ok}/{n} exécutables ({100*old_ok//max(n,1)} %)")
    print(f"PROMPT RAG      : {new_ok}/{n} exécutables ({100*new_ok//max(n,1)} %)")
    print(f"Corrigés par le RAG : {len(corriges)}")
    print(f"Régressions         : {len(regressions)}")
    if regressions:
        print("\n⚠️ RÉGRESSIONS (à examiner avant de déployer) :")
        for q in regressions:
            print(f"   - {q}")
    print(f"\nDétail complet : {args.out}")


if __name__ == "__main__":
    main()
