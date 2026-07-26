"""
Test de bout en bout du system prompt de l'Assistant IA.

Réutilise le VRAI chemin d'intégration :
    config.ai_system_prompt.get_system_prompt()  ->  services.ollama_service.generate_sql()

Pour chaque question : envoie à Ollama, vérifie le JSON {sql, explication},
contrôle que le SQL commence par SELECT/WITH, qu'il qualifie un schéma
(raw_data./clean_data.) et qu'il filtre mandt='700' quand il lit raw_data.
Affiche le SQL généré, le verdict et le temps de réponse.

Usage (depuis la racine du projet) :
    python scripts/test_ai_prompt.py
Variable optionnelle : OLLAMA_URL (défaut : http://10.190.100.58:11434)
"""
import os
import re
import sys
import time

# Forcer une sortie UTF-8 (console Windows cp1252 sinon → UnicodeEncodeError)
try:
    sys.stdout.reconfigure(encoding="utf-8")
except Exception:
    pass

# --- Rendre le package backend importable ---------------------------------
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BACKEND = os.path.join(ROOT, "backend")
if BACKEND not in sys.path:
    sys.path.insert(0, BACKEND)

# Cible Ollama (hôte de la VM par défaut, surchargée si OLLAMA_URL déjà défini)
os.environ.setdefault("OLLAMA_URL", "http://10.190.100.58:11434")
# Le 1er appel (cache KV froid) peut prendre plusieurs minutes sur CPU :
# on élargit le timeout pour le test (la prod reste sur AI_TIMEOUT_SECONDS).
os.environ.setdefault("AI_TIMEOUT_SECONDS", "600")

from config.ai_system_prompt import get_system_prompt          # noqa: E402
from services.ollama_service import generate_sql               # noqa: E402

QUESTIONS = [
    "Combien de fournisseurs actifs par pays ?",
    "Liste les articles de la division 2200 sans codification IFS",
    "Quels fournisseurs retenus n'ont pas d'email ?",
]


def _despace(s: str) -> str:
    return re.sub(r"\s+", "", s).lower()


def verifier(sql: str) -> list:
    """Retourne la liste des problèmes détectés (vide = OK)."""
    problemes = []
    s = sql.strip().lower()
    if not (s.startswith("select") or s.startswith("with")):
        problemes.append("ne commence pas par SELECT/WITH")
    if "raw_data." not in s and "clean_data." not in s:
        problemes.append("aucun schéma qualifié (raw_data./clean_data.)")
    # mandt='700' obligatoire dès qu'on interroge raw_data
    if "raw_data." in s and "mandt='700'" not in _despace(sql):
        problemes.append("interroge raw_data sans filtre mandt='700'")
    return problemes


def main():
    prompt = get_system_prompt()
    print(f"OLLAMA_URL = {os.environ['OLLAMA_URL']}")
    print(f"SYSTEM_PROMPT : {len(prompt)} caractères (~{round(len(prompt)/3.5)} tokens)")
    print(f"AI_TIMEOUT_SECONDS (test) = {os.environ['AI_TIMEOUT_SECONDS']}\n")

    # Préchauffe : peuple le cache KV avec le system prompt (1er appel lent).
    print("Préchauffe du modèle (peut prendre plusieurs minutes la 1re fois)…")
    t0 = time.time()
    try:
        generate_sql("Compte le nombre de fournisseurs.", prompt)
        print(f"  Préchauffe OK en {time.time()-t0:.1f}s\n")
    except Exception as e:
        print(f"  Préchauffe échouée ({type(e).__name__}) : {e}\n")

    total_ok = 0
    for i, q in enumerate(QUESTIONS, 1):
        print("=" * 78)
        print(f"Q{i}. {q}")
        t0 = time.time()
        try:
            res = generate_sql(q, prompt)
        except Exception as e:
            dt = time.time() - t0
            print(f"  ❌ Échec génération ({type(e).__name__}) en {dt:.1f}s : {e}")
            continue
        dt = time.time() - t0

        sql = res.get("sql", "")
        explic = res.get("explication", "")
        problemes = verifier(sql)
        verdict = "✅ OK" if not problemes else "❌ " + " ; ".join(problemes)
        if not problemes:
            total_ok += 1

        print(f"  Temps      : {dt:.1f}s")
        print(f"  Clés JSON  : sql={'oui' if sql else 'NON'}, explication={'oui' if explic else 'non'}")
        print(f"  Verdict    : {verdict}")
        print(f"  Explication: {explic}")
        print("  SQL généré :")
        for line in sql.splitlines() or [sql]:
            print(f"    {line}")
        print()

    print("=" * 78)
    print(f"RÉSULTAT : {total_ok}/{len(QUESTIONS)} requêtes conformes.")


if __name__ == "__main__":
    main()
