<!-- converted from contrat_interface_SAP_IFS_Articles.xlsx -->

## Sheet: Legende
| Contrat d'interface — Module Articles (SAP ECC 6.0 → IFS) |
| --- |
| Objet : documenter, pour chacune des 7 etapes du chargement des articles (module ETL "Donnees de base des Articles", backend/etl_modules/etl_inventory_part.py), l'origine de chaque colonne cible et la regle de transformation appliquee, afin que le metier valide le mapping. Chaque onglet correspond a une table clean_data et au script qui l'alimente, dans l'ordre d'execution. |
| Structure d'un onglet table |
| • Colonne cible : Nom de la colonne dans la table clean_data (cible finale). |
| • Type / Longueur : Type et longueur reels, lus directement dans la base clean_data. |
| • Champ / Table source : Table(s)/champ(s) source(s) (raw_data SAP, clean_data amont, ou constante). |
| • Systeme source : SAP, QlikView (fichier de perimetre des articles), IFS (table clean_data amont), Config (etl_default_values / TranscodificationTable), ou Technique. |
| • Regle de transformation / Condition : COALESCE, CASE, concatenation, valeur par defaut... Colonne cle a relire cote metier. |
| • Exemple de valeur : valeur reellement presente en base apres le dernier chargement. |
| • Valide metier (O/N) / Remarques metier / Date validation : Cellules en jaune, a remplir par le metier. |
| Les 7 etapes (dans l'ordre d'execution) |
| 01. IFS_ARTICLE_MAITRE — clean_data.ifs_article_maitre (50 colonnes). TABLE PILOTE. Perimetre = raw_data.export_article_qlikview (liste des articles a migrer), restreint aux articles ayant une fiche MARA active (mandt 700, non marques a supprimer). Agrege les donnees SAP par article : centres (MARC), commercial (MVKE), evaluation (MBEW), stocks (MARD), fournisseur principal (EINA/LFA1). |
| 02. PART_CATALOG — clean_data.part_catalog (19 colonnes). Catalogue des pieces IFS : table de BASE du module. Reprise 1:1 de ifs_article_maitre. Toutes les tables suivantes filtrent leur contenu sur la presence de l'article ici. |
| 03. INVENTORY_PART — clean_data.inventory_part (41 colonnes). Article d'inventaire par site (contract). Un enregistrement par couple article x centre SAP 9200 (SJ) / 9000 (CS). |
| 04. INVENT_PART_PLAN — clean_data.invent_part_plan (39 colonnes). Parametres de planification (lot, stock de securite, point de commande) par article x site. Filtre sur la presence dans inventory_part. |
| 05. PURCHASE_PART — clean_data.purchase_part (55 colonnes). Article d'achat par site. Centres 9200 / 9000 / 2200 et approvisionnement externe (MARC.BESKZ dans F, X). Les articles de vente (raw_data.articles_vente_sap) en sont EXCLUS : ils relevent de SALES_PART. |
| 06. PURCHASE_PART_SUPPLIER — clean_data.purchase_part_supplier (21 colonnes). Lien article x fournisseur issu des fiches info-achat SAP (EINA/EINE). Le fournisseur est remappe sur son NOUVEAU numero IFS (600xxx) via supplier_info_general.supplier_legacy_sap_id. |
| 07. SALES_PART — clean_data.sales_part (41 colonnes). Article de vente. Perimetre = raw_data.articles_vente_sap, restreint aux types d'article FERT / HALB / DIEN / NLAG / HIBE / ERSA presents dans part_catalog. |
| Points d'attention transverses reperes (a faire trancher par le metier) |
| ⚠ Perimetre — La liste des articles a migrer est pilotee par raw_data.export_article_qlikview (18 652 articles). Cette table n'est alimentee par AUCUN import applicatif : elle est chargee a la main. Si elle est vide au moment d'un chargement, les 7 tables du module se vident en cascade sans erreur. |
| ⚠ 01 — codification_id et new_transco ne sont plus alimentees : la table clean_data.mapping_codification_articles a ete retiree du mapping sur demande metier, et aucune source de remplacement n'est branchee. Les deux colonnes sortent a NULL. |
| ⚠ 01 — 89 articles du perimetre n'ont pas de libelle SAP (MAKT) en F/E/D : leur designation provient de export_article_qlikview. Les tables 03 et 05 exigeant MAKT en francais, ces articles n'apparaitront pas en article d'inventaire ni en article d'achat. |
| ⚠ 05 — Les articles de vente (raw_data.articles_vente_sap) sont exclus de PURCHASE_PART (264 articles) : achat et vente sont disjoints. A confirmer si certains articles doivent etre a la fois achetes et vendus. |
| ⚠ 06 — primary_vendor_db vaut 'Y' sur TOUTES les lignes, alors que 6 812 couples (contract, part_no) ont plusieurs fournisseurs (jusqu'a 12). IFS n'admet qu'un seul fournisseur principal par article et par site : le chargement rejettera ou ecrasera. Un seul 'Y' par couple doit etre designe (par exemple la fiche info-achat la plus recente). |
| ⚠ 06 — 3 744 liens article/fournisseur SAP sont perdus car le fournisseur (250 LIFNR distincts) n'existe pas dans clean_data.supplier_info_general. Le INNER JOIN est volontaire (un lien vers un fournisseur non migre serait rejete au chargement IFS), mais cela represente 11 % des liens : a valider cote metier. |
| ⚠ Couples <colonne> / <colonne>_db : par convention du depot, seule la colonne _db est renseignee. Les colonnes sans suffixe restent NULL. |
| Onglet 00_VALEURS_PAR_DEFAUT |
| Liste exhaustive (164 lignes) des valeurs enregistrees dans public.etl_default_values pour les 7 tables du module articles — celles que les scripts appellent via public.get_default_value(). Regroupee par onglet/table puis par colonne. Les lignes grisees correspondent a des variantes inactives (is_active = FALSE). C'est ici que la VALEUR reelle de chaque parametre est visible et modifiable (Configuration > Valeurs par defaut dans l'outil). |
## Sheet: 00_VALEURS_PAR_DEFAUT
| Onglet | Table cible (etl_default_values.table_cible) | Colonne | Variante | Type valeur | Valeur actuelle | Actif | Module | Description | Remarque metier |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 02_PART_CATALOG  —  clean_data.part_catalog |  |  |  |  |  |  |  |  |  |
| 02_PART_CATALOG | clean_data.part_catalog | allow_as_not_consumed_db | STANDARD | CONSTANTE | FALSE | Oui | articlePhl | Source : ajouter_article_silicium.sql (+ modules inventory) |  |
| 02_PART_CATALOG | clean_data.part_catalog | catch_unit_enabled_db | STANDARD | CONSTANTE | FALSE | Oui | articlePhl | Source : ajouter_article_silicium.sql (+ modules inventory) |  |
| 02_PART_CATALOG | clean_data.part_catalog | condition_code_usage_db | STANDARD | CONSTANTE | NOT_ALLOW_COND_CODE | Oui | articlePhl | Source : ajouter_article_silicium.sql (+ modules inventory) |  |
| 02_PART_CATALOG | clean_data.part_catalog | configurable_db | STANDARD | CONSTANTE | NOT CONFIGURED | Oui | articlePhl | Source : ajouter_article_silicium.sql (+ modules inventory) |  |
| 02_PART_CATALOG | clean_data.part_catalog | eng_serial_tracking_code_db | STANDARD | CONSTANTE | NOT SERIAL TRACKING | Oui | articlePhl | Source : ajouter_article_silicium.sql (+ modules inventory) |  |
| 02_PART_CATALOG | clean_data.part_catalog | multilevel_tracking_db | STANDARD | CONSTANTE | TRACKING_OFF | Oui | articlePhl | Source : ajouter_article_silicium.sql (+ modules inventory) |  |
| 02_PART_CATALOG | clean_data.part_catalog | position_part_db | STANDARD | CONSTANTE | NOT POSITION PART | Oui | articlePhl | Source : ajouter_article_silicium.sql (+ modules inventory) |  |
| 02_PART_CATALOG | clean_data.part_catalog | receipt_issue_serial_track_db | STANDARD | CONSTANTE | FALSE | Oui | articlePhl | Source : ajouter_article_silicium.sql (+ modules inventory) |  |
| 02_PART_CATALOG | clean_data.part_catalog | serial_rule_db | STANDARD | CONSTANTE | MANUAL | Oui | articlePhl | Source : ajouter_article_silicium.sql (+ modules inventory) |  |
| 02_PART_CATALOG | clean_data.part_catalog | serial_tracking_code_db | STANDARD | CONSTANTE | NOT SERIAL TRACKING | Oui | articlePhl | Source : ajouter_article_silicium.sql (+ modules inventory) |  |
| 02_PART_CATALOG | clean_data.part_catalog | stop_arrival_issued_serial_db | STANDARD | CONSTANTE | TRUE | Oui | articlePhl | Source : ajouter_article_silicium.sql (+ modules inventory) |  |
| 02_PART_CATALOG | clean_data.part_catalog | stop_new_serial_in_rma_db | STANDARD | CONSTANTE | TRUE | Oui | articlePhl | Source : ajouter_article_silicium.sql (+ modules inventory) |  |
| 02_PART_CATALOG | clean_data.part_catalog | sub_lot_rule_db | STANDARD | CONSTANTE | NO_SUBLOTS | Oui | articlePhl | Source : ajouter_article_silicium.sql (+ modules inventory) |  |
| 03_INVENTORY_PART  —  clean_data.inventory_part |  |  |  |  |  |  |  |  |  |
| 03_INVENTORY_PART | clean_data.inventory_part | asset_class | STANDARD | CONSTANTE | S | Oui | articlePhl | Source : ajouter_article_silicium.sql (+ modules inventory) |  |
| 03_INVENTORY_PART | clean_data.inventory_part | automatic_capability_check_db | STANDARD | CONSTANTE | NO AUTOMATIC CAPABILITY CHECK | Oui | articlePhl | Source : ajouter_article_silicium.sql (+ modules inventory) |  |
| 03_INVENTORY_PART | clean_data.inventory_part | avail_activity_status_db | STANDARD | CONSTANTE | CHANGED | Oui | articlePhl | Source : ajouter_article_silicium.sql (+ modules inventory) |  |
| 03_INVENTORY_PART | clean_data.inventory_part | co_reserve_onh_analys_flag_db | STANDARD | CONSTANTE | N | Oui | articlePhl | Source : ajouter_article_silicium.sql (+ modules inventory) |  |
| 03_INVENTORY_PART | clean_data.inventory_part | count_variance | STANDARD | CONSTANTE | 0 | Oui | articlePhl | Source : ajouter_article_silicium.sql (+ modules inventory) |  |
| 03_INVENTORY_PART | clean_data.inventory_part | cycle_code_db | STANDARD | CONSTANTE | N | Oui | articlePhl | Source : ajouter_article_silicium.sql (+ modules inventory) |  |
| 03_INVENTORY_PART | clean_data.inventory_part | cycle_period | STANDARD | CONSTANTE | 0 | Oui | articlePhl | Source : ajouter_article_silicium.sql (+ modules inventory) |  |
| 03_INVENTORY_PART | clean_data.inventory_part | dop_connection_db | STANDARD | CONSTANTE | AUT | Oui | articlePhl | Source : ajouter_article_silicium.sql (+ modules inventory) |  |
| 03_INVENTORY_PART | clean_data.inventory_part | dop_netting_db | STANDARD | CONSTANTE | NONET | Oui | articlePhl | Source : ajouter_article_silicium.sql (+ modules inventory) |  |
| 03_INVENTORY_PART | clean_data.inventory_part | excl_ship_pack_proposal_db | STANDARD | CONSTANTE | FALSE | Oui | articlePhl | Source : ajouter_article_silicium.sql (+ modules inventory) |  |
| 03_INVENTORY_PART | clean_data.inventory_part | ext_service_cost_method_db | STANDARD | CONSTANTE | EXCLUDE SERVICE COST | Oui | articlePhl | Source : ajouter_article_silicium.sql (+ modules inventory) |  |
| 03_INVENTORY_PART | clean_data.inventory_part | forecast_consumption_flag_db | STANDARD | CONSTANTE | FORECAST | Oui | articlePhl | Source : ajouter_article_silicium.sql (+ modules inventory) |  |
| 03_INVENTORY_PART | clean_data.inventory_part | frequency_class_db | STANDARD | CONSTANTE | VERY SLOW MOVER | Oui | articlePhl | Source : ajouter_article_silicium.sql (+ modules inventory) |  |
| 03_INVENTORY_PART | clean_data.inventory_part | inventory_part_cost_level_db | STANDARD | CONSTANTE | COST PER PART | Oui | articlePhl | Source : ajouter_article_silicium.sql (+ modules inventory) |  |
| 03_INVENTORY_PART | clean_data.inventory_part | invoice_consideration_db | STANDARD | CONSTANTE | TRANSACTION BASED | Oui | articlePhl | Source : ajouter_article_silicium.sql (+ modules inventory) |  |
| 03_INVENTORY_PART | clean_data.inventory_part | lead_time_code_db | STANDARD | CONSTANTE | P | Oui | inventory | Source : alimenter_inventory_part.sql |  |
| 03_INVENTORY_PART | clean_data.inventory_part | lifecycle_stage_db | STANDARD | CONSTANTE | DEVELOPMENT | Oui | articlePhl | Source : ajouter_article_silicium.sql (+ modules inventory) |  |
| 03_INVENTORY_PART | clean_data.inventory_part | mandatory_expiration_date_db | STANDARD | CONSTANTE | FALSE | Oui | articlePhl | Source : ajouter_article_silicium.sql (+ modules inventory) |  |
| 03_INVENTORY_PART | clean_data.inventory_part | manuf_leadtime | STANDARD | CONSTANTE | 0 | Oui | articlePhl | Source : ajouter_article_silicium.sql (+ modules inventory) |  |
| 03_INVENTORY_PART | clean_data.inventory_part | negative_on_hand_db | STANDARD | CONSTANTE | NEG ONHAND NOT OK | Oui | articlePhl | Source : ajouter_article_silicium.sql (+ modules inventory) |  |
| 03_INVENTORY_PART | clean_data.inventory_part | oe_alloc_assign_flag_db | STANDARD | CONSTANTE | N | Oui | articlePhl | Source : ajouter_article_silicium.sql (+ modules inventory) |  |
| 03_INVENTORY_PART | clean_data.inventory_part | onhand_analysis_flag_db | STANDARD | CONSTANTE | N | Oui | articlePhl | Source : ajouter_article_silicium.sql (+ modules inventory) |  |
| 03_INVENTORY_PART | clean_data.inventory_part | part_status | STANDARD | CONSTANTE | A | Oui | articlePhl | Source : ajouter_article_silicium.sql (+ modules inventory) |  |
| 03_INVENTORY_PART | clean_data.inventory_part | planner_buyer | STANDARD | CONSTANTE | * | Oui | articlePhl | Source : ajouter_article_silicium.sql (+ modules inventory) |  |
| 03_INVENTORY_PART | clean_data.inventory_part | purch_leadtime | STANDARD | CONSTANTE | 0 | Oui | articlePhl | Source : ajouter_article_silicium.sql (+ modules inventory) |  |
| 03_INVENTORY_PART | clean_data.inventory_part | qty_calc_rounding | STANDARD | CONSTANTE | 0 | Oui | articlePhl | Source : ajouter_article_silicium.sql (+ modules inventory) |  |
| 03_INVENTORY_PART | clean_data.inventory_part | reset_config_std_cost_db | STANDARD | CONSTANTE | FALSE | Oui | articlePhl | Source : ajouter_article_silicium.sql (+ modules inventory) |  |
| 03_INVENTORY_PART | clean_data.inventory_part | shortage_flag_db | STANDARD | CONSTANTE | Y | Oui | articlePhl | Source : ajouter_article_silicium.sql (+ modules inventory) |  |
| 03_INVENTORY_PART | clean_data.inventory_part | stock_management_db | STANDARD | CONSTANTE | Y | Oui | articlePhl | Source : ajouter_article_silicium.sql (+ modules inventory) |  |
| 03_INVENTORY_PART | clean_data.inventory_part | supply_code_db | STANDARD | CONSTANTE | IO | Oui | articlePhl | Source : ajouter_article_silicium.sql (+ modules inventory) |  |
| 03_INVENTORY_PART | clean_data.inventory_part | type_code_db | STANDARD | CONSTANTE | 4 | Oui | inventory | Source : alimenter_inventory_part.sql |  |
| 03_INVENTORY_PART | clean_data.inventory_part | zero_cost_flag_db | STANDARD | CONSTANTE | N | Oui | inventory | Source : alimenter_inventory_part.sql |  |
| 04_INVENT_PART_PLAN  —  clean_data.invent_part_plan |  |  |  |  |  |  |  |  |  |
| 04_INVENT_PART_PLAN | clean_data.invent_part_plan | acquired_supply_type | STANDARD | CONSTANTE | (NULL) | Oui | inventory | Source : alimenter_inventory_part_planning.sql |  |
| 04_INVENT_PART_PLAN | clean_data.invent_part_plan | acquired_supply_type_db | STANDARD | CONSTANTE | R | Oui | inventory | Source : alimenter_inventory_part_planning.sql |  |
| 04_INVENT_PART_PLAN | clean_data.invent_part_plan | carry_rate | STANDARD | CONSTANTE | 0 | Oui | inventory | Source : alimenter_inventory_part_planning.sql |  |
| 04_INVENT_PART_PLAN | clean_data.invent_part_plan | lot_size_auto | STANDARD | CONSTANTE | (NULL) | Oui | inventory | Source : alimenter_inventory_part_planning.sql |  |
| 04_INVENT_PART_PLAN | clean_data.invent_part_plan | lot_size_auto_db | STANDARD | CONSTANTE | N | Oui | inventory | Source : alimenter_inventory_part_planning.sql |  |
| 04_INVENT_PART_PLAN | clean_data.invent_part_plan | manuf_supply_type | STANDARD | CONSTANTE | (NULL) | Oui | inventory | Source : alimenter_inventory_part_planning.sql |  |
| 04_INVENT_PART_PLAN | clean_data.invent_part_plan | manuf_supply_type_db | STANDARD | CONSTANTE | R | Oui | inventory | Source : alimenter_inventory_part_planning.sql |  |
| 04_INVENT_PART_PLAN | clean_data.invent_part_plan | maxweek_supply | STANDARD | CONSTANTE | 0 | Oui | inventory | Source : alimenter_inventory_part_planning.sql |  |
| 04_INVENT_PART_PLAN | clean_data.invent_part_plan | mul_order_qty | STANDARD | CONSTANTE | 0 | Oui | inventory | Source : alimenter_inventory_part_planning.sql |  |
| 04_INVENT_PART_PLAN | clean_data.invent_part_plan | order_point_qty_auto | STANDARD | CONSTANTE | (NULL) | Oui | inventory | Source : alimenter_inventory_part_planning.sql |  |
| 04_INVENT_PART_PLAN | clean_data.invent_part_plan | order_point_qty_auto_db | STANDARD | CONSTANTE | N | Oui | inventory | Source : alimenter_inventory_part_planning.sql |  |
| 04_INVENT_PART_PLAN | clean_data.invent_part_plan | order_requisition | STANDARD | CONSTANTE | (NULL) | Oui | inventory | Source : alimenter_inventory_part_planning.sql |  |
| 04_INVENT_PART_PLAN | clean_data.invent_part_plan | order_requisition_db | STANDARD | CONSTANTE | R | Oui | inventory | Source : alimenter_inventory_part_planning.sql |  |
| 04_INVENT_PART_PLAN | clean_data.invent_part_plan | planning_method_auto | STANDARD | CONSTANTE | (NULL) | Oui | inventory | Source : alimenter_inventory_part_planning.sql |  |
| 04_INVENT_PART_PLAN | clean_data.invent_part_plan | planning_method_auto_db | STANDARD | CONSTANTE | TRUE | Oui | inventory | Source : alimenter_inventory_part_planning.sql |  |
| 04_INVENT_PART_PLAN | clean_data.invent_part_plan | proposal_release | STANDARD | CONSTANTE | (NULL) | Oui | inventory | Source : alimenter_inventory_part_planning.sql |  |
| 04_INVENT_PART_PLAN | clean_data.invent_part_plan | proposal_release_db | STANDARD | CONSTANTE | RELEASE | Oui | inventory | Source : alimenter_inventory_part_planning.sql |  |
| 04_INVENT_PART_PLAN | clean_data.invent_part_plan | safety_stock_auto | STANDARD | CONSTANTE | (NULL) | Oui | inventory | Source : alimenter_inventory_part_planning.sql |  |
| 04_INVENT_PART_PLAN | clean_data.invent_part_plan | safety_stock_auto_db | STANDARD | CONSTANTE | N | Oui | inventory | Source : alimenter_inventory_part_planning.sql |  |
| 04_INVENT_PART_PLAN | clean_data.invent_part_plan | sched_capacity | STANDARD | CONSTANTE | (NULL) | Oui | inventory | Source : alimenter_inventory_part_planning.sql |  |
| 04_INVENT_PART_PLAN | clean_data.invent_part_plan | sched_capacity_db | STANDARD | CONSTANTE | I | Oui | inventory | Source : alimenter_inventory_part_planning.sql |  |
| 04_INVENT_PART_PLAN | clean_data.invent_part_plan | service_rate | STANDARD | CONSTANTE | 0 | Oui | inventory | Source : alimenter_inventory_part_planning.sql |  |
| 04_INVENT_PART_PLAN | clean_data.invent_part_plan | setup_cost | STANDARD | CONSTANTE | 0 | Oui | inventory | Source : alimenter_inventory_part_planning.sql |  |
| 04_INVENT_PART_PLAN | clean_data.invent_part_plan | shrinkage_fac | STANDARD | CONSTANTE | 0 | Oui | inventory | Source : alimenter_inventory_part_planning.sql |  |
| 04_INVENT_PART_PLAN | clean_data.invent_part_plan | split_manuf_acquired | STANDARD | CONSTANTE | (NULL) | Oui | inventory | Source : alimenter_inventory_part_planning.sql |  |
| 04_INVENT_PART_PLAN | clean_data.invent_part_plan | split_manuf_acquired_db | STANDARD | CONSTANTE | NO_SPLIT | Oui | inventory | Source : alimenter_inventory_part_planning.sql |  |
| 05_PURCHASE_PART  —  clean_data.purchase_part |  |  |  |  |  |  |  |  |  |
| 05_PURCHASE_PART | clean_data.purchase_part | acquisition_origin | STANDARD | CONSTANTE | (NULL) | Non | articlePhl | Source : alimenter_purchase_part_phl.sql (+ modules inventory) |  |
| 05_PURCHASE_PART | clean_data.purchase_part | acquisition_reason_id | STANDARD | CONSTANTE | (NULL) | Non | articlePhl | Source : alimenter_purchase_part_phl.sql (+ modules inventory) |  |
| 05_PURCHASE_PART | clean_data.purchase_part | acquisition_type | STANDARD | CONSTANTE | (NULL) | Oui | articlePhl | Source : alimenter_purchase_part_phl.sql (+ modules inventory) |  |
| 05_PURCHASE_PART | clean_data.purchase_part | acquisition_type_db | STANDARD | CONSTANTE | PURCHASE | Oui | articlePhl | Source : alimenter_purchase_part_phl.sql (+ modules inventory) |  |
| 05_PURCHASE_PART | clean_data.purchase_part | action_authorized | STANDARD | CONSTANTE | (NULL) | Oui | articlePhl | Source : alimenter_purchase_part_phl.sql (+ modules inventory) |  |
| 05_PURCHASE_PART | clean_data.purchase_part | action_authorized_db | STANDARD | CONSTANTE | WARNING | Oui | articlePhl | Source : alimenter_purchase_part_phl.sql (+ modules inventory) |  |
| 05_PURCHASE_PART | clean_data.purchase_part | action_non_authorized | STANDARD | CONSTANTE | (NULL) | Oui | articlePhl | Source : alimenter_purchase_part_phl.sql (+ modules inventory) |  |
| 05_PURCHASE_PART | clean_data.purchase_part | action_non_authorized_db | STANDARD | CONSTANTE | WARNING | Oui | articlePhl | Source : alimenter_purchase_part_phl.sql (+ modules inventory) |  |
| 05_PURCHASE_PART | clean_data.purchase_part | buyer_code | STANDARD | CONSTANTE | (NULL) | Non | articlePhl | Source : alimenter_purchase_part_phl.sql (+ modules inventory) |  |
| 05_PURCHASE_PART | clean_data.purchase_part | close_code | STANDARD | CONSTANTE | (NULL) | Oui | articlePhl | Source : alimenter_purchase_part_phl.sql (+ modules inventory) |  |
| 05_PURCHASE_PART | clean_data.purchase_part | close_code_db | STANDARD | CONSTANTE | Y | Oui | articlePhl | Source : alimenter_purchase_part_phl.sql (+ modules inventory) |  |
| 05_PURCHASE_PART | clean_data.purchase_part | close_tolerance | STANDARD | CONSTANTE | 0 | Oui | articlePhl | Source : alimenter_purchase_part_phl.sql (+ modules inventory) |  |
| 05_PURCHASE_PART | clean_data.purchase_part | company | STANDARD | CONSTANTE | TRIMET | Oui | articlePhl | Source : alimenter_purchase_part_phl.sql (+ modules inventory) |  |
| 05_PURCHASE_PART | clean_data.purchase_part | dop_pegged_po_update_flag | STANDARD | CONSTANTE | (NULL) | Oui | articlePhl | Source : alimenter_purchase_part_phl.sql (+ modules inventory) |  |
| 05_PURCHASE_PART | clean_data.purchase_part | dop_pegged_po_update_flag_db | STANDARD | CONSTANTE | PLANNED | Oui | articlePhl | Source : alimenter_purchase_part_phl.sql (+ modules inventory) |  |
| 05_PURCHASE_PART | clean_data.purchase_part | eng_attribute | STANDARD | CONSTANTE | (NULL) | Non | articlePhl | Source : alimenter_purchase_part_phl.sql (+ modules inventory) |  |
| 05_PURCHASE_PART | clean_data.purchase_part | nbs_code | STANDARD | CONSTANTE | (NULL) | Non | articlePhl | Source : alimenter_purchase_part_phl.sql (+ modules inventory) |  |
| 05_PURCHASE_PART | clean_data.purchase_part | note_id | STANDARD | CONSTANTE | (NULL) | Non | articlePhl | Source : alimenter_purchase_part_phl.sql (+ modules inventory) |  |
| 05_PURCHASE_PART | clean_data.purchase_part | note_text | STANDARD | CONSTANTE | (NULL) | Non | articlePhl | Source : alimenter_purchase_part_phl.sql (+ modules inventory) |  |
| 05_PURCHASE_PART | clean_data.purchase_part | objid | STANDARD | CONSTANTE | (NULL) | Non | articlePhl | Source : alimenter_purchase_part_phl.sql (+ modules inventory) |  |
| 05_PURCHASE_PART | clean_data.purchase_part | objversion | STANDARD | CONSTANTE | (NULL) | Non | articlePhl | Source : alimenter_purchase_part_phl.sql (+ modules inventory) |  |
| 05_PURCHASE_PART | clean_data.purchase_part | over_delivery | STANDARD | CONSTANTE | (NULL) | Oui | articlePhl | Source : alimenter_purchase_part_phl.sql (+ modules inventory) |  |
| 05_PURCHASE_PART | clean_data.purchase_part | over_delivery_db | STANDARD | CONSTANTE | YES | Oui | articlePhl | Source : alimenter_purchase_part_phl.sql (+ modules inventory) |  |
| 05_PURCHASE_PART | clean_data.purchase_part | over_delivery_tolerance | STANDARD | CONSTANTE | 0 | Oui | articlePhl | Source : alimenter_purchase_part_phl.sql (+ modules inventory) |  |
| 05_PURCHASE_PART | clean_data.purchase_part | package_part_flag | STANDARD | CONSTANTE | (NULL) | Oui | articlePhl | Source : alimenter_purchase_part_phl.sql (+ modules inventory) |  |
| 05_PURCHASE_PART | clean_data.purchase_part | package_part_flag_db | STANDARD | CONSTANTE | FALSE | Oui | articlePhl | Source : alimenter_purchase_part_phl.sql (+ modules inventory) |  |
| 05_PURCHASE_PART | clean_data.purchase_part | process_type | STANDARD | CONSTANTE | STD | Oui | articlePhl | Source : alimenter_purchase_part_phl.sql (+ modules inventory) |  |
| 05_PURCHASE_PART | clean_data.purchase_part | qc_code | STANDARD | CONSTANTE | (NULL) | Non | articlePhl | Source : alimenter_purchase_part_phl.sql (+ modules inventory) |  |
| 05_PURCHASE_PART | clean_data.purchase_part | qc_date | STANDARD | CONSTANTE | (NULL) | Non | articlePhl | Source : alimenter_purchase_part_phl.sql (+ modules inventory) |  |
| 05_PURCHASE_PART | clean_data.purchase_part | qmr_approval_template | STANDARD | CONSTANTE | (NULL) | Non | articlePhl | Source : alimenter_purchase_part_phl.sql (+ modules inventory) |  |
| 05_PURCHASE_PART | clean_data.purchase_part | qsl_approval_template | STANDARD | CONSTANTE | (NULL) | Non | articlePhl | Source : alimenter_purchase_part_phl.sql (+ modules inventory) |  |
| 05_PURCHASE_PART | clean_data.purchase_part | qsr_approval_template | STANDARD | CONSTANTE | (NULL) | Non | articlePhl | Source : alimenter_purchase_part_phl.sql (+ modules inventory) |  |
| 05_PURCHASE_PART | clean_data.purchase_part | qualified_manufacturer | STANDARD | CONSTANTE | (NULL) | Oui | articlePhl | Source : alimenter_purchase_part_phl.sql (+ modules inventory) |  |
| 05_PURCHASE_PART | clean_data.purchase_part | qualified_manufacturer_db | STANDARD | CONSTANTE | FALSE | Oui | articlePhl | Source : alimenter_purchase_part_phl.sql (+ modules inventory) |  |
| 05_PURCHASE_PART | clean_data.purchase_part | qualified_supplier | STANDARD | CONSTANTE | (NULL) | Oui | articlePhl | Source : alimenter_purchase_part_phl.sql (+ modules inventory) |  |
| 05_PURCHASE_PART | clean_data.purchase_part | qualified_supplier_db | STANDARD | CONSTANTE | FALSE | Oui | articlePhl | Source : alimenter_purchase_part_phl.sql (+ modules inventory) |  |
| 05_PURCHASE_PART | clean_data.purchase_part | quality_system_level_id | STANDARD | CONSTANTE | (NULL) | Non | articlePhl | Source : alimenter_purchase_part_phl.sql (+ modules inventory) |  |
| 05_PURCHASE_PART | clean_data.purchase_part | standard_pack_size | STANDARD | CONSTANTE | 1 | Oui | articlePhl | Source : alimenter_purchase_part_phl.sql (+ modules inventory) |  |
| 05_PURCHASE_PART | clean_data.purchase_part | stat_grp | STANDARD | CONSTANTE | (NULL) | Non | articlePhl | Source : alimenter_purchase_part_phl.sql (+ modules inventory) |  |
| 05_PURCHASE_PART | clean_data.purchase_part | statistical_code | STANDARD | CONSTANTE | (NULL) | Non | articlePhl | Source : alimenter_purchase_part_phl.sql (+ modules inventory) |  |
| 05_PURCHASE_PART | clean_data.purchase_part | statistical_code_manuf | STANDARD | CONSTANTE | (NULL) | Non | articlePhl | Source : alimenter_purchase_part_phl.sql (+ modules inventory) |  |
| 05_PURCHASE_PART | clean_data.purchase_part | std_name_description | STANDARD | CONSTANTE | (NULL) | Non | articlePhl | Source : alimenter_purchase_part_phl.sql (+ modules inventory) |  |
| 05_PURCHASE_PART | clean_data.purchase_part | std_name_id | STANDARD | CONSTANTE | (NULL) | Non | articlePhl | Source : alimenter_purchase_part_phl.sql (+ modules inventory) |  |
| 05_PURCHASE_PART | clean_data.purchase_part | taxable | STANDARD | CONSTANTE | (NULL) | Oui | articlePhl | Source : alimenter_purchase_part_phl.sql (+ modules inventory) |  |
| 05_PURCHASE_PART | clean_data.purchase_part | taxable_db | STANDARD | CONSTANTE | TRUE | Oui | articlePhl | Source : alimenter_purchase_part_phl.sql (+ modules inventory) |  |
| 05_PURCHASE_PART | clean_data.purchase_part | technical_coordinator_id | STANDARD | CONSTANTE | (NULL) | Non | articlePhl | Source : alimenter_purchase_part_phl.sql (+ modules inventory) |  |
| 06_PURCHASE_PART_SUPPLIER  —  clean_data.purchase_part_supplier |  |  |  |  |  |  |  |  |  |
| 06_PURCHASE_PART_SUPPLIER | clean_data.purchase_part_supplier | acquisition_type_db | STANDARD | CONSTANTE | PURCHASE | Oui | inventory | Source : alimenter_purchase_part_supplier.sql |  |
| 06_PURCHASE_PART_SUPPLIER | clean_data.purchase_part_supplier | dist_order_receipt_type_db | STANDARD | CONSTANTE | NO AUTOMATIC RECPT | Oui | inventory | Source : alimenter_purchase_part_supplier.sql |  |
| 06_PURCHASE_PART_SUPPLIER | clean_data.purchase_part_supplier | external_service_allowed_db | STANDARD | CONSTANTE | FALSE | Oui | inventory | Source : alimenter_purchase_part_supplier.sql |  |
| 06_PURCHASE_PART_SUPPLIER | clean_data.purchase_part_supplier | ext_svc_primary_vendor_db | STANDARD | CONSTANTE | FALSE | Oui | inventory | Source : alimenter_purchase_part_supplier.sql |  |
| 06_PURCHASE_PART_SUPPLIER | clean_data.purchase_part_supplier | issue_packaging_material_db | STANDARD | CONSTANTE | FALSE | Oui | inventory | Source : alimenter_purchase_part_supplier.sql |  |
| 06_PURCHASE_PART_SUPPLIER | clean_data.purchase_part_supplier | leadtime_auto_db | STANDARD | CONSTANTE | N | Oui | inventory | Source : alimenter_purchase_part_supplier.sql |  |
| 06_PURCHASE_PART_SUPPLIER | clean_data.purchase_part_supplier | multisite_planned_part_db | STANDARD | CONSTANTE | NOT_MULTISITE_PLAN | Oui | inventory | Source : alimenter_purchase_part_supplier.sql |  |
| 06_PURCHASE_PART_SUPPLIER | clean_data.purchase_part_supplier | part_ownership_db | STANDARD | CONSTANTE | COMPANY OWNED | Oui | inventory | Source : alimenter_purchase_part_supplier.sql |  |
| 06_PURCHASE_PART_SUPPLIER | clean_data.purchase_part_supplier | primary_vendor_db | STANDARD | CONSTANTE | Y | Oui | inventory | Source : alimenter_purchase_part_supplier.sql |  |
| 06_PURCHASE_PART_SUPPLIER | clean_data.purchase_part_supplier | purchase_payment_type_db | STANDARD | CONSTANTE | NORMAL | Oui | inventory | Source : alimenter_purchase_part_supplier.sql |  |
| 06_PURCHASE_PART_SUPPLIER | clean_data.purchase_part_supplier | qualified_supplier_db | STANDARD | CONSTANTE | FALSE | Oui | inventory | Source : alimenter_purchase_part_supplier.sql |  |
| 06_PURCHASE_PART_SUPPLIER | clean_data.purchase_part_supplier | quick_registered_part_db | STANDARD | CONSTANTE | FALSE | Oui | inventory | Source : alimenter_purchase_part_supplier.sql |  |
| 06_PURCHASE_PART_SUPPLIER | clean_data.purchase_part_supplier | receive_case_db | STANDARD | CONSTANTE | INVDIR | Oui | inventory | Source : alimenter_purchase_part_supplier.sql |  |
| 06_PURCHASE_PART_SUPPLIER | clean_data.purchase_part_supplier | rental_primary_vendor_db | STANDARD | CONSTANTE | N | Oui | inventory | Source : alimenter_purchase_part_supplier.sql |  |
| 06_PURCHASE_PART_SUPPLIER | clean_data.purchase_part_supplier | status_code | STANDARD | CONSTANTE | 2 | Oui | inventory | Source : alimenter_purchase_part_supplier.sql |  |
| 06_PURCHASE_PART_SUPPLIER | clean_data.purchase_part_supplier | use_price_incl_tax_db | STANDARD | CONSTANTE | FALSE | Oui | inventory | Source : alimenter_purchase_part_supplier.sql |  |
| 07_SALES_PART  —  clean_data.sales_part |  |  |  |  |  |  |  |  |  |
| 07_SALES_PART | clean_data.sales_part | activeind_db | STANDARD | CONSTANTE | Y | Oui | articlePhl | Source : alimenter_sales_part_phl.sql (+ modules inventory) |  |
| 07_SALES_PART | clean_data.sales_part | allow_incomp_pkg_delivery | STANDARD | CONSTANTE | TRUE | Oui | articlePhl | Source : alimenter_sales_part_phl.sql (+ modules inventory) |  |
| 07_SALES_PART | clean_data.sales_part | allow_inc_pkg_rsrv_picklst | STANDARD | CONSTANTE | TRUE | Oui | articlePhl | Source : alimenter_sales_part_phl.sql (+ modules inventory) |  |
| 07_SALES_PART | clean_data.sales_part | catalog_group | STANDARD | CONSTANTE | 903028 | Oui | articlePhl | Source : alimenter_sales_part_phl.sql (+ modules inventory) |  |
| 07_SALES_PART | clean_data.sales_part | close_tolerance | STANDARD | CONSTANTE | 0 | Oui | articlePhl | Source : alimenter_sales_part_phl.sql (+ modules inventory) |  |
| 07_SALES_PART | clean_data.sales_part | conv_factor | STANDARD | CONSTANTE | 1 | Oui | articlePhl | Source : alimenter_sales_part_phl.sql (+ modules inventory) |  |
| 07_SALES_PART | clean_data.sales_part | cost | STANDARD | CONSTANTE | (NULL) | Non | articlePhl | Source : alimenter_sales_part_phl.sql (+ modules inventory) |  |
| 07_SALES_PART | clean_data.sales_part | country_of_origin | STANDARD | CONSTANTE | FR | Oui | articlePhl | Source : alimenter_sales_part_phl.sql (+ modules inventory) |  |
| 07_SALES_PART | clean_data.sales_part | create_sm_object_option_db | STANDARD | CONSTANTE | DONOTCREATESMOBJECT | Oui | articlePhl | Source : alimenter_sales_part_phl.sql (+ modules inventory) |  |
| 07_SALES_PART | clean_data.sales_part | delivery_type | STANDARD | CONSTANTE | (NULL) | Non | articlePhl | Source : alimenter_sales_part_phl.sql (+ modules inventory) |  |
| 07_SALES_PART | clean_data.sales_part | expected_average_price | STANDARD | CONSTANTE | (NULL) | Non | articlePhl | Source : alimenter_sales_part_phl.sql (+ modules inventory) |  |
| 07_SALES_PART | clean_data.sales_part | export_to_external_app_db | STANDARD | CONSTANTE | FALSE | Oui | articlePhl | Source : alimenter_sales_part_phl.sql (+ modules inventory) |  |
| 07_SALES_PART | clean_data.sales_part | inverted_conv_factor | STANDARD | CONSTANTE | 1 | Oui | articlePhl | Source : alimenter_sales_part_phl.sql (+ modules inventory) |  |
| 07_SALES_PART | clean_data.sales_part | list_price | STANDARD | CONSTANTE | 0 | Oui | articlePhl | Source : alimenter_sales_part_phl.sql (+ modules inventory) |  |
| 07_SALES_PART | clean_data.sales_part | list_price_incl_tax | STANDARD | CONSTANTE | 0 | Oui | articlePhl | Source : alimenter_sales_part_phl.sql (+ modules inventory) |  |
| 07_SALES_PART | clean_data.sales_part | minimum_qty | STANDARD | CONSTANTE | (NULL) | Non | articlePhl | Source : alimenter_sales_part_phl.sql (+ modules inventory) |  |
| 07_SALES_PART | clean_data.sales_part | pack_comp_in_shpmnt | STANDARD | CONSTANTE | FALSE | Oui | articlePhl | Source : alimenter_sales_part_phl.sql (+ modules inventory) |  |
| 07_SALES_PART | clean_data.sales_part | price_change_date | STANDARD | CONSTANTE | (NULL) | Non | articlePhl | Source : alimenter_sales_part_phl.sql (+ modules inventory) |  |
| 07_SALES_PART | clean_data.sales_part | price_conv_factor | STANDARD | CONSTANTE | 1 | Oui | articlePhl | Source : alimenter_sales_part_phl.sql (+ modules inventory) |  |
| 07_SALES_PART | clean_data.sales_part | primary_catalog_db | STANDARD | CONSTANTE | TRUE | Oui | articlePhl | Source : alimenter_sales_part_phl.sql (+ modules inventory) |  |
| 07_SALES_PART | clean_data.sales_part | quick_registered_part_db | STANDARD | CONSTANTE | FALSE | Oui | articlePhl | Source : alimenter_sales_part_phl.sql (+ modules inventory) |  |
| 07_SALES_PART | clean_data.sales_part | rental_list_price | STANDARD | CONSTANTE | 0 | Oui | articlePhl | Source : alimenter_sales_part_phl.sql (+ modules inventory) |  |
| 07_SALES_PART | clean_data.sales_part | rental_list_price_incl_tax | STANDARD | CONSTANTE | 0 | Oui | articlePhl | Source : alimenter_sales_part_phl.sql (+ modules inventory) |  |
| 07_SALES_PART | clean_data.sales_part | sales_price_group_id | STANDARD | CONSTANTE | * | Oui | articlePhl | Source : alimenter_sales_part_phl.sql (+ modules inventory) |  |
| 07_SALES_PART | clean_data.sales_part | sales_type_db | STANDARD | CONSTANTE | SALES | Oui | articlePhl | Source : alimenter_sales_part_phl.sql (+ modules inventory) |  |
| 07_SALES_PART | clean_data.sales_part | sourcing_option_db | STANDARD | CONSTANTE | NOTSUPPLIED | Oui | articlePhl | Source : alimenter_sales_part_phl.sql (+ modules inventory) |  |
| 07_SALES_PART | clean_data.sales_part | statistical_code | STANDARD | CONSTANTE | (NULL) | Non | articlePhl | Source : alimenter_sales_part_phl.sql (+ modules inventory) |  |
| 07_SALES_PART | clean_data.sales_part | taxable_db | STANDARD | CONSTANTE | TRUE | Oui | articlePhl | Source : alimenter_sales_part_phl.sql (+ modules inventory) |  |
| 07_SALES_PART | clean_data.sales_part | tax_class_id | STANDARD | CONSTANTE | (NULL) | Non | articlePhl | Source : alimenter_sales_part_phl.sql (+ modules inventory) |  |
| 07_SALES_PART | clean_data.sales_part | tax_code | STANDARD | CONSTANTE | C05 | Oui | articlePhl | Source : alimenter_sales_part_phl.sql (+ modules inventory) |  |
| 07_SALES_PART | clean_data.sales_part | use_price_incl_tax_db | STANDARD | CONSTANTE | FALSE | Oui | articlePhl | Source : alimenter_sales_part_phl.sql (+ modules inventory) |  |
## Sheet: 01_IFS_ARTICLE_MAITRE
| Colonne cible | Type / Longueur | Champ / Table source | Systeme source | Regle de transformation / Condition | Exemple de valeur | Valide metier (O/N) | Remarques metier | Date validation |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Script alimenter_ifs_article.sql  —  TABLE PILOTE. Perimetre = raw_data.export_article_qlikview (liste des articles a migrer), restreint aux articles ayant une fiche MARA active (mandt 700, non marques a supprimer). Agrege les donnees SAP par article : centres (MARC), commercial (MVKE), evaluation (MBEW), stocks (MARD), fournisseur principal (EINA/LFA1). |  |  |  |  |  |  |  |  |
| numero_article | VARCHAR(30) | raw_data.export_article_qlikview.article | QlikView | m.matnr AS numero_article | 000000000000220004 |  |  |  |
| designation | VARCHAR | raw_data.makt.maktx ; raw_data.export_article_qlikview.designation_article ; raw_data.export_article_qlikview.article | QlikView / SAP | m.maktx AS designation | ROUE TANGENTE = 1 REP.7 + 1 REP.8 |  |  |  |
| designation_courte | VARCHAR(200) | raw_data.makt.maktg | SAP | m.maktg AS designation_courte | ROUE TANGENTE = 1 REP.7 + 1 REP.8 |  |  |  |
| ancien_numero | VARCHAR(20) | raw_data.mara.bismt | SAP | m.bismt AS ancien_numero | GAL25 |  |  |  |
| type_article | VARCHAR(20) | raw_data.mara.mtart | SAP | m.mtart AS type_article | ERSA |  |  |  |
| libelle_type_article | TEXT | raw_data.t134.mtref ; raw_data.mara.mtart | SAP | COALESCE(t134.mtref, m.mtart::text) AS libelle_type_article | HIBE |  |  |  |
| groupe_article | VARCHAR(20) | raw_data.mara.matkl | SAP | m.matkl AS groupe_article | 76004 |  |  |  |
| libelle_groupe_article | VARCHAR(20) | raw_data.t023t.wgbez ; raw_data.mara.matkl | SAP | COALESCE(t023.wgbez, m.matkl) AS libelle_groupe_article | maintenance méca. |  |  |  |
| secteur_activite | VARCHAR(20) | raw_data.mara.mbrsh | SAP | m.mbrsh AS secteur_activite | C |  |  |  |
| unite_base | VARCHAR(20) | raw_data.mara.meins | SAP | m.meins AS unite_base | ST |  |  |  |
| unite_commande | VARCHAR(20) | raw_data.mara.bstme | SAP | m.bstme AS unite_commande | TO |  |  |  |
| nombre_centres_actifs | BIGINT | raw_data.marc (agregat) | SAP | COALESCE(centres_agg.nombre_centres, 0::bigint) AS nombre_centres_actifs | 2 |  |  |  |
| centres_list | TEXT | raw_data.marc.werks | SAP | centres_agg.centres_list | 2200, 9200 |  |  |  |
| groupes_achat_list | TEXT | raw_data.marc.ekgrp | SAP | centres_agg.groupes_achat_list | 22S, 92N |  |  |  |
| strategies_list | TEXT | raw_data.marc.dismm | SAP | centres_agg.strategies_list | VB, ZB |  |  |  |
| stock_minimum_total | NUMERIC | raw_data.marc.bstmi | SAP | centres_agg.stock_minimum_total | 2.0 |  |  |  |
| stock_securite_total | NUMERIC | raw_data.marc.bstrf | SAP | centres_agg.stock_securite_total | 2.0 |  |  |  |
| stock_maximum_total | NUMERIC | raw_data.marc.bstma | SAP | centres_agg.stock_maximum_total | 0.0 |  |  |  |
| avec_gestion_lot | TEXT | raw_data.marc.xchar | SAP | centres_agg.avec_gestion_lot | NON |  |  |  |
| profils_serie_list | TEXT | raw_data.marc.sernp | SAP | centres_agg.profils_serie_list |  |  |  |  |
| organisations_commerciales_list | TEXT | raw_data.mvke.vkorg | SAP | commerciales_agg.organisations_commerciales_list |  |  |  |  |
| canaux_distribution_list | TEXT | raw_data.mvke.vtweg | SAP | commerciales_agg.canaux_distribution_list |  |  |  |  |
| statuts_commerciaux_list | TEXT | raw_data.mvke.vmsta | SAP | commerciales_agg.statuts_commerciaux_list |  |  |  |  |
| cercles_evaluation_list | TEXT | raw_data.mbew.bwkey | SAP | evaluation_agg.cercles_evaluation_list | 2200, 9200 |  |  |  |
| prix_moyen_pondere_moyen | NUMERIC | raw_data.mbew.verpr | SAP | evaluation_agg.prix_moyen_pondere_moyen | 1126.69 |  |  |  |
| prix_standard_moyen | NUMERIC | raw_data.mbew.stprs | SAP | evaluation_agg.prix_standard_moyen | 0.00 |  |  |  |
| stock_quantite_total | NUMERIC | raw_data.mbew.lbkum | SAP | evaluation_agg.stock_quantite_total | 2.000 |  |  |  |
| valeur_stock_total | NUMERIC | raw_data.mbew.salk3 | SAP | evaluation_agg.valeur_stock_total | 2320.75 |  |  |  |
| classes_evaluation_list | TEXT | raw_data.mbew.bklas | SAP | evaluation_agg.classes_evaluation_list | 3040 |  |  |  |
| nombre_magasins | BIGINT | raw_data.mard.lgort | SAP | COALESCE(stocks_agg.nombre_magasins, 0::bigint) AS nombre_magasins | 1 |  |  |  |
| stock_total_libre | NUMERIC | raw_data.mard.labst | SAP | COALESCE(stocks_agg.stock_total_libre, 0::numeric) AS stock_total_libre | 2.000 |  |  |  |
| stock_total_bloque | NUMERIC | raw_data.mard.speme | SAP | COALESCE(stocks_agg.stock_total_bloque, 0::numeric) AS stock_total_bloque | 0.000 |  |  |  |
| stock_total_controle | NUMERIC | raw_data.mard.insme | SAP | COALESCE(stocks_agg.stock_total_controle, 0::numeric) AS stock_total_controle | 0.000 |  |  |  |
| valeur_stock_magasins_total | NUMERIC | raw_data.mard.vmlab | SAP | COALESCE(stocks_agg.valeur_stock_magasins_total, 0::numeric) AS valeur_stock_magasins_total | 1.000 |  |  |  |
| fournisseur_principal | VARCHAR(20) | raw_data.eina.lifnr | SAP | ei_principal.lifnr AS fournisseur_principal | 0002023281 |  |  |  |
| unite_commande_achat | VARCHAR(20) | raw_data.eina.meins | SAP | ei_principal.meins AS unite_commande_achat | ST |  |  |  |
| nom_fournisseur_principal | VARCHAR(35) | raw_data.lfa1.name1 | SAP | lfa.name1 AS nom_fournisseur_principal | PROMEA |  |  |  |
| pays_fournisseur_principal | VARCHAR(20) | raw_data.lfa1.land1 | SAP | lfa.land1 AS pays_fournisseur_principal | FR |  |  |  |
| ville_fournisseur_principal | VARCHAR(35) | raw_data.lfa1.ort01 | SAP | lfa.ort01 AS ville_fournisseur_principal | ASPACH-MICHELBACH |  |  |  |
| actif_dans_centre | TEXT | raw_data.marc (agregat) | SAP | CASE WHEN centres_agg.nombre_centres > 0 THEN 'OUI'::text ELSE 'NON'::text END AS actif_dans_centre | OUI |  |  |  |
| actif_commercial | TEXT | raw_data.mvke.vkorg | SAP | CASE WHEN commerciales_agg.organisations_commerciales_list IS NOT NULL THEN 'OUI'::text ELSE 'NON'::text END AS actif_commercial | NON |  |  |  |
| actif_evaluation | TEXT | raw_data.mbew.salk3 | SAP | CASE WHEN evaluation_agg.valeur_stock_total > 0::numeric THEN 'OUI'::text ELSE 'NON'::text END AS actif_evaluation | OUI |  |  |  |
| actif_achat | TEXT | raw_data.eina.lifnr | SAP | CASE WHEN ei_principal.lifnr IS NOT NULL THEN 'OUI'::text ELSE 'NON'::text END AS actif_achat | OUI |  |  |  |
| avec_stock | TEXT | raw_data.mard.labst | SAP | CASE WHEN stocks_agg.stock_total_libre > 0::numeric THEN 'OUI'::text ELSE 'NON'::text END AS avec_stock | OUI |  |  |  |
| statut_utilisation | TEXT | raw_data.marc (agregat) ; raw_data.mvke.vkorg ; raw_data.mard.labst ; raw_data.eina.lifnr | SAP | CASE WHEN centres_agg.nombre_centres > 0 OR commerciales_agg.organisations_commerciales_list IS NOT NULL OR stocks_agg.stock_total_libre > 0::numeric OR ei_principal.lifnr IS NOT NULL THEN 'UTILISE'::text ELSE 'NON_UTILISE'::text END AS statut_utilisation | UTILISE |  |  |  |
| date_creation | VARCHAR(20) | raw_data.mara.ersda | SAP | m.ersda AS date_creation | 19981026 |  |  |  |
| createur | VARCHAR(20) | raw_data.mara.ernam | SAP | m.ernam AS createur | BURDET |  |  |  |
| date_modification | VARCHAR(20) | raw_data.mara.laeda | SAP | m.laeda AS date_modification | 20230725 |  |  |  |
| modificateur | VARCHAR(20) | raw_data.mara.aenam | SAP | m.aenam AS modificateur | DESOUSA |  |  |  |
| langue | VARCHAR(20) | raw_data.makt.spras | SAP | CODIFICATION IFS : plus alimentee. clean_data.mapping_codification_articles n'est plus utilisee : la colonne codification_id reste NULL (aucune procedure aval ne la lit). | F |  |  |  |
## Sheet: 02_PART_CATALOG
| Colonne cible | Type / Longueur | Champ / Table source | Systeme source | Regle de transformation / Condition | Exemple de valeur | Valide metier (O/N) | Remarques metier | Date validation |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Script alimenter_part_catalog.sql  —  Catalogue des pieces IFS : table de BASE du module. Reprise 1:1 de ifs_article_maitre. Toutes les tables suivantes filtrent leur contenu sur la presence de l'article ici. |  |  |  |  |  |  |  |  |
| part_no | VARCHAR(25) | clean_data.ifs_article_maitre.numero_article | IFS | Colonnes obligatoires (NOT NULL) part_no: numero_article SAP (pas de transcodification, l'article garde son ID)
SQL : SUBSTRING(TRIM(LTRIM(va.numero_article, '0')), 1, 25) as part_no | 220004 |  |  |  |
| description | VARCHAR(200) | clean_data.ifs_article_maitre.designation | IFS | SUBSTRING(TRIM(COALESCE(va.designation, '')), 1, 200) as description | ROUE TANGENTE = 1 REP.7 + 1 REP.8 |  |  |  |
| unit_code | VARCHAR(30) | clean_data.ifs_article_maitre.unite_base ; public."TranscodificationTable" (categorie UOM) | IFS / Config | unit_code: unité de base via transcodification UOM (SAP->IFS), sinon unité d'entrée
SQL : SUBSTRING(COALESCE( public.get_transcodification('UOM', NULLIF(UPPER(TRIM(va.unite_base)), '')), UPPER(TRIM(va.unite_base)) ), 1, 30) as unit_code | PCS |  |  |  |
| lot_tracking_code_db | VARCHAR(30) | clean_data.ifs_article_maitre.avec_gestion_lot | IFS | Colonnes obligatoires _db (valeurs courtes selon documentation)
SQL : CASE WHEN va.avec_gestion_lot = 'OUI' THEN 'LOT TRACKING' ELSE 'NOT LOT TRACKING' END as lot_tracking_code_db | NOT LOT TRACKING |  |  |  |
| serial_rule_db | VARCHAR(20) | public.etl_default_values (part_catalog.serial_rule_db) | Config | public.get_default_value('clean_data.part_catalog', 'serial_rule_db') as serial_rule_db | MANUAL |  |  |  |
| serial_tracking_code_db | VARCHAR(30) | public.etl_default_values (part_catalog.serial_tracking_code_db) | Config | public.get_default_value('clean_data.part_catalog', 'serial_tracking_code_db') as serial_tracking_code_db | NOT SERIAL TRACKING |  |  |  |
| eng_serial_tracking_code_db | VARCHAR(20) | public.etl_default_values (part_catalog.eng_serial_tracking_code_db) | Config | public.get_default_value('clean_data.part_catalog', 'eng_serial_tracking_code_db') as eng_serial_tracking_code_db | NOT SERIAL TRACKING |  |  |  |
| configurable_db | VARCHAR(20) | public.etl_default_values (part_catalog.configurable_db) | Config | public.get_default_value('clean_data.part_catalog', 'configurable_db') as configurable_db | NOT CONFIGURED |  |  |  |
| condition_code_usage_db | VARCHAR(20) | public.etl_default_values (part_catalog.condition_code_usage_db) | Config | public.get_default_value('clean_data.part_catalog', 'condition_code_usage_db') as condition_code_usage_db | NOT_ALLOW_COND_CODE |  |  |  |
| sub_lot_rule_db | VARCHAR(20) | public.etl_default_values (part_catalog.sub_lot_rule_db) | Config | public.get_default_value('clean_data.part_catalog', 'sub_lot_rule_db') as sub_lot_rule_db | NO_SUBLOTS |  |  |  |
| lot_quantity_rule_db | VARCHAR(20) | clean_data.ifs_article_maitre.avec_gestion_lot | IFS | Allow Many Lots per Production Order : actif des que l'article est suivi en lot
SQL : CASE WHEN va.avec_gestion_lot = 'OUI' THEN 'MULTI_LOTS' ELSE 'ONE_LOT' END as lot_quantity_rule_db | ONE_LOT |  |  |  |
| position_part_db | VARCHAR(20) | public.etl_default_values (part_catalog.position_part_db) | Config | public.get_default_value('clean_data.part_catalog', 'position_part_db') as position_part_db | NOT POSITION PART |  |  |  |
| catch_unit_enabled_db | VARCHAR(5) | public.etl_default_values (part_catalog.catch_unit_enabled_db) | Config | public.get_default_value('clean_data.part_catalog', 'catch_unit_enabled_db') as catch_unit_enabled_db | FALSE |  |  |  |
| multilevel_tracking_db | VARCHAR(20) | public.etl_default_values (part_catalog.multilevel_tracking_db) | Config | public.get_default_value('clean_data.part_catalog', 'multilevel_tracking_db') as multilevel_tracking_db | TRACKING_OFF |  |  |  |
| component_lot_rule_db | VARCHAR(20) | public.etl_default_values (part_catalog.component_lot_rule_db) | Config | public.get_default_value('clean_data.part_catalog', 'component_lot_rule_db', 'INVENTORY') as component_lot_rule_db | ONE_LOT_ALLOWED |  |  |  |
| stop_arrival_issued_serial_db | VARCHAR(5) | public.etl_default_values (part_catalog.stop_arrival_issued_serial_db) | Config | public.get_default_value('clean_data.part_catalog', 'stop_arrival_issued_serial_db') as stop_arrival_issued_serial_db | TRUE |  |  |  |
| allow_as_not_consumed_db | VARCHAR(5) | public.etl_default_values (part_catalog.allow_as_not_consumed_db) | Config | public.get_default_value('clean_data.part_catalog', 'allow_as_not_consumed_db') as allow_as_not_consumed_db | FALSE |  |  |  |
| receipt_issue_serial_track_db | VARCHAR(20) | public.etl_default_values (part_catalog.receipt_issue_serial_track_db) | Config | public.get_default_value('clean_data.part_catalog', 'receipt_issue_serial_track_db') as receipt_issue_serial_track_db | FALSE |  |  |  |
| stop_new_serial_in_rma_db | VARCHAR(20) | public.etl_default_values (part_catalog.stop_new_serial_in_rma_db) | Config | public.get_default_value('clean_data.part_catalog', 'stop_new_serial_in_rma_db') as stop_new_serial_in_rma_db | TRUE |  |  |  |
## Sheet: 03_INVENTORY_PART
| Colonne cible | Type / Longueur | Champ / Table source | Systeme source | Regle de transformation / Condition | Exemple de valeur | Valide metier (O/N) | Remarques metier | Date validation |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Script alimenter_inventory_part.sql  —  Article d'inventaire par site (contract). Un enregistrement par couple article x centre SAP 9200 (SJ) / 9000 (CS). |  |  |  |  |  |  |  |  |
| contract | VARCHAR(5) | raw_data.marc.werks | SAP | 9200 = SJ (Saint Jean), 9000 = CS (Castel)
SQL : CASE WHEN marc.werks = '9200' THEN 'SJ' WHEN marc.werks = '9000' THEN 'CS' ELSE 'SJ' END as contract | SJ |  |  |  |
| part_no | VARCHAR(25) | clean_data.ifs_article_maitre.numero_article | IFS | numero_article SAP (pas de transcodification, l'article garde son ID)
SQL : SUBSTRING(TRIM(LTRIM(ifs.numero_article, '0')), 1, 25) as part_no | 220004 |  |  |  |
| description | VARCHAR(200) | raw_data.makt.maktx ; raw_data.mara.matnr | SAP | SUBSTRING(COALESCE(makt.maktx, mara.matnr), 1, 200) as description | ROUE TANGENTE = 1 REP.7 + 1 REP.8 |  |  |  |
| unit_meas | VARCHAR(10) | raw_data.mara.meins ; public."TranscodificationTable" (categorie UOM) | SAP / Config | MARA.MEINS via transcodification UOM (SAP->IFS), sinon unité d'entrée
SQL : SUBSTRING(COALESCE( public.get_transcodification('UOM', NULLIF(UPPER(TRIM(mara.meins)), '')), UPPER(TRIM(mara.meins)) ), 1, 10) as unit_meas | PCS |  |  |  |
| part_status | VARCHAR(1) | public.etl_default_values (inventory_part.part_status) | Config | public.get_default_value('clean_data.inventory_part', 'part_status') as part_status | A |  |  |  |
| planner_buyer | VARCHAR(20) | public.etl_default_values (inventory_part.planner_buyer) | Config | public.get_default_value('clean_data.inventory_part', 'planner_buyer') as planner_buyer | * |  |  |  |
| asset_class | VARCHAR(2) | public.etl_default_values (inventory_part.asset_class) | Config | public.get_default_value('clean_data.inventory_part', 'asset_class') as asset_class | S |  |  |  |
| country_of_origin | VARCHAR(3) | raw_data.marc.herkl | SAP | SUBSTRING(marc.herkl, 1, 10) as country_of_origin |  |  |  |  |
| type_code_db | VARCHAR(2) | public.etl_default_values (inventory_part.type_code_db) | Config | public.get_default_value('clean_data.inventory_part', 'type_code_db') as type_code_db | 4 |  |  |  |
| supply_code_db | VARCHAR(3) | public.etl_default_values (inventory_part.supply_code_db) | Config | public.get_default_value('clean_data.inventory_part', 'supply_code_db') as supply_code_db | IO |  |  |  |
| expected_leadtime | NUMERIC(20,0) | raw_data.marc.webaz | SAP | COALESCE(marc.webaz::numeric, 0) as expected_leadtime | 0 |  |  |  |
| manuf_leadtime | NUMERIC(20,0) | public.etl_default_values (inventory_part.manuf_leadtime) | Config | public.get_default_value('clean_data.inventory_part', 'manuf_leadtime')::numeric as manuf_leadtime | 0 |  |  |  |
| purch_leadtime | NUMERIC(20,0) | public.etl_default_values (inventory_part.purch_leadtime) | Config | public.get_default_value('clean_data.inventory_part', 'purch_leadtime')::numeric as purch_leadtime | 0 |  |  |  |
| lead_time_code_db | VARCHAR(1) | public.etl_default_values (inventory_part.lead_time_code_db) | Config | public.get_default_value('clean_data.inventory_part', 'lead_time_code_db') as lead_time_code_db | P |  |  |  |
| inventory_valuation_method_db | VARCHAR(50) | raw_data.mbew.vprsv | SAP | S => ST, V => AV (selon code prix SAP)
SQL : CASE WHEN mbew.vprsv = 'S' THEN 'ST' WHEN mbew.vprsv = 'V' THEN 'AV' ELSE 'ST' END as inventory_valuation_method_db | AV |  |  |  |
| count_variance | NUMERIC(20,0) | public.etl_default_values (inventory_part.count_variance) | Config | public.get_default_value('clean_data.inventory_part', 'count_variance')::numeric as count_variance | 0 |  |  |  |
| cycle_code_db | VARCHAR(1) | public.etl_default_values (inventory_part.cycle_code_db) | Config | public.get_default_value('clean_data.inventory_part', 'cycle_code_db') as cycle_code_db | N |  |  |  |
| cycle_period | NUMERIC(3,0) | public.etl_default_values (inventory_part.cycle_period) | Config | public.get_default_value('clean_data.inventory_part', 'cycle_period')::numeric as cycle_period | 0 |  |  |  |
| qty_calc_rounding | NUMERIC(20,0) | public.etl_default_values (inventory_part.qty_calc_rounding) | Config | public.get_default_value('clean_data.inventory_part', 'qty_calc_rounding')::numeric as qty_calc_rounding | 0 |  |  |  |
| zero_cost_flag_db | VARCHAR(1) | public.etl_default_values (inventory_part.zero_cost_flag_db) | Config | public.get_default_value('clean_data.inventory_part', 'zero_cost_flag_db') as zero_cost_flag_db | N |  |  |  |
| oe_alloc_assign_flag_db | VARCHAR(1) | public.etl_default_values (inventory_part.oe_alloc_assign_flag_db) | Config | public.get_default_value('clean_data.inventory_part', 'oe_alloc_assign_flag_db') as oe_alloc_assign_flag_db | N |  |  |  |
| onhand_analysis_flag_db | VARCHAR(1) | public.etl_default_values (inventory_part.onhand_analysis_flag_db) | Config | public.get_default_value('clean_data.inventory_part', 'onhand_analysis_flag_db') as onhand_analysis_flag_db | N |  |  |  |
| shortage_flag_db | VARCHAR(1) | public.etl_default_values (inventory_part.shortage_flag_db) | Config | public.get_default_value('clean_data.inventory_part', 'shortage_flag_db') as shortage_flag_db | Y |  |  |  |
| forecast_consumption_flag_db | VARCHAR(30) | public.etl_default_values (inventory_part.forecast_consumption_flag_db) | Config | public.get_default_value('clean_data.inventory_part', 'forecast_consumption_flag_db') as forecast_consumption_flag_db | FORECAST |  |  |  |
| stock_management_db | VARCHAR(50) | public.etl_default_values (inventory_part.stock_management_db) | Config | public.get_default_value('clean_data.inventory_part', 'stock_management_db') as stock_management_db | Y |  |  |  |
| dop_connection_db | VARCHAR(200) | public.etl_default_values (inventory_part.dop_connection_db) | Config | public.get_default_value('clean_data.inventory_part', 'dop_connection_db') as dop_connection_db | AUT |  |  |  |
| negative_on_hand_db | VARCHAR(50) | public.etl_default_values (inventory_part.negative_on_hand_db) | Config | NEG ONHAND NOT OK
SQL : public.get_default_value('clean_data.inventory_part', 'negative_on_hand_db') as negative_on_hand_db | NEG ONHAND NOT OK |  |  |  |
| invoice_consideration_db | VARCHAR(50) | public.etl_default_values (inventory_part.invoice_consideration_db) | Config | TRANSACTION BASED
SQL : public.get_default_value('clean_data.inventory_part', 'invoice_consideration_db') as invoice_consideration_db | TRANSACTION BASED |  |  |  |
| inventory_part_cost_level_db | VARCHAR(50) | public.etl_default_values (inventory_part.inventory_part_cost_level_db) | Config | COST PER PART
SQL : public.get_default_value('clean_data.inventory_part', 'inventory_part_cost_level_db') as inventory_part_cost_level_db | COST PER PART |  |  |  |
| ext_service_cost_method_db | VARCHAR(20) | public.etl_default_values (inventory_part.ext_service_cost_method_db) | Config | EXCLUDE SERVICE COST
SQL : public.get_default_value('clean_data.inventory_part', 'ext_service_cost_method_db') as ext_service_cost_method_db | EXCLUDE SERVICE COST |  |  |  |
| automatic_capability_check_db | VARCHAR(50) | public.etl_default_values (inventory_part.automatic_capability_check_db) | Config | NO AUTOMATIC CAPABILITY CHECK
SQL : public.get_default_value('clean_data.inventory_part', 'automatic_capability_check_db') as automatic_capability_check_db | NO AUTOMATIC CAPABILITY CHECK |  |  |  |
| dop_netting_db | VARCHAR(20) | public.etl_default_values (inventory_part.dop_netting_db) | Config | public.get_default_value('clean_data.inventory_part', 'dop_netting_db') as dop_netting_db | NONET |  |  |  |
| co_reserve_onh_analys_flag_db | VARCHAR(20) | public.etl_default_values (inventory_part.co_reserve_onh_analys_flag_db) | Config | public.get_default_value('clean_data.inventory_part', 'co_reserve_onh_analys_flag_db') as co_reserve_onh_analys_flag_db | N |  |  |  |
| mandatory_expiration_date_db | VARCHAR(5) | public.etl_default_values (inventory_part.mandatory_expiration_date_db) | Config | public.get_default_value('clean_data.inventory_part', 'mandatory_expiration_date_db') as mandatory_expiration_date_db | FALSE |  |  |  |
| excl_ship_pack_proposal_db | VARCHAR(5) | public.etl_default_values (inventory_part.excl_ship_pack_proposal_db) | Config | public.get_default_value('clean_data.inventory_part', 'excl_ship_pack_proposal_db') as excl_ship_pack_proposal_db | FALSE |  |  |  |
| reset_config_std_cost_db | VARCHAR(5) | public.etl_default_values (inventory_part.reset_config_std_cost_db) | Config | public.get_default_value('clean_data.inventory_part', 'reset_config_std_cost_db') as reset_config_std_cost_db | FALSE |  |  |  |
| lifecycle_stage_db | VARCHAR(20) | public.etl_default_values (inventory_part.lifecycle_stage_db) | Config | public.get_default_value('clean_data.inventory_part', 'lifecycle_stage_db') as lifecycle_stage_db | DEVELOPMENT |  |  |  |
| frequency_class_db | VARCHAR(20) | public.etl_default_values (inventory_part.frequency_class_db) | Config | VERY SLOW MOVER
SQL : public.get_default_value('clean_data.inventory_part', 'frequency_class_db') as frequency_class_db | VERY SLOW MOVER |  |  |  |
| avail_activity_status_db | VARCHAR(9) | public.etl_default_values (inventory_part.avail_activity_status_db) | Config | public.get_default_value('clean_data.inventory_part', 'avail_activity_status_db') as avail_activity_status_db | CHANGED |  |  |  |
| abc_class | VARCHAR(1) | raw_data.marc.maabc | SAP | SUBSTRING(marc.maabc, 1, 1) as abc_class | B |  |  |  |
| hsn_sac_code | VARCHAR(20) | raw_data.marc.mownr | SAP | SUBSTRING(marc.mownr, 1, 20) as hsn_sac_code |  |  |  |  |
## Sheet: 04_INVENT_PART_PLAN
| Colonne cible | Type / Longueur | Champ / Table source | Systeme source | Regle de transformation / Condition | Exemple de valeur | Valide metier (O/N) | Remarques metier | Date validation |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Script alimenter_inventory_part_planning.sql  —  Parametres de planification (lot, stock de securite, point de commande) par article x site. Filtre sur la presence dans inventory_part. |  |  |  |  |  |  |  |  |
| contract | VARCHAR(5) | raw_data.marc.werks | SAP | CASE WHEN marc.werks = '9000' THEN 'CS' WHEN marc.werks = '9200' THEN 'SJ' ELSE 'SJ' END as contract | CS |  |  |  |
| part_no | VARCHAR(25) | raw_data.mara.matnr | SAP | TRIM indispensable : inventory_part construit son part_no avec TRIM(LTRIM(...)). Sans lui, tout matnr avec un espace de fin donnait une cle differente => ligne de planification orpheline.
SQL : SUBSTRING(TRIM(LTRIM(mara.matnr, '0')), 1, 25) as part_no | 220335 |  |  |  |
| last_activity_date | TIMESTAMP | — | Technique | CURRENT_TIMESTAMP as last_activity_date | 2026-09-02 23:43:21.697544 |  |  |  |
| lot_size | NUMERIC(20,0) | raw_data.marc.bstmi | SAP | Tailles de lot (sources SAP MARC)
SQL : COALESCE(NULLIF(marc.bstmi, '')::numeric, 0) as lot_size | 0 |  |  |  |
| lot_size_auto | VARCHAR(4000) | public.etl_default_values (invent_part_plan.lot_size_auto) | Config | public.get_default_value('clean_data.invent_part_plan', 'lot_size_auto') as lot_size_auto |  |  |  |  |
| lot_size_auto_db | VARCHAR(1) | public.etl_default_values (invent_part_plan.lot_size_auto_db) | Config | public.get_default_value('clean_data.invent_part_plan', 'lot_size_auto_db') as lot_size_auto_db | N |  |  |  |
| max_order_qty | NUMERIC(20,0) | raw_data.marc.bstma | SAP | COALESCE(NULLIF(marc.bstma, '')::numeric, 0) as max_order_qty | 0 |  |  |  |
| min_order_qty | NUMERIC(20,0) | raw_data.marc.bstmi | SAP | COALESCE(NULLIF(marc.bstmi, '')::numeric, 0) as min_order_qty | 0 |  |  |  |
| mul_order_qty | NUMERIC(20,0) | public.etl_default_values (invent_part_plan.mul_order_qty) | Config | public.get_default_value('clean_data.invent_part_plan', 'mul_order_qty')::numeric as mul_order_qty | 0 |  |  |  |
| std_order_size | NUMERIC(20,0) | raw_data.marc.bstmi | SAP | COALESCE(NULLIF(marc.bstmi, '')::numeric, 0) as std_order_size | 0 |  |  |  |
| order_point_qty | NUMERIC(20,0) | raw_data.marc.minbe | SAP | Point de commande et stock
SQL : COALESCE(NULLIF(marc.minbe, '')::numeric, 0) as order_point_qty | 0 |  |  |  |
| order_point_qty_auto | VARCHAR(4000) | public.etl_default_values (invent_part_plan.order_point_qty_auto) | Config | public.get_default_value('clean_data.invent_part_plan', 'order_point_qty_auto') as order_point_qty_auto |  |  |  |  |
| order_point_qty_auto_db | VARCHAR(1) | public.etl_default_values (invent_part_plan.order_point_qty_auto_db) | Config | public.get_default_value('clean_data.invent_part_plan', 'order_point_qty_auto_db') as order_point_qty_auto_db | N |  |  |  |
| safety_stock | NUMERIC(20,0) | raw_data.marc.eisbe | SAP | COALESCE(NULLIF(marc.eisbe, '')::numeric, 0) as safety_stock | 0 |  |  |  |
| safety_stock_auto | VARCHAR(4000) | public.etl_default_values (invent_part_plan.safety_stock_auto) | Config | public.get_default_value('clean_data.invent_part_plan', 'safety_stock_auto') as safety_stock_auto |  |  |  |  |
| safety_stock_auto_db | VARCHAR(1) | public.etl_default_values (invent_part_plan.safety_stock_auto_db) | Config | public.get_default_value('clean_data.invent_part_plan', 'safety_stock_auto_db') as safety_stock_auto_db | N |  |  |  |
| safety_lead_time | NUMERIC(20,0) | raw_data.marc.shflg | SAP | Délais et couverture
SQL : COALESCE(NULLIF(marc.shflg, '')::numeric, 0) as safety_lead_time | 0 |  |  |  |
| maxweek_supply | NUMERIC(20,0) | public.etl_default_values (invent_part_plan.maxweek_supply) | Config | public.get_default_value('clean_data.invent_part_plan', 'maxweek_supply')::numeric as maxweek_supply | 0 |  |  |  |
| setup_cost | NUMERIC(20,0) | public.etl_default_values (invent_part_plan.setup_cost) | Config | public.get_default_value('clean_data.invent_part_plan', 'setup_cost')::numeric as setup_cost | 0 |  |  |  |
| carry_rate | NUMERIC(20,0) | public.etl_default_values (invent_part_plan.carry_rate) | Config | public.get_default_value('clean_data.invent_part_plan', 'carry_rate')::numeric as carry_rate | 0 |  |  |  |
| service_rate | NUMERIC(20,0) | public.etl_default_values (invent_part_plan.service_rate) | Config | public.get_default_value('clean_data.invent_part_plan', 'service_rate')::numeric as service_rate | 0 |  |  |  |
| shrinkage_fac | NUMERIC(20,0) | public.etl_default_values (invent_part_plan.shrinkage_fac) | Config | public.get_default_value('clean_data.invent_part_plan', 'shrinkage_fac')::numeric as shrinkage_fac | 0 |  |  |  |
| planning_method | VARCHAR(1) | raw_data.marc.dismm ; raw_data.marc.beskz | SAP | Méthode de planification (MARC.DISMM) Si VB, ZM, ZB → B (Planning Method Point commande) Si vide, M0, RP, PD, ZP → M (Planifié manuellement) Pour tout ce qui est Production → A (Lot pour lot) Par défaut → M
SQL : CASE WHEN UPPER(marc.dismm) IN ('VB', 'ZM', 'ZB') THEN 'B' WHEN UPPER(marc.dismm) IN ('', 'M0', 'RP', 'PD', 'ZP') OR marc.dismm IS NULL THEN 'M' WHEN marc.beskz = 'E' THEN 'A' ELSE 'M' END as planning_method | M |  |  |  |
| planning_method_auto | VARCHAR(4000) | public.etl_default_values (invent_part_plan.planning_method_auto) | Config | public.get_default_value('clean_data.invent_part_plan', 'planning_method_auto') as planning_method_auto |  |  |  |  |
| planning_method_auto_db | VARCHAR(20) | public.etl_default_values (invent_part_plan.planning_method_auto_db) | Config | public.get_default_value('clean_data.invent_part_plan', 'planning_method_auto_db') as planning_method_auto_db | TRUE |  |  |  |
| order_requisition | VARCHAR(4000) | public.etl_default_values (invent_part_plan.order_requisition) | Config | Type d'approvisionnement
SQL : public.get_default_value('clean_data.invent_part_plan', 'order_requisition') as order_requisition |  |  |  |  |
| order_requisition_db | VARCHAR(1) | public.etl_default_values (invent_part_plan.order_requisition_db) | Config | public.get_default_value('clean_data.invent_part_plan', 'order_requisition_db') as order_requisition_db | R |  |  |  |
| proposal_release | VARCHAR(4000) | public.etl_default_values (invent_part_plan.proposal_release) | Config | public.get_default_value('clean_data.invent_part_plan', 'proposal_release') as proposal_release |  |  |  |  |
| proposal_release_db | VARCHAR(20) | public.etl_default_values (invent_part_plan.proposal_release_db) | Config | public.get_default_value('clean_data.invent_part_plan', 'proposal_release_db') as proposal_release_db | RELEASE |  |  |  |
| percent_manufactured | NUMERIC(20,0) | raw_data.marc.beskz | SAP | Split fabrication/achat 100% fabriqué si production
SQL : CASE WHEN marc.beskz = 'E' THEN 100 ELSE 0 END as percent_manufactured | 0 |  |  |  |
| percent_acquired | NUMERIC(20,0) | raw_data.marc.beskz | SAP | 0% acheté si production 100% acheté sinon
SQL : CASE WHEN marc.beskz = 'E' THEN 0 ELSE 100 END as percent_acquired | 100 |  |  |  |
| split_manuf_acquired | VARCHAR(4000) | public.etl_default_values (invent_part_plan.split_manuf_acquired) | Config | public.get_default_value('clean_data.invent_part_plan', 'split_manuf_acquired') as split_manuf_acquired |  |  |  |  |
| split_manuf_acquired_db | VARCHAR(20) | public.etl_default_values (invent_part_plan.split_manuf_acquired_db) | Config | public.get_default_value('clean_data.invent_part_plan', 'split_manuf_acquired_db') as split_manuf_acquired_db | NO_SPLIT |  |  |  |
| acquired_supply_type | VARCHAR(4000) | public.etl_default_values (invent_part_plan.acquired_supply_type) | Config | public.get_default_value('clean_data.invent_part_plan', 'acquired_supply_type') as acquired_supply_type |  |  |  |  |
| acquired_supply_type_db | VARCHAR(20) | public.etl_default_values (invent_part_plan.acquired_supply_type_db) | Config | public.get_default_value('clean_data.invent_part_plan', 'acquired_supply_type_db') as acquired_supply_type_db | R |  |  |  |
| manuf_supply_type | VARCHAR(4000) | public.etl_default_values (invent_part_plan.manuf_supply_type) | Config | public.get_default_value('clean_data.invent_part_plan', 'manuf_supply_type') as manuf_supply_type |  |  |  |  |
| manuf_supply_type_db | VARCHAR(20) | public.etl_default_values (invent_part_plan.manuf_supply_type_db) | Config | public.get_default_value('clean_data.invent_part_plan', 'manuf_supply_type_db') as manuf_supply_type_db | R |  |  |  |
| sched_capacity | VARCHAR(4000) | public.etl_default_values (invent_part_plan.sched_capacity) | Config | Capacité de planification
SQL : public.get_default_value('clean_data.invent_part_plan', 'sched_capacity') as sched_capacity |  |  |  |  |
| sched_capacity_db | VARCHAR(20) | public.etl_default_values (invent_part_plan.sched_capacity_db) | Config | public.get_default_value('clean_data.invent_part_plan', 'sched_capacity_db') as sched_capacity_db | I |  |  |  |
## Sheet: 05_PURCHASE_PART
| Colonne cible | Type / Longueur | Champ / Table source | Systeme source | Regle de transformation / Condition | Exemple de valeur | Valide metier (O/N) | Remarques metier | Date validation |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Script alimenter_purchase_part.sql  —  Article d'achat par site. Centres 9200 / 9000 / 2200 et approvisionnement externe (MARC.BESKZ dans F, X). Les articles de vente (raw_data.articles_vente_sap) en sont EXCLUS : ils relevent de SALES_PART. |  |  |  |  |  |  |  |  |
| contract | VARCHAR(5) | raw_data.marc.werks | SAP | 9200 = SJ, 9000 = CS
SQL : CASE WHEN marc.werks = '9200' THEN 'SJ' WHEN marc.werks = '9000' THEN 'CS' ELSE 'SJ' END as contract | SJ |  |  |  |
| part_no | VARCHAR(25) | clean_data.ifs_article_maitre.numero_article | IFS | numero_article SAP (pas de transcodification, l'article garde son ID)
SQL : SUBSTRING(TRIM(LTRIM(ifs.numero_article, '0')), 1, 25) as part_no | 220004 |  |  |  |
| description | VARCHAR(200) | raw_data.makt.maktx ; raw_data.mara.matnr | SAP | MAKT.MAKTX (FR) sinon MARA.MATNR
SQL : SUBSTRING(COALESCE(makt.maktx, mara.matnr), 1, 200) as description | ROUE TANGENTE = 1 REP.7 + 1 REP.8 |  |  |  |
| eng_attribute | VARCHAR(5) | public.etl_default_values (purchase_part.eng_attribute) | Config | public.get_default_value('clean_data.purchase_part', 'eng_attribute') as eng_attribute |  |  |  |  |
| note_id | NUMERIC(20,0) | public.etl_default_values (purchase_part.note_id) | Config | vide (numeric)
SQL : public.get_default_value('clean_data.purchase_part', 'note_id')::numeric as note_id |  |  |  |  |
| qc_code | VARCHAR(20) | public.etl_default_values (purchase_part.qc_code) | Config | public.get_default_value('clean_data.purchase_part', 'qc_code') as qc_code |  |  |  |  |
| stat_grp | VARCHAR(6) | public.etl_default_values (purchase_part.stat_grp) | Config | public.get_default_value('clean_data.purchase_part', 'stat_grp') as stat_grp |  |  |  |  |
| close_code | VARCHAR(4000) | public.etl_default_values (purchase_part.close_code) | Config | Automatic (libellé IFS de Y)
SQL : public.get_default_value('clean_data.purchase_part', 'close_code') as close_code |  |  |  |  |
| close_code_db | VARCHAR(1) | public.etl_default_values (purchase_part.close_code_db) | Config | public.get_default_value('clean_data.purchase_part', 'close_code_db') as close_code_db | Y |  |  |  |
| close_tolerance | NUMERIC(20,0) | public.etl_default_values (purchase_part.close_tolerance) | Config | public.get_default_value('clean_data.purchase_part', 'close_tolerance')::numeric as close_tolerance | 0 |  |  |  |
| date_cre | TIMESTAMP | raw_data.mara.ersda | SAP | MARA.ERSDA (date création article SAP)
SQL : CASE WHEN mara.ersda IS NOT NULL AND mara.ersda <> '' THEN TO_DATE(mara.ersda, 'YYYYMMDD') ELSE NULL END as date_cre | 1998-10-26 00:00:00 |  |  |  |
| inventory_flag | VARCHAR(4000) | raw_data.mara.mtart | SAP | INVENTORY_FLAG / _DB: si type IBAU/DIEN/NLAG => N (No), sinon Y (Yes)
SQL : CASE WHEN mara.mtart IN ('IBAU', 'DIEN', 'NLAG') THEN 'No' ELSE 'Yes' END as inventory_flag | Yes |  |  |  |
| inventory_flag_db | VARCHAR(1) | raw_data.mara.mtart | SAP | CASE WHEN mara.mtart IN ('IBAU', 'DIEN', 'NLAG') THEN 'N' ELSE 'Y' END as inventory_flag_db | Y |  |  |  |
| note_text | VARCHAR(2000) | public.etl_default_values (purchase_part.note_text) | Config | public.get_default_value('clean_data.purchase_part', 'note_text') as note_text |  |  |  |  |
| qc_date | TIMESTAMP | public.etl_default_values (purchase_part.qc_date) | Config | public.get_default_value('clean_data.purchase_part', 'qc_date')::timestamp as qc_date |  |  |  |  |
| default_buy_unit_meas | VARCHAR(10) | raw_data.mara.bstme ; raw_data.mara.meins ; public."TranscodificationTable" (categorie UOM) | SAP / Config | MARA.BSTME sinon MEINS via transcodification UOM (SAP->IFS), sinon unité d'entrée
SQL : SUBSTRING(COALESCE( public.get_transcodification('UOM', NULLIF(UPPER(TRIM(COALESCE(NULLIF(mara.bstme, ''), mara.meins))), '')), UPPER(TRIM(COALESCE(NULLIF(mara.bstme, ''), mara.meins))) ), 1, 10) as default_buy_unit_meas | PCS |  |  |  |
| over_delivery_tolerance | NUMERIC(20,0) | public.etl_default_values (purchase_part.over_delivery_tolerance) | Config | public.get_default_value('clean_data.purchase_part', 'over_delivery_tolerance')::numeric as over_delivery_tolerance | 0 |  |  |  |
| over_delivery | VARCHAR(4000) | public.etl_default_values (purchase_part.over_delivery) | Config | OVER_DELIVERY / _DB: Yes / YES
SQL : public.get_default_value('clean_data.purchase_part', 'over_delivery') as over_delivery |  |  |  |  |
| over_delivery_db | VARCHAR(20) | public.etl_default_values (purchase_part.over_delivery_db) | Config | public.get_default_value('clean_data.purchase_part', 'over_delivery_db') as over_delivery_db | YES |  |  |  |
| buyer_code | VARCHAR(20) | public.etl_default_values (purchase_part.buyer_code) | Config | public.get_default_value('clean_data.purchase_part', 'buyer_code') as buyer_code |  |  |  |  |
| process_type | VARCHAR(3) | public.etl_default_values (purchase_part.process_type) | Config | public.get_default_value('clean_data.purchase_part', 'process_type') as process_type | STD |  |  |  |
| std_name_description | VARCHAR(200) | public.etl_default_values (purchase_part.std_name_description) | Config | public.get_default_value('clean_data.purchase_part', 'std_name_description') as std_name_description |  |  |  |  |
| standard_pack_size | NUMERIC(20,0) | public.etl_default_values (purchase_part.standard_pack_size) | Config | public.get_default_value('clean_data.purchase_part', 'standard_pack_size')::numeric as standard_pack_size | 1 |  |  |  |
| technical_coordinator_id | VARCHAR(4000) | public.etl_default_values (purchase_part.technical_coordinator_id) | Config | public.get_default_value('clean_data.purchase_part', 'technical_coordinator_id') as technical_coordinator_id |  |  |  |  |
| taxable | VARCHAR(4000) | public.etl_default_values (purchase_part.taxable) | Config | TAXABLE / _DB: Yes / TRUE
SQL : public.get_default_value('clean_data.purchase_part', 'taxable') as taxable |  |  |  |  |
| taxable_db | VARCHAR(5) | public.etl_default_values (purchase_part.taxable_db) | Config | public.get_default_value('clean_data.purchase_part', 'taxable_db') as taxable_db | TRUE |  |  |  |
| dop_pegged_po_update_flag | VARCHAR(4000) | public.etl_default_values (purchase_part.dop_pegged_po_update_flag) | Config | DOP_PEGGED_PO_UPDATE_FLAG / _DB: Planned / PLANNED
SQL : public.get_default_value('clean_data.purchase_part', 'dop_pegged_po_update_flag') as dop_pegged_po_update_flag |  |  |  |  |
| dop_pegged_po_update_flag_db | VARCHAR(20) | public.etl_default_values (purchase_part.dop_pegged_po_update_flag_db) | Config | public.get_default_value('clean_data.purchase_part', 'dop_pegged_po_update_flag_db') as dop_pegged_po_update_flag_db | PLANNED |  |  |  |
| acquisition_type | VARCHAR(4000) | public.etl_default_values (purchase_part.acquisition_type) | Config | ACQUISITION_TYPE / _DB: Purchase / PURCHASE
SQL : public.get_default_value('clean_data.purchase_part', 'acquisition_type') as acquisition_type |  |  |  |  |
| acquisition_type_db | VARCHAR(20) | public.etl_default_values (purchase_part.acquisition_type_db) | Config | public.get_default_value('clean_data.purchase_part', 'acquisition_type_db') as acquisition_type_db | PURCHASE |  |  |  |
| action_non_authorized | VARCHAR(4000) | public.etl_default_values (purchase_part.action_non_authorized) | Config | ACTION_NON_AUTHORIZED / _DB: Warning / WARNING
SQL : public.get_default_value('clean_data.purchase_part', 'action_non_authorized') as action_non_authorized |  |  |  |  |
| action_non_authorized_db | VARCHAR(20) | public.etl_default_values (purchase_part.action_non_authorized_db) | Config | public.get_default_value('clean_data.purchase_part', 'action_non_authorized_db') as action_non_authorized_db | WARNING |  |  |  |
| action_authorized | VARCHAR(4000) | public.etl_default_values (purchase_part.action_authorized) | Config | ACTION_AUTHORIZED / _DB: Warning / WARNING
SQL : public.get_default_value('clean_data.purchase_part', 'action_authorized') as action_authorized |  |  |  |  |
| action_authorized_db | VARCHAR(20) | public.etl_default_values (purchase_part.action_authorized_db) | Config | public.get_default_value('clean_data.purchase_part', 'action_authorized_db') as action_authorized_db | WARNING |  |  |  |
| external_resource | VARCHAR(4000) | raw_data.mara.mtart | SAP | EXTERNAL_RESOURCE / _DB: DIEN => Yes/TRUE sinon No/FALSE
SQL : CASE WHEN mara.mtart = 'DIEN' THEN 'Yes' ELSE 'No' END as external_resource | No |  |  |  |
| external_resource_db | VARCHAR(5) | raw_data.mara.mtart | SAP | CASE WHEN mara.mtart = 'DIEN' THEN 'TRUE' ELSE 'FALSE' END as external_resource_db | FALSE |  |  |  |
| company | VARCHAR(20) | public.etl_default_values (purchase_part.company) | Config | public.get_default_value('clean_data.purchase_part', 'company') as company | TRIMET |  |  |  |
| statistical_code | VARCHAR(15) | public.etl_default_values (purchase_part.statistical_code) | Config | STATISTICAL_CODE / STATISTICAL_CODE_MANUF: vide
SQL : public.get_default_value('clean_data.purchase_part', 'statistical_code') as statistical_code |  |  |  |  |
| statistical_code_manuf | VARCHAR(15) | public.etl_default_values (purchase_part.statistical_code_manuf) | Config | public.get_default_value('clean_data.purchase_part', 'statistical_code_manuf') as statistical_code_manuf |  |  |  |  |
| quality_system_level_id | VARCHAR(50) | public.etl_default_values (purchase_part.quality_system_level_id) | Config | QUALITY_SYSTEM_LEVEL_ID / QSL_APPROVAL_TEMPLATE: vide
SQL : public.get_default_value('clean_data.purchase_part', 'quality_system_level_id') as quality_system_level_id |  |  |  |  |
| qsl_approval_template | VARCHAR(10) | public.etl_default_values (purchase_part.qsl_approval_template) | Config | public.get_default_value('clean_data.purchase_part', 'qsl_approval_template') as qsl_approval_template |  |  |  |  |
| qualified_manufacturer | VARCHAR(4000) | public.etl_default_values (purchase_part.qualified_manufacturer) | Config | QUALIFIED_MANUFACTURER / _DB: No / FALSE
SQL : public.get_default_value('clean_data.purchase_part', 'qualified_manufacturer') as qualified_manufacturer |  |  |  |  |
| qualified_manufacturer_db | VARCHAR(20) | public.etl_default_values (purchase_part.qualified_manufacturer_db) | Config | public.get_default_value('clean_data.purchase_part', 'qualified_manufacturer_db') as qualified_manufacturer_db | FALSE |  |  |  |
| qmr_approval_template | VARCHAR(10) | public.etl_default_values (purchase_part.qmr_approval_template) | Config | public.get_default_value('clean_data.purchase_part', 'qmr_approval_template') as qmr_approval_template |  |  |  |  |
| qualified_supplier | VARCHAR(4000) | public.etl_default_values (purchase_part.qualified_supplier) | Config | QUALIFIED_SUPPLIER / _DB: No / FALSE
SQL : public.get_default_value('clean_data.purchase_part', 'qualified_supplier') as qualified_supplier |  |  |  |  |
| qualified_supplier_db | VARCHAR(20) | public.etl_default_values (purchase_part.qualified_supplier_db) | Config | public.get_default_value('clean_data.purchase_part', 'qualified_supplier_db') as qualified_supplier_db | FALSE |  |  |  |
| qsr_approval_template | VARCHAR(10) | public.etl_default_values (purchase_part.qsr_approval_template) | Config | public.get_default_value('clean_data.purchase_part', 'qsr_approval_template') as qsr_approval_template |  |  |  |  |
| acquisition_origin | NUMERIC(20,0) | public.etl_default_values (purchase_part.acquisition_origin) | Config | public.get_default_value('clean_data.purchase_part', 'acquisition_origin')::numeric as acquisition_origin |  |  |  |  |
| acquisition_reason_id | VARCHAR(10) | public.etl_default_values (purchase_part.acquisition_reason_id) | Config | public.get_default_value('clean_data.purchase_part', 'acquisition_reason_id') as acquisition_reason_id |  |  |  |  |
| package_part_flag | VARCHAR(4000) | public.etl_default_values (purchase_part.package_part_flag) | Config | PACKAGE_PART_FLAG / _DB: No / FALSE
SQL : public.get_default_value('clean_data.purchase_part', 'package_part_flag') as package_part_flag |  |  |  |  |
| package_part_flag_db | VARCHAR(5) | public.etl_default_values (purchase_part.package_part_flag_db) | Config | public.get_default_value('clean_data.purchase_part', 'package_part_flag_db') as package_part_flag_db | FALSE |  |  |  |
| nbs_code | VARCHAR(50) | public.etl_default_values (purchase_part.nbs_code) | Config | public.get_default_value('clean_data.purchase_part', 'nbs_code') as nbs_code |  |  |  |  |
| objversion | VARCHAR(50) | public.etl_default_values (purchase_part.objversion) | Config | vide (généré par IFS)
SQL : public.get_default_value('clean_data.purchase_part', 'objversion') as objversion |  |  |  |  |
| objid | VARCHAR(50) | public.etl_default_values (purchase_part.objid) | Config | vide (généré par IFS)
SQL : public.get_default_value('clean_data.purchase_part', 'objid') as objid |  |  |  |  |
| std_name_id | VARCHAR(50) | public.etl_default_values (purchase_part.std_name_id) | Config | public.get_default_value('clean_data.purchase_part', 'std_name_id') as std_name_id |  |  |  |  |
## Sheet: 06_PURCHASE_PART_SUPPLIER
| Colonne cible | Type / Longueur | Champ / Table source | Systeme source | Regle de transformation / Condition | Exemple de valeur | Valide metier (O/N) | Remarques metier | Date validation |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Script alimenter_purchase_part_supplier.sql  —  Lien article x fournisseur issu des fiches info-achat SAP (EINA/EINE). Le fournisseur est remappe sur son NOUVEAU numero IFS (600xxx) via supplier_info_general.supplier_legacy_sap_id. |  |  |  |  |  |  |  |  |
| contract | VARCHAR(5) | raw_data.eine.ekorg | SAP | 9200 = SJ, 9000 = CS
SQL : CASE WHEN eine.ekorg = '9200' THEN 'SJ' WHEN eine.ekorg = '9000' THEN 'CS' ELSE 'SJ' END as contract | SJ |  |  |  |
| part_no | VARCHAR(25) | clean_data.ifs_article_maitre.numero_article | IFS | numero_article SAP (pas de transcodification, l'article garde son ID)
SQL : SUBSTRING(TRIM(LTRIM(ifs.numero_article, '0')), 1, 25) as part_no | 220004 |  |  |  |
| vendor_no | VARCHAR(20) | clean_data.supplier_info_general.supplier_id | IFS | NOUVEAU numéro IFS du fournisseur (renuméroté 600xxx), mappé depuis le LIFNR SAP via supplier_info_general.supplier_legacy_sap_id. Indispensable : la table supplier est renumérotée, le LIFNR SAP brut ne correspond plus.
SQL : SUBSTRING(sig.supplier_id, 1, 20) as vendor_no | 600407 |  |  |  |
| buy_unit_meas | VARCHAR(30) | raw_data.eina.meins ; public."TranscodificationTable" (categorie UOM) | SAP / Config | EINA.MEINS via transcodification UOM (SAP->IFS), sinon unité d'entrée
SQL : SUBSTRING(COALESCE( public.get_transcodification('UOM', NULLIF(UPPER(TRIM(eina.meins)), '')), UPPER(TRIM(eina.meins)) ), 1, 10) as buy_unit_meas | PCS |  |  |  |
| currency_code | VARCHAR(3) | raw_data.eine.waers | SAP | SUBSTRING(COALESCE(NULLIF(eine.waers, ''), 'EUR'), 1, 3) as currency_code | EUR |  |  |  |
| status_code | VARCHAR(2) | public.etl_default_values (purchase_part_supplier.status_code) | Config | public.get_default_value('clean_data.purchase_part_supplier', 'status_code') as status_code | 2 |  |  |  |
| primary_vendor_db | VARCHAR(1) | public.etl_default_values (purchase_part_supplier.primary_vendor_db) | Config | Y par défaut (fournisseur principal)
SQL : public.get_default_value('clean_data.purchase_part_supplier', 'primary_vendor_db') as primary_vendor_db | Y |  |  |  |
| leadtime_auto_db | VARCHAR(1) | public.etl_default_values (purchase_part_supplier.leadtime_auto_db) | Config | N (délai manuel)
SQL : public.get_default_value('clean_data.purchase_part_supplier', 'leadtime_auto_db') as leadtime_auto_db | N |  |  |  |
| receive_case_db | VARCHAR(20) | public.etl_default_values (purchase_part_supplier.receive_case_db) | Config | INVDIR (réception directe en stock)
SQL : public.get_default_value('clean_data.purchase_part_supplier', 'receive_case_db') as receive_case_db | INVDIR |  |  |  |
| external_service_allowed_db | VARCHAR(5) | public.etl_default_values (purchase_part_supplier.external_service_allowed_db) | Config | public.get_default_value('clean_data.purchase_part_supplier', 'external_service_allowed_db') as external_service_allowed_db | FALSE |  |  |  |
| part_ownership_db | VARCHAR(20) | public.etl_default_values (purchase_part_supplier.part_ownership_db) | Config | COMPANY OWNED
SQL : public.get_default_value('clean_data.purchase_part_supplier', 'part_ownership_db') as part_ownership_db | COMPANY OWNED |  |  |  |
| dist_order_receipt_type_db | VARCHAR(20) | public.etl_default_values (purchase_part_supplier.dist_order_receipt_type_db) | Config | NO AUTOMATIC RECPT
SQL : public.get_default_value('clean_data.purchase_part_supplier', 'dist_order_receipt_type_db') as dist_order_receipt_type_db | NO AUTOMATIC RECPT |  |  |  |
| multisite_planned_part_db | VARCHAR(20) | public.etl_default_values (purchase_part_supplier.multisite_planned_part_db) | Config | NOT_MULTISITE_PLAN
SQL : public.get_default_value('clean_data.purchase_part_supplier', 'multisite_planned_part_db') as multisite_planned_part_db | NOT_MULTISITE_PLAN |  |  |  |
| quick_registered_part_db | VARCHAR(20) | public.etl_default_values (purchase_part_supplier.quick_registered_part_db) | Config | public.get_default_value('clean_data.purchase_part_supplier', 'quick_registered_part_db') as quick_registered_part_db | FALSE |  |  |  |
| purchase_payment_type_db | VARCHAR(20) | public.etl_default_values (purchase_part_supplier.purchase_payment_type_db) | Config | public.get_default_value('clean_data.purchase_part_supplier', 'purchase_payment_type_db') as purchase_payment_type_db | NORMAL |  |  |  |
| acquisition_type_db | VARCHAR(20) | public.etl_default_values (purchase_part_supplier.acquisition_type_db) | Config | public.get_default_value('clean_data.purchase_part_supplier', 'acquisition_type_db') as acquisition_type_db | PURCHASE |  |  |  |
| rental_primary_vendor_db | VARCHAR(1) | public.etl_default_values (purchase_part_supplier.rental_primary_vendor_db) | Config | public.get_default_value('clean_data.purchase_part_supplier', 'rental_primary_vendor_db') as rental_primary_vendor_db | N |  |  |  |
| use_price_incl_tax_db | VARCHAR(20) | public.etl_default_values (purchase_part_supplier.use_price_incl_tax_db) | Config | public.get_default_value('clean_data.purchase_part_supplier', 'use_price_incl_tax_db') as use_price_incl_tax_db | FALSE |  |  |  |
| qualified_supplier_db | VARCHAR(20) | public.etl_default_values (purchase_part_supplier.qualified_supplier_db) | Config | public.get_default_value('clean_data.purchase_part_supplier', 'qualified_supplier_db') as qualified_supplier_db | FALSE |  |  |  |
| ext_svc_primary_vendor_db | VARCHAR(5) | public.etl_default_values (purchase_part_supplier.ext_svc_primary_vendor_db) | Config | public.get_default_value('clean_data.purchase_part_supplier', 'ext_svc_primary_vendor_db') as ext_svc_primary_vendor_db | FALSE |  |  |  |
| issue_packaging_material_db | VARCHAR(5) | public.etl_default_values (purchase_part_supplier.issue_packaging_material_db) | Config | public.get_default_value('clean_data.purchase_part_supplier', 'issue_packaging_material_db') as issue_packaging_material_db | FALSE |  |  |  |
## Sheet: 07_SALES_PART
| Colonne cible | Type / Longueur | Champ / Table source | Systeme source | Regle de transformation / Condition | Exemple de valeur | Valide metier (O/N) | Remarques metier | Date validation |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Script alimenter_sales_part.sql  —  Article de vente. Perimetre = raw_data.articles_vente_sap, restreint aux types d'article FERT / HALB / DIEN / NLAG / HIBE / ERSA presents dans part_catalog. |  |  |  |  |  |  |  |  |
| contract | VARCHAR(5) | raw_data.marc.werks | SAP | Clés primaires
SQL : CASE WHEN marc.werks = '9200' THEN 'SJ' WHEN marc.werks = '9100' THEN 'CS' ELSE 'SJ' END as contract | SJ |  |  |  |
| catalog_no | VARCHAR(25) | raw_data.mara.matnr | SAP | SUBSTRING(LTRIM(mara.matnr, '0'), 1, 25) as catalog_no | 220451 |  |  |  |
| catalog_desc | VARCHAR(200) | raw_data.makt.maktx ; raw_data.mara.matnr | SAP | Données de base
SQL : SUBSTRING(COALESCE(makt.maktx, mara.matnr), 1, 200) as catalog_desc | SURLUNETTE DE SECURITE G-SUPER PLUS |  |  |  |
| sales_unit_meas | VARCHAR(10) | raw_data.mvke.vrkme ; raw_data.mara.meins ; public."TranscodificationTable" (categorie UOM) | SAP / Config | MVKE.VRKME sinon MARA.MEINS via transcodification UOM (SAP->IFS), sinon unité d'entrée
SQL : SUBSTRING(COALESCE( public.get_transcodification('UOM', NULLIF(UPPER(TRIM(COALESCE(NULLIF(mvke.vrkme, ''), mara.meins))), '')), UPPER(TRIM(COALESCE(NULLIF(mvke.vrkme, ''), mara.meins))) ), 1, 10) as sales_unit_meas | PCS |  |  |  |
| catalog_group | VARCHAR(10) | public.etl_default_values (sales_part.catalog_group) | Config | public.get_default_value('clean_data.sales_part', 'catalog_group') as catalog_group | 903028 |  |  |  |
| sales_price_group_id | VARCHAR(10) | public.etl_default_values (sales_part.sales_price_group_id) | Config | public.get_default_value('clean_data.sales_part', 'sales_price_group_id') as sales_price_group_id | * |  |  |  |
| part_no | VARCHAR(25) | raw_data.mara.mtart ; raw_data.mara.matnr | SAP | Article lié (pour Inventory part)
SQL : CASE WHEN mara.mtart IN ('FERT', 'HALB', 'ROH') THEN SUBSTRING(LTRIM(mara.matnr, '0'), 1, 25) ELSE NULL END as part_no |  |  |  |  |
| activeind_db | VARCHAR(1) | public.etl_default_values (sales_part.activeind_db) | Config | Flags et statuts (_DB uniquement) : tous les articles actifs
SQL : public.get_default_value('clean_data.sales_part', 'activeind_db') as activeind_db | Y |  |  |  |
| catalog_type_db | VARCHAR(4) | raw_data.mara.mtart | SAP | CASE WHEN mara.mtart IN ('FERT', 'HALB', 'ROH') THEN 'INV' ELSE 'NON' END as catalog_type_db | NON |  |  |  |
| conv_factor | NUMERIC(20,0) | public.etl_default_values (sales_part.conv_factor) | Config | Facteurs de conversion
SQL : public.get_default_value('clean_data.sales_part', 'conv_factor')::numeric as conv_factor | 1 |  |  |  |
| inverted_conv_factor | NUMERIC(20,0) | public.etl_default_values (sales_part.inverted_conv_factor) | Config | public.get_default_value('clean_data.sales_part', 'inverted_conv_factor')::numeric as inverted_conv_factor | 1 |  |  |  |
| price_conv_factor | NUMERIC(20,0) | public.etl_default_values (sales_part.price_conv_factor) | Config | public.get_default_value('clean_data.sales_part', 'price_conv_factor')::numeric as price_conv_factor | 1 |  |  |  |
| price_unit_meas | VARCHAR(10) | raw_data.mvke.vrkme ; raw_data.mara.meins ; public."TranscodificationTable" (categorie UOM) | SAP / Config | MVKE.VRKME sinon MARA.MEINS via transcodification UOM (SAP->IFS), sinon unité d'entrée
SQL : SUBSTRING(COALESCE( public.get_transcodification('UOM', NULLIF(UPPER(TRIM(COALESCE(NULLIF(mvke.vrkme, ''), mara.meins))), '')), UPPER(TRIM(COALESCE(NULLIF(mvke.vrkme, ''), mara.meins))) ), 1, 10) as price_unit_meas | PCS |  |  |  |
| list_price | NUMERIC(20,0) | public.etl_default_values (sales_part.list_price) | Config | Prix (par défaut à 0)
SQL : public.get_default_value('clean_data.sales_part', 'list_price')::numeric as list_price | 0 |  |  |  |
| list_price_incl_tax | NUMERIC(20,0) | public.etl_default_values (sales_part.list_price_incl_tax) | Config | public.get_default_value('clean_data.sales_part', 'list_price_incl_tax')::numeric as list_price_incl_tax | 0 |  |  |  |
| rental_list_price | NUMERIC(20,0) | public.etl_default_values (sales_part.rental_list_price) | Config | public.get_default_value('clean_data.sales_part', 'rental_list_price')::numeric as rental_list_price | 0 |  |  |  |
| rental_list_price_incl_tax | NUMERIC(20,0) | public.etl_default_values (sales_part.rental_list_price_incl_tax) | Config | public.get_default_value('clean_data.sales_part', 'rental_list_price_incl_tax')::numeric as rental_list_price_incl_tax | 0 |  |  |  |
| cost | NUMERIC(20,0) | public.etl_default_values (sales_part.cost) | Config | public.get_default_value('clean_data.sales_part', 'cost')::numeric as cost |  |  |  |  |
| expected_average_price | NUMERIC(20,0) | public.etl_default_values (sales_part.expected_average_price) | Config | public.get_default_value('clean_data.sales_part', 'expected_average_price')::numeric as expected_average_price |  |  |  |  |
| taxable_db | VARCHAR(20) | public.etl_default_values (sales_part.taxable_db) | Config | Taxes (_DB uniquement)
SQL : public.get_default_value('clean_data.sales_part', 'taxable_db') as taxable_db | TRUE |  |  |  |
| tax_code | VARCHAR(20) | public.etl_default_values (sales_part.tax_code) | Config | public.get_default_value('clean_data.sales_part', 'tax_code') as tax_code | C05 |  |  |  |
| tax_class_id | VARCHAR(20) | public.etl_default_values (sales_part.tax_class_id) | Config | public.get_default_value('clean_data.sales_part', 'tax_class_id') as tax_class_id |  |  |  |  |
| use_price_incl_tax_db | VARCHAR(20) | public.etl_default_values (sales_part.use_price_incl_tax_db) | Config | public.get_default_value('clean_data.sales_part', 'use_price_incl_tax_db') as use_price_incl_tax_db | FALSE |  |  |  |
| date_entered | TIMESTAMP | raw_data.mara.ersda | SAP | CASE WHEN mara.ersda IS NOT NULL AND mara.ersda ~ '^\d{8}$' THEN TO_TIMESTAMP(mara.ersda, 'YYYYMMDD') ELSE CURRENT_TIMESTAMP END as date_entered | 1998-10-26 00:00:00 |  |  |  |
| price_change_date | TIMESTAMP | public.etl_default_values (sales_part.price_change_date) | Config | public.get_default_value('clean_data.sales_part', 'price_change_date')::timestamp as price_change_date |  |  |  |  |
| close_tolerance | NUMERIC(20,0) | public.etl_default_values (sales_part.close_tolerance) | Config | Tolérances et quantités
SQL : public.get_default_value('clean_data.sales_part', 'close_tolerance')::numeric as close_tolerance | 0 |  |  |  |
| minimum_qty | NUMERIC(20,0) | public.etl_default_values (sales_part.minimum_qty) | Config | public.get_default_value('clean_data.sales_part', 'minimum_qty')::numeric as minimum_qty |  |  |  |  |
| sourcing_option_db | VARCHAR(20) | public.etl_default_values (sales_part.sourcing_option_db) | Config | Options d'approvisionnement (_DB uniquement)
SQL : public.get_default_value('clean_data.sales_part', 'sourcing_option_db') as sourcing_option_db | NOTSUPPLIED |  |  |  |
| create_sm_object_option_db | VARCHAR(20) | public.etl_default_values (sales_part.create_sm_object_option_db) | Config | Options de création (_DB uniquement)
SQL : public.get_default_value('clean_data.sales_part', 'create_sm_object_option_db') as create_sm_object_option_db | DONOTCREATESMOBJECT |  |  |  |
| quick_registered_part_db | VARCHAR(20) | public.etl_default_values (sales_part.quick_registered_part_db) | Config | public.get_default_value('clean_data.sales_part', 'quick_registered_part_db') as quick_registered_part_db | FALSE |  |  |  |
| export_to_external_app_db | VARCHAR(20) | public.etl_default_values (sales_part.export_to_external_app_db) | Config | Exports et options avancées (_DB uniquement)
SQL : public.get_default_value('clean_data.sales_part', 'export_to_external_app_db') as export_to_external_app_db | FALSE |  |  |  |
| allow_inc_pkg_rsrv_picklst | VARCHAR(5) | public.etl_default_values (sales_part.allow_inc_pkg_rsrv_picklst) | Config | public.get_default_value('clean_data.sales_part', 'allow_inc_pkg_rsrv_picklst') as allow_inc_pkg_rsrv_picklst | TRUE |  |  |  |
| allow_incomp_pkg_delivery | VARCHAR(5) | public.etl_default_values (sales_part.allow_incomp_pkg_delivery) | Config | public.get_default_value('clean_data.sales_part', 'allow_incomp_pkg_delivery') as allow_incomp_pkg_delivery | TRUE |  |  |  |
| pack_comp_in_shpmnt | VARCHAR(5) | public.etl_default_values (sales_part.pack_comp_in_shpmnt) | Config | public.get_default_value('clean_data.sales_part', 'pack_comp_in_shpmnt') as pack_comp_in_shpmnt | FALSE |  |  |  |
| sales_type_db | VARCHAR(20) | public.etl_default_values (sales_part.sales_type_db) | Config | Type de vente (_DB uniquement)
SQL : public.get_default_value('clean_data.sales_part', 'sales_type_db') as sales_type_db | SALES |  |  |  |
| primary_catalog_db | VARCHAR(5) | public.etl_default_values (sales_part.primary_catalog_db) | Config | Article principal (_DB uniquement)
SQL : public.get_default_value('clean_data.sales_part', 'primary_catalog_db') as primary_catalog_db | TRUE |  |  |  |
| delivery_type | VARCHAR(20) | public.etl_default_values (sales_part.delivery_type) | Config | Infos diverses
SQL : public.get_default_value('clean_data.sales_part', 'delivery_type') as delivery_type |  |  |  |  |
| non_inv_part_type_db | VARCHAR(7) | raw_data.mara.mtart | SAP | CASE WHEN mara.mtart NOT IN ('FERT', 'HALB', 'ROH') THEN 'GOODS' ELSE NULL END as non_inv_part_type_db | GOODS |  |  |  |
| customs_stat_no | VARCHAR(15) | raw_data.mara.extwg | SAP | mara.extwg as customs_stat_no |  |  |  |  |
| country_of_origin | VARCHAR(2) | public.etl_default_values (sales_part.country_of_origin) | Config | public.get_default_value('clean_data.sales_part', 'country_of_origin') as country_of_origin | FR |  |  |  |
| statistical_code | VARCHAR(15) | public.etl_default_values (sales_part.statistical_code) | Config | public.get_default_value('clean_data.sales_part', 'statistical_code') as statistical_code |  |  |  |  |