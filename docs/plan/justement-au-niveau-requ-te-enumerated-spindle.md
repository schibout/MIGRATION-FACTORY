# Assistant IA — Récapitulatif des travaux + Plan d'amélioration

> Document en deux parties : **A.** ce qui a été réalisé pendant la session, **B.** le plan
> d'amélioration de la qualité des requêtes. Statut de déploiement indiqué à chaque fois.

---

# PARTIE A — Ce qui a été fait

> ⚠️ Sauf mention « déployé », les changements de code sont **dans le dépôt mais pas encore
> en ligne** : ils nécessitent `./deploybackend.sh` et/ou `./deployfrontend.sh`.

## A1. Documentation & mémoire (fait)
- **`docs/ANALYSE_IMPLEMENTATION_IA.md`** (nouveau) : analyse complète de l'implémentation IA
  (architecture, pipeline RAG, sécurité, modèle, dataset, forces/limites).
- **`CLAUDE.md`** : ajout d'une section « Assistant IA », des fichiers backend IA dans la
  structure, des commandes (install/tests/éval), et des points d'attention (budget num_ctx,
  chauffe keep-warm, Ollama sur 127.0.0.1).
- **Mémoire** (`~/.claude/.../memory/`) : `assistant_ia_ollama.md` mis à jour (RAG + historique
  conversationnel = déployés ; installation faite le 2026-06-14) ; nouvelle fiche
  `openwebui_mcpo_stack.md` (stack Open WebUI + mcpo en prod ; appel d'outils résolu le 2026-06-14) ;
  `MEMORY.md` indexé.

## A2. Correctif « pas de délai imparti » (à déployer : backend + .env serveur)
- `backend/services/ollama_service.py` : `AI_TIMEOUT_SECONDS=0` (ou absent) ⇒ `timeout=None`
  (aucune limite sur l'appel Ollama, le worker attend la fin de génération).
- `.env` et `backend/.env.example` : valeur passée de `600` à `0`.
- `frontend/.../AssistantIA.tsx` : garde-fou du poller relevé (~10 min → ~60 min).
- ⚠️ Le **`.env` du serveur** doit aussi avoir `AI_TIMEOUT_SECONDS=0`.

## A3. Correctif bug d'exécution SQL `immutabledict is not a sequence` (à déployer : backend)
- Cause : `exec_driver_sql(sql)` transmettait un `immutabledict` vide à psycopg2, qui
  interprétait les `%` (ex. `LIKE '%texte%'`) comme des placeholders.
- `backend/services/ai_readonly_db.py` : exécution via **curseur psycopg2 brut sans paramètres**
  (psycopg2 ne touche plus aux `%`).
- `backend/api/ai_assistant.py` : détection du `pgcode` adaptée à l'erreur psycopg2 brute
  (`e.pgcode` en plus de `e.orig.pgcode`) — préserve les messages conviviaux 42P01/42703/57014
  et l'auto-correction.

## A4. SQL généré conservé même en cas d'échec (à déployer : backend + frontend)
- `backend/api/ai_assistant.py` : les payloads d'échec `rejete`/`erreur` incluent désormais
  `"sql"` (et `duree_ms`) → le SQL est conservé dans l'historique conversationnel et renvoyé au chat.
  *(Rappel : `ai_query_log.sql_genere` était déjà sauvegardé en échec.)*
- `frontend/.../AssistantIA.tsx` (`ResponseBlock`) : affiche le SQL même quand la requête échoue.

## A5. Suppression de l'onglet « Historique » de la page Assistant IA (à déployer : frontend)
- `frontend/.../AssistantIA.tsx` : page passée en **mono-vue chat** ; états/fonctions/imports
  liés à l'historique retirés. La consultation de l'historique se fait désormais uniquement via
  la page **Résultats IA**.

## A6. Refonte de la page « Résultats IA » (à déployer : frontend)
- `frontend/.../ResultatsIA.tsx` : disposition **maître-détail responsive** (empilée sur petit
  écran), barre d'outils (recherche + **filtre par statut**), liste avec statut/durée, détail
  enrichi (métadonnées + SQL repliable), bouton **Relancer** disponible aussi sur les requêtes
  rejetées/en erreur (utile pour rejouer les erreurs de l'ère du bug `immutabledict`).

## A7. Éditeur SQL : modifier, enregistrer, relancer (à déployer : backend + frontend)
- `backend/api/ai_assistant.py` : nouvel endpoint **`POST /api/v1/ai/run-sql`** (exécute un SQL
  fourni, validé par sql_guard + rôle readonly_ai, **journalisé** = « enregistré »).
- `frontend/.../aiService.ts` : `runSql(sql, question)`.
- `frontend/.../ResultatsIA.tsx`, bloc « SQL généré » : champ **éditable, texte noir sur fond
  blanc** (monospace), boutons **« Enregistrer et relancer »** et **« Réinitialiser »** ; l'export
  utilise le nouvel `id_log` de la requête éditée.

## A8. Commandes de déploiement (récap)
```bash
./deploybackend.sh     # A2, A3, A4, A7
./deployfrontend.sh    # A2 (poller), A4, A5, A6, A7
# + s'assurer que le .env du serveur a AI_TIMEOUT_SECONDS=0
```
> Build TS non vérifié en local (contrainte d'exécution distante) — surveiller `npm run build`.

---

# PARTIE B — Plan : améliorer la qualité des requêtes

## Contexte
Le modèle local `qwen2.5-coder:7b` (CPU, ~3 tok/s) génère du SQL « pas au niveau de Claude ».
Le pipeline RAG est déjà riche (carte `DOMAIN_TABLES` + recherche sémantique bge-m3 + repli FTS,
few-shots dynamiques, cache sémantique pgvector, auto-correction, keep-warm). Ce qui **manque** au
modèle : jointures/clés étrangères entre tables SAP, valeurs/enums, requêtes-types par domaine,
synonymes métier. Les « skills » au sens Claude Code ne s'appliquent pas à un modèle Ollama brut :
l'équivalent concret est **injecter ces connaissances structurées, ciblées par domaine, dans le
prompt**. Marge dispo : prompt ~2 200 tok sous `num_ctx=4096` → ~1 600 tok de marge.

## Décisions validées
- Leviers retenus : **(1) packs de connaissances (skills) locaux**, **(2) modèle local plus gros**.
- Plus de few-shots : non prioritaire (couvert en partie par les packs).
- Gouvernance : envoyer schéma + question (jamais les données) à une API cloud = *acceptable*
  → option **hybride Claude** laissée en **réserve documentée** (non sélectionnée).

## B0. Ancrage sur le dictionnaire DDIC (source de vérité — consigne utilisateur)
La compréhension des tables/champs SAP doit s'appuyer sur le dictionnaire :
- `public.sap_table_properties` (description FR des tables) et **`public.sap_table_fields`** (champs :
  `field_name, position, key_flag, mandatory, data_type, length, decimals, check_table, abap_type,
  field_text, header_text, long_description`) — déjà **dérivés du DDIC, riches**.
- Sources brutes DDIC (repli/contrôle) : `raw_data.dd02l`/`dd02t` (tables + libellés `ddtext`,
  `ddlanguage='F'`), `raw_data.dd03l`/`dd03t` (champs : keyflag, position, rollname, check table),
  `raw_data.dd04t` (libellés des éléments de données).

**Constat (exploration)** : `_columns_from_dictionary()` (ai_schema_retriever.py:209-237) n'injecte
aujourd'hui QUE `field_name + field_text + key_flag + position`. Il **n'expose pas** `data_type` ni
surtout **`check_table`** — or `check_table` = **table de contrôle = clé étrangère DDIC**, exactement
l'indice de jointure qui manque au modèle.

**Action (gain rapide, complémentaire des packs)** : enrichir `build_schema_block` /
`_columns_from_dictionary` pour ajouter par colonne, de façon compacte : `data_type` (savoir
caster varchar/numc) et `check_table` quand non vide, p. ex.
`lifnr (Fournisseur) [->lfa1]`. → **indices de jointure automatiques issus du dictionnaire**, en plus
des packs curés. Garder court (budget tokens) : `check_table` seulement s'il existe.

**Amorçage des packs depuis le DDIC** : pré-remplir les `joins` d'un pack via
```sql
SELECT lower(table_name), lower(field_name), lower(check_table)
FROM public.sap_table_fields
WHERE check_table IS NOT NULL AND check_table <> ''
  AND upper(table_name) = ANY (%(tables_du_pack)s);
```
puis affiner à la main (le DDIC donne la table cible, pas toujours la condition multi-champs exacte).

## B1. Packs de connaissances (skills)
**Principe** : un fichier JSON curé par domaine ; quand la question matche un domaine, on injecte un
bloc compact `=== CONNAISSANCES METIER ===` (jointures, enums, règles, 1 requête-type) **entre le
schéma et les exemples**. Reste dans le suffixe dynamique → n'invalide pas le préfixe keep-warm.

- **Stockage** : `backend/config/skills/<domaine>.json` (versionné, diffable, comme le dataset).
  Chargé au démarrage dans `_SKILLS = _load_skills()` (pattern `_EXAMPLES`).
- **Schéma d'un pack** : `domain`, `keywords`, `tables`, `joins`, `enums`, `patterns[{intent,sql}]`,
  `rules`, `synonyms`. (`domain` == nom de fichier ; `tables` = doc/validation, le schéma réel vient
  toujours de `retrieve_tables`.)
- **Détection de domaine** : étendre `DOMAIN_TABLES` (ai_schema_retriever.py:48-77) en **3-uplets
  `(domain_id, déclencheurs, [tables])`** + nouvelle `detect_domains(question) -> list[str]`.
  Les `keywords`/`synonyms` du pack sont une 2ᵉ source de déclenchement (phrases).
- **Injection** : nouvelle `build_skill_block(question)` dans ai_prompt_builder.py, câblée dans
  `build_dynamic_prompt` (lignes 183-188) entre schéma et exemples. Défaut **1 pack**, plafond
  **~700 car ≈ 220 tok**, **max 1 pattern/pack, jamais de SQL tronqué**, `''` si aucun domaine.
- **Budget** : top-1 ≈ +220 tok → ~2 676 < 4096 : sûr. **Ne PAS monter num_ctx à 8192** (désync du
  keep-warm calé sur 4096 + ralentit le CPU). En débordement : baisser `MAX_TABLES`/`MAX_COLS`.
- **Réglages** (settings.py) : `AI_SKILL_ENABLED`, `AI_SKILL_MAX_PACKS`, `AI_SKILL_MAX_CHARS`,
  `AI_SKILLS_PATH`.
- **Packs d'amorce** : `fournisseurs.json`, `factures.json`, `articles_stock.json`
  (jointures lifnr / belnr+gjahr / matnr+werks, enums mtart/spart/stblg/ktokk, règles
  LTRIM/CAST/loevm-lvorm, 1 requête-type runnable chacun).
- **Workflow d'ajout** : copier un pack → réutiliser/ajouter l'id DOMAIN_TABLES → remplir depuis le
  **dictionnaire DDIC** (`sap_table_fields` incl. `check_table` pour les jointures, `data_type` ;
  repli `raw_data.dd03l`/`dd04t`/`dd02t`) + SQL validé → vérifier via
  `python -m services.ai_prompt_builder "<q>"` → passer chaque pattern dans `sql_guard` + EXPLAIN.

## B2. Modèle local plus gros (7b → 14b/32b)
Réutilise le banc existant, **aucun nouveau code** :
- `ollama pull qwen2.5-coder:14b` (RAM 31 Go : 14b Q4 ≈ 9-10 Go OK ; 32b Q4 ≈ 19-20 Go, marge faible
  → tester hors heures, surveiller le swap).
- Bascule par env `OLLAMA_MODEL` ; A/B sur les 61 questions **skills ON** via
  `docs/eval_dataset.py --n 0 --model <m> --db <DSN>` et `compare_prompts.py`.
- Latence : 7b ~60-90 s ; 14b ~2-3 min ; 32b ~4-6 min (worker async masque le navigateur).
- **Critère d'adoption (les 3)** : taux exécutable ↑ (≥ +5/61) sans régression ; revue manuelle
  10-15 questions (jointures/filtres corrects) ; latence médiane ≤ ~3 min (14b). Tester 32b
  seulement si 14b est bon mais limite.

## Hors périmètre (réserve)
**Hybride API Claude** pour le seul appel `generate_sql` derrière `AI_PROVIDER=ollama|anthropic`
(garde sql_guard + readonly_ai + RAG). Plus gros saut qualité/vitesse — à rouvrir si 7b/14b + packs
ne suffisent pas.

## Fichiers à modifier / créer (Partie B)
- `backend/services/ai_prompt_builder.py` — `_load_skills`, `_SKILLS`, `build_skill_block`, câblage.
- `backend/services/ai_schema_retriever.py` — `detect_domains` ; `DOMAIN_TABLES` en 3-uplets ;
  **enrichir `_columns_from_dictionary` (data_type + `check_table`/FK)** depuis `sap_table_fields`.
- `backend/config/settings.py` — `AI_SKILL_*` / `AI_SKILLS_PATH`.
- `backend/config/skills/` (nouveau) — `fournisseurs.json`, `factures.json`, `articles_stock.json`.
- `backend/.env.example` — documenter `AI_SKILL_*`.
- (Réutilisés) `backend/compare_prompts.py`, `docs/eval_dataset.py`.

## Vérification (Partie B, côté serveur)
1. `python -m services.ai_prompt_builder "<q par domaine>"` → bon pack, sous budget ; hors domaine
   → section absente (prompt inchangé).
2. Chaque `patterns[].sql` passe `validate_and_wrap` + EXPLAIN (readonly_ai).
3. A/B skills OFF vs ON (`compare_prompts.py`, 61 q) → bilan exécutables net positif, 0 régression.
4. Revue manuelle 10-15 questions.
5. Éval modèle (B2) ; si adopté, bascule `OLLAMA_MODEL` + redéploiement.
6. `pytest backend/tests/` (+ `test_skills.py` : chaque pack parse, `domain`==fichier, patterns OK).
