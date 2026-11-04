# Catalogue technique des tables IFS

Écran : **Données IFS → Catalogue des tables IFS**
(`/ifs-data/table-catalog`). Un lien est également présent dans le catalogue
des spécifications par lot existant.

## Installation

1. Appliquer uniquement `migrations/073_create_ifs_dictionary.sql` sur la base
   applicative, avec les paramètres de connexion habituels :

   ```bash
   psql -v ON_ERROR_STOP=1 -f migrations/073_create_ifs_dictionary.sql
   ```

2. Déployer le backend et le frontend.
3. Depuis un compte administrateur, cliquer sur **Importer tables et colonnes**
   dans « Catalogue IFS » ou « Catalogue des tables IFS ». Sélectionner
   `ifs_table_name.csv` et `COLUMN_NAME.csv`, puis cliquer sur **Importer les deux fichiers**.

Les fichiers fournis ici sont des extraits : **2 tables du propriétaire SYS et
9 colonnes**, sans les colonnes de `PART_CATALOG`. Pour générer le rapport de
cette dernière, importer son véritable dictionnaire Oracle/IFS.
Les CSV ne sont pas chargés automatiquement au démarrage.

## Import et stockage

- `public.ifs_table_catalog` : identité `(owner, table_name)`, tablespace,
  statut, nombre estimé de lignes et date d'import.
- `public.ifs_column_catalog` : identité `(table_id, column_name)`, ordre Oracle,
  type, longueur en octets, précision, échelle, nullabilité et valeur par défaut.
- Chaque entrée conserve également **toutes les métadonnées CSV en JSONB**,
  consultables dans les détails. Le nombre de lignes est une statistique Oracle
  importée, pas un comptage en temps réel.
- Ces tables sont distinctes de `ifs_field_catalog`, qui décrit les
  spécifications fonctionnelles par lot.

Format : séparateur `;`, en-têtes Oracle tels que fournis, UTF-8 (BOM accepté)
ou Windows-1252, 32 Mo maximum par fichier. Les champs CSV entre guillemets
peuvent contenir des points-virgules et des retours à la ligne.

En-têtes obligatoires pour les tables : `Owner`, `Table Name`.
Pour les colonnes : `Owner`, `Table Name`, `Column Name`, `Data Type`,
`Nullable` (`Y`/`N`), `Column Id` (entier positif).
Chaque table référencée dans le fichier des colonnes doit figurer dans le
fichier des tables du même import.

Les doublons d'identité, les positions dupliquées au sein d'une table et les
valeurs invalides sont refusés avant écriture. Les deux fichiers sont importés
dans une transaction unique, avec sérialisation des imports concurrents.
Un réimport met à jour les métadonnées des entrées présentes ; **les tables et
colonnes absentes restent conservées**, pour permettre des imports partiels.
Il ne s'agit donc pas d'une synchronisation supprimant les anciennes colonnes.

## Consultation et rapport

Tous les utilisateurs authentifiés peuvent rechercher une table ou une colonne,
filtrer par propriétaire, parcourir les tables paginées et consulter leurs colonnes.
L'import est réservé aux administrateurs.

Dans **Consulter**, sélectionner les colonnes, puis cliquer sur **Générer le
rapport**. Toutes les colonnes sont sélectionnées au départ ; filtrer l'affichage
ne modifie pas cette sélection. Le rapport suit l'ordre `Column Id`, avec une
option pour inclure le propriétaire dans le `FROM`.

L'aperçu se télécharge sous le nom **report.md**. Comme le modèle fourni dans ce
dossier, le contenu est du SQL brut avec deux niveaux de `SELECT`, sans bloc
Markdown ajouté. Le fichier modèle du dépôt n'est pas écrasé. Les identifiants
atypiques ou réservés sont échappés. **Aucune requête générée n'est exécutée**,
et aucune connexion à Oracle n'est nécessaire.

## API

Préfixe : `/api/v1/data/ifs-dictionary` (JWT requis).

| Méthode | Route | Usage |
| --- | --- | --- |
| GET | `/tables?q=&owner=&page=0&page_size=25` | Liste, recherche, compteurs et propriétaires ; tailles 25/50/100 |
| GET | `/tables/{table_id}` | Métadonnées de la table et colonnes ordonnées |
| POST | `/import` | Admin, multipart `tables_file` et `columns_file` |
| POST | `/tables/{table_id}/report` | JSON `{ "columns": ["PART_NO"], "include_owner": false }` → `{ "sql": "…", "filename": "report.md" }` |

Si `columns` est omis, toutes les colonnes sont incluses. Une sélection vide,
dupliquée ou contenant un nom inconnu est refusée. Table inconnue : 404 ; import
ou paramètres invalides : 400 ; catalogue/base indisponible : 503.

## Vérification

```bash
PYTHONPATH=backend pytest -q backend/tests/test_ifs_dictionary.py
```

Les tests de parsing et du modèle SQL fonctionnent sans base. Pour activer
également les tests d'intégration (migration rejouée, import, rollback, API et
droits), définir `IFS_CATALOG_TEST_DATABASE_URL` vers une **base de test dédiée**
dont le nom commence par `ifs_catalog_test`. Les tables du catalogue y sont
vidées entre tests ; ne pas utiliser la base applicative.
