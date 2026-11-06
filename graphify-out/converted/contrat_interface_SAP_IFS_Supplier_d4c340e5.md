<!-- converted from contrat_interface_SAP_IFS_Supplier.xlsx -->

## Sheet: Légende
| Contrat d'interface — Module Fournisseurs (SAP ECC 6.0 → IFS) |
| --- |
| Objet : documenter, pour chacune des 16 étapes du chargement fournisseurs (scripts 01 à 16), l'origine de chaque colonne cible et la règle de transformation appliquée, afin que le métier valide le mapping. Chaque onglet correspond à une table clean_data et au script qui l'alimente, dans l'ordre d'exécution. |
| Structure d'un onglet table |
| • Colonne cible : Nom de la colonne dans la table clean_data (cible finale). |
| • Type / Longueur : Type et longueur réels, lus directement dans la base clean_data. |
| • Champ / Table source : Table(s)/champ(s) source(s) (raw_data SAP, clean_data amont, ou constante). |
| • Système source : SAP, IFS (fichier de sélection fournisseurs), Config (etl_default_values), ou Technique. |
| • Règle de transformation / Condition : COALESCE, CASE, concaténation, valeur par défaut... Colonne clé à relire côté métier. |
| • Exemple de valeur : Une valeur réelle ou plausible. |
| • Validé métier (O/N) / Remarques métier / Date validation : Cellules en jaune, à remplir par le métier. |
| Les 16 étapes (dans l'ordre d'exécution) |
| 01. IFS_FOURNISSEURS — Table pilote : fichier de sélection métier (raw_data.selection_fournisseurs_stg) enrichi par SAP (LFA1/LFB1/LFM1/LFBK/TIBAN/BNKA). Attribue aussi le numéro de compte IFS (600001+). |
| 02. SUPPLIER_INFO_GENERAL — Identité générale du fournisseur. |
| 03. SUPPLIER_INFO_OUR_ID — Identifiant interne (OUR_ID) par société. |
| 04. SUPPLIER_INFO_ADDRESS — Adresse détaillée (SAP ADRC, repli sur ifs_fournisseurs). |
| 05. SUPPLIER_INFO_ADDRESS_TYPE — 4 lignes par adresse : DELIVERY / INVOICE / VISIT / PAY. |
| 06. COMM_METHOD — Moyens de communication : PHONE / FAX / E_MAIL (SAP ADR2/ADR3/ADR6). |
| 07. SUPPLIER_ADDRESS — Complément adresse (Intrastat, calendrier) dérivé de l'étape 04. |
| 08. SUPPLIER_DOCUMENT_TAX_INFO — Type de document fiscal par pays (SIRET/TVA...). |
| 09. SUPPLIER — Fiche fournisseur IFS principale (achats). |
| 10. IDENTITY_INVOICE_INFO — Paramètres de facturation. |
| 11. IDENTITY_PAY_INFO — Paramètres de paiement (blocages, tolérances). |
| 12. PAYMENT_WAY_PER_IDENTITY — Moyen de paiement par défaut. |
| 13. SUPPLIER_DELIVERY_TAX_CODE — Code fiscal de livraison. |
| 14. PAYMENT_ADDRESS — Coordonnées bancaires (adresse par défaut + IBAN/SWIFT réels). |
| 15. SUPPLIER_TAX_INFO — Paramètres fiscaux (ICMS Brésil, structure de taxe). |
| 16. SUPPLIER_ADDR_TAX_NUMBER — Numéros d'identification fiscale : TVA UE / SIREN / SIRET (0 à 3 lignes/fournisseur). |
| Points d'attention transverses repérés (à faire trancher par le métier) |
| ⚠ 04 — SUPPLIER_INFO_ADDRESS.address (VARCHAR 35) est une concaténation rue+n°+ville+CP tronquée à 35 caractères : risque de perte d'information sur les adresses longues. |
| ⚠ 07 — SUPPLIER_ADDRESS.delivery_terms / ship_via_code / route_id sont explicitement marqués TODO dans le script source (non enrichis depuis LFM1/transcodification). |
| ⚠ 08 — SUPPLIER_DOCUMENT_TAX_INFO.vat_no utilise un placeholder 'NO_VAT_<id>' quand la TVA est absente, au lieu de NULL. |
| ⚠ 10 — IDENTITY_INVOICE_INFO.fiscal_no (VARCHAR 16) tronque le n° de TVA : le script signale déjà que 3 fournisseurs (1 FR, 2 CN) perdent des caractères. |
| ⚠ 16 — SUPPLIER_ADDR_TAX_NUMBER.default_tax_id_number (sans suffixe _db) n'est jamais alimentée : convention du dépôt (seule la colonne _db est renseignée sur les couples <col>/<col>_db). |
| Onglet 00_VALEURS_PAR_DEFAUT |
| Liste exhaustive (251 lignes) des valeurs actuellement enregistrées dans public.etl_default_values pour les 16 tables du module fournisseurs — celles que les scripts appellent via public.get_default_value(). Regroupée par onglet/table puis par colonne. Les lignes grisées correspondent à des variantes inactives (is_active = FALSE, non utilisées par le chargement actuel). Complète les lignes 'Config' résumées dans chaque onglet table : c'est ici que la VALEUR réelle de chaque paramètre est visible et modifiable (Configuration > Valeurs par défaut dans l'outil). |
## Sheet: 00_VALEURS_PAR_DEFAUT
| Onglet | Table cible (etl_default_values.table_cible) | Colonne | Variante | Type valeur | Valeur actuelle | Actif | Module | Description | Remarque métier |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 01_IFS_FOURNISSEURS  —  clean_data.ifs_fournisseurs |  |  |  |  |  |  |  |  |  |
| 01_IFS_FOURNISSEURS | clean_data.ifs_fournisseurs | address_id | STANDARD | CONSTANTE | 01 | Oui | supplier | Source : 01_alimenter_ifs_fournisseurs.sql (type CONSTANTE_FORCEE) |  |
| 01_IFS_FOURNISSEURS | clean_data.ifs_fournisseurs | company | STANDARD | CONSTANTE | TRIMET | Oui | supplier | Source : 01_alimenter_ifs_fournisseurs.sql (type CONSTANTE_FORCEE) |  |
| 02_SUPPLIER_INFO_GENERAL  —  clean_data.supplier_info_general |  |  |  |  |  |  |  |  |  |
| 02_SUPPLIER_INFO_GENERAL | clean_data.supplier_info_general | b2b_supplier | STANDARD | CONSTANTE | (NULL) | Oui | supplier | Source : 02_alimenter_supplier_info_general.sql (type CONSTANTE_FORCEE) |  |
| 02_SUPPLIER_INFO_GENERAL | clean_data.supplier_info_general | b2b_supplier_db | STANDARD | CONSTANTE | FALSE | Oui | supplier | Source : 02_alimenter_supplier_info_general.sql (type CONSTANTE_FORCEE) |  |
| 02_SUPPLIER_INFO_GENERAL | clean_data.supplier_info_general | business_classification | STANDARD | CONSTANTE |  | Oui | supplier | Source : 02_alimenter_supplier_info_general.sql (type NULL_EXPLICITE) |  |
| 02_SUPPLIER_INFO_GENERAL | clean_data.supplier_info_general | corporate_form | STANDARD | CONSTANTE |  | Oui | supplier | Source : 02_alimenter_supplier_info_general.sql (type NULL_EXPLICITE) |  |
| 02_SUPPLIER_INFO_GENERAL | clean_data.supplier_info_general | default_domain | STANDARD | CONSTANTE | FALSE | Oui | supplier | Source : 02_alimenter_supplier_info_general.sql (type CONSTANTE_FORCEE) |  |
| 02_SUPPLIER_INFO_GENERAL | clean_data.supplier_info_general | default_language | STANDARD | CONSTANTE | (NULL) | Oui | supplier | Source : 02_alimenter_supplier_info_general.sql (type CONSTANTE_FORCEE) |  |
| 02_SUPPLIER_INFO_GENERAL | clean_data.supplier_info_general | default_language_db | STANDARD | CONSTANTE | FR | Oui | supplier | Source : 02_alimenter_supplier_info_general.sql (type CONSTANTE_FORCEE) |  |
| 02_SUPPLIER_INFO_GENERAL | clean_data.supplier_info_general | identifier_ref_validation_db | STANDARD | CONSTANTE | NONE | Oui | supplier | Source : 02_alimenter_supplier_info_general.sql (type CONSTANTE_FORCEE) |  |
| 02_SUPPLIER_INFO_GENERAL | clean_data.supplier_info_general | one_time | STANDARD | CONSTANTE | (NULL) | Oui | supplier | Source : 02_alimenter_supplier_info_general.sql (type CONSTANTE_FORCEE) |  |
| 02_SUPPLIER_INFO_GENERAL | clean_data.supplier_info_general | one_time_db | STANDARD | CONSTANTE | FALSE | Oui | supplier | Source : 02_alimenter_supplier_info_general.sql (type CONSTANTE_FORCEE) |  |
| 02_SUPPLIER_INFO_GENERAL | clean_data.supplier_info_general | party | STANDARD | CONSTANTE |  | Oui | supplier | Source : 02_alimenter_supplier_info_general.sql (type NULL_EXPLICITE) |  |
| 02_SUPPLIER_INFO_GENERAL | clean_data.supplier_info_general | party_type | STANDARD | CONSTANTE | (NULL) | Oui | supplier | Source : 02_alimenter_supplier_info_general.sql (type CONSTANTE_FORCEE) |  |
| 02_SUPPLIER_INFO_GENERAL | clean_data.supplier_info_general | party_type_db | STANDARD | CONSTANTE | SUPPLIER | Oui | supplier | Source : 02_alimenter_supplier_info_general.sql (type CONSTANTE_FORCEE) |  |
| 02_SUPPLIER_INFO_GENERAL | clean_data.supplier_info_general | picture_id | STANDARD | CONSTANTE |  | Oui | supplier | Source : 02_alimenter_supplier_info_general.sql (type NULL_EXPLICITE) |  |
| 02_SUPPLIER_INFO_GENERAL | clean_data.supplier_info_general | supplier_category | STANDARD | CONSTANTE | (NULL) | Oui | supplier | Source : 02_alimenter_supplier_info_general.sql (type CONSTANTE_FORCEE) |  |
| 02_SUPPLIER_INFO_GENERAL | clean_data.supplier_info_general | supplier_category_db | STANDARD | CONSTANTE | SUPPLIER | Oui | supplier | Source : 02_alimenter_supplier_info_general.sql (type CONSTANTE_FORCEE) |  |
| 03_SUPPLIER_INFO_OUR_ID  —  clean_data.supplier_info_our_id |  |  |  |  |  |  |  |  |  |
| 03_SUPPLIER_INFO_OUR_ID | clean_data.supplier_info_our_id | our_id_prefix | STANDARD | CONSTANTE | TRIMET | Oui | supplier | Préfixe de OUR_ID (concaténé : <prefixe>-<numero_compte_fournisseur>) |  |
| 04_SUPPLIER_INFO_ADDRESS  —  clean_data.supplier_info_address |  |  |  |  |  |  |  |  |  |
| 04_SUPPLIER_INFO_ADDRESS | clean_data.supplier_info_address | address_id | STANDARD | CONSTANTE | 01 | Oui | supplier | Source : 04_alimenter_supplier_info_address.sql (type CONSTANTE_FORCEE) |  |
| 04_SUPPLIER_INFO_ADDRESS | clean_data.supplier_info_address | comm_id | STANDARD | CONSTANTE | (NULL) | Non | supplier | Source : 04_alimenter_supplier_info_address.sql (type NULL_EXPLICITE) |  |
| 04_SUPPLIER_INFO_ADDRESS | clean_data.supplier_info_address | default_domain | STANDARD | CONSTANTE | TRUE | Oui | supplier | Source : 04_alimenter_supplier_info_address.sql (type CONSTANTE_FORCEE) |  |
| 04_SUPPLIER_INFO_ADDRESS | clean_data.supplier_info_address | output_media | STANDARD | CONSTANTE | (NULL) | Oui | supplier | Source : 04_alimenter_supplier_info_address.sql (type CONSTANTE_FORCEE) |  |
| 04_SUPPLIER_INFO_ADDRESS | clean_data.supplier_info_address | output_media_db | STANDARD | CONSTANTE | 1 | Oui | supplier | Source : 04_alimenter_supplier_info_address.sql (type CONSTANTE_FORCEE) |  |
| 04_SUPPLIER_INFO_ADDRESS | clean_data.supplier_info_address | party_type | STANDARD | CONSTANTE | (NULL) | Oui | supplier | Source : 04_alimenter_supplier_info_address.sql (type CONSTANTE_FORCEE) |  |
| 04_SUPPLIER_INFO_ADDRESS | clean_data.supplier_info_address | party_type_db | STANDARD | CONSTANTE | SUPPLIER | Oui | supplier | Source : 04_alimenter_supplier_info_address.sql (type CONSTANTE_FORCEE) |  |
| 05_SUPPLIER_INFO_ADDRESS_TYPE  —  clean_data.supplier_info_address_type |  |  |  |  |  |  |  |  |  |
| 05_SUPPLIER_INFO_ADDRESS_TYPE | clean_data.supplier_info_address_type | address_type_code | DELIVERY | CONSTANTE | (NULL) | Oui | supplier | Source : 05_insert_supplier_address_types.sql (type CONSTANTE_FORCEE) |  |
| 05_SUPPLIER_INFO_ADDRESS_TYPE | clean_data.supplier_info_address_type | address_type_code | INVOICE | CONSTANTE | (NULL) | Oui | supplier | Source : 05_insert_supplier_address_types.sql (type CONSTANTE_FORCEE) |  |
| 05_SUPPLIER_INFO_ADDRESS_TYPE | clean_data.supplier_info_address_type | address_type_code | PAY | CONSTANTE | (NULL) | Oui | supplier | Source : 05_insert_supplier_address_types.sql (type CONSTANTE_FORCEE) |  |
| 05_SUPPLIER_INFO_ADDRESS_TYPE | clean_data.supplier_info_address_type | address_type_code | VISIT | CONSTANTE | (NULL) | Oui | supplier | Source : 05_insert_supplier_address_types.sql (type CONSTANTE_FORCEE) |  |
| 05_SUPPLIER_INFO_ADDRESS_TYPE | clean_data.supplier_info_address_type | address_type_code_db | DELIVERY | CONSTANTE | DELIVERY | Oui | supplier | Source : 05_insert_supplier_address_types.sql (type CONSTANTE_FORCEE) |  |
| 05_SUPPLIER_INFO_ADDRESS_TYPE | clean_data.supplier_info_address_type | address_type_code_db | INVOICE | CONSTANTE | INVOICE | Oui | supplier | Source : 05_insert_supplier_address_types.sql (type CONSTANTE_FORCEE) |  |
| 05_SUPPLIER_INFO_ADDRESS_TYPE | clean_data.supplier_info_address_type | address_type_code_db | PAY | CONSTANTE | PAY | Oui | supplier | Source : 05_insert_supplier_address_types.sql (type CONSTANTE_FORCEE) |  |
| 05_SUPPLIER_INFO_ADDRESS_TYPE | clean_data.supplier_info_address_type | address_type_code_db | VISIT | CONSTANTE | VISIT | Oui | supplier | Source : 05_insert_supplier_address_types.sql (type CONSTANTE_FORCEE) |  |
| 05_SUPPLIER_INFO_ADDRESS_TYPE | clean_data.supplier_info_address_type | def_address | DELIVERY | CONSTANTE | TRUE | Oui | supplier | Source : 05_insert_supplier_address_types.sql (type CONSTANTE_FORCEE) |  |
| 05_SUPPLIER_INFO_ADDRESS_TYPE | clean_data.supplier_info_address_type | def_address | INVOICE | CONSTANTE | TRUE | Oui | supplier | Source : 05_insert_supplier_address_types.sql (type CONSTANTE_FORCEE) |  |
| 05_SUPPLIER_INFO_ADDRESS_TYPE | clean_data.supplier_info_address_type | def_address | PAY | CONSTANTE | TRUE | Oui | supplier | Source : 05_insert_supplier_address_types.sql (type CONSTANTE_FORCEE) |  |
| 05_SUPPLIER_INFO_ADDRESS_TYPE | clean_data.supplier_info_address_type | def_address | VISIT | CONSTANTE | TRUE | Oui | supplier | Source : 05_insert_supplier_address_types.sql (type CONSTANTE_FORCEE) |  |
| 05_SUPPLIER_INFO_ADDRESS_TYPE | clean_data.supplier_info_address_type | default_domain | DELIVERY | CONSTANTE | TRUE | Oui | supplier | Source : 05_insert_supplier_address_types.sql (type CONSTANTE_FORCEE) |  |
| 05_SUPPLIER_INFO_ADDRESS_TYPE | clean_data.supplier_info_address_type | default_domain | INVOICE | CONSTANTE | TRUE | Oui | supplier | Source : 05_insert_supplier_address_types.sql (type CONSTANTE_FORCEE) |  |
| 05_SUPPLIER_INFO_ADDRESS_TYPE | clean_data.supplier_info_address_type | default_domain | PAY | CONSTANTE | TRUE | Oui | supplier | Source : 05_insert_supplier_address_types.sql (type CONSTANTE_FORCEE) |  |
| 05_SUPPLIER_INFO_ADDRESS_TYPE | clean_data.supplier_info_address_type | default_domain | VISIT | CONSTANTE | TRUE | Oui | supplier | Source : 05_insert_supplier_address_types.sql (type CONSTANTE_FORCEE) |  |
| 05_SUPPLIER_INFO_ADDRESS_TYPE | clean_data.supplier_info_address_type | invoice | DELIVERY | CONSTANTE | FALSE | Oui | supplier | Source : 05_insert_supplier_address_types.sql (type CONSTANTE_FORCEE) |  |
| 05_SUPPLIER_INFO_ADDRESS_TYPE | clean_data.supplier_info_address_type | invoice | INVOICE | CONSTANTE | TRUE | Oui | supplier | Source : 05_insert_supplier_address_types.sql (type CONSTANTE_FORCEE) |  |
| 05_SUPPLIER_INFO_ADDRESS_TYPE | clean_data.supplier_info_address_type | invoice | PAY | CONSTANTE | FALSE | Oui | supplier | Source : 05_insert_supplier_address_types.sql (type CONSTANTE_FORCEE) |  |
| 05_SUPPLIER_INFO_ADDRESS_TYPE | clean_data.supplier_info_address_type | invoice | VISIT | CONSTANTE | FALSE | Oui | supplier | Source : 05_insert_supplier_address_types.sql (type CONSTANTE_FORCEE) |  |
| 05_SUPPLIER_INFO_ADDRESS_TYPE | clean_data.supplier_info_address_type | party | DELIVERY | CONSTANTE |  | Oui | supplier | Source : 05_insert_supplier_address_types.sql (type CONSTANTE_FORCEE) |  |
| 05_SUPPLIER_INFO_ADDRESS_TYPE | clean_data.supplier_info_address_type | party | INVOICE | CONSTANTE | FALSE | Oui | supplier | Source : 05_insert_supplier_address_types.sql (type CONSTANTE_FORCEE) |  |
| 05_SUPPLIER_INFO_ADDRESS_TYPE | clean_data.supplier_info_address_type | party | PAY | CONSTANTE | FALSE | Oui | supplier | Source : 05_insert_supplier_address_types.sql (type CONSTANTE_FORCEE) |  |
| 05_SUPPLIER_INFO_ADDRESS_TYPE | clean_data.supplier_info_address_type | party | VISIT | CONSTANTE | FALSE | Oui | supplier | Source : 05_insert_supplier_address_types.sql (type CONSTANTE_FORCEE) |  |
| 05_SUPPLIER_INFO_ADDRESS_TYPE | clean_data.supplier_info_address_type | pay | DELIVERY | CONSTANTE | FALSE | Oui | supplier | Source : 05_insert_supplier_address_types.sql (type CONSTANTE_FORCEE) |  |
| 05_SUPPLIER_INFO_ADDRESS_TYPE | clean_data.supplier_info_address_type | pay | INVOICE | CONSTANTE | FALSE | Oui | supplier | Source : 05_insert_supplier_address_types.sql (type CONSTANTE_FORCEE) |  |
| 05_SUPPLIER_INFO_ADDRESS_TYPE | clean_data.supplier_info_address_type | pay | PAY | CONSTANTE | TRUE | Oui | supplier | Source : 05_insert_supplier_address_types.sql (type CONSTANTE_FORCEE) |  |
| 05_SUPPLIER_INFO_ADDRESS_TYPE | clean_data.supplier_info_address_type | pay | VISIT | CONSTANTE | FALSE | Oui | supplier | Source : 05_insert_supplier_address_types.sql (type CONSTANTE_FORCEE) |  |
| 05_SUPPLIER_INFO_ADDRESS_TYPE | clean_data.supplier_info_address_type | visit | DELIVERY | CONSTANTE | FALSE | Oui | supplier | Source : 05_insert_supplier_address_types.sql (type CONSTANTE_FORCEE) |  |
| 05_SUPPLIER_INFO_ADDRESS_TYPE | clean_data.supplier_info_address_type | visit | INVOICE | CONSTANTE | FALSE | Oui | supplier | Source : 05_insert_supplier_address_types.sql (type CONSTANTE_FORCEE) |  |
| 05_SUPPLIER_INFO_ADDRESS_TYPE | clean_data.supplier_info_address_type | visit | PAY | CONSTANTE | FALSE | Oui | supplier | Source : 05_insert_supplier_address_types.sql (type CONSTANTE_FORCEE) |  |
| 05_SUPPLIER_INFO_ADDRESS_TYPE | clean_data.supplier_info_address_type | visit | VISIT | CONSTANTE | TRUE | Oui | supplier | Source : 05_insert_supplier_address_types.sql (type CONSTANTE_FORCEE) |  |
| 06_COMM_METHOD  —  clean_data.comm_method |  |  |  |  |  |  |  |  |  |
| 06_COMM_METHOD | clean_data.comm_method | address_default | FAX | CONSTANTE | FALSE | Oui | supplier | Source : 06_alimenter_comm_method.sql (type CONSTANTE_FORCEE) |  |
| 06_COMM_METHOD | clean_data.comm_method | address_default | PHONE | CONSTANTE | FALSE | Oui | supplier | Source : 06_alimenter_comm_method.sql (type CONSTANTE_FORCEE) |  |
| 06_COMM_METHOD | clean_data.comm_method | method_id | E_MAIL | CONSTANTE | (NULL) | Oui | supplier | Source : 06_alimenter_comm_method.sql (type CONSTANTE_FORCEE) |  |
| 06_COMM_METHOD | clean_data.comm_method | method_id | FAX | CONSTANTE | (NULL) | Oui | supplier | Source : 06_alimenter_comm_method.sql (type CONSTANTE_FORCEE) |  |
| 06_COMM_METHOD | clean_data.comm_method | method_id | PHONE | CONSTANTE | (NULL) | Oui | supplier | Source : 06_alimenter_comm_method.sql (type CONSTANTE_FORCEE) |  |
| 06_COMM_METHOD | clean_data.comm_method | method_id_db | E_MAIL | CONSTANTE | E_MAIL | Oui | supplier | Source : 06_alimenter_comm_method.sql (type CONSTANTE_FORCEE) |  |
| 06_COMM_METHOD | clean_data.comm_method | method_id_db | FAX | CONSTANTE | FAX | Oui | supplier | Source : 06_alimenter_comm_method.sql (type CONSTANTE_FORCEE) |  |
| 06_COMM_METHOD | clean_data.comm_method | method_id_db | PHONE | CONSTANTE | PHONE | Oui | supplier | Source : 06_alimenter_comm_method.sql (type CONSTANTE_FORCEE) |  |
| 06_COMM_METHOD | clean_data.comm_method | party_type | E_MAIL | CONSTANTE | (NULL) | Oui | supplier | Source : 06_alimenter_comm_method.sql (type CONSTANTE_FORCEE) |  |
| 06_COMM_METHOD | clean_data.comm_method | party_type | FAX | CONSTANTE | (NULL) | Oui | supplier | Source : 06_alimenter_comm_method.sql (type CONSTANTE_FORCEE) |  |
| 06_COMM_METHOD | clean_data.comm_method | party_type | PHONE | CONSTANTE | (NULL) | Oui | supplier | Source : 06_alimenter_comm_method.sql (type CONSTANTE_FORCEE) |  |
| 06_COMM_METHOD | clean_data.comm_method | party_type_db | E_MAIL | CONSTANTE | SUPPLIER | Oui | supplier | Source : 06_alimenter_comm_method.sql (type CONSTANTE_FORCEE) |  |
| 06_COMM_METHOD | clean_data.comm_method | party_type_db | FAX | CONSTANTE | SUPPLIER | Oui | supplier | Source : 06_alimenter_comm_method.sql (type CONSTANTE_FORCEE) |  |
| 06_COMM_METHOD | clean_data.comm_method | party_type_db | PHONE | CONSTANTE | SUPPLIER | Oui | supplier | Source : 06_alimenter_comm_method.sql (type CONSTANTE_FORCEE) |  |
| 06_COMM_METHOD | clean_data.comm_method | valid_to | E_MAIL | CONSTANTE | 2099-12-31 | Oui | supplier | Source : 06_alimenter_comm_method.sql (type CONSTANTE_FORCEE) |  |
| 06_COMM_METHOD | clean_data.comm_method | valid_to | FAX | CONSTANTE | 2099-12-31 | Oui | supplier | Source : 06_alimenter_comm_method.sql (type CONSTANTE_FORCEE) |  |
| 06_COMM_METHOD | clean_data.comm_method | valid_to | PHONE | CONSTANTE | 2099-12-31 | Oui | supplier | Source : 06_alimenter_comm_method.sql (type CONSTANTE_FORCEE) |  |
| 07_SUPPLIER_ADDRESS  —  clean_data.supplier_address |  |  |  |  |  |  |  |  |  |
| 07_SUPPLIER_ADDRESS | clean_data.supplier_address | delivery_terms | STANDARD | CONSTANTE | (NULL) | Non | supplier | Source : 07_alimenter_supplier_address.sql (type NULL_EXPLICITE) |  |
| 07_SUPPLIER_ADDRESS | clean_data.supplier_address | route_id | STANDARD | CONSTANTE | (NULL) | Non | supplier | Source : 07_alimenter_supplier_address.sql (type NULL_EXPLICITE) |  |
| 07_SUPPLIER_ADDRESS | clean_data.supplier_address | ship_via_code | STANDARD | CONSTANTE | (NULL) | Non | supplier | Source : 07_alimenter_supplier_address.sql (type NULL_EXPLICITE) |  |
| 08_SUPPLIER_DOCUMENT_TAX_INFO  —  clean_data.supplier_document_tax_info |  |  |  |  |  |  |  |  |  |
| 08_SUPPLIER_DOCUMENT_TAX_INFO | clean_data.supplier_document_tax_info | company | STANDARD | CONSTANTE | TRIMET | Oui | supplier | Source : 08_insert_supplier_document_tax_info.sql (type CONSTANTE_FORCEE) |  |
| 08_SUPPLIER_DOCUMENT_TAX_INFO | clean_data.supplier_document_tax_info | company_addr_tax_id_type | STANDARD | CONSTANTE | (NULL) | Oui | supplier | Source : 08_insert_supplier_document_tax_info.sql (type CONSTANTE_FORCEE) |  |
| 08_SUPPLIER_DOCUMENT_TAX_INFO | clean_data.supplier_document_tax_info | company_addr_tax_id_type_db | STANDARD | CONSTANTE | FALSE | Oui | supplier | Source : 08_insert_supplier_document_tax_info.sql (type CONSTANTE_FORCEE) |  |
| 08_SUPPLIER_DOCUMENT_TAX_INFO | clean_data.supplier_document_tax_info | reliability_status_db | STANDARD | CONSTANTE | NOT_SET | Oui | supplier | Source : 08_insert_supplier_document_tax_info.sql (type CONSTANTE_FORCEE) |  |
| 08_SUPPLIER_DOCUMENT_TAX_INFO | clean_data.supplier_document_tax_info | tax_office_id | STANDARD | CONSTANTE |  | Oui | supplier | Source : 08_insert_supplier_document_tax_info.sql (type CONSTANTE_FORCEE) |  |
| 09_SUPPLIER  —  clean_data.supplier |  |  |  |  |  |  |  |  |  |
| 09_SUPPLIER | clean_data.supplier | additional_cost_amount | STANDARD | CONSTANTE | 0 | Oui | supplier | Source : 09_sp_insert_supplier_from_sap.sql (type CONSTANTE_FORCEE) |  |
| 09_SUPPLIER | clean_data.supplier | adhoc_pur_rqst_approval_db | STANDARD | CONSTANTE | MANUALLY | Oui | supplier | Source : 09_sp_insert_supplier_from_sap.sql (type CONSTANTE_FORCEE) |  |
| 09_SUPPLIER | clean_data.supplier | b2b_conf_order_with_diff_db | STANDARD | CONSTANTE | FALSE | Oui | supplier | Source : 09_sp_insert_supplier_from_sap.sql (type CONSTANTE_FORCEE) |  |
| 09_SUPPLIER | clean_data.supplier | blanket_date_db | STANDARD | CONSTANTE | ORDERDATE | Oui | supplier | Source : 09_sp_insert_supplier_from_sap.sql (type CONSTANTE_FORCEE) |  |
| 09_SUPPLIER | clean_data.supplier | buyer_code | STANDARD | CONSTANTE | * | Oui | supplier | Source : 09_sp_insert_supplier_from_sap.sql (type CONSTANTE_FORCEE) |  |
| 09_SUPPLIER | clean_data.supplier | category_db | STANDARD | CONSTANTE | E | Oui | supplier | Source : 09_sp_insert_supplier_from_sap.sql (type CONSTANTE_FORCEE) |  |
| 09_SUPPLIER | clean_data.supplier | coc_approval_db | STANDARD | CONSTANTE | Y | Oui | supplier | Source : 09_sp_insert_supplier_from_sap.sql (type CONSTANTE_FORCEE) |  |
| 09_SUPPLIER | clean_data.supplier | cr_check_db | STANDARD | CONSTANTE | Y | Oui | supplier | Source : 09_sp_insert_supplier_from_sap.sql (type CONSTANTE_FORCEE) |  |
| 09_SUPPLIER | clean_data.supplier | create_confirmation_chg_ord_db | STANDARD | CONSTANTE | FALSE | Oui | supplier | Source : 09_sp_insert_supplier_from_sap.sql (type CONSTANTE_FORCEE) |  |
| 09_SUPPLIER | clean_data.supplier | currency_code | STANDARD | CONSTANTE | EUR | Oui | supplier | Devise du fournisseur. Source : 09_sp_insert_supplier_from_sap.sql (remplace COALESCE(f.devise_principale, 'EUR')) |  |
| 09_SUPPLIER | clean_data.supplier | days_before_arrival | STANDARD | CONSTANTE | 30 | Oui | supplier | Delai avant arrivee en jours quand lfm1.plifz est absent (numerique) |  |
| 09_SUPPLIER | clean_data.supplier | days_before_delivery | STANDARD | CONSTANTE | 30 | Oui | supplier | Delai de livraison en jours quand lfm1.plifz est absent (numerique) |  |
| 09_SUPPLIER | clean_data.supplier | delivery_rem_interval | STANDARD | CONSTANTE | 3 | Oui | supplier | Source : 09_sp_insert_supplier_from_sap.sql (type CONSTANTE_FORCEE) |  |
| 09_SUPPLIER | clean_data.supplier | delivery_reminder_db | STANDARD | CONSTANTE | DELIVREM | Oui | supplier | Source : 09_sp_insert_supplier_from_sap.sql (type CONSTANTE_FORCEE) |  |
| 09_SUPPLIER | clean_data.supplier | dir_del_approval_db | STANDARD | CONSTANTE | AUTOMATICALLY | Oui | supplier | Source : 09_sp_insert_supplier_from_sap.sql (type CONSTANTE_FORCEE) |  |
| 09_SUPPLIER | clean_data.supplier | discount | STANDARD | CONSTANTE | 0 | Oui | supplier | Source : 09_sp_insert_supplier_from_sap.sql (type CONSTANTE_FORCEE) |  |
| 09_SUPPLIER | clean_data.supplier | email_purchase_order_db | STANDARD | CONSTANTE | TRUE | Oui | supplier | Source : 09_sp_insert_supplier_from_sap.sql (type CONSTANTE_FORCEE) |  |
| 09_SUPPLIER | clean_data.supplier | environmental_approval_db | STANDARD | CONSTANTE | APPROVED | Oui | supplier | Source : 09_sp_insert_supplier_from_sap.sql (type CONSTANTE_FORCEE) |  |
| 09_SUPPLIER | clean_data.supplier | express_order_allowed_db | STANDARD | CONSTANTE | 1 | Oui | supplier | Source : 09_sp_insert_supplier_from_sap.sql (type CONSTANTE_FORCEE) |  |
| 09_SUPPLIER | clean_data.supplier | ord_conf_rem_interval | STANDARD | CONSTANTE | 7 | Oui | supplier | Source : 09_sp_insert_supplier_from_sap.sql (type CONSTANTE_FORCEE) |  |
| 09_SUPPLIER | clean_data.supplier | ord_conf_reminder_db | STANDARD | CONSTANTE | CONFREM | Oui | supplier | Source : 09_sp_insert_supplier_from_sap.sql (type CONSTANTE_FORCEE) |  |
| 09_SUPPLIER | clean_data.supplier | order_conf_approval_db | STANDARD | CONSTANTE | AUTOMATICALLY | Oui | supplier | Source : 09_sp_insert_supplier_from_sap.sql (type CONSTANTE_FORCEE) |  |
| 09_SUPPLIER | clean_data.supplier | order_conf_diff_approval_db | STANDARD | CONSTANTE | MANUALLY | Oui | supplier | Source : 09_sp_insert_supplier_from_sap.sql (type CONSTANTE_FORCEE) |  |
| 09_SUPPLIER | clean_data.supplier | pack_list_flag_db | STANDARD | CONSTANTE | Y | Oui | supplier | Source : 09_sp_insert_supplier_from_sap.sql (type CONSTANTE_FORCEE) |  |
| 09_SUPPLIER | clean_data.supplier | po_change_management_db | STANDARD | CONSTANTE | USE_SITE_DEFAULT | Oui | supplier | Source : 09_sp_insert_supplier_from_sap.sql (type CONSTANTE_FORCEE) |  |
| 09_SUPPLIER | clean_data.supplier | pricat_automatic_approval_db | STANDARD | CONSTANTE | NOT_APPLICABLE | Oui | supplier | Source : 09_sp_insert_supplier_from_sap.sql (type CONSTANTE_FORCEE) |  |
| 09_SUPPLIER | clean_data.supplier | print_amounts_incl_tax_db | STANDARD | CONSTANTE | FALSE | Oui | supplier | Source : 09_sp_insert_supplier_from_sap.sql (type CONSTANTE_FORCEE) |  |
| 09_SUPPLIER | clean_data.supplier | purch_order_flag_db | STANDARD | CONSTANTE | Y | Oui | supplier | Source : 09_sp_insert_supplier_from_sap.sql (type CONSTANTE_FORCEE) |  |
| 09_SUPPLIER | clean_data.supplier | qc_approval_db | STANDARD | CONSTANTE | Y | Oui | supplier | Source : 09_sp_insert_supplier_from_sap.sql (type CONSTANTE_FORCEE) |  |
| 09_SUPPLIER | clean_data.supplier | quick_registered_supplier_db | STANDARD | CONSTANTE | ORDINARY | Oui | supplier | Source : 09_sp_insert_supplier_from_sap.sql (type CONSTANTE_FORCEE) |  |
| 09_SUPPLIER | clean_data.supplier | rec_adv_sb_consignment_db | STANDARD | CONSTANTE | FALSE | Oui | supplier | Source : 09_sp_insert_supplier_from_sap.sql (type CONSTANTE_FORCEE) |  |
| 09_SUPPLIER | clean_data.supplier | rec_adv_sb_mix_ownership_db | STANDARD | CONSTANTE | FALSE | Oui | supplier | Source : 09_sp_insert_supplier_from_sap.sql (type CONSTANTE_FORCEE) |  |
| 09_SUPPLIER | clean_data.supplier | rec_adv_self_billing_db | STANDARD | CONSTANTE | FALSE | Oui | supplier | Source : 09_sp_insert_supplier_from_sap.sql (type CONSTANTE_FORCEE) |  |
| 09_SUPPLIER | clean_data.supplier | receipt_ref_reminder_db | STANDARD | CONSTANTE | NO_RCPT_REMINDER | Oui | supplier | Source : 09_sp_insert_supplier_from_sap.sql (type CONSTANTE_FORCEE) |  |
| 09_SUPPLIER | clean_data.supplier | receiving_advice_type_db | STANDARD | CONSTANTE | USE_CUSTOMER_DEFAULT | Oui | supplier | Source : 09_sp_insert_supplier_from_sap.sql (type CONSTANTE_FORCEE) |  |
| 09_SUPPLIER | clean_data.supplier | supp_grp | STANDARD | CONSTANTE | DEFAULT | Oui | supplier | Source : 09_sp_insert_supplier_from_sap.sql (type CONSTANTE_FORCEE) |  |
| 09_SUPPLIER | clean_data.supplier | supplier_group | STANDARD | CONSTANTE | EXTERNAL | Oui | supplier | Source : 09_sp_insert_supplier_from_sap.sql (type CONSTANTE_FORCEE) |  |
| 09_SUPPLIER | clean_data.supplier | template_supplier_db | STANDARD | CONSTANTE | NOTEMPLATE | Oui | supplier | Source : 09_sp_insert_supplier_from_sap.sql (type CONSTANTE_FORCEE) |  |
| 10_IDENTITY_INVOICE_INFO  —  clean_data.identity_invoice_info |  |  |  |  |  |  |  |  |  |
| 10_IDENTITY_INVOICE_INFO | clean_data.identity_invoice_info | allow_quantity_diff | STANDARD | CONSTANTE | FALSE | Oui | supplier | Source : 10_sp_insert_identity_invoice_info_from_sap.sql (type CONSTANTE_FORCEE) |  |
| 10_IDENTITY_INVOICE_INFO | clean_data.identity_invoice_info | allow_tolerance | STANDARD | CONSTANTE | FALSE | Oui | supplier | Source : 10_sp_insert_identity_invoice_info_from_sap.sql (type CONSTANTE_FORCEE) |  |
| 10_IDENTITY_INVOICE_INFO | clean_data.identity_invoice_info | automatic_invoice | STANDARD | CONSTANTE | N | Oui | supplier | Source : 10_sp_insert_identity_invoice_info_from_sap.sql (type CONSTANTE_FORCEE) |  |
| 10_IDENTITY_INVOICE_INFO | clean_data.identity_invoice_info | automatic_pay_auth_flag | STANDARD | CONSTANTE | No | Oui | supplier |  |  |
| 10_IDENTITY_INVOICE_INFO | clean_data.identity_invoice_info | company | STANDARD | CONSTANTE | TRIMET | Oui | supplier | Code societe quand ifs_fournisseurs.company est NULL |  |
| 10_IDENTITY_INVOICE_INFO | clean_data.identity_invoice_info | country_tax_registered_db | STANDARD | CONSTANTE | FALSE | Oui | supplier |  |  |
| 10_IDENTITY_INVOICE_INFO | clean_data.identity_invoice_info | create_tolerance_posting | STANDARD | CONSTANTE | FALSE | Oui | supplier | Source : 10_sp_insert_identity_invoice_info_from_sap.sql (type CONSTANTE_FORCEE) |  |
| 10_IDENTITY_INVOICE_INFO | clean_data.identity_invoice_info | def_currency | STANDARD | CONSTANTE | EUR | Oui | supplier | Devise par defaut de facturation. Source : 10_sp_insert_identity_invoice_info_from_sap.sql (remplace COALESCE(f.devise_principale, 'EUR')) |  |
| 10_IDENTITY_INVOICE_INFO | clean_data.identity_invoice_info | digital_invoice | STANDARD | CONSTANTE | FALSE | Oui | supplier | Source : 10_sp_insert_identity_invoice_info_from_sap.sql (type CONSTANTE_FORCEE) |  |
| 10_IDENTITY_INVOICE_INFO | clean_data.identity_invoice_info | digital_invoice_db | STANDARD | CONSTANTE | FALSE | Oui | supplier |  |  |
| 10_IDENTITY_INVOICE_INFO | clean_data.identity_invoice_info | exc_from_spesometro_dec | STANDARD | CONSTANTE | FALSE | Oui | supplier | Source : 10_sp_insert_identity_invoice_info_from_sap.sql (type CONSTANTE_FORCEE) |  |
| 10_IDENTITY_INVOICE_INFO | clean_data.identity_invoice_info | exc_from_spesometro_dec_db | STANDARD | CONSTANTE | FALSE | Oui | supplier |  |  |
| 10_IDENTITY_INVOICE_INFO | clean_data.identity_invoice_info | exclude_invoice_image | STANDARD | CONSTANTE | FALSE | Oui | supplier | Source : 10_sp_insert_identity_invoice_info_from_sap.sql (type CONSTANTE_FORCEE) |  |
| 10_IDENTITY_INVOICE_INFO | clean_data.identity_invoice_info | exclude_invoice_image_db | STANDARD | CONSTANTE | FALSE | Oui | supplier |  |  |
| 10_IDENTITY_INVOICE_INFO | clean_data.identity_invoice_info | exclude_posting_auth | STANDARD | CONSTANTE | FALSE | Oui | supplier | Source : 10_sp_insert_identity_invoice_info_from_sap.sql (type CONSTANTE_FORCEE) |  |
| 10_IDENTITY_INVOICE_INFO | clean_data.identity_invoice_info | exclude_posting_auth_db | STANDARD | CONSTANTE | SPEC_ON_COMPANY | Oui | supplier |  |  |
| 10_IDENTITY_INVOICE_INFO | clean_data.identity_invoice_info | identity_type | STANDARD | CONSTANTE | FALSE | Oui | supplier | Source : 10_sp_insert_identity_invoice_info_from_sap.sql (type CONSTANTE_FORCEE) |  |
| 10_IDENTITY_INVOICE_INFO | clean_data.identity_invoice_info | inc_inv_curr_rate_base | STANDARD | CONSTANTE | FALSE | Oui | supplier | Source : 10_sp_insert_identity_invoice_info_from_sap.sql (type CONSTANTE_FORCEE) |  |
| 10_IDENTITY_INVOICE_INFO | clean_data.identity_invoice_info | inc_inv_curr_rate_base_db | STANDARD | CONSTANTE | SPEC_ON_COMPANY | Oui | supplier |  |  |
| 10_IDENTITY_INVOICE_INFO | clean_data.identity_invoice_info | invoice_fee | STANDARD | CONSTANTE | (NULL) | Non | supplier | Source : 10_sp_insert_identity_invoice_info_from_sap.sql (type NULL_EXPLICITE) |  |
| 10_IDENTITY_INVOICE_INFO | clean_data.identity_invoice_info | invoice_recipient_from | STANDARD | CONSTANTE | File | Oui | supplier | Source : 10_sp_insert_identity_invoice_info_from_sap.sql (type CONSTANTE_FORCEE) |  |
| 10_IDENTITY_INVOICE_INFO | clean_data.identity_invoice_info | legal_identity | STANDARD | CONSTANTE | FALSE | Oui | supplier | Source : 10_sp_insert_identity_invoice_info_from_sap.sql (type CONSTANTE_FORCEE) |  |
| 10_IDENTITY_INVOICE_INFO | clean_data.identity_invoice_info | legal_identity_db | STANDARD | CONSTANTE | FALSE | Oui | supplier |  |  |
| 10_IDENTITY_INVOICE_INFO | clean_data.identity_invoice_info | matching_level | STANDARD | CONSTANTE | PO Header | Oui | supplier | Source : 10_sp_insert_identity_invoice_info_from_sap.sql (type CONSTANTE_FORCEE) |  |
| 10_IDENTITY_INVOICE_INFO | clean_data.identity_invoice_info | ncf_reference_check | STANDARD | CONSTANTE | FALSE | Oui | supplier | Source : 10_sp_insert_identity_invoice_info_from_sap.sql (type CONSTANTE_FORCEE) |  |
| 10_IDENTITY_INVOICE_INFO | clean_data.identity_invoice_info | party_type | STANDARD | CONSTANTE | (NULL) | Oui | supplier | Source : 10_sp_insert_identity_invoice_info_from_sap.sql (type CONSTANTE_FORCEE) |  |
| 10_IDENTITY_INVOICE_INFO | clean_data.identity_invoice_info | party_type_db | STANDARD | CONSTANTE | SUPPLIER | Oui | supplier | Source : 10_sp_insert_identity_invoice_info_from_sap.sql (type CONSTANTE_FORCEE) |  |
| 10_IDENTITY_INVOICE_INFO | clean_data.identity_invoice_info | po_ref_rec_ref_val_method | STANDARD | CONSTANTE | PO Reference and Receipt Reference | Oui | supplier | Source : 10_sp_insert_identity_invoice_info_from_sap.sql (type CONSTANTE_FORCEE) |  |
| 10_IDENTITY_INVOICE_INFO | clean_data.identity_invoice_info | print_tax_code_text | STANDARD | CONSTANTE | FALSE | Oui | supplier | Source : 10_sp_insert_identity_invoice_info_from_sap.sql (type CONSTANTE_FORCEE) |  |
| 10_IDENTITY_INVOICE_INFO | clean_data.identity_invoice_info | report_and_withhold | STANDARD | CONSTANTE | FALSE | Oui | supplier | Source : 10_sp_insert_identity_invoice_info_from_sap.sql (type CONSTANTE_FORCEE) |  |
| 10_IDENTITY_INVOICE_INFO | clean_data.identity_invoice_info | second_tin | STANDARD | CONSTANTE | FALSE | Oui | supplier | Source : 10_sp_insert_identity_invoice_info_from_sap.sql (type CONSTANTE_FORCEE) |  |
| 10_IDENTITY_INVOICE_INFO | clean_data.identity_invoice_info | service_code_required | STANDARD | CONSTANTE | FALSE | Oui | supplier | Source : 10_sp_insert_identity_invoice_info_from_sap.sql (type CONSTANTE_FORCEE) |  |
| 10_IDENTITY_INVOICE_INFO | clean_data.identity_invoice_info | service_code_required_db | STANDARD | CONSTANTE | FALSE | Oui | supplier |  |  |
| 10_IDENTITY_INVOICE_INFO | clean_data.identity_invoice_info | tax_buy_curr_rate_base | STANDARD | CONSTANTE | FALSE | Oui | supplier | Source : 10_sp_insert_identity_invoice_info_from_sap.sql (type CONSTANTE_FORCEE) |  |
| 10_IDENTITY_INVOICE_INFO | clean_data.identity_invoice_info | tax_buy_curr_rate_base_db | STANDARD | CONSTANTE | SPEC_ON_COMPANY | Oui | supplier |  |  |
| 10_IDENTITY_INVOICE_INFO | clean_data.identity_invoice_info | tax_certificate_form | STANDARD | CONSTANTE | Not Used | Oui | supplier | Source : 10_sp_insert_identity_invoice_info_from_sap.sql (type CONSTANTE_FORCEE) |  |
| 10_IDENTITY_INVOICE_INFO | clean_data.identity_invoice_info | tax_exempt | STANDARD | CONSTANTE | FALSE | Oui | supplier | Source : 10_sp_insert_identity_invoice_info_from_sap.sql (type CONSTANTE_FORCEE) |  |
| 10_IDENTITY_INVOICE_INFO | clean_data.identity_invoice_info | tax_liability | STANDARD | CONSTANTE | TAX | Oui | supplier |  |  |
| 10_IDENTITY_INVOICE_INFO | clean_data.identity_invoice_info | utility_bill_provider | STANDARD | CONSTANTE | FALSE | Oui | supplier | Source : 10_sp_insert_identity_invoice_info_from_sap.sql (type CONSTANTE_FORCEE) |  |
| 10_IDENTITY_INVOICE_INFO | clean_data.identity_invoice_info | utility_bill_provider_db | STANDARD | CONSTANTE | FALSE | Oui | supplier |  |  |
| 10_IDENTITY_INVOICE_INFO | clean_data.identity_invoice_info | voting_share_percentage | STANDARD | CONSTANTE |  | Oui | supplier | Source : 10_sp_insert_identity_invoice_info_from_sap.sql (type CONSTANTE_FORCEE) |  |
| 10_IDENTITY_INVOICE_INFO | clean_data.identity_invoice_info | voting_share_percentage_db | STANDARD | CONSTANTE | NONE | Oui | supplier |  |  |
| 10_IDENTITY_INVOICE_INFO | clean_data.identity_invoice_info | withholding_base_amount | STANDARD | CONSTANTE | Invoice Net Amount | Oui | supplier | Source : 10_sp_insert_identity_invoice_info_from_sap.sql (type CONSTANTE_FORCEE) |  |
| 11_IDENTITY_PAY_INFO  —  clean_data.identity_pay_info |  |  |  |  |  |  |  |  |  |
| 11_IDENTITY_PAY_INFO | clean_data.identity_pay_info | amount_tolerance | STANDARD | CONSTANTE | 100 | Oui | supplier | Tolerance de montant quand lfm1.minbw est absent (numerique) |  |
| 11_IDENTITY_PAY_INFO | clean_data.identity_pay_info | ar_contact | STANDARD | CONSTANTE | (NULL) | Non | supplier | Source : 11_sp_insert_identity_pay_info_from_sap.sql (type NULL_EXPLICITE) |  |
| 11_IDENTITY_PAY_INFO | clean_data.identity_pay_info | business_category | STANDARD | CONSTANTE | SUPPLIER | Oui | supplier | Source : 11_sp_insert_identity_pay_info_from_sap.sql (type CONSTANTE_FORCEE) |  |
| 11_IDENTITY_PAY_INFO | clean_data.identity_pay_info | check_recipient | STANDARD | CONSTANTE | (NULL) | Oui | supplier | Source : 11_sp_insert_identity_pay_info_from_sap.sql (type CONSTANTE_FORCEE) |  |
| 11_IDENTITY_PAY_INFO | clean_data.identity_pay_info | check_recipient_db | STANDARD | CONSTANTE | PAYEE | Oui | supplier | Source : 11_sp_insert_identity_pay_info_from_sap.sql (type CONSTANTE_FORCEE) |  |
| 11_IDENTITY_PAY_INFO | clean_data.identity_pay_info | comm_id | STANDARD | CONSTANTE | 0 | Oui | supplier | Source : 11_sp_insert_identity_pay_info_from_sap.sql (type CONSTANTE_FORCEE) |  |
| 11_IDENTITY_PAY_INFO | clean_data.identity_pay_info | company | STANDARD | CONSTANTE | TRIMET | Oui | supplier | Code societe quand ifs_fournisseurs.company est NULL |  |
| 11_IDENTITY_PAY_INFO | clean_data.identity_pay_info | corporation_id | STANDARD | CONSTANTE | (NULL) | Non | supplier | Source : 11_sp_insert_identity_pay_info_from_sap.sql (type NULL_EXPLICITE) |  |
| 11_IDENTITY_PAY_INFO | clean_data.identity_pay_info | customer_id | STANDARD | CONSTANTE | (NULL) | Non | supplier | Source : 11_sp_insert_identity_pay_info_from_sap.sql (type NULL_EXPLICITE) |  |
| 11_IDENTITY_PAY_INFO | clean_data.identity_pay_info | deduction_group | STANDARD | CONSTANTE |  | Oui | supplier | Source : 11_sp_insert_identity_pay_info_from_sap.sql (type NULL_EXPLICITE) |  |
| 11_IDENTITY_PAY_INFO | clean_data.identity_pay_info | default_payment_method | STANDARD | CONSTANTE | FALSE | Oui | supplier | Source : 11_sp_insert_identity_pay_info_from_sap.sql (type CONSTANTE_FORCEE) |  |
| 11_IDENTITY_PAY_INFO | clean_data.identity_pay_info | disc_days_tolerance | STANDARD | CONSTANTE | 3 | Oui | supplier | Source : 11_sp_insert_identity_pay_info_from_sap.sql (type CONSTANTE_FORCEE) |  |
| 11_IDENTITY_PAY_INFO | clean_data.identity_pay_info | format_no | STANDARD | CONSTANTE | 1 | Oui | supplier | Source : 11_sp_insert_identity_pay_info_from_sap.sql (type CONSTANTE_FORCEE) |  |
| 11_IDENTITY_PAY_INFO | clean_data.identity_pay_info | interest_template | STANDARD | CONSTANTE | 1 | Oui | supplier | Source : 11_sp_insert_identity_pay_info_from_sap.sql (type CONSTANTE_FORCEE) |  |
| 11_IDENTITY_PAY_INFO | clean_data.identity_pay_info | is_one_inv_per_pay | STANDARD | CONSTANTE | (NULL) | Oui | supplier | Source : 11_sp_insert_identity_pay_info_from_sap.sql (type CONSTANTE_FORCEE) |  |
| 11_IDENTITY_PAY_INFO | clean_data.identity_pay_info | is_one_inv_per_pay_db | STANDARD | CONSTANTE | FALSE | Oui | supplier | Source : 11_sp_insert_identity_pay_info_from_sap.sql (type CONSTANTE_FORCEE) |  |
| 11_IDENTITY_PAY_INFO | clean_data.identity_pay_info | member_id | STANDARD | CONSTANTE | (NULL) | Non | supplier | Source : 11_sp_insert_identity_pay_info_from_sap.sql (type NULL_EXPLICITE) |  |
| 11_IDENTITY_PAY_INFO | clean_data.identity_pay_info | netting_allowed | STANDARD | CONSTANTE | FALSE | Oui | supplier | Source : 11_sp_insert_identity_pay_info_from_sap.sql (type CONSTANTE_FORCEE) |  |
| 11_IDENTITY_PAY_INFO | clean_data.identity_pay_info | next_payment_matching_id | STANDARD | CONSTANTE | 0 | Oui | supplier | Source : 11_sp_insert_identity_pay_info_from_sap.sql (type CONSTANTE_FORCEE) |  |
| 11_IDENTITY_PAY_INFO | clean_data.identity_pay_info | other_payee_identity | STANDARD | CONSTANTE | (NULL) | Non | supplier | Source : 11_sp_insert_identity_pay_info_from_sap.sql (type NULL_EXPLICITE) |  |
| 11_IDENTITY_PAY_INFO | clean_data.identity_pay_info | output_media | STANDARD | CONSTANTE | (NULL) | Oui | supplier | Source : 11_sp_insert_identity_pay_info_from_sap.sql (type CONSTANTE_FORCEE) |  |
| 11_IDENTITY_PAY_INFO | clean_data.identity_pay_info | output_media_db | STANDARD | CONSTANTE | 1 | Oui | supplier | Source : 11_sp_insert_identity_pay_info_from_sap.sql (type CONSTANTE_FORCEE) |  |
| 11_IDENTITY_PAY_INFO | clean_data.identity_pay_info | party_type | STANDARD | CONSTANTE | (NULL) | Oui | supplier | Source : 11_sp_insert_identity_pay_info_from_sap.sql (type CONSTANTE_FORCEE) |  |
| 11_IDENTITY_PAY_INFO | clean_data.identity_pay_info | party_type_db | STANDARD | CONSTANTE | SUPPLIER | Oui | supplier | Source : 11_sp_insert_identity_pay_info_from_sap.sql (type CONSTANTE_FORCEE) |  |
| 11_IDENTITY_PAY_INFO | clean_data.identity_pay_info | payment_advice | STANDARD | CONSTANTE | (NULL) | Oui | supplier | Source : 11_sp_insert_identity_pay_info_from_sap.sql (type CONSTANTE_FORCEE) |  |
| 11_IDENTITY_PAY_INFO | clean_data.identity_pay_info | payment_advice_db | STANDARD | CONSTANTE | 1 | Oui | supplier | Source : 11_sp_insert_identity_pay_info_from_sap.sql (type CONSTANTE_FORCEE) |  |
| 11_IDENTITY_PAY_INFO | clean_data.identity_pay_info | payment_delay | STANDARD | CONSTANTE | 30 | Oui | supplier | Delai de paiement en jours quand lfm1.plifz est absent (numerique) |  |
| 11_IDENTITY_PAY_INFO | clean_data.identity_pay_info | payment_mode | STANDARD | CONSTANTE | (NULL) | Oui | supplier | Source : 11_sp_insert_identity_pay_info_from_sap.sql (type CONSTANTE_FORCEE) |  |
| 11_IDENTITY_PAY_INFO | clean_data.identity_pay_info | payment_mode_db | STANDARD | CONSTANTE | 18 | Oui | supplier | Source : 11_sp_insert_identity_pay_info_from_sap.sql (type CONSTANTE_FORCEE) |  |
| 11_IDENTITY_PAY_INFO | clean_data.identity_pay_info | payment_receipt_type | STANDARD | CONSTANTE | (NULL) | Oui | supplier | Source : 11_sp_insert_identity_pay_info_from_sap.sql (type CONSTANTE_FORCEE) |  |
| 11_IDENTITY_PAY_INFO | clean_data.identity_pay_info | payment_receipt_type_db | STANDARD | CONSTANTE | NO_RECEIPT | Oui | supplier | Source : 11_sp_insert_identity_pay_info_from_sap.sql (type CONSTANTE_FORCEE) |  |
| 11_IDENTITY_PAY_INFO | clean_data.identity_pay_info | percent_tolerance | STANDARD | CONSTANTE | 5 | Oui | supplier | Source : 11_sp_insert_identity_pay_info_from_sap.sql (type CONSTANTE_FORCEE) |  |
| 11_IDENTITY_PAY_INFO | clean_data.identity_pay_info | predicted_payment_delay | STANDARD | CONSTANTE | (NULL) | Oui | supplier | Source : 11_sp_insert_identity_pay_info_from_sap.sql (type CONSTANTE_FORCEE) |  |
| 11_IDENTITY_PAY_INFO | clean_data.identity_pay_info | predicted_payment_delay_db | STANDARD | CONSTANTE | FALSE | Oui | supplier | Source : 11_sp_insert_identity_pay_info_from_sap.sql (type CONSTANTE_FORCEE) |  |
| 11_IDENTITY_PAY_INFO | clean_data.identity_pay_info | priority | STANDARD | CONSTANTE | 1 | Oui | supplier | Source : 11_sp_insert_identity_pay_info_from_sap.sql (type CONSTANTE_FORCEE) |  |
| 11_IDENTITY_PAY_INFO | clean_data.identity_pay_info | reminder_template | STANDARD | CONSTANTE | DEFAULT | Oui | supplier | Source : 11_sp_insert_identity_pay_info_from_sap.sql (type CONSTANTE_FORCEE) |  |
| 11_IDENTITY_PAY_INFO | clean_data.identity_pay_info | rule_id | STANDARD | CONSTANTE | (NULL) | Non | supplier | Source : 11_sp_insert_identity_pay_info_from_sap.sql (type NULL_EXPLICITE) |  |
| 11_IDENTITY_PAY_INFO | clean_data.identity_pay_info | send_interest_inv_to_payer | STANDARD | CONSTANTE | FALSE | Oui | supplier | Source : 11_sp_insert_identity_pay_info_from_sap.sql (type CONSTANTE_FORCEE) |  |
| 11_IDENTITY_PAY_INFO | clean_data.identity_pay_info | send_reminder_to_payer | STANDARD | CONSTANTE | FALSE | Oui | supplier | Source : 11_sp_insert_identity_pay_info_from_sap.sql (type CONSTANTE_FORCEE) |  |
| 11_IDENTITY_PAY_INFO | clean_data.identity_pay_info | send_stmt_of_acc_to_payer | STANDARD | CONSTANTE | FALSE | Oui | supplier | Source : 11_sp_insert_identity_pay_info_from_sap.sql (type CONSTANTE_FORCEE) |  |
| 11_IDENTITY_PAY_INFO | clean_data.identity_pay_info | template_id | STANDARD | CONSTANTE | (NULL) | Non | supplier | Source : 11_sp_insert_identity_pay_info_from_sap.sql (type NULL_EXPLICITE) |  |
| 12_PAYMENT_WAY_PER_IDENTITY  —  clean_data.payment_way_per_identity |  |  |  |  |  |  |  |  |  |
| 12_PAYMENT_WAY_PER_IDENTITY | clean_data.payment_way_per_identity | company | STANDARD | CONSTANTE | TRIMET | Oui | customer | Source : sp_insert_payment_way_per_identity_from_sap.sql (+ modules customerFile, customer_phl) |  |
| 12_PAYMENT_WAY_PER_IDENTITY | clean_data.payment_way_per_identity | default_payment_way | STANDARD | CONSTANTE | TRUE | Oui | supplier | Source : 12_fn_upsert_payment_way_per_identity.sql (type CONSTANTE_FORCEE) |  |
| 12_PAYMENT_WAY_PER_IDENTITY | clean_data.payment_way_per_identity | party_type | CUSTOMER | CONSTANTE | (NULL) | Oui | customer | Source : pipelines customer (STANDARD occupé par supplier=Supplier) |  |
| 12_PAYMENT_WAY_PER_IDENTITY | clean_data.payment_way_per_identity | party_type | CUSTOMERFILE | CONSTANTE | (NULL) | Oui | customerFile | Source : sp_insert_payment_way_per_identity_from_file_customer.sql (STANDARD occupe par supplier=Supplier) |  |
| 12_PAYMENT_WAY_PER_IDENTITY | clean_data.payment_way_per_identity | party_type | CUSTOMER_PHL | CONSTANTE | (NULL) | Oui | customer_phl | Source : sp_insert_payment_way_per_identity_from_client_phl.sql (STANDARD occupe par supplier=Supplier) |  |
| 12_PAYMENT_WAY_PER_IDENTITY | clean_data.payment_way_per_identity | party_type | STANDARD | CONSTANTE | (NULL) | Oui | supplier | Source : 12_fn_upsert_payment_way_per_identity.sql (type CONSTANTE_FORCEE) |  |
| 12_PAYMENT_WAY_PER_IDENTITY | clean_data.payment_way_per_identity | party_type_db | CUSTOMER | CONSTANTE | CUSTOMER | Oui | customer | Source : pipelines customer (STANDARD occupé par supplier=SUPPLIER) |  |
| 12_PAYMENT_WAY_PER_IDENTITY | clean_data.payment_way_per_identity | party_type_db | CUSTOMERFILE | CONSTANTE | CUSTOMER | Oui | customerFile | Source : sp_insert_payment_way_per_identity_from_file_customer.sql (STANDARD occupe par supplier=SUPPLIER) |  |
| 12_PAYMENT_WAY_PER_IDENTITY | clean_data.payment_way_per_identity | party_type_db | CUSTOMER_PHL | CONSTANTE | CUSTOMER | Oui | customer_phl | Source : sp_insert_payment_way_per_identity_from_client_phl.sql (STANDARD occupe par supplier=SUPPLIER) |  |
| 12_PAYMENT_WAY_PER_IDENTITY | clean_data.payment_way_per_identity | party_type_db | STANDARD | CONSTANTE | SUPPLIER | Oui | supplier | Source : 12_fn_upsert_payment_way_per_identity.sql (type CONSTANTE_FORCEE) |  |
| 12_PAYMENT_WAY_PER_IDENTITY | clean_data.payment_way_per_identity | valid_to | STANDARD | CONSTANTE | (NULL) | Non | customer | Source : sp_insert_payment_way_per_identity_from_sap.sql |  |
| 12_PAYMENT_WAY_PER_IDENTITY | clean_data.payment_way_per_identity | way_id | CUSTOMERFILE | CONSTANTE | BANK_TRANSFER | Oui | customerFile | Source : pipelines customer (STANDARD occupé par supplier=1) |  |
| 12_PAYMENT_WAY_PER_IDENTITY | clean_data.payment_way_per_identity | way_id | CUSTOMER_PHL | CONSTANTE | BANK_TRANSFER | Oui | customer_phl | Source : sp_insert_payment_way_per_identity_from_client_phl.sql (STANDARD occupe par supplier=1) |  |
| 12_PAYMENT_WAY_PER_IDENTITY | clean_data.payment_way_per_identity | way_id | STANDARD | CONSTANTE | 1 | Oui | supplier | Source : 12_fn_upsert_payment_way_per_identity.sql (type CONSTANTE_FORCEE) |  |
| 13_SUPPLIER_DELIVERY_TAX_CODE  —  clean_data.supplier_delivery_tax_code |  |  |  |  |  |  |  |  |  |
| 13_SUPPLIER_DELIVERY_TAX_CODE | clean_data.supplier_delivery_tax_code | address_id | STANDARD | CONSTANTE | DEFAULT_ADDR | Oui | supplier | Identifiant d'adresse quand le fournisseur n'a aucune supplier_info_address |  |
| 13_SUPPLIER_DELIVERY_TAX_CODE | clean_data.supplier_delivery_tax_code | company | STANDARD | CONSTANTE | TRIMET | Oui | supplier | Code societe quand ifs_fournisseurs.company est NULL |  |
| 14_PAYMENT_ADDRESS  —  clean_data.payment_address |  |  |  |  |  |  |  |  |  |
| 14_PAYMENT_ADDRESS | clean_data.payment_address | account | ADRESSE_DEFAUT | CONSTANTE | FR4530002021300000070521E23 | Non | supplier | Source : 14_fn_upsert_payment_address.sql (type NULL_EXPLICITE) |  |
| 14_PAYMENT_ADDRESS | clean_data.payment_address | bank_account_validated | ADRESSE_DEFAUT | CONSTANTE | (NULL) | Oui | supplier | Source : 14_fn_upsert_payment_address.sql (type CONSTANTE_FORCEE) |  |
| 14_PAYMENT_ADDRESS | clean_data.payment_address | bank_account_validated | BANQUE | CONSTANTE | (NULL) | Oui | supplier | Source : 14_fn_upsert_payment_address.sql (type CONSTANTE_FORCEE) |  |
| 14_PAYMENT_ADDRESS | clean_data.payment_address | bank_account_validated_db | ADRESSE_DEFAUT | CONSTANTE | FALSE | Oui | supplier | Source : 14_fn_upsert_payment_address.sql (type CONSTANTE_FORCEE) |  |
| 14_PAYMENT_ADDRESS | clean_data.payment_address | bank_account_validated_db | BANQUE | CONSTANTE | FALSE | Oui | supplier | Source : 14_fn_upsert_payment_address.sql (type CONSTANTE_FORCEE) |  |
| 14_PAYMENT_ADDRESS | clean_data.payment_address | bic_code | ADRESSE_DEFAUT | CONSTANTE | (NULL) | Non | supplier | Source : 14_fn_upsert_payment_address.sql (type NULL_EXPLICITE) |  |
| 14_PAYMENT_ADDRESS | clean_data.payment_address | blocked_for_use | ADRESSE_DEFAUT | CONSTANTE | FALSE | Oui | supplier | Source : 14_fn_upsert_payment_address.sql (type CONSTANTE_FORCEE) |  |
| 14_PAYMENT_ADDRESS | clean_data.payment_address | blocked_for_use | BANQUE | CONSTANTE | FALSE | Oui | supplier | Source : 14_fn_upsert_payment_address.sql (type CONSTANTE_FORCEE) |  |
| 14_PAYMENT_ADDRESS | clean_data.payment_address | company | ADRESSE_DEFAUT | CONSTANTE | TRIMET | Oui | supplier | Source : 14_fn_upsert_payment_address.sql (type CONSTANTE_FORCEE) |  |
| 14_PAYMENT_ADDRESS | clean_data.payment_address | company | BANQUE | CONSTANTE | TRIMET | Oui | supplier | Code societe des adresses de paiement bancaires (lfbk) |  |
| 14_PAYMENT_ADDRESS | clean_data.payment_address | default_address | ADRESSE_DEFAUT | CONSTANTE | TRUE | Oui | supplier | Source : 14_fn_upsert_payment_address.sql (type CONSTANTE_FORCEE) |  |
| 14_PAYMENT_ADDRESS | clean_data.payment_address | description | ADRESSE_DEFAUT | CONSTANTE | Adresse de paiement par défaut | Oui | supplier | Source : 14_fn_upsert_payment_address.sql (type CONSTANTE_FORCEE) |  |
| 14_PAYMENT_ADDRESS | clean_data.payment_address | mapping_type | ADRESSE_DEFAUT | CONSTANTE | DEFAULT | Oui | supplier | Source : 14_fn_upsert_payment_address.sql (type CONSTANTE_FORCEE) |  |
| 14_PAYMENT_ADDRESS | clean_data.payment_address | mapping_type | BANQUE | CONSTANTE | BANK_TRANSFER | Oui | supplier | Source : 14_fn_upsert_payment_address.sql (type CONSTANTE_FORCEE) |  |
| 14_PAYMENT_ADDRESS | clean_data.payment_address | party_type | ADRESSE_DEFAUT | CONSTANTE | (NULL) | Oui | supplier | Source : 14_fn_upsert_payment_address.sql (type CONSTANTE_FORCEE) |  |
| 14_PAYMENT_ADDRESS | clean_data.payment_address | party_type | BANQUE | CONSTANTE | (NULL) | Oui | supplier | Source : 14_fn_upsert_payment_address.sql (type CONSTANTE_FORCEE) |  |
| 14_PAYMENT_ADDRESS | clean_data.payment_address | party_type_db | ADRESSE_DEFAUT | CONSTANTE | SUPPLIER | Oui | supplier | Source : 14_fn_upsert_payment_address.sql (type CONSTANTE_FORCEE) |  |
| 14_PAYMENT_ADDRESS | clean_data.payment_address | party_type_db | BANQUE | CONSTANTE | SUPPLIER | Oui | supplier | Source : 14_fn_upsert_payment_address.sql (type CONSTANTE_FORCEE) |  |
| 14_PAYMENT_ADDRESS | clean_data.payment_address | way_id | ADRESSE_DEFAUT | CONSTANTE | SEPA | Oui | supplier | Source : 14_fn_upsert_payment_address.sql (type CONSTANTE_FORCEE) |  |
| 14_PAYMENT_ADDRESS | clean_data.payment_address | way_id | BANQUE | CONSTANTE | SEPA | Oui | supplier | Source : 14_fn_upsert_payment_address.sql (type CONSTANTE_FORCEE) |  |
| 15_SUPPLIER_TAX_INFO  —  clean_data.supplier_tax_info |  |  |  |  |  |  |  |  |  |
| 15_SUPPLIER_TAX_INFO | clean_data.supplier_tax_info | company | STANDARD | CONSTANTE | TRIMET | Oui | supplier | Code societe quand ifs_fournisseurs.company est NULL |  |
| 15_SUPPLIER_TAX_INFO | clean_data.supplier_tax_info | use_supp_address_for_tax | STANDARD | CONSTANTE | (NULL) | Oui | supplier | Source : 15_fn_upsert_supplier_tax_info.sql (type CONSTANTE_FORCEE) |  |
| 15_SUPPLIER_TAX_INFO | clean_data.supplier_tax_info | use_supp_address_for_tax_db | STANDARD | CONSTANTE | True | Oui | supplier | Source : 15_fn_upsert_supplier_tax_info.sql (type CONSTANTE_FORCEE) |  |
| 16_SUPPLIER_ADDR_TAX_NUMBER  —  clean_data.supplier_addr_tax_number |  |  |  |  |  |  |  |  |  |
| 16_SUPPLIER_ADDR_TAX_NUMBER | clean_data.supplier_addr_tax_number | company | STANDARD | CONSTANTE | TRIMET | Oui | supplier | Code societe |  |
| 16_SUPPLIER_ADDR_TAX_NUMBER | clean_data.supplier_addr_tax_number | default_tax_id_number_db | SIREN | CONSTANTE | FALSE | Oui | supplier | Le SIREN n'est pas le numero fiscal par defaut |  |
| 16_SUPPLIER_ADDR_TAX_NUMBER | clean_data.supplier_addr_tax_number | default_tax_id_number_db | SIRET | CONSTANTE | FALSE | Oui | supplier | Le SIRET n'est pas le numero fiscal par defaut |  |
| 16_SUPPLIER_ADDR_TAX_NUMBER | clean_data.supplier_addr_tax_number | default_tax_id_number_db | TVA_UE | CONSTANTE | TRUE | Oui | supplier | La TVA intracommunautaire est le numero fiscal par defaut du fournisseur |  |
| 16_SUPPLIER_ADDR_TAX_NUMBER | clean_data.supplier_addr_tax_number | tax_id_type | SIREN | CONSTANTE | SIREN | Oui | supplier | Type du numero SIREN (source : ifs_fournisseurs.numero_siren) |  |
| 16_SUPPLIER_ADDR_TAX_NUMBER | clean_data.supplier_addr_tax_number | tax_id_type | SIRET | CONSTANTE | SIRET | Oui | supplier | Type du numero SIRET (source : ifs_fournisseurs.siret) |  |
| 16_SUPPLIER_ADDR_TAX_NUMBER | clean_data.supplier_addr_tax_number | tax_id_type | TVA_UE | CONSTANTE | TVA UE | Oui | supplier | Type du numero de TVA intracommunautaire (source : ifs_fournisseurs.tva) |  |
## Sheet: 01_IFS_FOURNISSEURS
| Colonne cible | Type / Longueur | Champ / Table source | Système source | Règle de transformation / Condition | Exemple de valeur | Validé métier (O/N) | Remarques métier | Date validation |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Script 01_alimenter_ifs_fournisseurs.sql — TABLE PILOTE. Source principale : raw_data.selection_fournisseurs_stg (fichier métier). Enrichissement SAP en LEFT JOIN (ne filtre jamais). Complément : fournisseurs créés dans SAP après l'arrêté du fichier (source='SAP_NOUVEAU'). |  |  |  |  |  |  |  |  |
| Identifiants |  |  |  |  |  |  |  |  |
| numero_compte_fournisseur |  | selection_fournisseurs_stg.numero_compte_sap (LPAD 10) / lfa1.lifnr | IFS / SAP | Clé primaire. Complété à 10 caractères (LPAD) pour matcher le format SAP LIFNR. | 0000045036 |  |  |  |
| numero_compte_ifs |  | ifs_fournisseur_id_map (alimentée depuis sf.numero_compte_ifs, sinon séquence) | IFS | Numéro arbitré par le métier dans le fichier s'il existe ; sinon émis par clean_data.seq_numero_compte_ifs (démarre à 600001) pour les fournisseurs SAP créés après l'arrêté du fichier. Figé définitivement une fois attribué. | 600001 |  |  |  |
| address_id |  | lfa1.adrnr, repli sur Config | SAP / Config | COALESCE(adrnr SAP, valeur par défaut paramétrable). Colonne pivot : reprise telle quelle par les scripts 04, 06, 14, 15. | 0000012345 |  |  |  |
| source |  | — | Technique | Constante 'FICHIER' (bloc 1) ou 'SAP_NOUVEAU' (bloc 2, fournisseurs absents du fichier mais créés dans SAP depuis le 2025-10-07). | FICHIER |  |  |  |
| Priorité fichier de sélection > SAP (COALESCE) |  |  |  |  |  |  |  |  |
| nom_1 |  | sf.denomination_sociale > lfa1.name1 | IFS / SAP | COALESCE. | ACIERIES DE ROMPPAS |  |  |  |
| rue |  | sf.libelle_concatene (ou construction numero_voie+...) > lfa1.stras | IFS / SAP | COALESCE, 2 niveaux de repli côté fichier. | 12 RUE DE LA PAIX |  |  |  |
| localite |  | sf.localite > lfa1.ort01 | IFS / SAP | COALESCE. | LYON |  |  |  |
| code_postal |  | sf.code_postal > lfa1.pstlz | IFS / SAP | COALESCE. | 69000 |  |  |  |
| cle_pays |  | sf.code_pays > lfa1.land1 | IFS / SAP | COALESCE. | FR |  |  |  |
| siret |  | sf.numero_siret > lfa1.stcd1 | IFS / SAP | COALESCE. | 12345678901234 |  |  |  |
| tva |  | sf.numero_tva_intra > lfa1.stceg | IFS / SAP | COALESCE. | FR12345678901 |  |  |  |
| conditions_paiement_compta / _achats |  | sf.condition_paiement_ifs > données SAP agrégées (lfb1.zterm / lfm1.zterm) | IFS / SAP | COALESCE. | NET30 |  |  |  |
| telephone_1 |  | sf.telephone_1 > lfa1.telf1 | IFS / SAP | COALESCE. | 0472000000 |  |  |  |
| telephone_2 |  | sf.telephone_2 > sf.telephone_3 > lfa1.telf2 | IFS / SAP | COALESCE, 3 niveaux. |  |  |  |  |
| language_sap |  | sf.langue > lfa1.spras, via public.get_transcodification('LANGUAGE', ...) | IFS / SAP / Config | Table de transcodification LANGUAGE (source SAP → cible IFS). | FR |  |  |  |
| SAP uniquement (absent du fichier) |  |  |  |  |  |  |  |  |
| societe |  | raw_data.lfb1.bukrs (string_agg DISTINCT) | SAP | Agrégation de toutes les sociétés comptables du fournisseur, séparées par virgule. | APSJ, STJN |  |  |  |
| organisation_achats / incoterms_1 / incoterms_2 |  | raw_data.lfm1 (ekorg le plus petit) | SAP | Sous-requête retenant l'organisation d'achat de plus petit code (ekorg = MIN). | 1000 |  |  |  |
| date_creation_sap |  | lfa1.erdat | SAP | erdat est stocké en texte, au format SAP brut (YYYYMMDD) OU déjà ISO (YYYY-MM-DD) selon l'extraction : le script teste le motif avant TO_DATE. Format inattendu → NULL. | 2019-03-12 |  |  |  |
| destinataire_paiement |  | raw_data.lfb1.lnrzb (MIN) | SAP |  |  |  |  |  |
| Colonnes reprises telles quelles du fichier (pas de repli SAP) |  |  |  |  |  |  |  |  |
| code_tva_ifs / code_tva_sap / france_etranger / numero_siren / complement_adresse / condition_paiement_sap / telephone_3 / critere_recherche / langue / email / mode_paiement |  | raw_data.selection_fournisseurs_stg | IFS | NULLIF(TRIM(...),'') — pas de repli SAP, ces informations n'existent que dans le fichier. |  |  |  |  |
| Coordonnées bancaires — clean_data.fn_coordonnees_bancaires_sap(lifnr) |  |  |  |  |  |  |  |  |
| iban_paiement / swift_bic / nom_banque / numero_compte_bancaire / code_banque / pays_banque / titulaire_compte |  | raw_data.lfbk + tiban + bnka, via la fonction dédiée | SAP | IBAN réel (TIBAN) en priorité ; repli sur calcul FR (code banque + compte) si absent de TIBAN. Fonction partagée avec le script 14 (payment_address) : garantit le même compte des deux côtés. 1 seul compte retenu par fournisseur (priorité : IBAN renseigné, puis bvtyp, bankl, bankn). | FR7612345987650123456789014 |  |  |  |
| company |  | — | Config | public.get_default_value('clean_data.ifs_fournisseurs','company'). | STJN |  |  |  |
| ⚠ Point d'attention : deux INSERT successifs alimentent cette table (bloc FICHIER puis bloc SAP_NOUVEAU) — le second reprend uniquement les fournisseurs LFA1 créés depuis le 2025-10-07, absents du fichier et non marqués supprimés (loevm≠'X'). Vérifier avec le métier que cette date pivot reste correcte au moment du chargement final. |  |  |  |  |  |  |  |  |
## Sheet: 02_SUPPLIER_INFO_GENERAL
| Colonne cible | Type / Longueur | Champ / Table source | Système source | Règle de transformation / Condition | Exemple de valeur | Validé métier (O/N) | Remarques métier | Date validation |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Script 02_alimenter_supplier_info_general.sql — FROM clean_data.ifs_fournisseurs (1 ligne par fournisseur, TRUNCATE + INSERT). |  |  |  |  |  |  |  |  |
| supplier_id / supplier_legacy_sap_id |  | ifs_fournisseurs.numero_compte_fournisseur | IFS | SUBSTRING(...,1,20) — copie à l'identique dans les 2 colonnes. | 0000045036 |  |  |  |
| name | VARCHAR(100) | ifs_fournisseurs.nom_1 | IFS | SUBSTRING(...,1,100). | ACIERIES DE ROMPPAS |  |  |  |
| country / country_db |  | ifs_fournisseurs.cle_pays | IFS | SUBSTRING(...,1,2). | FR |  |  |  |
| creation_date / created_timestamp |  | ifs_fournisseurs.date_creation_sap | IFS | COALESCE(date SAP, CURRENT_TIMESTAMP). | 2019-03-12 |  |  |  |
| association_no / suppliers_own_id |  | ifs_fournisseurs.siret | IFS | SUBSTRING(siret,1,20) — même valeur dans les 2 colonnes. | 12345678901234 |  |  |  |
| identifier_reference | VARCHAR(100) | ifs_fournisseurs.siret / .tva / .numero_compte_fournisseur | IFS | CASE : SIRET si renseigné, sinon TVA, sinon numéro de compte SAP. | 12345678901234 |  |  |  |
| identifier_ref_validation | VARCHAR(100) | ifs_fournisseurs.siret / .tva | IFS | CASE : 'VERIFIED' si SIRET, 'PARTIAL' si seulement TVA, sinon 'NOT_VERIFIED'. | VERIFIED |  |  |  |
| Colonnes 100% paramétrables (Config) |  | Config : clean_data.etl_default_values
(public.get_default_value) | Config | Valeur(s) par défaut paramétrable(s) sans toucher au code — voir Configuration > Valeurs par défaut.
Colonnes concernées : party, default_domain, default_language, default_language_db, party_type, party_type_db, corporate_form, identifier_ref_validation_db, picture_id, one_time, one_time_db, supplier_category, supplier_category_db, b2b_supplier, b2b_supplier_db, business_classification |  |  |  |  |
| created_by / updated_by / updated_timestamp / is_deleted |  | — | Technique | Constantes techniques ('etl_supplier_base', CURRENT_TIMESTAMP, FALSE). |  |  |  |  |
## Sheet: 03_SUPPLIER_INFO_OUR_ID
| Colonne cible | Type / Longueur | Champ / Table source | Système source | Règle de transformation / Condition | Exemple de valeur | Validé métier (O/N) | Remarques métier | Date validation |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Script 03_alimenter_supplier_info_our_id.sql — FROM clean_data.ifs_fournisseurs. |  |  |  |  |  |  |  |  |
| supplier_id | VARCHAR(20) | ifs_fournisseurs.numero_compte_fournisseur | IFS | Valeur directe. | 0000045036 |  |  |  |
| company | VARCHAR(100) | ifs_fournisseurs.company | IFS | Valeur directe (déjà résolue à l'étape 01). | STJN |  |  |  |
| our_id | VARCHAR(20) | Config (préfixe) + numero_compte_fournisseur | Config / IFS | CONCAT(get_default_value('our_id_prefix'), '-', numero_compte_fournisseur). | SUP-0000045036 |  |  |  |
| created_timestamp | TIMESTAMP WITHOUT TIME ZONE | ifs_fournisseurs.date_creation_sap | IFS | COALESCE(date SAP, CURRENT_TIMESTAMP). |  |  |  |  |
| updated_timestamp / created_by / updated_by / is_deleted |  | — | Technique | Constantes techniques. |  |  |  |  |
| Filtre : numero_compte_fournisseur non NULL et non vide uniquement. |  |  |  |  |  |  |  |  |
## Sheet: 04_SUPPLIER_INFO_ADDRESS
| Colonne cible | Type / Longueur | Champ / Table source | Système source | Règle de transformation / Condition | Exemple de valeur | Validé métier (O/N) | Remarques métier | Date validation |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Script 04_alimenter_supplier_info_address.sql — FROM ifs_fournisseurs LEFT JOIN raw_data.lfa1 LEFT JOIN raw_data.adrc (adresse SAP détaillée par numéro adrnr, client='100'). |  |  |  |  |  |  |  |  |
| supplier_id | VARCHAR(20) | ifs_fournisseurs.numero_compte_fournisseur | IFS | SUBSTRING(...,1,20). |  |  |  |  |
| address_id | VARCHAR(50) | ifs_fournisseurs.address_id | IFS | SUBSTRING(...,1,50). Même identifiant que l'étape 01 — pivot des étapes 05/06/08/13/14. |  |  |  |  |
| name | VARCHAR(100) | adrc.name1 > ifs_fournisseurs.nom_1 | SAP / IFS | COALESCE, SUBSTRING(...,1,100). |  |  |  |  |
| address | VARCHAR(35) | adrc.street+house_num1+city1+post_code1 (repli ifs_fournisseurs) | SAP / IFS | Concaténation TRIM(street||' '||house_num1||' '||city1||' '||post_code1), tronquée à 35 caractères. | ⚠ Risque de troncature sur adresses longues — à valider. |  |  |  |
| valid_from / valid_to |  | adrc.date_from / date_to | SAP | valid_from = date SAP sinon CURRENT_DATE. valid_to = date SAP sinon NULL. |  |  |  |  |
| party | VARCHAR(20) | adrc.name_co | SAP | SUBSTRING(...,1,20). |  |  |  |  |
| country / country_db |  | adrc.country > ifs_fournisseurs.cle_pays | SAP / IFS | COALESCE. | FR |  |  |  |
| address1..address6 |  | adrc.street / str_suppl1 / str_suppl2 / building / floor / roomnumber | SAP | Correspondance directe champ à champ, SUBSTRING(...,1,35). |  |  |  |  |
| zip_code / city |  | adrc.post_code1 / city1 (repli ifs_fournisseurs) | SAP / IFS | COALESCE. |  |  |  |  |
| county / state / supplier_branch |  | adrc.city2 / region / addr_group | SAP | Correspondance directe. |  |  |  |  |
| ean_location | VARCHAR(100) | adrc.location | SAP |  |  |  |  |  |
| Colonnes paramétrables (Config) |  | Config : clean_data.etl_default_values
(public.get_default_value) | Config | Valeur(s) par défaut paramétrable(s) sans toucher au code — voir Configuration > Valeurs par défaut.
Colonnes concernées : default_domain, party_type, party_type_db, comm_id, output_media, output_media_db |  |  |  |  |
| created_timestamp / updated_timestamp / created_by / updated_by / is_deleted |  | — | Technique | Constantes techniques. |  |  |  |  |
| Jointure : ifs_fournisseurs → lfa1 (exclut loevm='X') → adrc (via adrnr, client fixé à '100'). |  |  |  |  |  |  |  |  |
## Sheet: 05_SUPPLIER_INFO_ADDRESS_TYPE
| Colonne cible | Type / Longueur | Champ / Table source | Système source | Règle de transformation / Condition | Exemple de valeur | Validé métier (O/N) | Remarques métier | Date validation |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Script 05_insert_supplier_address_types.sql — FROM clean_data.supplier_info_address. 4 INSERT successifs : chaque adresse génère systématiquement 4 lignes (DELIVERY / INVOICE / VISIT / PAY). |  |  |  |  |  |  |  |  |
| supplier_id / address_id |  | supplier_info_address.supplier_id / .address_id | IFS | Repris tel quel. |  |  |  |  |
| address_type_id | VARCHAR(40) | — | Technique | Construit : supplier_id || '_' || address_id || '_' || [D/I/V/P] (1 code par type). | 0000045036_0000012345_D |  |  |  |
| Colonnes paramétrables PAR TYPE (variante DELIVERY/INVOICE/VISIT/PAY dans etl_default_values) |  | Config : clean_data.etl_default_values
(public.get_default_value) | Config | Valeur(s) par défaut paramétrable(s) sans toucher au code — voir Configuration > Valeurs par défaut.
Colonnes concernées : address_type_code, address_type_code_db, party, def_address, default_domain, invoice, visit, pay |  |  |  |  |
| created_timestamp / updated_timestamp / created_by / updated_by / is_deleted |  | — | Technique | Constantes techniques. |  |  |  |  |
| Aucun filtre sur le type d'adresse SAP réel : les 4 lignes sont créées pour TOUTES les adresses actives, sans distinction. Le paramétrage (Config) est donc ce qui différencie réellement chaque type. |  |  |  |  |  |  |  |  |
## Sheet: 06_COMM_METHOD
| Colonne cible | Type / Longueur | Champ / Table source | Système source | Règle de transformation / Condition | Exemple de valeur | Validé métier (O/N) | Remarques métier | Date validation |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Script 06_alimenter_comm_method.sql — 3 blocs UNION ALL : téléphone (raw_data.adr2), fax (adr3), email (adr6), tous joints via ifs_fournisseurs → lfa1 → adrc (adrnr). Contrairement à l'étape 05, PAS de ligne par défaut : seuls les fournisseurs avec une valeur SAP renseignée génèrent une ligne. |  |  |  |  |  |  |  |  |
| identity / supplier_id |  | ifs_fournisseurs.numero_compte_fournisseur | IFS | Repris tel quel. |  |  |  |  |
| address_id | VARCHAR(50) | ifs_fournisseurs.address_id | IFS | Repris tel quel. |  |  |  |  |
| value | VARCHAR(200) | adr2.tel_number / adr3.fax_number / adr6.smtp_addr | SAP | 1 valeur par type ; email filtré sur ILIKE '%@%'. | contact@fournisseur.fr |  |  |  |
| description | VARCHAR(200) | adr2/adr3/adr6.flgdefault | SAP | CASE : texte 'principal' si flgdefault='X', sinon texte générique. | Téléphone principal du fournisseur |  |  |  |
| method_default | VARCHAR(5) | flgdefault | SAP | CASE : 'TRUE' si flgdefault='X', sinon 'FALSE'. | TRUE |  |  |  |
| address_default | VARCHAR(5) | flgdefault (email uniquement) | SAP / Config | Pour E_MAIL : reflète flgdefault comme method_default. Pour PHONE/FAX : valeur Config fixe (pas liée à flgdefault). ⚠ Incohérence de traitement entre email et téléphone/fax — à confirmer que c'est voulu. |  |  |  |  |
| name | VARCHAR(100) | ifs_fournisseurs.nom_1 | IFS |  |  |  |  |  |
| valid_from | DATE | — | Technique | CURRENT_DATE. |  |  |  |  |
| Colonnes paramétrables PAR TYPE (variante PHONE/FAX/E_MAIL) |  | Config : clean_data.etl_default_values
(public.get_default_value) | Config | Valeur(s) par défaut paramétrable(s) sans toucher au code — voir Configuration > Valeurs par défaut.
Colonnes concernées : party_type_db, method_id_db, valid_to, method_id, party_type |  |  |  |  |
| created_timestamp | TIMESTAMP WITHOUT TIME ZONE | ifs_fournisseurs.date_creation_sap | IFS | COALESCE(date SAP, CURRENT_TIMESTAMP). |  |  |  |  |
| updated_timestamp / created_by / updated_by / is_deleted |  | — | Technique | Constantes techniques. |  |  |  |  |
## Sheet: 07_SUPPLIER_ADDRESS
| Colonne cible | Type / Longueur | Champ / Table source | Système source | Règle de transformation / Condition | Exemple de valeur | Validé métier (O/N) | Remarques métier | Date validation |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Script 07_alimenter_supplier_address.sql — FROM clean_data.supplier_info_address (donc dépend de l'étape 04). |  |  |  |  |  |  |  |  |
| vendor_no / addr_no |  | supplier_info_address.supplier_id / .address_id | IFS | SUBSTRING. |  |  |  |  |
| contact | VARCHAR(100) | supplier_info_address.name | IFS | SUBSTRING(...,1,100). |  |  |  |  |
| intrastat_exempt / intrastat_exempt_db |  | supplier_info_address.country_db | IFS | CASE : 'Include'/'INCLUDE' si pays dans la liste UE (27 pays codés en dur), sinon 'Exempt'/'EXEMPT'. | Include |  |  |  |
| del_terms_location | VARCHAR(100) | supplier_info_address.city ou .address1 | IFS | COALESCE(city, address1). |  |  |  |  |
| supplier_calendar_id | VARCHAR(10) | supplier_info_address.country_db | IFS | Construit : 'CAL_' || COALESCE(country_db, 'XX'), SUBSTRING(...,1,10). | CAL_FR |  |  |  |
| Colonnes NON enrichies (TODO explicite dans le script source) |  | Config : clean_data.etl_default_values
(public.get_default_value) | Config | Valeur(s) par défaut paramétrable(s) sans toucher au code — voir Configuration > Valeurs par défaut.
Colonnes concernées : delivery_terms, ship_via_code, route_id |  |  |  |  |
| ⚠ delivery_terms / ship_via_code / route_id sont explicitement en attente d'enrichissement depuis LFM1 ou une table de transcodification (commentaire TODO dans le script). À prioriser avec le métier si ces champs sont bloquants. |  |  |  |  |  |  |  |  |
## Sheet: 08_SUPPLIER_DOCUMENT_TAX_INFO
| Colonne cible | Type / Longueur | Champ / Table source | Système source | Règle de transformation / Condition | Exemple de valeur | Validé métier (O/N) | Remarques métier | Date validation |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Script 08_insert_supplier_document_tax_info.sql — FROM clean_data.supplier_info_address LEFT JOIN clean_data.ifs_fournisseurs. |  |  |  |  |  |  |  |  |
| supplier_id / address_id |  | supplier_info_address.supplier_id / .address_id | IFS | Repris tel quel. |  |  |  |  |
| tax_id_type | VARCHAR(10) | supplier_info_address.country | IFS | CASE : FR→'SIRET', DE→'TVA DE', BE→'VAT BE', NL→'VAT NL', IT→'VAT IT', sinon 'OTHER'. | SIRET |  |  |  |
| vat_no | VARCHAR(50) | ifs_fournisseurs.tva | IFS | COALESCE(tva, 'NO_VAT_'||supplier_id). | ⚠ Placeholder 'NO_VAT_<id>' si TVA absente, au lieu de NULL — à valider. |  |  |  |
| validated_date / declaration_date / last_modify_date |  | — | Technique | CURRENT_DATE. |  |  |  |  |
| created_timestamp / created_by |  | supplier_info_address.created_timestamp / .created_by | IFS | COALESCE(valeur amont, valeur technique). |  |  |  |  |
| updated_by | VARCHAR(50) | — | Technique | Constante 'insert_supplier_tax_info_v1'.
⚠ Nom en dur qui ne correspond pas au nom réel du script (insert_supplier_document_tax_info) — probable copier-coller. |  |  |  |  |
| Colonnes paramétrables (Config) |  | Config : clean_data.etl_default_values
(public.get_default_value) | Config | Valeur(s) par défaut paramétrable(s) sans toucher au code — voir Configuration > Valeurs par défaut.
Colonnes concernées : company, reliability_status_db, tax_office_id, company_addr_tax_id_type, company_addr_tax_id_type_db |  |  |  |  |
## Sheet: 09_SUPPLIER
| Colonne cible | Type / Longueur | Champ / Table source | Système source | Règle de transformation / Condition | Exemple de valeur | Validé métier (O/N) | Remarques métier | Date validation |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Script 09_sp_insert_supplier_from_sap.sql — FROM clean_data.ifs_fournisseurs LEFT JOIN raw_data.lfm1 (organisation d'achat = ifs_fournisseurs.organisation_achats). |  |  |  |  |  |  |  |  |
| vendor_no |  | ifs_fournisseurs.numero_compte_fournisseur | IFS | Valeur directe (SELECT DISTINCT). |  |  |  |  |
| days_before_delivery / days_before_arrival |  | raw_data.lfm1.plifz | SAP | COALESCE(délai de livraison SAP, 30) — même valeur utilisée pour les deux colonnes. | 30 |  |  |  |
| tax_liability |  | ifs_fournisseurs.cle_pays | IFS | CASE : 'EU_TAX' si pays dans liste UE (12 pays codés en dur), sinon 'NON_EU'. | EU_TAX |  |  |  |
| ~30 colonnes 100% paramétrables (Config) — comportements achats par défaut |  | Config : clean_data.etl_default_values
(public.get_default_value) | Config | Valeur(s) par défaut paramétrable(s) sans toucher au code — voir Configuration > Valeurs par défaut.
Colonnes concernées : buyer_code, currency_code, supp_grp, supplier_group, additional_cost_amount, cr_check_db, discount, pack_list_flag_db, purch_order_flag_db, qc_approval_db, ord_conf_rem_interval, delivery_rem_interval, ord_conf_reminder_db, delivery_reminder_db, category_db, environmental_approval_db, coc_approval_db, template_supplier_db, quick_registered_supplier_db, blanket_date_db, express_order_allowed_db, pricat_automatic_approval_db, receipt_ref_reminder_db, print_amounts_incl_tax_db, receiving_advice_type_db, rec_adv_self_billing_db, po_change_management_db, create_confirmation_chg_ord_db, email_purchase_order_db, dir_del_approval_db, order_conf_approval_db, order_conf_diff_approval_db, adhoc_pur_rqst_approval_db, b2b_conf_order_with_diff_db, rec_adv_sb_consignment_db, rec_adv_sb_mix_ownership_db |  |  |  |  |
| created_timestamp / updated_timestamp / created_by / updated_by / is_deleted |  | — | Technique | Constantes techniques. |  |  |  |  |
| Table cible clean_data.supplier ≈ 140 colonnes au total ; seules celles listées ci-dessus sont explicitement alimentées par ce script — le reste garde sa valeur par défaut de colonne (souvent NULL). |  |  |  |  |  |  |  |  |
## Sheet: 10_IDENTITY_INVOICE_INFO
| Colonne cible | Type / Longueur | Champ / Table source | Système source | Règle de transformation / Condition | Exemple de valeur | Validé métier (O/N) | Remarques métier | Date validation |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Script 10_sp_insert_identity_invoice_info_from_sap.sql — FROM ifs_fournisseurs LEFT JOIN raw_data.selection_fournisseurs LEFT JOIN raw_data.lfbk LEFT JOIN raw_data.lfm1. Passe par une table temporaire (déduplication DISTINCT). |  |  |  |  |  |  |  |  |
| company | VARCHAR(20) | ifs_fournisseurs.company | IFS | COALESCE(company, 'TRIMET'). | STJN |  |  |  |
| identity | VARCHAR(20) | ifs_fournisseurs.numero_compte_fournisseur | IFS | Valeur directe. |  |  |  |  |
| pay_term_id | VARCHAR(20) | sf.condition_paiement_ifs > ifs_fournisseurs.conditions_paiement_achats | IFS | COALESCE, repli final sur constante 'NET30'. | NET30 |  |  |  |
| def_vat_code | VARCHAR(20) | sf.code_tva_ifs (raw_data.selection_fournisseurs, PAS le stg) | IFS | COALESCE(..., ''). |  |  |  |  |
| fiscal_no | VARCHAR(16) | ifs_fournisseurs.tva | IFS | SUBSTRING(TVA, 1, 16). ⚠ Le script signale lui-même que 3 fournisseurs (1 FR, 2 CN) portant un n° de 18 caractères sont tronqués. | FR1234567890123 |  |  |  |
| country_tax_registered | VARCHAR(4000) | ifs_fournisseurs.cle_pays | IFS | CASE : 'TRUE' si pays UE (liste de 12 pays), sinon 'FALSE'. | TRUE |  |  |  |
| created_by / updated_by |  | raw_data.lfbk (présence d'un compte bancaire) | SAP | CASE : 'etl_supplier_base_with_bank' si le fournisseur a un compte lfbk, sinon 'etl_supplier_base'. |  |  |  |  |
| ~28 colonnes paramétrables (Config) |  | Config : clean_data.etl_default_values
(public.get_default_value) | Config | Valeur(s) par défaut paramétrable(s) sans toucher au code — voir Configuration > Valeurs par défaut.
Colonnes concernées : party_type, party_type_db, invoice_fee, def_currency, identity_type, voting_share_percentage, automatic_invoice, ncf_reference_check, tax_exempt, second_tin, report_and_withhold, print_tax_code_text, withholding_base_amount, matching_level, allow_tolerance, create_tolerance_posting, allow_quantity_diff, tax_certificate_form, legal_identity, po_ref_rec_ref_val_method, invoice_recipient_from, exc_from_spesometro_dec, service_code_required, inc_inv_curr_rate_base, tax_buy_curr_rate_base, exclude_posting_auth, exclude_invoice_image, utility_bill_provider, digital_invoice |  |  |  |  |
| bi_timestamp / created_timestamp / updated_timestamp / is_deleted |  | — | Technique | CURRENT_TIMESTAMP / FALSE. |  |  |  |  |
| ⚠ Table cible à 107 colonnes en base ; ce script n'en alimente explicitement qu'environ 38 — le reste n'est pas couvert par ce loader et garde sa valeur par défaut (souvent NULL). |  |  |  |  |  |  |  |  |
## Sheet: 11_IDENTITY_PAY_INFO
| Colonne cible | Type / Longueur | Champ / Table source | Système source | Règle de transformation / Condition | Exemple de valeur | Validé métier (O/N) | Remarques métier | Date validation |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Script 11_sp_insert_identity_pay_info_from_sap.sql — FROM ifs_fournisseurs LEFT JOIN raw_data.lfb1 LEFT JOIN raw_data.lfm1. Dédoublonnage explicite par ROW_NUMBER() (1 ligne / (company, identity)). |  |  |  |  |  |  |  |  |
| company | VARCHAR(20) | ifs_fournisseurs.company | IFS | COALESCE(company, 'TRIMET'). | STJN |  |  |  |
| identity / supplier_id |  | ifs_fournisseurs.numero_compte_fournisseur | IFS | Valeur directe (dupliquée sur les 2 colonnes). |  |  |  |  |
| blocked_for_payment | VARCHAR(5) | raw_data.lfb1.sperr / raw_data.lfm1.sperm | SAP | CASE : 'TRUE' si l'un des deux blocages SAP est renseigné, sinon 'FALSE'. | FALSE |  |  |  |
| payment_delay | NUMERIC | raw_data.lfm1.plifz | SAP | COALESCE(délai SAP, 30). | 30 |  |  |  |
| amount_tolerance | NUMERIC | raw_data.lfm1.minbw | SAP | COALESCE(tolérance SAP, 100). | 100 |  |  |  |
| ~25 colonnes paramétrables (Config) |  | Config : clean_data.etl_default_values
(public.get_default_value) | Config | Valeur(s) par défaut paramétrable(s) sans toucher au code — voir Configuration > Valeurs par défaut.
Colonnes concernées : party_type, party_type_db, priority, other_payee_identity, interest_template, reminder_template, percent_tolerance, disc_days_tolerance, netting_allowed, format_no, payment_advice, payment_advice_db, deduction_group, corporation_id, member_id, send_reminder_to_payer, send_interest_inv_to_payer, rule_id, payment_receipt_type, payment_receipt_type_db, template_id, check_recipient, check_recipient_db, send_stmt_of_acc_to_payer, ar_contact, comm_id, output_media, output_media_db, default_payment_method, customer_id, next_payment_matching_id, is_one_inv_per_pay, is_one_inv_per_pay_db, payment_mode, payment_mode_db, predicted_payment_delay, predicted_payment_delay_db, business_category |  |  |  |  |
| Table temporaire + ROW_NUMBER() OVER (PARTITION BY company, identity, 'SUPPLIER') garantit 1 seule ligne par couple (company, identity), même si plusieurs lignes SAP LFM1 existent en amont. |  |  |  |  |  |  |  |  |
## Sheet: 12_PAYMENT_WAY_PER_IDENTITY
| Colonne cible | Type / Longueur | Champ / Table source | Système source | Règle de transformation / Condition | Exemple de valeur | Validé métier (O/N) | Remarques métier | Date validation |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Script 12_fn_upsert_payment_way_per_identity.sql — FROM clean_data.ifs_fournisseurs (1 ligne / fournisseur). |  |  |  |  |  |  |  |  |
| company |  | ifs_fournisseurs.company | IFS | COALESCE(company, 'TRIMET'). | STJN |  |  |  |
| identity |  | ifs_fournisseurs.numero_compte_fournisseur | IFS | Valeur directe. |  |  |  |  |
| Colonnes paramétrables (Config, variante STANDARD) |  | Config : clean_data.etl_default_values
(public.get_default_value) | Config | Valeur(s) par défaut paramétrable(s) sans toucher au code — voir Configuration > Valeurs par défaut.
Colonnes concernées : party_type, party_type_db, way_id, default_payment_way |  |  |  |  |
| created_timestamp / updated_timestamp / created_by / updated_by / is_deleted |  | — | Technique | CURRENT_TIMESTAMP / 'System' / FALSE. |  |  |  |  |
| ⚠ party_type est actuellement enregistré à NULL en configuration (variante STANDARD) — à confirmer avec le métier : le module 'customer' équivalent utilise 'Customer'/'CUSTOMER', faut-il un pendant 'Supplier' ici ? |  |  |  |  |  |  |  |  |
## Sheet: 13_SUPPLIER_DELIVERY_TAX_CODE
| Colonne cible | Type / Longueur | Champ / Table source | Système source | Règle de transformation / Condition | Exemple de valeur | Validé métier (O/N) | Remarques métier | Date validation |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Script 13_fn_upsert_supplier_delivery_tax_code.sql — FROM ifs_fournisseurs LEFT JOIN clean_data.supplier_info_address. |  |  |  |  |  |  |  |  |
| supplier_id | VARCHAR(20) | ifs_fournisseurs.numero_compte_fournisseur | IFS | Valeur directe. |  |  |  |  |
| address_id | VARCHAR(50) | supplier_info_address.address_id | IFS | COALESCE(adresse liée, 'DEFAULT_ADDR'). |  |  |  |  |
| company | VARCHAR(20) | ifs_fournisseurs.company | IFS | COALESCE(company, 'TRIMET'). | STJN |  |  |  |
| tax_code | VARCHAR(20) | ifs_fournisseurs.tva / .siret / .cle_pays | IFS | CASE en cascade : TVA si renseignée, sinon SIRET, sinon 'PAYS_DEFAULT' (ex. FR_DEFAULT), sinon 'NO_TAX_CODE'. SUBSTRING(...,1,20). | FR12345678901 |  |  |  |
| created_timestamp / updated_timestamp / created_by / updated_by / is_deleted |  | — | Technique | Constantes techniques. |  |  |  |  |
## Sheet: 14_PAYMENT_ADDRESS
| Colonne cible | Type / Longueur | Champ / Table source | Système source | Règle de transformation / Condition | Exemple de valeur | Validé métier (O/N) | Remarques métier | Date validation |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Script 14_fn_upsert_payment_address.sql — 2 ÉTAPES. Étape 1 : une adresse de paiement PAR DÉFAUT pour chaque fournisseur (depuis supplier_info_address). Étape 2 : boucle FOR sur ifs_fournisseurs pour compléter avec les vraies données bancaires (déjà résolues à l'étape 01 par fn_coordonnees_bancaires_sap) — UPSERT sur la même ligne via ON CONFLICT (company, identity, party_type_db, way_id, address_id). |  |  |  |  |  |  |  |  |
| Étape 1 — adresse par défaut (DISTINCT ON supplier_id) |  |  |  |  |  |  |  |  |
| identity / address_id |  | supplier_info_address.supplier_id / .address_id | IFS | 1 ligne par fournisseur (la 1ère adresse trouvée). |  |  |  |  |
| Colonnes paramétrables étape 1 (variante ADRESSE_DEFAUT) |  | Config : clean_data.etl_default_values
(public.get_default_value) | Config | Valeur(s) par défaut paramétrable(s) sans toucher au code — voir Configuration > Valeurs par défaut.
Colonnes concernées : company, party_type_db, way_id, party_type, description, default_address, account, bic_code, blocked_for_use, mapping_type, bank_account_validated, bank_account_validated_db |  |  |  |  |
| Étape 2 — données bancaires réelles (UPSERT sur la ligne de l'étape 1) |  |  |  |  |  |  |  |  |
| company | VARCHAR(20) | ifs_fournisseurs.company | IFS | COALESCE(company, 'TRIMET'). | STJN |  |  |  |
| identity / address_id |  | ifs_fournisseurs.numero_compte_fournisseur / .address_id | IFS | Même address_id qu'à l'étape 1 (= ifs_fournisseurs.address_id) : condition explicitement corrigée dans le script pour que l'UPSERT mette à jour la ligne existante au lieu d'en créer une seconde. |  |  |  |  |
| account | VARCHAR(50) | ifs_fournisseurs.iban_paiement / .numero_compte_bancaire | IFS | COALESCE(IBAN, numéro de compte). | FR7612345987650123456789014 |  |  |  |
| bic_code | VARCHAR(20) | ifs_fournisseurs.swift_bic | IFS | Valeur directe. | BNPAFRPP |  |  |  |
| description | VARCHAR(2000) | ifs_fournisseurs.nom_banque | IFS | COALESCE(nom banque, 'Compte bancaire '||n°séquence). | BNP PARIBAS |  |  |  |
| default_address | VARCHAR(5) | — | Technique | CASE : 'TRUE' pour le 1er (et unique) compte traité par fournisseur, sinon 'FALSE'. | TRUE |  |  |  |
| Colonnes paramétrables étape 2 (variante BANQUE) |  | Config : clean_data.etl_default_values
(public.get_default_value) | Config | Valeur(s) par défaut paramétrable(s) sans toucher au code — voir Configuration > Valeurs par défaut.
Colonnes concernées : party_type_db, way_id, party_type, blocked_for_use, mapping_type, bank_account_validated, bank_account_validated_db |  |  |  |  |
| ⚠ Étape 2 : boucle FOR...LOOP avec bloc BEGIN/EXCEPTION par ligne — une erreur sur un fournisseur ne bloque pas les autres, mais reste silencieuse (RAISE NOTICE uniquement, pas remontée comme échec global). |  |  |  |  |  |  |  |  |
| N'alimente que les fournisseurs limités à UN SEUL compte bancaire (celui déjà retenu par fn_coordonnees_bancaires_sap à l'étape 01) — les comptes bancaires secondaires (1065 fournisseurs en ont plusieurs dans raw_data.lfbk) ne sont pas repris ici. |  |  |  |  |  |  |  |  |
## Sheet: 15_SUPPLIER_TAX_INFO
| Colonne cible | Type / Longueur | Champ / Table source | Système source | Règle de transformation / Condition | Exemple de valeur | Validé métier (O/N) | Remarques métier | Date validation |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Script 15_fn_upsert_supplier_tax_info.sql — FROM clean_data.ifs_fournisseurs. |  |  |  |  |  |  |  |  |
| supplier_id / address_id |  | ifs_fournisseurs.numero_compte_fournisseur / .address_id | IFS | Valeur directe. |  |  |  |  |
| company | VARCHAR(20) | ifs_fournisseurs.company | IFS | COALESCE(company, 'TRIMET'). | STJN |  |  |  |
| tax_calc_structure_id / business_transaction_id |  | ifs_fournisseurs.cle_pays | IFS | Valeur directe (code pays utilisé tel quel pour les 2 colonnes). | FR |  |  |  |
| icms_tax_payer / icms_tax_payer_db |  | ifs_fournisseurs.cle_pays | IFS | CASE : 'Taxpayer'/'TAXPAYER' si pays = 'BR' (Brésil), sinon NULL. Règle fiscale spécifique au Brésil (ICMS). | Taxpayer (si BR) |  |  |  |
| Colonnes paramétrables (Config) — forcées identiques pour tous |  | Config : clean_data.etl_default_values
(public.get_default_value) | Config | Valeur(s) par défaut paramétrable(s) sans toucher au code — voir Configuration > Valeurs par défaut.
Colonnes concernées : use_supp_address_for_tax, use_supp_address_for_tax_db |  |  |  |  |
| created_timestamp / updated_timestamp / created_by / updated_by / is_deleted |  | — | Technique | Constantes techniques. |  |  |  |  |
## Sheet: 16_SUPPLIER_ADDR_TAX_NUMBER
| Colonne cible | Type / Longueur | Champ / Table source | Système source | Règle de transformation / Condition | Exemple de valeur | Validé métier (O/N) | Remarques métier | Date validation |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Script 16_sp_insert_supplier_addr_tax_number.sql — FROM clean_data.ifs_fournisseurs, 3 blocs UNION ALL (TVA UE / SIREN / SIRET). Un fournisseur produit 0 à 3 lignes : les valeurs vides ne génèrent aucune ligne. |  |  |  |  |  |  |  |  |
| supplier_id / address_id |  | ifs_fournisseurs.numero_compte_fournisseur / .address_id | IFS | SUBSTRING. |  |  |  |  |
| tax_id_number | VARCHAR(50) | ifs_fournisseurs.tva / .numero_siren / .siret | IFS | TVA : UPPER(TRIM(tva)) — IFS refuse un n° de TVA en minuscules. SIREN/SIRET : TRIM simple. | FR12345678901 |  |  |  |
| Colonnes paramétrables PAR TYPE (variante TVA_UE/SIREN/SIRET) |  | Config : clean_data.etl_default_values
(public.get_default_value) | Config | Valeur(s) par défaut paramétrable(s) sans toucher au code — voir Configuration > Valeurs par défaut.
Colonnes concernées : company, tax_id_type, default_tax_id_number_db |  |  |  |  |
| ⚠ default_tax_id_number (sans suffixe _db) n'est jamais alimentée — convention appliquée à tout le dépôt : sur un couple <colonne>/<colonne>_db, seule la colonne _db est renseignée. |  |  |  |  |  |  |  |  |
| 0 à 3 lignes par fournisseur selon les valeurs réellement renseignées dans ifs_fournisseurs (TVA/SIREN/SIRET vides → aucune ligne pour ce type). |  |  |  |  |  |  |  |  |