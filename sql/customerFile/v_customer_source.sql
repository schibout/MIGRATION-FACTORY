-- =====================================================
-- Vue : clean_data.v_customer_source
-- Source unifiee des clients pour les 20 procedures *_from_file_customer.
--
--   FILE : raw_data.file_customer          -> 168 clients, 1 ligne par client
--   PHL  : raw_data.client_phl             -> les 60 clients ABSENTS du fichier
--          + raw_data.client_adresse_phl      (217 lignes d'adresse)
--
-- Le rapprochement FILE <-> PHL se fait sur file_customer.kunnr = client_phl.numero_sap.
-- Les 92 clients PHL deja presents dans le fichier ne sont PAS repris : le
-- fichier fait autorite (donnees corrigees).
--
-- La vue expose exactement les colonnes de raw_data.file_customer, plus :
--   customer_id     identifiant client deja calcule (evite de le recalculer
--                   dans chaque procedure, et permet aux lignes PHL d'utiliser
--                   leur propre code sans passer par nouveau_compte_ifs)
--   address_id      identifiant d'adresse deja calcule
--   source_systeme  'FILE' ou 'PHL', pour tracer et filtrer si besoin
--
-- Grain : 1 ligne par (client, adresse). Cote FILE le fichier ne porte qu'une
-- adresse par client ; cote PHL un client peut en avoir plusieurs (jusqu'a 171).
-- Les procedures de niveau client font deja DISTINCT ON (fc.customer_id), ce
-- grain ne les affecte donc pas.
-- =====================================================

CREATE OR REPLACE VIEW clean_data.v_customer_source AS

-- ---------- 1. Le fichier (source faisant autorite) ----------
SELECT
    f.raw_id,
    f.kunnr,
    f.num_corrige,
    f.nouveau_compte_ifs,
    f.account_group,
    f.vendor_number,
    f.code_tva_ifs,
    f.terme_reglement,
    f.name_1,
    f.name_2,
    f.name_3,
    f.name_4,
    f.street,
    f.postal_code,
    f.city,
    f.country,
    f.region,
    f.search_term,
    f.telephone,
    f.fax,
    f.telephone_2,
    f.teletex,
    f.telex,
    f.language,
    f.tax_number_1,
    f.tax_number_2,
    f.vat_number,
    f.siren,
    f.industry,
    f.created_on,
    f.created_by,
    f.customer_classification,
    f.order_block,
    f.delivery_block,
    f.billing_block,
    f.central_block,
    f.deletion_flag,
    f.bukrs,
    f.reconciliation_account,
    f.payment_methods,
    f.accounting_delete_flag,
    f.accounting_created_on,
    f.accounting_created_by,
    f.vkorg,
    f.distribution_channel,
    f.division,
    f.customer_group,
    f.sales_district,
    f.pricing_procedure,
    f.incoterms_1,
    f.incoterms_2,
    f.sales_delivery_block,
    f.sales_billing_block,
    f.sales_order_block,
    f.sales_delete_flag,
    f.sales_created_on,
    f.sales_created_by,
    f.inserted_at,
    f.updated_at,
    f.numero_adresse,
    f.association_number,
    f.source_file,
    f.loaded_at,
    -- colonnes calculees
    COALESCE(NULLIF(TRIM(f.nouveau_compte_ifs), ''),
             NULLIF(TRIM(f.num_corrige), ''),
             TRIM(f.kunnr))                                   AS customer_id,
    COALESCE(NULLIF(split_part(TRIM(f.numero_adresse), '.', 1), ''), '1') AS address_id,
    'FILE'::TEXT                                              AS source_systeme,
    -- champs d'adresse propres a client_adresse_phl (NULL cote fichier)
    NULL::TEXT                                                AS phl_address,
    NULL::TEXT                                                AS phl_address_lov,
    NULL::TEXT                                                AS phl_address2,
    NULL::TEXT                                                AS phl_addr_name,
    NULL::TEXT                                                AS phl_default_domain,
    NULL::TEXT                                                AS phl_party_type_db,
    -- champs client propres a client_phl (NULL cote fichier)
    NULL::TEXT                                                AS phl_client_default_domain,
    NULL::TEXT                                                AS phl_one_time_db,
    NULL::TEXT                                                AS phl_customer_category_db,
    NULL::TEXT                                                AS phl_b2b_customer_db,
    NULL::TEXT                                                AS phl_identifier_ref_validation_db
FROM raw_data.file_customer f
WHERE COALESCE(NULLIF(TRIM(f.nouveau_compte_ifs), ''),
               NULLIF(TRIM(f.num_corrige), ''),
               TRIM(f.kunnr)) IS NOT NULL

UNION ALL

-- ---------- 2. Les clients PHL absents du fichier ----------
SELECT
    NULL::BIGINT                        AS raw_id,
    TRIM(cp.numero_sap)::TEXT           AS kunnr,
    NULL::TEXT                          AS num_corrige,
    NULL::TEXT                          AS nouveau_compte_ifs,
    NULL::TEXT                          AS account_group,
    NULL::TEXT                          AS vendor_number,
    NULL::TEXT                          AS code_tva_ifs,
    NULL::TEXT                          AS terme_reglement,
    cp.name::TEXT                       AS name_1,
    NULL::TEXT                          AS name_2,
    NULL::TEXT                          AS name_3,
    NULL::TEXT                          AS name_4,
    ca.address1::TEXT                   AS street,
    -- client_adresse_phl.zip_code est vide sur toutes les lignes ; le code postal
    -- est noye dans le texte `address`, juste avant la ville. On l'extrait, mais on
    -- ne le retient que s'il ressemble vraiment a un code postal : sur les adresses
    -- etrangeres le decoupage ramene sinon des morceaux de rue.
    (CASE
        WHEN position(TRIM(ca.city) in ca.address) > 1
         AND TRIM((regexp_match(
                      rtrim(left(ca.address, position(TRIM(ca.city) in ca.address) - 1)),
                      '([A-Za-z0-9][A-Za-z0-9 -]{2,9})$'))[1])
             ~ '^([0-9]{4,6}|[A-Z]-[0-9]{4,6})$'
        THEN TRIM((regexp_match(
                      rtrim(left(ca.address, position(TRIM(ca.city) in ca.address) - 1)),
                      '([A-Za-z0-9][A-Za-z0-9 -]{2,9})$'))[1])
     END)::TEXT                         AS postal_code,
    ca.city::TEXT                       AS city,
    COALESCE(ca.country_db, cp.country_db)::TEXT AS country,
    ca.state::TEXT                      AS region,
    NULL::TEXT                          AS search_term,
    NULL::TEXT                          AS telephone,
    NULL::TEXT                          AS fax,
    NULL::TEXT                          AS telephone_2,
    NULL::TEXT                          AS teletex,
    NULL::TEXT                          AS telex,
    -- client_phl porte deja le code IFS cible ('fr', 'en'...) alors que les
    -- procedures appliquent public.get_transcodification('LANGUAGE', ...), qui
    -- attend un code SAP ('F', 'E'...). On remonte donc au code source, sinon
    -- la transcodification renvoie NULL et la langue est perdue.
    (SELECT t.source_value
       FROM public."TranscodificationTable" t
      WHERE t.category = 'LANGUAGE'
        AND t.is_active = true
        AND t.target_value = cp.default_language_db
      ORDER BY t.source_value
      LIMIT 1)::TEXT                   AS language,
    cp.association_no::TEXT             AS tax_number_1,
    NULL::TEXT                          AS tax_number_2,
    cp.identifier_reference::TEXT       AS vat_number,
    NULL::TEXT                          AS siren,
    NULL::TEXT                          AS industry,
    -- les procedures attendent created_on au format texte YYYYMMDD
    TO_CHAR(cp.creation_date, 'YYYYMMDD')::TEXT AS created_on,
    NULL::TEXT                          AS created_by,
    NULL::TEXT                          AS customer_classification,
    NULL::TEXT                          AS order_block,
    NULL::TEXT                          AS delivery_block,
    NULL::TEXT                          AS billing_block,
    NULL::TEXT                          AS central_block,
    NULL::TEXT                          AS deletion_flag,
    NULL::TEXT                          AS bukrs,
    NULL::TEXT                          AS reconciliation_account,
    NULL::TEXT                          AS payment_methods,
    NULL::TEXT                          AS accounting_delete_flag,
    NULL::TEXT                          AS accounting_created_on,
    NULL::TEXT                          AS accounting_created_by,
    NULL::TEXT                          AS vkorg,
    NULL::TEXT                          AS distribution_channel,
    NULL::TEXT                          AS division,
    NULL::TEXT                          AS customer_group,
    NULL::TEXT                          AS sales_district,
    NULL::TEXT                          AS pricing_procedure,
    NULL::TEXT                          AS incoterms_1,
    NULL::TEXT                          AS incoterms_2,
    NULL::TEXT                          AS sales_delivery_block,
    NULL::TEXT                          AS sales_billing_block,
    NULL::TEXT                          AS sales_order_block,
    NULL::TEXT                          AS sales_delete_flag,
    NULL::TEXT                          AS sales_created_on,
    NULL::TEXT                          AS sales_created_by,
    NULL::TEXT                          AS inserted_at,
    NULL::TEXT                          AS updated_at,
    ca.address_id::TEXT                 AS numero_adresse,
    cp.association_no::TEXT             AS association_number,
    'client_phl'::TEXT                  AS source_file,
    cp.created_at::TIMESTAMPTZ          AS loaded_at,
    -- colonnes calculees
    TRIM(cp.customer_id)::TEXT          AS customer_id,
    COALESCE(NULLIF(TRIM(ca.address_id), ''), '1')::TEXT AS address_id,
    'PHL'::TEXT                         AS source_systeme,
    -- champs d'adresse propres a client_adresse_phl, deja au format IFS.
    -- Seules les colonnes reellement alimentees sont reprises : address3 a
    -- address6, county, state, zip_code, ean_location, jurisdiction_code,
    -- primary_contact et secondary_contact sont vides sur les 217 lignes.
    ca.address::TEXT                    AS phl_address,
    ca.address_lov::TEXT                AS phl_address_lov,
    ca.address2::TEXT                   AS phl_address2,
    ca.name::TEXT                       AS phl_addr_name,
    -- 'VRAI'/'FAUX' -> booleen IFS attendu en MAJUSCULES
    (CASE UPPER(TRIM(COALESCE(ca.default_domain, '')))
        WHEN 'VRAI' THEN 'TRUE'
        WHEN 'TRUE' THEN 'TRUE'
        WHEN 'FAUX' THEN 'FALSE'
        WHEN 'FALSE' THEN 'FALSE'
     END)::TEXT                         AS phl_default_domain,
    UPPER(TRIM(ca.party_type_db))::TEXT AS phl_party_type_db,
    -- champs client propres a client_phl. Les booleens y sont en casse mixte
    -- ('True'/'False') alors qu'IFS les attend en MAJUSCULES -> UPPER().
    UPPER(TRIM(cp.default_domain))::TEXT               AS phl_client_default_domain,
    UPPER(TRIM(cp.one_time_db))::TEXT                  AS phl_one_time_db,
    UPPER(TRIM(cp.customer_category_db))::TEXT         AS phl_customer_category_db,
    UPPER(TRIM(cp.b2b_customer_db))::TEXT              AS phl_b2b_customer_db,
    UPPER(TRIM(cp.identifier_ref_validation_db))::TEXT AS phl_identifier_ref_validation_db
FROM raw_data.client_phl cp
JOIN raw_data.client_adresse_phl ca
     ON ca.customer_id = cp.customer_id
WHERE NULLIF(TRIM(cp.customer_id), '') IS NOT NULL
  -- exclure les clients PHL deja portes par le fichier
  AND NOT EXISTS (
        SELECT 1
        FROM raw_data.file_customer f2
        WHERE NULLIF(TRIM(f2.kunnr), '') IS NOT NULL
          AND TRIM(f2.kunnr) = TRIM(cp.numero_sap)
      );

COMMENT ON VIEW clean_data.v_customer_source IS
'Source unifiee clients : raw_data.file_customer + les clients raw_data.client_phl absents du fichier (rapprochement kunnr = numero_sap). Colonnes de file_customer + customer_id, address_id, source_systeme.';

-- Controles
-- SELECT source_systeme, count(*) AS lignes, count(DISTINCT customer_id) AS clients
--   FROM clean_data.v_customer_source GROUP BY 1;
-- Attendu : FILE 168 lignes / 168 clients, PHL 217 lignes / 60 clients.
