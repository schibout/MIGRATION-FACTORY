# Problème : Open WebUI + mcpo — le modèle n'appelle pas les outils MCP/OpenAPI

## Objectif
Faire en sorte que le modèle **qwen2.5-coder:7b** (servi par Ollama) appelle
réellement les outils exposés via **mcpo** (proxy MCP → OpenAPI) dans
**Open WebUI**, au lieu de répondre « je ne peux pas accéder à une base de
données / exécuter des requêtes SQL ».

## Stack et environnement
- Serveur Linux unique : `10.190.100.58` (hôte FRSJMTAL1, 31 Go RAM, CPU only).
- **Ollama** installé sur l'hôte : `http://10.190.100.58:11434`.
  - Modèles : `qwen2.5-coder:7b` (génération SQL), `bge-m3` (embeddings).
  - Vitesse ~3 tokens/s (CPU, pas de GPU).
- **PostgreSQL** installé sur l'hôte (pas en conteneur) : `10.190.100.58:5432`,
  base `sap_migration_db`, user `postgres`.
- **Docker** : conteneurs `open-webui` (image `ghcr.io/open-webui/open-webui:main`,
  port hôte 3001→8080) et `mcpo` (image `ghcr.io/open-webui/mcpo:main`,
  port hôte 8800→8000), tous deux sur le réseau Docker `ia-net`.
- mcpo lancé avec `--api-key "trimet-mcp-CHANGE_ME"` et un fichier de config
  exposant 3 serveurs MCP : `postgres` (paquet `postgres-mcp`, mode unrestricted,
  `DATABASE_URI` vers la base), `fetch` (`mcp-server-fetch`),
  `time` (`mcp-server-time`).

## Ce qui FONCTIONNE déjà (validé)
1. mcpo démarre et se connecte aux 3 serveurs MCP. Logs :
   ```
   Successfully connected to: postgres, fetch, time
   Uvicorn running on http://0.0.0.0:8000
   PostgreSQL MCP Server ... Successfully connected to database
   ```
2. `pg_hba.conf` a été corrigé pour autoriser le réseau Docker
   (`host all all 172.16.0.0/12 md5` + `pg_reload_conf()`), donc `postgres-mcp`
   se connecte bien à la base.
3. Les routes OpenAPI répondent :
   - `http://10.190.100.58:8800/postgres/openapi.json` → JSON OpenAPI valide.
   - `/postgres/docs`, `/fetch/docs`, `/time/docs` → Swagger OK.
   - (la racine `/postgres/` renvoie `{"detail":"Not Found"}`, ce qui est normal.)
4. Dans Open WebUI : **Settings → Tools** (profil utilisateur), les 3 serveurs
   OpenAPI sont enregistrés. Le bouton refresh affiche **statut vert « 200 OK »**.
5. Depuis le conteneur open-webui, `curl` vers mcpo (par IP hôte `:8800` et par
   nom `mcpo:8000`) renvoie 200 avec le header `Authorization: Bearer ...`.

## Ce qui NE FONCTIONNE PAS
- Quand on demande au modèle, par ex. :
  « Exécute cette requête SQL via l'outil postgres : `SELECT COUNT(*) FROM raw_data.kna1;` »
  → le modèle répond qu'il **ne peut pas** accéder à une base / exécuter du SQL,
  **sans jamais émettre d'appel d'outil** (aucun bloc « Tool called », aucune
  requête HTTP vers mcpo dans les logs au moment du chat).
- Le sélecteur **Controls → Valves → Tools → « Select a tool »** est **vide/grisé**
  (mais c'est apparemment réservé aux outils Python natifs du Workspace, pas aux
  OpenAPI Tool Servers).
- **Advanced Params → Function Calling** est actuellement sur **Default**.

## Questions / aide demandée
1. Avec un **OpenAPI Tool Server** (mcpo) enregistré dans *Settings → Tools* et au
   statut vert, **comment forcer Open WebUI à exposer ces outils au modèle** pour
   une conversation ? Faut-il une activation par chat, un réglage global, ou est-ce
   automatique ?
2. Quel **mode Function Calling** utiliser pour Ollama + `qwen2.5-coder:7b` :
   **Native** ou **Default** ? Lequel est compatible avec les OpenAPI Tool Servers ?
3. Comment **vérifier que le modèle a bien la capability `tools`** côté Ollama, et
   que faire s'il ne l'a pas ?
4. Pourquoi le modèle répond « je ne peux pas » au lieu d'appeler l'outil alors que
   la connexion est verte (200 OK) ? Est-ce un problème de mode, de modèle, de
   prompt système, ou de version d'Open WebUI ?
5. Y a-t-il une étape spécifique (icône « tool servers / prise » dans la barre de
   chat, toggle par message, system prompt particulier) qui manque pour déclencher
   l'appel d'outil ?

## Contraintes
- Tout tourne sur CPU (lent). Pas de GPU, pas de changement d'infra majeur souhaité.
- Solution privilégiée : configuration Open WebUI / Ollama, sans réécrire mcpo.
- Donne des étapes concrètes et, si possible, comment vérifier chaque étape
  (logs, curl, UI).
```
