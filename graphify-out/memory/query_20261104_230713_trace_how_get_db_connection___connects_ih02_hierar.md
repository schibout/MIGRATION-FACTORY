---
type: "query"
date: "2026-11-04T23:07:13.378071+00:00"
question: "Trace how get_db_connection() connects IH02 Hierarchy to Data API Functions, SharePoint Service, and AI Assistant. Show the graph nodes and edges across the communities, with sources and confidence."
contributor: "graphify"
source_nodes: ["get_db_connection()", "get_root_nodes()", "get_sharepoint_projets()", "SharePointService", "ask()"]
---

# Q: Trace how get_db_connection() connects IH02 Hierarchy to Data API Functions, SharePoint Service, and AI Assistant. Show the graph nodes and edges across the communities, with sources and confidence.

## Answer

Le graphe montre get_db_connection() dans backend/config/database.py (L53) comme point commun d’accès PostgreSQL : 200 relations calls EXTRACTED entrent dans ce nœud, depuis plusieurs modules. Exemples : api_data.get_sharepoint_projets() l’appelle (backend/api/data.py L524); ih02_hierarchy.get_root_nodes() l’appelle (backend/api/ih02_hierarchy.py L227); SharePointService._import_projets_to_database() l’appelle (backend/services/sharepoint_service.py L189); ai_assistant.ask() l’appelle (backend/api/ai_assistant.py L410). L’implémentation ouvre psycopg2 avec get_db_params(), yield la connexion puis la ferme dans finally (database.py L53–84). Ainsi, le lien entre ces communautés est un utilitaire partagé d’accès BD, pas un flux direct IH02→SharePoint→IA. Attention : l’étiquette de communauté IH02 Hierarchy sur get_db_connection() est une classification de clustering, pas une propriété architecturale. Le graphe trouve 200 appelants répartis notamment entre IH02 (31), data.py (16), maintenance reload (15), assistant IA (13), SharePoint (12) et maintenance hierarchy (12).

## Source Nodes

- get_db_connection()
- get_root_nodes()
- get_sharepoint_projets()
- SharePointService
- ask()