# Amélioration Assistant IA (RAG & fiabilité) — Plan d'implémentation

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal :** Réduire le taux d'échec de l'Assistant IA (aujourd'hui 56 % : 63 erreurs / 50 succès dans `ai_query_log`) en assainissant les few-shots, en élargissant le RAG quand le fournisseur externe est actif, en couvrant `clean_data`, et en rendant l'auto-correction plus efficace.

**Architecture :** Le pipeline existant (SOCLE + schéma ciblé + KG + connaissances + few-shots → modèle → sql_guard → readonly_ai) est conservé tel quel. On ajoute un module de **budgets RAG adaptatifs** (profil `compact` pour Ollama num_ctx=4096, `large` pour le fournisseur externe), on **assainit** le dataset few-shots (filtres `mandt/loevm` interdits mais présents dans 61/61 exemples), on **indexe `clean_data`** (126 tables cibles IFS invisibles du RAG), on **enrichit le prompt de réparation** avec les colonnes réelles, et on ajoute des **stats d'erreurs** mesurables dans l'onglet Usage.

**Tech Stack :** Python 3.11 / Flask, PostgreSQL + pgvector, Ollama (bge-m3 pour embeddings), React + MUI.

**⚠️ Règle projet :** ne PAS lancer pip/pytest/python en local. Tous les `pytest` et scripts s'exécutent **sur le serveur** : `docker-compose exec backend pytest …` / `docker-compose exec backend python …`. Les commits se font en local.

---

## Constats chiffrés qui motivent ce plan (2026-07-07)

| Constat | Preuve | Tâche |
|---|---|---|
| 61/61 exemples few-shots contiennent `mandt`/`loevm`/`lvorm`, contredisant le SOCLE (« N'AJOUTE PAS de filtre technique ») → le modèle imite les exemples → erreurs `column loevm does not exist` (~7 occurrences) | `grep -c` sur `dataset_sap_ia.jsonl` ; `ai_query_log.raison_rejet` | 1 |
| Budgets RAG figés pour Ollama (7 tables, 18 col., 3 exemples, 1 pack/700 c., 8 arêtes) alors que le mode externe (Kimi, 256k ctx) n'a pas la contrainte num_ctx=4096 | Constantes dans `ai_schema_retriever` / `ai_prompt_builder` / `ai_knowledge_graph` | 2, 3 |
| Index sémantique : 142 tables indexées sur 316 (190 raw_data + 126 clean_data) → `clean_data` (cible IFS !) invisible du RAG, et ses colonnes injectées SANS libellés | `SELECT kind, count(*) FROM ai_embeddings` ; `build_ai_index.py` ne traite que `sap_table_properties` | 4 |
| L'auto-correction (self-heal 42703/42P01) renvoie l'erreur PG brute sans donner les colonnes réelles de la table fautive → le modèle re-devine | `_try_repair` dans `api/ai_assistant.py` | 5 |
| Pas de mesure du taux d'erreur par type → impossible de vérifier qu'une amélioration améliore | `/ai-config/usage` ne renvoie que feedback + co-occurrences | 6 |

Hors périmètre (YAGNI) : timeouts modèle local (déjà traités par le worker arrière-plan + fournisseur externe), bug `immutabledict` (déjà corrigé dans `ai_readonly_db.py`), `too many connections` (pool applicatif principal, pas spécifique IA), synthèse des résultats en langage naturel.

---

### Task 1 : Assainir le dataset few-shots (retirer mandt/loevm/lvorm)

Le dataset `backend/config/dataset_sap_ia.jsonl` (61 exemples, format `{"messages":[{role:user},{role:assistant}]}` où le contenu assistant est un JSON `{"sql","explication"}`) précède la décision du 2026-06-15 (« SQL simple SANS mandt/loevm/lvorm »). Chaque exemple montre au modèle les filtres interdits.

**Files:**
- Create: `backend/assainir_dataset.py` (à la racine backend, comme `build_ai_index.py`)
- Test: `backend/tests/test_assainir_dataset.py`

- [ ] **Step 1 : Écrire les tests de la fonction de nettoyage**

```python
# backend/tests/test_assainir_dataset.py
"""Tests du nettoyage des filtres techniques SAP dans le dataset few-shots."""
from assainir_dataset import nettoyer_sql


def test_retire_mandt_en_tete_de_where():
    sql = "SELECT lifnr FROM raw_data.lfa1 WHERE mandt = '700' AND land1 = 'FR'"
    assert nettoyer_sql(sql) == "SELECT lifnr FROM raw_data.lfa1 WHERE land1 = 'FR'"


def test_retire_loevm_en_fin_de_where():
    sql = "SELECT lifnr FROM raw_data.lfa1 WHERE land1 = 'FR' AND loevm = ''"
    assert nettoyer_sql(sql) == "SELECT lifnr FROM raw_data.lfa1 WHERE land1 = 'FR'"


def test_retire_where_entier_si_seul_filtre_technique():
    sql = "SELECT lifnr FROM raw_data.lfa1 WHERE mandt = '700' ORDER BY lifnr LIMIT 10"
    assert nettoyer_sql(sql) == "SELECT lifnr FROM raw_data.lfa1 ORDER BY lifnr LIMIT 10"


def test_retire_where_entier_en_fin_de_requete():
    sql = "SELECT count(*) FROM raw_data.mara WHERE lvorm = ''"
    assert nettoyer_sql(sql) == "SELECT count(*) FROM raw_data.mara"


def test_conserve_sql_sans_filtre_technique():
    sql = "SELECT matnr, maktx FROM raw_data.makt WHERE spras = 'F'"
    assert nettoyer_sql(sql) == sql


def test_enchaine_mandt_et_loevm():
    sql = ("SELECT lifnr FROM raw_data.lfa1 "
           "WHERE mandt = '700' AND loevm = '' AND land1 = 'FR'")
    assert nettoyer_sql(sql) == "SELECT lifnr FROM raw_data.lfa1 WHERE land1 = 'FR'"
```

- [ ] **Step 2 : Vérifier que les tests échouent (module absent)**

Run (serveur) : `docker-compose exec backend pytest tests/test_assainir_dataset.py -v`
Expected: FAIL / erreur d'import `assainir_dataset`.

- [ ] **Step 3 : Écrire le script**

```python
# backend/assainir_dataset.py
# -*- coding: utf-8 -*-
"""
assainir_dataset — Retire les filtres techniques SAP (mandt / loevm / lvorm /
loekz / stblg) des exemples few-shots, conformément à la décision 2026-06-15
(« SQL simple sans filtres techniques »). Ces filtres présents dans TOUS les
exemples apprennent au modèle à halluciner `loevm` sur des tables qui ne l'ont
pas (cf. erreurs 42703 dans ai_query_log), malgré l'interdiction du SOCLE.

Usage (sur le serveur) :
    python assainir_dataset.py            # écrit config/dataset_sap_ia.nettoye.jsonl + rapport
    python assainir_dataset.py --apply    # remplace le dataset original (backup .bak)
Après --apply : python build_ai_index.py --only examples  (réindexation sémantique)
"""
import os
import re
import sys
import json
import shutil
import argparse

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from services.sql_guard import validate_and_wrap, SqlGuardError  # noqa: E402

_FILTRES = r"(mandt|loevm|lvorm|loekz|stblg)"
# Ordre important : on retire d'abord les occurrences en milieu de WHERE,
# puis les WHERE devenus vides.
_SUBSTITUTIONS = [
    # ... AND mandt = '700'  /  ... AND loevm = ''
    (re.compile(rf"\s+AND\s+{_FILTRES}\s*(=|<>|!=)\s*'[^']*'", re.I), ""),
    # WHERE mandt = '700' AND ...   ->  WHERE ...
    (re.compile(rf"\b{_FILTRES}\s*(=|<>|!=)\s*'[^']*'\s+AND\s+", re.I), ""),
    # WHERE <filtre technique> seul, suivi de GROUP/ORDER/LIMIT/fin/parenthèse
    (re.compile(rf"\s+WHERE\s+{_FILTRES}\s*(=|<>|!=)\s*'[^']*'\s*(?=$|GROUP\s+BY|ORDER\s+BY|LIMIT\b|\))", re.I), " "),
]


def nettoyer_sql(sql: str) -> str:
    """Retire les filtres techniques d'une requête. Idempotent."""
    out = sql or ""
    for regex, remplacement in _SUBSTITUTIONS:
        out = regex.sub(remplacement, out)
    return re.sub(r"\s{2,}", " ", out).strip()


def _chemin_dataset() -> str:
    return os.getenv("AI_EXAMPLES_PATH",
                     os.path.join(os.path.dirname(__file__), "config", "dataset_sap_ia.jsonl"))


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--apply", action="store_true",
                        help="Remplace le dataset original (backup .bak).")
    args = parser.parse_args()

    src = _chemin_dataset()
    dst = src.replace(".jsonl", ".nettoye.jsonl")
    modifies, intacts, rejets = 0, 0, []

    with open(src, encoding="utf-8") as fin, open(dst, "w", encoding="utf-8") as fout:
        for i, ligne in enumerate(fin):
            ligne = ligne.strip()
            if not ligne:
                continue
            doc = json.loads(ligne)
            for msg in doc.get("messages", []):
                if msg.get("role") != "assistant":
                    continue
                try:
                    contenu = json.loads(msg["content"])
                except (ValueError, TypeError):
                    continue
                sql_avant = contenu.get("sql", "")
                sql_apres = nettoyer_sql(sql_avant)
                if sql_apres != sql_avant:
                    # Garde-fou : le SQL nettoyé doit toujours passer sql_guard.
                    try:
                        validate_and_wrap(sql_apres, 500)
                    except SqlGuardError as e:
                        rejets.append((i, str(e), sql_avant, sql_apres))
                        sql_apres = sql_avant  # on conserve l'original, à corriger à la main
                    else:
                        modifies += 1
                        print(f"--- exemple {i} ---\nAVANT : {sql_avant}\nAPRES : {sql_apres}\n")
                else:
                    intacts += 1
                contenu["sql"] = sql_apres
                msg["content"] = json.dumps(contenu, ensure_ascii=False)
            fout.write(json.dumps(doc, ensure_ascii=False) + "\n")

    print(f"\n{modifies} exemple(s) nettoyé(s), {intacts} intact(s), {len(rejets)} à corriger à la main.")
    for i, motif, avant, apres in rejets:
        print(f"  ⚠️ exemple {i} rejeté par sql_guard ({motif})")

    if args.apply:
        shutil.copyfile(src, src + ".bak")
        shutil.move(dst, src)
        print(f"✅ Dataset remplacé ({src}). Backup : {src}.bak")
        print("➡️  Relancez : python build_ai_index.py --only examples")
    else:
        print(f"Aperçu écrit dans {dst} (aucune modification du dataset). Relancez avec --apply pour appliquer.")


if __name__ == "__main__":
    main()
```

- [ ] **Step 4 : Vérifier que les tests passent**

Run (serveur) : `docker-compose exec backend pytest tests/test_assainir_dataset.py -v`
Expected: 6 PASS.

- [ ] **Step 5 : Exécuter le nettoyage sur le serveur (aperçu, puis apply)**

```bash
docker-compose exec backend python assainir_dataset.py           # revue visuelle des AVANT/APRES
docker-compose exec backend python assainir_dataset.py --apply
docker-compose exec backend python build_ai_index.py --only examples
```
Expected: ~61 exemples nettoyés, 0 rejet sql_guard, réindexation « Exemples indexés : 61/61 ».

- [ ] **Step 6 : Commit**

```bash
git add backend/assainir_dataset.py backend/tests/test_assainir_dataset.py backend/config/dataset_sap_ia.jsonl
git commit -m "fix(ia): retirer les filtres techniques mandt/loevm des few-shots (cause des hallucinations 42703)"
```

---

### Task 2 : Module de budgets RAG adaptatifs (`ai_rag_budget`)

Profil `compact` (valeurs actuelles, Ollama num_ctx=4096) vs `large` (fournisseur externe). Sélection automatique selon `AI_PROVIDER`, surcharge possible via `AI_RAG_PROFILE`.

**Files:**
- Create: `backend/services/ai_rag_budget.py`
- Test: `backend/tests/test_ai_rag_budget.py`

- [ ] **Step 1 : Écrire les tests**

```python
# backend/tests/test_ai_rag_budget.py
"""Tests des budgets RAG adaptatifs (profil compact Ollama / large externe)."""
from unittest.mock import patch

from services import ai_rag_budget


def _fake_config(valeurs):
    """get_config(key, default) simulé sur un dict."""
    return lambda key, default=None: valeurs.get(key, default)


def test_profil_compact_par_defaut_avec_ollama():
    with patch.object(ai_rag_budget, "get_config", _fake_config({"AI_PROVIDER": "ollama"})), \
         patch.object(ai_rag_budget, "get_config_int", lambda k, d=0: d):
        b = ai_rag_budget.get_budget()
    assert b["profil"] == "compact"
    assert b["max_tables"] == 7
    assert b["max_cols"] == 18
    assert b["nb_exemples"] == 3


def test_profil_large_avec_fournisseur_externe():
    with patch.object(ai_rag_budget, "get_config", _fake_config({"AI_PROVIDER": "openai"})), \
         patch.object(ai_rag_budget, "get_config_int", lambda k, d=0: d):
        b = ai_rag_budget.get_budget()
    assert b["profil"] == "large"
    assert b["max_tables"] == 14
    assert b["max_cols"] == 40
    assert b["nb_exemples"] == 6
    assert b["max_packs"] == 3
    assert b["max_edges"] == 20


def test_ai_rag_profile_force_le_profil():
    valeurs = {"AI_PROVIDER": "openai", "AI_RAG_PROFILE": "compact"}
    with patch.object(ai_rag_budget, "get_config", _fake_config(valeurs)), \
         patch.object(ai_rag_budget, "get_config_int", lambda k, d=0: d):
        b = ai_rag_budget.get_budget()
    assert b["profil"] == "compact"
    assert b["max_tables"] == 7


def test_surcharge_fine_par_cle():
    def fake_int(key, default=0):
        return 10 if key == "AI_RAG_MAX_TABLES" else default
    with patch.object(ai_rag_budget, "get_config", _fake_config({"AI_PROVIDER": "ollama"})), \
         patch.object(ai_rag_budget, "get_config_int", fake_int):
        b = ai_rag_budget.get_budget()
    assert b["max_tables"] == 10          # surchargé
    assert b["max_cols"] == 18            # valeur du profil
```

- [ ] **Step 2 : Vérifier l'échec**

Run (serveur) : `docker-compose exec backend pytest tests/test_ai_rag_budget.py -v`
Expected: FAIL (module inexistant).

- [ ] **Step 3 : Implémenter le module**

```python
# backend/services/ai_rag_budget.py
# -*- coding: utf-8 -*-
"""
ai_rag_budget — Budgets RAG adaptés au fournisseur de modèle actif.

Les plafonds historiques (7 tables, 18 colonnes, 3 exemples, 1 pack, 8 arêtes)
sont calibrés pour Ollama local (num_ctx=4096, cache KV CPU : cf. CLAUDE.md,
« ne pas gonfler le prompt »). Le fournisseur EXTERNE (AI_PROVIDER=openai,
contexte 128k+) n'a pas cette contrainte : un prompt plus riche réduit les
hallucinations et améliore les jointures.

Profils :
  compact — valeurs historiques (Ollama). NE PAS AUGMENTER sans retirer ailleurs.
  large   — fournisseur externe.
Sélection : AI_RAG_PROFILE (auto|compact|large, défaut auto = selon AI_PROVIDER).
Surcharges fines : AI_RAG_MAX_TABLES, AI_RAG_MAX_COLS, AI_RAG_NB_EXEMPLES,
AI_SKILL_MAX_PACKS, AI_SKILL_MAX_CHARS, AI_RAG_MAX_EDGES (0/absent = profil).
"""
from services.config_service import get_config, get_config_int

_PROFILS = {
    "compact": {"max_tables": 7,  "max_cols": 18, "nb_exemples": 3,
                "max_packs": 1, "pack_chars": 700,  "max_edges": 8},
    "large":   {"max_tables": 14, "max_cols": 40, "nb_exemples": 6,
                "max_packs": 3, "pack_chars": 2500, "max_edges": 20},
}

_SURCHARGES = [
    ("max_tables", "AI_RAG_MAX_TABLES"),
    ("max_cols", "AI_RAG_MAX_COLS"),
    ("nb_exemples", "AI_RAG_NB_EXEMPLES"),
    ("max_packs", "AI_SKILL_MAX_PACKS"),
    ("pack_chars", "AI_SKILL_MAX_CHARS"),
    ("max_edges", "AI_RAG_MAX_EDGES"),
]


def get_budget() -> dict:
    """Budget RAG effectif : {profil, max_tables, max_cols, nb_exemples,
    max_packs, pack_chars, max_edges}. Lecture dynamique (DB > env > défaut)."""
    profil = (get_config("AI_RAG_PROFILE", "auto") or "auto").strip().lower()
    if profil not in ("compact", "large"):
        provider = (get_config("AI_PROVIDER", "ollama") or "ollama").strip().lower()
        profil = "large" if provider == "openai" else "compact"
    budget = dict(_PROFILS[profil])
    for cle, param in _SURCHARGES:
        v = get_config_int(param, 0)
        if v > 0:
            budget[cle] = v
    budget["profil"] = profil
    return budget
```

- [ ] **Step 4 : Vérifier le passage des tests**

Run (serveur) : `docker-compose exec backend pytest tests/test_ai_rag_budget.py -v`
Expected: 4 PASS.

- [ ] **Step 5 : Commit**

```bash
git add backend/services/ai_rag_budget.py backend/tests/test_ai_rag_budget.py
git commit -m "feat(ia): budgets RAG adaptatifs selon le fournisseur (compact Ollama / large externe)"
```

---

### Task 3 : Brancher les budgets dans le pipeline RAG

**Files:**
- Modify: `backend/services/ai_schema_retriever.py` (constantes `MAX_TABLES`, `MAX_COLS_PAR_TABLE`)
- Modify: `backend/services/ai_prompt_builder.py` (`NB_EXEMPLES`, `build_skill_block`)
- Modify: `backend/services/ai_knowledge_graph.py` (`MAX_EDGES`)

- [ ] **Step 1 : `ai_schema_retriever` — remplacer les constantes par le budget**

En tête de fichier, ajouter l'import :
```python
from services.ai_rag_budget import get_budget
```
Les constantes `MAX_TABLES = 7` / `MAX_COLS_PAR_TABLE = 18` restent comme documentation du profil compact mais ne sont plus utilisées. Dans `retrieve_tables`, remplacer les 3 usages :
```python
def retrieve_tables(question: str, conn=None) -> list:
    if conn is None:
        with get_db_connection() as c:
            return retrieve_tables(question, c)
    max_tables = get_budget()["max_tables"]
    tables = _match_domain_tables(question)
    for t in _semantic_tables(question, conn, max_tables):
        if t not in tables:
            tables.append(t)
    if len(tables) < 2:
        for t in _fts_fallback(question, conn, max_tables):
            if t not in tables:
                tables.append(t)
    logger.info(f"RAG tables pour «{question[:60]}» : {tables[:max_tables]}")
    return tables[:max_tables]
```
Dans `_columns_from_dictionary`, remplacer la dernière ligne :
```python
    max_cols = get_budget()["max_cols"]
    return [(nom, txt, ab, ck, lng)
            for nom, txt, _kf, _pos, ab, ck, lng in rows[:max_cols]]
```
Dans `_columns_from_information_schema`, remplacer le paramètre du `LIMIT` :
```python
    with conn.cursor() as cur:
        cur.execute(sql, (schema, table, get_budget()["max_cols"]))
        return cur.fetchall()
```

- [ ] **Step 2 : `ai_prompt_builder` — exemples et packs budgétés**

Import en tête : `from services.ai_rag_budget import get_budget`.
Dans `build_skill_block`, remplacer la lecture des env `AI_SKILL_MAX_PACKS` / `AI_SKILL_MAX_CHARS` :
```python
    budget = get_budget()
    max_packs = max(1, budget["max_packs"])
    max_chars = budget["pack_chars"]
```
Dans `build_dynamic_prompt`, remplacer l'appel aux exemples :
```python
    exemples = _select_examples(question, k=get_budget()["nb_exemples"], conn=conn)
```
(`NB_EXEMPLES = 3` reste comme valeur par défaut de la signature `_select_examples`.)

- [ ] **Step 3 : `ai_knowledge_graph` — arêtes budgétées**

Import en tête : `from services.ai_rag_budget import get_budget`.
Au début de `get_relevant_subgraph` (après le `if len(noms) < 2`), lire `max_edges = get_budget()["max_edges"]` et remplacer les 3 comparaisons `>= MAX_EDGES` / `< MAX_EDGES` par `>= max_edges` / `< max_edges`.

- [ ] **Step 4 : Vérifier la non-régression des tests IA sur le serveur**

Run : `docker-compose exec backend pytest tests/ -k "ai or ollama or llm" -v`
Expected: tous PASS (les modules RAG n'ont pas de test dédié ; la non-régression passe par l'inspecteur, étape suivante).

- [ ] **Step 5 : Vérification fonctionnelle via l'inspecteur**

Sur `http://10.190.100.58:3000/configuration-ia`, onglet **Inspecteur**, question « liste des fournisseurs avec leurs factures » :
- avec `AI_PROVIDER=ollama` → ~7 tables max, ~3 exemples (comportement inchangé) ;
- avec `AI_PROVIDER=openai` → jusqu'à 14 tables, 6 exemples, bloc connaissances plus riche, `tokens_estimes` sensiblement plus élevé.

- [ ] **Step 6 : Commit**

```bash
git add backend/services/ai_schema_retriever.py backend/services/ai_prompt_builder.py backend/services/ai_knowledge_graph.py
git commit -m "feat(ia): pipeline RAG branché sur les budgets adaptatifs"
```

---

### Task 4 : Couvrir `clean_data` dans le RAG (indexation + libellés)

126 tables `clean_data` (cible IFS) sont invisibles de la recherche sémantique et leurs colonnes sont injectées sans libellés. On indexe leurs documents (nom + description `COMMENT ON` + colonnes) et on enrichit le rendu colonnes avec `col_description`.

**Files:**
- Modify: `backend/build_ai_index.py` (nouvelle fonction `_fetch_clean_table_documents`, appelée par `index_tables`)
- Modify: `backend/services/ai_schema_retriever.py` (`_columns_from_information_schema`)

- [ ] **Step 1 : `build_ai_index.py` — documents clean_data**

Ajouter après `_fetch_table_documents` :
```python
def _fetch_clean_table_documents(conn):
    """
    Documents des tables/vues clean_data (cible IFS) : nom + description
    (COMMENT ON TABLE, souvent vide) + colonnes avec leurs commentaires
    (COMMENT ON COLUMN). Ces tables sont absentes du dictionnaire SAP, d'où
    le passage par information_schema + pg_description.
    """
    sql = """
        SELECT c.table_name,
               coalesce(obj_description(pc.oid), '') AS descr,
               string_agg(
                   c.column_name ||
                   CASE WHEN coalesce(col_description(pc.oid, c.ordinal_position), '') <> ''
                        THEN ' (' || col_description(pc.oid, c.ordinal_position) || ')' ELSE '' END,
                   ', ' ORDER BY c.ordinal_position
               ) AS colonnes
        FROM information_schema.columns c
        JOIN pg_catalog.pg_class pc ON pc.relname = c.table_name
        JOIN pg_catalog.pg_namespace n ON n.oid = pc.relnamespace
                                       AND n.nspname = c.table_schema
        WHERE c.table_schema = 'clean_data'
        GROUP BY c.table_name, pc.oid
    """
    docs = []
    with conn.cursor() as cur:
        cur.execute(sql)
        for tbl, descr, colonnes in cur.fetchall():
            ref_id = f"clean_data.{tbl}"
            content = f"Table {ref_id} (donnees transformees pour IFS). {descr}. Colonnes : {colonnes}".strip()
            if len(content) > MAX_DOC_CHARS:
                content = content[:MAX_DOC_CHARS].rsplit(",", 1)[0] + " …"
            docs.append((ref_id, content))
    return docs
```
Dans `index_tables`, remplacer la première ligne :
```python
def index_tables(conn) -> int:
    docs = _fetch_table_documents(conn) + _fetch_clean_table_documents(conn)
```

- [ ] **Step 2 : `ai_schema_retriever._columns_from_information_schema` — libellés**

Remplacer la requête pour récupérer les commentaires de colonnes (même forme de tuple qu'avant : le libellé remplace la chaîne vide) :
```python
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
```

- [ ] **Step 3 : Réindexer sur le serveur**

```bash
docker-compose exec backend python build_ai_index.py --only tables
```
Expected: « Tables du dictionnaire à indexer : ~316 » puis « ✅ Tables indexées : ~316/316 » (~10-15 min sur CPU, bge-m3).

- [ ] **Step 4 : Vérifier en base et via l'inspecteur**

```sql
SELECT count(*) FROM public.ai_embeddings WHERE kind='table' AND ref_id LIKE 'clean_data.%';
```
Expected: ~126. Puis, Inspecteur avec « articles transformés pour IFS » → des tables `clean_data.*` apparaissent dans « Tables retrouvées ».

- [ ] **Step 5 : Commit**

```bash
git add backend/build_ai_index.py backend/services/ai_schema_retriever.py
git commit -m "feat(ia): RAG etendu aux tables clean_data (index semantique + libelles colonnes)"
```

---

### Task 5 : Auto-correction enrichie des colonnes réelles

Quand un SQL échoue en 42703/42P01, le prompt de réparation ne contient que l'erreur PG. On y ajoute le schéma réel des tables référencées par le SQL fautif : le modèle corrige au lieu de re-deviner.

**Files:**
- Modify: `backend/services/ai_schema_retriever.py` (nouvelle fonction `schema_for_sql` + `import re`)
- Modify: `backend/api/ai_assistant.py` (`_try_repair`)
- Test: `backend/tests/test_schema_for_sql.py`

- [ ] **Step 1 : Écrire les tests**

```python
# backend/tests/test_schema_for_sql.py
"""Tests de l'extraction des tables d'un SQL fautif pour l'auto-correction."""
from unittest.mock import patch

from services import ai_schema_retriever
from services.ai_schema_retriever import _tables_in_sql


def test_extrait_tables_qualifiees_dedupliquees():
    sql = ("SELECT a.lifnr FROM raw_data.lfa1 a "
           "JOIN raw_data.lfb1 b ON b.lifnr = a.lifnr "
           "JOIN raw_data.lfa1 c ON c.lifnr = a.lifnr")
    assert _tables_in_sql(sql) == ["raw_data.lfa1", "raw_data.lfb1"]


def test_extrait_clean_data_et_public():
    sql = "SELECT * FROM clean_data.part_catalog p JOIN public.sap_table_fields f ON true"
    assert _tables_in_sql(sql) == ["clean_data.part_catalog", "public.sap_table_fields"]


def test_sql_sans_table_renvoie_vide():
    assert _tables_in_sql("SELECT 1") == []


def test_schema_for_sql_delegue_a_build_schema_block():
    with patch.object(ai_schema_retriever, "build_schema_block",
                      return_value="raw_data.lfa1 : lifnr, name1") as bsb:
        bloc = ai_schema_retriever.schema_for_sql("SELECT nom FROM raw_data.lfa1", conn="fake")
    assert "lfa1" in bloc
    bsb.assert_called_once_with("", "fake", tables=["raw_data.lfa1"])
```

- [ ] **Step 2 : Vérifier l'échec**

Run (serveur) : `docker-compose exec backend pytest tests/test_schema_for_sql.py -v`
Expected: FAIL (`_tables_in_sql` inexistant).

- [ ] **Step 3 : Implémenter dans `ai_schema_retriever.py`**

Ajouter `import re` en tête, puis en fin de module (avant le `if __name__`) :
```python
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
```

- [ ] **Step 4 : Brancher dans `_try_repair` (`api/ai_assistant.py`)**

Remplacer la fonction existante :
```python
def _try_repair(question, system_prompt, bad_sql, erreur):
    """Appelle le modèle pour corriger un SQL fautif, en lui fournissant les
    colonnes RÉELLES des tables référencées (le message d'erreur PG seul le
    laisse re-deviner). Renvoie le SQL corrigé ou None (best-effort)."""
    try:
        from services.ai_schema_retriever import schema_for_sql
        bloc = schema_for_sql(bad_sql)
        if bloc:
            erreur = f"{erreur}\nSCHEMA REEL des tables utilisees (seules colonnes valides) :\n{bloc}"
    except Exception as e:
        logger.debug(f"Auto-correction : schéma réel indisponible ({e})")
    try:
        fix = repair_sql(question, system_prompt, bad_sql, erreur)
        sql = (fix or {}).get("sql")
        return sql or None
    except (LLMBusyError, LLMUnavailableError, LLMError) as e:
        logger.warning(f"⚠️ Auto-correction indisponible : {e}")
        return None
    except Exception as e:
        logger.warning(f"⚠️ Auto-correction : échec inattendu : {e}")
        return None
```

- [ ] **Step 5 : Vérifier le passage des tests**

Run (serveur) : `docker-compose exec backend pytest tests/test_schema_for_sql.py tests/ -k "ai or llm" -v`
Expected: PASS.

- [ ] **Step 6 : Commit**

```bash
git add backend/services/ai_schema_retriever.py backend/api/ai_assistant.py backend/tests/test_schema_for_sql.py
git commit -m "feat(ia): auto-correction avec schema reel des tables du SQL fautif"
```

---

### Task 6 : Stats d'erreurs mesurables (API + onglet Usage)

Pour vérifier que les tâches 1-5 font baisser le taux d'échec, l'onglet Usage affiche la répartition succès/erreurs par type sur 30 jours.

**Files:**
- Modify: `backend/api/ai_config.py` (route `/usage`)
- Modify: `frontend/src/services/aiConfigService.ts` (type `AiConfigUsage`)
- Modify: `frontend/src/pages/ConfigurationIA.tsx` (onglet Usage)

- [ ] **Step 1 : Backend — enrichir `/ai-config/usage`**

Dans la fonction de la route `/usage` d'`ai_config.py`, ajouter au payload une clé `erreurs_30j` calculée par :
```python
    stats_sql = """
        SELECT CASE
                 WHEN statut = 'rejete' THEN 'rejet_sql_guard'
                 WHEN raison_rejet ILIKE '%délai imparti%'
                   OR raison_rejet ILIKE '%delai imparti%' THEN 'timeout_modele'
                 WHEN raison_rejet ILIKE '%does not exist%' THEN 'colonne_ou_table_inexistante'
                 WHEN raison_rejet ILIKE '%JSON exploitable%' THEN 'json_modele'
                 WHEN statut = 'succes' THEN 'succes'
                 ELSE 'autre_erreur'
               END AS type_resultat,
               count(*) AS nb
        FROM public.ai_query_log
        WHERE date_creation >= CURRENT_TIMESTAMP - INTERVAL '30 days'
        GROUP BY 1
        ORDER BY nb DESC
    """
    with conn.cursor() as cur:
        cur.execute(stats_sql)
        erreurs_30j = [{"type": r[0], "nb": r[1]} for r in cur.fetchall()]
```
et l'ajouter au `jsonify` existant : `"erreurs_30j": erreurs_30j`.
(NB : `cur.execute(stats_sql)` est appelé SANS paramètres → les `%` littéraux des ILIKE passent tels quels, ne pas les doubler.)

- [ ] **Step 2 : Frontend — type et affichage**

`aiConfigService.ts` :
```typescript
export interface AiConfigUsage {
  feedback: { up: number; down: number };
  cooccurrences: { src: string; dst: string; poids: number }[];
  erreurs_30j?: { type: string; nb: number }[];
}
```
`ConfigurationIA.tsx`, onglet Usage (tab 5), ajouter un `Paper` à côté de « Feedback » :
```tsx
          <Paper variant="outlined" sx={{ p: 2, flex: '1 1 300px' }}>
            <Typography variant="subtitle2" sx={{ fontWeight: 700, mb: 1 }}>
              Résultats des 30 derniers jours
            </Typography>
            <Stack direction="row" spacing={0.5} flexWrap="wrap" useFlexGap>
              {(usage.erreurs_30j || []).map((e) => (
                <Chip
                  key={e.type}
                  size="small"
                  color={e.type === 'succes' ? 'success' : 'error'}
                  variant={e.type === 'succes' ? 'filled' : 'outlined'}
                  label={`${e.type} : ${e.nb}`}
                />
              ))}
            </Stack>
          </Paper>
```

- [ ] **Step 3 : Vérifier (serveur)**

Build frontend serveur (`npm run build` via le deploy habituel), puis onglet Usage : chips `succes : N`, `timeout_modele : N`, `colonne_ou_table_inexistante : N`… cohérents avec `ai_query_log`.

- [ ] **Step 4 : Commit**

```bash
git add backend/api/ai_config.py frontend/src/services/aiConfigService.ts frontend/src/pages/ConfigurationIA.tsx
git commit -m "feat(ia): repartition succes/erreurs 30j dans l'onglet Usage (mesure des ameliorations)"
```

---

### Task 7 : Réglages au catalogue Paramètres + documentation

**Files:**
- Modify: `backend/api/settings.py` (catalogue, catégorie `ai` existante)
- Modify: `CLAUDE.md` (section Assistant IA)

- [ ] **Step 1 : Ajouter la clé de profil au `SETTINGS_CATALOG`** (à la suite des clés `AI_EXTERNAL_*`)

```python
    {'key': 'AI_RAG_PROFILE', 'category': 'ai', 'label': 'Profil RAG (auto | compact | large)', 'type': 'text', 'secret': False, 'default': 'auto', 'requires_restart': False},
```

- [ ] **Step 2 : Documenter dans `CLAUDE.md`** (section « Assistant IA », après la ligne sur le pipeline)

```markdown
- Fournisseurs : `AI_PROVIDER` = `ollama` (local, defaut) | `openai` (API OpenAI-compatible, cles `AI_EXTERNAL_*` en base). Budgets RAG adaptatifs (`services/ai_rag_budget.py`) : profil `compact` (Ollama, num_ctx=4096) / `large` (externe) selon le fournisseur, forcable via `AI_RAG_PROFILE`. La contrainte « ne pas gonfler le prompt » ne s'applique qu'au profil compact.
- Few-shots : `dataset_sap_ia.jsonl` SANS filtres techniques mandt/loevm (assaini par `assainir_dataset.py`) ; apres modification du dataset, relancer `python build_ai_index.py --only examples`.
```

- [ ] **Step 3 : Commit**

```bash
git add backend/api/settings.py CLAUDE.md
git commit -m "chore(ia): cle AI_RAG_PROFILE au catalogue + doc CLAUDE.md"
```

---

## Vérification finale (sur le serveur, après déploiement)

1. `docker-compose exec backend pytest tests/ -v` → tout PASS.
2. Réindexation complète : `docker-compose exec backend python build_ai_index.py` → ~316 tables + 61 exemples + cards.
3. Inspecteur : une question « fournisseurs » en mode externe → 14 tables max, 6 exemples, packs élargis ; en mode ollama → comportement identique à avant (7/18/3).
4. Poser 5-10 questions réelles (dont une sur `clean_data`, ex. « articles du catalogue transformé ») et suivre l'onglet Usage : la part `colonne_ou_table_inexistante` doit chuter (baseline actuelle : ~19/63 erreurs).
