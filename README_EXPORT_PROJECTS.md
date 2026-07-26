# Export des Projets - Nouvelle Fonctionnalité

## 🎯 Vue d'ensemble

Une nouvelle fonctionnalité d'export des projets a été ajoutée au système de migration Factory, suivant exactement la même logique que les autres exports (clients, fournisseurs, articles, maintenance).

## 🚀 Fonctionnalités

### **Frontend**
- **Page d'export** : `/export/projets`
- **Carte dans le menu principal** : Ajoutée à la page `ExportData.tsx`
- **Interface utilisateur** : Identique aux autres pages d'export
- **Sélection de tables** : Choix dynamique des tables à exporter
- **Configuration** : Options pour inclure les en-têtes et les enregistrements inactifs

### **Backend**
- **Endpoint API** : `POST /export/projects`
- **Service d'export** : Intégré avec le système existant
- **Format de sortie** : Fichier ZIP contenant les données CSV

## 📋 Tables Disponibles

Les tables suivantes sont configurées pour l'export des projets :

| Table | Description | Catégorie |
|-------|-------------|-----------|
| `PROJECT_BASE` | Projets - Informations de Base | project |
| `PROJECT_SITE_EXT` | Projets - Association Sites | project |
| `PROJECT_MARGIN_MATRIX` | Projets - Matrice des Marges | project |

## 🔧 Architecture

### **Frontend**
- **Service d'export** : `frontend/src/services/exportService.ts` - Fonction `exportProjectsData()`
- **Page d'export** : `frontend/src/pages/ExportProjects.tsx` - Interface utilisateur
- **Route** : Ajoutée dans `frontend/src/App.tsx` - Chemin : `/export/projets`

### **Backend**
- **Endpoint** : `backend/api/export.py` - Route `/projects` avec méthode POST
- **Service** : Utilise le `ExportService` existant

## 📱 Utilisation

### **Via l'Interface Web**
1. Aller à **Export des Données** dans le menu principal
2. Cliquer sur la carte **"Export Projets"**
3. Sélectionner les tables à exporter
4. Configurer les options (en-têtes, inactifs)
5. Cliquer sur **"Exporter"**
6. Le fichier ZIP sera téléchargé automatiquement

### **Via l'API**
```bash
POST /export/projects
Content-Type: application/json

{
  "selectedTables": ["PROJECT_BASE", "PROJECT_SITE_EXT"],
  "format": "zip",
  "includeHeaders": true,
  "includeInactive": false
}
```

## 🎨 Design

- **Couleur** : Violet (`#673ab7`) pour se distinguer
- **Icône** : Assignment (📋) pour représenter les projets
- **Placement** : Ajoutée à la page principale d'export

## ✅ Statut

- **Frontend** : ✅ Implémenté et testé
- **Backend** : ✅ Endpoint créé
- **Base de données** : ✅ Tables configurées
- **Interface** : ✅ Identique aux autres exports

La fonctionnalité est maintenant **entièrement intégrée** et suit exactement le même pattern que vos autres exports existants !
