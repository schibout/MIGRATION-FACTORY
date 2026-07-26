# sql/ai — Connaissance projet pour l'Assistant IA (config RAG)

Scripts d'alimentation des tables de configuration qui pilotent le RAG de
l'Assistant IA (page **Configuration IA**, `http://10.190.100.58:3000/configuration-ia`).

Ils **ajoutent la couverture des tables cibles IFS (`clean_data`)** — absentes
de la config initiale, qui ne couvrait que les tables sources SAP (`raw_data`).

## Contenu

| Fichier | Cible | Effet |
|---|---|---|
| `01_ifs_domain_tables.sql` | `public.ai_domain_tables` | Associations mot-clé → tables `clean_data` (5 domaines `ifs_*`) |
| `02_ifs_packs.sql` | `public.ai_packs` | Packs de connaissances (jointures, valeurs, règles, requêtes-types) pour ces 5 domaines |

12 domaines IFS ajoutés :

| Domaine | Tables principales `clean_data` |
|---|---|
| `ifs_articles` | part_catalog, inventory_part, purchase_part, sales_part |
| `ifs_fournisseurs` | supplier, supplier_info_general (mapping LIFNR→vendor_no) |
| `ifs_clients` | ifs_customer |
| `ifs_projet` | project_base, sub_project, project_activity, project_role_assignment |
| `ifs_personnes` | ifs_person, project_role_assignment |
| `ifs_maintenance` | maintenance_object (hiérarchie), equipment_functional |
| `ifs_pm_actions` | pm_action + resource/work_step/job (clé pm_no+pm_revision) |
| `ifs_article_maitre` | ifs_article_maitre (synthèse dénormalisée) |
| `ifs_taxes` | supplier_tax_info, customer_tax_info |
| `ifs_adresses` | supplier_address, customer_info_address |
| `ifs_paiement` | identity_pay_info, payment_address, income_type_per_identity |
| `ifs_ressources` | maint_person_resource, resource_availability |

Tout le contenu est **ancré sur la structure réelle** : colonnes et **jointures
vérifiées en base** le 2026-07-07 — pas de colonne ni de jointure inventée
(plusieurs jointures « évidentes » se sont révélées fausses à la vérification et
ont été écartées).

## Idempotence

- `01` : `DELETE` puis `INSERT` des seuls domaines `ifs_*` (ne touche pas la
  config SAP existante). Rejouable.
- `02` : `INSERT ... ON CONFLICT (domain) DO UPDATE`. Rejouable.

## Application (sur le serveur)

Comme les autres modules, via `compile.sh` (depuis le dossier `sql/ai/`) :

```bash
cd sql/ai && ./compile.sh
```

Le script exécute les deux fichiers dans l'ordre (domaines puis packs), vérifie
le nombre d'objets `ifs_*` insérés, et rappelle la réindexation.

Équivalent manuel :

```bash
# 1. Charger la config (prend effet sous 60 s via le cache TTL d'ai_config_store)
psql "$DATABASE_URL" -f sql/ai/01_ifs_domain_tables.sql
psql "$DATABASE_URL" -f sql/ai/02_ifs_packs.sql

# 2. Réindexer pour la recherche sémantique (tables clean_data + cards des packs).
#    NÉCESSITE Ollama/bge-m3 (serveur). Voir build_ai_index.py.
docker-compose exec backend python build_ai_index.py --only tables      # inclut clean_data
docker-compose exec backend python build_ai_index.py --only knowledge   # cards derivees des packs
```

> Les packs et les domaines sont lus **en direct** (cache 60 s) : effet quasi
> immédiat sur la génération. La **réindexation** ne sert qu'au classement
> sémantique (few-shots / tables / cards) — utile mais non bloquant.

## Vérification

Après application, onglets **Domaines & mots-clés** et **Packs** de Configuration IA :
les 5 domaines `ifs_*` doivent apparaître. Onglet **Inspecteur**, tester par ex.
« nombre d'articles dans le catalogue IFS » → doit retrouver `clean_data.part_catalog`.
