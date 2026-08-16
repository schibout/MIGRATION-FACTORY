# Hermes dans Migration Factory — appel par profil

Ce document décrit l'intégration réellement déployée et testée entre Migration
Factory et Hermes Agent : appel du profil `migration`, proxy Flask, streaming
SSE, authentification, endpoints, déploiement et incidents rencontrés.

## 1. Principe fondamental

Migration Factory ne choisit ni le fournisseur ni le modèle LLM. L'application
sélectionne uniquement le profil Hermes dans l'URL :

```text
POST /p/migration/v1/chat/completions
```

Le profil `migration` gère ensuite :

- fournisseur et modèle principal ;
- modèles auxiliaires et mélange d'agents ;
- persona, outils, skills et MCP ;
- authentification du fournisseur ;
- mémoire et paramètres d'exécution Hermes.

Le corps envoyé par Migration Factory ne contient donc pas de champ `model` :

```json
{
  "messages": [
    {"role": "user", "content": "Liste les tables fournisseurs SAP"}
  ],
  "stream": true
}
```

`"model": "migration"` ne sélectionne pas le profil. Seul le segment
`/p/migration/` de l'URL le fait.

## 2. Architecture

```text
Navigateur
  POST /app4/api/v1/hermes/chat
  JWT Migration Factory
        |
        v
Backend Flask — backend/api/hermes.py
  - valide messages/instructions
  - construit /p/migration/v1/chat/completions
  - ajoute la clé Hermes côté serveur
        |
        v
Gateway Hermes — conteneur hermes:8642
  - charge le profil migration
  - choisit modèle, fournisseur, outils et MCP
        |
        v
Fournisseur LLM choisi par Hermes
        |
        v
Flux SSE relayé jusqu'au navigateur
```

La clé Hermes ne quitte jamais le backend. Le navigateur connaît uniquement le
JWT Migration Factory.

Fichiers concernés :

- `backend/api/hermes.py` : proxy, historique, jobs et statut ;
- `backend/api/__init__.py` : route `/api/v1/hermes` ;
- `backend/api/settings.py` : paramètres Hermes ;
- `frontend/src/services/hermesService.ts` : appel et parseur SSE ;
- `frontend/src/store/slices/hermesChatSlice.ts` : état Redux ;
- `frontend/src/pages/HermesChat.tsx` : écran `/hermes` ;
- `backend/tests/test_hermes_api.py` : tests backend.

## 3. Configuration Migration Factory

```dotenv
HERMES_API_URL=http://hermes:8642/v1
HERMES_PROFILE=migration
HERMES_API_KEY=<API_SERVER_KEY du profil/gateway Hermes>
HERMES_TIMEOUT_SECONDS=300
```

Ordre de résolution :

1. `public.system_config` ;
2. environnement du backend ;
3. valeur par défaut du code.

La base est prioritaire. Une ancienne clé dans `system_config` peut donc écraser
une clé correcte dans `.env`. `CONFIG_ENV_PRIORITY` permet une surcharge locale
explicite, conformément à `backend/services/config_service.py`.

`HERMES_API_URL` contient `/v1`, mais pas `/p/migration`. Le backend construit :

```text
http://hermes:8642/p/migration/v1/chat/completions
```

Ne jamais committer `.env`, une clé Hermes, un token fournisseur ou `auth.json`.

## 4. Appels de conversation

### 4.1 Navigateur vers Migration Factory

```http
POST /api/v1/hermes/chat
Authorization: Bearer <JWT Migration Factory>
Content-Type: application/json
```

```json
{
  "messages": [
    {"role": "user", "content": "Quelles sont les tables fournisseurs SAP ?"}
  ],
  "instructions": "Réponds en français.",
  "stream": true
}
```

- `messages` est obligatoire et non vide ;
- rôles acceptés : `user`, `assistant`, `system` ;
- `instructions` est facultatif et devient l'unique message `system` en tête ;
- `stream` vaut `true` par défaut ;
- tout l'historique est renvoyé à chaque tour (API stateless).

### 4.2 Backend vers Hermes

```http
POST http://hermes:8642/p/migration/v1/chat/completions
Authorization: Bearer <HERMES_API_KEY>
Content-Type: application/json
Accept: text/event-stream
```

```json
{
  "messages": [
    {"role": "system", "content": "Réponds en français."},
    {"role": "user", "content": "Quelles sont les tables fournisseurs SAP ?"}
  ],
  "stream": true
}
```

Le backend ne doit ajouter ni `model`, ni `provider`, ni clé fournisseur.

### 4.3 Réponse non-streaming

```json
{
  "choices": [
    {
      "message": {"role": "assistant", "content": "..."},
      "finish_reason": "stop"
    }
  ]
}
```

Le contenu se lit dans `choices[0].message.content`.

### 4.4 Réponse streaming SSE

```text
data: {"object":"chat.completion.chunk","choices":[{"delta":{"content":"Bon"}}]}

data: {"object":"chat.completion.chunk","choices":[{"delta":{"content":"jour"}}]}

data: [DONE]
```

Le frontend concatène `choices[0].delta.content` et gère :

- `event: hermes.tool.progress` ;
- `parsed.error` ;
- `hermes.error` et `finish_reason: "error"` ;
- `[DONE]` ou une fermeture propre ;
- l'annulation via `AbortController`.

Hermes peut répondre HTTP 200 tout en signalant un échec métier. Toujours lire
`finish_reason`, `hermes.failed`, `hermes.error` et les en-têtes `X-Hermes-*`.

## 5. Authentification

| Trajet | Authentification |
|---|---|
| Navigateur → Migration Factory | JWT application |
| Backend → Hermes | `Authorization: Bearer HERMES_API_KEY` |
| Hermes → fournisseur LLM | Géré dans le profil (`auth.json`, OAuth/token) |

Avec le multiplexage, le profil peut exiger sa propre `API_SERVER_KEY` dans :

```text
<HERMES_HOME>/profiles/migration/.env
```

Si elle manque, Hermes journalise :

```text
no profile-scoped API_SERVER_KEY is configured
```

Une mauvaise clé donne HTTP 401 depuis Hermes, traduit par Migration Factory en
502 « Authentification refusée par Hermes ».

## 6. Incident principal : deux stockages Hermes

Deux instances utilisaient deux volumes différents :

| Usage | Conteneur | Stockage hôte monté sur `/opt/data` |
|---|---|---|
| Chat/dashboard natif | `hermes-dashboard` | `/root/.hermes` |
| Gateway Migration Factory | `hermes` | `/opt/hermes/.hermes` |

Conséquence :

- chat natif : `openai-codex / gpt-5.6-luna` ;
- API Migration Factory : `anthropic / claude-sonnet-5` ;
- modifier le dashboard ne modifiait pas la copie chargée par le gateway ;
- Anthropic répondait `HTTP 400: You're out of extra usage`.

Cette erreur ne venait pas de Migration Factory. Les logs Hermes confirmaient :

```text
Provider: anthropic
Model: claude-sonnet-5
Endpoint: https://api.anthropic.com
```

La correction a consisté à sauvegarder puis synchroniser vers le gateway :

- `profiles/migration/config.yaml` ;
- `profiles/migration/auth.json`.

Ne pas synchroniser `.env` aveuglément : il contient la clé du gateway et peut
être spécifique à chaque instance. Ne jamais afficher `auth.json` ou une clé.

Après correction :

```text
HTTP 200
finish_reason=stop
content=OK
```

Le streaming a également renvoyé du contenu, `[DONE]` et aucune erreur.

### Diagnostiquer les stockages

```bash
docker inspect hermes hermes-dashboard \
  --format '{{.Name}} {{range .Mounts}}{{.Source}}:{{.Destination}} {{end}}'

docker exec hermes sh -lc \
  'sed -n "1,8p" /opt/data/profiles/migration/config.yaml'

docker exec hermes-dashboard sh -lc \
  'sed -n "1,8p" /opt/data/profiles/migration/config.yaml'
```

Comparer les authentifications sans les afficher :

```bash
docker exec hermes sha256sum /opt/data/profiles/migration/auth.json
docker exec hermes-dashboard sha256sum /opt/data/profiles/migration/auth.json
```

## 7. Multiplexage et port 8642

Le gateway principal possède l'unique listener et sert les profils sous
`/p/<profil>/`. La configuration principale utilise :

```yaml
multiplex_profiles: true
```

Un profil secondaire ne doit pas lancer son propre `api_server` sur `8642`.
Sinon les logs contiennent :

```text
Skipping secondary profile 'migration' due to port-binding config error
Port 8642 already in use
```

En mode multiplexé :

- gateway par défaut : écoute sur `8642` ;
- profil `migration` : servi par `/p/migration/...` ;
- aucun second listener sur `8642`.

## 8. Autres endpoints Migration Factory

### Conversations

```text
GET    /api/v1/hermes/conversations
GET    /api/v1/hermes/conversations/<id>
POST   /api/v1/hermes/conversations
DELETE /api/v1/hermes/conversations/<id>
```

Tables : `public.hermes_conversations` et `public.hermes_messages`. Les données
sont isolées par l'identité JWT.

### Jobs

```text
GET    /api/v1/hermes/jobs
POST   /api/v1/hermes/jobs
GET    /api/v1/hermes/jobs/<id>
PATCH  /api/v1/hermes/jobs/<id>
DELETE /api/v1/hermes/jobs/<id>
POST   /api/v1/hermes/jobs/<id>/pause
POST   /api/v1/hermes/jobs/<id>/resume
POST   /api/v1/hermes/jobs/<id>/run
```

Les Jobs Hermes sont sous `http://hermes:8642/api/jobs`, sans `/v1` et sans
`/p/migration`.

### Exécution immédiate d'un job

```text
POST /api/v1/hermes/jobs/<id>/execute
```

Le backend récupère le prompt, l'envoie au chat du profil en non-streaming, puis
stocke le résultat dans `public.hermes_job_results`. Aucun champ `model`.

### Statut agent

```text
GET /api/v1/hermes/agent-status
```

## 9. Diagnostic des erreurs

| Symptôme | Cause probable | Vérification |
|---|---|---|
| 401 application | JWT absent/expiré | Reconnexion, `/auth/me` |
| 400 `messages doit être...` | Corps invalide | Liste et rôles |
| 500 clé non configurée | `HERMES_API_KEY` vide | DB puis environnement |
| 502 authentification refusée | Mauvaise clé gateway/profil | Comparer sans afficher |
| 502 profil inconnu | Profil absent/multiplexage inactif | URL et logs Hermes |
| 502 agent injoignable | Réseau/DNS Docker | Résolution de `hermes` |
| 504 | Timeout | Timeout et logs Hermes |
| HTTP 200 + erreur | Erreur LLM encapsulée | `hermes.error`, logs fournisseur |
| Aucun texte à l'écran | Erreur SSE imbriquée ignorée | Parseur frontend |
| Chat natif OK, application KO | Stockages différents | Mounts et `config.yaml` |

En-têtes utiles :

```text
X-Hermes-Completed
X-Hermes-Partial
X-Hermes-Error
X-Hermes-Session-Id
```

Les corps non JSON, traces, URLs internes et secrets ne doivent jamais être
relayés au navigateur.

## 10. Tests opérationnels

### Appel direct depuis le backend

```bash
docker compose exec -T backend python3 - <<'PY'
import requests
from api.hermes import _hermes_config, _chat_url

cfg = _hermes_config()
r = requests.post(
    _chat_url(cfg),
    headers={
        "Authorization": "Bearer " + cfg["api_key"],
        "Content-Type": "application/json",
    },
    json={
        "messages": [{"role": "user", "content": "Réponds uniquement par OK"}],
        "stream": False,
    },
    timeout=(10, 60),
)
data = r.json()
print("status=", r.status_code)
print("finish_reason=", data["choices"][0]["finish_reason"])
print("content=", data["choices"][0]["message"]["content"])
PY
```

Attendu : HTTP 200, `finish_reason=stop`, contenu non vide.

### Tests backend et frontend

```bash
docker compose exec -T backend \
  python3 -m pytest -q tests/test_hermes_api.py

docker compose exec -T frontend npm run build

docker compose ps
```

Résultat validé pendant la correction : `33 passed`. Le warning Vite sur la
taille du bundle est non bloquant.

## 11. Déploiement

Les scripts historiques peuvent échouer si l'ancien `docker-compose` ne comprend
pas le tag YAML `!reset`. Utiliser Docker Compose moderne :

```bash
docker compose build backend frontend
docker compose up -d backend frontend
docker compose ps
```

Après modification d'un profil Hermes :

```bash
docker restart hermes
```

Puis refaire un test non-streaming et un test SSE.

## 12. Points d'attention

1. Le profil est dans l'URL, jamais dans `model`.
2. Migration Factory ne choisit pas le modèle ou le fournisseur.
3. HTTP 200 Hermes peut contenir une erreur LLM.
4. Le frontend doit gérer les erreurs imbriquées du SSE.
5. `system_config` peut écraser `.env`.
6. Un profil multiplexé peut demander une clé API dédiée.
7. Gateway et dashboard doivent lire le même `HERMES_HOME`, ou être
   synchronisés prudemment.
8. Ne jamais copier `.env` ou `auth.json` sans sauvegarde et autorisation.
9. Ne jamais exposer le port `8642` publiquement : terminal et MCP sont puissants.
10. Redémarrer ne corrige pas une configuration située dans le mauvais volume.
11. Conserver le MCP PostgreSQL et les règles de sécurité du profil `migration`.
12. Tester depuis le conteneur backend, pas uniquement depuis l'hôte.

## 13. Checklist finale

- [ ] URL : `/p/migration/v1/chat/completions`.
- [ ] JSON : uniquement `messages` et `stream`.
- [ ] `HERMES_PROFILE=migration` effectif.
- [ ] Clé gateway/profil valide et non exposée.
- [ ] Gateway et chat utilisent la même configuration de profil.
- [ ] Modèle des logs conforme au modèle affiché dans Hermes.
- [ ] Non-streaming : contenu et `finish_reason=stop`.
- [ ] SSE : deltas, `[DONE]`, aucune erreur.
- [ ] Tests Hermes réussis.
- [ ] Build frontend réussi.
- [ ] Services `healthy`.

---

État validé après correction : Migration Factory appelle uniquement le profil
`migration`; Hermes gère `openai-codex / gpt-5.6-luna`; les appels
non-streaming et streaming répondent correctement.
