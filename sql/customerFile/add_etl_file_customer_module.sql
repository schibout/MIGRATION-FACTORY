-- =====================================================
-- Script SQL pour ajouter le module ETL Clients FICHIER à la table etl_target_tables
-- Description : enregistre le module de chargement des clients depuis
--               raw_data.file_customer vers les tables clean_data (module etl_file_customer.py).
--
-- Robustesse : l'id est calculé automatiquement (MAX(id)+1) pour éviter toute
--              collision avec les modules déjà présents en base. Le script est
--              idempotent : ré-exécuté, il met à jour la ligne existante
--              (repérée par python_module = 'etl_file_customer.py').
-- =====================================================

DO $$
DECLARE
    v_id INTEGER;
BEGIN
    -- La ligne existe-t-elle déjà (par module Python) ?
    SELECT id INTO v_id
    FROM etl_target_tables
    WHERE python_module = 'etl_file_customer.py'
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
            'customer_info_file',
            'Clients FICHIER',
            'Module ETL pour le chargement des données clients depuis raw_data.file_customer vers les tables clean_data (customer_info, customer_info_address, cust_ord_customer, taxes, paiements, etc.). Source alternative aux modules SAP et PHL : alimente les mêmes tables clean_data via les procédures clean_data.sp_*_from_file_customer, avec jointures de repli vers KNA1/KNB1/KNVV. customer_id dérivé de nouveau_compte_ifs (repli num_corrige/kunnr).',
            'raw_data',
            'clean_data',
            'etl_file_customer.py',
            11,
            null,
            true,
            'person',
            CURRENT_TIMESTAMP,
            CURRENT_TIMESTAMP,
            'ETL_SYSTEM',
            'IFS_Customers',
            22
        );

        RAISE NOTICE 'Module ETL Clients FICHIER inséré avec id = %', v_id;
    ELSE
        -- Mise à jour idempotente
        UPDATE etl_target_tables SET
            table_name          = 'customer_info_file',
            display_name        = 'Clients FICHIER',
            description         = 'Module ETL pour le chargement des données clients depuis raw_data.file_customer vers les tables clean_data (customer_info, customer_info_address, cust_ord_customer, taxes, paiements, etc.). Source alternative aux modules SAP et PHL : alimente les mêmes tables clean_data via les procédures clean_data.sp_*_from_file_customer, avec jointures de repli vers KNA1/KNB1/KNVV. customer_id dérivé de nouveau_compte_ifs (repli num_corrige/kunnr).',
            source_schema       = 'raw_data',
            target_schema       = 'clean_data',
            python_module       = 'etl_file_customer.py',
            execution_order     = 11,
            dependent_on        = null,
            is_active           = true,
            icon_name           = 'person',
            last_modified       = CURRENT_TIMESTAMP,
            domaine_fonctionnel = 'IFS_Customers',
            display_order       = 22
        WHERE id = v_id;

        RAISE NOTICE 'Module ETL Clients FICHIER mis à jour (id = %)', v_id;
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
    is_active,
    description
FROM etl_target_tables
WHERE python_module = 'etl_file_customer.py';

-- Afficher tous les modules ETL actifs triés par ordre d'exécution
SELECT
    id,
    display_name,
    python_module,
    execution_order,
    is_active,
    domaine_fonctionnel
FROM etl_target_tables
WHERE is_active = true
ORDER BY execution_order, display_order;

-- Message de confirmation
DO $$
BEGIN
    RAISE NOTICE '========================================';
    RAISE NOTICE '✅ Module ETL Clients FICHIER enregistré';
    RAISE NOTICE '========================================';
    RAISE NOTICE 'Nom affiché : Clients FICHIER';
    RAISE NOTICE 'Module Python : etl_file_customer.py';
    RAISE NOTICE 'Domaine : IFS_Customers';
    RAISE NOTICE 'Statut : Actif';
    RAISE NOTICE '========================================';
    RAISE NOTICE 'Le module est maintenant disponible dans l''interface de chargement des données';
    RAISE NOTICE 'URL : http://10.190.100.58:3000/data-loading';
    RAISE NOTICE '========================================';
END $$;
