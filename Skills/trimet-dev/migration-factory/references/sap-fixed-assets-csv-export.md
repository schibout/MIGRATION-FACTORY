# Export CSV des immobilisations SAP pour migration IFS

Contexte réutilisable : quand l'utilisateur demande un fichier CSV des immobilisations SAP depuis les tables `raw_data.anla/anlb/anlc/ankt`, produire un fichier local dans `/opt/data/exports/` avec des libellés métier français, pas des noms techniques SAP, sauf demande contraire.

## Sources SAP principales

- `raw_data.anla` : base de l'export, une ligne par immobilisation (`bukrs`, `anln1`, `anln2`).
- `raw_data.ankt` : libellé de famille/classe d'immobilisation, jointure `ankt.anlkl = anla.anlkl`; privilégier `spras='F'`, puis `E`, puis `D`.
- `raw_data.anlc` : valeurs cumulées et amortissements par exercice/zone.
- `raw_data.anlb` : date de début et durée d'amortissement.

## Colonnes métier recommandées

Libellés CSV recommandés :

- Société SAP
- Numéro immobilisation
- Libellé immobilisation
- Famille immobilisation
- Détermination comptable immobilisation
- Date acquisition
- Date première acquisition SAP
- Date début amortissement
- Date fin amortissement estimée
- Valeur acquisition cumulée
- Mouvements valeur exercice
- Cumul amortissements
- VNC
- Exercice de valorisation retenu
- Date retrait / sortie
- Date désactivation
- Blocage comptabilisation
- Numéro inventaire
- Fabricant
- Type / modèle
- Fournisseur
- Quantité
- Unité
- Ordre investissement

Colonnes techniques ou trop détaillées à éviter si l'utilisateur demande un fichier lisible : `sub_asset_no`, `asset_key`, `asset_class`, `asset_description_2`, `deletion_flag`, `serial_number`, `country`, `evaluation_group_*`, `project_no`, `depreciation_area_param`, `depreciation_key`, `useful_life_years`, `useful_life_periods`, `retirements_value_cum`, `ordinary_depr_cum`, `special_depr_cum`, `unplanned_depr_cum`.

## Calculs utiles

SAP stocke les amortissements dans `ANLC` avec des montants souvent signés négativement. Pour un export lisible :

- Date acquisition : `ANLA-AKTIV` si renseigné, sinon `ANLA-ZUGDT`.
- Date première acquisition SAP : `ANLA-ZUGDT`.
- Date début amortissement : `ANLB-AFABG`.
- Valeur acquisition cumulée : `ANLC-KANSW + ANLC-ANSWL - ANLC-ABGAN`.
- Cumul amortissements : `ANLC-KNAFA + KSafa + KAAFA + KMAFA + NAFAG + SAFAG + AAFAG + MAFAG` (en SQL utiliser les vrais noms minuscules : `knafa`, `ksafa`, `kaafa`, `kmafa`, `nafag`, `safag`, `aafag`, `mafag`). Garder le signe SAP : il est généralement négatif.
- VNC : `valeur_acquisition_cumulée + cumul_amortissements`.
- Date fin amortissement estimée : `ANLB-AFABG + (ANLB-NDJAR * 12 + ANLB-NDPER) mois - 1 jour`. Laisser vide si durée nulle/non renseignée.

## Choix de zone de valorisation

Ne pas supposer que la zone `01` contient toujours les valeurs utiles. Dans le jeu SAP TRIMET observé, la zone 01 était peu valorisée, tandis que `03` et `73` portaient beaucoup de valeurs. Pour l'export synthétique, choisir une ligne `ANLC` par immobilisation avec une priorité explicite, par exemple : `03`, puis `73`, puis `02`, puis `60`, puis `01`, puis autres, et prendre l'exercice le plus récent dans cette zone.

Pour `ANLB`, choisir en priorité une ligne ayant une durée non nulle (`ndjar <> '000'` ou `ndper <> '000'`), puis prioriser les zones `03`, `73`, `02`, `30`, `42`, `72`, `01`.

## Vérifications avant réponse

Après export :

1. Relire le CSV avec `csv.DictReader(..., delimiter=';')`.
2. Vérifier que le nombre de lignes correspond à `COUNT(*)` de `raw_data.anla`.
3. Si le CSV contient exactement le double de `ANLA`, vérifier les jointures référentielles : dans ce système `raw_data.t001` peut avoir 2 lignes par `bukrs`; créer une CTE `company AS (SELECT DISTINCT ON (bukrs) bukrs, ktopl FROM raw_data.t001 ORDER BY bukrs, id NULLS LAST)` avant de joindre `T095`.
4. Vérifier que les colonnes explicitement supprimées ne sont plus présentes.
5. Vérifier que `VNC`, `Cumul amortissements`, `Date acquisition` sont alimentés autant que possible.
6. Pour les enrichissements amortissement, contrôler le taux de remplissage de `ANLZ-KOSTL/WERKS/GSBER`, `ANLA-SERNR`, `ANEK-XBLNR`, `ANEP-BWASL`/`TABWT` et `ANLC-KNAFA`; dans le jeu TRIMET observé, `ANLA-SERNR` était chargé mais vide.
7. Répondre avec le chemin complet du fichier, le nombre de lignes, le nombre de colonnes et les contrôles effectués.
