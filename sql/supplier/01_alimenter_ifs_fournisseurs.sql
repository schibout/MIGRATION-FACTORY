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
    ADD COLUMN IF NOT EXISTS source                 VARCHAR(20),
    -- Coordonnees bancaires SAP (LFBK / TIBAN / BNKA)
    ADD COLUMN IF NOT EXISTS numero_compte_bancaire VARCHAR(20),
    ADD COLUMN IF NOT EXISTS code_banque            VARCHAR(20),
    ADD COLUMN IF NOT EXISTS pays_banque            VARCHAR(3),
    ADD COLUMN IF NOT EXISTS titulaire_compte       VARCHAR(60);

-- ----------------------------------------------------------------------------
-- Cle primaire : le numero de compte SAP (LIFNR)
-- ----------------------------------------------------------------------------
-- Un fournisseur = une ligne. La contrainte fait echouer bruyamment tout
-- doublon introduit par le fichier de selection ou par le complement SAP,
-- au lieu de le laisser se propager aux scripts 03->15.
ALTER TABLE clean_data.ifs_fournisseurs
    ALTER COLUMN numero_compte_fournisseur SET NOT NULL;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
          FROM pg_constraint c
          JOIN pg_class t      ON t.oid = c.conrelid
          JOIN pg_namespace n  ON n.oid = t.relnamespace
         WHERE n.nspname = 'clean_data'
           AND t.relname = 'ifs_fournisseurs'
           AND c.contype = 'p'
    ) THEN
        ALTER TABLE clean_data.ifs_fournisseurs
            ADD CONSTRAINT pk_ifs_fournisseurs PRIMARY KEY (numero_compte_fournisseur);
        RAISE NOTICE 'Cle primaire pk_ifs_fournisseurs creee sur numero_compte_fournisseur';
    END IF;
END $$;

-- ----------------------------------------------------------------------------
-- Attribution des identifiants IFS
-- ----------------------------------------------------------------------------
-- La fonction TRUNCATE puis reinsere a chaque execution : sans memoire, un
-- nextval() reattribuerait des numeros differents a chaque rechargement. La
-- table d'affectation fige le couple LIFNR -> numero IFS ; la sequence ne sert
-- qu'a emettre un numero pour un fournisseur jamais vu.
CREATE SEQUENCE IF NOT EXISTS clean_data.seq_numero_compte_ifs
    START WITH 600001 INCREMENT BY 1 MINVALUE 600001 NO CYCLE;

CREATE TABLE IF NOT EXISTS clean_data.ifs_fournisseur_id_map (
    numero_compte_sap VARCHAR(10)  PRIMARY KEY,
    numero_compte_ifs INTEGER      NOT NULL UNIQUE,
    source            VARCHAR(20)  NOT NULL,
    created_at        TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP
);

COMMENT ON TABLE clean_data.ifs_fournisseur_id_map IS
    'Affectation definitive LIFNR SAP -> numero de compte IFS. Ne jamais purger : un numero deja attribue ne doit plus changer.';

COMMENT ON COLUMN clean_data.ifs_fournisseurs.source IS
    'Origine de la ligne : FICHIER (selection_fournisseurs_stg) ou SAP_NOUVEAU (cree dans SAP apres la selection)';
COMMENT ON COLUMN clean_data.ifs_fournisseurs.numero_compte_ifs IS
    'Identifiant IFS arbitre par le metier, repris tel quel du fichier de selection (600001+)';
COMMENT ON COLUMN clean_data.ifs_fournisseurs.numero_compte_fournisseur IS
    'Numero de compte SAP (LIFNR) complete a 10 caracteres, cle de jointure vers raw_data.lfa1';

-- ----------------------------------------------------------------------------
-- Coordonnees bancaires d'un fournisseur, depuis SAP
-- ----------------------------------------------------------------------------
-- ifs_fournisseurs porte UNE ligne par fournisseur, alors que raw_data.lfbk en
-- contient plusieurs pour 1065 fournisseurs. Cette fonction choisit un compte
-- de facon deterministe : d'abord ceux qui ont un IBAN, puis le plus petit type
-- de banque partenaire (bvtyp), puis la cle et le numero de compte.
--   lfbk  = lien fournisseur -> compte bancaire
--   tiban = IBAN, cle (banks, bankl, bankn)
--   bnka  = referentiel banques : nom (banka) et code SWIFT
-- DROP obligatoire : CREATE OR REPLACE ne sait pas modifier les colonnes d'un
-- RETURNS TABLE (« cannot change return type of existing function »). Sans lui,
-- l'ancienne version a 3 colonnes (iban, swift, nom) reste en place et le
-- chargement echoue sur « column banque.nom_banque does not exist ».
DROP FUNCTION IF EXISTS clean_data.fn_coordonnees_bancaires_sap(TEXT);

CREATE FUNCTION clean_data.fn_coordonnees_bancaires_sap(p_lifnr TEXT)
RETURNS TABLE (
    iban        TEXT,
    swift       TEXT,
    nom_banque  TEXT,
    compte      TEXT,
    code_banque TEXT,
    pays_banque TEXT,
    titulaire   TEXT
)
LANGUAGE sql
STABLE
AS $function$
    SELECT
        -- IBAN reel de SAP (TIBAN) en priorite ; pour les comptes francais qui
        -- n'y figurent pas, repli sur le calcul depuis code banque + compte.
        COALESCE(
            NULLIF(TRIM(t.iban), ''),
            CASE WHEN l.banks = 'FR' AND l.bankl IS NOT NULL AND l.bankn IS NOT NULL
                 THEN clean_data.fn_calculate_iban('FR', l.bankl, '00000', l.bankn)
            END
        ),
        NULLIF(TRIM(k.swift), ''),
        NULLIF(TRIM(k.banka), ''),
        NULLIF(TRIM(l.bankn), ''),
        NULLIF(TRIM(l.bankl), ''),
        NULLIF(TRIM(l.banks), ''),
        NULLIF(TRIM(l.koinh), '')
      FROM raw_data.lfbk l
      LEFT JOIN raw_data.tiban t
             ON t.banks = l.banks AND t.bankl = l.bankl AND t.bankn = l.bankn
      LEFT JOIN raw_data.bnka k
             ON k.banks = l.banks AND k.bankl = l.bankl
     WHERE l.lifnr::text = p_lifnr
       AND NULLIF(TRIM(l.bankn), '') IS NOT NULL
     ORDER BY (NULLIF(TRIM(t.iban), '') IS NULL), l.bvtyp NULLS LAST, l.bankl, l.bankn
     LIMIT 1;
$function$;

COMMENT ON FUNCTION clean_data.fn_coordonnees_bancaires_sap(TEXT) IS
    'Compte bancaire retenu pour un fournisseur SAP (lfbk + tiban + bnka) : celui qui porte un IBAN, sinon le premier par bvtyp/bankl/bankn. Source unique partagee par ifs_fournisseurs (script 01) et payment_address (script 14).';

CREATE OR REPLACE FUNCTION clean_data.alimenter_ifs_fournisseurs()
 RETURNS void
 LANGUAGE plpgsql
AS $function$
DECLARE
   -- Date de création SAP à partir de laquelle un fournisseur absent du fichier
   -- de sélection est quand même repris (le fichier a été arrêté avant).
   v_date_creation_min CONSTANT DATE := DATE '2025-10-07';
   v_nb_fichier INTEGER := 0;
   v_nb_sap INTEGER := 0;
   v_nb_nouveaux_ids INTEGER := 0;
BEGIN
   -- =========================================================================
   -- 0. Attribution des identifiants IFS (avant toute insertion)
   -- =========================================================================
   -- 0.a Les numéros arbitrés par le métier dans le fichier font foi : ils
   --     entrent tels quels dans la table d'affectation. ON CONFLICT DO NOTHING
   --     garantit qu'un numéro déjà attribué n'est jamais réécrit.
   INSERT INTO clean_data.ifs_fournisseur_id_map (numero_compte_sap, numero_compte_ifs, source)
   SELECT LPAD(TRIM(sf.numero_compte_sap), 10, '0'),
          sf.numero_compte_ifs::INTEGER,
          'FICHIER'
     FROM raw_data.selection_fournisseurs_stg sf
    WHERE TRIM(COALESCE(sf.numero_compte_ifs, '')) ~ '^[0-9]+$'
   ON CONFLICT (numero_compte_sap) DO NOTHING;

   -- 0.b Recaler la séquence au-dessus du dernier numéro attribué. setval sur
   --     le MAX de la table d'affectation : aucun numéro déjà distribué ne peut
   --     être réémis, et on ne crée pas de trou inutile.
   PERFORM setval('clean_data.seq_numero_compte_ifs',
                  COALESCE((SELECT MAX(numero_compte_ifs) FROM clean_data.ifs_fournisseur_id_map), 600000));

   -- 0.c Émettre un numéro pour les fournisseurs SAP récents encore inconnus.
   --     Le sous-select ordonné par LIFNR fait suivre à la séquence l'ordre du
   --     numéro SAP, comme le fichier le fait déjà (600000 + rang par LIFNR).
   INSERT INTO clean_data.ifs_fournisseur_id_map (numero_compte_sap, numero_compte_ifs, source)
   SELECT t.lifnr,
          nextval('clean_data.seq_numero_compte_ifs'),
          'SAP_NOUVEAU'
     FROM (
         SELECT a.lifnr::text as lifnr
           FROM raw_data.lfa1 a
          WHERE CASE
                    WHEN TRIM(COALESCE(a.erdat, '')) ~ '^[0-9]{8}$' AND TRIM(a.erdat) <> '00000000'
                        THEN TO_DATE(TRIM(a.erdat), 'YYYYMMDD')
                    WHEN TRIM(COALESCE(a.erdat, '')) ~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}$'
                        THEN TO_DATE(TRIM(a.erdat), 'YYYY-MM-DD')
                    ELSE NULL
                END >= v_date_creation_min
            AND COALESCE(a.loevm, '') <> 'X'
            AND NOT EXISTS (
                SELECT 1 FROM clean_data.ifs_fournisseur_id_map mp
                 WHERE mp.numero_compte_sap = a.lifnr::text
            )
          ORDER BY a.lifnr::text
     ) t
   ON CONFLICT (numero_compte_sap) DO NOTHING;

   GET DIAGNOSTICS v_nb_nouveaux_ids = ROW_COUNT;

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
      email, iban_paiement, swift_bic, nom_banque, mode_paiement, source,
      numero_compte_bancaire, code_banque, pays_banque, titulaire_compte
   )
   SELECT
      public.get_default_value('clean_data.ifs_fournisseurs', 'company') as company,

      -- Numéro SAP complété à 10 caractères : le staging le porte non complété
      -- ("45036"), alors que lfa1.lifnr et les scripts 03->15 attendent la forme
      -- SAP ("0000045036"). Sans le LPAD, aucune jointure SAP ne remonte.
      k.lifnr as numero_compte_fournisseur,

      -- Identifiant IFS : lu dans la table d'affectation (alimentée en 0.a
      -- depuis le fichier), avec repli sur la valeur brute du fichier.
      COALESCE(mp.numero_compte_ifs::text, NULLIF(TRIM(sf.numero_compte_ifs), '')) as numero_compte_ifs,

      -- Numéro d'adresse SAP (lfa1.adrnr) : le fichier de sélection ne porte pas
      -- d'identifiant d'adresse. Repli sur la constante paramétrable pour les
      -- rares fournisseurs sans adrnr. Les scripts 04, 06, 14 et 15 reprennent
      -- cette colonne, l'identifiant reste donc cohérent dans tout le module.
      COALESCE(
          NULLIF(TRIM(a.adrnr), ''),
          public.get_default_value('clean_data.ifs_fournisseurs', 'address_id')
      ) as address_id,

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

      -- === Coordonnees bancaires : fichier > SAP ==============================
      -- Les colonnes bancaires du fichier de selection sont vides (verifie :
      -- 0 IBAN / 0 SWIFT / 0 nom de banque sur les 1716 lignes) ; le COALESCE
      -- garde neanmoins la priorite au fichier s'il venait a etre complete.
      COALESCE(NULLIF(TRIM(sf.iban_paiement), ''), banque.iban)       as iban_paiement,
      COALESCE(NULLIF(TRIM(sf.swift_bic), ''),     banque.swift)      as swift_bic,
      COALESCE(NULLIF(TRIM(sf.nom_banque), ''),    banque.nom_banque) as nom_banque,

      NULLIF(TRIM(sf.mode_paiement), '')          as mode_paiement,
      'FICHIER'                                   as source,

      -- Reste du compte retenu : uniquement SAP (absent du fichier)
      banque.compte      as numero_compte_bancaire,
      banque.code_banque as code_banque,
      banque.pays_banque as pays_banque,
      banque.titulaire   as titulaire_compte

   FROM raw_data.selection_fournisseurs_stg sf
   CROSS JOIN LATERAL (
       SELECT LPAD(TRIM(sf.numero_compte_sap), 10, '0') as lifnr
   ) k
   LEFT JOIN clean_data.ifs_fournisseur_id_map mp ON mp.numero_compte_sap = k.lifnr
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
   ) sap_data ON TRUE
   LEFT JOIN LATERAL clean_data.fn_coordonnees_bancaires_sap(k.lifnr) banque ON TRUE;

   GET DIAGNOSTICS v_nb_fichier = ROW_COUNT;

   -- =========================================================================
   -- Fournisseurs créés dans SAP APRÈS l'arrêté du fichier de sélection
   -- =========================================================================
   -- Le fichier a figé le périmètre à une date donnée. Les fournisseurs créés
   -- dans SAP depuis v_date_creation_min et absents du fichier sont repris ici,
   -- avec les seules données SAP (le fichier ne les connaît pas : ni IBAN, ni
   -- email, ni code TVA IFS...).
   --
   -- Identifiant IFS : émis par clean_data.seq_numero_compte_ifs à l'étape 0.c
   -- et figé dans la table d'affectation, donc stable d'un rechargement à l'autre.
   -- Le INNER JOIN sur la table d'affectation garantit qu'aucune ligne n'est
   -- insérée sans identifiant.
   INSERT INTO clean_data.ifs_fournisseurs (company,
      numero_compte_fournisseur, numero_compte_ifs, address_id, nom_1, rue, localite, code_postal,
      cle_pays, siret, tva, societe, organisation_achats,
      conditions_paiement_compta, conditions_paiement_achats,
      incoterms_1, incoterms_2, telephone_1, telephone_2, date_creation_sap,
      destinataire_paiement, language_sap,
      iban_paiement, swift_bic, nom_banque, source,
      numero_compte_bancaire, code_banque, pays_banque, titulaire_compte
   )
   SELECT
      public.get_default_value('clean_data.ifs_fournisseurs', 'company') as company,
      a.lifnr::text as numero_compte_fournisseur,

      -- Numéro émis par la séquence, figé dans la table d'affectation
      mp.numero_compte_ifs::text as numero_compte_ifs,

      -- Numéro d'adresse SAP (lfa1.adrnr), repli sur la constante paramétrable
      COALESCE(
          NULLIF(TRIM(a.adrnr), ''),
          public.get_default_value('clean_data.ifs_fournisseurs', 'address_id')
      ) as address_id,

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

      -- Coordonnées bancaires SAP (lfbk + tiban + bnka)
      banque.iban       as iban_paiement,
      banque.swift      as swift_bic,
      banque.nom_banque as nom_banque,

      'SAP_NOUVEAU' as source,

      banque.compte      as numero_compte_bancaire,
      banque.code_banque as code_banque,
      banque.pays_banque as pays_banque,
      banque.titulaire   as titulaire_compte

   FROM raw_data.lfa1 a
   JOIN clean_data.ifs_fournisseur_id_map mp ON mp.numero_compte_sap = a.lifnr::text
   LEFT JOIN LATERAL clean_data.fn_coordonnees_bancaires_sap(a.lifnr::text) banque ON TRUE
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
   RAISE NOTICE 'Identifiants IFS : % nouveaux numéros émis par la séquence (dernier attribué : %)',
                v_nb_nouveaux_ids,
                (SELECT MAX(numero_compte_ifs) FROM clean_data.ifs_fournisseur_id_map);
   RAISE NOTICE 'Table IFS_fournisseurs alimentée avec succès';
END;
$function$
;
