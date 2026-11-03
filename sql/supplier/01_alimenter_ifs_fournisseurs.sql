-- ============================================================================
-- Alimentation de clean_data.ifs_fournisseurs = table d'entree des scripts 02->16
-- Source unique (2026-11-03) : clean_data.ifs_fournisseurs_perimetre (script
-- 01b, ecran Finance > Fournisseurs), copiee telle quelle, fournisseurs sans
-- N° IFS exclus. Ce script ne lit plus ni le fichier de selection ni SAP.
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
-- Plus alimentees depuis le 2026-11-03 (le N° IFS vient du metier, cf. fonction
-- ci-dessous) ; conservees pour l'historique des numeros deja emis.
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
    'Origine de la ligne, reprise de ifs_fournisseurs_perimetre : FICHIER ou SAP_NOUVEAU';
COMMENT ON COLUMN clean_data.ifs_fournisseurs.numero_compte_ifs IS
    'Identifiant IFS fixe par le metier (fichier de selection ou fichier valide), repris de ifs_fournisseurs_perimetre';
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

-- ----------------------------------------------------------------------------
-- Alimentation : copie de clean_data.ifs_fournisseurs_perimetre (2026-11-03)
-- ----------------------------------------------------------------------------
-- Le perimetre (ecran Finance > Fournisseurs, script 01b) est la SEULE source
-- du module : fichier de selection + fichier valide par le metier + fournisseurs
-- crees dans SAP depuis la date d'arrete, toutes les donnees venant de SAP. Il
-- n'est pas recalcule ici : on reprend ce qui a ete calcule et valide a l'ecran.
-- Le N° IFS n'est jamais genere (plus de sequence, ifs_fournisseur_id_map n'est
-- plus alimentee) : un fournisseur sans N° IFS fixe par le metier n'est pas
-- charge, IFS ne saurait pas l'identifier.
CREATE OR REPLACE FUNCTION clean_data.alimenter_ifs_fournisseurs()
 RETURNS void
 LANGUAGE plpgsql
AS $function$
DECLARE
   v_nb INTEGER;
   v_sans_ifs INTEGER;
BEGIN
   IF NOT EXISTS (SELECT 1 FROM clean_data.ifs_fournisseurs_perimetre) THEN
      RAISE EXCEPTION 'clean_data.ifs_fournisseurs_perimetre est vide : lancer « Calculer » dans l''ecran Finance > Fournisseurs';
   END IF;

   TRUNCATE TABLE clean_data.ifs_fournisseurs;

   INSERT INTO clean_data.ifs_fournisseurs (
      numero_compte_fournisseur, source, numero_compte_ifs, company, address_id,
      nom_1, rue, complement_adresse, localite, code_postal, cle_pays,
      siret, numero_siren, tva, code_tva_ifs, code_tva_sap, france_etranger,
      societe, organisation_achats, conditions_paiement_compta, conditions_paiement_achats,
      condition_paiement_sap, mode_paiement, incoterms_1, incoterms_2,
      telephone_1, telephone_2, telephone_3, email, critere_recherche, langue, language_sap,
      destinataire_paiement, date_creation_sap,
      iban_paiement, swift_bic, nom_banque, numero_compte_bancaire, code_banque, pays_banque, titulaire_compte,
      date_creation, date_maj
   )
   SELECT
      numero_compte_fournisseur, source, numero_compte_ifs, company, address_id,
      nom_1, rue, complement_adresse, localite, code_postal, cle_pays,
      siret, numero_siren, tva, code_tva_ifs, code_tva_sap, france_etranger,
      societe, organisation_achats, conditions_paiement_compta, conditions_paiement_achats,
      condition_paiement_sap, mode_paiement, incoterms_1, incoterms_2,
      telephone_1, telephone_2, telephone_3, email, critere_recherche, langue, language_sap,
      destinataire_paiement, date_creation_sap,
      iban_paiement, swift_bic, nom_banque, numero_compte_bancaire, code_banque, pays_banque, titulaire_compte,
      CURRENT_TIMESTAMP, CURRENT_TIMESTAMP
     FROM clean_data.ifs_fournisseurs_perimetre
    WHERE numero_compte_ifs IS NOT NULL;

   GET DIAGNOSTICS v_nb = ROW_COUNT;
   SELECT count(*) INTO v_sans_ifs
     FROM clean_data.ifs_fournisseurs_perimetre WHERE numero_compte_ifs IS NULL;

   RAISE NOTICE 'ifs_fournisseurs : % fournisseurs repris de ifs_fournisseurs_perimetre', v_nb;
   IF v_sans_ifs > 0 THEN
      RAISE WARNING '% fournisseurs du perimetre sans N° IFS non charges (a completer dans le fichier valide)', v_sans_ifs;
   END IF;
END;
$function$
;
