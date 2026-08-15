# FI-AA immobilisations SAP pour migration IFS

Notes réutilisables pour préparer un export immobilisations SAP lisible métier à partir des tables extraites par l'API SAP Extraction.

## Tables utiles

Socle immobilisations :

- `ANLA` : fiche immobilisation, dont société `BUKRS`, numéro `ANLN1`, sous-numéro `ANLN2`, classe `ANLKL`, clé de détermination des comptes `KTOGR`, date de capitalisation `AKTIV`, date de première acquisition `ZUGDT`, fournisseur `LIFNR`, fabricant `HERST`, inventaire `INVNR`, ordre investissement `EAUFN`.
- `ANKA` / `ANKT` : classes d'immobilisations et libellés de classes. Utiliser `ANKT` pour un libellé métier de famille immobilisation.
- `ANLB` : paramètres d'amortissement par zone `AFABE`, dont date de début amortissement `AFABG`, clé d'amortissement `AFASL`, durée `NDJAR` années et `NDPER` périodes.
- `ANLC` : valeurs cumulées par exercice et zone, dont `KANSW` valeur acquisition début/cumul, `ANSWL` mouvements acquisition exercice, `KNAFA` amortissement normal cumulé, `KSAFA` spécial, `KAAFA` non planifié, `KMAFA` manuel, `NDABJ`/`NDABP` fin d'amortissement.
- `ANLP`, `ANEP`, `ANEK` : amortissements périodiques et documents/mouvements détaillés si l'historique est demandé.

Customizing/libellés complémentaires :

- `T093` / `T093T` : zones d'amortissement et libellés des zones. Charger ces tables avant d'expliquer des valeurs comme 02/03/42/72 ; leur signification est propre au paramétrage client.
- `T095A` : check table de `ANLA-KTOGR`, peut être vide dans certains systèmes.
- `T095T` : désignation/libellé des groupes de comptes (`KTOGR`).
- `T095` : détermination comptable par plan comptable `KTOPL`, clé `KTOGR` et zone `AFABE` : compte immobilisation `KTANSW`, compte amortissement cumulé `KTANZA`, comptes de dotation/sortie selon colonnes disponibles.
- `T001` : société vers plan comptable (`BUKRS` -> `KTOPL`) pour joindre correctement `T095`.
- `SAP_TABLE_FIELDS` et `DD003L` : libellés de champs et check tables. S'en servir pour produire des exports avec des libellés compréhensibles au lieu de noms techniques.

## Règles de mapping utiles

- VNC = valeur nette comptable. Dans `ANLC`, calculer à partir des valeurs d'acquisition nettes des mouvements et des amortissements cumulés. Attention à ne pas nommer `KANSW + ANSWL` "Valeur acquisition cumulée" : c'est plutôt une valeur d'acquisition fin exercice / après mouvements.
- Cumul amortissements = addition des colonnes d'amortissement cumulées pertinentes : `KNAFA + KSAFA + KAAFA + KMAFA` selon usage client.
- Date acquisition/capitalisation principale : `ANLA-AKTIV` (`Date de capitalisation` / mise en service comptable). Garder séparément `ANLA-ZUGDT` si le métier veut la date de première acquisition SAP.
- Date début amortissement : `ANLB-AFABG` pour la zone d'amortissement retenue.
- Date fin amortissement : utiliser `ANLC-NDABJ`/`NDABP` si renseignés, sinon calculer depuis `ANLB-AFABG + NDJAR/NDPER` après choix de la zone.
- Durée d'amortissement : `ANLB-NDJAR` années et `ANLB-NDPER` périodes. Toujours préciser la zone d'amortissement source ; la zone 01 peut être peu renseignée alors que 02/03 portent les durées.
- Clé comptable immo : `ANLA-KTOGR`. Ce n'est pas le compte GL unique ; c'est la clé/groupe de détermination des comptes.
- Compte immobilisation : joindre `ANLA.BUKRS -> T001.KTOPL`, puis `T095` sur `KTOPL`, `KTOGR`, et la zone d'amortissement retenue (souvent `AFABE='01'` pour comptabilité principale). `T095.KTANSW` donne le compte immobilisation, `T095.KTANZA` le compte amortissement cumulé quand renseigné.

## Préférences d'export pour ce projet

- Répondre et livrer les CSV en français.
- Préférer des en-têtes métier : `Société SAP`, `Numéro immobilisation`, `Libellé immobilisation`, `Famille immobilisation`, `Clé détermination comptes immo SAP`, `Libellé clé comptable immo SAP`, `Compte immobilisation SAP`, `Compte amortissement cumulé SAP`, `Date acquisition`, `Date début amortissement`, `Date fin amortissement estimée`, `Valeur acquisition début exercice`, `Mouvements acquisition exercice`, `Valeur acquisition fin exercice`, `Cumul amortissements`, `VNC`.
- Éviter de réintroduire des colonnes techniques supprimées par l'utilisateur, sauf demande explicite : `sub_asset_no`, `asset_key`, `asset_class`, `asset_description_2`, `deletion_flag`, `serial_number`, `country`, `evaluation_group_*`, `project_no`, `depreciation_area_param`, `depreciation_key`, `useful_life_*`, amortissements détaillés techniques.
- Pour les chargements/extractions API de ce projet, utiliser `user_id: "schibout"` sauf instruction contraire explicite.

## Vérifications avant livraison

- Vérifier le nombre de lignes du CSV contre la table source principale (`ANLA`).
- Vérifier que les colonnes supprimées par l'utilisateur ne sont plus présentes.
- Vérifier le taux de remplissage des champs ajoutés : clé comptable, libellé clé, compte immobilisation, VNC, cumul amortissements, dates.
- Sauvegarder une copie avant de modifier un CSV déjà livré.
