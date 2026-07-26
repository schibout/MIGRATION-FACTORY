**Proposition de Meilleur Plan (Version B’ — Significativement Améliorée)**

Voici une refonte complète et optimisée de la **Partie B**, rédigée dans le même style et format que ton document original. Elle conserve tes excellentes idées (exploitation prioritaire du DDIC, injection de connaissances métier, montée en modèle) tout en les rendant **plus puissantes, scalables et maintenables**.

Les principaux gains par rapport à la version initiale :
- Remplacement des **packs JSON statiques par domaine** (rigides, difficiles à maintenir, risque de bloat) par un **système hybride de Knowledge Graph (automatique) + Knowledge Cards sémantiques granulaires** (dynamique, évolutif, précis).
- Meilleure exploitation du DDIC via une vue matérialisée et un graphe de relations.
- **Prompting structuré en deux phases** (raisonnement explicite + génération) avec sortie JSON → gros saut de qualité attendu sur les modèles coder.
- Boucle d’amélioration continue exploitant `ai_query_log`.
- Évaluation et vérification plus rigoureuses.

---

# PARTIE B — Meilleur Plan : améliorer la qualité des requêtes (v2)

## Contexte
Le modèle local `qwen2.5-coder:7b` (CPU, ~3 tok/s) produit du SQL nettement inférieur à Claude sur les jointures SAP complexes, les règles métier implicites, les enums et les filtres business. Le pipeline RAG actuel est déjà riche (DOMAIN_TABLES + recherche sémantique bge-m3 + repli FTS, few-shots dynamiques, cache pgvector, auto-correction, keep-warm).  

**Manques critiques** : connaissance fine et fiable des clés étrangères/jointures (le `check_table` du DDIC est sous-exploité), valeurs/enums métier, règles business récurrentes, synonymes et patterns de requêtes par domaine. Les « skills » statiques aident mais manquent de granularité, d’évolutivité et de précision de récupération.

**Marge disponible** : prompt ~2 200 tok sous `num_ctx=4096` → ~1 600–1 800 tok de marge utile. On refuse de monter à 8192 (incompatibilité keep-warm + ralentissement CPU).

## Décisions validées (mises à jour)
- Leviers prioritaires : **(1) Exploitation maximale du DDIC + Knowledge Graph**, **(2) Récupération sémantique granulaire et dynamique de connaissances** (remplace les packs JSON statiques), **(3) Prompting structuré en deux phases (CoT + JSON)**, **(4) Modèle plus puissant + boucle d’amélioration continue**.
- Les packs JSON par domaine sont abandonnés au profit d’une approche plus fine et auto-apprenante.
- Option hybride Claude (comme générateur ou critic) reste documentée en réserve (non activée maintenant).

## B0. Enrichissement massif du DDIC + Knowledge Graph (fondation — gain rapide et durable)
Le DDIC (`public.sap_table_fields` surtout) est la source de vérité. On passe d’un enrichissement minimal à une exploitation systématique :

- Refonte de `_columns_from_dictionary()` (`ai_schema_retriever.py`) : injection compacte et expressive par colonne → `lifnr (Fournisseur) [NUMC 10] [FK→lfa1]`.
- Création d’une **vue matérialisée** `mv_sap_table_relationships` consolidant :
  - Toutes les relations `check_table` du DDIC.
  - Jointures manuellement validées.
  - Co-occurrences fréquentes extraites de `ai_query_log` (requêtes en statut `succes`).
- Nouveau module `backend/services/ai_knowledge_graph.py` : construit (au démarrage ou via cache) un graphe léger des tables/concepts/jointures. Fonction `get_relevant_subgraph(question, tables)` renvoie un bloc très dense et justifié.

**Avantage** : le modèle reçoit automatiquement des indices de jointure de haute qualité issus du dictionnaire, réduisant fortement la dépendance à la curation manuelle.

## B1. Système de Knowledge Cards sémantique granulaire (remplace les packs statiques)
Au lieu de fichiers JSON monolithiques par domaine, on crée une **base de petits chunks curés et vectorisés** (jointures précises, règles métier, enums, patterns validés, glossaire/synonymes).

- **Stockage** : `backend/config/knowledge/` (fichiers `.md` avec frontmatter YAML : `type` (join|rule|enum|pattern), `tables`, `priority`, `keywords`). Chargés dans une table `ai_knowledge_base` (contenu + embedding bge-m3 + metadata).
- **Récupération** : nouvelle fonction `retrieve_relevant_knowledge(question, tables_used)` (dans `ai_schema_retriever.py` ou nouveau `knowledge_service.py`) qui combine :
  - Recherche vectorielle (bge-m3 existant).
  - Filtrage par tables du graphe et priorité.
  - Reranking simple.
- **Injection** : `build_knowledge_block()` dans `ai_prompt_builder.py`, placé après le schéma enrichi et le subgraph, avant les few-shots. Plafond strict (~350–450 tokens). Quelques règles critiques (fournisseurs, factures, stocks) peuvent être forcées.

**Avantages vs version originale** : beaucoup plus granulaire, maintenable (ajouter une règle = un petit fichier), précis (seules les connaissances pertinentes sont injectées), et scalable à de nouveaux domaines sans refonte de détection.

## B2. Prompting structuré en deux phases (CoT + sortie JSON)
Refonte majeure de `build_dynamic_prompt()` pour compenser les limites du modèle local :

1. **Phase Raisonnement** : le modèle doit d’abord expliciter (tables, jointures justifiées par le graphe/DDIC, règles métier à appliquer, filtres).
2. **Phase Génération** : production du SQL en s’appuyant strictement sur le contexte fourni.

**Template renforcé** avec persona experte SAP + instruction stricte d’utiliser uniquement le graphe et les knowledge cards fournies. Sortie **JSON structurée** (`raisonnement`, `tables`, `jointures`, `sql`, `explications`).

Option légère de self-critique (2e passage sur erreur d’exécution) pour les cas ambigus.

Cela devrait produire un gain majeur en précision des jointures et respect des règles métier.

## B3. Stratégie Modèle & Évaluation
- Migration principale vers `qwen2.5-coder:14b` (Q4_K_M recommandé, ~9–10 Go RAM).
- Test conditionnel du 32B (Q3_K_M) et d’alternatives 2026 (DeepSeek-R1 dérivés ou Qwen3-Coder si disponibles localement).
- `OLLAMA_MODEL` configurable. Garder `num_ctx=4096` et adapter le keep-warm.
- Critères d’adoption stricts : +10 à +18 points de requêtes exécutables sur le dataset (sans régression), qualité des jointures/règles validée manuellement sur 15–20 cas, latence médiane ≤ 3 min pour le 14B.

## B4. Boucle d’amélioration continue (moat long terme)
- Après chaque requête en statut `succes`, extraction automatique (prompt léger) des nouveaux patterns, jointures ou règles observées.
- Proposition à un administrateur pour validation et ajout dans la base de connaissances/graphe.
- Bouton de feedback (thumbs up/down) dans l’interface pour collecter des signaux supervisés.

## Hors périmètre (réserve documentée)
- Hybride Claude (générateur ou critic) derrière `AI_PROVIDER`.
- Fine-tuning LoRA ou agent multi-étapes complet.
- À réévaluer uniquement si le 14B + Knowledge Graph ne suffit pas.

## Fichiers à modifier / créer
- `backend/services/ai_schema_retriever.py` — enrichissement massif DDIC, vue matérialisée, `retrieve_relevant_knowledge()`.
- `backend/services/ai_knowledge_graph.py` (**nouveau**) — construction et interrogation du graphe.
- `backend/services/knowledge_service.py` (**nouveau**) — chargement, vectorisation et retrieval des cards.
- `backend/services/ai_prompt_builder.py` — refonte majeure (`build_knowledge_block()`, templates en 2 phases, JSON mode).
- `backend/config/knowledge/` (**nouveau**) — fichiers `.md` d’amorce (jointures fournisseurs/factures/stocks, règles métier courantes, enums).
- `backend/config/settings.py` + `backend/.env.example` — nouveaux paramètres `AI_KNOWLEDGE_*`, `AI_KG_*`.
- Migration pour `ai_knowledge_base` et `mv_sap_table_relationships`.
- Scripts : `scripts/seed_knowledge.py`, mise à jour de `docs/eval_dataset.py` et `compare_prompts.py`.
- Tests : `test_knowledge_retrieval.py`, `test_knowledge_graph.py`.

## Vérification (côté serveur)
1. `python -m services.ai_prompt_builder "<question domaine>"` → schéma très enrichi, subgraph pertinent, knowledge block ciblé (< 3800 tokens total), JSON bien formé.
2. Tous les patterns SQL dans les knowledge cards passent `validate_and_wrap` + EXPLAIN (rôle readonly_ai).
3. A/B complet (baseline vs nouveau système) sur les 61 questions + 20 cas ajoutés → gain net significatif en taux d’exécution, exactitude des jointures et respect des règles métier (utiliser un LLM-judge pour la sémantique).
4. Revue manuelle approfondie de 15–20 questions complexes par un utilisateur métier.
5. Test du 14B : latence, stabilité RAM, qualité vs 7B.
6. `pytest backend/tests/` (parsing des cards, retrieval pertinent, non-régression du prompt de base, tests du graphe).
7. Validation de la boucle d’amélioration sur un échantillon de logs existants.

---

**Recommandation de déploiement phasé** :
1. B0 (DDIC + vue + graphe) → gain immédiat (1–2 jours).
2. B1 (Knowledge Cards + retrieval).
3. B2 (Prompt 2 phases).
4. B3 (montée en 14B + éval rigoureuse).
5. B4 (boucle continue).

Ce plan est **nettement supérieur** à la version originale : plus maintenable, plus précis, auto-apprenant, et mieux aligné avec les meilleures pratiques Text-to-SQL/RAG de 2025–2026 (multi-stage retrieval, graph-based schema linking, structured CoT).

Veux-tu que je fusionne cela dans le document complet (Partie A inchangée + cette Partie B), que j’ajoute des exemples concrets de knowledge cards, ou que l’on affine un point particulier (ex. : garder une petite partie de packs statiques pour les domaines critiques) ?