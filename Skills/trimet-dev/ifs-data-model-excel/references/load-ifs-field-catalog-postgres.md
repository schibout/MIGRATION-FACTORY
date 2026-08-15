# Chargement du catalogue champs IFS vers PostgreSQL

Contexte : les fichiers Excel IFS de `/opt/data/ifs_files` sont déjà consolidés dans `/opt/data/ifs_model_analysis/ifs_fields_catalog.csv`. Pour alimenter `public.ifs_field_catalog`, partir de ce CSV consolidé plutôt que de reparcourir tous les `.xlsx`.

Table cible observée : `public.ifs_field_catalog`.

Colonnes clés :

- `lot_id` : déduit du préfixe fichier `LotNN` en majuscule (`LOT09`, `LOT11`, etc.).
- `entity` : `target_table` du CSV.
- `field_name` : `field_name` du CSV.
- Contrainte unique : `(lot_id, entity, field_name)`.
- `catalog_id` : identity ALWAYS, ne pas fournir de valeur explicite.

Mapping utile depuis `ifs_fields_catalog.csv` :

- `file` -> `source_file`
- `target_table` -> `entity`
- `field_name` -> `field_name`
- `field_label_fr` sinon `field_label` -> `field_label_fr`
- `data_type` -> `data_type`
- `data_length` -> `data_length` integer nullable
- `rnd_flags` -> `rnd_flags`
- `mandatory`, `insertable`, `updatable`, `primary_key`, `lov`, `in_scope` -> booléens
- `default_value` -> `default_value`
- `description` -> `transformation_rules` si pas d'autre règle dédiée
- `comments` sinon `description` -> `comments`
- `source_system/source_table/source_field/source_type` -> chaîne synthétique `reference`
- `sort_order` : numéro de ligne CSV ou ordre stable dans le fichier

Gestion des doublons : le CSV consolidé peut avoir beaucoup plus de lignes que la table cible à cause des variantes/fichiers Final/(1)/Vx. Dédupliquer par `(lot_id, entity, field_name)` avant insertion. Si plusieurs lignes existent, privilégier les fichiers contenant `Final`, pénaliser les copies `(1)`, puis garder la ligne la plus complète.

Connexion PostgreSQL : si psycopg n'est pas installé globalement, utiliser `uv run --with 'psycopg[binary]' --with pyyaml python ...`. Le DSN MCP Postgres peut être lu depuis `/opt/data/config.yaml` : `mcp_servers.postgres.args[-1]` ou `postgres.args[-1]` selon la forme du fichier.

Pattern SQL recommandé :

- Ne pas insérer `catalog_id`.
- Utiliser `INSERT ... ON CONFLICT ON CONSTRAINT uq_ifs_field_catalog DO UPDATE SET ... loaded_at=now()`.
- Vérifier après chargement :
  - `SELECT count(*) FROM public.ifs_field_catalog;`
  - `SELECT count(source_file) FROM public.ifs_field_catalog;`
  - `SELECT count(DISTINCT (lot_id, entity, field_name)) FROM public.ifs_field_catalog;`
  - `SELECT lot_id, count(*) FROM public.ifs_field_catalog GROUP BY lot_id ORDER BY lot_id;`

Résultat de référence lors du chargement du 2026-07-09 :

- CSV source : 21 766 lignes valides.
- Après déduplication par contrainte unique : 12 969 enregistrements chargés.
- Toutes les lignes chargées avaient `source_file` renseigné.
