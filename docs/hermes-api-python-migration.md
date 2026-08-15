# Appeler Hermes depuis Python avec le profil `migration`

Cette documentation explique comment envoyer un prompt à Hermes depuis Python via son API HTTP compatible OpenAI.

Le profil `migration` contient le serveur MCP PostgreSQL et peut utiliser l’outil `mcp_postgres_query`.

## 1. Démarrer l’API Hermes

Pour démarrer Hermes avec le profil `migration` :

```bash
export HERMES_HOME=/opt/data/profiles/migration
export API_SERVER_ENABLED=true
export API_SERVER_KEY="une-cle-api-securisee"

hermes gateway run
```

Avec le chemin complet de l’installation :

```bash
HERMES_HOME=/opt/data/profiles/migration \
API_SERVER_ENABLED=true \
API_SERVER_KEY="une-cle-api-securisee" \
/opt/hermes/.venv/bin/hermes gateway run
```

Par défaut, l’API écoute sur :

```text
http://127.0.0.1:8642
```

La clé `API_SERVER_KEY` est la clé d’authentification de l’API Hermes. Elle est différente du mot de passe PostgreSQL.

## 2. Appel depuis Python avec `requests`

Installer la dépendance si nécessaire :

```bash
pip install requests
```

Exemple complet :

```python
import os
import requests


API_URL = "http://127.0.0.1:8642/v1/chat/completions"
API_KEY = os.environ["API_SERVER_KEY"]

payload = {
    "model": "hermes-agent",
    "messages": [
        {
            "role": "user",
            "content": """
Utilise le serveur MCP PostgreSQL du profil migration.
Liste les tables du schéma public et leurs colonnes.
Ne modifie aucune donnée.
""",
        }
    ],
}

response = requests.post(
    API_URL,
    headers={
        "Authorization": f"Bearer {API_KEY}",
        "Content-Type": "application/json",
    },
    json=payload,
    timeout=300,
)

response.raise_for_status()

data = response.json()
answer = data["choices"][0]["message"]["content"]

print(answer)
```

Avant de lancer le script :

```bash
export API_SERVER_KEY="une-cle-api-securisee"
python3 script.py
```

## 3. Fonction Python réutilisable

```python
import os
import requests


def ask_hermes(prompt: str) -> str:
    response = requests.post(
        "http://127.0.0.1:8642/v1/chat/completions",
        headers={
            "Authorization": f"Bearer {os.environ['API_SERVER_KEY']}",
            "Content-Type": "application/json",
        },
        json={
            "model": "hermes-agent",
            "messages": [
                {
                    "role": "user",
                    "content": prompt,
                }
            ],
        },
        timeout=300,
    )

    response.raise_for_status()
    return response.json()["choices"][0]["message"]["content"]


answer = ask_hermes(
    "Utilise mcp_postgres_query pour compter les tables PostgreSQL."
)

print(answer)
```

## 4. Exemple de prompt PostgreSQL

```python
answer = ask_hermes(
    """
Utilise mcp_postgres_query pour inspecter la base de migration.
Retourne :
1. les schémas disponibles ;
2. les tables du schéma public ;
3. les colonnes et leurs types.
Ne modifie aucune donnée.
"""
)

print(answer)
```

Hermes reçoit le prompt, utilise le MCP PostgreSQL configuré dans le profil `migration`, puis Python récupère la réponse avec :

```python
data["choices"][0]["message"]["content"]
```

## 5. API avec multiplexage des profils

Si un gateway global utilise `gateway.multiplex_profiles`, le profil doit être indiqué dans l’URL :

```python
API_URL = "http://127.0.0.1:8642/p/migration/v1/chat/completions"
```

Le préfixe `/p/migration/` sélectionne explicitement le profil `migration`.

Exemple :

```python
response = requests.post(
    "http://127.0.0.1:8642/p/migration/v1/chat/completions",
    headers={
        "Authorization": f"Bearer {os.environ['API_SERVER_KEY']}",
        "Content-Type": "application/json",
    },
    json={
        "model": "hermes-agent",
        "messages": [
            {
                "role": "user",
                "content": "Liste les tables PostgreSQL de migration.",
            }
        ],
    },
    timeout=300,
)

response.raise_for_status()
print(response.json()["choices"][0]["message"]["content"])
```

## 6. Vérifier l’API

Vérifier les modèles disponibles :

```bash
curl \
  -H "Authorization: Bearer $API_SERVER_KEY" \
  http://127.0.0.1:8642/v1/models
```

Vérifier le MCP PostgreSQL du profil :

```bash
HERMES_HOME=/opt/data/profiles/migration \
/opt/hermes/.venv/bin/hermes mcp list
```

Tester la connexion MCP :

```bash
HERMES_HOME=/opt/data/profiles/migration \
/opt/hermes/.venv/bin/hermes mcp test postgres
```

## 7. Résumé du flux

```text
Python
  |
  | POST /v1/chat/completions
  v
Hermes API
  |
  | Profil migration
  v
Agent Hermes
  |
  | mcp_postgres_query
  v
Base PostgreSQL
```

Le script Python n’a pas besoin de connaître l’URI ou le mot de passe PostgreSQL. Ces informations restent dans la configuration MCP du profil Hermes `migration`.
