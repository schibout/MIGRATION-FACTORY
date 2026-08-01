# Intégrer l'agent Hermes dans une application — Guide de référence

Ce document décrit **comment Hermes est installé** sur le serveur et **comment
Migration Factory s'y connecte**, afin de servir de modèle pour intégrer Hermes
dans une autre application. L'implémentation de référence vit dans ce repo :

| Rôle | Fichier |
|---|---|
| Proxy backend (Flask) | `backend/api/hermes.py` |
| Client frontend (fetch + SSE) | `frontend/src/services/hermesService.ts` |
| Page de chat | `frontend/src/pages/HermesChat.tsx` |
| Doc complète des endpoints Hermes | `endpoints-hermes-agent.md` |

---

## 1. Qu'est-ce que Hermes ?

**Hermes** (Nous Research) est un agent IA autonome avec accès à des outils
(terminal, fichiers, recherche web, mémoire, skills…). Il peut exposer un
**serveur HTTP compatible OpenAI** : n'importe quelle application sachant parler
à l'API OpenAI (`/v1/chat/completions`) peut donc l'utiliser comme backend
d'agent, sans SDK spécifique.

Doc officielle : https://hermes-agent.nousresearch.com/docs/user-guide/features/api-server

---

## 2. Installation et activation côté serveur

### 2.1 Où tourne Hermes

Hermes tourne sur le serveur `10.190.100.58`, dans un conteneur Docker nommé
**`hermes`**, en `network_mode: host`. Son API écoute sur le **port 8642**.

### 2.2 Activer le serveur API

Le serveur API de Hermes est **désactivé par défaut**. Il s'active par
variables d'environnement dans le fichier `.env` de Hermes — dans notre
installation Docker, c'est **`/opt/data/.env` à l'intérieur du conteneur**
(installation native : `~/.hermes/.env`) :

```env
API_SERVER_ENABLED=true
API_SERVER_KEY=<clé secrète forte>      # OBLIGATOIRE — token Bearer
API_SERVER_HOST=0.0.0.0                 # 127.0.0.1 par défaut ; 0.0.0.0 pour être joignable par une autre app
API_SERVER_PORT=8642                    # défaut
```

Vérifier / appliquer :

```bash
docker exec hermes sh -c 'cat /opt/data/.env'   # vérifier la config
docker restart hermes                            # redémarrer après modification
```

Test de bon fonctionnement :

```bash
curl -H "Authorization: Bearer $API_SERVER_KEY" http://10.190.100.58:8642/v1/models
# → HTTP 200 avec le modèle "hermes-agent"
```

### 2.3 ⚠️ Sécurité de la clé

`API_SERVER_KEY` donne accès au **toolset complet de Hermes, terminal inclus**.
Règles absolues :

- La clé ne doit **jamais** atteindre un navigateur ni un bundle frontend.
- Ne pas exposer le port 8642 sur Internet (ici : réseau interne uniquement).
- Une clé différente par environnement ; rotation possible sans redémarrage de
  l'app (cf. §4.2).

---

## 3. Architecture de connexion : le pattern proxy

L'application ne laisse **jamais** le frontend parler directement à Hermes.
Tout passe par un **proxy backend** qui détient la clé et impose
l'authentification existante de l'application (JWT) :

```
Navigateur (JWT app)               Backend (proxy)                    Agent Hermes
page de chat  ── fetch SSE ──►  POST /api/v1/hermes/chat  ──►  POST http://10.190.100.58:8642/v1/chat/completions
client SSE    ◄─ relay SSE ──   (jwt_required, clé côté serveur)   (Authorization: Bearer HERMES_API_KEY)
```

Pourquoi ce pattern (à reproduire dans toute nouvelle application) :

1. **La clé reste côté serveur** — le navigateur n'envoie que son JWT applicatif.
2. **Contrôle d'accès** — mêmes décorateurs/middleware d'auth que le reste de l'app.
3. **Pas de CORS à ouvrir sur Hermes** — seul le backend l'appelle.
4. **Gestion d'erreurs uniforme** — le proxy traduit les pannes Hermes en codes
   HTTP clairs pour le frontend (voir §5.3).

---

## 4. Côté backend : le proxy en détail

### 4.1 Appel de l'API Hermes

L'API est OpenAI-compatible. Requête type (celle qu'envoie `backend/api/hermes.py`) :

```http
POST http://10.190.100.58:8642/v1/chat/completions
Authorization: Bearer <HERMES_API_KEY>
Content-Type: application/json

{
  "model": "hermes-agent",                     // champ cosmétique côté Hermes
  "messages": [
    {"role": "system", "content": "<instructions utilisateur>"},   // optionnel, en tête
    {"role": "user", "content": "Bonjour"}
  ],
  "stream": true
}
```

Points clés :

- **Stateless** : Hermes ne garde pas l'historique en mode chat/completions —
  le client renvoie **toute la conversation** à chaque requête.
- **Instructions système** : la consigne persistante de l'utilisateur est
  injectée comme unique message `{"role":"system"}` en tête du tableau
  (tout autre message system reçu du front est retiré — une seule source de consigne).
- **Streaming SSE** : chunks standard `chat.completion.chunk`
  (`choices[0].delta.content`), un event custom `hermes.tool.progress`
  (« Hermes utilise un outil… »), et un `data: [DONE]` final.

### 4.2 Configuration de l'application

Trois clés, lues dynamiquement (**DB `system_config` > variable d'environnement > défaut**),
donc modifiables sans redémarrage :

| Clé | Défaut | Rôle |
|---|---|---|
| `HERMES_API_URL` | `http://10.190.100.58:8642/v1` | Base URL OpenAI-compatible de Hermes |
| `HERMES_API_KEY` | *(vide — obligatoire)* | La `API_SERVER_KEY` du serveur Hermes |
| `HERMES_TIMEOUT_SECONDS` | `300` | **Silence max entre deux chunks** du stream (read timeout), pas la durée totale |

### 4.3 Relais du flux SSE

Le proxy relaie les octets SSE **tels quels** (framing `event:`/`data:`
préservé, aucun re-parsing serveur) — voir `relay()` dans `backend/api/hermes.py` :

- `requests.post(..., stream=True, timeout=(10, read_timeout))` vers Hermes ;
- réponse Flask `text/event-stream` avec `stream_with_context` ;
- headers `Cache-Control: no-cache` et **`X-Accel-Buffering: no`** (indispensable
  si un nginx avec `proxy_buffering on` est devant le backend — sinon les tokens
  arrivent par gros paquets) ;
- coupure **en cours** de stream (le 200 est déjà parti) → émettre un
  `data: {"error": "..."}` que le frontend sait afficher ;
- `finally: upstream.close()` couvre aussi la fermeture d'onglet (`GeneratorExit`).

### 4.4 Serveur WSGI : attention aux workers sync

Un stream SSE occupe un worker pendant toute sa durée. Avec gunicorn, passer en
workers threadés (cf. `backend/start.sh`) :

```bash
gunicorn -w 4 --worker-class gthread --threads 8 -b 0.0.0.0:5000 app:app
```

### 4.5 Gestion d'erreurs (contrat proxy → frontend)

| Situation | Code renvoyé au frontend |
|---|---|
| `messages` absent/vide/malformé | **400** |
| `HERMES_API_KEY` non configurée | **500** explicite (erreur de config, pas d'appel) |
| Hermes injoignable (éteint, réseau) | **502** |
| Hermes répond 401/403 (mauvaise clé) | **502** « Authentification refusée » |
| Timeout (aucun chunk pendant `HERMES_TIMEOUT_SECONDS`) | **504** |
| Sans JWT applicatif | **401** (auth de l'app) |

---

## 5. Côté frontend : consommer le stream

Voir `frontend/src/services/hermesService.ts` (fonction `streamChat`). Les
bibliothèques HTTP classiques (axios) ne savent pas consommer un flux : utiliser
**`fetch` + `ReadableStream`** avec un parseur SSE maison :

1. `fetch('/api/v1/hermes/chat', {method:'POST', headers:{Authorization: Bearer <JWT app>}, body:{messages, instructions, stream:true}})` ;
2. lire `res.body.getReader()` + `TextDecoder`, **bufferiser les lignes
   incomplètes** entre deux chunks réseau ;
3. ligne vide = fin d'un event SSE → dispatcher :
   - `data: [DONE]` → fin de flux ;
   - `event: hermes.tool.progress` (ou `parsed.object === 'hermes.tool.progress'`)
     → indicateur « Hermes utilise un outil… » ;
   - `data: {"error": "..."}` → erreur relayée mi-stream par le proxy ;
   - sinon chunk standard : accumuler `choices[0].delta.content` ;
4. gérer le 401 (refresh du JWT applicatif puis un seul retry) et l'`AbortSignal`
   (bouton « stop »).

**Historique multi-tour** : l'API étant stateless, le frontend renvoie tout
l'historique à chaque message. La persistance des conversations est faite côté
application (ici : tables `public.hermes_conversations` / `hermes_messages`,
routes `/api/v1/hermes/conversations*`) — Hermes n'en sait rien.

---

## 6. Spécification complète des appels API vers Hermes

Référence : documentation officielle Hermes Agent, page API Server
(https://hermes-agent.nousresearch.com/docs/user-guide/features/api-server).

### 6.1 Conventions générales

- **URL de base** (notre installation) : `http://10.190.100.58:8642`
- **Base OpenAI-compatible** : `http://10.190.100.58:8642/v1`
- **Authentification** : Bearer token **obligatoire** sur tous les endpoints
  protégés :

  ```http
  Authorization: Bearer <API_SERVER_KEY>
  ```

- **Deux préfixes distincts** :
  - `/v1/...` → surface OpenAI-compatible (chat, responses, runs, models,
    capabilities, skills, toolsets) ;
  - `/api/...` → surface propre à Hermes (jobs, sessions), **HORS `/v1`**
    (d'où le calcul d'origine dans `_hermes_origin()` de `backend/api/hermes.py`).
- **Content-Type** : `application/json` sur tous les POST/PATCH.
- Le champ `"model": "hermes-agent"` est **cosmétique** : Hermes n'en tient pas
  compte, mais beaucoup de clients OpenAI l'exigent.

### 6.2 `POST /v1/chat/completions` — chat (utilisé par l'app)

Endpoint compatible OpenAI Chat Completions. **Stateless** : renvoyer tout
l'historique `messages` à chaque appel.

Requête :

```http
POST /v1/chat/completions
Authorization: Bearer <API_SERVER_KEY>
Content-Type: application/json
```

```json
{
  "model": "hermes-agent",
  "messages": [
    {"role": "system", "content": "Tu es un assistant technique."},
    {"role": "user", "content": "Explique ce projet."}
  ],
  "stream": false
}
```

Rôles acceptés : `system`, `user`, `assistant`.

Réponse non-stream (`"stream": false`) :

```json
{
  "id": "chatcmpl-abc123",
  "object": "chat.completion",
  "created": 1710000000,
  "model": "hermes-agent",
  "choices": [
    {
      "index": 0,
      "message": {"role": "assistant", "content": "Voici l’explication..."},
      "finish_reason": "stop"
    }
  ],
  "usage": {"prompt_tokens": 50, "completion_tokens": 200, "total_tokens": 250}
}
```

**Streaming** (`"stream": true`, header `Accept: text/event-stream` conseillé) :
réponse SSE composée de :

- chunks standard `chat.completion.chunk` — le texte est dans
  `choices[0].delta.content` ;
- events custom **`hermes.tool.progress`** (Hermes commence un appel d'outil) —
  émis soit en `event: hermes.tool.progress`, soit comme objet
  `{"object": "hermes.tool.progress", "tool": "...", "message": "..."}` dans une
  ligne `data:` ;
- terminaison par `data: [DONE]`.

**Entrée image inline** : le `content` d'un message user peut être un tableau
de parties `text` / `image_url` (URLs HTTP(S) et `data:image/...` supportées) :

```json
{
  "model": "hermes-agent",
  "messages": [
    {
      "role": "user",
      "content": [
        {"type": "text", "text": "Que vois-tu dans cette image ?"},
        {"type": "image_url", "image_url": {"url": "https://example.com/image.png", "detail": "high"}}
      ]
    }
  ]
}
```

Limite : les uploads de fichiers (`file`, `input_file`, `file_id`) et les data
URLs non-image renvoient `400 unsupported_content_type`.

### 6.3 `POST /v1/responses` — Responses API (multi-tour côté serveur)

Alternative recommandée quand on veut que **Hermes stocke l'historique**
(l'app n'a alors plus à renvoyer toute la conversation).

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
      "content": [{"type": "output_text", "text": "Voici les fichiers..."}]
    }
  ],
  "usage": {"input_tokens": 50, "output_tokens": 200, "total_tokens": 250}
}
```

Chaînage multi-tour, deux options :

```json
{"model": "hermes-agent", "input": "Maintenant montre-moi le README", "previous_response_id": "resp_abc123"}
```

```json
{"model": "hermes-agent", "input": "Lance les tests", "conversation": "mon-projet"}
```

(avec `conversation`, Hermes chaîne automatiquement avec la dernière réponse de
cette conversation nommée).

Images inline (format Responses) :

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

Gestion des réponses stockées :

- `GET /v1/responses/{id}` — relit une réponse stockée ;
- `DELETE /v1/responses/{id}` — la supprime.

### 6.4 Découverte, santé, capacités

| Endpoint | Auth | Rôle |
|---|---|---|
| `GET /v1/models` | oui | Liste le modèle exposé (`hermes-agent` ou nom du profil). Requis par beaucoup de frontends OpenAI-compatibles. |
| `GET /v1/capabilities` | oui | Surface API supportée par l'instance — à appeler au démarrage de l'app pour détecter les fonctionnalités. |
| `GET /health` | non | Health check simple → `{"status": "ok"}` |
| `GET /v1/health` | non | Idem avec préfixe `/v1` (certains clients l'exigent). |
| `GET /health/detailed` | oui | Santé étendue : sessions actives, agents en cours, ressources. |

Réponse typique de `/v1/capabilities` :

```json
{
  "object": "hermes.api_server.capabilities",
  "platform": "hermes-agent",
  "model": "hermes-agent",
  "auth": {"type": "bearer", "required": true},
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

### 6.5 Runs API — tâches longues avec suivi d'événements

Pour lancer une tâche d'agent puis suivre sa progression sans gérer soi-même le
streaming chat.

- `POST /v1/runs` — crée un run :

  ```json
  {
    "input": "Analyse ce dépôt et fais un résumé.",
    "session_id": "space-session",
    "instructions": "Réponds en français.",
    "conversation_history": [],
    "previous_response_id": null
  }
  ```

  → `{"run_id": "run_abc123", "status": "started"}`

- `GET /v1/runs/{run_id}` — état courant. Statuts possibles : `started`,
  `running`, `completed`, `failed`, `cancelled`, `stopping`. Réponse typique :

  ```json
  {
    "object": "hermes.run",
    "run_id": "run_abc123",
    "status": "completed",
    "session_id": "space-session",
    "model": "hermes-agent",
    "output": "Terminé.",
    "usage": {"input_tokens": 50, "output_tokens": 200, "total_tokens": 250}
  }
  ```

- `GET /v1/runs/{run_id}/events` (`Accept: text/event-stream`) — flux SSE des
  événements du run (progression outils, deltas de texte, cycle de vie).
  Recommandé pour dashboards et UI avec reconnexion.
- `POST /v1/runs/{run_id}/stop` — interruption → `{"status": "stopping"}`.
- `POST /v1/runs/{run_id}/approval` — résout une demande d'approbation humaine
  bloquant un outil sensible :

  ```json
  {"approved": true, "reason": "Action validée par l’utilisateur"}
  ```

### 6.6 Jobs API — tâches planifiées (cron)

Sous `{origin}/api/jobs`, **hors `/v1`**. C'est la surface proxifiée par
`/api/v1/hermes/jobs*` dans l'app.

| Méthode + endpoint | Rôle |
|---|---|
| `GET /api/jobs` | Liste tous les jobs planifiés |
| `POST /api/jobs` | Crée un job |
| `GET /api/jobs/{job_id}` | Définition + dernier état d'exécution |
| `PATCH /api/jobs/{job_id}` | Mise à jour partielle (ex. `{"schedule": "every 2h", "prompt": "..."}`) |
| `DELETE /api/jobs/{job_id}` | Supprime le job (annule toute exécution en cours) |
| `POST /api/jobs/{job_id}/pause` | Met en pause |
| `POST /api/jobs/{job_id}/resume` | Reprend |
| `POST /api/jobs/{job_id}/run` | Déclenche immédiatement hors planning |

Body de création (champs possibles : `prompt`, `schedule`, `skills`, override
provider/model, cible de livraison) :

```json
{
  "name": "Brief quotidien",
  "schedule": "0 9 * * *",
  "prompt": "Prépare un brief quotidien en français.",
  "skills": [],
  "deliver": "origin"
}
```

⚠️ Limite constatée dans notre installation : `deliver: "origin"` **échoue en
mode api_server** (pas de webhook sortant) — Hermes ne sait pas livrer le
résultat d'un cron vers l'application. Contournement implémenté :
`POST /api/v1/hermes/jobs/{id}/execute` (côté app) récupère le prompt du job,
l'exécute via `/v1/chat/completions` en non-stream, et stocke le texte dans
`public.hermes_job_results`.

### 6.7 Sessions API — contrôle des sessions REST

Sous `/api/sessions/*`, protégé par `API_SERVER_KEY`.

| Méthode + endpoint | Rôle |
|---|---|
| `GET /api/sessions?limit=20&offset=0&source=api_server&include_children=false` | Liste les sessions (pagination, filtre par source, inclusion des forks) |
| `POST /api/sessions` | Crée une session vide — body : `{"title": "Nouvelle session application"}` |
| `GET /api/sessions/{id}` | Métadonnées d'une session |
| `PATCH /api/sessions/{id}` | Met à jour `title` / `end_reason` |
| `DELETE /api/sessions/{id}` | Supprime la session |
| `GET /api/sessions/{id}/messages` | Historique des messages |
| `POST /api/sessions/{id}/fork` | Fork/branche la session — body : `{"title": "exploration alternative"}` |
| `POST /api/sessions/{id}/chat` | Tour d'agent **synchrone** — body : `{"input": "Que contient ce projet ?"}` |
| `POST /api/sessions/{id}/chat/stream` | Tour d'agent en **SSE** (`Accept: text/event-stream`) — body : `{"input": "..."}` |

Événements SSE de `chat/stream` :

```text
assistant.delta
tool.started
tool.completed
run.completed
```

Les payloads `chat` et `chat/stream` supportent les images inline si l'instance
est multimodale.

### 6.8 Skills et toolsets

- `GET /v1/skills` — skills disponibles avec métadonnées :

  ```json
  [{"name": "github-pr-workflow", "description": "Workflow GitHub PR...", "category": "github"}]
  ```

- `GET /v1/toolsets` — toolsets résolus pour la plateforme `api_server`, avec
  les outils concrets :

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

### 6.9 Headers utiles

| Header | Rôle |
|---|---|
| `Authorization: Bearer <API_SERVER_KEY>` | Obligatoire sur les endpoints protégés |
| `X-Hermes-Session-Id: transcript-alpha` | Identifiant de transcript/session côté client (alternative au renvoi de l'historique complet en chat/completions) |
| `X-Hermes-Session-Key: agent:main:webui:dm:user-42` | Clé stable de mémoire long terme pour frontends multi-utilisateurs. Max 256 caractères, pas de caractères de contrôle (`\r`, `\n`, `\x00`) ; renvoyée dans les réponses JSON et SSE |
| `Idempotency-Key: request-unique-id-123` | Anti-doublon : Hermes peut mettre en cache la réponse par clé pendant 5 minutes (header autorisé quand CORS est activé) |

### 6.10 Variables d'environnement du serveur API

```text
API_SERVER_ENABLED       false par défaut ; active le serveur API
API_SERVER_PORT          8642 par défaut
API_SERVER_HOST          127.0.0.1 par défaut
API_SERVER_KEY           obligatoire ; token Bearer
API_SERVER_CORS_ORIGINS  vide par défaut ; allowlist CORS explicite (si appel direct navigateur)
API_SERVER_MODEL_NAME    nom exposé dans /v1/models ; défaut : nom du profil ou hermes-agent
```

Ces réglages se font par variables d'environnement dans le `.env` de Hermes,
pas via `config.yaml`.

### 6.11 Récapitulatif de tous les endpoints

```text
POST   /v1/chat/completions          # chat OpenAI-compatible (stream ou non)
POST   /v1/responses                 # Responses API (multi-tour côté serveur)
GET    /v1/responses/{id}
DELETE /v1/responses/{id}
GET    /v1/models
GET    /v1/capabilities
GET    /health
GET    /v1/health
GET    /health/detailed

POST   /v1/runs                      # tâches longues avec suivi
GET    /v1/runs/{run_id}
GET    /v1/runs/{run_id}/events      # SSE
POST   /v1/runs/{run_id}/stop
POST   /v1/runs/{run_id}/approval

GET    /api/jobs                     # cron (hors /v1)
POST   /api/jobs
GET    /api/jobs/{job_id}
PATCH  /api/jobs/{job_id}
DELETE /api/jobs/{job_id}
POST   /api/jobs/{job_id}/pause
POST   /api/jobs/{job_id}/resume
POST   /api/jobs/{job_id}/run

GET    /api/sessions                 # sessions REST (hors /v1)
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

### 6.12 Correspondance avec les routes proxy de l'application

| Usage | Endpoint Hermes | Route proxy dans l'app |
|---|---|---|
| Chat (stream ou non) | `POST /v1/chat/completions` | `POST /api/v1/hermes/chat` |
| Jobs : CRUD | `GET/POST/PATCH/DELETE /api/jobs[/{id}]` | `/api/v1/hermes/jobs[/{id}]` |
| Jobs : pause / resume / run | `POST /api/jobs/{id}/{action}` | `POST /api/v1/hermes/jobs/{id}/{action}` |
| Exécution à la demande + stockage | `GET /api/jobs/{id}` puis `POST /v1/chat/completions` | `POST /api/v1/hermes/jobs/{id}/execute` |
| Capacités + santé | `GET /v1/capabilities` + `GET /health/detailed` | `GET /api/v1/hermes/agent-status` |

### 6.13 Exemples minimaux d'appel direct

JavaScript (fetch) :

```js
const API_BASE = "http://10.190.100.58:8642/v1";
const API_KEY = process.env.HERMES_API_KEY;   // jamais dans un bundle frontend !

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
  if (!res.ok) throw new Error(`Hermes API error ${res.status}: ${await res.text()}`);
  const data = await res.json();
  return data.choices[0].message.content;
}
```

Python (SDK OpenAI officiel, API compatible) :

```python
import os
from openai import OpenAI

client = OpenAI(
    base_url="http://10.190.100.58:8642/v1",
    api_key=os.environ["HERMES_API_KEY"],
)

response = client.chat.completions.create(
    model="hermes-agent",
    messages=[{"role": "user", "content": "Bonjour Hermes"}],
)
print(response.choices[0].message.content)
```

---

## 7. Tester la chaîne complète

```bash
# 1. Hermes en direct (isoler l'upstream)
curl -N http://10.190.100.58:8642/v1/chat/completions \
  -H "Authorization: Bearer $HERMES_API_KEY" -H "Content-Type: application/json" \
  -d '{"model":"hermes-agent","messages":[{"role":"user","content":"Bonjour"}],"stream":true}'

# 2. Via le proxy de l'application (JWT requis)
TOKEN=$(curl -s -X POST http://10.190.100.58:5000/api/v1/auth/login \
  -H 'Content-Type: application/json' \
  -d '{"username":"<user>","password":"<mot de passe>"}' | jq -r '.access_token')

curl -N -X POST http://10.190.100.58:5000/api/v1/hermes/chat \
  -H "Authorization: Bearer $TOKEN" -H 'Content-Type: application/json' \
  -d '{"messages":[{"role":"user","content":"Présente-toi en une phrase."}],"instructions":"Réponds en français.","stream":true}'
```

`-N` désactive le buffering curl : les `data: {...}` doivent arriver
**progressivement** et se terminer par `data: [DONE]`. Si les tokens arrivent
par gros paquets derrière nginx : vérifier `X-Accel-Buffering: no` ou ajouter
`proxy_buffering off;` au `location /api/` du vhost.

---

## 8. Checklist pour une nouvelle application

- [ ] Serveur : `API_SERVER_ENABLED=true`, `API_SERVER_KEY` forte,
      `API_SERVER_HOST=0.0.0.0` **uniquement** si l'app est sur une autre machine/conteneur, puis `docker restart hermes`.
- [ ] Vérifier `GET /v1/models` → 200 avec la clé.
- [ ] Backend : route proxy protégée par l'auth de l'app ; clé lue en config
      serveur (env ou DB), jamais côté client.
- [ ] Construire `messages` : instructions → unique message `system` en tête ;
      renvoyer tout l'historique à chaque tour.
- [ ] Streaming : relayer le SSE tel quel, `X-Accel-Buffering: no`,
      workers threadés, timeout = silence entre chunks (300 s conseillé).
- [ ] Erreurs : 400 (payload), 500 (clé manquante), 502 (Hermes down/clé refusée),
      504 (timeout), event `{"error"}` mi-stream.
- [ ] Frontend : fetch + ReadableStream, parseur SSE bufferisé, gestion de
      `[DONE]`, `hermes.tool.progress`, erreurs mi-stream et abort.
- [ ] Persistance de l'historique côté application si besoin (Hermes chat est stateless).
