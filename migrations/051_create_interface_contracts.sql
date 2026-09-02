-- =====================================================================
-- Migration 051 : Contrats d'interface (validation metier des mappings
-- SAP -> IFS), pour piloter en base ce qui etait jusque-la fige dans le
-- classeur contrat_interface_migration_SAP_IFS_v3.xlsx.
--
-- 4 tables :
--   interface_contract_table      : 1 ligne par table cible (= 1 onglet Excel)
--                                    + signature globale metier + responsable
--   interface_contract_column     : 1 ligne par mapping colonne (source
--                                    structuree + regle + condition)
--   interface_contract_validation : DERNIER etat de validation metier,
--                                    separe de la definition technique pour
--                                    survivre a une regeneration du contrat
--   interface_contract_event      : journal (audit + fil de discussion) :
--                                    chaque changement de statut / commentaire
-- + 1 vue de lecture consolidee (visionneuse + export Excel), qui calcule
--   aussi l'obsolescence : une colonne VALIDE dont la definition a change
--   depuis la validation est signalee (validation_obsolete = true).
--
-- Pre-requis : la fonction update_updated_at_column() existe deja
-- (migration 004) ; on la reutilise pour fiabiliser updated_at, dont
-- depend le calcul d'obsolescence.
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1. Tables cibles (1 onglet)
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.interface_contract_table (
    id                  SERIAL PRIMARY KEY,
    module              VARCHAR(50)  NOT NULL,              -- ex: 'supplier'
    schema_cible        VARCHAR(50)  NOT NULL DEFAULT 'clean_data',
    table_cible         VARCHAR(100) NOT NULL,               -- ex: 'supplier_info_general'
    libelle             VARCHAR(200) NOT NULL,               -- ex: '02 - Supplier Info General'
    description         TEXT,
    source_procedure    VARCHAR(200),                        -- ex: 'alimenter_supplier_info_general'
    ordre               INTEGER NOT NULL DEFAULT 0,
    -- pilotage metier
    owner_metier        VARCHAR(100),                        -- responsable de la relecture
    date_limite         DATE,                                -- echeance de validation
    -- signature globale de la table (distincte du % calcule ligne a ligne)
    signe_par           VARCHAR(50),
    signe_le            TIMESTAMP,
    is_active           BOOLEAN NOT NULL DEFAULT TRUE,
    created_at          TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at          TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_interface_contract_table UNIQUE (module, table_cible)
);

-- Rattrapage si la table existait deja (version v1 de cette migration)
ALTER TABLE public.interface_contract_table
    ADD COLUMN IF NOT EXISTS owner_metier VARCHAR(100),
    ADD COLUMN IF NOT EXISTS date_limite  DATE,
    ADD COLUMN IF NOT EXISTS signe_par    VARCHAR(50),
    ADD COLUMN IF NOT EXISTS signe_le     TIMESTAMP,
    ADD COLUMN IF NOT EXISTS is_active    BOOLEAN NOT NULL DEFAULT TRUE;

-- ---------------------------------------------------------------------
-- 2. Colonnes (1 ligne du classeur)
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.interface_contract_column (
    id                      SERIAL PRIMARY KEY,
    contract_table_id       INTEGER NOT NULL REFERENCES public.interface_contract_table(id) ON DELETE CASCADE,
    section                 VARCHAR(200),                    -- regroupement type "Identite fournisseur"
    target_column           VARCHAR(100) NOT NULL,           -- champ cible IFS
    field_label              VARCHAR(200),
    -- source STRUCTUREE (nullable) : permet l'apercu de donnees reelles dans
    -- la visionneuse et l'analyse d'impact ("qui utilise lfa1.stceg ?")
    source_schema            VARCHAR(50),                     -- ex: 'raw_data'
    source_table             VARCHAR(100),                    -- ex: 'lfa1'
    source_column            VARCHAR(100),                    -- ex: 'name1'
    -- source en clair (jointures, concatenations, "Config", "Constante"...)
    source_expression        TEXT,
    transformation_rule      TEXT,                            -- logique metier (CASE/COALESCE/etc.)
    condition_application    TEXT,
    row_type                 VARCHAR(20) NOT NULL DEFAULT 'COLUMN'
                              CHECK (row_type IN ('COLUMN', 'CONFIG_SUMMARY', 'NOTE')),
    -- rapprochement avec etl_default_values (cle reelle = table_cible + colonne + variante)
    default_value_column     VARCHAR(100),
    default_value_variante   VARCHAR(30) NOT NULL DEFAULT 'STANDARD',
    sort_order                INTEGER NOT NULL DEFAULT 0,
    created_at                TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at                TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_interface_contract_column UNIQUE (contract_table_id, target_column)
);

-- Rattrapage si la table existait deja (version v1 de cette migration)
ALTER TABLE public.interface_contract_column
    ADD COLUMN IF NOT EXISTS source_schema          VARCHAR(50),
    ADD COLUMN IF NOT EXISTS source_table           VARCHAR(100),
    ADD COLUMN IF NOT EXISTS source_column          VARCHAR(100),
    ADD COLUMN IF NOT EXISTS default_value_variante VARCHAR(30) NOT NULL DEFAULT 'STANDARD';

-- ---------------------------------------------------------------------
-- 3. Dernier etat de validation metier (1-1 avec la colonne)
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.interface_contract_validation (
    id                    SERIAL PRIMARY KEY,
    contract_column_id    INTEGER NOT NULL UNIQUE REFERENCES public.interface_contract_column(id) ON DELETE CASCADE,
    statut                VARCHAR(20) NOT NULL DEFAULT 'A_VALIDER'
                           CHECK (statut IN ('A_VALIDER', 'VALIDE', 'A_CORRIGER', 'NON_APPLICABLE')),
    remarque_metier       TEXT,                              -- derniere remarque (le fil complet est dans _event)
    validated_by          VARCHAR(50),
    validated_at          TIMESTAMP,
    updated_at             TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- ---------------------------------------------------------------------
-- 4. Journal : audit des statuts + fil de discussion tech <-> metier
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.interface_contract_event (
    id                    SERIAL PRIMARY KEY,
    contract_column_id    INTEGER NOT NULL REFERENCES public.interface_contract_column(id) ON DELETE CASCADE,
    event_type            VARCHAR(20) NOT NULL
                           CHECK (event_type IN ('STATUT', 'COMMENTAIRE', 'DEFINITION', 'IMPORT_EXCEL')),
    ancien_statut         VARCHAR(20),
    nouveau_statut        VARCHAR(20),
    commentaire           TEXT,
    auteur                VARCHAR(50) NOT NULL,
    created_at            TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- ---------------------------------------------------------------------
-- Index
-- ---------------------------------------------------------------------
CREATE INDEX IF NOT EXISTS idx_ic_column_table      ON public.interface_contract_column(contract_table_id);
CREATE INDEX IF NOT EXISTS idx_ic_column_source     ON public.interface_contract_column(source_table, source_column);
CREATE INDEX IF NOT EXISTS idx_ic_validation_statut ON public.interface_contract_validation(statut);
CREATE INDEX IF NOT EXISTS idx_ic_event_column      ON public.interface_contract_event(contract_column_id, created_at DESC);

-- ---------------------------------------------------------------------
-- Triggers updated_at (fonction existante, migration 004)
-- ---------------------------------------------------------------------
DROP TRIGGER IF EXISTS trg_ic_table_updated_at ON public.interface_contract_table;
CREATE TRIGGER trg_ic_table_updated_at
    BEFORE UPDATE ON public.interface_contract_table
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS trg_ic_column_updated_at ON public.interface_contract_column;
CREATE TRIGGER trg_ic_column_updated_at
    BEFORE UPDATE ON public.interface_contract_column
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS trg_ic_validation_updated_at ON public.interface_contract_validation;
CREATE TRIGGER trg_ic_validation_updated_at
    BEFORE UPDATE ON public.interface_contract_validation
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- ---------------------------------------------------------------------
-- Vue de lecture consolidee (visionneuse + export Excel a la demande)
-- ---------------------------------------------------------------------
-- DROP necessaire : CREATE OR REPLACE refuse de changer la liste des colonnes
-- d'une vue existante (version v1)
DROP VIEW IF EXISTS public.v_interface_contract_summary;
DROP VIEW IF EXISTS public.v_interface_contract;

CREATE VIEW public.v_interface_contract AS
SELECT
    t.id            AS contract_table_id,
    t.module,
    t.schema_cible,
    t.table_cible,
    t.libelle       AS table_libelle,
    t.ordre         AS table_ordre,
    t.owner_metier,
    t.date_limite,
    t.signe_par,
    t.signe_le,
    c.id            AS contract_column_id,
    c.section,
    c.target_column,
    c.field_label,
    c.source_schema,
    c.source_table,
    c.source_column,
    c.source_expression,
    c.transformation_rule,
    c.condition_application,
    c.row_type,
    c.sort_order,
    c.updated_at    AS definition_updated_at,
    COALESCE(v.statut, 'A_VALIDER')   AS statut,
    v.remarque_metier,
    v.validated_by,
    v.validated_at,
    -- une validation est obsolete si la definition technique a change apres
    COALESCE(v.statut = 'VALIDE' AND c.updated_at > v.validated_at, FALSE) AS validation_obsolete,
    edv.valeur      AS default_value_actuelle,
    edv.type_valeur AS default_value_type,
    edv.is_active   AS default_value_active
FROM public.interface_contract_table t
JOIN public.interface_contract_column c
  ON c.contract_table_id = t.id
LEFT JOIN public.interface_contract_validation v
  ON v.contract_column_id = c.id
LEFT JOIN public.etl_default_values edv
  ON edv.table_cible = t.table_cible
 AND edv.colonne     = c.default_value_column
 AND edv.variante    = c.default_value_variante
 AND c.row_type      = 'CONFIG_SUMMARY'
WHERE t.is_active
ORDER BY t.ordre, c.sort_order;

-- ---------------------------------------------------------------------
-- Vue de synthese par table (tableau de bord + panneau de gauche)
-- ---------------------------------------------------------------------
CREATE VIEW public.v_interface_contract_summary AS
SELECT
    t.id            AS contract_table_id,
    t.module,
    t.table_cible,
    t.libelle,
    t.ordre,
    t.owner_metier,
    t.date_limite,
    t.signe_par,
    t.signe_le,
    COUNT(c.id) FILTER (WHERE c.row_type <> 'NOTE')                              AS nb_lignes,
    COUNT(c.id) FILTER (WHERE v.statut = 'VALIDE')                                AS nb_valide,
    COUNT(c.id) FILTER (WHERE v.statut = 'A_CORRIGER')                            AS nb_a_corriger,
    COUNT(c.id) FILTER (WHERE v.statut IS NULL OR v.statut = 'A_VALIDER')         AS nb_a_valider,
    COUNT(c.id) FILTER (WHERE v.statut = 'VALIDE' AND c.updated_at > v.validated_at) AS nb_obsolete,
    ROUND(100.0 * COUNT(c.id) FILTER (WHERE v.statut IN ('VALIDE', 'NON_APPLICABLE'))
          / NULLIF(COUNT(c.id) FILTER (WHERE c.row_type <> 'NOTE'), 0), 1)        AS pct_valide
FROM public.interface_contract_table t
LEFT JOIN public.interface_contract_column c ON c.contract_table_id = t.id
LEFT JOIN public.interface_contract_validation v ON v.contract_column_id = c.id
WHERE t.is_active
GROUP BY t.id
ORDER BY t.ordre;
