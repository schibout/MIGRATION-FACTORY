-- ============================================================================
-- Alimentation de clean_data.ifs_fournisseurs_perimetre
-- Perimetre fournisseurs IFS = fichier de selection + fournisseurs crees dans
-- SAP apres la date d'arrete du fichier. La colonne `source` dit d'ou vient
-- chaque ligne :
--   FICHIER     : present dans raw_data.selection_fournisseurs_stg
--   SAP_NOUVEAU : absent du fichier, cree dans SAP (lfa1.erdat) a partir de la
--                 date d'arrete, non marque pour suppression
-- Du fichier on ne lit que le n° SAP et le n° IFS (NULL pour un SAP_NOUVEAU ;
-- ifs_fournisseur_id_map n'est ni lue ni alimentee). Tout le reste vient de
-- SAP (lfa1, lfb1, lfm1, adrc, adr6, coordonnees bancaires lfbk/tiban/bnka),
-- avec les transcodifications COUNTRY, PAY_TERM (migration 125) et LANGUAGE.
-- Prerequis : script 01 compile (fn_coordonnees_bancaires_sap).
-- ============================================================================

CREATE TABLE IF NOT EXISTS clean_data.ifs_fournisseurs_perimetre (
    numero_compte_fournisseur  VARCHAR      NOT NULL,
    source                     VARCHAR(20)  NOT NULL
        CONSTRAINT ck_ifs_fournisseurs_perimetre_source CHECK (source IN ('FICHIER', 'SAP_NOUVEAU')),
    numero_compte_ifs          VARCHAR(20),
    company                    VARCHAR(10),
    address_id                 VARCHAR(50),
    nom_1                      VARCHAR,
    rue                        VARCHAR,
    complement_adresse         VARCHAR(255),
    localite                   VARCHAR,
    code_postal                VARCHAR,
    cle_pays                   VARCHAR,
    siret                      VARCHAR,
    numero_siren               VARCHAR(20),
    tva                        VARCHAR,
    code_tva_ifs               VARCHAR(20),
    code_tva_sap               VARCHAR(20),
    france_etranger            VARCHAR(20),
    societe                    TEXT,
    organisation_achats        VARCHAR,
    conditions_paiement_compta TEXT,
    conditions_paiement_achats VARCHAR,
    condition_paiement_sap     VARCHAR(50),
    mode_paiement              VARCHAR(50),
    incoterms_1                VARCHAR,
    incoterms_2                VARCHAR,
    telephone_1                VARCHAR,
    telephone_2                VARCHAR,
    telephone_3                VARCHAR(50),
    email                      VARCHAR(255),
    critere_recherche          VARCHAR(255),
    langue                     VARCHAR(10),
    language_sap               VARCHAR,
    destinataire_paiement      VARCHAR(60),
    date_creation_sap          DATE,
    iban_paiement              VARCHAR(50),
    swift_bic                  VARCHAR(20),
    nom_banque                 VARCHAR(100),
    numero_compte_bancaire     VARCHAR(20),
    code_banque                VARCHAR(20),
    pays_banque                VARCHAR(3),
    titulaire_compte           VARCHAR(60),
    charge_le                  TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_ifs_fournisseurs_perimetre PRIMARY KEY (numero_compte_fournisseur)
);

-- Date d'arrete utilisee au dernier chargement (ecran Finance > Fournisseurs)
ALTER TABLE clean_data.ifs_fournisseurs_perimetre ADD COLUMN IF NOT EXISTS date_arrete DATE;

COMMENT ON TABLE clean_data.ifs_fournisseurs_perimetre IS
    'Perimetre fournisseurs IFS : fichier de selection + fournisseurs crees dans SAP apres la date d''arrete. Rechargee en entier par clean_data.alimenter_ifs_fournisseurs_perimetre().';
COMMENT ON COLUMN clean_data.ifs_fournisseurs_perimetre.source IS
    'FICHIER (selection_fournisseurs_stg) ou SAP_NOUVEAU (cree dans SAP depuis la date d''arrete, absent du fichier)';
COMMENT ON COLUMN clean_data.ifs_fournisseurs_perimetre.numero_compte_fournisseur IS
    'LIFNR SAP complete a 10 caracteres';

-- lfa1.erdat est du texte, au format SAP (YYYYMMDD) ou ISO selon l'extraction
CREATE OR REPLACE FUNCTION clean_data.fn_date_sap(p_valeur TEXT)
RETURNS DATE
LANGUAGE sql
IMMUTABLE
AS $function$
    SELECT CASE
        WHEN TRIM(COALESCE(p_valeur, '')) ~ '^[0-9]{8}$' AND TRIM(p_valeur) <> '00000000'
            THEN TO_DATE(TRIM(p_valeur), 'YYYYMMDD')
        WHEN TRIM(COALESCE(p_valeur, '')) ~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}$'
            THEN TO_DATE(TRIM(p_valeur), 'YYYY-MM-DD')
    END;
$function$;

-- Ancienne signature sans parametre : sinon un appel sans argument serait ambigu
DROP FUNCTION IF EXISTS clean_data.alimenter_ifs_fournisseurs_perimetre();

-- p_date_arrete : saisie dans l'ecran Finance > Fournisseurs ; NULL = valeur
-- de l'ecran /configuration/valeurs-defaut (meme parametre que le script 01).
-- Retourne le nombre de lignes chargees.
CREATE OR REPLACE FUNCTION clean_data.alimenter_ifs_fournisseurs_perimetre(p_date_arrete DATE DEFAULT NULL)
 RETURNS integer
 LANGUAGE plpgsql
AS $function$
DECLARE
   v_date_arrete CONSTANT DATE := COALESCE(
       p_date_arrete,
       NULLIF(TRIM(public.get_default_value('clean_data.ifs_fournisseurs', 'date_arrete')), '')::DATE,
       DATE '2025-10-07');
   v_nb_fichier INTEGER;
   v_nb_sap INTEGER;
BEGIN
   TRUNCATE TABLE clean_data.ifs_fournisseurs_perimetre;

   INSERT INTO clean_data.ifs_fournisseurs_perimetre (
      numero_compte_fournisseur, source, numero_compte_ifs, company, address_id,
      nom_1, rue, complement_adresse, localite, code_postal, cle_pays,
      siret, numero_siren, tva, code_tva_ifs, code_tva_sap, france_etranger,
      societe, organisation_achats, conditions_paiement_compta, conditions_paiement_achats,
      condition_paiement_sap, mode_paiement, incoterms_1, incoterms_2,
      telephone_1, telephone_2, telephone_3, email, critere_recherche, langue, language_sap,
      destinataire_paiement, date_creation_sap,
      iban_paiement, swift_bic, nom_banque, numero_compte_bancaire, code_banque, pays_banque, titulaire_compte,
      date_arrete
   )
   WITH fichier AS (
       -- Du fichier on ne garde QUE le n° SAP et le n° IFS (demande du
       -- 2026-10-30 : ses textes sont mal encodes, « FranÃ§ais »). Le staging
       -- s'empile a chaque import : une ligne par fournisseur, celle qui porte
       -- un n° IFS puis la plus recente.
       SELECT DISTINCT ON (LPAD(TRIM(stg.numero_compte_sap), 10, '0'))
              LPAD(TRIM(stg.numero_compte_sap), 10, '0') AS cle_lifnr,
              NULLIF(TRIM(stg.numero_compte_ifs), '') AS numero_compte_ifs
         FROM raw_data.selection_fournisseurs_stg stg
        WHERE NULLIF(TRIM(stg.numero_compte_sap), '') IS NOT NULL
        ORDER BY LPAD(TRIM(stg.numero_compte_sap), 10, '0'),
                 (NULLIF(TRIM(stg.numero_compte_ifs), '') IS NULL),
                 stg.ctid DESC
   ),
   perimetre AS (
       SELECT f.cle_lifnr AS lifnr, 'FICHIER' AS source FROM fichier f
       UNION ALL
       SELECT a.lifnr::text, 'SAP_NOUVEAU'
         FROM raw_data.lfa1 a
        WHERE clean_data.fn_date_sap(a.erdat) >= v_date_arrete
          AND COALESCE(a.loevm, '') <> 'X'
          -- Employes geres en fournisseur exclus (groupes de comptes T077Y :
          -- ZPER / ZPE1 « Personnel (AGORA) gere en fourn », P001 « Fournisseurs personnel »)
          AND COALESCE(a.ktokk, '') NOT IN ('ZPER', 'ZPE1', 'P001')
          AND NOT EXISTS (SELECT 1 FROM fichier f WHERE f.cle_lifnr = a.lifnr::text)
   )
   -- Toutes les donnees viennent de SAP, pour les deux sources ; transcodifications
   -- COUNTRY (pays), PAY_TERM (conditions de paiement), LANGUAGE (langue). Code
   -- non transcode -> NULL (le code SAP reste visible dans condition_paiement_sap
   -- / langue), sauf le pays : COUNTRY est l'identite, repli sur le code SAP.
   SELECT
      p.lifnr,
      p.source,
      -- Numero IFS : uniquement celui du fichier, NULL pour un SAP_NOUVEAU
      sf.numero_compte_ifs,
      public.get_default_value('clean_data.ifs_fournisseurs', 'company'),
      COALESCE(NULLIF(TRIM(a.adrnr), ''), public.get_default_value('clean_data.ifs_fournisseurs', 'address_id')),

      a.name1,
      a.stras,
      NULLIF(CONCAT_WS(' ', NULLIF(TRIM(adr.str_suppl1), ''), NULLIF(TRIM(adr.str_suppl2), '')), ''),
      a.ort01,
      a.pstlz,
      COALESCE(public.get_transcodification('COUNTRY', a.land1), a.land1),

      NULLIF(TRIM(a.stcd1), ''),
      -- SIREN = 9 premiers chiffres d'un SIRET francais
      CASE WHEN TRIM(a.stcd1) ~ '^[0-9]{14}$' THEN LEFT(TRIM(a.stcd1), 9) END,
      NULLIF(TRIM(a.stceg), ''),
      -- Codes TVA : arbitres par le metier dans le fichier, sans source SAP
      -- identifiee -> non repris
      NULL,
      NULL,
      CASE WHEN a.land1 = 'FR' THEN 'Français' WHEN NULLIF(TRIM(a.land1), '') IS NOT NULL THEN 'Etranger' END,

      cpta.societe,
      achats.ekorg,
      public.get_transcodification('PAY_TERM', cpta.zterm),
      public.get_transcodification('PAY_TERM', achats.zterm),
      cpta.zterm,
      cpta.zwels,
      achats.inco1,
      achats.inco2,

      NULLIF(TRIM(a.telf1), ''),
      NULLIF(TRIM(a.telf2), ''),
      NULL,  -- telephone_3 : pas de 3e numero dans LFA1 (telfx = fax)
      mail.smtp_addr,
      NULLIF(TRIM(a.sortl), ''),
      a.spras,
      public.get_transcodification('LANGUAGE', a.spras),

      cpta.lnrzb,
      clean_data.fn_date_sap(a.erdat),

      banque.iban,
      banque.swift,
      banque.nom_banque,
      banque.compte,
      banque.code_banque,
      banque.pays_banque,
      banque.titulaire,
      v_date_arrete
   FROM perimetre p
   LEFT JOIN fichier sf ON sf.cle_lifnr = p.lifnr
   LEFT JOIN raw_data.lfa1 a ON a.lifnr::text = p.lifnr
   -- Donnees comptables : societe STJN en priorite, toutes les societes listees
   LEFT JOIN LATERAL (
       SELECT b.zterm::text AS zterm, NULLIF(TRIM(b.zwels), '') AS zwels, b.lnrzb,
              string_agg(b.bukrs::text, ', ') OVER () AS societe
         FROM raw_data.lfb1 b
        WHERE b.lifnr::text = p.lifnr
        ORDER BY (b.bukrs = 'STJN') DESC, b.bukrs
        LIMIT 1
   ) cpta ON TRUE
   -- Donnees d'achat : plus petite organisation d'achats
   LEFT JOIN LATERAL (
       SELECT m.ekorg, m.zterm::text AS zterm, m.inco1, m.inco2
         FROM raw_data.lfm1 m
        WHERE m.lifnr::text = p.lifnr
        ORDER BY m.ekorg
        LIMIT 1
   ) achats ON TRUE
   LEFT JOIN LATERAL (
       SELECT c.str_suppl1, c.str_suppl2 FROM raw_data.adrc c
        WHERE c.addrnumber = a.adrnr LIMIT 1
   ) adr ON TRUE
   -- E-mail de l'adresse (pas d'une personne de contact), celui par defaut d'abord
   LEFT JOIN LATERAL (
       SELECT NULLIF(TRIM(e.smtp_addr), '') AS smtp_addr FROM raw_data.adr6 e
        WHERE e.addrnumber = a.adrnr AND COALESCE(TRIM(e.persnumber), '') = ''
          AND NULLIF(TRIM(e.smtp_addr), '') IS NOT NULL
        ORDER BY (e.flgdefault = 'X') DESC, e.consnumber
        LIMIT 1
   ) mail ON TRUE
   LEFT JOIN LATERAL clean_data.fn_coordonnees_bancaires_sap(p.lifnr) banque ON TRUE;

   SELECT COUNT(*) FILTER (WHERE source = 'FICHIER'),
          COUNT(*) FILTER (WHERE source = 'SAP_NOUVEAU')
     INTO v_nb_fichier, v_nb_sap
     FROM clean_data.ifs_fournisseurs_perimetre;

   RAISE NOTICE 'ifs_fournisseurs_perimetre : % FICHIER + % SAP_NOUVEAU (crees depuis le %) = % lignes',
                v_nb_fichier, v_nb_sap, v_date_arrete, v_nb_fichier + v_nb_sap;
   RETURN v_nb_fichier + v_nb_sap;
END;
$function$;
