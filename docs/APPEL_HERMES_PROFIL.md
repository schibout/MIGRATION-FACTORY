# Appeler Hermès avec un profil

> **À lire comme une consigne d'implémentation, pas comme un récit.**
> Tu es l'agent chargé de brancher une application sur Hermès Agent en ciblant un
> profil nommé. Ce document contient le contrat exact, les pièges qui font perdre
> une demi-journée, et une implémentation de référence déjà en production.
> Implémentation vivante : [hermes_adapter.py](backend/src/klinicos/modules/ai/infrastructure/hermes_adapter.py).
> Variante Node/Express du même contrat : [APPEL_HERMES.md](docs/api/APPEL_HERMES.md).

---

## 1. Ce que tu dois produire

Un **adaptateur serveur unique** — un seul fichier parle à Hermès — qui :

1. construit l'URL `<racine>/p/<profil>/v1/chat/completions` ;
2. envoie `{model, messages, stream:false}` en POST JSON ;
3. lit la réponse dans `choices[0].message.content` ;
4. traduit tout échec en code générique, sans jamais renvoyer au client l'URL
   interne, la clé, le corps d'erreur d'Hermès ou une stack trace ;
5. lit son URL, son profil et sa clé dans l'environnement — jamais en dur, jamais
   dans un bundle navigateur.

Le navigateur ne connaît ni Hermès, ni le profil, ni la clé. Il parle à ton
backend, ton backend parle à Hermès.

---

## 2. Le contrat HTTP, exactement

### Requête

```http
POST http://127.0.0.1:8642/p/klinicos/v1/chat/completions
Content-Type: application/json
Authorization: Bearer <HERMES_API_KEY>      ← en-tête omis si la clé est vide
```

```json
{
  "model": "klinicos",
  "messages": [
    { "role": "system",    "content": "<persona imposée par le serveur>" },
    { "role": "user",      "content": "Bonjour" },
    { "role": "assistant", "content": "…" }
  ],
  "stream": false
}
```

Clés facultatives, ajoutées **seulement si configurées** : `max_tokens`,
`temperature`. Une variable d'environnement vide signifie *absente du corps*,
pas *valeur par défaut*.

Rôles acceptés : `system`, `user`, `assistant`, `tool`. Le rôle `tool` est
utilisé ici en texte libre (`"Result of search_slots:\n…"`), sans
`tool_call_id` : Hermès n'exige pas le protocole outils d'OpenAI.

### Réponse

```json
{ "choices": [ { "message": { "content": "…" } } ] }
```

Tout le reste est ignoré. Un `content` absent, non-textuel ou vide est une
erreur, pas une réponse.

---

## 3. Les trois pièges — c'est la partie qui compte

**Piège 1 — le profil est dans l'URL, pas dans `model`.**
`/p/<profil>/` est ce qui sélectionne l'agent. Le champ `model` du corps est
décoratif : Hermès le renvoie tel quel et ne sélectionne rien. Cibler le profil
par `model` donne un **404**. Par convention on met quand même le nom du profil
dans `model` pour que les journaux soient lisibles.

**Piège 2 — le corps validé ne contient que trois clés.**
`model`, `messages`, `stream:false`. N'ajoute rien « pour faire bien » : c'est la
forme vérifiée à la main contre le vrai service.

**Piège 3 — sans message système, tu obtiens l'agent Hermès générique.**
Le profil par défaut se présente comme un agent système et **propose d'exécuter
des commandes shell** à qui le lui demande gentiment. Le message système est donc
ajouté **côté serveur**, après filtrage. Tout message de rôle `system` ou `tool`
venant du client est **rejeté en 400**, jamais silencieusement retiré : un client
qui envoie un `system` est un client qui tente de réécrire les instructions de
l'assistant.

---

## 4. Où vit la persona : profil ou requête ?

Les deux marchent. Ils ne produisent pas le même comportement, et le choix a été
tranché par mesure, pas par goût — même question, même profil, même modèle :

| Emplacement | Résultat observé |
|---|---|
| Persona du profil (`~/.hermes/profiles/<profil>/SOUL.md`) | Le modèle adopte le ton, **n'émet jamais le bloc d'outil**. Le scaffolding de l'agent — des dizaines de milliers de tokens — décide comment il appelle des outils, et une persona ne le surclasse pas. |
| Tour `system` de la requête | Le bon appel d'outil dès le premier essai. |

Règle : **conversation simple → profil suffit ; protocole d'outils → tour
`system` dans la requête.**

Deuxième raison, indépendante du runtime : un profil s'édite hors du dépôt, par
qui a un accès shell, et dérive du catalogue d'outils sans qu'un seul test le
remarque. Si tu tiens quand même à mettre le texte dans le profil, **génère-le**
depuis le code plutôt que de le maintenir à la main :

```bash
uv run python scripts/hermes_profile_prompt.py > /tmp/klinicos-soul.md
hermes profile create klinicos
cp /tmp/klinicos-soul.md ~/.hermes/profiles/klinicos/SOUL.md   # chemin exact : hermes profile show
```

Voir [hermes_profile_prompt.py](backend/scripts/hermes_profile_prompt.py) : le
texte est composé de `persona(assistant, locale)` + protocole d'outils +
catalogue décrit depuis la table sur laquelle l'exécuteur dispatche. À
régénérer dès qu'un outil change.

**Ce texte n'est pas un contrôle de sécurité.** Il dit au modèle quels outils
existent. Ce que le modèle a le *droit* de faire est redécidé à chaque appel par
le garde d'autorisation, et toute action modifiante passe par une confirmation
humaine sur proposition signée. Un profil édité par n'importe qui ne peut donc
pas élargir ce que l'assistant atteint.

---

## 5. Configuration

```bash
HERMES_API_URL=http://127.0.0.1:8642   # racine seule, SANS /v1 ni /p/…
HERMES_PROFILE=klinicos                # segment /p/… : ce qui choisit l'agent
HERMES_API_KEY=                        # = API_SERVER_KEY côté Hermès ; vide → pas d'en-tête
HERMES_MODEL=klinicos                  # champ "model" du corps ; défaut = le profil
HERMES_TIMEOUT_MS=30000
HERMES_MAX_TOKENS=                     # vide → clé absente du corps
HERMES_TEMPERATURE=                    # vide → clé absente du corps
```

Dans KlinicOS ces variables portent le préfixe applicatif `KLINICOS_` (une seule
convention par application) — voir [.env.example](.env.example) et
[config.py](backend/src/klinicos/core/config.py). Adapte le préfixe, pas la
sémantique.

### Depuis un conteneur : l'adresse change

Hermès écoute sur `127.0.0.1:8642` **de l'hôte**. Dans un conteneur, `127.0.0.1`
désigne le conteneur : l'URL de `.env` n'y vaut rien, exactement comme pour une
base de données. Deux adresses coexistent donc, et ce n'est pas une redondance :

```yaml
# docker-compose.yml — l'URL est reconstruite pour les conteneurs
KLINICOS_HERMES_API_URL: http://${KLINICOS_HERMES_HOST:-172.28.0.1}:${KLINICOS_HERMES_PORT:-18642}
```

`172.28.0.1:18642` est un relais nginx local vers `127.0.0.1:8642`, restreint au
réseau Docker de la pile. Passer par un relais plutôt que de faire écouter Hermès
plus largement : Hermès est mutualisé entre plusieurs sites de production, et on
ne reconfigure pas un service dont d'autres dépendent pour un seul appelant.

---

## 6. Implémentation de référence (Python, httpx)

```python
class HermesAgentRuntimeAdapter:
    def __init__(self, *, base_url, profile, api_key=None, model=None,
                 timeout_ms=30_000, max_tokens=None, temperature=None):
        self._base_url = base_url.rstrip("/")
        self._profile = profile
        self._api_key = api_key
        self._model = model or profile          # défaut = le profil
        self._timeout = timeout_ms / 1000
        self._max_tokens = max_tokens
        self._temperature = temperature

    @property
    def endpoint(self) -> str:
        return f"{self._base_url}/p/{self._profile}/v1/chat/completions"

    def complete(self, conversation) -> AgentReply:
        body = {
            "model": self._model,
            "messages": [{"role": m.role.value, "content": m.content}
                         for m in conversation.messages],
            "stream": False,
        }
        if self._max_tokens is not None:
            body["max_tokens"] = self._max_tokens
        if self._temperature is not None:
            body["temperature"] = self._temperature

        headers = {"Content-Type": "application/json"}
        if self._api_key:
            headers["Authorization"] = f"Bearer {self._api_key}"

        try:
            response = httpx.post(self.endpoint, json=body, headers=headers,
                                  timeout=self._timeout)
        except httpx.TimeoutException as exc:
            logger.warning("hermes_timeout", profile=self._profile)
            raise AgentRuntimeError("TIMEOUT") from exc
        except httpx.HTTPError as exc:
            logger.warning("hermes_unreachable", profile=self._profile,
                           error=type(exc).__name__)
            raise AgentRuntimeError("UPSTREAM_UNAVAILABLE") from exc

        if response.status_code >= 400:
            # Le statut et le profil au journal ; le corps nulle part.
            logger.warning("hermes_error", profile=self._profile,
                           status_code=response.status_code)
            raise AgentRuntimeError("UPSTREAM_ERROR")

        try:
            content = response.json()["choices"][0]["message"]["content"]
        except (ValueError, KeyError, IndexError, TypeError) as exc:
            logger.warning("hermes_unreadable_reply", profile=self._profile)
            raise AgentRuntimeError("UPSTREAM_ERROR") from exc

        if not isinstance(content, str) or not content.strip():
            raise AgentRuntimeError("EMPTY_REPLY")

        return AgentReply(content=content, metadata={"profile": self._profile})
```

Prévois un double en mémoire (`ScriptedRuntime` : une liste de réponses
préparées) **à côté de l'adaptateur**, pas dans l'arbre de tests : la façon dont
le port s'exerce fait partie du port, et une seconde copie par fichier de test
est la manière dont les assertions se mettent à diverger sur le comportement du
runtime.

---

## 7. Erreurs : classifier, jamais relayer

| Interne | HTTP client | Quand |
|---|---|---|
| `TIMEOUT` | 504 | dépassement du délai |
| `UPSTREAM_UNAVAILABLE` | 503 | Hermès injoignable |
| `UPSTREAM_ERROR` | 502 | statut ≥ 400, ou réponse illisible |
| `EMPTY_REPLY` | 502 | `content` vide ou non textuel |

Un corps d'erreur amont peut contenir l'URL interne, la clé ou une trace. Le
texte d'erreur d'un LLM est la dernière chose à renvoyer dans un navigateur.

---

## 8. Vérifier

```bash
# 1. Hermès répond, profil compris — appel brut, sans passer par le backend
curl -sS -X POST "http://127.0.0.1:8642/p/klinicos/v1/chat/completions" \
  -H "Content-Type: application/json" -H "Authorization: Bearer <CLE>" \
  -d '{"model":"klinicos","messages":[{"role":"user","content":"test"}],"stream":false}'

# 2. Le profil existe bien (un profil absent → 404)
hermes profile show klinicos

# 3. Depuis le conteneur, via le relais
docker compose exec backend curl -sS -X POST \
  "http://172.28.0.1:18642/p/klinicos/v1/chat/completions" \
  -H "Content-Type: application/json" \
  -d '{"model":"klinicos","messages":[{"role":"user","content":"test"}],"stream":false}'

# 4. Le trajet applicatif complet
curl -sS -X POST http://localhost:8000/api/v1/ai/converse \
  -H "Content-Type: application/json" -H "Authorization: Bearer <JWT>" \
  -d '{"assistant":"SECRETARY","messages":[{"role":"user","content":"Bonjour"}]}'
```

Un 404 sur l'étape 1 signifie presque toujours l'une de deux choses : le profil
n'existe pas, ou tu as ciblé le profil par `model` au lieu de l'URL.

---

## 9. Checklist avant de dire que c'est fait

- [ ] Le profil est dans l'URL ; `model` n'est jamais utilisé pour le sélectionner.
- [ ] Le corps contient trois clés, plus `max_tokens`/`temperature` uniquement si configurés.
- [ ] `HERMES_API_URL` est la racine seule, sans `/v1` ni `/p/…`.
- [ ] Clé vide → en-tête `Authorization` absent (et pas `Bearer ` vide).
- [ ] Les rôles `system` et `tool` venant du client sont rejetés en 400.
- [ ] Le message système est ajouté par le serveur, après filtrage.
- [ ] Aucune erreur amont ne traverse vers le client ; tout part au journal.
- [ ] URL, profil et clé viennent de l'environnement, jamais du dépôt, jamais du bundle front.
- [ ] Depuis Docker, l'URL passe par le relais et pas par `127.0.0.1`.
- [ ] Le timeout est posé sur l'appel (30 s par défaut).
