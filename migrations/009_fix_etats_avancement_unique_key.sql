-- =====================================================
-- Migration: Correction de la cle d'unicite sur sharepoint_etats_avancement
-- Probleme: la contrainte UNIQUE(sharepoint_id) ecrase les etats entre sites
--           car chaque site SharePoint a ses propres IDs commencant a 1, 2, 3...
-- Solution: remplacer par UNIQUE(sharepoint_id, site_id)
-- Date: 2026-05-26
-- =====================================================

BEGIN;

-- 1. Supprimer toutes les contraintes UNIQUE existantes sur sharepoint_id seul
DO $$
DECLARE
    rec RECORD;
BEGIN
    FOR rec IN
        SELECT tc.constraint_name
        FROM information_schema.table_constraints tc
        JOIN information_schema.key_column_usage kcu
            ON tc.constraint_name = kcu.constraint_name
           AND tc.table_schema = kcu.table_schema
           AND tc.table_name   = kcu.table_name
        WHERE tc.table_schema = 'raw_data'
          AND tc.table_name   = 'sharepoint_etats_avancement'
          AND tc.constraint_type = 'UNIQUE'
        GROUP BY tc.constraint_name
        HAVING COUNT(*) = 1
           AND MAX(kcu.column_name) = 'sharepoint_id'
    LOOP
        EXECUTE format(
            'ALTER TABLE raw_data.sharepoint_etats_avancement DROP CONSTRAINT %I',
            rec.constraint_name
        );
        RAISE NOTICE 'Contrainte UNIQUE supprimee: %', rec.constraint_name;
    END LOOP;
END $$;

-- 2. S'assurer que site_id est NOT NULL (sinon la contrainte composee laissera passer des doublons)
UPDATE raw_data.sharepoint_etats_avancement
SET site_id = 'unknown'
WHERE site_id IS NULL OR site_id = '';

ALTER TABLE raw_data.sharepoint_etats_avancement
    ALTER COLUMN site_id SET NOT NULL;

-- 3. Ajouter la nouvelle contrainte composee (si pas deja la)
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint
        WHERE conname = 'uq_etats_avancement_sharepoint_site'
          AND conrelid = 'raw_data.sharepoint_etats_avancement'::regclass
    ) THEN
        ALTER TABLE raw_data.sharepoint_etats_avancement
            ADD CONSTRAINT uq_etats_avancement_sharepoint_site
            UNIQUE (sharepoint_id, site_id);
        RAISE NOTICE 'Contrainte UNIQUE(sharepoint_id, site_id) ajoutee';
    ELSE
        RAISE NOTICE 'Contrainte uq_etats_avancement_sharepoint_site deja presente';
    END IF;
END $$;

-- 4. Vider la table pour permettre un re-import propre
--    (les donnees actuelles sont incompletes a cause du bug)
TRUNCATE TABLE raw_data.sharepoint_etats_avancement RESTART IDENTITY;

COMMIT;

-- Verification
SELECT
    COUNT(*)                                     AS lignes_restantes,
    COUNT(DISTINCT site_id)                      AS nb_sites,
    (SELECT COUNT(*) FROM pg_constraint
     WHERE conname = 'uq_etats_avancement_sharepoint_site'
       AND conrelid = 'raw_data.sharepoint_etats_avancement'::regclass) AS contrainte_ok
FROM raw_data.sharepoint_etats_avancement;
