# SAP Extraction API — Documentation

**Base URL** : `http://10.190.100.58:8000`  
**Swagger UI** : `http://10.190.100.58:8000/docs`  
**Version** : 2.1.0

## Architecture

```
React (:3000) → Flask (:5000) → SAP API (:8000) → fast_extract.py → PostgreSQL
   frontend       backend         sap-extraction
```

Le frontend appelle le backend Flask (`POST /api/v1/extraction/start`) qui appelle
automatiquement l'API SAP. Pas besoin d'appeler directement depuis le frontend.

---

## Demarrage

```bash
# Dans le conteneur sap-extraction
uvicorn api_simple:app --host 0.0.0.0 --port 8000

# Ou en arriere-plan
nohup uvicorn api_simple:app --host 0.0.0.0 --port 8000 >> /app/logs/api_simple.log 2>&1 &
```

Au redemarrage du conteneur, l'API demarre automatiquement via `start.sh`.

---

## Endpoints

### 1. Health Check

```
GET /health
```

```bash
curl http://10.190.100.58:8000/health
```

**Reponse :**

```json
{
  "status": "healthy",
  "timestamp": "2026-05-07T16:00:00.000000",
  "active_jobs": 0
}
```

---

### 2. Liste des tables disponibles

```
GET /tables
```

```bash
curl http://10.190.100.58:8000/tables
```

**Reponse :**

```json
[
  { "name": "T001",  "description": "Societes",               "disabled": false },
  { "name": "IFLOT", "description": "Postes techniques",      "disabled": false },
  { "name": "IFLO",  "description": "Vue composite (IFLO)",   "disabled": false }
]
```

---

### 3. Lancer une extraction

```
POST /extract
```

```bash
curl -X POST http://10.190.100.58:8000/extract \
  -H "Content-Type: application/json" \
  -d '{
    "tables": ["T001", "IFLOT", "EQUI"],
    "options": {
      "batch_size": 500,
      "mode": "standard",
      "workers": 4,
      "page_size": 5000,
      "clean": false
    }
  }'
```

#### Parametres du body

| Champ              | Type       | Defaut       | Description                          |
|--------------------|------------|--------------|--------------------------------------|
| `tables`           | `string[]` | **requis**   | Liste des tables SAP a extraire      |
| `options.batch_size` | `int`    | `500`        | Taille de lot                        |
| `options.mode`     | `string`   | `"standard"` | `standard`, `debug` ou `complete`    |
| `options.workers`  | `int`      | `4`          | Nb de connexions SAP paralleles      |
| `options.page_size`| `int`      | `5000`       | Lignes par page RFC                  |
| `options.clean`    | `bool`     | `false`      | TRUNCATE les tables avant extraction |

#### Modes d'extraction

| Mode       | Description                              |
|------------|------------------------------------------|
| `standard` | Extraction des donnees de base           |
| `debug`    | Inclut les logs detailles (LOGURU=DEBUG) |
| `complete` | Toutes les donnees et relations          |

**Reponse (202) :**

```json
{
  "extraction_id": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
  "status": "pending",
  "tables": ["T001", "IFLOT", "EQUI"]
}
```

---

### 4. Statut d'une extraction

```
GET /status/{job_id}
```

```bash
curl http://10.190.100.58:8000/status/a1b2c3d4-e5f6-7890-abcd-ef1234567890
```

**Reponse :**

```json
{
  "id": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
  "status": "running",
  "progress": 33,
  "tables": ["T001", "IFLOT", "EQUI"],
  "tablesDetails": [
    {
      "name": "T001",
      "status": "completed",
      "rows": 42,
      "startTime": "2026-05-07T16:01:00",
      "endTime": "2026-05-07T16:01:05"
    },
    {
      "name": "IFLOT",
      "status": "running",
      "rows": 0,
      "startTime": "2026-05-07T16:01:05",
      "endTime": null
    },
    {
      "name": "EQUI",
      "status": "pending",
      "rows": 0,
      "startTime": null,
      "endTime": null
    }
  ],
  "startedAt": "2026-05-07T16:01:00",
  "completedAt": null,
  "rowsExtracted": 42,
  "mode": "standard",
  "batchSize": 500,
  "duration": null,
  "error": null
}
```

#### Statuts possibles

| Statut      | Description        |
|-------------|--------------------|
| `pending`   | En attente         |
| `running`   | En cours           |
| `completed` | Termine avec succes|
| `failed`    | Erreur             |
| `cancelled` | Annule par l'user  |

---

### 5. Liste de tous les jobs

```
GET /jobs?limit=30
```

```bash
curl http://10.190.100.58:8000/jobs?limit=10
```

**Reponse :** tableau d'objets au meme format que `GET /status/{job_id}`.

---

### 6. Arreter une extraction

```
POST /stop/{job_id}
```

```bash
curl -X POST http://10.190.100.58:8000/stop/a1b2c3d4-e5f6-7890-abcd-ef1234567890
```

**Reponse :**

```json
{
  "message": "Job a1b2c3d4-e5f6-7890-abcd-ef1234567890 annule"
}
```

> Le thread en cours finira le batch SAP actuel avant de s'arreter.

---

### 7. Extraction des metadonnees SAP

Equivalent HTTP de `python -m sap_extraction.main_metadata --tables ...`.
Extrait la structure des tables SAP (via `DDIF_FIELDINFO_GET`) et charge les
metadonnees dans PostgreSQL (`sap_table_fields`, `sap_table_properties`).
S'execute en **job de fond** : on recupere un `metadata_job_id` a suivre.

#### 7.1 Lancer l'extraction de metadonnees

```
POST /metadata/extract
```

```bash
curl -X POST http://10.190.100.58:8000/metadata/extract \
  -H "Content-Type: application/json" \
  -d '{
    "tables": ["T005", "EKKO"],
    "add_to_config": true,
    "batch_size": 50,
    "force": false,
    "find_relations": true
  }'
```

##### Parametres du body

| Champ            | Type       | Defaut     | Description                                                                 |
|------------------|------------|------------|----------------------------------------------------------------------------|
| `tables`         | `string[]` | **requis** | Liste des tables SAP dont extraire les metadonnees                         |
| `add_to_config`  | `bool`     | `true`     | Ajoute la table a `table_config.py` **et** cree la table dans `raw_data`   |
| `batch_size`     | `int`      | `50`       | Taille de lot ecrite dans la config (utilise seulement si `add_to_config`) |
| `force`          | `bool`     | `false`    | Remplace la config existante si la table y figure deja                     |
| `find_relations` | `bool`     | `true`     | Recherche les relations (via `check_table`) et les ecrit dans la config    |

> ⚠️ **`add_to_config` (defaut `true`)** ecrit dans le fichier source
> `table_config.py` **a l'interieur du conteneur**. Pour que l'ajout survive a
> un redemarrage, monter `config/table_config.py` en volume. Passer
> `"add_to_config": false` pour ne charger que les metadonnees dans PostgreSQL.

##### Correspondance avec le CLI

| Flag CLI            | Champ JSON                |
|---------------------|---------------------------|
| `--tables T005 EKKO`| `"tables": ["T005","EKKO"]` |
| `--add-to-config`   | `"add_to_config": true`   |
| `--batch-size 50`   | `"batch_size": 50`        |
| `--force`           | `"force": true`           |
| `--no-relations`    | `"find_relations": false` |

**Reponse (202) :**

```json
{
  "metadata_job_id": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
  "status": "pending",
  "tables": ["T005", "EKKO"],
  "add_to_config": true
}
```

#### 7.2 Statut d'un job de metadonnees

```
GET /metadata/status/{job_id}
```

```bash
curl http://10.190.100.58:8000/metadata/status/a1b2c3d4-e5f6-7890-abcd-ef1234567890
```

**Reponse :**

```json
{
  "id": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
  "status": "completed",
  "progress": 100,
  "tables": ["T005", "EKKO"],
  "addToConfig": true,
  "tablesDone": 2,
  "errors": 0,
  "tablesDetails": [
    { "name": "T005", "status": "completed", "fields_count": 12, "added_to_config": true },
    { "name": "EKKO", "status": "completed", "fields_count": 187, "added_to_config": true }
  ],
  "startedAt": "2026-07-08T16:01:00",
  "completedAt": "2026-07-08T16:01:14",
  "duration": 14.3,
  "error": null
}
```

##### Statuts possibles

| Statut                  | Description                                   |
|-------------------------|-----------------------------------------------|
| `pending`               | En attente                                    |
| `running`               | En cours                                      |
| `completed`             | Termine, toutes les tables OK                 |
| `completed_with_errors` | Termine mais au moins une table en erreur     |
| `failed`                | Erreur fatale (connexion SAP/PG indisponible) |
| `cancelled`             | Annule par l'utilisateur                      |

#### 7.3 Liste des jobs de metadonnees

```
GET /metadata/jobs?limit=30
```

**Reponse :** tableau d'objets au meme format que `GET /metadata/status/{job_id}`.

#### 7.4 Logs d'un job de metadonnees

```
GET /metadata/jobs/{job_id}/logs
```

**Reponse :**

```json
{
  "job_id": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
  "count": 4,
  "logs": [
    "2026-07-08T16:01:00 [INFO] Extraction metadonnees T005",
    "2026-07-08T16:01:03 [INFO] T005 termine — 12 champ(s)"
  ]
}
```

#### 7.5 Annuler un job de metadonnees

```
POST /metadata/jobs/{job_id}/cancel
```

```bash
curl -X POST http://10.190.100.58:8000/metadata/jobs/a1b2c3d4-.../cancel
```

> L'arret est effectif **entre deux tables** : un appel RFC en cours n'est pas interrompu.

---

## Exemples d'utilisation

### Extraire une seule table

```bash
curl -X POST http://10.190.100.58:8000/extract \
  -H "Content-Type: application/json" \
  -d '{"tables": ["T001"]}'
```

### Extraire toutes les tables de maintenance avec clean

```bash
curl -X POST http://10.190.100.58:8000/extract \
  -H "Content-Type: application/json" \
  -d '{
    "tables": ["IFLOT","IFLOTX","ILOA","IHPA","EQUI","EQKT","EQUZ","ITOB","IFLO"],
    "options": {"clean": true, "workers": 6}
  }'
```

### Extraire les metadonnees d'une nouvelle table (et l'ajouter a la config)

```bash
curl -X POST http://10.190.100.58:8000/metadata/extract \
  -H "Content-Type: application/json" \
  -d '{"tables": ["T005", "EKKO"]}'
# add_to_config vaut true par defaut → la table est ajoutee a table_config.py
# et creee dans raw_data
```

### Charger uniquement les metadonnees (sans toucher a la config)

```bash
curl -X POST http://10.190.100.58:8000/metadata/extract \
  -H "Content-Type: application/json" \
  -d '{"tables": ["T005"], "add_to_config": false}'
```

### Polling du statut (script bash)

```bash
JOB_ID="a1b2c3d4-..."
while true; do
  STATUS=$(curl -s http://10.190.100.58:8000/status/$JOB_ID | python3 -c "import sys,json; print(json.load(sys.stdin)['status'])")
  echo "Statut: $STATUS"
  [ "$STATUS" = "completed" ] || [ "$STATUS" = "failed" ] && break
  sleep 5
done
```

---

## Configuration

| Variable d'environnement    | Defaut                        | Description                        |
|-----------------------------|-------------------------------|------------------------------------|
| `SAP_EXTRACTION_API_URL`    | `http://10.190.100.58:8000`   | URL de l'API (cote backend Flask)  |
| `SAP_API_TIMEOUT`           | `10`                          | Timeout HTTP en secondes           |

Ces variables sont configurees dans :
- `migration-Factory/backend/.env`
- `migration-Factory/docker-compose.yml`

---

## Logs

Les logs de l'API sont ecrits dans `/app/logs/api_simple.log` dans le conteneur `sap-extraction`.

```bash
docker exec sap-extraction tail -f /app/logs/api_simple.log
```
