# MAINT_MATERIAL_REQ_LINE — mapping SAP vers IFS

Contexte : table IFS des lignes de besoin matière maintenance. Source principale SAP PM : `RESB` (réservations / besoins dépendants / composants d'ordre). Tables de contexte utiles : `AUFK` (ordre administratif), `AFKO` (en-tête planification), `AFVC` (opérations), `AFVV` (dates/valeurs opération), `MARA`/`MAKT`/`MARC`/`MARD` (articles), `PLMZ` (affectation composants gamme).

## Tables SAP à vérifier / charger

Priorité extraction :
1. `RESB` — indispensable ; contient les lignes composants/réservations.
2. `AUFK` — contexte ordre et site/société si besoin.
3. `PLMZ` — complément pour composants affectés à des gammes/opérations.
4. `AFKO`, `AFVC`, `AFVV` — déjà souvent présents pour `JT_TASK`; servent au lien tâche (`AUFPL`/`APLZL`) et WO.
5. `MARA`, `MAKT`, `MARC`, `MARD` — article, libellé, article-site, stock.

Toujours lancer d'abord `/metadata/extract` avec `add_to_config=true` si `RESB`, `AUFK` ou `PLMZ` n'existent pas dans `raw_data`, puis `/extract` avec `user_id='schibout'`.

## Mapping principal

- `RESB.RSNUM` -> `maint_material_order_no` (n° réservation SAP assimilé au bon de sortie matière maintenance)
- `RESB.RSPOS` -> `line_item_no` / `plan_line_no`
- `RESB.MATNR` -> `part_no` après trim et suppression des zéros à gauche
- `RESB.WERKS` -> `spare_contract`, `contract`, `catalog_contract`, `supply_site` avec règle projet `9200 -> SJ`, `9000 -> CS`, sinon code WERKS tronqué 5
- `RESB.BDTER` -> `date_required` (`YYYYMMDD` -> timestamp)
- `RESB.BDMNG` -> `plan_qty`
- `RESB.AUFNR` -> `wo_no`
- `RESB.AUFPL` + `RESB.APLZL` -> `task_seq = AUFPL::numeric * 100000000 + APLZL::numeric`, même convention que `clean_data.alimenter_jt_task()`
- `RESB.ENMNG` -> `qty_issued`
- `RESB.BDMNG - RESB.ENMNG` -> `qty_left`
- `RESB.ENWRT` -> `cost`
- `RESB.EBELN` / `RESB.EBELP` -> `purchase_order_no` / `purchase_order_line_no`
- `RESB.BANFN` / `RESB.BNFPO` -> `purchase_req_no` / `purchase_req_line_no`
- `RESB.LIFNR` -> `vendor_no`
- `RESB.WAERS` -> `currency_code`
- `RESB.SERNR` -> `serial_no`
- `RESB.SGTXT` -> `note`
- constantes IFS utiles : `part_ownership_db='COMPANY OWNED'`, `supply_code_db='INVENT_ORDER'`, `objtype='MaintMaterialReqLine'`, `objversion='1'`

Champs calculés par IFS à ne pas forcer sauf besoin métier : `qty`, `qty_short`, `qty_assigned`, `qty_returned`, prix/facturation, `objid` réel IFS.

## Pattern DDL / loader

Créer `clean_data.maint_material_req_line` depuis `/opt/data/ifs_model_analysis/ifs_fields_catalog.csv` filtré sur `target_table='MAINT_MATERIAL_REQ_LINE'` : 101 colonnes dans le lot opérations. Conventions habituelles `clean_data` : snake_case, nullable, pas de PK/default, commentaires depuis les libellés Excel.

Fonction recommandée : `clean_data.alimenter_maint_material_req_line()` :
- `INSERT ... SELECT DISTINCT ON (r.mandt, r.rsnum, r.rspos)` depuis `raw_data.resb r`
- `LEFT JOIN raw_data.aufk a ON a.mandt = r.mandt AND a.aufnr = r.aufnr` pour contexte éventuel
- filtres : `matnr` non vide, `xloek` vide, `kzear` vide
- idempotence : `NOT EXISTS` sur `(maint_material_order_no, line_item_no)`
- journaliser dans `clean_data.etl_log`

## Vérifications

Après extraction et fonction :

```sql
SELECT 'raw_data.resb' AS table_name, count(*) FROM raw_data.resb
UNION ALL SELECT 'clean_data.maint_material_req_line', count(*) FROM clean_data.maint_material_req_line;
```

Si `raw_data.resb = 0`, la fonction peut réussir avec 0 ligne : ce n'est pas une erreur du loader, c'est que l'extraction SAP n'a pas encore ramené de données ou que le périmètre SAP est vide/bloqué.
