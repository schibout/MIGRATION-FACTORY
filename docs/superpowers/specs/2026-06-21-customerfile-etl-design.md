# Module ETL `customerFile` — Conception

Date : 2026-06-21
Auteur : Samir (via Claude Code)
Dossier cible : `sql/customerFile/`

## 1. Objectif

Créer le jeu complet (21 procédures stockées) qui alimente les tables `clean_data`
du domaine *Customer* à partir de la table plate `raw_data.file_customer`, à l'image
des modules existants `sql/customer/` (source SAP brute) et `sql/customer_phl/`
(source plate `client_phl`).

`customerFile` est une **source alternative** : les procédures font `TRUNCATE + INSERT`
sur les **mêmes** tables `clean_data` que `customer` et `customer_phl`. On exécute donc
un seul de ces trois modules à la fois (jamais en concurrence).

## 2. Découverte structurante

`raw_data.file_customer` a quasiment la **même structure** que la table maître
`clean_data.ifs_customer` du module SAP. Les procédures `customerFile` sont donc les
procédures `sql/customer/sp_*_from_sap.sql` avec **la table maître basculée** :

| Module `customer` (SAP)            | Module `customerFile`                         |
|------------------------------------|-----------------------------------------------|
| `clean_data.ifs_customer ifs`      | `raw_data.file_customer fc` (via CTE)         |
| `ifs.customer_number`              | `fc.customer_id` (expression, voir §3)        |
| `ifs.numero_adresse`               | `fc.address_id` (expression, voir §3)         |
| `ifs.company_code`                 | `fc.bukrs`                                     |
| `ifs.sales_organization`           | `fc.vkorg`                                     |
| `ifs.<autre_colonne>`              | `fc.<même_colonne>` (noms identiques)         |

Les jointures de repli vers les tables SAP brutes (`KNA1`, `KNB1`, `KNVV`, …) sont
**conservées** (décision validée) : `fc.kunnr` sert de clé de jointure ;
`COALESCE(fc.col, sap.col)` comble les colonnes vides du fichier.

## 3. CTE source commune à toutes les procédures

Chaque procédure remplace la table maître par cette CTE (les alias `fc.*` du corps
restent inchangés par rapport au module SAP) :

```sql
WITH fc AS (
    SELECT
        f.*,
        COALESCE(
            NULLIF(TRIM(f.nouveau_compte_ifs), ''),
            NULLIF(TRIM(f.num_corrige), ''),
            TRIM(f.kunnr)
        )                                        AS customer_id,
        COALESCE(NULLIF(TRIM(f.numero_adresse), ''), '1') AS address_id
    FROM raw_data.file_customer f
    WHERE COALESCE(
            NULLIF(TRIM(f.nouveau_compte_ifs), ''),
            NULLIF(TRIM(f.num_corrige), ''),
            TRIM(f.kunnr)
        ) IS NOT NULL
)
SELECT DISTINCT ON (...) ...
FROM fc
LEFT JOIN raw_data.KNA1 k  ON fc.kunnr = k.KUNNR  AND (k.LOEVM IS NULL OR k.LOEVM = '')
LEFT JOIN raw_data.KNB1 kb ON fc.kunnr = kb.KUNNR AND fc.bukrs = kb.BUKRS AND (kb.LOEVM IS NULL OR kb.LOEVM = '')
LEFT JOIN raw_data.KNVV kv ON fc.kunnr = kv.KUNNR AND fc.vkorg = kv.VKORG AND (kv.LOEVM IS NULL OR kv.LOEVM = '')
... -- autres jointures selon la procédure source (T005T, etc.)
```

Clé métier propagée partout : `customer_id` (= `nouveau_compte_ifs` avec repli
`num_corrige` puis `kunnr`). `address_id` = `numero_adresse` (repli `'1'`).

## 4. Règles de transformation issues du module SAP

- **Transcodification** : `public.get_transcodification('LANGUAGE', COALESCE(fc.language, k.SPRAS))`
  → `default_language_db`. (Seule catégorie utilisée par le module `customer`.)
- **Pays** : conserver la logique SAP `CASE WHEN COALESCE(...) IN ('SZ') THEN NULL` pour
  `country_db` (évite l'erreur IFS IsoCountry.NOTEXIST).
- **Dates SAP** (texte `YYYYMMDD` dans `file_customer`) : parser via
  `CASE WHEN LENGTH(TRIM(x)) = 8 THEN TO_DATE(x,'YYYYMMDD') ELSE NULL END`.
- **Champs déjà au format IFS présents dans le fichier** :
  - `fc.code_tva_ifs`  → `def_vat_code` (au lieu de la constante du module SAP)
  - `fc.terme_reglement` → `pay_term_id`  (au lieu de la constante du module SAP)
- **Constantes IFS en dur** : identiques au module `customer` (`PARTY_TYPE='Customer'`/
  `PARTY_TYPE_DB='CUSTOMER'`, `company='TRIMET'`, etc. — voir chaque procédure source).
- **Adresse / comm method** : construites depuis les colonnes propres de `file_customer`
  (`street`, `postal_code`, `city`, `country`, `region`, `telephone`, `fax`,
  `telephone_2`) avec repli `COALESCE` sur les colonnes SAP correspondantes.

## 5. Liste des 21 procédures (cibles = mêmes que `customer`)

Suffixe de nommage : `_from_file_customer`. Granularité `DISTINCT ON` identique au
module source.

Ordre d'exécution (= `compile.sh`) :

1. `sp_insert_customer_info_from_file_customer`            → `customer_info` (clé: customer_id)
2. `sp_insert_customer_info_cfv_from_file_customer`        → `customer_info_cfv`
3. `sp_insert_customer_info_address_from_file_customer`    → `customer_info_address` (TRUNCATE CASCADE ; clé: customer_id,address_id)
4. `sp_insert_customer_address_type_single_file` (sous-proc paramétrée DELIVERY/INVOICE/DOCUMENT)
5. `sp_insert_customer_address_type_from_file_customer`    → `customer_info_address_type` (orchestrateur)
6. `sp_insert_cus_comm_method_from_file_customer`          → `cus_comm_method` (téléphone/fax/email)
7. `sp_insert_customer_tax_info_from_file_customer`        → `customer_tax_info`
8. `sp_insert_customer_delivery_tax_info_from_file_customer` → `customer_delivery_tax_info`
9. `sp_insert_customer_delivery_fee_code_from_file_customer` → `customer_delivery_fee_code`
10. `sp_insert_customer_document_tax_info_from_file_customer` → `customer_document_tax_info`
11. `sp_insert_customer_tax_free_tax_code_from_file_customer` → `customer_tax_free_tax_code`
12. `sp_insert_customer_addr_tax_number_from_file_customer` → `customer_addr_tax_number`
13. `sp_insert_customer_del_tax_exempt_from_file_customer`  → `customer_del_tax_exempt`
14. `sp_insert_cus_ident_invoice_info_from_file_customer`   → `cus_ident_invoice_info`
15. `sp_insert_cus_identity_pay_info_from_file_customer`    → `cus_identity_pay_info`
16. `sp_insert_cus_paym_way_per_ident_from_file_customer`   → `cus_paym_way_per_ident`
17. `sp_insert_cus_payment_address_from_file_customer`      → `cus_payment_address`
18. `sp_insert_payment_way_per_identity_from_file_customer` → `payment_way_per_identity`
19. `sp_insert_customer_credit_info_from_file_customer`     → `customer_credit_info`
20. `sp_insert_cust_ord_customer_from_file_customer`        → `cust_ord_customer`
21. `sp_insert_cust_ord_customer_address_from_file_customer`→ `cust_ord_customer_address`

Procédures de maintenance (mêmes corps que les `_phl`, suffixe `_file`) :
- `sp_update_customer_id_cascade_file(p_old VARCHAR, p_new VARCHAR)`
- `sp_renumber_all_customer_ids_file(p_start INTEGER DEFAULT 700000)`

Chaque procédure : structure `CREATE OR REPLACE PROCEDURE … LANGUAGE plpgsql`, bloc
`DECLARE/BEGIN`, `RAISE NOTICE`, `TRUNCATE`, `INSERT … SELECT`, `GET DIAGNOSTICS`,
`EXCEPTION WHEN OTHERS`, à l'identique du module `customer`.

## 6. Scripts d'accompagnement

`sql/customerFile/compile.sh` et `sql/customerFile/export_procedures.sh` existent déjà
(copies PHL). Les mettre à jour :
- En-têtes/messages : « CLIENT FILE » au lieu de « CLIENT PHL ».
- Liste `files=(...)` / `procedures=(...)` : les 23 noms ci-dessus dans l'ordre §5
  (les 21 + sous-proc `_single` + 2 maintenance).
- Conserver la même config de connexion et la même logique psql.

## 7. Validation / tests

Exécution sur le serveur distant uniquement (cf. règle projet — pas de psql local) :
```bash
cd sql/customerFile && ./compile.sh        # compile les 23 procédures
# puis, dans psql, appeler les procédures dans l'ordre et vérifier les compteurs RAISE NOTICE
```
Contrôles de cohérence : `COUNT(*)` par table cible vs nombre de clients distincts de
`file_customer` ; vérifier qu'aucune clé `customer_id` n'est NULL ; échantillon de
`customer_info` / `customer_info_address`.

## 8. Hors périmètre (YAGNI)

- Pas de modification des tables `clean_data` (DDL inchangé).
- Pas de modification des modules `customer` / `customer_phl`.
- Pas d'intégration UI/API (les procédures sont appelées via `compile.sh` / psql).
- `siren` du fichier : non mappé pour l'instant (aucune cible IFS évidente).
