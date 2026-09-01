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
-- STRUCTURE DE raw_data.client_adresse_phl (rechargee le 2026-09-01, l'ancien
-- format a largeur fixe est conserve sous raw_data.client_adresse_phl_old) :
--   mnemo         code client PHL   -> cle vers client_phl.customer_id
--   id_client     identifiant d'ADRESSE (nommage trompeur) -> addr_id
--   nom, adresse, adresse_suite, code_postal, ville, pays, id_ville (ISO 2)
--   siren, siret, tva
-- Le code postal et la ville sont enfin des colonnes a part entiere : le
-- decoupage a largeur fixe de l'ancienne table (substring 75-82) a disparu.
--
-- REPLI : la nouvelle table ne porte ni address3 a address6, ni county/state,
-- ni ean_location, ni jurisdiction_code, ni indicateur d'adresse par defaut,
-- ni type de tiers. Les colonnes addr_* correspondantes valent NULL et les
-- procedures completent avec le fichier / SAP / la valeur d'ecran.
-- CASCADE (revision 2026-09-01) : sur l'ADRESSE PRINCIPALE le FICHIER fait
-- autorite, PHL ne vient qu'ensuite :
--     FICHIER -> PHL -> SAP (ADRC/KNA1) -> public.get_default_value
-- ATTENTION : le fichier ne decrit QUE l'adresse principale. Ses colonnes
-- (rue, code postal, ville, region) ne doivent jamais etre appliquees aux
-- autres adresses PHL, sous peine de code postal faux (89108 pour une adresse
-- a Bagnolet) : les procedures reservent la branche fichier/SAP aux lignes
-- ou addr_id = address_id.
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
    COALESCE(NULLIF(TRIM(ca.id_client), ''), '1')::TEXT AS addr_id,
    NULLIF(TRIM(ca.nom), '')::TEXT                    AS addr_name,
    -- Texte d'adresse complet reconstitue depuis les colonnes de la nouvelle
    -- table (l'ancienne le portait deja formate, a largeur fixe).
    NULLIF(TRIM(CONCAT_WS(' ', NULLIF(TRIM(ca.adresse), ''),
                               NULLIF(TRIM(ca.adresse_suite), ''),
                               NULLIF(TRIM(ca.code_postal), ''),
                               NULLIF(TRIM(ca.ville), ''))), '')::TEXT AS addr_address,
    NULLIF(TRIM(CONCAT_WS(', ', NULLIF(TRIM(ca.adresse), ''),
                                NULLIF(TRIM(ca.ville), ''),
                                NULLIF(TRIM(ca.code_postal), ''))), '')::TEXT AS addr_address_lov,
    NULLIF(TRIM(ca.adresse), '')::TEXT                AS addr_address1,
    NULLIF(TRIM(ca.adresse_suite), '')::TEXT          AS addr_address2,
    -- address3 a address6 : absentes de la nouvelle table.
    NULL::TEXT                                        AS addr_address3,
    NULL::TEXT                                        AS addr_address4,
    NULL::TEXT                                        AS addr_address5,
    NULL::TEXT                                        AS addr_address6,
    -- CODE POSTAL : colonne a part entiere depuis le rechargement du
    -- 2026-09-01. 646 des 670 adresses en portent un ; sans lui les
    -- procedures retombent sur le fichier puis sur SAP.
    NULLIF(TRIM(ca.code_postal), '')::TEXT            AS addr_zip_code,
    NULLIF(TRIM(ca.ville), '')::TEXT                  AS addr_city,
    -- county / state : absents de la nouvelle table. Les procedures
    -- reconstituent le departement depuis le code postal francais.
    NULL::TEXT                                        AS addr_county,
    NULL::TEXT                                        AS addr_state,
    NULLIF(TRIM(ca.pays), '')::TEXT                   AS addr_country,
    -- id_ville porte en realite le code pays ISO 2 (nommage trompeur).
    -- ANOMALIE SOURCE : 4 adresses 'COTE D''IVOIRE' portent id_ville = 'FR'.
    NULLIF(UPPER(TRIM(ca.id_ville)), '')::TEXT        AS addr_country_db,
    -- ean_location / jurisdiction_code / indicateur d'adresse par defaut /
    -- type de tiers : absents de la nouvelle table -> fichier ou valeur d'ecran.
    NULL::TEXT                                        AS addr_ean_location,
    NULL::TEXT                                        AS addr_jurisdiction_code,
    NULL::TEXT                                        AS addr_default_domain,
    NULL::TEXT                                        AS addr_party_type,
    NULL::TEXT                                        AS addr_party_type_db
FROM src s
-- CLE : mnemo = code client PHL, id_client = identifiant d'ADRESSE.
JOIN raw_data.client_adresse_phl ca
  ON s.phl_cli_customer_id IS NOT NULL
 AND TRIM(ca.mnemo) = s.phl_cli_customer_id

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
--   Attendu (2026-09-01) : PHL 455 adresses / 92 clients, FILE 104 adresses.
--   Total 559 lignes.
-- Aucun doublon de cle :
-- SELECT customer_id, addr_id, count(*) FROM clean_data.v_customer_address_source
--   GROUP BY 1,2 HAVING count(*) > 1;
-- L'adresse principale de v_customer_source doit exister dans cette vue :
-- SELECT count(*) FROM clean_data.v_customer_source s
--   WHERE NOT EXISTS (SELECT 1 FROM clean_data.v_customer_address_source a
--                      WHERE a.customer_id = s.customer_id AND a.addr_id = s.address_id);
--   Attendu : 0.
