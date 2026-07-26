# Assistant IA — Installation & Exploitation

Chatbot interne connecté à PostgreSQL : pose des questions en français,
génère une requête SQL **en lecture seule** via un modèle local (Ollama),
l'exécute et affiche les résultats. Aucune donnée ne sort de la VM.

- Backend : Blueprint Flask `/api/v1/ai` ([backend/api/ai_assistant.py](backend/api/ai_assistant.py))
- Frontend : page [frontend/src/pages/AssistantIA.tsx](frontend/src/pages/AssistantIA.tsx) (menu « Assistant IA »)
- Modèle : `qwen2.5-coder:7b` servi par Ollama sur `127.0.0.1:11434`

## Architecture

```
React (AssistantIA.tsx)
   │  POST /api/v1/ai/ask  { question }
   ▼
Flask  ── ollama_service ──► Ollama (génère un JSON {sql, explication})
   │
   ├── sql_guard ............ valide : SELECT/WITH only, anti-injection, borne LIMIT
   ├── ai_readonly_db ....... exécute via le rôle PostgreSQL readonly_ai (SELECT seul)
   └── ai_query_log ......... journalise chaque question (succès / erreur / rejet)
```

Double rempart de sécurité : **sql_guard** (analyse `sqlparse`) + le rôle
**readonly_ai** qui n'a que le droit `SELECT` (et un `statement_timeout` de 30 s).

## 1. Installation d'Ollama (sur la VM)

Voir [install_IA.sh](install_IA.sh). En résumé :

```bash
curl -fsSL https://ollama.com/install.sh | sh
ollama pull qwen2.5-coder:7b          # ≈ 4,7 Go
```

⚠️ **Ne jamais exposer le port 11434 hors de la VM.** Ollama doit écouter sur
`127.0.0.1` uniquement (ou l'interface interne) et aucune règle firewall ne doit
ouvrir 11434 vers l'extérieur. Le `override.conf` du script positionne
`OLLAMA_HOST` — adaptez-le à `127.0.0.1:11434` si le backend tourne sur la même VM.

## 2. Création du rôle PostgreSQL et du journal

Éditer [migrations/012_create_ai_assistant.sql](migrations/012_create_ai_assistant.sql)
pour remplacer `CHANGE_ME` par le mot de passe réel (= `AI_DB_PASSWORD`), puis :

```bash
psql -h 10.190.100.58 -U postgres -d sap_migration_db -f migrations/012_create_ai_assistant.sql
```

Ce script crée :
- le rôle `readonly_ai` : `SELECT` sur `raw_data` et `clean_data`, aucun droit
  sur `public`, `statement_timeout = 30s`, `CONNECTION LIMIT 3` ;
- la table `public.ai_query_log` (journal des questions).

## 3. Variables d'environnement

À ajouter dans `backend/.env` (voir [backend/.env.example](backend/.env.example)) :

| Variable | Défaut | Rôle |
|---|---|---|
| `OLLAMA_URL` | `http://localhost:11434` | URL du service Ollama |
| `OLLAMA_MODEL` | `qwen2.5-coder:7b` | Modèle utilisé |
| `AI_DB_USER` | `readonly_ai` | Rôle PostgreSQL lecture seule |
| `AI_DB_PASSWORD` | — | Mot de passe du rôle (= migration 012) |
| `AI_MAX_ROWS` | `500` | Lignes max affichées dans l'UI |
| `AI_EXPORT_MAX_ROWS` | `50000` | Lignes max pour l'export Excel |
| `AI_TIMEOUT_SECONDS` | `120` | Timeout d'appel au modèle |

Installer la dépendance ajoutée : `pip install -r backend/requirements.txt`
(ajoute `sqlparse`).

## 4. Lancement

```bash
# Backend (le blueprint /api/v1/ai est enregistré automatiquement)
cd backend && python app.py            # ou gunicorn -w 4 -b 0.0.0.0:5000 app:app

# Frontend
cd frontend && npm run dev
```

Ouvrir l'application → menu **Assistant IA**.

## 5. Endpoints

| Méthode | Route | Description |
|---|---|---|
| POST | `/api/v1/ai/ask` | question → SQL → résultats |
| POST | `/api/v1/ai/export` | `{id_log}` → fichier Excel |
| GET | `/api/v1/ai/templates` | analyses pré-définies |
| POST | `/api/v1/ai/templates/<id>/run` | exécute une analyse pré-définie |
| GET | `/api/v1/ai/history?page=&par_utilisateur=` | historique |
| GET | `/api/v1/ai/health` | statut Ollama + modèle |

Toutes les routes exigent un JWT valide.

## 6. Tests

```bash
cd backend && pytest tests/test_sql_guard.py tests/test_ollama_service.py -v
```

## 7. Vérifications post-déploiement

```bash
# Le rôle readonly_ai ne peut pas écrire
psql -h 10.190.100.58 -U readonly_ai -d sap_migration_db \
  -c "DELETE FROM raw_data.lfa1 WHERE 1=0;"   # attendu : permission denied

# Le rôle ne voit pas le schéma public
psql -h 10.190.100.58 -U readonly_ai -d sap_migration_db \
  -c "SELECT * FROM public.users LIMIT 1;"    # attendu : permission denied

# L'API rejette les requêtes dangereuses (TOKEN = JWT valide)
curl -X POST http://localhost:5000/api/v1/ai/ask \
  -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" \
  -d '{"question": "supprime tous les fournisseurs"}'
# attendu : statut "rejete"

# Santé Ollama
curl -H "Authorization: Bearer $TOKEN" http://localhost:5000/api/v1/ai/health
```
