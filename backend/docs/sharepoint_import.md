# Import SharePoint - Documentation

## Vue d'ensemble

Ce module permet d'importer les données des projets depuis l'API SharePoint vers les tables `raw_data` existantes.

## Architecture

### Services
- **SharePointService** : Gère la connexion et l'import depuis SharePoint
- **Endpoints API** : Exposent les fonctionnalités d'import via REST

### Tables cibles
- `raw_data.sharepoint_projets` : Table principale des projets
- `raw_data.sharepoint_projets_budgets` : Budgets des projets (à implémenter)
- `raw_data.sharepoint_projets_phases` : Phases des projets (à implémenter)

## Utilisation

### 1. Test de connexion

Vérifiez que la connexion à SharePoint fonctionne :

**Mode local (sans authentification) :**
```bash
curl -X GET http://10.190.100.58:8080/api/v1/import/projets/test-connection \
  -H "Content-Type: application/json"
```

**Mode production (avec JWT) :**
```bash
curl -X GET http://10.190.100.58:8080/api/v1/import/projets/test-connection \
  -H "Authorization: Bearer YOUR_JWT_TOKEN"
```

Réponse attendue :
```json
{
  "success": true,
  "message": "Connexion SharePoint OK",
  "url": "http://asap.stjn.local/_api/web/lists/getByTitle('Projets')/items",
  "sample_count": 1,
  "status_code": 200,
  "sample_data": { ... }
}
```

### 2. Import des projets

Importez les projets depuis SharePoint :

```bash
curl -X POST http://10.190.100.58:8080/api/v1/import/projets \
  -H "Authorization: Bearer YOUR_JWT_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "limit": 1000,
    "filters": {
      "Status": "Active"
    }
  }'
```

Paramètres disponibles :
- `limit` : Nombre maximum de projets à importer (défaut: 1000)
- `filters` : Filtres SharePoint (optionnel)

**Note importante** : Par défaut, l'import **exclut automatiquement** les projets avec les statuts 'Clôturé' et 'Annulé'. Seuls les projets actifs sont importés.

Réponse :
```json
{
  "message": "Import des projets SharePoint terminé",
  "result": {
    "success": true,
    "imported_count": 150,
    "errors": []
  }
}
```

### 3. Vérification du statut

Consultez le statut de l'import :

```bash
curl -X GET http://10.190.100.58:8080/api/v1/import/projets/status \
  -H "Authorization: Bearer YOUR_JWT_TOKEN"
```

Réponse :
```json
{
  "total_projets": 150,
  "derniere_sync": "2024-01-15T10:30:00",
  "sync_recente": 150,
  "premiere_import": "2024-01-15T09:00:00",
  "dernier_import": "2024-01-15T10:30:00",
  "status": "ok"
}
```

## Configuration

### URL SharePoint

Par défaut, l'URL SharePoint est configurée sur `http://asap.stjn.local`.

Pour modifier :
```python
service = SharePointService("http://votre-sharepoint.local")
```

### Filtres SharePoint

Utilisez la syntaxe OData pour filtrer :

```json
{
  "filters": {
    "Status": "Active",
    "Category": "Development"
  }
}
```

Génère le filtre : `Status eq 'Active' and Category eq 'Development'`

## Structure des données

### Table raw_data.sharepoint_projets

La table stocke les données des projets SharePoint avec **des colonnes structurées pour les champs importants** et **un champ JSONB pour la flexibilité**.

#### Colonnes principales

| Colonne | Type | Description |
|---------|------|-------------|
| id | SERIAL | Clé primaire auto-incrémentée |
| sharepoint_id | INTEGER | ID du projet dans SharePoint (unique, NOT NULL) |
| title | TEXT | Titre du projet |
| code | TEXT | Code SAP du projet (ex: SN.16044) |
| project_number | TEXT | Numéro du projet (ex: 16.001) |
| description | TEXT | Description détaillée du projet |

#### Statut et progression

| Colonne | Type | Description |
|---------|------|-------------|
| global_status | TEXT | Statut global (Clôturé, En cours, etc.) |
| phase_text | TEXT | Phase actuelle du projet |
| percent_completed | NUMERIC(5,2) | Pourcentage d'avancement (0-100) |
| health | TEXT | Indicateur de santé du projet |
| planning | TEXT | Indicateur planning |
| cost | TEXT | Indicateur coût |

#### Dates importantes

| Colonne | Type | Description |
|---------|------|-------------|
| start_date | TIMESTAMP | Date de démarrage du projet |
| estimated_end_date | TIMESTAMP | Date de fin estimée |
| last_status_report_date | TIMESTAMP | Dernière date de rapport de statut |
| opening_date | TIMESTAMP | Date d'ouverture du projet |
| modified | TIMESTAMP | Date de dernière modification SharePoint |
| created | TIMESTAMP | Date de création SharePoint |
| imported_at | TIMESTAMP | Date/heure d'import dans PostgreSQL |

#### Budget

| Colonne | Type | Description |
|---------|------|-------------|
| budget_initial | NUMERIC(15,2) | Budget initial |
| budget_total_sap | NUMERIC(15,2) | Budget total SAP |
| budget_actual | NUMERIC(15,2) | Budget réel dépensé |
| budget_at_completion | NUMERIC(15,2) | Budget à l'achèvement |
| budget_demanded | NUMERIC(15,2) | Budget demandé |
| budget_delivered | NUMERIC(15,2) | Budget livré |
| budget_im_sap | NUMERIC(15,2) | Budget IM SAP |
| budget_ex_sap | NUMERIC(15,2) | Budget EX SAP |

#### Organisation

| Colonne | Type | Description |
|---------|------|-------------|
| sector | TEXT | Secteur (Fonderie, Carbone, etc.) |
| group_name | TEXT | Groupe/Site (Saint Jean de Maurienne, etc.) |
| template | TEXT | Template du projet (Petit projet, Grand projet, etc.) |

#### IDs de référence

| Colonne | Type | Description |
|---------|------|-------------|
| pm_id | INTEGER | ID du Chef de projet |
| client_correspondent_id | INTEGER | ID du correspondant client |
| project_team_id | INTEGER | ID de l'équipe projet |
| sponsor_id | INTEGER | ID du sponsor |
| acheteur_capex_id | INTEGER | ID de l'acheteur CAPEX |
| maintenance_correspondent_id | INTEGER | ID du correspondant maintenance |
| author_id | INTEGER | ID de l'auteur |
| editor_id | INTEGER | ID du dernier éditeur |

#### Jalons (Gates)

| Colonne | Type | Description |
|---------|------|-------------|
| passing_gate | TEXT | Jalon en cours de validation (P0-P6) |
| end_p0 à end_p6 | TIMESTAMP | Dates de fin de chaque phase |
| last_milestone_passed | TIMESTAMP | Dernier jalon franchi |

#### Autres champs importants

| Colonne | Type | Description |
|---------|------|-------------|
| raw_data | JSONB | **Données brutes complètes en JSON** (pour flexibilité) |
| site_url | TEXT | URL SharePoint du projet |
| validation_id | TEXT | ID de validation SharePoint |
| guid | TEXT | GUID SharePoint |
| project_ahead | BOOLEAN | Projet en avance |
| retroplanning | BOOLEAN | Rétro-planning actif |
| attachments | BOOLEAN | Présence de pièces jointes |

#### Indexes

Pour optimiser les performances, les index suivants sont créés :
- Index unique sur `sharepoint_id`
- Index sur `code`, `project_number`, `global_status`, `sector`
- Index sur `imported_at` pour filtrage temporel
- Index GIN sur `raw_data` pour requêtes JSONB

**Note :** Voir le fichier de migration `backend/migrations/006_add_sharepoint_projets_columns.sql` pour le schéma SQL complet.

### Exemple de données raw_data

```json
{
  "ID": 123,
  "Title": "Projet Migration",
  "Description": "Migration des données...",
  "Status": "Active",
  "StartDate": "2024-01-15T00:00:00Z",
  "EndDate": "2024-06-15T00:00:00Z",
  "ProjectManager": "John Doe",
  "Client": "Acme Corp",
  "Budget": 50000,
  "Priority": "High",
  "Category": "IT"
}
```

## Tests

### Script de test automatique

Exécutez le script de test :

```bash
cd backend
python test_sharepoint_import.py
```

Tests effectués :
1. ✅ Connexion SharePoint
2. ✅ Import de projets (échantillon)
3. ✅ Statut des tables
4. ✅ Endpoints API

### Tests manuels

1. **Test de connexion** :
   ```bash
   python -c "
   from services.sharepoint_service import SharePointService
   service = SharePointService()
   print(service.test_connection())
   "
   ```

2. **Test d'import** :
   ```bash
   python -c "
   from services.sharepoint_service import SharePointService
   service = SharePointService()
   result = service.import_projets_from_sharepoint(top=5)
   print(f'Importé: {result[\"imported_count\"]} projets')
   "
   ```

## Dépannage

### Erreurs courantes

**Erreur de connexion SharePoint** :
```
Erreur de connexion à SharePoint: HTTPConnectionPool...
```
- Vérifiez l'URL SharePoint
- Vérifiez la connectivité réseau
- Vérifiez les permissions d'accès

**Erreur de base de données** :
```
Erreur import base de données: relation "raw_data.sharepoint_projets" does not exist
```
- Assurez-vous que la table existe
- Vérifiez les permissions de la base
- Vérifiez la configuration de connexion

**Erreur de parsing JSON** :
```
Expecting value: line 1 column 1 (char 0)
```
- Vérifiez la réponse SharePoint
- L'API peut retourner du HTML au lieu de JSON en cas d'erreur

### Logs

Les logs détaillés sont disponibles dans les fichiers de log de l'application :

```bash
# Logs de l'application
tail -f logs/app.log | grep SharePoint

# Logs spécifiques à l'import
tail -f logs/app.log | grep "import projets"
```

## Extensions futures

### Tables budgets et phases

Le service est préparé pour étendre l'import vers :
- `raw_data.sharepoint_projets_budgets`
- `raw_data.sharepoint_projets_phases`

Ces fonctionnalités peuvent être implémentées en étendant les méthodes :
- `_process_budgets()`
- `_process_phases()`

### Authentification SharePoint

Pour ajouter l'authentification :
```python
self.session.auth = ('username', 'password')
# ou
self.session.headers['Authorization'] = 'Bearer TOKEN'
```

### Filtres avancés

Support pour des filtres OData plus complexes :
```python
sharepoint_params['filter'] = "startswith(Title,'Projet') and Year gt 2023"
```

## Support

Pour toute question ou problème :
1. Vérifiez les logs
2. Exécutez le script de test
3. Consultez la documentation SharePoint REST API
