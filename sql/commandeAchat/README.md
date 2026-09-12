# Module ETL Commandes d'achat (SAP -> `clean_data.commande_achat_ifs`)

Charge les commandes d'achat SAP **ouvertes** au format de reprise IFS : une ligne par poste
`EKPO` non supprime, **non clos** (`ekpo.elikz` vide = pas de « livraison finale ») et avec un
reliquat a livrer > 0. Les postes anciens que les acheteurs n'ont jamais clos dans SAP sont
ouverts au sens SAP et ressortent (au 12/09/2026 : 4 868 postes, dont ~3 000 anterieurs a 2024) :
borner par `date_debut` dans `module_params` si le metier ne veut pas les reprendre.

| Element | Emplacement |
|---|---|
| DDL de la table cible | `01_create_clean_data_commande_achat_ifs.sql` (DROP + CREATE, table snapshot) |
| Fonction de chargement | `02_alimenter_commande_achat_ifs.sql` -> `clean_data.alimenter_commande_achat_ifs(p_date_debut, p_date_fin, p_ebeln)` |
| Compilation | `./compile.sh` (compile aussi `../functions/get_vendor_no_ifs.sql`) |
| Enregistrement du module | `add_etl_commande_achat_module.sql` (`etl_target_tables`, `etl_commande_achat.py`, ordre 15) |
| Requete d'export | `insert_etl_export_queries.sql` (categorie `Commande Achat`) |
| Module Python | `backend/etl_modules/etl_commande_achat.py` |
| Export frontend | `/export/commandes-achat` (`pages/ExportCommandeAchat.tsx`), carte dans `ExportData.tsx` |

## Installation

```bash
cd sql/commandeAchat
./compile.sh
psql ... -f add_etl_commande_achat_module.sql
psql ... -f insert_etl_export_queries.sql
```

Puis lancer le module depuis l'ecran de chargement des donnees, ou :

```bash
docker exec -e PYTHONPATH=/app migration-app-backend python etl_modules/etl_commande_achat.py [date_debut [date_fin]]
```

## Regles de mappage

- **Fournisseur IFS** (`fournisseur_ifs`, `fournisseur_facturation_ifs`) : `public.get_vendor_no_ifs(lifnr)`,
  numero de compte du fichier de selection ; NULL si le fournisseur n'y figure pas. Le fournisseur
  de facturation est le partenaire `EKPA` `RS` (sinon `PI`), a defaut le fournisseur de la commande.
- **Site** : deduit de la division `werks` (`9200`/`2200` = SJ, `9000`/`2000` = CS), jamais de la
  societe (`STJN` couvre les deux sites).
- **Article** : `matnr` sans zeros de tete (= `part_catalog.part_no`) ; `type_ligne_ifs` = `PART` /
  `NOPART`.
- **Quantites** : recu = `EKBE` `vgabe=1`, facture = `vgabe` 2/3 (annulations `shkzg='H'` en negatif) ;
  reliquats = `GREATEST(menge - recu|facture, 0)`, montants = reliquat x `netpr / peinh`, arrondis a 4.
- **Unite d'achat** : transcodification `UOM`, repli `'*'`.
- **Dates** : `DD/MM/YYYY` ; livraison planifiee / promise = prochaine echeance `EKET` a venir, sinon
  la derniere ; reception souhaitee = derniere reception `EKBE`.
- **Adresse de livraison** : `ADRC` du poste (`adrnr`, `adrn2`), sinon de la division (`T001W`).
- **Pre-imputation** : `PROJET=` (`PRPS.posid`) > `CENTRE_COUT=` > `ORDRE=` > `COMPTE=` depuis `EKKN`.
- Non transcode : `acheteur_sap` (`ekgrp`, pas de table de correspondance), `mode_expedition` = `'10'`.

## Repli en-tete

Si `raw_data.ekpo` est **vide** (cas rencontre le 11/09/2026, rechargee le 12/09), la fonction emet un
`WARNING` et charge une ligne par **commande** `EKKO` : colonnes de poste NULL, commandes ouvertes =
au moins un poste dont les echeances `EKET` portent `menge - wemng > 0` (approximation : `elikz`
n'est pas disponible sans `ekpo`, d'anciennes commandes ressortent), site = division majoritaire des
mouvements `EKBE` (NULL sans mouvement). Des que `ekpo` est rechargee, rejouer le module : la branche
poste est prise automatiquement.

## Performance

~22 s en repli en-tete, ~65 s en mode poste. Trois pieges deja rencontres, a ne pas reintroduire :
- `get_vendor_no_ifs` balaie le fichier a chaque appel : l'appeler par LIFNR distinct (CTE), pas par ligne ;
- les index SAP commencent par `mandt` : pas d'`EXISTS` correle sur `ebeln` seul, pre-agreger en CTE ;
- `COALESCE(loekz,'') = ''` et les predicats via fonction ne sont pas estimables par le planificateur
  (8 lignes estimees sur 338 k -> boucles imbriquees) : `loekz IS NULL OR loekz = ''` et bornes de
  date comparees en texte `YYYYMMDD`.
