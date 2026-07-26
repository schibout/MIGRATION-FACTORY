# Gestion des Colonnes Système

## Description

L'application masque automatiquement certaines colonnes système des tables IFS pour améliorer la lisibilité des données métier et faciliter l'analyse des données. Ces colonnes système sont généralement utilisées pour le suivi technique et l'audit, mais ne sont pas pertinentes pour la plupart des utilisateurs métier.

## Colonnes Système Masquées par Défaut

Les colonnes suivantes sont considérées comme des colonnes système et sont masquées par défaut :

- `created_timestamp` - Date et heure de création de l'enregistrement
- `updated_timestamp` - Date et heure de la dernière mise à jour
- `created_by` - Identifiant de l'utilisateur ayant créé l'enregistrement
- `updated_by` - Identifiant de l'utilisateur ayant modifié l'enregistrement en dernier
- `is_deleted` - Indicateur de suppression logique

## Comportement de l'API

### Endpoints concernés

- `GET /ifs-tables/<table_name>/columns` - Retourne la liste des colonnes d'une table
- `GET /ifs-tables/<table_name>/data` - Retourne les données d'une table

### Paramètre de contrôle

Un paramètre de requête `includeSystemColumns` a été implémenté pour contrôler l'affichage des colonnes système :

- `includeSystemColumns=false` (défaut) : Les colonnes système sont masquées
- `includeSystemColumns=true` : Toutes les colonnes, y compris les colonnes système, sont affichées

### Exemple d'utilisation

Pour obtenir toutes les colonnes d'une table, y compris les colonnes système :
```
GET /api/data/ifs-tables/public.supplier/columns?includeSystemColumns=true
```

Pour obtenir les données d'une table avec les colonnes système :
```
GET /api/data/ifs-tables/public.supplier/data?includeSystemColumns=true&page=0&pageSize=10
```

## Implémentation Frontend

Le service frontend `ifsTablesService` a été mis à jour pour passer le paramètre `includeSystemColumns=false` par défaut lors des appels à l'API, assurant ainsi la cohérence de l'interface utilisateur.

## Considérations Techniques

- Le filtrage des colonnes système se fait au niveau de l'API pour réduire la quantité de données transférées
- Pour les requêtes SQL, lorsque `includeSystemColumns=false`, seules les colonnes non-système sont explicitement listées dans la clause SELECT
- Cette approche optimise les performances en réduisant la quantité de données traitées
