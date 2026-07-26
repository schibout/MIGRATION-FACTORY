-- =====================================================
-- Script SQL pour ajouter le module ETL PM Actions à la table etl_target_tables
-- Description : enregistre le module de chargement des actions de maintenance
--               préventive depuis raw_data.pe_tools vers les tables clean_data
--               pm_action / pm_action_work_step / pm_action_resource / pm_action_role
--               (module etl_pm_action.py, procédures sql/pm_actions/).
--
-- ORDRE : execution_order = 13 (après le module Articles PHL, order 12). Le module est
--         autonome (grain 1 ligne pe_tools = 1 pm_action, chaque procédure TRUNCATE + INSERT).
--
-- Robustesse : l'id est calculé automatiquement (MAX(id)+1) pour éviter toute
--              collision. Script idempotent : ré-exécuté, il met à jour la ligne
--              existante (repérée par python_module = 'etl_pm_action.py').
-- =====================================================

DO $$
DECLARE
    v_id INTEGER;
BEGIN
    -- La ligne existe-t-elle déjà (par module Python) ?
    SELECT id INTO v_id
    FROM etl_target_tables
    WHERE python_module = 'etl_pm_action.py'
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
            'pm_action',
            'Actions de maintenance préventive (PM)',
            'Module ETL pour le chargement des actions de maintenance préventive depuis raw_data.pe_tools (gammes d''entretien SAP) vers clean_data.pm_action, pm_action_work_step, pm_action_resource, pm_action_role. Grain : 1 ligne pe_tools = 1 pm_action. pm_no = plan_entretien (repli 900000+raw_id). Fréquence décodée S/M/A -> Semaines/Mois/Années. Constantes IFS paramétrables dans les procédures (org_code, connection_type, demand_type, unités _db) à confirmer avant le run réel.',
            'raw_data',
            'clean_data',
            'etl_pm_action.py',
            13,
            null,
            true,
            'build',
            CURRENT_TIMESTAMP,
            CURRENT_TIMESTAMP,
            'ETL_SYSTEM',
            'IFS_Maintenance',
            24
        );

        RAISE NOTICE 'Module ETL PM Actions inséré avec id = %', v_id;
    ELSE
        -- Mise à jour idempotente
        UPDATE etl_target_tables SET
            table_name          = 'pm_action',
            display_name        = 'Actions de maintenance préventive (PM)',
            description         = 'Module ETL pour le chargement des actions de maintenance préventive depuis raw_data.pe_tools (gammes d''entretien SAP) vers clean_data.pm_action, pm_action_work_step, pm_action_resource, pm_action_role. Grain : 1 ligne pe_tools = 1 pm_action. pm_no = plan_entretien (repli 900000+raw_id). Fréquence décodée S/M/A -> Semaines/Mois/Années. Constantes IFS paramétrables dans les procédures (org_code, connection_type, demand_type, unités _db) à confirmer avant le run réel.',
            source_schema       = 'raw_data',
            target_schema       = 'clean_data',
            python_module       = 'etl_pm_action.py',
            execution_order     = 13,
            dependent_on        = null,
            is_active           = true,
            icon_name           = 'build',
            last_modified       = CURRENT_TIMESTAMP,
            domaine_fonctionnel = 'IFS_Maintenance',
            display_order       = 24
        WHERE id = v_id;

        RAISE NOTICE 'Module ETL PM Actions mis à jour (id = %)', v_id;
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
WHERE python_module = 'etl_pm_action.py';

-- Message de confirmation
DO $$
BEGIN
    RAISE NOTICE '========================================';
    RAISE NOTICE '✅ Module ETL PM Actions enregistré';
    RAISE NOTICE '========================================';
    RAISE NOTICE 'Nom affiché : Actions de maintenance préventive (PM)';
    RAISE NOTICE 'Module Python : etl_pm_action.py';
    RAISE NOTICE 'Domaine : IFS_Maintenance';
    RAISE NOTICE 'Statut : Actif';
    RAISE NOTICE '========================================';
    RAISE NOTICE 'Prérequis : compiler les procédures (sql/pm_actions/compile.sh)';
    RAISE NOTICE 'Le module est disponible dans l''interface de chargement des données';
    RAISE NOTICE 'URL : http://10.190.100.58:3000/data-loading';
    RAISE NOTICE '========================================';
END $$;
