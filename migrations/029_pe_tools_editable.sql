-- 029 — Rendre raw_data.pe_tools exploitable depuis l'ecran Maintenance
--
-- La table est chargee telle quelle depuis le fichier PE Tools : pas de cle
-- primaire, pas d'index, pas de tracabilite. L'ecran /maintenance/pe-tools
-- permet de la filtrer, l'exporter ET de la modifier -> il faut :
--   1. garantir l'unicite de raw_id (cle d'edition cote API) ;
--   2. indexer les colonnes filtrees / triees ;
--   3. tracer qui a modifie quoi et quand.
--
-- Idempotent : rejouable sans risque.

BEGIN;

-- 1. Cle d'edition -------------------------------------------------------
-- raw_id est deja NOT NULL et unique en donnees ; on materialise la contrainte.
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint
        WHERE conrelid = 'raw_data.pe_tools'::regclass AND contype = 'p'
    ) THEN
        ALTER TABLE raw_data.pe_tools ADD CONSTRAINT pk_pe_tools PRIMARY KEY (raw_id);
    END IF;
END $$;

-- 2. Colonnes de tracabilite ---------------------------------------------
ALTER TABLE raw_data.pe_tools ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ;
ALTER TABLE raw_data.pe_tools ADD COLUMN IF NOT EXISTS updated_by TEXT;

COMMENT ON COLUMN raw_data.pe_tools.updated_at IS
    'Horodatage de la derniere modification via l''ecran Maintenance / PE Tools';
COMMENT ON COLUMN raw_data.pe_tools.updated_by IS
    'Utilisateur (identite JWT) ayant modifie la ligne via l''ecran Maintenance / PE Tools';

-- 3. Index de filtrage ----------------------------------------------------
CREATE INDEX IF NOT EXISTS idx_pe_tools_poste_technique ON raw_data.pe_tools (poste_technique);
CREATE INDEX IF NOT EXISTS idx_pe_tools_frequence      ON raw_data.pe_tools (frequence);
CREATE INDEX IF NOT EXISTS idx_pe_tools_type           ON raw_data.pe_tools (type);
CREATE INDEX IF NOT EXISTS idx_pe_tools_localisation   ON raw_data.pe_tools (localisation_classement);
CREATE INDEX IF NOT EXISTS idx_pe_tools_plan_entretien ON raw_data.pe_tools (plan_entretien);

COMMIT;
