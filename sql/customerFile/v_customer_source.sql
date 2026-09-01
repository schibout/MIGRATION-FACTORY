-- =====================================================
-- Vue : clean_data.v_customer_source
-- Source des clients pour les 20 procedures *_from_file_customer.
--
-- TABLE PIVOT : raw_data.file_customer -> 196 clients, 1 ligne par client
-- (365 lignes brutes dedoublonnees ci-dessous, cf. DEDOUBLONNAGE DU FICHIER).
-- Le fichier est la SEULE source de lignes. SAP et PHL ne creent jamais de
-- client : ils viennent en JOINTURE EXTERNE completer ce que le fichier ne
-- porte pas.
--
--   PIVOT      raw_data.file_customer         196 clients (autorite)
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
-- 92 des 196 clients du fichier sont rapproches a PHL.
--
-- La vue expose exactement les colonnes de raw_data.file_customer, plus :
--   customer_id     identifiant client deja calcule
--   address_id      adresse PRINCIPALE : address_id PHL si le client est
--                   rapproche, sinon le numero d'adresse du fichier. Les
--                   procedures qui referencent UNE adresse (types, taxes,
--                   paiement, commande) s'appuient dessus. Pour charger
--                   TOUTES les adresses, voir clean_data.v_customer_address_source
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

-- DEDOUBLONNAGE DU FICHIER : raw_data.file_customer empile les chargements
-- successifs (l'import ne purge pas la table). Au 2026-09-01 elle porte 365
-- lignes pour 196 clients : 168 clients y figurent deux fois, une version du
-- 2026-06-21 et une du 2026-09-01. Sans ce DISTINCT ON, la vue rend 365
-- lignes et les 20 procedures choisissent arbitrairement l'ancienne ou la
-- nouvelle version. On retient le chargement le PLUS RECENT.
WITH fichier AS (
    SELECT DISTINCT ON (COALESCE(NULLIF(TRIM(f0.nouveau_compte_ifs), ''),
                                 NULLIF(TRIM(f0.num_corrige), ''),
                                 TRIM(f0.kunnr)))
           f0.*
    FROM raw_data.file_customer f0
    WHERE COALESCE(NULLIF(TRIM(f0.nouveau_compte_ifs), ''),
                   NULLIF(TRIM(f0.num_corrige), ''),
                   TRIM(f0.kunnr)) IS NOT NULL
    ORDER BY COALESCE(NULLIF(TRIM(f0.nouveau_compte_ifs), ''),
                      NULLIF(TRIM(f0.num_corrige), ''),
                      TRIM(f0.kunnr)),
             f0.loaded_at DESC NULLS LAST,
             f0.raw_id DESC
)

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
    -- ADRESSE PRINCIPALE du client. C'est l'identifiant d'adresse PHL
    -- (client_adresse_phl.id_client) retenu par la LATERAL ci-dessous -- le
    -- plus petit dans l'ordre alphabetique, soit '01' quand il existe -- des
    -- qu'un rapprochement existe. Toutes les tables satellites qui referencent
    -- une adresse (types, taxes, paiement, commande) pointent ainsi sur une
    -- ligne reellement chargee dans customer_info_address. Le CONTENU de cette
    -- adresse principale vient, lui, du fichier (cf.
    -- sp_insert_customer_info_address_from_file_customer).
    -- Repli : le numero d'adresse du fichier, puis '1'.
    COALESCE(NULLIF(TRIM(pa.id_client), ''),
             NULLIF(split_part(TRIM(f.numero_adresse), '.', 1), ''),
             '1')                                             AS address_id,
    'FILE'::TEXT                                              AS source_systeme,
    -- ---- champs d'ADRESSE issus de client_adresse_phl ----
    -- Colonnes de compatibilite : aucune procedure ne les lit (les adresses
    -- passent par clean_data.v_customer_address_source). Elles sont conservees
    -- parce que CREATE OR REPLACE VIEW interdit de supprimer une colonne.
    NULLIF(TRIM(CONCAT_WS(' ', NULLIF(TRIM(pa.adresse), ''),
                               NULLIF(TRIM(pa.adresse_suite), ''),
                               NULLIF(TRIM(pa.code_postal), ''),
                               NULLIF(TRIM(pa.ville), ''))), '')::TEXT AS phl_address,
    NULLIF(TRIM(CONCAT_WS(', ', NULLIF(TRIM(pa.adresse), ''),
                                NULLIF(TRIM(pa.ville), ''),
                                NULLIF(TRIM(pa.code_postal), ''))), '')::TEXT AS phl_address_lov,
    NULLIF(TRIM(pa.adresse_suite), '')::TEXT          AS phl_address2,
    NULLIF(TRIM(pa.nom), '')::TEXT                    AS phl_addr_name,
    -- La nouvelle raw_data.client_adresse_phl ne porte plus d'indicateur
    -- d'adresse par defaut ni de type de tiers : les procedures les derivent
    -- (code societe du fichier) ou prennent la valeur d'ecran.
    NULL::TEXT                                        AS phl_default_domain,
    NULL::TEXT                                        AS phl_party_type_db,
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
    p.match_kind::TEXT                                AS phl_match_kind,
    -- Code client PHL retenu : cle de jointure vers raw_data.client_adresse_phl
    -- pour clean_data.v_customer_address_source (toutes les adresses du client).
    -- EN DERNIERE POSITION A DESSEIN : CREATE OR REPLACE VIEW n'accepte que
    -- l'AJOUT de colonnes en fin de liste. Inserer une colonne au milieu fait
    -- echouer le remplacement ("cannot change name of view column") et laisse
    -- l'ancienne vue en place -> ne jamais reordonner les colonnes ci-dessus.
    NULLIF(TRIM(p.customer_id), '')::TEXT             AS phl_cli_customer_id
FROM fichier f
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
-- Un client PHL peut porter plusieurs adresses alors que le fichier n'en
-- porte qu'une : on retient la premiere par id_client, pour garder le grain
-- "1 ligne par client". La nouvelle raw_data.client_adresse_phl ne porte plus
-- d'indicateur d'adresse par defaut ; l'ordre alphabetique fait remonter les
-- identifiants numeriques ('01', '02') avant les mnemoniques ('AM', 'BU'), ce
-- qui reconduit le choix de l'ancienne table.
-- CLE : le code client PHL est ca2.mnemo, l'identifiant d'ADRESSE est
-- ca2.id_client (nommage trompeur, verifie sur les 670 lignes).
LEFT JOIN LATERAL (
    SELECT ca2.*
    FROM raw_data.client_adresse_phl ca2
    WHERE p.customer_id IS NOT NULL
      AND TRIM(ca2.mnemo) = TRIM(p.customer_id)
    ORDER BY TRIM(ca2.id_client)
    LIMIT 1
) pa ON TRUE
WHERE COALESCE(NULLIF(TRIM(f.nouveau_compte_ifs), ''),
               NULLIF(TRIM(f.num_corrige), ''),
               TRIM(f.kunnr)) IS NOT NULL;

COMMENT ON VIEW clean_data.v_customer_source IS
'Source clients du module customerFile. Table pivot : raw_data.file_customer (196 clients, 1 ligne par client apres dedoublonnage sur le chargement le plus recent). raw_data.client_phl et client_adresse_phl sont joints en externe (n SAP, puis nom normalise) pour completer, sans jamais creer de ligne.';

-- Controles
-- SELECT count(*) AS lignes, count(DISTINCT customer_id) AS clients FROM clean_data.v_customer_source;
--   Attendu : 196 / 196 (une ligne par client, sans doublon de chargement).
-- SELECT COALESCE(phl_match_kind, 'AUCUN') AS voie, count(*)
--   FROM clean_data.v_customer_source GROUP BY 1 ORDER BY 1;
