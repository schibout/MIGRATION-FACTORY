# Assistant Hermes — Intégration Migration Factory

Page de chat (menu **Intelligence Artificielle → Assistant Hermes**, route `/hermes`)
branchée sur l'agent **Hermes** (Nous Research) qui tourne sur le serveur
`10.190.100.58` (Docker, `network_mode: host`). Hermes expose une API HTTP
**OpenAI-compatible** ; Migration Factory y accède via un **proxy backend** —
la clé API ne transite **jamais** par le navigateur.

## Architecture

```
Navigateur (JWT MF)                Backend Flask                    Agent Hermes
HermesChat.tsx  ── fetch SSE ──►  POST /api/v1/hermes/chat  ──►  POST :8642/v1/chat/completions
hermesService.ts ◄─ relay SSE ──  (api/hermes.py, jwt_required)   (Bearer HERMES_API_KEY)
```

- **Streaming bout-en-bout** : chunks `chat.completion.chunk` relayés tels quels,
  y compris l'event custom `hermes.tool.progress` (affiché « Hermes utilise un
  outil… ») et le `[DONE]` final.
- **Instructions système** : le champ repliable « Instructions à Hermes » de la
  page est envoyé comme message `{"role":"system"}` en tête de chaque requête —
  consigne persistante sur toute la conversation.
- **Multi-tour** : API Hermes stateless — le frontend renvoie tout l'historique
  à chaque message.

## Prérequis côté serveur (déjà en place au 2026-07-07)

Le serveur API de Hermes doit être activé. La config vit dans le conteneur
Docker **`hermes`** (sur `10.190.100.58`), fichier **`/opt/data/.env`** :

```
API_SERVER_ENABLED=true
API_SERVER_KEY=<clé secrète forte>
API_SERVER_HOST=0.0.0.0       # pour que le conteneur backend MF puisse joindre Hermes
API_SERVER_PORT=8642
```

Inspection / redémarrage :

```bash
docker exec hermes sh -c 'cat /opt/data/.env'   # vérifier la config
docker restart hermes                            # après modification du .env
```

> ✅ **Vérifié le 2026-07-07** : `GET /v1/models` → HTTP 200, et un chat
> `stream:true` renvoie bien des trames `data: {chat.completion.chunk}` avec
> `choices[0].delta.content`, terminées par ligne vide (SSE standard).
> ⚠️ `API_SERVER_KEY` est **obligatoire** : cette API donne accès au **toolset
> complet** de Hermes (terminal inclus). Ne jamais l'exposer ; elle se configure
> côté Migration Factory (ci-dessous) et ne transite jamais vers le navigateur.

## Configuration côté Migration Factory

Page **Paramètres → Assistant IA — Modèle** (ou variables d'environnement) :

| Clé | Défaut | Rôle |
|---|---|---|
| `HERMES_API_URL` | `http://10.190.100.58:8642/v1` | Endpoint OpenAI-compatible de Hermes |
| `HERMES_API_KEY` | *(vide — obligatoire)* | La `API_SERVER_KEY` du serveur Hermes (masquée) |
| `HERMES_TIMEOUT_SECONDS` | `300` | Silence max entre deux chunks du stream |

Lecture dynamique (DB `system_config` > env > défaut) : changement de clé sans
redémarrage.

Note déploiement : `backend/start.sh` lance désormais gunicorn en
`--worker-class gthread` (4 workers × 8 threads) pour que les streams SSE ne
bloquent pas les workers sync (rollback : `WORKER_CLASS=sync`).

## Tester

```bash
# 1. Hermes en direct (isoler l'upstream)
curl -N http://10.190.100.58:8642/v1/chat/completions \
  -H "Authorization: Bearer $HERMES_API_KEY" -H "Content-Type: application/json" \
  -d '{"model":"hermes-agent","messages":[{"role":"user","content":"Bonjour"}],"stream":true}'

# 2. Proxy Migration Factory (JWT requis)
TOKEN=$(curl -s -X POST http://10.190.100.58:5000/api/v1/auth/login \
  -H 'Content-Type: application/json' \
  -d '{"username":"<user>","password":"<mot de passe>"}' | jq -r '.access_token')

curl -N -X POST http://10.190.100.58:5000/api/v1/hermes/chat \
  -H "Authorization: Bearer $TOKEN" -H 'Content-Type: application/json' \
  -d '{"messages":[{"role":"user","content":"Présente-toi en une phrase."}],"instructions":"Réponds en français.","stream":true}'
```

`-N` désactive le buffering curl : les chunks `data: {...}` doivent arriver
**progressivement**, terminés par `data: [DONE]`.

Cas d'erreur attendus : clé vide → 500 explicite ; Hermes éteint → 502 ;
mauvaise clé → 502 « Authentification refusée » ; sans JWT → 401 ;
`{"messages":[]}` → 400.

Si les tokens arrivent par gros paquets derrière nginx : la réponse pose déjà
`X-Accel-Buffering: no`, sinon ajouter `proxy_buffering off;` au
`location /api/` du vhost.
