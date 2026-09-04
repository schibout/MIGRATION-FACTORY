# Prompt de verification — rechargement du module fournisseurs

A coller tel quel dans Claude Code apres chaque rechargement ETL fournisseurs.
Toutes les requetes sont en LECTURE SEULE. Base : `10.190.100.58 / sap_migration_db`
(identifiants dans `.env`).

---

Verifie le rechargement du module fournisseurs. Pour chaque point ci-dessous,
execute la requete, compare au resultat attendu, et signale tout ecart en
citant les valeurs obtenues. Ne corrige rien sans me le dire.

## 0. Prerequis de deploiement (a verifier AVANT de conclure quoi que ce soit)

Les fonctions `clean_data.*` vivent dans la base, pas dans le depot : un
`git pull` ne les met pas a jour. Un rechargement lance sans avoir recompile
produit l'ancien comportement en silence.

```sql
-- Les fonctions deployees portent-elles bien le numero IFS ?
SELECT p.proname,
       pg_get_functiondef(p.oid) LIKE '%numero_compte_ifs as supplier_id%'
    OR pg_get_functiondef(p.oid) LIKE '%numero_compte_ifs, 1, 20) as supplier_id%'
    OR pg_get_functiondef(p.oid) LIKE '%numero_compte_ifs as vendor_no%' AS a_jour
  FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
 WHERE n.nspname = 'clean_data'
   AND p.proname IN ('alimenter_supplier_info_general', 'sp_insert_supplier_from_sap');
```
Attendu : `a_jour = true` partout. Sinon : lancer `sql/supplier/compile.sh`, puis
relancer l'ETL. Le backend doit aussi avoir ete redeploye (`./deploybackend.sh`)
pour que l'etape de renumerotation reste desactivee.

## 1. L'identifiant est le numero IFS du fichier

```sql
SELECT count(*) AS total,
       count(*) FILTER (WHERE g.supplier_id = f.numero_compte_ifs) AS conformes,
       count(*) FILTER (WHERE g.supplier_id = g.supplier_legacy_sap_id) AS restes_en_sap
  FROM clean_data.supplier_info_general g
  JOIN clean_data.ifs_fournisseurs f ON f.numero_compte_fournisseur = g.supplier_legacy_sap_id;
```
Attendu : `conformes = total`, `restes_en_sap = 0`.
`supplier_id` doit ressembler a `6018xx`, jamais a `0000045036` ni a `P276983`.

```sql
-- Le numero SAP d'origine est conserve, et lui seul dans cette colonne
SELECT count(*) FILTER (WHERE supplier_legacy_sap_id ~ '^[0-9]{10}$'
                           OR supplier_legacy_sap_id ~ '^[A-Z]') AS legacy_sap_ok,
       count(*) FILTER (WHERE supplier_legacy_sap_id ~ '^60[0-9]{4}$') AS legacy_pollue
  FROM clean_data.supplier_info_general;
```
Attendu : `legacy_pollue = 0` (un numero IFS dans la colonne legacy = trace d'une
renumerotation en cascade rejouee par erreur).

```sql
-- Aucune trace de l'ancienne renumerotation sequentielle
SELECT count(*) FROM clean_data.supplier_info_general WHERE supplier_id = '600000';
```
Attendu : `0` — la numerotation metier commence a 600001.

## 2. Numerotation : figee, unique, incrementale

```sql
SELECT (SELECT count(*) FROM clean_data.ifs_fournisseur_id_map)                    AS nb_affectations,
       (SELECT count(DISTINCT numero_compte_ifs) FROM clean_data.ifs_fournisseur_id_map) AS nb_numeros,
       (SELECT max(numero_compte_ifs) FROM clean_data.ifs_fournisseur_id_map)      AS max_attribue,
       (SELECT last_value FROM clean_data.seq_numero_compte_ifs)                   AS sequence;
```
Attendu : `nb_affectations = nb_numeros` (aucun doublon) et `sequence = max_attribue`
(le prochain nouveau fournisseur prendra `max + 1`).

```sql
-- Un numero du fichier deja donne a un AUTRE fournisseur par la sequence
-- (ferait echouer le prochain chargement sur la contrainte UNIQUE)
SELECT count(*) AS collisions
  FROM raw_data.selection_fournisseurs_stg s
  JOIN clean_data.ifs_fournisseur_id_map m
    ON m.numero_compte_ifs = NULLIF(TRIM(s.numero_compte_ifs), '')::int
 WHERE TRIM(COALESCE(s.numero_compte_ifs, '')) ~ '^[0-9]+$'
   AND m.numero_compte_sap <> LPAD(TRIM(s.numero_compte_sap), 10, '0');
```
Attendu : `0`. Sinon, le fichier metier reattribue un numero deja pris : le
corriger AVANT de recharger (`ifs_fournisseur_id_map` ne doit jamais etre purgee).

```sql
-- Les numeros deja attribues n'ont pas bouge depuis le chargement precedent
SELECT source, count(*), min(created_at)::date AS premiere, max(created_at)::date AS derniere
  FROM clean_data.ifs_fournisseur_id_map GROUP BY 1;
```
Attendu : les lignes `FICHIER` gardent leur date d'origine ; seules des lignes
`SAP_NOUVEAU` recentes peuvent apparaitre.

## 3. Date d'arrete

```sql
SELECT valeur, is_active, updated_at, updated_by
  FROM public.etl_default_values
 WHERE table_cible = 'clean_data.ifs_fournisseurs' AND colonne = 'date_arrete';
```
Attendu : la date voulue, `is_active = true`.
Piege : la migration 065 est en `ON CONFLICT DO NOTHING` — rejouer le fichier ne
change PAS une ligne existante. Pour modifier la date, passer par l'ecran
`/configuration/valeurs-defaut` ou par un `UPDATE` explicite.

```sql
-- Le perimetre SAP_NOUVEAU correspond-il a la date active ?
SELECT count(*) AS nb_sap_nouveau,
       min(date_creation_sap) AS plus_ancien
  FROM clean_data.ifs_fournisseurs WHERE source = 'SAP_NOUVEAU';
```
Attendu : `plus_ancien >= date d'arrete`. Un fournisseur cree avant la date ne
doit pas etre repris hors fichier.

```sql
-- Aucun fournisseur SAP eligible oublie
SELECT count(*) AS manquants
  FROM raw_data.lfa1 a
 WHERE COALESCE(a.loevm, '') <> 'X'
   AND CASE WHEN TRIM(COALESCE(a.erdat,'')) ~ '^[0-9]{8}$' AND TRIM(a.erdat) <> '00000000'
                THEN TO_DATE(TRIM(a.erdat), 'YYYYMMDD')
            WHEN TRIM(COALESCE(a.erdat,'')) ~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}$'
                THEN TO_DATE(TRIM(a.erdat), 'YYYY-MM-DD') END
       >= (SELECT valeur::date FROM public.etl_default_values
            WHERE table_cible='clean_data.ifs_fournisseurs' AND colonne='date_arrete' AND is_active)
   AND NOT EXISTS (SELECT 1 FROM clean_data.ifs_fournisseurs f
                    WHERE f.numero_compte_fournisseur = a.lifnr::text);
```
Attendu : `0`.

## 4. Completude des tables filles

```sql
SELECT 'supplier_info_general' t, count(*) FROM clean_data.supplier_info_general
UNION ALL SELECT 'supplier',                   count(*) FROM clean_data.supplier
UNION ALL SELECT 'supplier_info_our_id',       count(*) FROM clean_data.supplier_info_our_id
UNION ALL SELECT 'supplier_info_address',      count(*) FROM clean_data.supplier_info_address
UNION ALL SELECT 'supplier_info_address_type', count(*) FROM clean_data.supplier_info_address_type
UNION ALL SELECT 'supplier_address',           count(*) FROM clean_data.supplier_address
UNION ALL SELECT 'comm_method',                count(*) FROM clean_data.comm_method
UNION ALL SELECT 'identity_invoice_info',      count(*) FROM clean_data.identity_invoice_info
UNION ALL SELECT 'identity_pay_info',          count(*) FROM clean_data.identity_pay_info
UNION ALL SELECT 'payment_way_per_identity',   count(*) FROM clean_data.payment_way_per_identity
UNION ALL SELECT 'payment_address',            count(*) FROM clean_data.payment_address
UNION ALL SELECT 'supplier_document_tax_info', count(*) FROM clean_data.supplier_document_tax_info
UNION ALL SELECT 'supplier_tax_info',          count(*) FROM clean_data.supplier_tax_info
UNION ALL SELECT 'supplier_delivery_tax_code', count(*) FROM clean_data.supplier_delivery_tax_code
UNION ALL SELECT 'supplier_addr_tax_number',   count(*) FROM clean_data.supplier_addr_tax_number
ORDER BY 1;
```
Attendu : une ligne par fournisseur (= total `ifs_fournisseurs`) pour
`supplier_info_general`, `supplier`, `supplier_info_our_id`, `supplier_info_address`,
`identity_invoice_info`, `identity_pay_info`, `payment_way_per_identity`,
`supplier_document_tax_info`, `supplier_tax_info`, `supplier_delivery_tax_code`.
Volumes variables (dependent des donnees SAP) pour `comm_method`, `payment_address`,
`supplier_addr_tax_number`, `supplier_info_address_type`, `supplier_address`.
Aucune table a 0. Toute table vide = script qui a echoue sans bloquer la chaine.

## 5. Coherence des identifiants entre tables (orphelins)

```sql
WITH ref AS (SELECT supplier_id FROM clean_data.supplier_info_general)
SELECT 'supplier'                   t, count(*) FROM clean_data.supplier                   x WHERE x.vendor_no   NOT IN (SELECT supplier_id FROM ref)
UNION ALL SELECT 'supplier_info_our_id',       count(*) FROM clean_data.supplier_info_our_id       x WHERE x.supplier_id NOT IN (SELECT supplier_id FROM ref)
UNION ALL SELECT 'supplier_info_address',      count(*) FROM clean_data.supplier_info_address      x WHERE x.supplier_id NOT IN (SELECT supplier_id FROM ref)
UNION ALL SELECT 'supplier_info_address_type', count(*) FROM clean_data.supplier_info_address_type x WHERE x.supplier_id NOT IN (SELECT supplier_id FROM ref)
UNION ALL SELECT 'supplier_address',           count(*) FROM clean_data.supplier_address           x WHERE x.vendor_no   NOT IN (SELECT supplier_id FROM ref)
UNION ALL SELECT 'comm_method',                count(*) FROM clean_data.comm_method                x WHERE x.supplier_id NOT IN (SELECT supplier_id FROM ref)
UNION ALL SELECT 'identity_invoice_info',      count(*) FROM clean_data.identity_invoice_info      x WHERE x.identity    NOT IN (SELECT supplier_id FROM ref)
UNION ALL SELECT 'identity_pay_info',          count(*) FROM clean_data.identity_pay_info          x WHERE x.identity    NOT IN (SELECT supplier_id FROM ref)
UNION ALL SELECT 'payment_way_per_identity',   count(*) FROM clean_data.payment_way_per_identity   x WHERE x.identity    NOT IN (SELECT supplier_id FROM ref)
UNION ALL SELECT 'payment_address',            count(*) FROM clean_data.payment_address            x WHERE x.identity    NOT IN (SELECT supplier_id FROM ref)
UNION ALL SELECT 'supplier_document_tax_info', count(*) FROM clean_data.supplier_document_tax_info x WHERE x.supplier_id NOT IN (SELECT supplier_id FROM ref)
UNION ALL SELECT 'supplier_tax_info',          count(*) FROM clean_data.supplier_tax_info          x WHERE x.supplier_id NOT IN (SELECT supplier_id FROM ref)
UNION ALL SELECT 'supplier_delivery_tax_code', count(*) FROM clean_data.supplier_delivery_tax_code x WHERE x.supplier_id NOT IN (SELECT supplier_id FROM ref)
UNION ALL SELECT 'supplier_addr_tax_number',   count(*) FROM clean_data.supplier_addr_tax_number   x WHERE x.supplier_id NOT IN (SELECT supplier_id FROM ref)
ORDER BY 1;
```
Attendu : `0` partout. Un compte non nul = une table restee sur l'ancienne
numerotation (script non recompile, ou TRUNCATE qui n'a pas eu lieu).

```sql
-- OUR_ID suit le numero IFS
SELECT count(*) AS incoherents FROM clean_data.supplier_info_our_id
 WHERE our_id <> 'TRIMET-' || supplier_id;
```
Attendu : `0` (le prefixe vient de `etl_default_values`, adapter si modifie).

## 6. Jointures sensibles (celles qui se sont deja cassees)

```sql
-- Script 08 : la TVA doit etre retrouvee via supplier_info_address
SELECT count(*) AS total,
       count(*) FILTER (WHERE vat_no LIKE 'NO_VAT_%') AS sans_tva
  FROM clean_data.supplier_document_tax_info;
```
Attendu : `sans_tva` proche du nombre de fournisseurs sans TVA dans
`ifs_fournisseurs` (~78), PAS du total. `sans_tva = total` = jointure cassee.

```sql
-- Script 14 : payment_address doit pointer sur l'adresse, pas sur le fournisseur
SELECT count(*) AS total,
       count(*) FILTER (WHERE pa.address_id = pa.identity) AS address_id_suspect,
       count(*) FILTER (WHERE pa.account IS NOT NULL)      AS avec_compte
  FROM clean_data.payment_address pa;
```
Attendu : `address_id_suspect = 0`.

```sql
-- Module articles : purchase_part_supplier passe par le numero SAP legacy
SELECT count(*) AS lignes,
       count(*) FILTER (WHERE vendor_no NOT IN (SELECT supplier_id FROM clean_data.supplier_info_general)) AS orphelins
  FROM clean_data.purchase_part_supplier;
```
Attendu : `orphelins = 0` (table vide = normal si le module articles n'a pas tourne).

## 7. Doublons et source

```sql
SELECT (SELECT count(*) FROM (SELECT supplier_id FROM clean_data.supplier_info_general
                               GROUP BY 1 HAVING count(*) > 1) d) AS doublons_supplier_id,
       (SELECT count(*) FROM (SELECT numero_compte_ifs FROM clean_data.ifs_fournisseurs
                               GROUP BY 1 HAVING count(*) > 1) d) AS doublons_numero_ifs,
       (SELECT count(*) FROM raw_data.selection_fournisseurs_stg)  AS lignes_staging,
       (SELECT count(DISTINCT LPAD(TRIM(numero_compte_sap), 10, '0'))
          FROM raw_data.selection_fournisseurs_stg)                AS fournisseurs_staging;
```
Attendu : `0` doublon. Si `lignes_staging > fournisseurs_staging`, plusieurs
imports se sont empiles dans le staging : le script 01 s'en protege par un
`DISTINCT ON`, mais verifier que c'est bien le dernier fichier qui gagne.

## 8. Non-regression des valeurs par defaut

```bash
python3 sql/config/verifier_valeurs_defaut.py /root/migration-Factory/sql/supplier
```
Attendu : code de sortie 0, « 0 SANS ligne seedee », « 0 litteraux encore codes en dur ».

## 9. Exports

Depuis l'ecran d'export fournisseurs (ou l'API), generer le ZIP et verifier que
chaque CSV porte le numero IFS en identifiant. `supplier_info_contact` sort
toujours vide : aucune procedure ne l'alimente (anomalie connue, sans impact).
