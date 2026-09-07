# Import des listes SharePoint

Ce guide explique comment récupérer les items des listes SharePoint et les exporter en CSV.

## Prérequis
- Python 3.8+
- pip

## Installer les dépendances (PowerShell):

```powershell
pip install requests
# Si vous utilisez NTLM (auth Windows), installez aussi:
pip install requests-ntlm
```

## 1. Découvrir les listes disponibles

**IMPORTANT** : Avant d'importer des données, listez d'abord les listes disponibles sur votre site SharePoint.

```powershell
# Lister toutes les listes du site SharePoint
python .\list_sharepoint_lists.py --site "http://asap.stjn.local" --auth ntlm --username "DOMAIN\\user" --password "pass"

# Sans authentification (si le site est ouvert)
python .\list_sharepoint_lists.py --site "http://asap.stjn.local"
```

Ce script affichera :
- Le titre exact de chaque liste
- Le nombre d'items
- L'URL de l'API REST à utiliser pour l'import

## 2. Listes disponibles sur votre site

### Liste "Projets"
URL : `http://asap.stjn.local/_api/web/lists/getByTitle('Projets')/items`

### Liste "Tasks" (Tâches)
URL : `http://asap.stjn.local/_api/web/lists/getByTitle('Tasks')/items`

### Liste "TachesProjets"
URL : `http://asap.stjn.local/_api/web/lists/getByTitle('TachesProjets')/items`

## 3. Exemples d'exécution (PowerShell)

### Import des Projets

```powershell
# Utilisation sans auth (site ouvert pour le réseau interne):
python .\import_projets_sharepoint.py --url "http://asap.stjn.local/_api/web/lists/getByTitle('Projets')/items" --out Projets.csv

# Avec authentification Basic:
python .\import_projets_sharepoint.py --auth basic --username "user@example.com" --password "MyPass" --out Projets.csv

# Avec NTLM (DOMAIN\\user) — pour SharePoint on-prem Windows:
python .\import_projets_sharepoint.py --auth ntlm --username "DOMAIN\\user" --password "MyPass" --out Projets.csv
```

### Import d'une autre liste

Une fois que vous avez trouvé le nom exact de la liste via `list_sharepoint_lists.py`, utilisez :

```powershell
# Exemple avec une liste nommée "TachesProjets" ou "Tasks"
python .\import_projets_sharepoint.py --url "http://asap.stjn.local/_api/web/lists/getByTitle('NomExactDeLaListe')/items" --out MaListe.csv --auth ntlm --username "DOMAIN\\user" --password "pass"
```

## Notes
- Si vous avez besoin d'importer vers une base de données, vous pouvez lire le CSV généré puis l'insérer via vos scripts habituels.
- Pour des environnements plus sécurisés (OAuth / App-Only), adaptez le script pour ajouter le header Authorization: Bearer <token> ou utilisez une bibliothèque plus adaptée.

## Problèmes courants
- Erreur 401/403 : vérifier méthode d'authentification et droits sur la liste.
- Response non-JSON : assurez-vous que l'endpoint est correct et accessible depuis votre machine.

## Options avancées
Si vous voulez, je peux :
- Ajouter une option pour écrire directement dans la base de données du projet.
- Filtrer les champs retournés ou normaliser les colonnes du CSV.

Exemple de URL
http://asap.stjn.local/_api/web/lists/getByTitle('Idées')/items
http://asap.stjn.local/_api/web/lists/getByTitle('ImportZCOA')/items
http://asap.stjn.local/_api/web/lists/getByTitle('Projets')/items
http://asap.stjn.local/_api/web/lists/getByTitle('Rapports')/items
http://asap.stjn.local/_api/web/lists/getByTitle('Ressources')/items
http://asap.stjn.local/_api/web/lists/getByTitle('Documents')/items
http://asap.stjn.local/_api/web/lists/getByTitle('Pages du site')/items
http://asap.stjn.local/_api/web/lists/getByTitle('Pièces jointes')/items


#	Titre	EntityTypeName	BaseTemplate	ItemCount	Hidden
1	appdata	OData__x005f_catalogs_x002f_appdata	125	0	✓
2	Bibliothèque de styles	Style_x0020_Library	101	11	
3	Documents (Documents partages)	Documents_x0020_partages	101	9	
4	Galerie de composants WebPart	OData__x005f_catalogs_x002f_wp	113	33	✓
5	Galerie Modèles de listes	OData__x005f_catalogs_x002f_lt	114	2	✓
6	Galerie Pages maîtres	OData__x005f_catalogs_x002f_masterpage	116	82	✓
7	Galerie Solutions	OData__x005f_catalogs_x002f_solutions	121	10	✓
8	Galerie Thèmes	OData__x005f_catalogs_x002f_theme	123	94	✓
9	Idées	IdesList	100	128	
10	ImportZCOA	ImportZCOAList	100	0	
11	Page d'accueil	HomepageList	170	9	
12	Pages du site	SitePages	119	25	
13	Pièces jointes (SiteAssets)	SiteAssets	101	8	
14	Présentations composées	OData__x005f_catalogs_x002f_design	124	18	✓
15	Projets	ProjectsList	10001	1122	
16	Rapports	ReportingList	101	37	
17	Rapports feuille de temps	TimesheetReportsList	170	6	
18	Rapports plan de charge prévisionnel	CapacityPlanningReportsList	170	2	
19	Rapports plan de charge prévisionnel interne	CapacityPlanningInternalReportsList	170	3	
20	Rapports projet	ProjectReportsList	170	7	
21	Ressources	ResourcesList	10016	488	