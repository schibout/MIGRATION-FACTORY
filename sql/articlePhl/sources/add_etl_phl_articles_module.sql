-- =====================================================
-- Script SQL pour ajouter le module ETL Articles PHL à la table etl_target_tables
-- Description : enregistre le module de chargement des articles PHL depuis
--               raw_data.phl_article vers les tables clean_data (module etl_phl_article.py).
--
-- ORDRE : execution_order = 12, SUPÉRIEUR à celui du module Articles SAP (etl_inventory_part.py,
--         order 8). Les fonctions PHL insèrent en APPEND dans les mêmes tables clean_data que
--         le module SAP (qui les TRUNCATE) ; le module Articles PHL doit donc passer APRÈS.
--
-- Robustesse : l'id est calculé automatiquement (MAX(id)+1) pour éviter toute
--              collision avec les modules déjà présents en base. Le script est
--              idempotent : ré-exécuté, il met à jour la ligne existante
--              (repérée par python_module = 'etl_phl_article.py').
-- =====================================================

DO $$
DECLARE
    v_id INTEGER;
BEGIN
    -- La ligne existe-t-elle déjà (par module Python) ?
    SELECT id INTO v_id
    FROM etl_target_tables
    WHERE python_module = 'etl_phl_article.py'
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
            'inventory_part_phl',
            'Articles PHL',
            'Module ETL pour le chargement des articles PHL depuis raw_data.phl_article vers les tables clean_data (part_catalog, inventory_part, sales_part, purchase_part). Clé = N. ARTICLE. Insertion en APPEND APRÈS le module Articles SAP (qui vide les tables). Contract = SJ. Pas de purchase_part_supplier (aucun fournisseur dans la source PHL). Mêmes valeurs par défaut que les procédures SAP (transcodification UOM incluse).',
            'raw_data',
            'clean_data',
            'etl_phl_article.py',
            12,
            null,
            true,
            'package',
            CURRENT_TIMESTAMP,
            CURRENT_TIMESTAMP,
            'ETL_SYSTEM',
            'IFS_Articles',
            23
        );

        RAISE NOTICE 'Module ETL Articles PHL inséré avec id = %', v_id;
    ELSE
        -- Mise à jour idempotente
        UPDATE etl_target_tables SET
            table_name          = 'inventory_part_phl',
            display_name        = 'Articles PHL',
            description         = 'Module ETL pour le chargement des articles PHL depuis raw_data.phl_article vers les tables clean_data (part_catalog, inventory_part, sales_part, purchase_part). Clé = N. ARTICLE. Insertion en APPEND APRÈS le module Articles SAP (qui vide les tables). Contract = SJ. Pas de purchase_part_supplier (aucun fournisseur dans la source PHL). Mêmes valeurs par défaut que les procédures SAP (transcodification UOM incluse).',
            source_schema       = 'raw_data',
            target_schema       = 'clean_data',
            python_module       = 'etl_phl_article.py',
            execution_order     = 12,
            dependent_on        = null,
            is_active           = true,
            icon_name           = 'package',
            last_modified       = CURRENT_TIMESTAMP,
            domaine_fonctionnel = 'IFS_Articles',
            display_order       = 23
        WHERE id = v_id;

        RAISE NOTICE 'Module ETL Articles PHL mis à jour (id = %)', v_id;
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
WHERE python_module = 'etl_phl_article.py';

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
    RAISE NOTICE '✅ Module ETL Articles PHL enregistré';
    RAISE NOTICE '========================================';
    RAISE NOTICE 'Nom affiché : Articles PHL';
    RAISE NOTICE 'Module Python : etl_phl_article.py';
    RAISE NOTICE 'Domaine : IFS_Articles';
    RAISE NOTICE 'Statut : Actif';
    RAISE NOTICE '========================================';
    RAISE NOTICE 'À exécuter APRÈS le module Articles SAP (qui TRUNCATE les tables cibles)';
    RAISE NOTICE 'Le module est maintenant disponible dans l''interface de chargement des données';
    RAISE NOTICE 'URL : http://10.190.100.58:3000/data-loading';
    RAISE NOTICE '========================================';
END $$;
