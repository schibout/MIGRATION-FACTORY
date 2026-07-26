# Spec — Modèle externe (OpenAI-compatible) pour l'Assistant IA

**Date :** 2026-06-22
**Auteur :** Samir (dev principal) + Claude Code
**Statut :** Approuvé — prêt pour plan d'implémentation

## Objectif

Permettre à l'Assistant IA (texte → SQL) d'appeler, **au choix**, le modèle local
Ollama (`qwen2.5-coder:7b`) **ou** un modèle externe via une API
**OpenAI-compatible** (OpenAI, Azure OpenAI, Mistral, Groq, OpenRouter, vLLM…).

Exigences explicites de l'utilisateur :
- La **clé API** et l'**URL** du modèle externe sont **stockées en base**
  (`public.system_config`), la clé étant masquée comme les autres secrets.
- Le **choix local / distant** est **paramétrable depuis les pages de
  configuration** (onglet dédié dans Configuration IA, et page Paramètres).

## Décisions de cadrage (validées)

| Sujet | Décision |
|---|---|
| Type de fournisseur externe | API **OpenAI-compatible générique** (Base URL + Clé + Modèle) |
| Cohabitation avec Ollama | **Bascule (toggle)** : un seul fournisseur actif à la fois (`AI_PROVIDER`) |
| Portée | **Bout-en-bout** : UI + stockage + câblage backend réel |
| Stockage de la config | **Approche A** : clés ajoutées au `SETTINGS_CATALOG` (catégorie `ai`), réutilisation de l'infra Paramètres |
| Bouton « Tester la connexion » | **Oui** |

## Avertissement de confidentialité

Le projet pose le principe « **aucune donnée vers le cloud** » (CLAUDE.md).
Basculer sur le fournisseur externe envoie vers un service tiers la **question**
**et** le prompt RAG (schéma des tables, few-shots pouvant contenir des valeurs
réelles). Le design doit donc afficher un **bandeau d'avertissement clair** dans
l'UI quand le mode externe est actif. Le mode par défaut reste `ollama`.

---

## 1. Configuration — clés `system_config` (catégorie `ai`)

Ajout au `SETTINGS_CATALOG` de `backend/api/settings.py` :

| Clé | Type | Secret | Défaut | Rôle |
|---|---|---|---|---|
| `AI_PROVIDER` | text | non | `ollama` | `ollama` \| `openai` — fournisseur actif |
| `AI_EXTERNAL_BASE_URL` | url | non | `https://api.openai.com/v1` | Endpoint OpenAI-compatible |
| `AI_EXTERNAL_API_KEY` | password | **oui** | _(vide)_ | Clé API (masquée `••••••••`) |
| `AI_EXTERNAL_MODEL` | text | non | `gpt-4o-mini` | Nom du modèle |
| `AI_EXTERNAL_TIMEOUT_SECONDS` | number | non | `60` | Timeout HTTP de la complétion |

- Nouvelle entrée `'ai': 'Assistant IA — Modèle'` dans `CATEGORY_LABELS`.
- Persistance (DB > env > défaut), masquage du secret et application à
  `os.environ` : **réutilisés tels quels** via le `PUT /settings` existant.
- Lecture côté services via `config_service.get_config(...)` (ordre DB > env >
  défaut déjà implémenté).

## 2. Backend — façade fournisseur

### 2.1 `services/external_llm_service.py` (nouveau)
Client OpenAI-compatible exposant les **mêmes signatures publiques** que
`ollama_service` :
- `generate_sql(question, system_prompt) -> {"sql","explication"}`
- `repair_sql(question, system_prompt, bad_sql, erreur) -> {"sql","explication"}`
- `check_health() -> {"available","model","model_present","models","error"}`

Détails :
- Appel `POST {base_url}/chat/completions`, corps :
  `{model, messages:[{system},{user}], temperature:0,
  response_format:{"type":"json_object"}, max_tokens}`.
- Lecture de la config via `config_service.get_config` (`AI_EXTERNAL_*`).
- Réutilise les helpers de parsing JSON `_strip_json_fences` et
  `_extract_sql_payload` d'`ollama_service` (importés ; ils sont purs). Même
  logique de **retry unique** sur JSON non exploitable, alignée sur le mode CoT
  (`AI_COT_ENABLED`) comme `ollama_service.generate_sql`.
- **Lève les mêmes classes d'exceptions** que `ollama_service`
  (`OllamaUnavailableError`, `OllamaError`) afin de ne rien changer aux blocs
  `except` d'`ai_assistant`. Pas de `OllamaBusyError` (le cloud encaisse la
  concurrence → pas de sémaphore 429).
- Mapping erreurs : timeout/connexion → `OllamaUnavailableError` ;
  HTTP 401/403 → `OllamaUnavailableError` avec message explicite (clé invalide) ;
  HTTP 429 → `OllamaUnavailableError` (quota/limite) ; réponse non parsable après
  retry → `OllamaError`.

### 2.2 `services/llm_service.py` (nouveau — façade)
- Lit `AI_PROVIDER` (`config_service.get_config('AI_PROVIDER','ollama')`) et
  délègue `generate_sql` / `repair_sql` / `check_health` à `ollama_service` ou
  `external_llm_service`.
- `check_health()` ajoute `"provider"` au payload retourné.
- Ré-exporte les exceptions sous des alias neutres :
  `LLMBusyError = OllamaBusyError`, `LLMUnavailableError = OllamaUnavailableError`,
  `LLMError = OllamaError` (les classes restent définies dans `ollama_service`).

### 2.3 `api/ai_assistant.py` (modifié)
- Remplacer l'import `from services.ollama_service import (...)` par
  `from services.llm_service import (generate_sql, repair_sql, check_health,
  LLMBusyError, LLMUnavailableError, LLMError)`.
- Adapter les noms d'exceptions dans les `except` (3 emplacements :
  `process_question`, `_try_repair`). **Aucune autre logique modifiée.**

### 2.4 Keep-warm (modifié, `ollama_service.py`)
- La boucle `_keepwarm_loop` saute sa passe si
  `config_service.get_config('AI_PROVIDER','ollama') != 'ollama'` (lecture
  dynamique → la bascule est prise en compte à chaud, sans redéploiement).
- `ollama_service` ne reçoit **aucune modification de ses fonctions publiques**
  (`generate_sql`, `repair_sql`, `check_health` inchangées) → le test existant
  `tests/test_ollama_service.py` reste valide.

## 3. Backend — test de connexion

Nouvelle route `POST /settings/test/ai` dans `backend/api/settings.py`, sur le
modèle de `test_database` / `test_smtp` :
- Lit les valeurs effectives via `_effective('AI_EXTERNAL_BASE_URL' | '...API_KEY'
  | '...MODEL' | '...TIMEOUT_SECONDS')`.
- Fait un appel minimal : `GET {base_url}/models` avec `Authorization: Bearer
  <clé>` (ou, en repli, une mini-complétion `max_tokens:1`).
- Renvoie `{success, message|error, details}` (HTTP 200 toujours, comme les
  autres tests).

## 4. Frontend — onglet « Modèle externe » dans Configuration IA

Dans `frontend/src/pages/ConfigurationIA.tsx`, ajout d'un **7ᵉ onglet** :
- **Sélecteur « Fournisseur actif »** : Ollama local / Externe (OpenAI-compatible)
  → écrit `AI_PROVIDER`.
- Champs **Base URL**, **Clé API** (masquée), **Modèle**, **Timeout**, préremplis
  via `settingsService.getAll()` filtré sur la catégorie `ai`.
- Boutons **Enregistrer** (`settingsService.update`) et **Tester la connexion**
  (`settingsService.test('ai')`), avec retour visuel succès/erreur (Snackbar
  existant).
- **Bandeau d'avertissement** (severity `warning`/`error`) visible quand
  Fournisseur actif = externe : « Les questions et le schéma des données sont
  envoyés à un service tiers (cloud). »
- Chip d'**état du fournisseur courant** (réutilise l'endpoint `/ai/health`,
  enrichi de `provider`).

### Frontend — `settingsService.ts` (modifié)
- Étendre `TestTarget` avec `'ai'`.
- Aucun nouveau service : la lecture/écriture passe par `getAll()` / `update()`.

> Conséquence assumée : la catégorie `ai` apparaît aussi dans la page
> **Paramètres** (cohérent avec DB/SAP/SharePoint/SMTP), ce qui satisfait
> l'exigence « paramétrable dans les pages de configuration ».

## 5. Contrat de génération inchangé — RAG identique pour les deux fournisseurs

Le fournisseur ne change **que qui génère le SQL**. En amont **comme** en aval,
rien ne bouge :

- **RAG (exigence explicite)** : le prompt dynamique est construit **une seule
  fois** par `build_dynamic_prompt(question)` dans `process_question`
  (`ai_assistant.py`), **avant** l'appel au modèle, puis passé tel quel à
  `generate_sql(question, system_prompt)` / `repair_sql(...)`. La façade
  transmet ce même `system_prompt` au fournisseur actif. **L'IA distante reçoit
  donc exactement le même prompt RAG que l'IA locale** : schéma ciblé
  (`ai_schema_retriever`), sous-graphe de jointures (`ai_knowledge_graph`),
  connaissances métier (cards/packs), few-shots vivants et anti-hallucination.
  `external_llm_service` n'a **aucune** logique de construction de prompt : il ne
  fait que relayer le `system_prompt` reçu.
- **Note `num_ctx`** : le budget serré `num_ctx=4096` est une contrainte
  **Ollama** (cache KV CPU). Le fournisseur externe n'envoie pas cette option ;
  le même prompt RAG (déjà compacté) y passe sans risque de troncature.
- **Aval inchangé** : même JSON `{sql, explication}`, même
  `sql_guard.validate_and_wrap`, même exécution sous le rôle `readonly_ai`,
  même LIMIT borné, `statement_timeout` 30 s, audit `ai_query_log`, cache
  sémantique, historique conversationnel et auto-correction.

## 6. Tests

- `tests/test_external_llm_service.py` (nouveau, `requests` mocké) :
  - génération JSON valide → `{sql, explication}` ;
  - JSON invalide puis retry réussi ;
  - HTTP 401 → `OllamaUnavailableError` (message clé invalide) ;
  - réponse non parsable après retry → `OllamaError`.
- `tests/test_llm_service.py` (nouveau) : aiguillage selon `AI_PROVIDER`
  (`ollama` vs `openai`), `check_health` renvoie le bon `provider`.
- `tests/test_ollama_service.py` : doit rester vert (aucune fonction publique
  d'`ollama_service` modifiée).

> Rappel projet : installation des deps et exécution des tests **sur le serveur
> distant**, pas en local.

## Hors périmètre (YAGNI)

- Pas de connecteur spécifique (OpenAI/Anthropic natif) : un seul connecteur
  OpenAI-compatible générique.
- Pas de synthèse en langage naturel des résultats par le modèle (inchangé).
- Pas de keep-warm pour le fournisseur externe (inutile : pas de cache KV CPU).
- Pas de routage par-question (le choix est global via `AI_PROVIDER`).
