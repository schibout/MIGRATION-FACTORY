-- =====================================================
-- Enregistrement du module ETL Immobilisations dans etl_target_tables
-- Description : snapshot de raw_data.v_immo_comptes vers
--               clean_data.immobilisation (module etl_immobilisation.py,
--               fonction sql/immobilisation/02_alimenter_immobilisation.sql).
-- ORDRE : execution_order = 16 (apres Commandes d'achat, order 15). Aucune
--         dependance de module : ne lit que raw_data.
-- Idempotent : re-execute, le script met a jour la ligne existante (reperee
-- par python_module = 'etl_immobilisation.py').
-- =====================================================

DO $$
DECLARE
    v_id INTEGER;
BEGIN
    SELECT id INTO v_id
    FROM etl_target_tables
    WHERE python_module = 'etl_immobilisation.py'
    LIMIT 1;

    IF v_id IS NULL THEN
        SELECT COALESCE(MAX(id), 0) + 1 INTO v_id FROM etl_target_tables;

        INSERT INTO etl_target_tables (
            id, table_name, display_name, description,
            source_schema, target_schema, python_module,
            execution_order, dependent_on, is_active, icon_name,
            last_modified, created_at, created_by,
            domaine_fonctionnel, display_order
        ) VALUES (
            v_id,
            'immobilisation',
            'Immobilisations SAP (comptes FI-AA)',
            'Module ETL des immobilisations SAP : snapshot de raw_data.v_immo_comptes (tout ANLA x zones d''amortissement, avec la determination comptable FI-AA T095/T095B : comptes de valeur d''acquisition, d''amortissement et de cession) vers clean_data.immobilisation. TRUNCATE + INSERT (idempotent).',
            'raw_data',
            'clean_data',
            'etl_immobilisation.py',
            16,
            null,
            true,
            'account_balance',
            CURRENT_TIMESTAMP,
            CURRENT_TIMESTAMP,
            'ETL_SYSTEM',
            'IFS_Finance',
            27
        );

        RAISE NOTICE 'Module ETL Immobilisations insere avec id = %', v_id;
    ELSE
        UPDATE etl_target_tables SET
            table_name          = 'immobilisation',
            display_name        = 'Immobilisations SAP (comptes FI-AA)',
            description         = 'Module ETL des immobilisations SAP : snapshot de raw_data.v_immo_comptes (tout ANLA x zones d''amortissement, avec la determination comptable FI-AA T095/T095B : comptes de valeur d''acquisition, d''amortissement et de cession) vers clean_data.immobilisation. TRUNCATE + INSERT (idempotent).',
            source_schema       = 'raw_data',
            target_schema       = 'clean_data',
            python_module       = 'etl_immobilisation.py',
            execution_order     = 16,
            dependent_on        = null,
            is_active           = true,
            icon_name           = 'account_balance',
            last_modified       = CURRENT_TIMESTAMP,
            domaine_fonctionnel = 'IFS_Finance',
            display_order       = 27
        WHERE id = v_id;

        RAISE NOTICE 'Module ETL Immobilisations mis a jour (id = %)', v_id;
    END IF;
END $$;

SELECT id, table_name, display_name, domaine_fonctionnel, python_module,
       execution_order, display_order, is_active, module_params
FROM etl_target_tables
WHERE python_module = 'etl_immobilisation.py';
