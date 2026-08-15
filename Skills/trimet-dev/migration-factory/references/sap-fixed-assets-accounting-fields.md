# SAP FI-AA — champs comptables utiles pour export immobilisations

Contexte : exports CSV lisibles des immobilisations SAP depuis `raw_data.anla` / `anlb` / `anlc` / référentiels FI-AA vers IFS.

## Dates principales

- `ANLA-AKTIV` : date de capitalisation / mise en service comptable. Ne pas la confondre avec une date de facture.
- `ANLA-ZUGDT` : date de première acquisition / premier mouvement d'acquisition.
- `ANLB-AFABG` : début du calcul d'amortissement pour une zone d'amortissement donnée.
- Date de fin d'amortissement : préférer les champs de fin disponibles (`ANLC-NDABJ` / `ANLC-NDABP`) quand ils sont fiables ; sinon calculer depuis `ANLB-AFABG` + durée (`ANLB-NDJAR`, `ANLB-NDPER`) en documentant la zone retenue.

## Valeurs ANLC et libellés CSV

Éviter le libellé ambigu « Valeur acquisition cumulée » si la valeur exportée est `KANSW + ANSWL`.

Libellés recommandés :
- `ANLC-KANSW` : Valeur acquisition début exercice
- `ANLC-ANSWL` : Mouvements acquisition exercice
- `KANSW + ANSWL` : Valeur acquisition fin exercice
- Cumul amortissements : somme des amortissements cumulés pertinents (`KNAFA`, `KSAFA`, `KAAFA`, éventuellement `KMAFA` selon usage)
- VNC : valeur nette comptable, généralement `valeur acquisition fin exercice - cumul amortissements` en tenant compte des signes SAP observés dans la donnée.

Toujours vérifier quelques lignes douteuses directement dans `raw_data.anlc` avant de valider le CSV : la VNC peut être correcte alors que le libellé de la colonne d'acquisition est trompeur.

## Zones d'amortissement

- `ANLB-AFABE` est la zone / tableau d'évaluation. Son check table est `T093`.
- Les codes `02`, `03`, `42`, `72`, etc. ne sont pas universels : charger `T093` et surtout `T093T` pour obtenir les libellés métier réels avant de choisir la zone IFS de référence.
- Pour la durée d'amortissement, comparer le taux de remplissage par zone (`ANLB-NDJAR`, `ANLB-NDPER`) ; ne pas supposer que la zone `01` porte la durée.

## Détermination comptable immobilisation

- `ANLA-KTOGR` : clé / groupe de détermination des comptes FI-AA. Ce n'est pas la classe d'immobilisation et pas forcément le compte GL directement.
- `T095T` : libellé du groupe de comptes (`KTGRTX`).
- `T095` : comptes paramétrés FI-AA, notamment compte immobilisation et comptes associés selon zone/plan.
- `T095B` / `T095C` : paramétrage complémentaire selon besoin.
- `T095A` peut être vide même si c'est la check table indiquée par le DDIC ; si aucun libellé n'en sort, charger `T095T`.

Libellés CSV recommandés :
- Clé détermination comptes immo SAP
- Libellé clé comptable immo SAP
- Compte immobilisation SAP
- Compte amortissement cumulé SAP
- Compte dotation amortissement SAP

## Libellés de colonnes

Utiliser `public.sap_table_fields` pour les libellés SAP (`field_text`, `header_text`, `long_description`, `check_table`) plutôt que les noms techniques quand l'utilisateur demande un CSV métier. Pour les libellés de valeurs, charger la table de check / texte correspondante ; `sap_table_fields` donne le libellé du champ, pas celui de chaque valeur.