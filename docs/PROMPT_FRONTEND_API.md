# Prompt — Adapter le frontend à l'API SAP Extraction

> À copier-coller comme prompt pour une IA de développement frontend. Il décrit
> **exactement** les endpoints exposés par `api_simple.py` (FastAPI), avec les
> schémas de requête/réponse réels. Respecte scrupuleusement les noms de champs :
> les réponses sont en **camelCase** (`tablesDetails`, `rowsExtracted`, `startedAt`…),
> les corps de requête en **snake_case** (`batch_size`, `user_id`…).

---

## Contexte

Tu adaptes un frontend web (React/Vue/…) à une API REST FastAPI d'extraction de
données SAP → PostgreSQL. L'API tourne sur `http://<host>:8000`. **Pas
d'authentification** (aucun header requis). CORS ouvert (`*`). Toutes les réponses
sont en JSON. Les erreurs suivent le format FastAPI : `{ "detail": "<message>" }`
avec un code HTTP (400 requête invalide, 404 introuvable, 502 erreur SAP/PG, 503
modules SAP indisponibles).

Le flux principal côté UI : **choisir des tables → lancer une extraction → suivre
la progression au fil de l'eau (polling) → consulter logs / annuler**.

---

## Modèle de suivi (IMPORTANT)

- L'extraction est **asynchrone** : `POST /extract` retourne immédiatement un
  `extraction_id` ; l'extraction tourne en tâche de fond.
- Le suivi se fait par **polling** de `GET /status/{job_id}` (recommandé toutes
  les **1 à 2 s** tant que `status` ∈ `pending|running`). Il n'y a **pas** de
  WebSocket/SSE pour l'instant.
- **Progression au fil de l'eau** : pendant l'extraction, `tablesDetails[].rows`
  et `rowsExtracted` **augmentent en direct** (mis à jour à chaque lot commité).
  Le champ `progress` (0–100) est calculé au **grain table** (tables terminées /
  total), donc il progresse par paliers ; pour un ressenti « live », affiche aussi
  le compteur de lignes `rows` par table et `rowsExtracted` global.
- Statuts possibles d'un job : `pending`, `running`, `completed`,
  `completed_with_errors`, `failed`, `cancelled`. Statuts par table (dans
  `tablesDetails[].status`) : `pending`, `running`, `completed`, `failed`,
  `cancelled`.

---

## Endpoints

### Santé & catalogue

| Méthode & route | Description |
|---|---|
| `GET /health` | `{ status, active_jobs, sap: {...}, postgres: {...}, database_persistence: bool }`. Teste les connexions SAP + PostgreSQL. |
| `GET /tables?disabled={bool?}` | Liste des tables **configurées** (`TableInfo[]`). |
| `GET /tables/available?domaine=&search=&limit=&offset=` | Catalogue SAP paginé (interroge le dico de données) : `{ total, results: [...] }`. |
| `GET /tables/compare` | Écart configuration ↔ PostgreSQL : `{ missing: [...], existing: [...], extra: [...] }`. |
| `GET /tables/{table_name}` | Config d'une table (404 si absente). |
| `GET /tables/{table_name}/metadata` | Métadonnées **live** des champs (RFC). |
| `POST /tables/create` | Corps `{ "tables": ["T001", ...] }` → crée les structures PostgreSQL seules (sans données) : `{ results: [...] }`. |

`TableInfo` :
```ts
interface TableInfo {
  name: string;
  description: string;
  primary_keys: string[];
  fields_count: number;
  batch_size: number;
  disabled: boolean;
  alternative_table: string | null;
}
```

### Extraction de données

**`POST /extract`** — lance une extraction. Corps (`ExtractionRequest`) :
```ts
interface ExtractionRequest {
  tables: string[];              // requis, ex: ["LFA1", "T001"]
  batch_size?: number;           // defaut 500 (>=1) — lot de lignes
  field_batch_size?: number;     // defaut 5  (accepte mais gere auto par le moteur)
  row_page_size?: number;        // defaut 5000 (>=100)
  workers?: number;              // defaut 1 (1..16) — execution sequentielle pour l'instant
  truncate_before?: boolean;     // defaut false
  mode?: "standard" | "debug" | "complet";  // defaut "standard"
  options?: Record<string, any>; // optionnel (les champs directs priment)
  user_id?: string | null;       // defaut cote serveur: "demo_user"
}
```
- `mode: "complet"` (ou `options.clean = true`) → **extraction complète** : la table
  est **vidée (TRUNCATE) puis rechargée**. Sinon → extraction **différentielle**
  (depuis la dernière extraction réussie) avec upsert idempotent.
- ⚠️ La valeur de `mode` est validée par regex : seules `standard|debug|complet`
  sont acceptées (pas `complete`).

Réponse (200) :
```ts
interface StartExtractionResponse {
  extraction_id: string;   // = job_id, a utiliser pour le polling
  status: "pending";
  tables: string[];
  persisted_db: boolean;   // true si persiste en base (DATABASE_URL defini)
}
```

**`GET /status/{job_id}`** — statut détaillé (à poller). Réponse :
```ts
interface JobStatus {
  id: string;
  status: "pending" | "running" | "completed" | "completed_with_errors" | "failed" | "cancelled";
  progress: number;              // 0..100 (grain table ; 100 si completed)
  tables: string[];
  tablesDetails: TableDetail[];  // progression live par table
  startedAt: string | null;      // ISO
  completedAt: string | null;    // ISO
  rowsExtracted: number;         // total live, augmente pendant l'extraction
  mode: string;
  batchSize: number;
  error: string | null;
  duration: number | null;       // secondes
  user: string;
  userId: string | null;
  userName: string | null;       // rempli si table users presente
  userEmail: string | null;
  userRole: string | null;
}

interface TableDetail {
  name: string;
  rows: number;                  // lignes committees pour cette table (live)
  startTime: string | null;      // ISO
  endTime: string | null;        // ISO
  status: "pending" | "running" | "completed" | "failed" | "cancelled";
  error: string | null;
}
```

| Méthode & route | Description |
|---|---|
| `GET /jobs?limit=30` | Historique des jobs : `JobStatus[]` (mêmes objets que `/status`). |
| `GET /jobs/{job_id}` | Alias de `GET /status/{job_id}`. |
| `GET /jobs/{job_id}/logs` | `{ "logs": string[] }` — lignes horodatées `"<iso> [LEVEL] message"`. À poller pour un affichage de log live. |
| `POST /jobs/{job_id}/cancel` | Annule le job → `{ message }`. Alias de `POST /stop/{job_id}`. |
| `POST /stop/{job_id}` | Idem cancel. L'annulation est coopérative (prise en compte entre deux lots / deux tables). |

### Extraction de métadonnées (indépendante des données)

À lancer **avant** d'extraire une table jamais vue (le moteur a besoin des types
de colonnes / de la PK). Endpoints symétriques à l'extraction de données :

**`POST /metadata/extract`** — corps (`MetadataExtractionRequest`) :
```ts
interface MetadataExtractionRequest {
  tables: string[];          // requis
  add_to_config?: boolean;   // defaut true — ajoute a table_config.py
  batch_size?: number;       // defaut 50
  force?: boolean;           // defaut false
  find_relations?: boolean;  // defaut true
}
```
Réponse : `{ metadata_job_id: string, status: "pending", tables: string[] }`.

| Méthode & route | Description |
|---|---|
| `GET /metadata/jobs?limit=30` | Liste des jobs métadonnées. |
| `GET /metadata/status/{job_id}` | Statut d'un job métadonnées (clés : `status`, `tables_done`, `errors`, `tablesDetails`…). |
| `GET /metadata/jobs/{job_id}/logs` | `{ "logs": string[] }`. |
| `POST /metadata/jobs/{job_id}/cancel` | Annule → `{ message }`. |

⚠️ Les jobs de **métadonnées** vivent **en mémoire seule** (perdus si l'API
redémarre). Les jobs d'**extraction** sont persistés en base **si** `DATABASE_URL`
est défini côté serveur, sinon eux aussi en mémoire.

---

## Ce que le frontend doit implémenter

1. **Écran « Nouvelle extraction »** : sélection multi-tables (via `GET /tables`),
   choix du mode (`standard`/`complet`), bouton qui appelle `POST /extract` et
   récupère `extraction_id`.
2. **Suivi live** : après lancement, poller `GET /status/{extraction_id}` toutes
   les 1–2 s. Afficher :
   - une **barre de progression** basée sur `progress` (0–100) ;
   - le **nombre de lignes en direct** : `rowsExtracted` global et `tablesDetails[].rows`
     par table (ces valeurs augmentent au fil de l'eau — c'est le retour attendu
     de « progression au fil de l'eau ») ;
   - le statut par table (`tablesDetails[].status`) avec badge.
   Arrêter le polling quand `status` ∈ `completed|completed_with_errors|failed|cancelled`.
3. **Logs live** : optionnellement poller `GET /jobs/{id}/logs` et afficher les lignes.
4. **Annulation** : bouton appelant `POST /jobs/{id}/cancel`.
5. **Historique** : `GET /jobs` pour la liste des runs passés.
6. **Métadonnées** : un écran équivalent branché sur `/metadata/*`.

### Exemple d'appel (fetch)
```ts
// Lancer
const res = await fetch(`${API}/extract`, {
  method: "POST",
  headers: { "Content-Type": "application/json" },
  body: JSON.stringify({ tables: ["LFA1"], mode: "complet" }),
});
const { extraction_id } = await res.json();

// Poller
const poll = setInterval(async () => {
  const s: JobStatus = await (await fetch(`${API}/status/${extraction_id}`)).json();
  updateUI(s); // s.progress, s.rowsExtracted, s.tablesDetails[].rows/status
  if (["completed","completed_with_errors","failed","cancelled"].includes(s.status)) {
    clearInterval(poll);
  }
}, 1500);
```

---

## Limites connues (à prévoir côté UI)

- **Progression fine** : `progress` est au grain table. Pour une jauge intra-table,
  s'appuyer sur `tablesDetails[].rows` (pas de total exposé aujourd'hui côté API).
- **Pas de temps réel poussé** : polling uniquement (pas de WebSocket/SSE).
- **Persistance** : sans `DATABASE_URL`, un redémarrage de l'API perd les jobs en
  cours/historique. Gérer le cas `404` sur `/status/{id}` (job inconnu après restart).
- **Un seul worker** effectif (extraction séquentielle des tables pour l'instant).
```
