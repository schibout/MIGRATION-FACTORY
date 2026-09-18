-- =====================================================
-- Script SQL pour ajouter le module ETL Opérations de maintenance à la table etl_target_tables
-- Description : enregistre le module de chargement des opérations de maintenance
--               (bons de travail SAP PM) depuis raw_data.afvc/afko/crhd + raw_data.resb
--               vers les tables clean_data jt_task / jt_task_resource / maint_material_req_line
--               (module etl_operation.py, fonctions sql/operation/).
--
-- ORDRE : execution_order = 14 (après le module PM Actions, order 13). Le module est
--         autonome (chaque fonction TRUNCATE + INSERT ; jt_task alimentée en premier,
--         les tables filles filtrent via EXISTS sur jt_task).
--
-- Robustesse : l'id est calculé automatiquement (MAX(id)+1) pour éviter toute
--              collision. Script idempotent : ré-exécuté, il met à jour la ligne
--              existante (repérée par python_module = 'etl_operation.py').
-- =====================================================

DO $$
DECLARE
    v_id INTEGER;
BEGIN
    -- La ligne existe-t-elle déjà (par module Python) ?
    SELECT id INTO v_id
    FROM etl_target_tables
    WHERE python_module = 'etl_operation.py'
    LIMIT 1;

    IF v_id IS NULL THEN
        -- Premier enregistrement : on prend le prochain id libre
        SELECT COALESCE(MAX(id), 0) + 1 INTO v_id FROM etl_target_tables;

        INSERT INTO etl_target_tables (
            id,
            table_name,
            display_name,
            description,
            source_schema,
            target_schema,
            python_module,
            execution_order,
            dependent_on,
            is_active,
            icon_name,
            last_modified,
            created_at,
            created_by,
            domaine_fonctionnel,
            display_order
        ) VALUES (
            v_id,
            'jt_task',
            'Opérations de maintenance (JT Task)',
            'Module ETL pour le chargement des opérations de maintenance (bons de travail SAP PM) depuis raw_data.afvc/afko/crhd et raw_data.resb vers clean_data.jt_task, jt_task_resource, maint_material_req_line. task_seq = aufpl*100000000 + aplzl. jt_task alimentée en premier ; jt_task_resource (demandes ressources, resource_group_seq via resource_detail_file + transcodification RESOURCE_GROUP/ARBPL) et maint_material_req_line (besoins matière RESB) filtrent via EXISTS sur jt_task. Chaque fonction fait TRUNCATE + INSERT (idempotent).',
            'raw_data',
            'clean_data',
            'etl_operation.py',
            14,
            null,
            true,
            'handyman',
            CURRENT_TIMESTAMP,
            CURRENT_TIMESTAMP,
            'ETL_SYSTEM',
            'IFS_Maintenance',
            25
        );

        RAISE NOTICE 'Module ETL Opérations de maintenance inséré avec id = %', v_id;
    ELSE
        -- Mise à jour idempotente
        UPDATE etl_target_tables SET
            table_name          = 'jt_task',
            display_name        = 'Opérations de maintenance (JT Task)',
            description         = 'Module ETL pour le chargement des opérations de maintenance (bons de travail SAP PM) depuis raw_data.afvc/afko/crhd et raw_data.resb vers clean_data.jt_task, jt_task_resource, maint_material_req_line. task_seq = aufpl*100000000 + aplzl. jt_task alimentée en premier ; jt_task_resource (demandes ressources, resource_group_seq via resource_detail_file + transcodification RESOURCE_GROUP/ARBPL) et maint_material_req_line (besoins matière RESB) filtrent via EXISTS sur jt_task. Chaque fonction fait TRUNCATE + INSERT (idempotent).',
            source_schema       = 'raw_data',
            target_schema       = 'clean_data',
            python_module       = 'etl_operation.py',
            execution_order     = 14,
            dependent_on        = null,
            is_active           = true,
            icon_name           = 'handyman',
            last_modified       = CURRENT_TIMESTAMP,
            domaine_fonctionnel = 'IFS_Maintenance',
            display_order       = 25
        WHERE id = v_id;

        RAISE NOTICE 'Module ETL Opérations de maintenance mis à jour (id = %)', v_id;
    END IF;
END $$;

-- Vérification de l'insertion / mise à jour
SELECT
    id,
    table_name,
    display_name,
    domaine_fonctionnel,
    python_module,
    execution_order,
    display_order,
    is_active
FROM etl_target_tables
WHERE python_module = 'etl_operation.py';

-- Message de confirmation
DO $$
BEGIN
    RAISE NOTICE '========================================';
    RAISE NOTICE '✅ Module ETL Opérations de maintenance enregistré';
    RAISE NOTICE '========================================';
    RAISE NOTICE 'Nom affiché : Opérations de maintenance (JT Task)';
    RAISE NOTICE 'Module Python : etl_operation.py';
    RAISE NOTICE 'Domaine : IFS_Maintenance';
    RAISE NOTICE 'Statut : Actif';
    RAISE NOTICE '========================================';
    RAISE NOTICE 'Prérequis : compiler les fonctions (sql/operation/compile.sh)';
    RAISE NOTICE 'Le module est disponible dans l''interface de chargement des données';
    RAISE NOTICE 'URL : http://10.190.100.58:3000/data-loading';
    RAISE NOTICE '========================================';
END $$;
