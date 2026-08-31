-- =====================================================
-- Vue : clean_data.v_customer_address_source
-- Source des ADRESSES du module customerFile : 1 ligne = 1 adresse a charger.
--
-- POURQUOI : les adresses clients doivent venir de PHL
-- (raw_data.client_adresse_phl), qui en porte plusieurs par client
-- (ex. AFFIMET : CO, CS, 01, 02) la ou raw_data.file_customer n'en porte
-- qu'une. clean_data.v_customer_source reste au grain "1 ligne par client"
-- (elle ne retient que l'adresse principale) : les procedures qui chargent
-- les adresses elles-memes s'appuient sur CETTE vue-ci.
--
--   Branche PHL   client rapproche (phl_cli_customer_id non nul)
--                 -> TOUTES ses adresses raw_data.client_adresse_phl
--   Branche FILE  client sans rapprochement PHL
--                 -> l'unique adresse du fichier (address_id du fichier)
--
-- Le client reste identifie par customer_id (numerotation IFS du fichier) :
-- seul l'identifiant d'ADRESSE vient de PHL.
--
-- REPLI : PHL ne renseigne que address1, address2, city, country, country_db,
-- address (texte complet) et address_lov. zip_code (reconstitue ici depuis le
-- texte `address`, voir addr_zip_code), county, state, address3 a address6,
-- ean_location et jurisdiction_code sont vides sur les 670 lignes.
-- Les colonnes addr_* valent donc NULL et les procedures appliquent la
-- cascade PHL -> FICHIER -> SAP (ADRC/KNA1) -> public.get_default_value.
-- ATTENTION : le code postal et le departement du FICHIER ne valent que pour
-- l'adresse principale. Les reprendre sur les autres adresses PHL donnerait un
-- code postal faux (89108 pour une adresse a Bagnolet) : les procedures ne
-- retombent sur le fichier que si PHL ne dit rien du tout.
--
-- Colonnes ajoutees a celles de clean_data.v_customer_source :
--   addr_origin  'PHL' ou 'FILE' (controle qualite)
--   addr_id      identifiant d'adresse de la ligne (a charger dans IFS)
--   addr_*       colonnes de l'adresse PHL, deja trimmees / NULLifiees
--
-- ATTENTION : les colonnes phl_address / phl_address_lov / phl_address2 /
-- phl_addr_name heritees de v_customer_source decrivent l'adresse PRINCIPALE,
-- pas la ligne courante. Utiliser les colonnes addr_* dans les procedures.
-- =====================================================

CREATE OR REPLACE VIEW clean_data.v_customer_address_source AS

WITH src AS (
    SELECT *
    FROM clean_data.v_customer_source
    WHERE customer_id IS NOT NULL
)

-- ---------- Branche PHL : toutes les adresses du client rapproche ----------
SELECT
    s.*,
    'PHL'::TEXT                                       AS addr_origin,
    COALESCE(NULLIF(TRIM(ca.address_id), ''), '1')::TEXT AS addr_id,
    NULLIF(TRIM(ca.name), '')::TEXT                   AS addr_name,
    NULLIF(TRIM(ca.address), '')::TEXT                AS addr_address,
    NULLIF(TRIM(ca.address_lov), '')::TEXT            AS addr_address_lov,
    NULLIF(TRIM(ca.address1), '')::TEXT               AS addr_address1,
    NULLIF(TRIM(ca.address2), '')::TEXT               AS addr_address2,
    NULLIF(TRIM(ca.address3), '')::TEXT               AS addr_address3,
    NULLIF(TRIM(ca.address4), '')::TEXT               AS addr_address4,
    NULLIF(TRIM(ca.address5), '')::TEXT               AS addr_address5,
    NULLIF(TRIM(ca.address6), '')::TEXT               AS addr_address6,
    -- CODE POSTAL : la colonne zip_code de PHL est vide sur les 670 lignes,
    -- mais le texte `address` est a largeur fixe et le contient :
    --   1-37 address1 | 38-74 address2 | 75-82 code postal | 83+ ville
    -- Verifie sur la totalite des lignes (address1 et city reconstitues a
    -- l'identique). 646 des 670 adresses ont ainsi un code postal ; sans lui
    -- les procedures retombent sur le fichier puis sur SAP.
    COALESCE(NULLIF(TRIM(ca.zip_code), ''),
             NULLIF(TRIM(substring(ca.address from 75 for 8)), ''))::TEXT AS addr_zip_code,
    NULLIF(TRIM(ca.city), '')::TEXT                   AS addr_city,
    NULLIF(TRIM(ca.county), '')::TEXT                 AS addr_county,
    NULLIF(TRIM(ca.state), '')::TEXT                  AS addr_state,
    NULLIF(TRIM(ca.country), '')::TEXT                AS addr_country,
    NULLIF(UPPER(TRIM(ca.country_db)), '')::TEXT      AS addr_country_db,
    NULLIF(TRIM(ca.ean_location), '')::TEXT           AS addr_ean_location,
    NULLIF(TRIM(ca.jurisdiction_code), '')::TEXT      AS addr_jurisdiction_code,
    -- 'VRAI'/'FAUX' -> booleen IFS attendu en MAJUSCULES
    (CASE UPPER(TRIM(COALESCE(ca.default_domain, '')))
        WHEN 'VRAI'  THEN 'TRUE'
        WHEN 'TRUE'  THEN 'TRUE'
        WHEN 'FAUX'  THEN 'FALSE'
        WHEN 'FALSE' THEN 'FALSE'
     END)::TEXT                                       AS addr_default_domain,
    NULLIF(TRIM(ca.party_type), '')::TEXT             AS addr_party_type,
    NULLIF(UPPER(TRIM(ca.party_type_db)), '')::TEXT   AS addr_party_type_db
FROM src s
JOIN raw_data.client_adresse_phl ca
  ON s.phl_cli_customer_id IS NOT NULL
 AND TRIM(ca.customer_id) = s.phl_cli_customer_id

UNION ALL

-- ---------- Branche FICHIER : clients sans rapprochement PHL ----------
SELECT
    s.*,
    'FILE'::TEXT                                      AS addr_origin,
    s.address_id::TEXT                                AS addr_id,
    NULL::TEXT AS addr_name,
    NULL::TEXT AS addr_address,
    NULL::TEXT AS addr_address_lov,
    NULL::TEXT AS addr_address1,
    NULL::TEXT AS addr_address2,
    NULL::TEXT AS addr_address3,
    NULL::TEXT AS addr_address4,
    NULL::TEXT AS addr_address5,
    NULL::TEXT AS addr_address6,
    NULL::TEXT AS addr_zip_code,
    NULL::TEXT AS addr_city,
    NULL::TEXT AS addr_county,
    NULL::TEXT AS addr_state,
    NULL::TEXT AS addr_country,
    NULL::TEXT AS addr_country_db,
    NULL::TEXT AS addr_ean_location,
    NULL::TEXT AS addr_jurisdiction_code,
    NULL::TEXT AS addr_default_domain,
    NULL::TEXT AS addr_party_type,
    NULL::TEXT AS addr_party_type_db
FROM src s
WHERE s.phl_cli_customer_id IS NULL;

COMMENT ON VIEW clean_data.v_customer_address_source IS
'Adresses du module customerFile, 1 ligne = 1 adresse. Les clients rapproches a PHL reprennent TOUTES leurs adresses raw_data.client_adresse_phl (addr_id = address_id PHL) ; les autres gardent l''unique adresse du fichier. Le client reste identifie par customer_id (numerotation IFS du fichier).';

-- Controles
-- SELECT addr_origin, count(*) AS adresses, count(DISTINCT customer_id) AS clients
--   FROM clean_data.v_customer_address_source GROUP BY 1 ORDER BY 1;
--   Attendu : PHL ~445 adresses / ~90 clients, FILE ~78 adresses / autant de clients.
-- Aucun doublon de cle :
-- SELECT customer_id, addr_id, count(*) FROM clean_data.v_customer_address_source
--   GROUP BY 1,2 HAVING count(*) > 1;
-- L'adresse principale de v_customer_source doit exister dans cette vue :
-- SELECT count(*) FROM clean_data.v_customer_source s
--   WHERE NOT EXISTS (SELECT 1 FROM clean_data.v_customer_address_source a
--                      WHERE a.customer_id = s.customer_id AND a.addr_id = s.address_id);
--   Attendu : 0.
