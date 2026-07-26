# Module Maintenance - Mode d'emploi

## Accès

Menu latéral **Maintenance** → `http://10.190.100.58:3000/maintenance`

La page d'accueil du module présente deux cartes :

| Carte | Description | Accès |
|-------|-------------|-------|
| **Équipements** | Liste des équipements SAP avec caractéristiques et rattachements | `/maintenance/equipment` |
| **Hiérarchie technique & Équipements** | Arborescence complète des postes techniques avec équipements (IH02) | `/maintenance/ih02` |

---

## Page Hiérarchie technique & Équipements (IH02)

### Vue d'ensemble

L'écran est divisé en deux panneaux :
- **Panneau gauche** : arborescence des postes techniques et équipements
- **Panneau droit** : détails de l'élément sélectionné

En haut de page, des statistiques résument le contenu : nombre total de postes techniques, nombre de types distincts et nombre de centres de coûts.

---

### 1. Navigation dans l'arborescence

- Cliquer sur la **flèche** (▶) à gauche d'un poste technique pour déplier ses enfants (postes de niveau inférieur + équipements rattachés)
- Les **postes techniques** sont représentés par une icône dossier colorée selon le niveau hiérarchique
- Les **équipements** sont représentés par une icône outil (orange)
- Un badge indique le nombre d'enfants ou de sous-équipements
- Les sous-équipements se déplient de la même façon en cliquant sur la flèche

### 2. Recherche

- Taper au moins **2 caractères** dans la barre de recherche en haut du panneau gauche
- La recherche s'effectue sur : désignation, identifiant du poste technique, centre de coûts, numéro d'équipement, fabricant
- Les résultats affichent les postes techniques et équipements correspondants
- Cliquer sur un résultat pour afficher ses détails dans le panneau droit

### 3. Consultation des détails

**Pour un poste technique :**
- Cliquer sur un poste dans l'arbre pour afficher ses détails à droite
- Informations affichées : désignation, type, niveau, identifiant, type construction, quantité, centre de coûts, responsable maintenance, nombre d'équipements rattachés

**Pour un équipement :**
- Cliquer sur un équipement pour afficher ses détails dans 4 onglets :
  - **Général** : désignation, type, catégorie, n° série, n° inventaire, n° article, date mise en service, plan de maintenance
  - **Localisation** : poste technique, division, emplacement, section, équipement supérieur
  - **Organisation** : société, centre de coûts, domaine d'activité, fournisseur, valeur acquisition, garantie
  - **Fabrication** : fabricant, pays, modèle, taille, poids, année/mois de construction

---

### 4. Modification des données

Il est possible de modifier directement les postes techniques et les équipements depuis le panneau de détails.

**Procédure :**
1. Sélectionner un élément dans l'arbre (poste technique ou équipement)
2. Cliquer sur l'icône **crayon** (✏️) en haut à droite du panneau de détails
3. Les champs éditables se transforment en champs de saisie
4. Modifier les valeurs souhaitées
5. Cliquer sur **Enregistrer** pour sauvegarder ou **Annuler** pour revenir en lecture seule

**Champs modifiables pour un poste technique :**
- Identifiant, parent, désignation, type de poste, art/type construction, quantité, unité, centre de coûts, poste travail resp. maintenance

**Champs modifiables pour un équipement :**
- Tous les champs descriptifs (désignation, type, catégorie, fabricant, modèle, n° série, centre de coûts, etc.)
- Les champs système (n° équipement, dates de création, créé par) restent en lecture seule

> **Note** : les modifications sont enregistrées directement en base de données. Après la sauvegarde, les détails sont automatiquement rechargés. Si l'identifiant ou le parent est modifié, l'arborescence est rechargée.

---

### 5. Déplacement par glisser-déposer (drag & drop)

Les postes techniques peuvent être réorganisés dans l'arborescence par glisser-déposer.

**Procédure :**
1. Repérer l'icône de glissement (⠿) à gauche de chaque poste technique
2. Cliquer et maintenir sur un poste technique, puis le glisser
3. Le noeud glissé devient semi-transparent
4. Survoler le poste technique cible : celui-ci s'illumine en bleu avec une bordure en pointillés
5. Relâcher pour déplacer le noeud sous la cible (il devient enfant de la cible)
6. L'arborescence est automatiquement rechargée après le déplacement

**Contraintes :**
- Seuls les postes techniques (dossiers) peuvent être glissés
- La cible doit être un poste technique (pas un équipement)
- Si le niveau change (ex: noeud niveau 3 déplacé sous un parent niveau 1), le noeud passe automatiquement au niveau adéquat (niveau 2)

---

### 6. Modification en masse (noeud + enfants)

Permet de modifier un champ sur un poste technique **et tous ses descendants** en une seule opération.

**Procédure :**
1. Sélectionner un poste technique dans l'arbre
2. Dans le panneau de détails, cliquer sur l'icône **modification en masse** (icône crayon avec lignes, à gauche de l'icône crayon simple)
3. Une fenêtre s'ouvre indiquant le nombre de noeuds concernés (noeud + descendants)
4. Choisir un **champ** dans la liste déroulante (Désignation, Type de poste, Centre de coûts, etc.)
5. Saisir la **nouvelle valeur**
6. Cliquer sur le bouton **+** pour ajouter la modification à la liste
7. Répéter les étapes 4-6 pour empiler plusieurs modifications de champs différents
8. Consulter le récapitulatif dans le tableau (possibilité de supprimer une ligne avec l'icône poubelle)
9. Cliquer sur **Appliquer sur N noeud(s)** pour enregistrer

**Champs disponibles pour la modification en masse :**

| Champ | Description |
|-------|-------------|
| Désignation | Texte descriptif du poste |
| Type de poste | Type du poste technique |
| Centre de coûts | Code du centre de coûts |
| Poste travail resp. maintenance | Responsable maintenance |
| Art / Type construction | Type de construction |
| Quantité | Quantité associée |
| Unité | Unité de mesure |

> **Attention** : la modification en masse s'applique à **tous les descendants** du noeud sélectionné. Vérifier le nombre de noeuds affiché dans le badge avant de valider.

---

### 7. Export CSV

Le bouton **Export CSV** en haut de page permet de télécharger les données au format CSV (séparateur `;`, compatible Excel).

**Procédure :**
1. Cliquer sur le bouton **Export CSV**
2. Choisir le type d'export dans le menu déroulant :
   - **Postes techniques (structures)** → fichier `ih02_postes_techniques.csv`
   - **Équipements** → fichier `ih02_equipements.csv`
3. Le fichier CSV se télécharge automatiquement

**Contenu des exports :**

| Export | Colonnes principales |
|--------|---------------------|
| Postes techniques | id, niveau_0 à niveau_15, désignation, type_poste, centre_couts, poste_travail_resp_maintenance, art_type_construction, quantité, unité |
| Équipements | equnr, désignation, type, catégorie, poste_technique, equipement_superieur, fabricant, modèle, n° série, centre_couts, société, division, fournisseur, plan_maintenance, etc. |

> **Astuce** : les fichiers CSV exportés peuvent être ouverts dans Excel pour modifier en masse les données, puis réimportés via le module d'import générique.

---

### 8. Rafraîchir les données

Cliquer sur l'icône **↻** (rafraîchir) en haut à droite pour recharger l'arborescence et les statistiques depuis la base de données.

---

## Page Équipements

Accessible via la carte **Équipements** depuis la page Maintenance.

Cette page affiche la liste complète des équipements SAP avec leurs caractéristiques et rattachements sous forme de tableau.
