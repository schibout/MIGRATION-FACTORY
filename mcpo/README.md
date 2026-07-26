# Outils MCP pour Open WebUI (mcpo + Ollama)

Dossier d'installation pour exposer des **serveurs MCP** comme outils dans
**Open WebUI**, via le proxy **mcpo** (MCP → OpenAPI), branché sur Ollama.

```
Open WebUI ──HTTP/OpenAPI──> mcpo ──MCP──> postgres / fetch / time
  :3001                       :8000
        \__________ Ollama (:11434) __________/
```

## Contenu du dossier

| Fichier                          | Rôle |
|----------------------------------|------|
| `deploytool.sh`                  | Script de déploiement (mcpo + Open WebUI) |
| `.env.example`                   | Modèle de configuration (à copier en `.env`) |
| `mcp-config.json`                | Exemple de configuration des serveurs MCP |
| `create_mcp_readonly_user.sql`   | Crée un compte PostgreSQL **lecture seule** pour l'IA |
| `.gitignore`                     | Exclut `.env` et la config générée |

> `mcp-config.runtime.json` est généré automatiquement par le script à partir
> du `.env` (le mot de passe n'est jamais committé).

## Installation (sur le serveur 10.190.100.58)

```bash
cd mcpo

# 1. Compte PostgreSQL lecture seule (recommandé)
#    Adapter le mot de passe 'CHANGE_ME' dans le fichier .sql au préalable.
psql -h 10.190.100.58 -U postgres -d sap_migration_db -f create_mcp_readonly_user.sql

# 2. Configuration
cp .env.example .env
nano .env          # renseigner PG_PASSWORD, MCPO_API_KEY, etc.

# 3. Déploiement
chmod +x deploytool.sh
./deploytool.sh            # lance mcpo + Open WebUI
```

Autres commandes :

```bash
./deploytool.sh --mcpo     # mcpo seul
./deploytool.sh --webui    # Open WebUI seul
./deploytool.sh --logs     # logs des deux conteneurs
./deploytool.sh --down     # arrêt + suppression (volumes conservés)
```

## Déclarer les outils dans Open WebUI

1. Ouvrir http://10.190.100.58:3001
2. **Settings → Tools → +**
3. URL : `http://mcpo:8000/postgres` (même réseau Docker `ia-net`)
   - depuis l'extérieur : `http://10.190.100.58:8000/postgres`
4. Auth : **Bearer** → la valeur de `MCPO_API_KEY`
5. Répéter pour `/fetch` et `/time`.
6. Dans une conversation, activer l'outil via l'icône 🔧.

Swagger de vérification : http://10.190.100.58:8000/docs

## Sécurité ⚠️

- Le serveur MCP `postgres` donne au LLM un accès SQL direct : utiliser
  **impérativement** le compte `mcp_ro` (lecture seule) créé par le `.sql`.
- Protéger mcpo par `MCPO_API_KEY` (déjà appliqué par le script).
- Ne jamais committer `.env` ni `mcp-config.runtime.json` (déjà dans `.gitignore`).
- Le modèle `qwen2.5-coder` tourne sur CPU (~3 tok/s) : les enchaînements
  outil → réponse peuvent être lents.
