# Migration vers un Système d'Export Dynamique

Ce guide explique comment migrer du système d'export avec requêtes hardcodées vers un système dynamique utilisant une table de base de données.

## 🎯 Objectifs

- ✅ Remplacer les requêtes SQL hardcodées par des requêtes stockées en base
- ✅ Permettre la gestion dynamique des requêtes sans redéploiement
- ✅ Ajouter une interface d'administration pour gérer les requêtes
- ✅ Améliorer la maintenabilité et la flexibilité

## 📋 Étapes de Migration

### 1. Base de Données

**Exécuter la migration SQL :**
```bash
# Appliquer la migration
psql -d votre_db -f backend/migrations/003_create_etl_export_queries.sqloi
```

La migration créera la table `etl_export_queries` et y insérera toutes les requêtes existantes.

### 2. Backend

**Ajouter l'endpoint d'export :**
```bash
# Créer le nouveau blueprint
# Le fichier backend/api/export.py a été créé avec tous les endpoints nécessaires
```

**Enregistrer le blueprint dans votre app Flask :**
```python
# Dans votre fichier principal (app.py ou __init__.py)
from api.export import export_blueprint

app.register_blueprint(export_blueprint, url_prefix='/api/v1/export')
```

### 3. Frontend

**Les fichiers suivants ont été modifiés :**
- `frontend/src/services/exportService.ts` - Service principal avec cache
- `frontend/src/pages/ExportFournisseurs.tsx` - Page principale mise à jour
- `frontend/src/components/export/TableSelector.tsx` - Sélection dynamique
- `frontend/src/components/export/ExportPreview.tsx` - Aperçu dynamique

**Interface d'administration (optionnelle) :**
- `frontend/src/pages/admin/ExportQueriesManagement.tsx` - CRUD des requêtes

## 🔄 Nouveau Flux d'Export

```mermaid
graph TD
    A[Utilisateur clique Export] --> B[Chargement des requêtes depuis API]
    B --> C[Cache local des requêtes 5min]
    C --> D[Sélection des tables]
    D --> E[Exécution via /export/queries/{table}/execute]
    E --> F[Téléchargement du fichier]
    
    G[Admin modifie requête] --> H[Invalidation du cache]
    H --> I[Rechargement automatique]
```

## 🆕 Nouvelles Fonctionnalités

### Cache Intelligent
- **Cache local** : 5 minutes pour éviter les appels répétés
- **Invalidation automatique** : lors des modifications admin
- **Refresh manuel** : bouton "Actualiser" disponible

### Organisation par Catégories
- **supplier** : Tables fournisseurs principales
- **payment** : Tables de paiement
- **tax** : Tables fiscales
- **communication** : Tables de communication
- **contact** : Tables de contacts

### Interface Admin
- **CRUD complet** : Créer, modifier, supprimer des requêtes
- **Visualisation SQL** : Voir et éditer les requêtes
- **Activation/Désactivation** : Contrôler la disponibilité
- **Validation** : Vérification de la syntaxe SQL

## 🔌 API Endpoints

### GET `/api/v1/export/queries`
```javascript
// Récupérer toutes les requêtes
const response = await api.get('/export/queries?category=supplier');
```

### GET `/api/v1/export/queries/{table_name}`
```javascript
// Récupérer une requête spécifique
const response = await api.get('/export/queries/SUPPLIER');
```

### POST `/api/v1/export/queries/{table_name}/execute`
```javascript
// Exécuter une requête
const response = await api.post('/export/queries/SUPPLIER/execute');
```

### POST `/api/v1/export/queries`
```javascript
// Créer une nouvelle requête
const response = await api.post('/export/queries', {
  table_name: 'NEW_TABLE',
  table_schema: 'public',
  display_name: 'Nouvelle Table',
  sql_query: 'SELECT * FROM new_table',
  category: 'supplier',
  description: 'Description...',
  is_active: true
});
```

### PUT `/api/v1/export/queries/{table_name}`
```javascript
// Modifier une requête existante
const response = await api.put('/export/queries/SUPPLIER', {
  display_name: 'Nouveau nom',
  sql_query: 'SELECT * FROM supplier WHERE active = true'
});
```

### DELETE `/api/v1/export/queries/{table_name}`
```javascript
// Supprimer une requête
const response = await api.delete('/export/queries/SUPPLIER');
```

## 💡 Utilisation

### Pour les Utilisateurs
1. **Page d'export** : Interface identique, tables chargées dynamiquement
2. **Actualisation** : Bouton pour rafraîchir la liste des tables
3. **Organisation** : Tables groupées par catégories avec couleurs

### Pour les Administrateurs
1. **Accès** : `/admin/export-queries` (à ajouter au routing)
2. **Gestion** : CRUD complet des requêtes d'export
3. **Test** : Possibilité de voir et modifier les requêtes SQL
4. **Monitoring** : Statut actif/inactif pour chaque requête

## 🚨 Points d'Attention

### Sécurité
- **Validation SQL** : Toutes les requêtes sont validées côté backend
- **Permissions** : Seuls les SELECT sont autorisés
- **Échappement** : Protection contre les injections SQL

### Performance
- **Cache** : Évite les appels répétés à l'API
- **Lazy loading** : Chargement à la demande
- **Optimisation** : Index sur table_name et category

### Migration
- **Compatibilité** : L'ancien système reste fonctionnel en parallèle
- **Rollback** : Possibilité de revenir en arrière si nécessaire
- **Test** : Valider toutes les requêtes avant mise en production

## 🧪 Tests

### Tester la Migration
```bash
# 1. Vérifier que la table existe
psql -d votre_db -c "SELECT COUNT(*) FROM etl_export_queries;"

# 2. Tester l'API
curl -X GET "http://localhost:5000/api/v1/export/queries"

# 3. Tester une exécution
curl -X POST "http://localhost:5000/api/v1/export/queries/SUPPLIER/execute"
```

### Validation Frontend
1. Ouvrir `/export-fournisseurs`
2. Vérifier le chargement des tables
3. Tester l'export d'une table
4. Vérifier le cache (actualiser la page < 5min)
5. Tester le bouton "Actualiser"

## 📈 Avantages de la Solution

### Flexibilité
- ✅ Modification des requêtes sans redéploiement
- ✅ Ajout de nouvelles tables facilement
- ✅ Désactivation temporaire possible

### Maintenabilité
- ✅ Code plus propre et modulaire
- ✅ Séparation des responsabilités
- ✅ Interface d'administration dédiée

### Performance
- ✅ Cache intelligent côté frontend
- ✅ Requêtes optimisées par catégorie
- ✅ Chargement paresseux

### Évolutivité
- ✅ Support multi-catégories
- ✅ Extensible à d'autres types d'export
- ✅ Interface d'administration complète

## 🔮 Évolutions Futures

### Prochaines Fonctionnalités
- **Scheduling** : Exports automatiques programmés
- **Templates** : Modèles de requêtes prédéfinies
- **Historique** : Suivi des modifications des requêtes
- **Permissions** : Contrôle d'accès granulaire par utilisateur
- **Monitoring** : Métriques sur l'utilisation des exports
- **Notifications** : Alertes en cas d'erreur d'export

### Support Multi-Schémas (Nouveau)
- **Colonne table_schema** : Support de plusieurs schémas de base de données
- **Schémas disponibles** : public, raw_data, transformed, analytics
- **Interface adaptée** : Sélection du schéma dans l'administration
- **Contrainte unique** : (table_schema, table_name) pour éviter les doublons
- **Migration automatique** : Toutes les tables existantes assignées au schéma 'public'

### Optimisations
- **Mise en cache Redis** : Cache distribué pour les environnements multi-instances
- **Queue system** : Traitement asynchrone pour les gros exports
- **Compression** : Compression automatique des fichiers volumineux 