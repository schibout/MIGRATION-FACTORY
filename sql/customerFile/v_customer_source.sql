-- =====================================================
-- Vue : clean_data.v_customer_source
-- Source des clients pour les 20 procedures *_from_file_customer.
--
-- TABLE PIVOT : raw_data.file_customer -> 168 clients, 1 ligne par client.
-- Le fichier est la SEULE source de lignes. SAP et PHL ne creent jamais de
-- client : ils viennent en JOINTURE EXTERNE completer ce que le fichier ne
-- porte pas.
--
--   PIVOT      raw_data.file_customer         168 lignes (autorite)
--   ENRICH PHL raw_data.client_phl            LEFT JOIN LATERAL (1 ligne max)
--              raw_data.client_adresse_phl    LEFT JOIN LATERAL (1 ligne max)
--   ENRICH SAP raw_data.KNA1 / ADRC / T005T   joints dans chaque procedure
--
-- HISTORIQUE : la vue ajoutait auparavant, par UNION ALL, les 60 clients
-- raw_data.client_phl absents du fichier (228 lignes / 385 avec les adresses).
-- Cette branche a ete retiree : le fichier est la table pivot, un client qui
-- n'y figure pas n'est pas migre par ce module.
--
-- RAPPROCHEMENT FICHIER <-> PHL
-- Meme strategie que clean_data.get_legacy_as400_id, du plus sur au plus
-- permissif :
--   1. numero SAP exact          file_customer.kunnr = client_phl.numero_sap
--   2. nom normalise identique   clean_data.normalize_customer_name()
--   3. inclusion d'un nom dans l'autre (les deux >= 5 caracteres)
-- Le repli par nom permet d'enrichir aussi les clients du fichier sans kunnr
-- (nouveaux clients, absents de SAP). LATERAL + LIMIT 1 et non LEFT JOIN :
-- 152 lignes client_phl pour 149 numero_sap distincts, un JOIN dupliquerait
-- les lignes du fichier et fausserait les 19 autres procedures.
--
-- La vue expose exactement les colonnes de raw_data.file_customer, plus :
--   customer_id     identifiant client deja calcule
--   address_id      identifiant d'adresse deja calcule
--   source_systeme  toujours 'FILE' (conserve : plusieurs procedures le lisent)
--   phl_*           champs d'ADRESSE issus de client_adresse_phl
--   phl_cli_*       champs CLIENT issus de client_phl
--   phl_match_kind  voie de rapprochement retenue (controle qualite)
--
-- Les colonnes phl_* / phl_cli_* ne remplacent jamais la donnee du fichier :
-- elles sont exposees a part, pour que les procedures appliquent la cascade
-- FICHIER -> PHL -> SAP -> valeur par defaut d'ecran (public.get_default_value).
-- =====================================================

CREATE OR REPLACE VIEW clean_data.v_customer_source AS

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
    -- ---- champs d'ADRESSE issus de client_adresse_phl ----
    -- Seules les colonnes reellement alimentees sont reprises : address3 a
    -- address6, county, state, zip_code, ean_location, jurisdiction_code,
    -- primary_contact et secondary_contact sont vides sur les 217 lignes.
    NULLIF(TRIM(pa.address), '')::TEXT                AS phl_address,
    NULLIF(TRIM(pa.address_lov), '')::TEXT            AS phl_address_lov,
    NULLIF(TRIM(pa.address2), '')::TEXT               AS phl_address2,
    NULLIF(TRIM(pa.name), '')::TEXT                   AS phl_addr_name,
    -- 'VRAI'/'FAUX' -> booleen IFS attendu en MAJUSCULES
    (CASE UPPER(TRIM(COALESCE(pa.default_domain, '')))
        WHEN 'VRAI' THEN 'TRUE'
        WHEN 'TRUE' THEN 'TRUE'
        WHEN 'FAUX' THEN 'FALSE'
        WHEN 'FALSE' THEN 'FALSE'
     END)::TEXT                                       AS phl_default_domain,
    NULLIF(UPPER(TRIM(pa.party_type_db)), '')::TEXT   AS phl_party_type_db,
    -- ---- champs CLIENT issus de client_phl ----
    -- Les booleens PHL sont en casse mixte ('True'/'False') alors qu'IFS les
    -- attend en MAJUSCULES cote _db -> UPPER().
    NULLIF(UPPER(TRIM(p.default_domain)), '')::TEXT               AS phl_client_default_domain,
    NULLIF(UPPER(TRIM(p.one_time_db)), '')::TEXT                  AS phl_one_time_db,
    NULLIF(UPPER(TRIM(p.customer_category_db)), '')::TEXT         AS phl_customer_category_db,
    NULLIF(UPPER(TRIM(p.b2b_customer_db)), '')::TEXT              AS phl_b2b_customer_db,
    NULLIF(UPPER(TRIM(p.identifier_ref_validation_db)), '')::TEXT AS phl_identifier_ref_validation_db,
    NULLIF(TRIM(p.name), '')::TEXT                    AS phl_cli_name,
    p.creation_date::DATE                             AS phl_cli_creation_date,
    NULLIF(TRIM(p.association_no), '')::TEXT          AS phl_cli_association_no,
    NULLIF(TRIM(p.default_language), '')::TEXT        AS phl_cli_default_language,
    NULLIF(TRIM(p.default_language_db), '')::TEXT     AS phl_cli_default_language_db,
    NULLIF(TRIM(p.country), '')::TEXT                 AS phl_cli_country,
    NULLIF(TRIM(p.country_db), '')::TEXT              AS phl_cli_country_db,
    NULLIF(TRIM(p.party_type), '')::TEXT              AS phl_cli_party_type,
    NULLIF(UPPER(TRIM(p.party_type_db)), '')::TEXT    AS phl_cli_party_type_db,
    NULLIF(TRIM(p.corporate_form), '')::TEXT          AS phl_cli_corporate_form,
    NULLIF(TRIM(p.identifier_reference), '')::TEXT    AS phl_cli_identifier_reference,
    NULLIF(TRIM(p.identifier_ref_validation), '')::TEXT AS phl_cli_identifier_ref_validation,
    NULLIF(TRIM(p.picture_id), '')::TEXT              AS phl_cli_picture_id,
    NULLIF(TRIM(p.one_time), '')::TEXT                AS phl_cli_one_time,
    NULLIF(TRIM(p.customer_category), '')::TEXT       AS phl_cli_customer_category,
    NULLIF(TRIM(p.b2b_customer), '')::TEXT            AS phl_cli_b2b_customer,
    NULLIF(TRIM(p.customer_tax_usage_type), '')::TEXT AS phl_cli_customer_tax_usage_type,
    NULLIF(TRIM(p.business_classification), '')::TEXT AS phl_cli_business_classification,
    p.date_of_registration::DATE                      AS phl_cli_date_of_registration,
    -- Voie par laquelle le client PHL a ete retrouve : 'SAP_ID', 'NAME',
    -- 'NAME_PARTIAL' ou NULL. Sert au controle de qualite du rapprochement.
    p.match_kind::TEXT                                AS phl_match_kind
FROM raw_data.file_customer f
-- Nom du fichier normalise une seule fois (majuscules, sans accents ni
-- ponctuation), pour que les deux cotes de la comparaison restent coherents.
CROSS JOIN LATERAL (
    SELECT NULLIF(clean_data.normalize_customer_name(f.name_1), '') AS nn
) fn
-- ---------- Enrichissement CLIENT depuis PHL (jointure externe) ----------
LEFT JOIN LATERAL (
    SELECT cp2.*,
           CASE
               WHEN NULLIF(TRIM(f.kunnr), '') IS NOT NULL
                    AND TRIM(cp2.numero_sap) = TRIM(f.kunnr)                 THEN 'SAP_ID'
               WHEN fn.nn IS NOT NULL
                    AND clean_data.normalize_customer_name(cp2.name) = fn.nn THEN 'NAME'
               ELSE 'NAME_PARTIAL'
           END AS match_kind
    FROM raw_data.client_phl cp2
    WHERE NULLIF(TRIM(cp2.customer_id), '') IS NOT NULL
      AND (
            -- 1. numero SAP exact
            (NULLIF(TRIM(f.kunnr), '') IS NOT NULL
             AND TRIM(cp2.numero_sap) = TRIM(f.kunnr))
            -- 2. nom normalise identique
         OR (fn.nn IS NOT NULL
             AND clean_data.normalize_customer_name(cp2.name) = fn.nn)
            -- 3. inclusion d'un nom dans l'autre, les deux >= 5 caracteres.
            --    Le seuil evite qu'un nom court s'accroche a n'importe quelle
            --    raison sociale ; sans lui, position('' in x) matcherait tout.
         OR (fn.nn IS NOT NULL
             AND length(fn.nn) >= 5
             AND length(clean_data.normalize_customer_name(cp2.name)) >= 5
             AND (position(fn.nn in clean_data.normalize_customer_name(cp2.name)) > 0
               OR position(clean_data.normalize_customer_name(cp2.name) in fn.nn) > 0))
          )
    -- Priorite a la voie la plus sure, puis choix deterministe quand plusieurs
    -- codes PHL repondent (3 numero_sap portent 2 codes).
    ORDER BY
        CASE
            WHEN NULLIF(TRIM(f.kunnr), '') IS NOT NULL
                 AND TRIM(cp2.numero_sap) = TRIM(f.kunnr)                 THEN 1
            WHEN fn.nn IS NOT NULL
                 AND clean_data.normalize_customer_name(cp2.name) = fn.nn THEN 2
            ELSE 3
        END,
        TRIM(cp2.customer_id)
    LIMIT 1
) p ON TRUE
-- ---------- Enrichissement ADRESSE depuis PHL (jointure externe) ----------
-- Un client PHL peut porter plusieurs adresses (jusqu'a 171) alors que le
-- fichier n'en porte qu'une : on retient l'adresse par defaut, sinon la
-- premiere par address_id, pour garder le grain "1 ligne par client".
LEFT JOIN LATERAL (
    SELECT ca2.*
    FROM raw_data.client_adresse_phl ca2
    WHERE p.customer_id IS NOT NULL
      AND ca2.customer_id = p.customer_id
    ORDER BY
        CASE WHEN UPPER(TRIM(COALESCE(ca2.default_domain, ''))) IN ('VRAI', 'TRUE')
             THEN 0 ELSE 1 END,
        TRIM(ca2.address_id)
    LIMIT 1
) pa ON TRUE
WHERE COALESCE(NULLIF(TRIM(f.nouveau_compte_ifs), ''),
               NULLIF(TRIM(f.num_corrige), ''),
               TRIM(f.kunnr)) IS NOT NULL;

COMMENT ON VIEW clean_data.v_customer_source IS
'Source clients du module customerFile. Table pivot : raw_data.file_customer (168 clients, 1 ligne par client). raw_data.client_phl et client_adresse_phl sont joints en externe (n SAP, puis nom normalise) pour completer, sans jamais creer de ligne.';

-- Controles
-- SELECT count(*) AS lignes, count(DISTINCT customer_id) AS clients FROM clean_data.v_customer_source;
--   Attendu : 168 / 168.
-- SELECT COALESCE(phl_match_kind, 'AUCUN') AS voie, count(*)
--   FROM clean_data.v_customer_source GROUP BY 1 ORDER BY 1;
