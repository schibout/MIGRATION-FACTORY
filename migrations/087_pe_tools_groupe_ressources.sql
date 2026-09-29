-- ============================================================================
-- 087 - raw_data.pe_tools.groupe_ressources (groupe de ressources IFS)
-- ----------------------------------------------------------------------------
-- Deduit du Type de la gamme : mecanique -> MM, electrique -> ME
-- ('CTRL MEC', 'CHANG MEC', 'REGL MEC' -> MM ; 'CTRL ELEC', 'REGL ELEC' -> ME).
-- Type mixte ('CTRL MEC / ELEC') ou autre (GR, PROD, TOUR, ...) -> NULL.
-- Lu par clean_data.populate_pm_action_resource() -> pm_action_resource.resource_group.
--
-- Colonne GENEREE (STORED), comme ifs_date_execution (083) : jamais dans la
-- liste de colonnes d'un INSERT / UPDATE. Idempotente.
-- A jouer AVANT sql/pm_actions/compile.sh, puis redemarrer le backend
-- (presence de la colonne memorisee par worker).
-- ============================================================================
BEGIN;

ALTER TABLE raw_data.pe_tools ADD COLUMN IF NOT EXISTS groupe_ressources VARCHAR(10)
    GENERATED ALWAYS AS (
        CASE
            WHEN upper(type) LIKE '%ELEC%' AND upper(type) NOT LIKE '%MEC%' THEN 'ME'
            WHEN upper(type) LIKE '%MEC%'  AND upper(type) NOT LIKE '%ELEC%' THEN 'MM'
        END
    ) STORED;

COMMENT ON COLUMN raw_data.pe_tools.groupe_ressources IS
    'Groupe de ressources IFS deduit du type : MEC -> MM, ELEC -> ME, sinon NULL. Generee, migration 087.';

COMMIT;
