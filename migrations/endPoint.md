# SharePoint 2013 REST API - Guide Python

## 📋 Table des matières

- [Introduction](#introduction)
- [Installation](#installation)
- [Authentification](#authentification)
- [URL de base](#url-de-base)
- [Endpoints principaux](#endpoints-principaux)
- [Client Python](#client-python)
- [Opérations CRUD](#opérations-crud)
- [Filtrage et tri](#filtrage-et-tri)
- [Gestion des fichiers](#gestion-des-fichiers)
- [Change Queries](#change-queries)
- [Exemples pratiques](#exemples-pratiques)
- [Gestion des erreurs](#gestion-des-erreurs)

## 🎯 Introduction

L'interface REST SharePoint 2013 permet d'interagir avec SharePoint depuis Python en utilisant des requêtes HTTP standard. Cette API offre un accès programmatique aux sites, listes, bibliothèques de documents et autres ressources SharePoint.

## 📦 Installation

```bash
pip install requests
```

## 🔐 Authentification

### OAuth 2.0 avec Bearer Token

```python
import requests

headers = {
    'Authorization': f'Bearer {access_token}',
    'Accept': 'application/json;odata=verbose'
}

response = requests.get(
    'https://<site_url>/_api/web/lists',
    headers=headers
)
```

## 🌐 URL de base

**Format standard :**
```python
site_url = "https://<domain>/<site url>"
api_base = f"{site_url}/_api/"
```

**Note :** `_api/` est un alias simplifié de `_vti_bin/client.svc/`

## 📚 Endpoints principaux

### Sites et listes

| Endpoint | Méthode | Description |
|----------|---------|-------------|
| `_api/site` | GET | Informations sur la collection de sites |
| `_api/web` | GET | Informations sur le site web actuel |
| `_api/web/title` | GET | Titre du site actuel |
| `_api/web/lists` | GET | Toutes les listes du site |
| `_api/web/lists(guid'<list_id>')` | GET | Liste spécifique par GUID |
| `_api/web/lists/getByTitle('ListName')` | GET | Liste spécifique par titre |
| `_api/web/lists/getByTitle('ListName')/items` | GET | Tous les éléments d'une liste |
| `_api/web/lists/getByTitle('ListName')/fields` | GET | Toutes les colonnes d'une liste |

### Utilisateurs et groupes

| Endpoint | Méthode | Description |
|----------|---------|-------------|
| `_api/web/siteusers` | GET | Tous les utilisateurs du site |
| `_api/web/sitegroups` | GET | Tous les groupes du site |
| `_api/web/sitegroups(<id>)/users` | GET | Utilisateurs d'un groupe spécifique |
| `_api/web/currentuser` | GET | Utilisateur actuel |

### Fichiers et dossiers

| Endpoint | Méthode | Description |
|----------|---------|-------------|
| `_api/web/GetFolderByServerRelativeUrl('/path')` | GET | Accéder à un dossier |
| `_api/web/GetFolderByServerRelativeUrl('/path')/Files` | GET | Lister les fichiers d'un dossier |
| `_api/web/GetFileByServerRelativeUrl('/path/file.txt')` | GET | Métadonnées d'un fichier |
| `_api/web/GetFileByServerRelativeUrl('/path/file.txt')/$value` | GET | Contenu d'un fichier |

### Contexte

| Endpoint | Méthode | Description |
|----------|---------|-------------|
| `_api/contextinfo` | POST | Obtenir le form digest (requis pour les opérations d'écriture) |

## 💻 Client Python

### Classe SharePointRestClient complète

```python
import requests
import json
from typing import Optional, Dict, Any, List

class SharePointRestClient:
    """Client Python pour l'API REST SharePoint 2013"""
    
    def __init__(self, site_url: str, access_token: str):
        """
        Initialiser le client SharePoint
        
        Args:
            site_url: URL du site SharePoint (ex: https://tenant.sharepoint.com/sites/mysite)
            access_token: Token d'accès OAuth
        """
        self.site_url = site_url.rstrip('/')
        self.access_token = access_token
        self.headers = {
            'Authorization': f'Bearer {access_token}',
            'Accept': 'application/json;odata=verbose'
        }
        self._form_digest = None
    
    def _get_request(self, endpoint: str, params: Optional[Dict] = None) -> Dict:
        """Effectuer une requête GET"""
        url = f"{self.site_url}/_api/{endpoint}"
        response = requests.get(url, headers=self.headers, params=params)
        response.raise_for_status()
        return response.json()
    
    def _post_request(self, endpoint: str, data: Optional[Dict] = None, 
                     extra_headers: Optional[Dict] = None) -> Dict:
        """Effectuer une requête POST"""
        url = f"{self.site_url}/_api/{endpoint}"
        headers = self.headers.copy()
        
        if extra_headers:
            headers.update(extra_headers)
        
        response = requests.post(url, headers=headers, json=data)
        response.raise_for_status()
        return response.json()
    
    def get_form_digest(self, force_refresh: bool = False) -> str:
        """
        Récupérer le form digest (requis pour les opérations d'écriture)
        
        Args:
            force_refresh: Forcer le rafraîchissement du digest
            
        Returns:
            Form digest value
        """
        if self._form_digest and not force_refresh:
            return self._form_digest
        
        response = self._post_request('contextinfo')
        self._form_digest = response['d']['GetContextWebInformation']['FormDigestValue']
        return self._form_digest
    
    # ==================== SITES ET LISTES ====================
    
    def get_web_info(self) -> Dict:
        """Récupérer les informations du site web actuel"""
        return self._get_request('web')
    
    def get_web_title(self) -> str:
        """Récupérer le titre du site"""
        data = self._get_request('web/title')
        return data['d']['Title']
    
    def get_lists(self) -> List[Dict]:
        """Récupérer toutes les listes du site"""
        data = self._get_request('web/lists')
        return data['d']['results']
    
    def get_list_by_title(self, list_title: str) -> Dict:
        """
        Récupérer une liste par son titre
        
        Args:
            list_title: Titre de la liste
        """
        data = self._get_request(f"web/lists/getByTitle('{list_title}')")
        return data['d']
    
    def get_list_by_id(self, list_id: str) -> Dict:
        """
        Récupérer une liste par son GUID
        
        Args:
            list_id: GUID de la liste
        """
        data = self._get_request(f"web/lists(guid'{list_id}')")
        return data['d']
    
    def get_list_fields(self, list_title: str) -> List[Dict]:
        """Récupérer les colonnes d'une liste"""
        data = self._get_request(f"web/lists/getByTitle('{list_title}')/fields")
        return data['d']['results']
    
    def get_list_items(self, list_title: str, select: Optional[str] = None,
                      filter_query: Optional[str] = None, orderby: Optional[str] = None,
                      top: Optional[int] = None, skip: Optional[int] = None,
                      expand: Optional[str] = None) -> List[Dict]:
        """
        Récupérer les éléments d'une liste avec options de filtrage
        
        Args:
            list_title: Titre de la liste
            select: Champs à sélectionner (ex: 'Title,Author,Created')
            filter_query: Filtre OData (ex: "Status eq 'Active'")
            orderby: Tri (ex: 'Title asc')
            top: Nombre max de résultats
            skip: Nombre d'éléments à ignorer
            expand: Champs lookup à inclure (ex: 'Author')
            
        Returns:
            Liste des éléments
        """
        endpoint = f"web/lists/getByTitle('{list_title}')/items"
        
        params = {}
        if select:
            params['$select'] = select
        if filter_query:
            params['$filter'] = filter_query
        if orderby:
            params['$orderby'] = orderby
        if top:
            params['$top'] = top
        if skip:
            params['$skip'] = skip
        if expand:
            params['$expand'] = expand
        
        data = self._get_request(endpoint, params=params)
        return data['d']['results']
    
    def create_list_item(self, list_title: str, item_data: Dict[str, Any]) -> Dict:
        """
        Créer un élément dans une liste
        
        Args:
            list_title: Titre de la liste
            item_data: Données de l'élément (sans __metadata)
            
        Returns:
            Élément créé
        """
        # Récupérer le type de métadonnées de la liste
        list_info = self.get_list_by_title(list_title)
        item_type = list_info['ListItemEntityTypeFullName']
        
        # Préparer les données avec métadonnées
        payload = {
            '__metadata': {'type': item_type},
            **item_data
        }
        
        # Récupérer le form digest
        form_digest = self.get_form_digest()
        
        headers = {
            'X-RequestDigest': form_digest,
            'Content-Type': 'application/json;odata=verbose'
        }
        
        endpoint = f"web/lists/getByTitle('{list_title}')/items"
        data = self._post_request(endpoint, data=payload, extra_headers=headers)
        return data['d']
    
    def update_list_item(self, list_title: str, item_id: int, 
                        item_data: Dict[str, Any]) -> None:
        """
        Mettre à jour un élément de liste
        
        Args:
            list_title: Titre de la liste
            item_id: ID de l'élément
            item_data: Données à mettre à jour
        """
        # Récupérer le type de métadonnées
        list_info = self.get_list_by_title(list_title)
        item_type = list_info['ListItemEntityTypeFullName']
        
        payload = {
            '__metadata': {'type': item_type},
            **item_data
        }
        
        form_digest = self.get_form_digest()
        
        url = f"{self.site_url}/_api/web/lists/getByTitle('{list_title}')/items({item_id})"
        headers = self.headers.copy()
        headers.update({
            'X-RequestDigest': form_digest,
            'X-HTTP-Method': 'MERGE',
            'IF-MATCH': '*',
            'Content-Type': 'application/json;odata=verbose'
        })
        
        response = requests.post(url, headers=headers, json=payload)
        response.raise_for_status()
    
    def delete_list_item(self, list_title: str, item_id: int) -> None:
        """
        Supprimer un élément de liste
        
        Args:
            list_title: Titre de la liste
            item_id: ID de l'élément
        """
        form_digest = self.get_form_digest()
        
        url = f"{self.site_url}/_api/web/lists/getByTitle('{list_title}')/items({item_id})"
        headers = self.headers.copy()
        headers.update({
            'X-RequestDigest': form_digest,
            'X-HTTP-Method': 'DELETE',
            'IF-MATCH': '*'
        })
        
        response = requests.post(url, headers=headers)
        response.raise_for_status()
    
    # ==================== UTILISATEURS ET GROUPES ====================
    
    def get_site_users(self) -> List[Dict]:
        """Récupérer tous les utilisateurs du site"""
        data = self._get_request('web/siteusers')
        return data['d']['results']
    
    def get_current_user(self) -> Dict:
        """Récupérer l'utilisateur actuel"""
        data = self._get_request('web/currentuser')
        return data['d']
    
    def get_site_groups(self) -> List[Dict]:
        """Récupérer tous les groupes du site"""
        data = self._get_request('web/sitegroups')
        return data['d']['results']
    
    def get_group_users(self, group_id: int) -> List[Dict]:
        """Récupérer les utilisateurs d'un groupe"""
        data = self._get_request(f'web/sitegroups({group_id})/users')
        return data['d']['results']
    
    # ==================== FICHIERS ET DOSSIERS ====================
    
    def get_folder(self, folder_path: str) -> Dict:
        """
        Récupérer un dossier
        
        Args:
            folder_path: Chemin relatif au serveur (ex: '/Shared Documents')
        """
        data = self._get_request(f"web/GetFolderByServerRelativeUrl('{folder_path}')")
        return data['d']
    
    def get_folder_files(self, folder_path: str) -> List[Dict]:
        """Lister les fichiers d'un dossier"""
        data = self._get_request(f"web/GetFolderByServerRelativeUrl('{folder_path}')/Files")
        return data['d']['results']
    
    def get_file_info(self, file_path: str) -> Dict:
        """
        Récupérer les métadonnées d'un fichier
        
        Args:
            file_path: Chemin relatif au serveur (ex: '/Shared Documents/file.txt')
        """
        data = self._get_request(f"web/GetFileByServerRelativeUrl('{file_path}')")
        return data['d']
    
    def download_file(self, file_path: str) -> bytes:
        """
        Télécharger le contenu d'un fichier
        
        Args:
            file_path: Chemin relatif au serveur
            
        Returns:
            Contenu du fichier en bytes
        """
        url = f"{self.site_url}/_api/web/GetFileByServerRelativeUrl('{file_path}')/$value"
        response = requests.get(url, headers=self.headers)
        response.raise_for_status()
        return response.content
    
    def upload_file(self, folder_path: str, file_name: str, 
                   file_content: bytes, overwrite: bool = True) -> Dict:
        """
        Télécharger un fichier vers SharePoint
        
        Args:
            folder_path: Chemin du dossier (ex: '/Shared Documents')
            file_name: Nom du fichier
            file_content: Contenu du fichier en bytes
            overwrite: Écraser si existe
            
        Returns:
            Métadonnées du fichier créé
        """
        form_digest = self.get_form_digest()
        
        url = f"{self.site_url}/_api/web/GetFolderByServerRelativeUrl('{folder_path}')/Files/add(url='{file_name}',overwrite={str(overwrite).lower()})"
        
        headers = self.headers.copy()
        headers.update({
            'X-RequestDigest': form_digest,
            'Content-Type': 'application/octet-stream'
        })
        
        response = requests.post(url, headers=headers, data=file_content)
        response.raise_for_status()
        return response.json()['d']
    
    def checkout_file(self, file_path: str) -> None:
        """Extraire un fichier (checkout)"""
        form_digest = self.get_form_digest()
        
        url = f"{self.site_url}/_api/web/GetFileByServerRelativeUrl('{file_path}')/CheckOut()"
        headers = self.headers.copy()
        headers['X-RequestDigest'] = form_digest
        
        response = requests.post(url, headers=headers)
        response.raise_for_status()
    
    def checkin_file(self, file_path: str, comment: str = '', 
                    checkin_type: int = 0) -> None:
        """
        Archiver un fichier (checkin)
        
        Args:
            file_path: Chemin du fichier
            comment: Commentaire
            checkin_type: 0 = mineur, 1 = majeur
        """
        form_digest = self.get_form_digest()
        
        url = f"{self.site_url}/_api/web/GetFileByServerRelativeUrl('{file_path}')/CheckIn(comment='{comment}',checkintype={checkin_type})"
        headers = self.headers.copy()
        headers['X-RequestDigest'] = form_digest
        
        response = requests.post(url, headers=headers)
        response.raise_for_status()
    
    def update_file(self, file_path: str, file_content: bytes) -> None:
        """
        Mettre à jour le contenu d'un fichier
        
        Args:
            file_path: Chemin du fichier
            file_content: Nouveau contenu
        """
        form_digest = self.get_form_digest()
        
        url = f"{self.site_url}/_api/web/GetFileByServerRelativeUrl('{file_path}')/$value"
        headers = self.headers.copy()
        headers.update({
            'X-RequestDigest': form_digest,
            'X-HTTP-Method': 'PUT',
            'Content-Type': 'application/octet-stream'
        })
        
        response = requests.post(url, headers=headers, data=file_content)
        response.raise_for_status()
    
    # ==================== CHANGE QUERIES ====================
    
    def get_site_changes(self, change_query: Dict) -> List[Dict]:
        """Récupérer les modifications au niveau collection de sites"""
        return self._get_changes('site/getchanges', change_query)
    
    def get_web_changes(self, change_query: Dict) -> List[Dict]:
        """Récupérer les modifications au niveau site web"""
        return self._get_changes('web/getchanges', change_query)
    
    def get_list_changes(self, list_title: str, change_query: Dict) -> List[Dict]:
        """Récupérer les modifications au niveau liste"""
        endpoint = f"web/lists/getByTitle('{list_title}')/getchanges"
        return self._get_changes(endpoint, change_query)
    
    def get_list_changes_since_token(self, list_title: str, 
                                    change_token: str) -> List[Dict]:
        """
        Récupérer les modifications depuis un token spécifique
        
        Args:
            list_title: Titre de la liste
            change_token: Token de changement
        """
        query = {
            'query': {
                '__metadata': {'type': 'SP.ChangeLogItemQuery'},
                'ChangeToken': change_token
            }
        }
        
        endpoint = f"web/lists/getByTitle('{list_title}')/getListChangesSinceToken"
        form_digest = self.get_form_digest()
        
        headers = {
            'X-RequestDigest': form_digest,
            'Content-Type': 'application/json;odata=verbose'
        }
        
        data = self._post_request(endpoint, data=query, extra_headers=headers)
        return data['d']['results']
    
    def _get_changes(self, endpoint: str, change_query: Dict) -> List[Dict]:
        """Méthode interne pour récupérer les changements"""
        query = {
            'query': {
                '__metadata': {'type': 'SP.ChangeQuery'},
                **change_query
            }
        }
        
        form_digest = self.get_form_digest()
        
        headers = {
            'X-RequestDigest': form_digest,
            'Content-Type': 'application/json;odata=verbose'
        }
        
        data = self._post_request(endpoint, data=query, extra_headers=headers)
        return data['d']['results']
```

## ✏️ Opérations CRUD

### Lecture (GET)

```python
# Récupérer toutes les listes
lists = client.get_lists()
print(f"Nombre de listes: {len(lists)}")

# Récupérer les éléments d'une liste
items = client.get_list_items('Tasks')
for item in items:
    print(f"Titre: {item['Title']}")
```

### Création (POST)

```python
# Créer un nouvel élément
new_item = client.create_list_item('Tasks', {
    'Title': 'Nouvelle tâche',
    'Status': 'Not Started',
    'Priority': 'High'
})

print(f"Élément créé avec ID: {new_item['Id']}")
```

### Mise à jour (MERGE)

```python
# Mettre à jour un élément existant
client.update_list_item('Tasks', item_id=1, item_data={
    'Title': 'Tâche mise à jour',
    'Status': 'In Progress'
})

print("Élément mis à jour avec succès")
```

### Suppression (DELETE)

```python
# Supprimer un élément
client.delete_list_item('Tasks', item_id=1)
print("Élément supprimé avec succès")
```

## 🔍 Filtrage et tri

### Opérateurs OData disponibles

| Opérateur | Description | Exemple |
|-----------|-------------|---------|
| `$select` | Sélectionner des champs spécifiques | `select='Title,Author,ISBN'` |
| `$filter` | Filtrer les résultats | `filter_query="Author eq 'Mark Twain'"` |
| `$expand` | Inclure des champs de lookup | `expand='PublishedBy'` |
| `$top` | Limiter le nombre de résultats | `top=10` |
| `$skip` | Ignorer les n premiers résultats | `skip=5` |
| `$orderby` | Trier les résultats | `orderby='Title asc'` |

### Exemples pratiques

```python
# Sélectionner des champs spécifiques
items = client.get_list_items(
    'Books',
    select='Author,Title,ISBN'
)

# Filtrer par auteur
items = client.get_list_items(
    'Books',
    filter_query="Author eq 'Mark Twain'"
)

# Trier par titre en ordre croissant
items = client.get_list_items(
    'Books',
    orderby='Title asc'
)

# Combiner plusieurs opérateurs
items = client.get_list_items(
    'Books',
    select='Title',
    filter_query="Author eq 'Mark Twain'",
    top=2
)

# Gérer les lookup fields
items = client.get_list_items(
    'Books',
    select='Title,PublishedBy/Name',
    expand='PublishedBy'
)

# Pagination
page_1 = client.get_list_items('Books', top=10, skip=0)
page_2 = client.get_list_items('Books', top=10, skip=10)
page_3 = client.get_list_items('Books', top=10, skip=20)
```

### Opérateurs de filtrage avancés

```python
# Égal à
filter_query="Status eq 'Active'"

# Différent de
filter_query="Status ne 'Completed'"

# Supérieur à
filter_query="Price gt 50"

# Supérieur ou égal à
filter_query="Price ge 50"

# Inférieur à
filter_query="Price lt 100"

# Inférieur ou égal à
filter_query="Price le 100"

# ET logique
filter_query="Status eq 'Active' and Priority eq 'High'"

# OU logique
filter_query="Status eq 'Active' or Status eq 'Pending'"

# NON logique
filter_query="not (Status eq 'Completed')"

# Commence par
filter_query="startswith(Title, 'Project')"

# Contient
filter_query="substringof('urgent', Title)"

# Plusieurs conditions
filter_query="Status eq 'Active' and Priority eq 'High' and substringof('Project', Title)"
```

## 📁 Gestion des fichiers

### Télécharger un fichier vers SharePoint

```python
# Lire un fichier local
with open('document.pdf', 'rb') as f:
    file_content = f.read()

# Télécharger vers SharePoint
result = client.upload_file(
    folder_path='/Shared Documents',
    file_name='document.pdf',
    file_content=file_content,
    overwrite=True
)

print(f"Fichier téléchargé: {result['Name']}")
```

### Télécharger un fichier depuis SharePoint

```python
# Récupérer le contenu du fichier
file_content = client.download_file('/Shared Documents/document.pdf')

# Sauvegarder localement
with open('downloaded_document.pdf', 'wb') as f:
    f.write(file_content)

print("Fichier téléchargé avec succès")
```

### Lister les fichiers d'un dossier

```python
# Récupérer tous les fichiers d'un dossier
files = client.get_folder_files('/Shared Documents')

for file in files:
    print(f"Fichier: {file['Name']} - Taille: {file['Length']} bytes")
```

### Obtenir les métadonnées d'un fichier

```python
# Récupérer les informations d'un fichier
file_info = client.get_file_info('/Shared Documents/document.pdf')

print(f"Nom: {file_info['Name']}")
print(f"Taille: {file_info['Length']} bytes")
print(f"Modifié: {file_info['TimeLastModified']}")
print(f"Créé par: {file_info['Author']['Title']}")
```

### Extraire un fichier (Check Out)

```python
# Extraire le fichier avant modification
client.checkout_file('/Shared Documents/document.docx')
print("Fichier extrait")
```

### Archiver un fichier (Check In)

```python
# Archiver le fichier après modification
client.checkin_file(
    file_path='/Shared Documents/document.docx',
    comment='Mise à jour du contenu',
    checkin_type=1  # 0 = mineur, 1 = majeur
)
print("Fichier archivé")
```

### Mettre à jour un fichier existant

```python
# Lire le nouveau contenu
with open('updated_document.pdf', 'rb') as f:
    new_content = f.read()

# Extraire le fichier
client.checkout_file('/Shared Documents/document.pdf')

# Mettre à jour le contenu
client.update_file('/Shared Documents/document.pdf', new_content)

# Archiver le fichier
client.checkin_file(
    file_path='/Shared Documents/document.pdf',
    comment='Contenu mis à jour',
    checkin_type=1
)

print("Fichier mis à jour avec succès")
```

### Workflow complet de gestion de fichier

```python
def update_document_workflow(client, file_path, new_content, comment):
    """
    Workflow complet pour mettre à jour un document
    """
    try:
        # 1. Extraire le fichier
        client.checkout_file(file_path)
        print(f"✓ Fichier extrait: {file_path}")
        
        # 2. Mettre à jour le contenu
        client.update_file(file_path, new_content)
        print(f"✓ Contenu mis à jour")
        
        # 3. Archiver le fichier
        client.checkin_file(file_path, comment=comment, checkin_type=1)
        print(f"✓ Fichier archivé avec commentaire: {comment}")
        
        return True
        
    except Exception as e:
        print(f"✗ Erreur: {e}")
        # Essayer d'annuler l'extraction si erreur
        try:
            client.checkin_file(file_path, comment="Annulation", checkin_type=0)
        except:
            pass
        return False

# Utilisation
with open('new_version.docx', 'rb') as f:
    content = f.read()

success = update_document_workflow(
    client,
    '/Shared Documents/report.docx',
    content,
    'Mise à jour trimestrielle'
)
```

## 🔄 Change Queries

Les Change Queries permettent d'interroger le journal des modifications SharePoint pour suivre les changements sur les sites, listes et éléments.

### Récupérer les modifications d'une liste

```python
# Définir la requête de changement
change_query = {
    'Add': 'true',      # Éléments ajoutés
    'Update': 'true',   # Éléments modifiés
    'Delete': 'true',   # Éléments supprimés
    'Item': 'true'      # Type: éléments de liste
}

# Récupérer les modifications
changes = client.get_list_changes('Tasks', change_query)

for change in changes:
    change_type = change['ChangeType']
    item_id = change.get('ItemId', 'N/A')
    time = change['Time']
    
    print(f"Type: {change_type}, Item ID: {item_id}, Date: {time}")
```

### Récupérer les modifications du site web

```python
# Modifications au niveau du site
change_query = {
    'Web': 'true',
    'Update': 'true'
}

changes = client.get_web_changes(change_query)

for change in changes:
    print(f"Changement détecté: {change['ChangeType']} à {change['Time']}")
```

### Utiliser les Change Tokens

```python
# Première requête pour obtenir le token initial
change_query = {
    'Add': 'true',
    'Item': 'true'
}

initial_changes = client.get_list_changes('Tasks', change_query)

# Extraire le dernier token de changement
if initial_changes:
    last_change = initial_changes[-1]
    change_token = last_change['ChangeToken']['StringValue']
    
    print(f"Token de changement: {change_token}")
    
    # Utiliser le token pour récupérer les modifications ultérieures
    # (à exécuter plus tard)
    new_changes = client.get_list_changes_since_token('Tasks', change_token)
    
    print(f"Nouveaux changements: {len(new_changes)}")
```

### Types de changements disponibles

```python
# Configuration complète de Change Query
complete_change_query = {
    # Types de changements
    'Add': 'true',           # Ajouts
    'Update': 'true',        # Modifications
    'Delete': 'true',        # Suppressions
    'Rename': 'true',        # Renommages
    'MoveAway': 'true',      # Déplacements
    'MoveInto': 'true',      # Arrivées
    'Restore': 'true',       # Restaurations
    'RoleAdd': 'true',       # Ajout de rôle
    'RoleDelete': 'true',    # Suppression de rôle
    'RoleUpdate': 'true',    # Mise à jour de rôle
    
    # Objets concernés
    'Item': 'true',          # Éléments de liste
    'List': 'true',          # Listes
    'Web': 'true',           # Sites web
    'Site': 'true',          # Collections de sites
    'Folder': 'true',        # Dossiers
    'File': 'true',          # Fichiers
    'User': 'true',          # Utilisateurs
    'Group': 'true'          # Groupes
}

changes = client.get_list_changes('Tasks', complete_change_query)
```

### Filtrer par période avec Change Tokens

```python
def monitor_changes_between_dates(client, list_title, start_token, end_token):
    """
    Récupérer les changements entre deux points dans le temps
    """
    change_query = {
        'Add': 'true',
        'Update': 'true',
        'Delete': 'true',
        'Item': 'true',
        'ChangeTokenStart': start_token,
        'ChangeTokenEnd': end_token
    }
    
    changes = client.get_list_changes(list_title, change_query)
    
    return changes

# Utilisation
changes = monitor_changes_between_dates(
    client,
    'Tasks',
    'token_start_value',
    'token_end_value'
)
```

### Exemple pratique: Surveillance des modifications

```python
import time
from datetime import datetime

class ChangeMonitor:
    """Classe pour surveiller les modifications SharePoint"""
    
    def __init__(self, client, list_title):
        self.client = client
        self.list_title = list_title
        self.last_token = None
    
    def get_initial_token(self):
        """Obtenir le token initial"""
        change_query = {
            'Add': 'true',
            'Item': 'true'
        }
        
        changes = self.client.get_list_changes(self.list_title, change_query)
        
        if changes:
            self.last_token = changes[-1]['ChangeToken']['StringValue']
            print(f"Token initial défini: {self.last_token}")
    
    def check_for_new_changes(self):
        """Vérifier les nouveaux changements depuis le dernier token"""
        if not self.last_token:
            print("Aucun token initial. Appelez get_initial_token() d'abord.")
            return []
        
        try:
            changes = self.client.get_list_changes_since_token(
                self.list_title,
                self.last_token
            )
            
            if changes:
                # Mettre à jour le token
                self.last_token = changes[-1]['ChangeToken']['StringValue']
                
                # Analyser les changements
                for change in changes:
                    change_type = self._get_change_type_name(change['ChangeType'])
                    item_id = change.get('ItemId', 'N/A')
                    timestamp = change['Time']
                    
                    print(f"[{timestamp}] {change_type} - Item ID: {item_id}")
                
            return changes
            
        except Exception as e:
            print(f"Erreur lors de la vérification: {e}")
            return []
    
    def _get_change_type_name(self, change_type):
        """Convertir le code de type de changement en nom lisible"""
        types = {
            1: 'Add',
            2: 'Update',
            3: 'Delete',
            4: 'Rename',
            5: 'MoveAway',
            6: 'MoveInto',
            7: 'Restore'
        }
        return types.get(change_type, f'Unknown ({change_type})')
    
    def monitor_continuously(self, interval_seconds=60):
        """Surveiller en continu les changements"""
        print(f"Démarrage de la surveillance de '{self.list_title}'...")
        
        # Obtenir le token initial
        self.get_initial_token()
        
        try:
            while True:
                print(f"\n[{datetime.now()}] Vérification des changements...")
                changes = self.check_for_new_changes()
                
                if not changes:
                    print("Aucun nouveau changement")
                
                time.sleep(interval_seconds)
                
        except KeyboardInterrupt:
            print("\nSurveillance arrêtée")

# Utilisation
monitor = ChangeMonitor(client, 'Tasks')

# Surveiller en continu (toutes les 60 secondes)
# monitor.monitor_continuously(interval_seconds=60)

# Ou vérification ponctuelle
monitor.get_initial_token()
time.sleep(10)  # Attendre un peu
monitor.check_for_new_changes()
```

## 💡 Exemples pratiques

### Exemple 1: Synchroniser des données locales avec SharePoint

```python
import json
from pathlib import Path

def sync_local_to_sharepoint(client, list_title, local_file):
    """
    Synchroniser des données depuis un fichier JSON local vers SharePoint
    """
    # Lire les données locales
    with open(local_file, 'r', encoding='utf-8') as f:
        local_data = json.load(f)
    
    # Récupérer les éléments existants
    existing_items = client.get_list_items(list_title, select='Id,Title')
    existing_titles = {item['Title']: item['Id'] for item in existing_items}
    
    stats = {'created': 0, 'updated': 0, 'skipped': 0}
    
    for item_data in local_data:
        title = item_data['Title']
        
        if title in existing_titles:
            # Mettre à jour l'élément existant
            try:
                client.update_list_item(
                    list_title,
                    existing_titles[title],
                    item_data
                )
                print(f"✓ Mis à jour: {title}")
                stats['updated'] += 1
            except Exception as e:
                print(f"✗ Erreur mise à jour {title}: {e}")
                stats['skipped'] += 1
        else:
            # Créer un nouvel élément
            try:
                client.create_list_item(list_title, item_data)
                print(f"✓ Créé: {title}")
                stats['created'] += 1
            except Exception as e:
                print(f"✗ Erreur création {title}: {e}")
                stats['skipped'] += 1
    
    print(f"\n=== Résumé ===")
    print(f"Créés: {stats['created']}")
    print(f"Mis à jour: {stats['updated']}")
    print(f"Ignorés: {stats['skipped']}")

# Utilisation
sync_local_to_sharepoint(client, 'Products', 'products.json')
```

### Exemple 2: Exporter une liste vers CSV

```python
import csv
from datetime import datetime

def export_list_to_csv(client, list_title, output_file, fields=None):
    """
    Exporter une liste SharePoint vers un fichier CSV
    """
    # Récupérer les éléments
    if fields:
        items = client.get_list_items(list_title, select=','.join(fields))
    else:
        items = client.get_list_items(list_title)
    
    if not items:
        print("Aucun élément à exporter")
        return
    
    # Déterminer les colonnes
    if fields:
        fieldnames = fields
    else:
        fieldnames = list(items[0].keys())
        # Exclure les métadonnées
        fieldnames = [f for f in fieldnames if not f.startswith('__')]
    
    # Écrire le CSV
    with open(output_file, 'w', newline='', encoding='utf-8') as f:
        writer = csv.DictWriter(f, fieldnames=fieldnames, extrasaction='ignore')
        writer.writeheader()
        
        for item in items:
            # Nettoyer les données
            clean_item = {}
            for field in fieldnames:
                value = item.get(field, '')
                # Gérer les objets complexes
                if isinstance(value, dict):
                    value = value.get('Title', str(value))
                clean_item[field] = value
            
            writer.writerow(clean_item)
    
    print(f"✓ {len(items)} éléments exportés vers {output_file}")

# Utilisation
export_list_to_csv(
    client,
    'Tasks',
    'tasks_export.csv',
    fields=['Title', 'Status', 'Priority', 'DueDate']
)
```

### Exemple 3: Sauvegarder automatiquement des documents

```python
import os
from datetime import datetime

def backup_document_library(client, library_path, backup_dir):
    """
    Sauvegarder tous les fichiers d'une bibliothèque de documents
    """
    # Créer le dossier de backup
    timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
    backup_folder = os.path.join(backup_dir, f'backup_{timestamp}')
    os.makedirs(backup_folder, exist_ok=True)
    
    # Récupérer la liste des fichiers
    files = client.get_folder_files(library_path)
    
    print(f"Sauvegarde de {len(files)} fichiers...")
    
    success_count = 0
    error_count = 0
    
    for file_info in files:
        file_name = file_info['Name']
        file_path = file_info['ServerRelativeUrl']
        
        try:
            # Télécharger le fichier
            content = client.download_file(file_path)
            
            # Sauvegarder localement
            local_path = os.path.join(backup_folder, file_name)
            with open(local_path, 'wb') as f:
                f.write(content)
            
            print(f"✓ Sauvegardé: {file_name}")
            success_count += 1
            
        except Exception as e:
            print(f"✗ Erreur {file_name}: {e}")
            error_count += 1
    
    print(f"\n=== Résumé ===")
    print(f"Réussis: {success_count}")
    print(f"Erreurs: {error_count}")
    print(f"Dossier: {backup_folder}")

# Utilisation
backup_document_library(
    client,
    '/Shared Documents',
    './backups'
)
```

### Exemple 4: Script d'initialisation complet

```python
"""
Script d'initialisation et d'utilisation de l'API SharePoint REST
"""

def main():
    # Configuration
    site_url = "https://yourtenant.sharepoint.com/sites/yoursite"
    access_token = "votre_token_oauth"
    
    # Initialiser le client
    print("Connexion à SharePoint...")
    client = SharePointRestClient(site_url, access_token)
    
    # Vérifier la connexion
    try:
        web_info = client.get_web_info()
        print(f"✓ Connecté à: {web_info['d']['Title']}")
    except Exception as e:
        print(f"✗ Erreur de connexion: {e}")
        return
    
    # Lister les listes disponibles
    print("\nListes disponibles:")
    lists = client.get_lists()
    for lst in lists:
        print(f"  - {lst['Title']} ({lst['ItemCount']} éléments)")
    
    # Exemple d'opérations CRUD
    list_title = 'Tasks'
    
    # Créer un élément
    print(f"\nCréation d'un élément dans '{list_title}'...")
    new_item = client.create_list_item(list_title, {
        'Title': 'Nouvelle tâche de test',
        'Status': 'Not Started',
        'Priority': 'High'
    })
    print(f"✓ Élément créé avec ID: {new_item['Id']}")
    
    # Lire les éléments
    print(f"\nLecture des éléments de '{list_title}'...")
    items = client.get_list_items(
        list_title,
        select='Id,Title,Status',
        top=5
    )
    for item in items:
        print(f"  [{item['Id']}] {item['Title']} - {item.get('Status', 'N/A')}")
    
    # Mettre à jour l'élément
    print(f"\nMise à jour de l'élément {new_item['Id']}...")
    client.update_list_item(list_title, new_item['Id'], {
        'Status': 'In Progress'
    })
    print("✓ Élément mis à jour")
    
    print("\n=== Script terminé ===")

if __name__ == '__main__':
    main()
```

## ⚠️ Gestion des erreurs

### Gestion des erreurs HTTP

```python
import requests
from requests.exceptions import HTTPError, ConnectionError, Timeout

class SharePointError(Exception):
    """Exception personnalisée pour les erreurs SharePoint"""
    pass

def safe_request(func):
    """Décorateur pour gérer les erreurs de requêtes"""
    def wrapper(*args, **kwargs):
        try:
            return func(*args, **kwargs)
        except HTTPError as e:
            if e.response.status_code == 401:
                raise SharePointError("Erreur d'authentification - Token invalide ou expiré")
            elif e.response.status_code == 403:
                raise SharePointError("Accès refusé - Permissions insuffisantes")
            elif e.response.status_code == 404:
                raise SharePointError("Ressource non trouvée")
            elif e.response.status_code == 429:
                raise SharePointError("Trop de requêtes - Rate limit atteint")
            elif e.response.status_code >= 500:
                raise SharePointError(f"Erreur serveur SharePoint: {e.response.status_code}")
            else:
                raise SharePointError(f"Erreur HTTP: {e.response.status_code} - {e.response.text}")
        except ConnectionError:
            raise SharePointError("Erreur de connexion - Impossible de joindre SharePoint")
        except Timeout:
            raise SharePointError("Timeout - La requête a pris trop de temps")
        except Exception as e:
            raise SharePointError(f"Erreur inattendue: {str(e)}")
    
    return wrapper

# Utilisation
@safe_request
def get_list_items_safe(client, list_title):
    return client.get_list_items(list_title)
```

### Retry avec backoff exponentiel

```python
import time
from functools import wraps

def retry_with_backoff(max_retries=3, initial_delay=1, backoff_factor=2):
    """
    Décorateur pour réessayer automatiquement avec backoff exponentiel
    """
    def decorator(func):
        @wraps(func)
        def wrapper(*args, **kwargs):
            delay = initial_delay
            
            for attempt in range(max_retries):
                try:
                    return func(*args, **kwargs)
                except requests.exceptions.RequestException as e:
                    if attempt == max_retries - 1:
                        raise
                    
                    print(f"Tentative {attempt + 1} échouée: {e}")
                    print(f"Nouvelle tentative dans {delay}s...")
                    time.sleep(delay)
                    delay *= backoff_factor
            
            return None
        
        return wrapper
    return decorator

# Utilisation
class RobustSharePointClient(SharePointRestClient):
    @retry_with_backoff(max_retries=3, initial_delay=1, backoff_factor=2)
    def get_lists_robust(self):
        return self.get_lists()
```

### Validation des données

```python
def validate_list_item(item_data, required_fields=None, field_types=None):
    """
    Valider les données avant de les envoyer à SharePoint
    
    Args:
        item_data: Données à valider
        required_fields: Liste des champs obligatoires
        field_types: Dictionnaire des types attendus par champ
    
    Raises:
        ValueError: Si la validation échoue
    """
    # Vérifier les champs obligatoires
    if required_fields:
        for field in required_fields:
            if field not in item_data or not item_data[field]:
                raise ValueError(f"Champ obligatoire manquant: {field}")
    
    # Vérifier les types
    if field_types:
        for field, expected_type in field_types.items():
            if field in item_data:
                value = item_data[field]
                if not isinstance(value, expected_type):
                    raise ValueError(
                        f"Type incorrect pour {field}: "
                        f"attendu {expected_type.__name__}, "
                        f"reçu {type(value).__name__}"
                    )
    
    return True

# Utilisation
try:
    item_data = {
        'Title': 'Ma tâche',
        'Priority': 'High'
    }
    
    validate_list_item(
        item_data,
        required_fields=['Title', 'Status'],
        field_types={'Title': str, 'Priority': str}
    )
    
    client.create_list_item('Tasks', item_data)
    
except ValueError as e:
    print(f"Validation échouée: {e}")
```

### Logging et monitoring

```python
import logging
from datetime import datetime

# Configuration du logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler(f'sharepoint_{datetime.now().strftime("%Y%m%d")}.log'),
        logging.StreamHandler()
    ]
)

logger = logging.getLogger('SharePoint')

class LoggingSharePointClient(SharePointRestClient):
    """Client SharePoint avec logging intégré"""
    
    def get_lists(self):
        logger.info("Récupération des listes")
        try:
            result = super().get_lists()
            logger.info(f"✓ {len(result)} listes récupérées")
            return result
        except Exception as e:
            logger.error(f"✗ Erreur lors de la récupération des listes: {e}")
            raise
    
    def create_list_item(self, list_title, item_data):
        logger.info(f"Création d'un élément dans '{list_title}'")
        logger.debug(f"Données: {item_data}")
        try:
            result = super().create_list_item(list_title, item_data)
            logger.info(f"✓ Élément créé avec ID: {result['Id']}")
            return result
        except Exception as e:
            logger.error(f"✗ Erreur lors de la création: {e}")
            raise
    
    def upload_file(self, folder_path, file_name, file_content, overwrite=True):
        file_size = len(file_content)
        logger.info(f"Upload de '{file_name}' ({file_size} bytes) vers '{folder_path}'")
        try:
            result = super().upload_file(folder_path, file_name, file_content, overwrite)
            logger.info(f"✓ Fichier uploadé avec succès")
            return result
        except Exception as e:
            logger.error(f"✗ Erreur lors de l'upload: {e}")
            raise
```

### Gestion du rate limiting

```python
import time
from collections import deque

class RateLimitedSharePointClient(SharePointRestClient):
    """Client avec limitation du nombre de requêtes"""
    
    def __init__(self, site_url, access_token, max_requests_per_minute=60):
        super().__init__(site_url, access_token)
        self.max_requests_per_minute = max_requests_per_minute
        self.request_times = deque()
    
    def _wait_if_needed(self):
        """Attendre si la limite de requêtes est atteinte"""
        now = time.time()
        
        # Supprimer les requêtes de plus d'une minute
        while self.request_times and now - self.request_times[0] > 60:
            self.request_times.popleft()
        
        # Vérifier si la limite est atteinte
        if len(self.request_times) >= self.max_requests_per_minute:
            sleep_time = 60 - (now - self.request_times[0])
            if sleep_time > 0:
                print(f"Rate limit atteint. Attente de {sleep_time:.1f}s...")
                time.sleep(sleep_time)
        
        # Enregistrer cette requête
        self.request_times.append(time.time())
    
    def _get_request(self, endpoint, params=None):
        self._wait_if_needed()
        return super()._get_request(endpoint, params)
    
    def _post_request(self, endpoint, data=None, extra_headers=None):
        self._wait_if_needed()
        return super()._post_request(endpoint, data, extra_headers)
```

## 📚 Ressources supplémentaires

### Documentation officielle

- [SharePoint 2013 REST API Reference](https://learn.microsoft.com/en-us/sharepoint/dev/sp-add-ins/get-to-know-the-sharepoint-rest-service)
- [Complete basic operations using SharePoint REST endpoints](https://learn.microsoft.com/en-us/sharepoint/dev/sp-add-ins/complete-basic-operations-using-sharepoint-rest-endpoints)
- [OData Query Operations](https://www.odata.org/documentation/)

### Bonnes pratiques

1. **Gestion du Form Digest**
   - Mettre en cache le form digest (valide pendant 30 minutes)
   - Le rafraîchir automatiquement avant expiration

2. **Performance**
   - Utiliser `$select` pour limiter les champs retournés
   - Implémenter la pagination pour les grandes listes
   - Utiliser des requêtes batch pour les opérations multiples

3. **Sécurité**
   - Ne jamais stocker les tokens en clair
   - Utiliser HTTPS pour toutes les requêtes
   - Implémenter un système de rotation des tokens

4. **Fiabilité**
   - Implémenter un système de retry avec backoff
   - Logger toutes les opérations importantes
   - Gérer les erreurs de façon appropriée

### Codes d'erreur courants

| Code | Description | Solution |
|------|-------------|----------|
| 401 | Non autorisé | Vérifier le token d'accès |
| 403 | Accès refusé | Vérifier les permissions |
| 404 | Non trouvé | Vérifier l'URL et les noms |
| 429 | Trop de requêtes | Implémenter rate limiting |
| 500 | Erreur serveur | Réessayer plus tard |

---

## 🎯 Exemples pratiques basés sur ASAP SharePoint

### Configuration pour ASAP

```python
from requests_ntlm import HttpNtlmAuth
import requests

# Configuration ASAP SharePoint
SHAREPOINT_URL = "http://asap.stjn.local"
SHAREPOINT_USER = r"stjn\samir.chibout"
SHAREPOINT_PASSWORD = "votre_mot_de_passe"

# Configuration de la session avec authentification NTLM
session = requests.Session()
session.auth = HttpNtlmAuth(SHAREPOINT_USER, SHAREPOINT_PASSWORD)
session.headers.update({
    'Accept': 'application/json;odata=verbose',
    'Content-Type': 'application/json;odata=verbose'
})
```

### Exemple 1 : Récupérer tous les projets

```python
def get_all_projects():
    """Récupérer tous les projets de la liste 'Projets'"""
    url = f"{SHAREPOINT_URL}/_api/web/lists/getByTitle('Projets')/items"
    
    params = {
        '$top': 100,
        '$orderby': 'ID'
    }
    
    response = session.get(url, params=params)
    response.raise_for_status()
    
    data = response.json()
    projects = data['d']['results']
    
    print(f"Nombre de projets récupérés: {len(projects)}")
    
    for project in projects:
        print(f"ID: {project['Id']}")
        print(f"Titre: {project['Title']}")
        print(f"Code: {project.get('Code', 'N/A')}")
        print(f"Statut: {project.get('Global_x0020_Status', 'N/A')}")
        print(f"Budget Total SAP: {project.get('Budget_x0020_Total_x0020_SAP', 0)}")
        print("-" * 50)
    
    return projects

# Utilisation
projects = get_all_projects()
```

**Réponse exemple (XML):**
```xml
<?xml version="1.0" encoding="utf-8"?>
<feed xml:base="http://asap.stjn.local/_api/">
    <entry>
        <id>Web/Lists(guid'...')/Items(79)</id>
        <content type="application/xml">
            <m:properties>
                <d:Id m:type="Edm.Int32">79</d:Id>
                <d:Title>FONDERIE - Evacuation chlore et réseau informatique boucle</d:Title>
                <d:Code>SN.16044</d:Code>
                <d:Global_x0020_Status>Clôturé</d:Global_x0020_Status>
                <d:Budget_x0020_Total_x0020_SAP m:type="Edm.Double">197500</d:Budget_x0020_Total_x0020_SAP>
                <d:Secteur>Fonderie</d:Secteur>
            </m:properties>
        </content>
    </entry>
</feed>
```

### Exemple 2 : Filtrer les projets actifs

```python
def get_active_projects():
    """Récupérer uniquement les projets en cours"""
    url = f"{SHAREPOINT_URL}/_api/web/lists/getByTitle('Projets')/items"
    
    params = {
        '$select': 'Id,Title,Code,Global_x0020_Status,Secteur,Budget_x0020_Total_x0020_SAP',
        '$filter': "Global_x0020_Status eq 'En cours'",
        '$orderby': 'Title asc',
        '$top': 50
    }
    
    response = session.get(url, params=params)
    data = response.json()
    
    projects = data['d']['results']
    print(f"Projets actifs: {len(projects)}")
    
    return projects

# Utilisation
active_projects = get_active_projects()
```

**Réponse JSON:**
```json
{
    "d": {
        "results": [
            {
                "Id": 85,
                "Title": "CARBONE - Modernisation atelier",
                "Code": "SN.20045",
                "Global_x0020_Status": "En cours",
                "Secteur": "Carbone",
                "Budget_x0020_Total_x0020_SAP": 450000
            }
        ]
    }
}
```

### Exemple 3 : Récupérer un projet spécifique

```python
def get_project_by_id(project_id):
    """Récupérer un projet par son ID"""
    url = f"{SHAREPOINT_URL}/_api/web/lists/getByTitle('Projets')/items({project_id})"
    # Exemple tiré de responProjet.xml :
    url_test = "http://asap.stjn.local/_api/web/lists/getByTitle('Projets')/items(79)"
    
    response = session.get(url)
    data = response.json()
    
    project = data['d']
    
    print(f"Projet ID: {project['Id']}")
    print(f"Titre: {project['Title']}")
    print(f"Code: {project.get('Code')}")
    print(f"Numéro: {project.get('Num_x00e9_ro_x0020_du_x0020_proj')}")
    print(f"Statut Global: {project.get('Global_x0020_Status')}")
    print(f"Phase: {project.get('PhaseText')}")
    print(f"Avancement: {project.get('OData__x0025__x0020_Completed', 0) * 100}%")
    print(f"\nBudgets:")
    print(f"  - Initial: {project.get('Budget_x0020_Initial', 0)} €")
    print(f"  - Total SAP: {project.get('Budget_x0020_Total_x0020_SAP', 0)} €")
    print(f"  - Actual: {project.get('Budget_x0020_Actual', 0)} €")
    print(f"\nOrganisation:")
    print(f"  - Secteur: {project.get('Secteur')}")
    print(f"  - Groupe: {project.get('Group1')}")
    print(f"  - Template: {project.get('Template')}")
    
    return project

# Utilisation
project = get_project_by_id(79)
```

**Réponse complète:**
```json
{
    "d": {
        "Id": 79,
        "Title": "FONDERIE - Evacuation chlore et réseau informatique boucle",
        "Code": "SN.16044",
        "Num_x00e9_ro_x0020_du_x0020_proj": "16.001",
        "Global_x0020_Status": "Clôturé",
        "PhaseText": "P6 en validation",
        "OData__x0025__x0020_Completed": 1,
        "Budget_x0020_Initial": 197500,
        "Budget_x0020_Total_x0020_SAP": 197500,
        "Budget_x0020_Actual": 193431.7,
        "Secteur": "Fonderie",
        "Group1": "Saint Jean de Maurienne",
        "Template": "Petit projet",
        "StartDate": "2015-06-28T22:00:00Z",
        "Estimated_x0020_End_x0020_Date": "2016-03-06T23:00:00Z",
        "Health": "Ok",
        "Planning": "Ok",
        "Cost": "Ok",
        "PassingGate": "P6"
    }
}
```

### Exemple 4 : Filtrer par secteur et budget

```python
def get_projects_by_sector_and_budget(sector, min_budget):
    """Filtrer les projets par secteur et budget minimum"""
    url = f"{SHAREPOINT_URL}/_api/web/lists/getByTitle('Projets')/items"
    
    params = {
        '$select': 'Id,Title,Code,Secteur,Budget_x0020_Total_x0020_SAP,Global_x0020_Status',
        '$filter': f"Secteur eq '{sector}' and Budget_x0020_Total_x0020_SAP gt {min_budget}",
        '$orderby': 'Budget_x0020_Total_x0020_SAP desc',
        '$top': 10
    }
    
    response = session.get(url, params=params)
    data = response.json()
    
    projects = data['d']['results']
    
    print(f"Projets {sector} avec budget > {min_budget} €:")
    total_budget = 0
    
    for project in projects:
        budget = project.get('Budget_x0020_Total_x0020_SAP', 0)
        total_budget += budget
        print(f"  - {project['Code']}: {project['Title']}")
        print(f"    Budget: {budget:,.2f} € - Statut: {project.get('Global_x0020_Status')}")
    
    print(f"\nBudget total: {total_budget:,.2f} €")
    
    return projects

# Utilisation
fonderie_projects = get_projects_by_sector_and_budget('Fonderie', 100000)
```

### Exemple 5 : Pagination avec gestion de __next

```python
def get_all_projects_with_pagination():
    """Récupérer tous les projets avec pagination automatique"""
    url = f"{SHAREPOINT_URL}/_api/web/lists/getByTitle('Projets')/items"
    
    params = {
        '$top': 100,
        '$orderby': 'ID'
    }
    
    all_projects = []
    page = 1
    
    while url:
        print(f"Récupération page {page}...")
        
        if page == 1:
            response = session.get(url, params=params)
        else:
            # Les pages suivantes utilisent l'URL complète fournie par __next
            response = session.get(url)
        
        data = response.json()
        projects = data['d']['results']
        all_projects.extend(projects)
        
        print(f"  - {len(projects)} projets récupérés")
        
        # Vérifier s'il y a une page suivante
        url = data['d'].get('__next')
        page += 1
    
    print(f"\nTotal: {len(all_projects)} projets")
    return all_projects

# Utilisation
all_projects = get_all_projects_with_pagination()
```

### Exemple 6 : Récupérer les champs de la liste

```python
def get_list_fields():
    """Récupérer la liste des champs disponibles"""
    url = f"{SHAREPOINT_URL}/_api/web/lists/getByTitle('Projets')/fields"
    
    params = {
        '$filter': "Hidden eq false and ReadOnlyField eq false",
        '$select': 'Title,InternalName,TypeAsString,Required'
    }
    
    response = session.get(url, params=params)
    data = response.json()
    
    fields = data['d']['results']
    
    print("Champs disponibles dans la liste Projets:")
    print("-" * 80)
    
    for field in fields:
        required = "✓" if field.get('Required') else " "
        print(f"[{required}] {field['Title']:<30} ({field['InternalName']:<40}) {field['TypeAsString']}")
    
    return fields

# Utilisation
fields = get_list_fields()
```

**Réponse:**
```json
{
    "d": {
        "results": [
            {
                "Title": "Titre",
                "InternalName": "Title",
                "TypeAsString": "Text",
                "Required": true
            },
            {
                "Title": "Code",
                "InternalName": "Code",
                "TypeAsString": "Text",
                "Required": false
            },
            {
                "Title": "Budget Total SAP",
                "InternalName": "Budget_x0020_Total_x0020_SAP",
                "TypeAsString": "Number",
                "Required": false
            }
        ]
    }
}
```

### Exemple 7 : Recherche par titre

```python
def search_projects_by_title(search_term):
    """Rechercher des projets par titre"""
    url = f"{SHAREPOINT_URL}/_api/web/lists/getByTitle('Projets')/items"
    
    params = {
        '$select': 'Id,Title,Code,Global_x0020_Status',
        '$filter': f"substringof('{search_term}', Title)",
        '$top': 20
    }
    
    response = session.get(url, params=params)
    data = response.json()
    
    projects = data['d']['results']
    
    print(f"Résultats pour '{search_term}': {len(projects)} projet(s)")
    
    for project in projects:
        print(f"  [{project['Id']}] {project['Title']}")
        print(f"      Code: {project.get('Code')} - Statut: {project.get('Global_x0020_Status')}")
    
    return projects

# Utilisation
results = search_projects_by_title('FONDERIE')
```

### Exemple 8 : Statistiques par secteur

```python
def get_statistics_by_sector():
    """Calculer des statistiques par secteur"""
    url = f"{SHAREPOINT_URL}/_api/web/lists/getByTitle('Projets')/items"
    
    params = {
        '$select': 'Secteur,Budget_x0020_Total_x0020_SAP,Global_x0020_Status',
        '$top': 5000
    }
    
    response = session.get(url, params=params)
    data = response.json()
    
    projects = data['d']['results']
    
    # Regrouper par secteur
    stats = {}
    
    for project in projects:
        sector = project.get('Secteur', 'Non défini')
        budget = project.get('Budget_x0020_Total_x0020_SAP', 0)
        status = project.get('Global_x0020_Status', 'N/A')
        
        if sector not in stats:
            stats[sector] = {
                'count': 0,
                'total_budget': 0,
                'actifs': 0,
                'clotures': 0
            }
        
        stats[sector]['count'] += 1
        stats[sector]['total_budget'] += budget
        
        if status == 'En cours':
            stats[sector]['actifs'] += 1
        elif status == 'Clôturé':
            stats[sector]['clotures'] += 1
    
    # Afficher les statistiques
    print("Statistiques par secteur:")
    print("=" * 80)
    
    for sector, data in sorted(stats.items(), key=lambda x: x[1]['total_budget'], reverse=True):
        print(f"\n{sector}:")
        print(f"  - Projets: {data['count']}")
        print(f"  - Budget total: {data['total_budget']:,.2f} €")
        print(f"  - Actifs: {data['actifs']}")
        print(f"  - Clôturés: {data['clotures']}")
        print(f"  - Budget moyen: {data['total_budget']/data['count']:,.2f} €")
    
    return stats

# Utilisation
statistics = get_statistics_by_sector()
```

### Exemple 9 : Exporter vers CSV

```python
import csv
from datetime import datetime

def export_projects_to_csv(filename='projets_export.csv'):
    """Exporter tous les projets vers un fichier CSV"""
    url = f"{SHAREPOINT_URL}/_api/web/lists/getByTitle('Projets')/items"
    
    params = {
        '$select': 'Id,Title,Code,Num_x00e9_ro_x0020_du_x0020_proj,Global_x0020_Status,'
                  'Secteur,Budget_x0020_Total_x0020_SAP,Budget_x0020_Actual,'
                  'StartDate,Estimated_x0020_End_x0020_Date',
        '$top': 5000
    }
    
    response = session.get(url, params=params)
    data = response.json()
    
    projects = data['d']['results']
    
    # Écrire le CSV
    with open(filename, 'w', newline='', encoding='utf-8') as f:
        writer = csv.writer(f, delimiter=';')
        
        # En-têtes
        writer.writerow([
            'ID', 'Code', 'Numéro', 'Titre', 'Secteur', 'Statut',
            'Budget Total SAP', 'Budget Actual', 'Date Début', 'Date Fin Estimée'
        ])
        
        # Données
        for project in projects:
            writer.writerow([
                project.get('Id'),
                project.get('Code', ''),
                project.get('Num_x00e9_ro_x0020_du_x0020_proj', ''),
                project.get('Title', ''),
                project.get('Secteur', ''),
                project.get('Global_x0020_Status', ''),
                project.get('Budget_x0020_Total_x0020_SAP', 0),
                project.get('Budget_x0020_Actual', 0),
                project.get('StartDate', ''),
                project.get('Estimated_x0020_End_x0020_Date', '')
            ])
    
    print(f"✓ {len(projects)} projets exportés vers {filename}")

# Utilisation
export_projects_to_csv('projets_asap.csv')
```

### Exemple 10 : Importer vers PostgreSQL

```python
import psycopg2
import psycopg2.extras
import json

def import_projects_to_postgresql():
    """Importer les projets SharePoint vers PostgreSQL"""
    
    # 1. Récupérer les projets depuis SharePoint
    url = f"{SHAREPOINT_URL}/_api/web/lists/getByTitle('Projets')/items"
    
    all_projects = []
    current_url = url
    params = {'$top': 100, '$orderby': 'ID'}
    
    while current_url:
        if current_url == url:
            response = session.get(current_url, params=params)
        else:
            response = session.get(current_url)
        
        data = response.json()
        projects = data['d']['results']
        all_projects.extend(projects)
        
        current_url = data['d'].get('__next')
        print(f"Récupéré: {len(all_projects)} projets...")
    
    print(f"Total récupéré: {len(all_projects)} projets")
    
    # 2. Connexion PostgreSQL
    conn = psycopg2.connect(
        host="10.190.100.58",
        port=5432,
        database="sap_migration_db",
        user="postgres",
        password="trimet2025"
    )
    cursor = conn.cursor()
    
    # 3. Insertion des projets
    imported_count = 0
    
    for project in all_projects:
        try:
            # Préparer les données
            cursor.execute("""
                INSERT INTO raw_data.sharepoint_projets (
                    sharepoint_id, title, code, project_number, description,
                    global_status, phase_text, percent_completed,
                    budget_total_sap, budget_actual, sector, group_name,
                    template, imported_at, raw_data
                )
                VALUES (
                    %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, NOW(), %s
                )
                ON CONFLICT (sharepoint_id) 
                DO UPDATE SET
                    title = EXCLUDED.title,
                    code = EXCLUDED.code,
                    global_status = EXCLUDED.global_status,
                    budget_total_sap = EXCLUDED.budget_total_sap,
                    imported_at = NOW()
            """, (
                project.get('Id'),
                project.get('Title'),
                project.get('Code'),
                project.get('Num_x00e9_ro_x0020_du_x0020_proj'),
                project.get('Description'),
                project.get('Global_x0020_Status'),
                project.get('PhaseText'),
                project.get('OData__x0025__x0020_Completed'),
                project.get('Budget_x0020_Total_x0020_SAP'),
                project.get('Budget_x0020_Actual'),
                project.get('Secteur'),
                project.get('Group1'),
                project.get('Template'),
                json.dumps(project)
            ))
            
            imported_count += 1
            
        except Exception as e:
            print(f"Erreur projet {project.get('Id')}: {e}")
    
    conn.commit()
    cursor.close()
    conn.close()
    
    print(f"✓ {imported_count} projets importés dans PostgreSQL")

# Utilisation
import_projects_to_postgresql()
```

### Mapping des champs SharePoint

```python
# Correspondance des noms de champs SharePoint
FIELD_MAPPING = {
    # Identifiants
    'Id': 'sharepoint_id',
    'ID': 'sharepoint_id',
    'Title': 'title',
    'Code': 'code',
    'Num_x00e9_ro_x0020_du_x0020_proj': 'project_number',
    
    # Statut
    'Global_x0020_Status': 'global_status',
    'PhaseText': 'phase_text',
    'PassingGate': 'passing_gate',
    'OData__x0025__x0020_Completed': 'percent_completed',
    
    # Indicateurs
    'Health': 'health',
    'Planning': 'planning',
    'Cost': 'cost',
    
    # Budgets
    'Budget_x0020_Initial': 'budget_initial',
    'Budget_x0020_Total_x0020_SAP': 'budget_total_sap',
    'Budget_x0020_Actual': 'budget_actual',
    'Budget_x0020_At_x0020_Completion': 'budget_at_completion',
    'Budget_x0020_demand_x00e9_': 'budget_demanded',
    'Budget_x0020_Delivered': 'budget_delivered',
    'BudgetIMSAP': 'budget_im_sap',
    'BudgetEXSAP': 'budget_ex_sap',
    
    # Organisation
    'Secteur': 'sector',
    'Group1': 'group_name',
    'Template': 'template',
    
    # Dates
    'StartDate': 'start_date',
    'Estimated_x0020_End_x0020_Date': 'estimated_end_date',
    'Modified': 'modified',
    'Created': 'created',
    
    # IDs de référence
    'PMId': 'pm_id',
    'Correspondant_x002f__x0020_ClienId': 'client_correspondent_id',
    'ProjectTeamId': 'project_team_id',
}
```

---

**Note**: Ce guide est basé sur SharePoint 2013 avec des exemples concrets tirés du système ASAP de Saint Jean de Maurienne. La plupart des endpoints fonctionnent également avec SharePoint Online et les versions ultérieures.