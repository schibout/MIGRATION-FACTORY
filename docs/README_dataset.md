# Dataset texte→SQL — Migration Factory (SAP R/3 4.6C → IFS)

## Contenu
- `dataset_sap_ia.jsonl` — **61 exemples** question française → réponse `{"sql": ..., "explication": ...}`, au format chat standard (`messages` system/user/assistant). Le SQL est conforme au **schéma réel** de `sap_migration` (introspection du 2026-06-11) : mandt='700', flags loevm/lvorm/loekz, casts `::numeric`, dates varchar `YYYYMMDD`, `spras='F'`, tables schéma-qualifiées. Les patterns à risque (FILTER, regex, fenêtres de dates, agrégation ekpo 800k lignes) ont été validés par EXPLAIN sur la base.
- `build_dataset.py` — générateur : modifie/ajoute des exemples puis relance `python3 build_dataset.py` (nécessite `ai_system_prompt.py` à côté).
- `eval_dataset.py` — banc d'évaluation contre Ollama.

## Couverture (61 exemples)
| Domaine | Nb | Exemples |
|---|---|---|
| Fournisseurs | 20 | complétude, doublons, blocages, banques/IBAN, périmètre migration, CA |
| Articles / stocks | 11 | types, divisions 2200/9200, désignations, stocks, valorisation |
| Codification IFS | 5 | taux de codification, manuelles, reste à faire, audit |
| Achats | 9 | commandes par an, top fournisseurs, info-achats, sources, délais |
| Maintenance | 6 | équipements, postes techniques, hiérarchie, fabricants |
| Clients | 3 | volumétrie, pays, SIRET |
| Dictionnaire | 4 | dd02t, sap_table_fields, sap_table_properties |
| Qualité de données | 3 | CP invalides, emails, IBAN |

## Usage 1 — Banc d'évaluation (recommandé, à faire maintenant)
Mesure si ton qwen2.5-coder:7b + system prompt produit du SQL correct :
```bash
# 10 premières questions, vérification du format uniquement
python3 eval_dataset.py --n 10

# Tout le dataset + vérification que chaque SQL s'exécute réellement (EXPLAIN)
pip install psycopg2-binary requests
python3 eval_dataset.py --n 0 \
  --db "postgresql://postgres:trimet2025@10.190.100.58:5432/sap_migration"
       pg_user = os.getenv("DB_USER", "postgres")
        pg_password = os.getenv("DB_PASSWORD", "trimet2025")
```
Objectif : ≥ 90 % de format valide. En dessous, c'est le system prompt qu'il faut ajuster.
⚠️ 61 questions × ~30 s sur ta VM ≈ 30 min pour le passage complet — lance-le hors heures d'usage.

## Usage 2 — Few-shots dynamiques (gain immédiat, sans entraînement)
Au lieu des exemples fixes du system prompt, sélectionne à chaque question les 3 exemples
du dataset les plus proches (similarité simple sur mots-clés ou embeddings) et injecte-les
dans le prompt. Sur un 7B, c'est le levier de qualité le plus rentable. Le dataset sert
alors de **banque d'exemples** côté `ollama_service.py`.

## Usage 3 — Fine-tuning LoRA (plus tard, nécessite un GPU)
Le format JSONL `messages` est directement consommé par Unsloth, LLaMA-Factory ou Axolotl :
```yaml
# llama-factory : dataset_info.json
"sap_sql": {"file_name": "dataset_sap_ia.jsonl", "formatting": "sharegpt",
            "columns": {"messages": "messages"}}
```
⚠️ Pas sur ta VM (CPU sans AVX2) : entraîner sur une machine GPU, puis convertir le LoRA
en GGUF et le charger dans Ollama via un Modelfile (`FROM qwen2.5-coder:7b` + `ADAPTER ./lora`).
61 exemples sont suffisants pour un premier LoRA de style/format ; vise 200-300 pour un vrai
gain de précision — enrichis avec les vraies questions de ton équipe via `ai_query_log`
(les requêtes corrigées/validées par les utilisateurs sont les meilleurs exemples).

## Maintenance du dataset
1. Toute question réelle qui a échoué puis a été corrigée → l'ajouter dans `EXEMPLES` de `build_dataset.py`.
2. Régénérer : `python3 build_dataset.py`.
3. Re-passer l'éval (usage 1) avant de déployer un changement de prompt ou de modèle.
