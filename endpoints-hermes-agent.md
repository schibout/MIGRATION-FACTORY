# Documentation des endpoints Hermes Agent à intégrer dans une application

Source de référence consultée : documentation officielle Hermes Agent, page API Server : https://hermes-agent.nousresearch.com/docs/user-guide/features/api-server

## 1. Vue d’ensemble

Hermes Agent peut exposer un serveur HTTP compatible OpenAI. Une application peut donc l’utiliser comme backend d’agent IA avec accès aux outils Hermes : terminal, fichiers, recherche web, mémoire, skills, navigateur, génération/analyse d’images selon la configuration active.

URL de base par défaut :

```text
http://localhost:8642
```

URL de base OpenAI-compatible :

```text
http://localhost:8642/v1
```

Authentification : Bearer token obligatoire.

```http
Authorization: Bearer <API_SERVER_KEY>
```

Configuration minimale dans `~/.hermes/.env` :

```env
API_SERVER_ENABLED=true
API_SERVER_KEY=change-me-local-dev
API_SERVER_HOST=127.0.0.1
API_SERVER_PORT=8642
```

Si une application web appelle Hermes directement depuis le navigateur, ajouter une allowlist CORS explicite :

```env
API_SERVER_CORS_ORIGINS=http://localhost:3000,http://127.0.0.1:3000
```

Démarrage :

```bash
hermes gateway
```

## 2. Endpoints principaux OpenAI-compatible

### POST /v1/chat/completions

Endpoint compatible OpenAI Chat Completions.

Usage : envoyer une conversation complète dans `messages`. Ce mode est stateless : le client doit renvoyer l’historique à chaque appel.

Requête :

```http
POST /v1/chat/completions
Authorization: Bearer <API_SERVER_KEY>
Content-Type: application/json
```

Body :

```json
{
  "model": "hermes-agent",
  "messages": [
    {
      "role": "system",
      "content": "Tu es un assistant technique."
    },
    {
      "role": "user",
      "content": "Explique ce projet."
    }
  ],
  "stream": false
}
```

Réponse typique :

```json
{
  "id": "chatcmpl-abc123",
  "object": "chat.completion",
  "created": 1710000000,
  "model": "hermes-agent",
  "choices": [
    {
      "index": 0,
      "message": {
        "role": "assistant",
        "content": "Voici l’explication..."
      },
      "finish_reason": "stop"
    }
  ],
  "usage": {
    "prompt_tokens": 50,
    "completion_tokens": 200,
    "total_tokens": 250
  }
}
```

Streaming : mettre `"stream": true`. Hermes renvoie du SSE avec des chunks compatibles OpenAI, plus des événements `hermes.tool.progress` pour signaler les appels d’outils.

Exemple curl :

```bash
curl http://localhost:8642/v1/chat/completions \
  -H "Authorization: Bearer change-me-local-dev" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "hermes-agent",
    "messages": [{"role": "user", "content": "Bonjour"}],
    "stream": false
  }'
```

#### Entrée image inline

Les messages utilisateur peuvent contenir un tableau de parties `text` et `image_url`. Les URLs HTTP(S) et les `data:image/...` sont supportées.

```json
{
  "model": "hermes-agent",
  "messages": [
    {
      "role": "user",
      "content": [
        {"type": "text", "text": "Que vois-tu dans cette image ?"},
        {
          "type": "image_url",
          "image_url": {
            "url": "https://example.com/image.png",
            "detail": "high"
          }
        }
      ]
    }
  ]
}
```

Limite : les uploads de fichiers (`file`, `input_file`, `file_id`) et les data URLs non-image renvoient `400 unsupported_content_type`.

### POST /v1/responses

Endpoint compatible OpenAI Responses API.

Usage : recommandé pour les conversations multi-tours côté serveur. Hermes peut stocker l’historique et le réutiliser via `previous_response_id` ou `conversation`.

Requête :

```http
POST /v1/responses
Authorization: Bearer <API_SERVER_KEY>
Content-Type: application/json
```

Body simple :

```json
{
  "model": "hermes-agent",
  "input": "Quels fichiers sont dans mon projet ?",
  "instructions": "Tu es un assistant de développement.",
  "store": true
}
```

Réponse typique :

```json
{
  "id": "resp_abc123",
  "object": "response",
  "status": "completed",
  "model": "hermes-agent",
  "output": [
    {
      "type": "message",
      "role": "assistant",
      "content": [
        {
          "type": "output_text",
          "text": "Voici les fichiers..."
        }
      ]
    }
  ],
  "usage": {
    "input_tokens": 50,
    "output_tokens": 200,
    "total_tokens": 250
  }
}
```

Multi-tour avec `previous_response_id` :

```json
{
  "model": "hermes-agent",
  "input": "Maintenant montre-moi le README",
  "previous_response_id": "resp_abc123"
}
```

Conversation nommée :

```json
{
  "model": "hermes-agent",
  "input": "Bonjour",
  "conversation": "mon-projet"
}
```

Puis :

```json
{
  "model": "hermes-agent",
  "input": "Lance les tests",
  "conversation": "mon-projet"
}
```

Hermes chaîne automatiquement avec la dernière réponse de cette conversation.

#### Entrée image inline avec Responses API

```json
{
  "model": "hermes-agent",
  "input": [
    {
      "role": "user",
      "content": [
        {"type": "input_text", "text": "Décris cette capture."},
        {"type": "input_image", "image_url": "data:image/png;base64,iVBORw0K..."}
      ]
    }
  ]
}
```

### GET /v1/responses/{id}

Récupère une réponse stockée.

```http
GET /v1/responses/resp_abc123
Authorization: Bearer <API_SERVER_KEY>
```

### DELETE /v1/responses/{id}

Supprime une réponse stockée.

```http
DELETE /v1/responses/resp_abc123
Authorization: Bearer <API_SERVER_KEY>
```

## 3. Découverte, santé et capacités

### GET /v1/models

Liste le modèle exposé par Hermes. Le nom annoncé est par défaut le nom du profil Hermes, ou `hermes-agent` pour le profil par défaut.

```http
GET /v1/models
Authorization: Bearer <API_SERVER_KEY>
```

Usage : nécessaire pour beaucoup de frontends compatibles OpenAI.

### GET /v1/capabilities

Retourne la surface API supportée par l’instance Hermes.

```http
GET /v1/capabilities
Authorization: Bearer <API_SERVER_KEY>
```

Réponse typique :

```json
{
  "object": "hermes.api_server.capabilities",
  "platform": "hermes-agent",
  "model": "hermes-agent",
  "auth": {
    "type": "bearer",
    "required": true
  },
  "features": {
    "chat_completions": true,
    "responses_api": true,
    "run_submission": true,
    "run_status": true,
    "run_events_sse": true,
    "run_stop": true
  }
}
```

Usage : à appeler au démarrage de votre application pour détecter dynamiquement les fonctionnalités disponibles.

### GET /health

Health check simple.

```http
GET /health
```

Réponse :

```json
{"status": "ok"}
```

### GET /v1/health

Même health check avec préfixe `/v1`, utile pour certains clients OpenAI-compatible.

```http
GET /v1/health
```

### GET /health/detailed

Health check étendu : sessions actives, agents en cours, usage des ressources.

```http
GET /health/detailed
Authorization: Bearer <API_SERVER_KEY>
```

## 4. Runs API : exécution longue avec suivi d’événements

La Runs API est utile si votre application veut lancer une tâche d’agent puis suivre sa progression sans gérer directement le streaming Chat/Responses.

### POST /v1/runs

Crée un run d’agent et renvoie un `run_id`.

```http
POST /v1/runs
Authorization: Bearer <API_SERVER_KEY>
Content-Type: application/json
```

Body possible :

```json
{
  "input": "Analyse ce dépôt et fais un résumé.",
  "session_id": "space-session",
  "instructions": "Réponds en français.",
  "conversation_history": [],
  "previous_response_id": null
}
```

Réponse :

```json
{
  "run_id": "run_abc123",
  "status": "started"
}
```

### GET /v1/runs/{run_id}

Récupère l’état courant du run.

```http
GET /v1/runs/run_abc123
Authorization: Bearer <API_SERVER_KEY>
```

Réponse typique :

```json
{
  "object": "hermes.run",
  "run_id": "run_abc123",
  "status": "completed",
  "session_id": "space-session",
  "model": "hermes-agent",
  "output": "Terminé.",
  "usage": {
    "input_tokens": 50,
    "output_tokens": 200,
    "total_tokens": 250
  }
}
```

Statuts possibles : `started`, `running`, `completed`, `failed`, `cancelled`, `stopping`.

### GET /v1/runs/{run_id}/events

Flux SSE des événements du run : progression des outils, deltas de texte, cycle de vie.

```http
GET /v1/runs/run_abc123/events
Authorization: Bearer <API_SERVER_KEY>
Accept: text/event-stream
```

Usage : recommandé pour dashboards, frontends riches et UI avec reconnexion.

### POST /v1/runs/{run_id}/stop

Demande l’interruption d’un run en cours.

```http
POST /v1/runs/run_abc123/stop
Authorization: Bearer <API_SERVER_KEY>
```

Réponse :

```json
{"status": "stopping"}
```

### POST /v1/runs/{run_id}/approval

Résout une demande d’approbation humaine sur un run en attente.

```http
POST /v1/runs/run_abc123/approval
Authorization: Bearer <API_SERVER_KEY>
Content-Type: application/json
```

Body indicatif :

```json
{
  "approved": true,
  "reason": "Action validée par l’utilisateur"
}
```

À utiliser quand une politique d’approbation bloque un outil ou une action sensible.

## 5. Jobs API : tâches planifiées et background

Ces endpoints permettent de gérer les jobs planifiés Hermes, équivalents à `hermes cron`.

### GET /api/jobs

Liste tous les jobs planifiés.

```http
GET /api/jobs
Authorization: Bearer <API_SERVER_KEY>
```

### POST /api/jobs

Crée un job planifié.

```http
POST /api/jobs
Authorization: Bearer <API_SERVER_KEY>
Content-Type: application/json
```

Body indicatif :

```json
{
  "name": "Brief quotidien",
  "schedule": "0 9 * * *",
  "prompt": "Prépare un brief quotidien en français.",
  "skills": [],
  "deliver": "origin"
}
```

Champs possibles : `prompt`, `schedule`, `skills`, override provider/model, cible de livraison.

### GET /api/jobs/{job_id}

Récupère la définition et le dernier état d’exécution d’un job.

```http
GET /api/jobs/job_123
Authorization: Bearer <API_SERVER_KEY>
```

### PATCH /api/jobs/{job_id}

Met à jour partiellement un job.

```http
PATCH /api/jobs/job_123
Authorization: Bearer <API_SERVER_KEY>
Content-Type: application/json
```

Body indicatif :

```json
{
  "schedule": "every 2h",
  "prompt": "Nouveau prompt du job"
}
```

### DELETE /api/jobs/{job_id}

Supprime un job et annule toute exécution en cours.

```http
DELETE /api/jobs/job_123
Authorization: Bearer <API_SERVER_KEY>
```

### POST /api/jobs/{job_id}/pause

Met un job en pause.

```http
POST /api/jobs/job_123/pause
Authorization: Bearer <API_SERVER_KEY>
```

### POST /api/jobs/{job_id}/resume

Reprend un job en pause.

```http
POST /api/jobs/job_123/resume
Authorization: Bearer <API_SERVER_KEY>
```

### POST /api/jobs/{job_id}/run

Déclenche immédiatement le job hors planning.

```http
POST /api/jobs/job_123/run
Authorization: Bearer <API_SERVER_KEY>
```

## 6. Sessions API : contrôle des sessions REST

Tous les endpoints sont sous `/api/sessions/*` et protégés par `API_SERVER_KEY`.

### GET /api/sessions

Liste les sessions.

```http
GET /api/sessions?limit=20&offset=0&source=api_server&include_children=false
Authorization: Bearer <API_SERVER_KEY>
```

Paramètres :

```text
limit             Nombre de sessions à retourner
offset            Pagination
source            Filtre par source
include_children  Inclure les sessions enfants/forks
```

### POST /api/sessions

Crée une session vide.

```http
POST /api/sessions
Authorization: Bearer <API_SERVER_KEY>
Content-Type: application/json
```

Body indicatif :

```json
{
  "title": "Nouvelle session application"
}
```

### GET /api/sessions/{id}

Lit les métadonnées d’une session.

```http
GET /api/sessions/session_123
Authorization: Bearer <API_SERVER_KEY>
```

### PATCH /api/sessions/{id}

Met à jour le titre ou `end_reason`.

```http
PATCH /api/sessions/session_123
Authorization: Bearer <API_SERVER_KEY>
Content-Type: application/json
```

Body indicatif :

```json
{
  "title": "Titre mis à jour",
  "end_reason": "completed"
}
```

### DELETE /api/sessions/{id}

Supprime une session.

```http
DELETE /api/sessions/session_123
Authorization: Bearer <API_SERVER_KEY>
```

### GET /api/sessions/{id}/messages

Récupère l’historique des messages d’une session.

```http
GET /api/sessions/session_123/messages
Authorization: Bearer <API_SERVER_KEY>
```

### POST /api/sessions/{id}/fork

Branche/fork une session, équivalent à `/branch` côté CLI/gateway.

```http
POST /api/sessions/session_123/fork
Authorization: Bearer <API_SERVER_KEY>
Content-Type: application/json
```

Body indicatif :

```json
{
  "title": "exploration alternative"
}
```

### POST /api/sessions/{id}/chat

Lance un tour d’agent synchrone dans une session.

```http
POST /api/sessions/session_123/chat
Authorization: Bearer <API_SERVER_KEY>
Content-Type: application/json
```

Body indicatif :

```json
{
  "input": "Que contient ce projet ?"
}
```

### POST /api/sessions/{id}/chat/stream

Lance un tour d’agent en SSE dans une session.

```http
POST /api/sessions/session_123/chat/stream
Authorization: Bearer <API_SERVER_KEY>
Content-Type: application/json
Accept: text/event-stream
```

Body indicatif :

```json
{
  "input": "Quels fichiers ont changé dans la dernière heure ?"
}
```

Événements SSE annoncés :

```text
assistant.delta
tool.started
tool.completed
run.completed
```

Les payloads `chat` et `chat/stream` supportent les images inline si l’instance Hermes est multimodale.

## 7. Découverte des skills et toolsets

### GET /v1/skills

Liste les skills disponibles avec leurs métadonnées.

```http
GET /v1/skills
Authorization: Bearer <API_SERVER_KEY>
```

Réponse typique :

```json
[
  {
    "name": "github-pr-workflow",
    "description": "Workflow GitHub PR...",
    "category": "github"
  }
]
```

### GET /v1/toolsets

Liste les toolsets résolus pour la plateforme `api_server`, avec les outils concrets inclus.

```http
GET /v1/toolsets
Authorization: Bearer <API_SERVER_KEY>
```

Réponse typique :

```json
[
  {
    "name": "core",
    "label": "Core",
    "description": "Outils principaux",
    "enabled": true,
    "configured": true,
    "tools": ["read_file", "write_file", "terminal"]
  }
]
```

## 8. Headers utiles

### Authorization

Obligatoire sur les endpoints protégés.

```http
Authorization: Bearer <API_SERVER_KEY>
```

### X-Hermes-Session-Id

Identifiant de transcript/session côté client.

```http
X-Hermes-Session-Id: transcript-alpha
```

### X-Hermes-Session-Key

Clé stable de mémoire long terme pour les frontends multi-utilisateurs.

```http
X-Hermes-Session-Key: agent:main:webui:dm:user-42
```

Règles : maximum 256 caractères, pas de caractères de contrôle (`\r`, `\n`, `\x00`). La valeur est renvoyée dans les réponses JSON et SSE.

### Idempotency-Key

Header autorisé quand CORS est activé. Hermes peut mettre en cache les réponses par clé pendant 5 minutes pour éviter les doublons.

```http
Idempotency-Key: request-unique-id-123
```

## 9. Variables d’environnement

```text
API_SERVER_ENABLED       false par défaut ; active le serveur API
API_SERVER_PORT          8642 par défaut
API_SERVER_HOST          127.0.0.1 par défaut
API_SERVER_KEY           obligatoire ; token Bearer
API_SERVER_CORS_ORIGINS  vide par défaut ; allowlist CORS explicite
API_SERVER_MODEL_NAME    nom de modèle exposé dans /v1/models ; par défaut nom du profil ou hermes-agent
```

Important : selon la documentation actuelle, ces réglages se font par variables d’environnement dans `.env`, pas encore via `config.yaml`.

## 10. Sécurité

Le serveur API donne accès à l’agent Hermes et donc potentiellement à ses outils, y compris le terminal et les fichiers selon les toolsets activés.

Recommandations :

1. Garder `API_SERVER_KEY` secret et différent par environnement.
2. Laisser `API_SERVER_HOST=127.0.0.1` si l’accès externe n’est pas nécessaire.
3. Si exposition réseau obligatoire, mettre derrière un reverse proxy HTTPS avec authentification supplémentaire.
4. Limiter strictement `API_SERVER_CORS_ORIGINS`.
5. Utiliser des profils Hermes séparés pour isoler les utilisateurs.
6. Ne pas exposer publiquement une instance avec terminal/fichiers activés sans contrôle d’accès fort.

## 11. Exemple minimal d’intégration JavaScript

```js
const API_BASE = "http://localhost:8642/v1";
const API_KEY = "change-me-local-dev";

async function askHermes(message) {
  const res = await fetch(`${API_BASE}/chat/completions`, {
    method: "POST",
    headers: {
      "Authorization": `Bearer ${API_KEY}`,
      "Content-Type": "application/json"
    },
    body: JSON.stringify({
      model: "hermes-agent",
      messages: [{ role: "user", content: message }],
      stream: false
    })
  });

  if (!res.ok) {
    throw new Error(`Hermes API error ${res.status}: ${await res.text()}`);
  }

  const data = await res.json();
  return data.choices[0].message.content;
}
```

## 12. Exemple minimal d’intégration Python

```python
from openai import OpenAI

client = OpenAI(
    base_url="http://localhost:8642/v1",
    api_key="change-me-local-dev",
)

response = client.chat.completions.create(
    model="hermes-agent",
    messages=[{"role": "user", "content": "Bonjour Hermes"}],
)

print(response.choices[0].message.content)
```

## 13. Résumé rapide de tous les endpoints

```text
POST   /v1/chat/completions
POST   /v1/responses
GET    /v1/responses/{id}
DELETE /v1/responses/{id}
GET    /v1/models
GET    /v1/capabilities
GET    /health
GET    /v1/health
GET    /health/detailed

POST   /v1/runs
GET    /v1/runs/{run_id}
GET    /v1/runs/{run_id}/events
POST   /v1/runs/{run_id}/stop
POST   /v1/runs/{run_id}/approval

GET    /api/jobs
POST   /api/jobs
GET    /api/jobs/{job_id}
PATCH  /api/jobs/{job_id}
DELETE /api/jobs/{job_id}
POST   /api/jobs/{job_id}/pause
POST   /api/jobs/{job_id}/resume
POST   /api/jobs/{job_id}/run

GET    /api/sessions
POST   /api/sessions
GET    /api/sessions/{id}
PATCH  /api/sessions/{id}
DELETE /api/sessions/{id}
GET    /api/sessions/{id}/messages
POST   /api/sessions/{id}/fork
POST   /api/sessions/{id}/chat
POST   /api/sessions/{id}/chat/stream

GET    /v1/skills
GET    /v1/toolsets
```
