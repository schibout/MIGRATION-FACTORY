---
name: migration-factory
description: Concevoir ou relire les migrations SQL et loaders SAP ECC vers IFS de Migration Factory, avec introspection des schemas et preservation des saisies utilisateur.
---

# Migration SAP vers IFS

Lire `AGENTS.md` a la racine du depot, puis uniquement la documentation du
module concerne. Les conventions metier detaillees sont conservees dans
`docs/ai/project-reference.md` ; rechercher les noms de tables ou de fonctions
avant de lire les passages utiles.

## Avant de proposer du SQL

- Identifier les schemas `raw_data`, `clean_data` et `public`, les colonnes,
  types, cles, contraintes et definitions des fonctions existantes.
- Utiliser une introspection en lecture seule, ou les migrations et definitions
  SQL versionnees quand aucun acces DB n'est disponible. Signaler alors que
  l'etat reel de la base n'a pas ete confirme.
- Ne jamais modifier directement `raw_data`, ni proposer DROP/RECREATE pour
  contourner une difference de structure. Les rechargements SAP passent par
  les outils de maintenance du projet dans le perimetre autorise.
- Trouver le prochain numero libre dans `migrations/` ; ne pas faire confiance
  a un numero memorise dans une documentation. Ne pas modifier une migration
  deja deployee pour masquer une nouvelle evolution.

## Relecture des loaders

- Verifier le perimetre SAP, les jointures, les doublons et l'idempotence
  selon les contraintes reelles de la table ; ne pas generaliser l'absence
  de PK ou la nullabilite d'un ancien exemple a toutes les tables IFS.
- Conserver les saisies utilisateur lors d'une fusion maintenance : `source`
  MANUAL ou `updated_by` renseigne. Respecter snapshot, verrou et retour 409.
- Respecter les cles SAP et les chemins de nomenclature du module concerne.
  IH02 et les exports utilisent `clean_data.maintenance_object`.
- Pour un fichier source, verifier encodage, separateur, en-tetes dupliques,
  taux de NULL et longueurs avant d'inferer des types ou mappings.
- `public."TranscodificationTable"` reste quotee ; reprendre la signature
  existante de `get_transcodification` au lieu de l'inventer.

## Livrable et validation

Fournir le changement SQL, son impact attendu, les controles avant/apres et
les conditions de retour arriere utiles. Un controle de syntaxe de fichier
ne prouve ni la validite PostgreSQL ni le respect du contrat IFS.
Ne pas executer une migration ou un test connecte sur la base distante pour
une simple relecture. Utiliser `verify-change` pour les controles hors ligne.
