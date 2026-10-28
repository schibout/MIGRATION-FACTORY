-- ============================================================================
-- Alimentation de clean_data.ifs_fournisseurs_perimetre
-- Perimetre fournisseurs IFS = fichier de selection + fournisseurs crees dans
-- SAP apres la date d'arrete du fichier. La colonne `source` dit d'ou vient
-- chaque ligne :
--   FICHIER     : present dans raw_data.selection_fournisseurs_stg
--   SAP_NOUVEAU : absent du fichier, cree dans SAP (lfa1.erdat) a partir de la
--                 date d'arrete, non marque pour suppression
-- Memes regles que clean_data.ifs_fournisseurs (script 01) : fichier > SAP,
-- coordonnees bancaires SAP. Numero IFS : uniquement celui du fichier (NULL
-- pour un SAP_NOUVEAU) ; ifs_fournisseur_id_map n'est ni lue ni alimentee.
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
       -- Le staging s'empile a chaque import : une ligne par fournisseur, la
       -- plus renseignee puis la plus recente (meme regle que le script 01)
       SELECT DISTINCT ON (LPAD(TRIM(stg.numero_compte_sap), 10, '0'))
              LPAD(TRIM(stg.numero_compte_sap), 10, '0') AS cle_lifnr, stg.*
         FROM raw_data.selection_fournisseurs_stg stg
        WHERE NULLIF(TRIM(stg.numero_compte_sap), '') IS NOT NULL
        ORDER BY LPAD(TRIM(stg.numero_compte_sap), 10, '0'),
                 (SELECT COUNT(*) FROM jsonb_each_text(to_jsonb(stg)) j
                   WHERE NULLIF(TRIM(j.value), '') IS NOT NULL) DESC,
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
   -- Une seule requete pour les deux sources : pour un SAP_NOUVEAU, sf est
   -- NULL et chaque COALESCE retombe sur la valeur SAP.
   SELECT
      p.lifnr,
      p.source,
      -- Numero IFS : uniquement celui du fichier, NULL pour un SAP_NOUVEAU
      NULLIF(TRIM(sf.numero_compte_ifs), ''),
      public.get_default_value('clean_data.ifs_fournisseurs', 'company'),
      COALESCE(NULLIF(TRIM(a.adrnr), ''), public.get_default_value('clean_data.ifs_fournisseurs', 'address_id')),

      COALESCE(NULLIF(TRIM(sf.denomination_sociale), ''), a.name1),
      COALESCE(NULLIF(TRIM(sf.libelle_concatene), ''),
               NULLIF(TRIM(CONCAT_WS(' ', sf.numero_voie, sf.indice_numero_voie, sf.type_voie, sf.libelle_voie)), ''),
               a.stras),
      NULLIF(TRIM(sf.complement_adresse), ''),
      COALESCE(NULLIF(TRIM(sf.localite), ''), a.ort01),
      COALESCE(NULLIF(TRIM(sf.code_postal), ''), a.pstlz),
      COALESCE(NULLIF(TRIM(sf.code_pays), ''), a.land1),

      COALESCE(NULLIF(TRIM(sf.numero_siret), ''), a.stcd1),
      NULLIF(TRIM(sf.numero_siren), ''),
      COALESCE(NULLIF(TRIM(sf.numero_tva_intra), ''), a.stceg),
      NULLIF(TRIM(sf.code_tva_ifs), ''),
      NULLIF(TRIM(sf.code_tva_sap), ''),
      NULLIF(TRIM(sf.france_etranger), ''),

      sap_data.societe,
      sap_data.organisation_achats,
      COALESCE(NULLIF(TRIM(sf.condition_paiement_ifs), ''), sap_data.conditions_paiement_compta),
      COALESCE(NULLIF(TRIM(sf.condition_paiement_ifs), ''), sap_data.conditions_paiement_achats),
      NULLIF(TRIM(sf.condition_paiement_sap), ''),
      NULLIF(TRIM(sf.mode_paiement), ''),
      sap_data.incoterms_1,
      sap_data.incoterms_2,

      COALESCE(NULLIF(TRIM(sf.telephone_1), ''), a.telf1),
      COALESCE(NULLIF(TRIM(sf.telephone_2), ''), NULLIF(TRIM(sf.telephone_3), ''), a.telf2),
      NULLIF(TRIM(sf.telephone_3), ''),
      NULLIF(TRIM(sf.email), ''),
      NULLIF(TRIM(sf.critere_recherche), ''),
      NULLIF(TRIM(sf.langue), ''),
      COALESCE(public.get_transcodification('LANGUAGE', NULLIF(TRIM(sf.langue), '')),
               public.get_transcodification('LANGUAGE', a.spras)),

      sap_data.destinataire_paiement,
      clean_data.fn_date_sap(a.erdat),

      COALESCE(NULLIF(TRIM(sf.iban_paiement), ''), banque.iban),
      COALESCE(NULLIF(TRIM(sf.swift_bic), ''),     banque.swift),
      COALESCE(NULLIF(TRIM(sf.nom_banque), ''),    banque.nom_banque),
      banque.compte,
      banque.code_banque,
      banque.pays_banque,
      banque.titulaire,
      v_date_arrete
   FROM perimetre p
   LEFT JOIN fichier sf ON sf.cle_lifnr = p.lifnr
   LEFT JOIN raw_data.lfa1 a ON a.lifnr::text = p.lifnr
   LEFT JOIN LATERAL (
       SELECT string_agg(DISTINCT b.bukrs::text, ', ' ORDER BY b.bukrs::text) AS societe,
              m.ekorg AS organisation_achats,
              min(b.zterm::text) AS conditions_paiement_compta,
              m.zterm AS conditions_paiement_achats,
              m.inco1 AS incoterms_1,
              m.inco2 AS incoterms_2,
              min(b.lnrzb) AS destinataire_paiement
         FROM raw_data.lfb1 b
         JOIN raw_data.lfm1 m ON b.mandt::text = m.mandt::text AND b.lifnr::text = m.lifnr::text
        WHERE b.lifnr::text = p.lifnr
          AND m.ekorg::text = (SELECT min(m2.ekorg::text) FROM raw_data.lfm1 m2
                                WHERE m2.mandt::text = m.mandt::text AND m2.lifnr::text = m.lifnr::text)
        GROUP BY m.ekorg, m.zterm, m.inco1, m.inco2
        LIMIT 1
   ) sap_data ON TRUE
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
