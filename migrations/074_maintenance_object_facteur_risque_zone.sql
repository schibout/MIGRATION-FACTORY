-- ============================================================================
-- 074 : "Facteur de Risque" et "Zone" sur les postes techniques (ecran IH02)
--
-- Deux champs de SAISIE LIBRE demandes sur la fiche d'un poste technique
-- (/maintenance/ih02). Ils n'existent pas dans SAP : ce sont des donnees
-- produites par l'utilisateur pendant la migration, sans equivalent dans
-- raw_data.iflot / iflo.
--
-- POURQUOI DES COLONNES ET PAS attributes (JSONB) : la convention de
-- create_maintenance_object.sql reserve `attributes` aux champs SAP repris
-- tels quels et met en colonne ce qui est affiche / filtre. Ces deux champs
-- sont saisis, relus et destines a l'export : une colonne les rend greppables,
-- indexables et typables, alors qu'une cle JSONB serait invisible au schema.
--
-- SURVIE AUX RECHARGEMENTS SAP :
--   - mode fusion (clean_data.load_maintenance_object_merge) : les UPDATE
--     enumerent leurs colonnes une par une et ne touchent ni risk_factor ni
--     zone ; de plus toute ligne editee depuis l'ecran porte updated_by, ce qui
--     l'exclut deja des rafraichissements. Rien a modifier dans la procedure.
--   - mode reset (clean_data.load_maintenance_object) : il commence par
--     DELETE ... WHERE source = 'SAP' ; les valeurs saisies sur des lignes SAP
--     sont donc perdues, comme tout le reste du travail utilisateur. C'est le
--     comportement documente de ce mode (un snapshot le precede toujours).
--
-- Rejouable (IF NOT EXISTS). Rollback en bas de fichier.
-- ============================================================================
BEGIN;

ALTER TABLE clean_data.maintenance_object
    ADD COLUMN IF NOT EXISTS risk_factor TEXT,   -- "Facteur de Risque" (saisie libre)
    ADD COLUMN IF NOT EXISTS zone        TEXT;   -- "Zone"              (saisie libre)

COMMENT ON COLUMN clean_data.maintenance_object.risk_factor IS
    'Facteur de risque saisi dans l''ecran IH02 (hors SAP, migration 074)';
COMMENT ON COLUMN clean_data.maintenance_object.zone IS
    'Zone saisie dans l''ecran IH02 (hors SAP, migration 074)';

COMMIT;

-- ============================================================================
-- ROLLBACK
-- ============================================================================
-- BEGIN;
-- ALTER TABLE clean_data.maintenance_object
--     DROP COLUMN IF EXISTS risk_factor,
--     DROP COLUMN IF EXISTS zone;
-- COMMIT;
