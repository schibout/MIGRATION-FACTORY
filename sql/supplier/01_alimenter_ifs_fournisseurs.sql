-- ============================================================================
-- Alimentation de clean_data.ifs_fournisseurs
-- Source pilote  : raw_data.selection_fournisseurs_stg (fichier de selection)
-- Enrichissement : raw_data.lfa1 / lfb1 / lfm1 (LEFT JOIN, ne filtrent jamais)
-- Complement     : fournisseurs crees dans SAP depuis V_DATE_CREATION_MIN et
--                  absents du fichier (source = 'SAP_NOUVEAU')
-- ============================================================================

-- ----------------------------------------------------------------------------
-- Colonnes reprises du fichier de selection (structure alignee sur le staging)
-- ----------------------------------------------------------------------------
ALTER TABLE clean_data.ifs_fournisseurs
    ADD COLUMN IF NOT EXISTS numero_compte_ifs      VARCHAR(20),
    ADD COLUMN IF NOT EXISTS code_tva_sap           VARCHAR(20),
    ADD COLUMN IF NOT EXISTS france_etranger        VARCHAR(20),
    ADD COLUMN IF NOT EXISTS numero_siren           VARCHAR(20),
    ADD COLUMN IF NOT EXISTS complement_adresse     VARCHAR(255),
    ADD COLUMN IF NOT EXISTS condition_paiement_sap VARCHAR(50),
    ADD COLUMN IF NOT EXISTS telephone_3            VARCHAR(50),
    ADD COLUMN IF NOT EXISTS critere_recherche      VARCHAR(255),
    ADD COLUMN IF NOT EXISTS langue                 VARCHAR(10),
    ADD COLUMN IF NOT EXISTS email                  VARCHAR(255),
    ADD COLUMN IF NOT EXISTS iban_paiement          VARCHAR(50),
    ADD COLUMN IF NOT EXISTS swift_bic              VARCHAR(20),
    ADD COLUMN IF NOT EXISTS nom_banque             VARCHAR(100),
    ADD COLUMN IF NOT EXISTS mode_paiement          VARCHAR(50),
    ADD COLUMN IF NOT EXISTS source                 VARCHAR(20);

COMMENT ON COLUMN clean_data.ifs_fournisseurs.source IS
    'Origine de la ligne : FICHIER (selection_fournisseurs_stg) ou SAP_NOUVEAU (cree dans SAP apres la selection)';
COMMENT ON COLUMN clean_data.ifs_fournisseurs.numero_compte_ifs IS
    'Identifiant IFS arbitre par le metier, repris tel quel du fichier de selection (600001+)';
COMMENT ON COLUMN clean_data.ifs_fournisseurs.numero_compte_fournisseur IS
    'Numero de compte SAP (LIFNR) complete a 10 caracteres, cle de jointure vers raw_data.lfa1';

CREATE OR REPLACE FUNCTION clean_data.alimenter_ifs_fournisseurs()
 RETURNS void
 LANGUAGE plpgsql
AS $function$
DECLARE
   -- Date de création SAP à partir de laquelle un fournisseur absent du fichier
   -- de sélection est quand même repris (le fichier a été arrêté avant).
   v_date_creation_min CONSTANT DATE := DATE '2025-10-07';
   -- Dernier identifiant IFS attribué par le fichier : les fournisseurs ajoutés
   -- depuis SAP poursuivent la séquence à partir de là.
   v_max_ifs INTEGER;
   v_nb_fichier INTEGER := 0;
   v_nb_sap INTEGER := 0;
BEGIN
   -- Vider et réinsérer
   TRUNCATE TABLE clean_data.ifs_fournisseurs;
   -- Insérer données de base depuis selection_fournisseurs_stg (source principale)
   -- avec enrichissement depuis les tables SAP (LEFT JOIN)
   INSERT INTO clean_data.ifs_fournisseurs (company,
      numero_compte_fournisseur, numero_compte_ifs, address_id, nom_1, rue, localite, code_postal,
      cle_pays, siret, tva, code_tva_ifs, societe, organisation_achats,
      conditions_paiement_compta, conditions_paiement_achats,
      incoterms_1, incoterms_2, telephone_1, telephone_2, date_creation_sap,
      destinataire_paiement, language_sap,
      code_tva_sap, france_etranger, numero_siren, complement_adresse,
      condition_paiement_sap, telephone_3, critere_recherche, langue,
      email, iban_paiement, swift_bic, nom_banque, mode_paiement, source
   )
   SELECT
      public.get_default_value('clean_data.ifs_fournisseurs', 'company', 'TRIMET') as company,

      -- Numéro SAP complété à 10 caractères : le staging le porte non complété
      -- ("45036"), alors que lfa1.lifnr et les scripts 03->15 attendent la forme
      -- SAP ("0000045036"). Sans le LPAD, aucune jointure SAP ne remonte.
      k.lifnr as numero_compte_fournisseur,

      -- Identifiant IFS arbitré par le métier, repris tel quel du fichier
      NULLIF(TRIM(sf.numero_compte_ifs), '') as numero_compte_ifs,

        public.get_default_value('clean_data.ifs_fournisseurs', 'address_id', '01') as address_id,

      -- === PRIORITÉ 1: selection_fournisseurs_stg | PRIORITÉ 2: SAP ===

      -- Nom: selection_fournisseurs_stg.denomination_sociale > SAP.name1
      COALESCE(NULLIF(TRIM(sf.denomination_sociale), ''), a.name1) as nom_1,

      -- Rue: selection_fournisseurs_stg (libelle_concatene ou construction) > SAP.stras
      COALESCE(
          NULLIF(TRIM(sf.libelle_concatene), ''),
          NULLIF(TRIM(CONCAT_WS(' ', sf.numero_voie, sf.indice_numero_voie, sf.type_voie, sf.libelle_voie)), ''),
          a.stras
      ) as rue,

      -- Localité: selection_fournisseurs_stg.localite > SAP.ort01
      COALESCE(NULLIF(TRIM(sf.localite), ''), a.ort01) as localite,

      -- Code postal: selection_fournisseurs_stg.code_postal > SAP.pstlz
      COALESCE(NULLIF(TRIM(sf.code_postal), ''), a.pstlz) as code_postal,

      -- Pays: selection_fournisseurs_stg.code_pays > SAP.land1
      COALESCE(NULLIF(TRIM(sf.code_pays), ''), a.land1) as cle_pays,

      -- SIRET: selection_fournisseurs_stg.numero_siret > SAP.stcd1
      COALESCE(NULLIF(TRIM(sf.numero_siret), ''), a.stcd1) as siret,

      -- TVA: selection_fournisseurs_stg.numero_tva_intra > SAP.stceg
      COALESCE(NULLIF(TRIM(sf.numero_tva_intra), ''), a.stceg) as tva,

      -- Code TVA IFS: selection_fournisseurs_stg
      NULLIF(TRIM(sf.code_tva_ifs), '') as code_tva_ifs,

      -- Société: uniquement SAP (pas dans selection_fournisseurs_stg)
      sap_data.societe as societe,

      -- Organisation achats: uniquement SAP
      sap_data.organisation_achats,

      -- Conditions paiement: selection_fournisseurs_stg > SAP
      COALESCE(NULLIF(TRIM(sf.condition_paiement_ifs), ''), sap_data.conditions_paiement_compta) as conditions_paiement_compta,
      COALESCE(NULLIF(TRIM(sf.condition_paiement_ifs), ''), sap_data.conditions_paiement_achats) as conditions_paiement_achats,

      -- Incoterms: uniquement SAP
      sap_data.incoterms_1,
      sap_data.incoterms_2,

      -- Téléphones: selection_fournisseurs_stg > SAP
      COALESCE(NULLIF(TRIM(sf.telephone_1), ''), a.telf1) as telephone_1,
      COALESCE(NULLIF(TRIM(sf.telephone_2), ''), NULLIF(TRIM(sf.telephone_3), ''), a.telf2) as telephone_2,

      -- Date création: uniquement SAP
      -- lfa1.erdat est stocké en texte : selon l'extraction il arrive au format
      -- SAP brut (YYYYMMDD) ou déjà normalisé en ISO (YYYY-MM-DD). On teste le
      -- format avant conversion, sinon TO_DATE(...,'YYYYMMDD') plante sur l'ISO
      -- ("date/time field value out of range"). Le staging ne portant pas de
      -- date d'import, un format inattendu donne NULL.
      CASE
          WHEN TRIM(COALESCE(a.erdat, '')) ~ '^[0-9]{8}$' AND TRIM(a.erdat) <> '00000000'
              THEN TO_DATE(TRIM(a.erdat), 'YYYYMMDD')
          WHEN TRIM(COALESCE(a.erdat, '')) ~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}$'
              THEN TO_DATE(TRIM(a.erdat), 'YYYY-MM-DD')
          ELSE NULL
      END as date_creation_sap,

      -- Destinataire paiement: uniquement SAP
      sap_data.destinataire_paiement,

      -- Langue: selection_fournisseurs_stg.langue > SAP.spras
      COALESCE(
          public.get_transcodification('LANGUAGE', NULLIF(TRIM(sf.langue), '')),
          public.get_transcodification('LANGUAGE', a.spras)
      ) as language_sap,

      -- === Colonnes reprises telles quelles du fichier de sélection ===
      NULLIF(TRIM(sf.code_tva_sap), '')           as code_tva_sap,
      NULLIF(TRIM(sf.france_etranger), '')        as france_etranger,
      NULLIF(TRIM(sf.numero_siren), '')           as numero_siren,
      NULLIF(TRIM(sf.complement_adresse), '')     as complement_adresse,
      NULLIF(TRIM(sf.condition_paiement_sap), '') as condition_paiement_sap,
      NULLIF(TRIM(sf.telephone_3), '')            as telephone_3,
      NULLIF(TRIM(sf.critere_recherche), '')      as critere_recherche,
      NULLIF(TRIM(sf.langue), '')                 as langue,
      NULLIF(TRIM(sf.email), '')                  as email,
      NULLIF(TRIM(sf.iban_paiement), '')          as iban_paiement,
      NULLIF(TRIM(sf.swift_bic), '')              as swift_bic,
      NULLIF(TRIM(sf.nom_banque), '')             as nom_banque,
      NULLIF(TRIM(sf.mode_paiement), '')          as mode_paiement,
      'FICHIER'                                   as source

   FROM raw_data.selection_fournisseurs_stg sf
   CROSS JOIN LATERAL (
       SELECT LPAD(TRIM(sf.numero_compte_sap), 10, '0') as lifnr
   ) k
   LEFT JOIN raw_data.lfa1 a ON a.lifnr::text = k.lifnr
   LEFT JOIN LATERAL (
       -- Sous-requête pour récupérer les données agrégées SAP (fallback si pas dans selection_fournisseurs_stg)
       SELECT
           string_agg(DISTINCT b.bukrs::text, ', '::text ORDER BY (b.bukrs::text)) as societe,
           m.ekorg as organisation_achats,
           min(b.zterm::text) as conditions_paiement_compta,
           m.zterm as conditions_paiement_achats,
           m.inco1 as incoterms_1,
           m.inco2 as incoterms_2,
           min(b.lnrzb) as destinataire_paiement
       FROM raw_data.lfb1 b
       JOIN raw_data.lfm1 m ON b.mandt::text = m.mandt::text AND b.lifnr::text = m.lifnr::text
       WHERE b.lifnr::text = k.lifnr
         AND m.ekorg::text = (
             SELECT min(m2.ekorg::text)
             FROM raw_data.lfm1 m2
             WHERE m2.mandt::text = m.mandt::text AND m2.lifnr::text = m.lifnr::text
         )
       GROUP BY m.ekorg, m.zterm, m.inco1, m.inco2
       LIMIT 1
   ) sap_data ON TRUE;

   GET DIAGNOSTICS v_nb_fichier = ROW_COUNT;

   -- =========================================================================
   -- Fournisseurs créés dans SAP APRÈS l'arrêté du fichier de sélection
   -- =========================================================================
   -- Le fichier a figé le périmètre à une date donnée. Les fournisseurs créés
   -- dans SAP depuis v_date_creation_min et absents du fichier sont repris ici,
   -- avec les seules données SAP (le fichier ne les connaît pas : ni IBAN, ni
   -- email, ni code TVA IFS...).
   --
   -- Identifiant IFS : le fichier attribue 600000 + rang par LIFNR croissant
   -- (règle vérifiée sur les 1716 lignes). On poursuit la même séquence.
   SELECT COALESCE(MAX(numero_compte_ifs::INTEGER), 600000)
     INTO v_max_ifs
     FROM clean_data.ifs_fournisseurs
    WHERE numero_compte_ifs ~ '^[0-9]+$';

   INSERT INTO clean_data.ifs_fournisseurs (company,
      numero_compte_fournisseur, numero_compte_ifs, address_id, nom_1, rue, localite, code_postal,
      cle_pays, siret, tva, societe, organisation_achats,
      conditions_paiement_compta, conditions_paiement_achats,
      incoterms_1, incoterms_2, telephone_1, telephone_2, date_creation_sap,
      destinataire_paiement, language_sap, source
   )
   SELECT
      public.get_default_value('clean_data.ifs_fournisseurs', 'company', 'TRIMET') as company,
      a.lifnr::text as numero_compte_fournisseur,

      -- Poursuite de la séquence du fichier, dans l'ordre du numéro SAP
      (v_max_ifs + ROW_NUMBER() OVER (ORDER BY a.lifnr::text))::text as numero_compte_ifs,

      public.get_default_value('clean_data.ifs_fournisseurs', 'address_id', '01') as address_id,

      -- Uniquement SAP : le fichier de sélection ne connaît pas ces fournisseurs
      a.name1 as nom_1,
      a.stras as rue,
      a.ort01 as localite,
      a.pstlz as code_postal,
      a.land1 as cle_pays,
      a.stcd1 as siret,
      a.stceg as tva,
      sap_data.societe,
      sap_data.organisation_achats,
      sap_data.conditions_paiement_compta,
      sap_data.conditions_paiement_achats,
      sap_data.incoterms_1,
      sap_data.incoterms_2,
      a.telf1 as telephone_1,
      a.telf2 as telephone_2,
      CASE
          WHEN TRIM(COALESCE(a.erdat, '')) ~ '^[0-9]{8}$' AND TRIM(a.erdat) <> '00000000'
              THEN TO_DATE(TRIM(a.erdat), 'YYYYMMDD')
          WHEN TRIM(COALESCE(a.erdat, '')) ~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}$'
              THEN TO_DATE(TRIM(a.erdat), 'YYYY-MM-DD')
          ELSE NULL
      END as date_creation_sap,
      sap_data.destinataire_paiement,
      public.get_transcodification('LANGUAGE', a.spras) as language_sap,
      'SAP_NOUVEAU' as source

   FROM raw_data.lfa1 a
   LEFT JOIN LATERAL (
       SELECT
           string_agg(DISTINCT b.bukrs::text, ', '::text ORDER BY (b.bukrs::text)) as societe,
           m.ekorg as organisation_achats,
           min(b.zterm::text) as conditions_paiement_compta,
           m.zterm as conditions_paiement_achats,
           m.inco1 as incoterms_1,
           m.inco2 as incoterms_2,
           min(b.lnrzb) as destinataire_paiement
       FROM raw_data.lfb1 b
       JOIN raw_data.lfm1 m ON b.mandt::text = m.mandt::text AND b.lifnr::text = m.lifnr::text
       WHERE b.lifnr::text = a.lifnr::text
         AND m.ekorg::text = (
             SELECT min(m2.ekorg::text)
             FROM raw_data.lfm1 m2
             WHERE m2.mandt::text = m.mandt::text AND m2.lifnr::text = m.lifnr::text
         )
       GROUP BY m.ekorg, m.zterm, m.inco1, m.inco2
       LIMIT 1
   ) sap_data ON TRUE
   WHERE
      -- Date de création SAP : erdat est stocké en texte (YYYYMMDD ou ISO)
      CASE
          WHEN TRIM(COALESCE(a.erdat, '')) ~ '^[0-9]{8}$' AND TRIM(a.erdat) <> '00000000'
              THEN TO_DATE(TRIM(a.erdat), 'YYYYMMDD')
          WHEN TRIM(COALESCE(a.erdat, '')) ~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}$'
              THEN TO_DATE(TRIM(a.erdat), 'YYYY-MM-DD')
          ELSE NULL
      END >= v_date_creation_min
     -- Marqués pour suppression dans SAP : exclus (cohérent avec le script 04)
     AND COALESCE(a.loevm, '') <> 'X'
     -- Pas déjà repris par le fichier de sélection
     AND NOT EXISTS (
         SELECT 1
         FROM raw_data.selection_fournisseurs_stg sf2
         WHERE LPAD(TRIM(sf2.numero_compte_sap), 10, '0') = a.lifnr::text
     );

   GET DIAGNOSTICS v_nb_sap = ROW_COUNT;

   RAISE NOTICE 'ifs_fournisseurs : % depuis le fichier + % créés dans SAP depuis le % = % lignes',
                v_nb_fichier, v_nb_sap, v_date_creation_min, v_nb_fichier + v_nb_sap;
   /*-- Mettre à jour les KPI
   UPDATE clean_data.ifs_fournisseurs
   SET
       (derniere_date_commande, devise_principale,
        ca_2025, ca_2024, ca_2023, ca_2022, ca_2021, ca_2020,
        nb_commandes_2025, nb_commandes_2024, nb_commandes_2023,
        nb_commandes_2022, nb_commandes_2021, nb_commandes_2020) =
   (
       SELECT
           MAX(e.budat::DATE),
           MODE() WITHIN GROUP (ORDER BY ek.waers),
           SUM(CASE WHEN EXTRACT(YEAR FROM e.budat::DATE) = 2025 THEN e.dmbtr::NUMERIC ELSE 0 END),
           SUM(CASE WHEN EXTRACT(YEAR FROM e.budat::DATE) = 2024 THEN e.dmbtr::NUMERIC ELSE 0 END),
           SUM(CASE WHEN EXTRACT(YEAR FROM e.budat::DATE) = 2023 THEN e.dmbtr::NUMERIC ELSE 0 END),
           SUM(CASE WHEN EXTRACT(YEAR FROM e.budat::DATE) = 2022 THEN e.dmbtr::NUMERIC ELSE 0 END),
           SUM(CASE WHEN EXTRACT(YEAR FROM e.budat::DATE) = 2021 THEN e.dmbtr::NUMERIC ELSE 0 END),
           SUM(CASE WHEN EXTRACT(YEAR FROM e.budat::DATE) = 2020 THEN e.dmbtr::NUMERIC ELSE 0 END),
           COUNT(CASE WHEN EXTRACT(YEAR FROM e.budat::DATE) = 2025 THEN 1 END),
           COUNT(CASE WHEN EXTRACT(YEAR FROM e.budat::DATE) = 2024 THEN 1 END),
           COUNT(CASE WHEN EXTRACT(YEAR FROM e.budat::DATE) = 2023 THEN 1 END),
           COUNT(CASE WHEN EXTRACT(YEAR FROM e.budat::DATE) = 2022 THEN 1 END),
           COUNT(CASE WHEN EXTRACT(YEAR FROM e.budat::DATE) = 2021 THEN 1 END),
           COUNT(CASE WHEN EXTRACT(YEAR FROM e.budat::DATE) = 2020 THEN 1 END)
       FROM raw_data.ekbe e
       JOIN raw_data.ekko ek ON e.mandt = ek.mandt AND e.ebeln = ek.ebeln
       WHERE ek.lifnr = ifs_fournisseurs.numero_compte_fournisseur
         AND e.bewtp = 'E'
         AND e.shkzg = 'S'
         AND e.budat IS NOT NULL
   );
   UPDATE clean_data.ifs_fournisseurs SET date_maj = CURRENT_TIMESTAMP;*/
   RAISE NOTICE 'Table IFS_fournisseurs alimentée avec succès';
END;
$function$
;
