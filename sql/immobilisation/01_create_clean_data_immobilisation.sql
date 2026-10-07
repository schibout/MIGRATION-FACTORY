-- ============================================================================
-- clean_data.immobilisation : immobilisations SAP au format de l'extraction
-- transmise aux metiers (sap_immobilisations_champs_importants.csv, Hermes,
-- 18/08/2026), une ligne par immobilisation.
-- ============================================================================
-- 2026-10-06 : remplace la premiere version calquee sur raw_data.v_immo_comptes
-- (une ligne par immobilisation x zone, comptes seulement). Demande explicite :
-- « le fichier est plus recent et plus fiable ». Memes 60 colonnes que le
-- fichier, dans le meme ordre ; noms techniques en minuscules (le service
-- d'export les reprend tels quels en en-tete), libelles metier dans l'ecran
-- Finance > Immobilisations et en COMMENT de colonne.
-- Table de SNAPSHOT (DELETE + INSERT par clean_data.alimenter_immobilisation),
-- le DROP est sans risque.
-- 2026-10-06 (soir) : + 8 colonnes de reprise IFS en fin de table (statut de
-- reprise, comptes IFS, groupe objet, site, OTP), cf. migration 098.
-- ============================================================================

DROP TABLE IF EXISTS clean_data.immobilisation;

CREATE TABLE clean_data.immobilisation (
    societe_sap                 varchar(4)   NOT NULL,
    num_immobilisation          varchar(12)  NOT NULL,
    sous_numero                 varchar(4)   NOT NULL,
    cle_immobilisation          varchar(30),
    libelle                     varchar(50),
    libelle_complementaire      varchar(50),
    classe_immo                 varchar(8),
    famille_immo                varchar(50),
    indicateur_suppression      varchar(1),
    numero_serie                varchar(18),
    pays                        varchar(3),
    groupe_evaluation_1         varchar(4),
    groupe_evaluation_2         varchar(4),
    groupe_evaluation_3         varchar(4),
    groupe_evaluation_4         varchar(4),
    projet                      varchar(24),
    cle_comptes_immo            varchar(8),
    libelle_cle_comptes_immo    varchar(50),
    compte_immobilisation       varchar(10),
    compte_amort_cumule         varchar(10),
    compte_dotation_amort       varchar(10),
    date_acquisition            date,
    date_premiere_acquisition   date,
    date_debut_amort            date,
    date_fin_amort_estimee      date,
    duree_amort_annees          varchar(3),
    duree_amort_periodes        varchar(3),
    duree_amort_totale_mois     integer,
    zone_amortissement          varchar(2),
    type_amortissement          varchar(4),
    libelle_type_amortissement  varchar(50),
    taux_amort_estime           numeric(9,4),
    centre_cout                 varchar(10),
    libelle_centre_cout         varchar(40),
    site_sap                    varchar(4),
    secteur_sap                 varchar(4),
    libelle_secteur             varchar(30),
    emplacement                 varchar(10),
    immo_origine                varchar(12),
    sous_numero_origine         varchar(4),
    date_origine                date,
    numero_inventaire           varchar(25),
    fabricant                   varchar(30),
    type_modele                 varchar(15),
    fournisseur                 varchar(10),
    quantite                    varchar(20),
    unite                       varchar(3),
    ordre_investissement        varchar(12),
    zone_valorisation           varchar(2),
    exercice_valorisation       varchar(4),
    valeur_acq_debut_exercice   numeric(17,2),
    mouvements_acq_exercice     numeric(17,2),
    sorties_exercice            numeric(17,2),
    valeur_acq_fin_exercice     numeric(17,2),
    amort_cumules               numeric(17,2),
    vnc                         numeric(17,2),
    dotation_annuelle           numeric(17,2),
    blocage_comptabilisation    varchar(1),
    date_sortie                 date,
    date_desactivation          date,
    -- Colonnes de reprise IFS (migration 098, classeur metier du 18/08/2026,
    -- onglets Methode / Travail / Conversion cpte general). Toujours APRES les
    -- 60 colonnes du fichier livre.
    reprise_ifs                 boolean,
    motif_exclusion             text,
    compte_immobilisation_ifs   varchar(10),
    compte_amort_cumule_ifs     varchar(10),
    object_group_id             varchar(10),
    site_ifs                    varchar(2),
    element_otp                 varchar(24),
    libelle_otp                 varchar(40),
    date_arrete                 date,        -- migration 102
    PRIMARY KEY (societe_sap, num_immobilisation, sous_numero)
);

COMMENT ON COLUMN clean_data.immobilisation.reprise_ifs IS 'Dans le perimetre de reprise IFS : pas de date de sortie, ou sortie posterieure a la date de bascule (etl_default_values date_bascule_ifs). Une sortie posterieure a la bascule est reprise SANS date de sortie cote IFS';
COMMENT ON COLUMN clean_data.immobilisation.motif_exclusion IS 'Raison de l''exclusion quand reprise_ifs = false';
COMMENT ON COLUMN clean_data.immobilisation.compte_immobilisation_ifs IS 'Transcodification FA_ACCOUNT (SAP -> IFS) de compte_immobilisation ; NULL si le compte n''est pas dans l''ecran Transcodification';
COMMENT ON COLUMN clean_data.immobilisation.compte_amort_cumule_ifs IS 'Transcodification FA_ACCOUNT de compte_amort_cumule';
COMMENT ON COLUMN clean_data.immobilisation.object_group_id IS 'Groupe objet IFS : FA_OBJECT_GROUP_IMMO (par numero d''immobilisation) sinon FA_OBJECT_GROUP (par classe_immo) ; NULL = a completer dans Transcodification';
COMMENT ON COLUMN clean_data.immobilisation.site_ifs IS 'SJ / CS : site_sap 9200 -> SJ, 9000 -> CS ; sans site, secteur 9030 (Fonderie Castel) -> CS sinon SJ';
COMMENT ON COLUMN clean_data.immobilisation.element_otp IS 'Element d''OTP (code projet) : ANLA-POSNR -> PRPS-POSID';
COMMENT ON COLUMN clean_data.immobilisation.libelle_otp IS 'PRPS-POST1';

COMMENT ON TABLE clean_data.immobilisation IS
    'Immobilisations SAP STJN au format de l''extraction transmise aux metiers (1 ligne / immobilisation, valeurs statutaires zone 02 arretees a la derniere cloture mensuelle). Recharge par clean_data.alimenter_immobilisation().';
COMMENT ON COLUMN clean_data.immobilisation.libelle_complementaire IS 'ANLA-TXA50 (le fichier Hermes du 18/08 y mettait TXT50 par erreur)';
COMMENT ON COLUMN clean_data.immobilisation.zone_amortissement IS 'ANLB-AFABE retenue : 03 > 73 > 02 > 60 > 01, puis BDATU la plus recente';
COMMENT ON COLUMN clean_data.immobilisation.valeur_acq_debut_exercice IS 'Somme ANLC-KANSW, zone 02, exercice de valorisation';
COMMENT ON COLUMN clean_data.immobilisation.amort_cumules IS 'Amortissements cumules a la date d''arrete (positif), cf. migration 102';
COMMENT ON COLUMN clean_data.immobilisation.vnc IS 'valeur_acq_fin_exercice - amort_cumules, a la date d''arrete';
