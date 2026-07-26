# Migration SharePoint - Guide d'application

## Vue d'ensemble

La migration `006_add_sharepoint_projets_columns.sql` crée la table `raw_data.sharepoint_projets` avec une structure complète incluant:
- Des colonnes structurées pour tous les champs importants de SharePoint
- Un champ JSONB `raw_data` pour stocker les données brutes complètes
- Des index optimisés pour les requêtes

## ⚠️ ATTENTION

**Cette migration SUPPRIME et RECRÉE la table `raw_data.sharepoint_projets`.**

Toutes les données existantes dans cette table seront perdues. Si vous avez des données importantes:
1. Faites une sauvegarde avant d'appliquer la migration
2. Ou modifiez le script SQL pour utiliser `ALTER TABLE` au lieu de `DROP TABLE`

## Application de la migration

### Option 1: Script PowerShell (Windows)

```powershell
cd backend
.\apply_sharepoint_migration.ps1
```

Le script va:
1. Afficher la configuration de la base de données
2. Demander confirmation avant d'appliquer la migration
3. Exécuter la migration
4. Vérifier la structure de la table créée

### Option 2: Script Bash (Linux/Mac)

```bash
cd backend
chmod +x apply_sharepoint_migration.sh
./apply_sharepoint_migration.sh
```

### Option 3: psql direct

```bash
# Linux/Mac
cd backend
export PGPASSWORD="trimet2025"
psql -h 10.190.100.58 -p 5432 -U postgres -d sap_migration_db -f migrations/006_add_sharepoint_projets_columns.sql

# Windows PowerShell
cd backend
$env:PGPASSWORD = "trimet2025"
psql -h 10.190.100.58 -p 5432 -U postgres -d sap_migration_db -f migrations/006_add_sharepoint_projets_columns.sql
```

## Variables d'environnement

Vous pouvez personnaliser la configuration via des variables d'environnement:

```bash
# Linux/Mac
export DB_HOST="10.190.100.58"
export DB_PORT="5432"
export DB_NAME="sap_migration_db"
export DB_USER="postgres"
export DB_PASSWORD="trimet2025"

# Windows PowerShell
$env:DB_HOST = "10.190.100.58"
$env:DB_PORT = "5432"
$env:DB_NAME = "sap_migration_db"
$env:DB_USER = "postgres"
$env:DB_PASSWORD = "trimet2025"
```

## Vérification après migration

### 1. Vérifier la création de la table

```sql
SELECT table_name, table_schema 
FROM information_schema.tables 
WHERE table_schema = 'raw_data' 
  AND table_name = 'sharepoint_projets';
```

### 2. Vérifier les colonnes

```sql
SELECT 
    column_name, 
    data_type, 
    is_nullable,
    column_default
FROM information_schema.columns 
WHERE table_schema = 'raw_data' 
  AND table_name = 'sharepoint_projets'
ORDER BY ordinal_position;
```

### 3. Vérifier les index

```sql
SELECT 
    indexname, 
    indexdef 
FROM pg_indexes 
WHERE schemaname = 'raw_data' 
  AND tablename = 'sharepoint_projets';
```

### 4. Compter les enregistrements

```sql
SELECT COUNT(*) FROM raw_data.sharepoint_projets;
```

## Structure de la table

La table contient 60+ colonnes organisées en catégories:

### Colonnes principales
- `id`, `sharepoint_id`, `title`, `code`, `project_number`, `description`

### Statut et progression
- `global_status`, `phase_text`, `percent_completed`, `health`, `planning`, `cost`

### Dates
- `start_date`, `estimated_end_date`, `last_status_report_date`, `opening_date`
- `modified`, `created`, `imported_at`

### Budget
- `budget_initial`, `budget_total_sap`, `budget_actual`, `budget_at_completion`
- `budget_demanded`, `budget_delivered`, `budget_im_sap`, `budget_ex_sap`

### Organisation
- `sector`, `group_name`, `template`

### IDs de référence
- `pm_id`, `client_correspondent_id`, `project_team_id`, `sponsor_id`
- `acheteur_capex_id`, `maintenance_correspondent_id`, `author_id`, `editor_id`

### Jalons (Gates)
- `passing_gate`, `end_p0` à `end_p6`, `last_milestone_passed`

### Autres
- `raw_data` (JSONB) - Données brutes complètes
- `site_url`, `validation_id`, `guid`
- Flags: `project_ahead`, `retroplanning`, `attachments`

## Test de l'import

Après avoir appliqué la migration:

### 1. Redémarrer le backend

```bash
cd backend
flask run
# ou
python app.py
```

### 2. Tester la connexion SharePoint

```bash
curl -X GET http://10.190.100.58:8080/api/v1/import/projets/test-connection
```

### 3. Lancer un import de test (5 projets)

```bash
curl -X POST http://10.190.100.58:8080/api/v1/import/projets \
  -H "Content-Type: application/json" \
  -d '{"limit": 5}'
```

### 4. Vérifier les données importées

```sql
SELECT 
    sharepoint_id,
    code,
    title,
    global_status,
    sector,
    budget_total_sap,
    imported_at
FROM raw_data.sharepoint_projets
ORDER BY imported_at DESC
LIMIT 5;
```

### 5. Tester le champ JSONB

```sql
SELECT 
    sharepoint_id,
    code,
    raw_data->>'Title' as title_from_json,
    raw_data->>'Budget_x0020_Total_x0020_SAP' as budget_from_json
FROM raw_data.sharepoint_projets
LIMIT 5;
```

## Dépannage

### Erreur: "relation already exists"

Si vous obtenez cette erreur, c'est que la table existe déjà. Options:
1. Supprimer manuellement la table: `DROP TABLE IF EXISTS raw_data.sharepoint_projets CASCADE;`
2. Modifier le script de migration pour utiliser `DROP TABLE IF EXISTS`

### Erreur: "permission denied"

Assurez-vous que l'utilisateur PostgreSQL a les droits nécessaires:

```sql
GRANT ALL PRIVILEGES ON SCHEMA raw_data TO postgres;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA raw_data TO postgres;
```

### Erreur: "schema does not exist"

Le schéma `raw_data` n'existe pas. La migration devrait le créer automatiquement avec:

```sql
CREATE SCHEMA IF NOT EXISTS raw_data;
```

## Rollback (restauration)

Si vous devez annuler la migration:

```sql
-- Supprimer la table
DROP TABLE IF EXISTS raw_data.sharepoint_projets CASCADE;

-- Restaurer l'ancienne structure (si vous aviez une sauvegarde)
-- pg_restore ...
```

## Support

Pour plus d'informations, consultez:
- [Documentation SharePoint Import](../docs/sharepoint_import.md)
- [Structure de la table](../docs/sharepoint_import.md#structure-des-données)
- Service Python: `backend/services/sharepoint_service.py`
- API: `backend/api/import_api.py`


