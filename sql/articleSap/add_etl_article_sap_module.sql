-- =====================================================
-- Enregistrement du module ETL Article SAP dans etl_target_tables
-- Description : catalogue des articles (clean_data.part_catalog) pour les
--               articles de raw_data.article_sap, infos lues dans SAP
--               (module etl_article_sap.py, fonction
--               sql/articleSap/alimenter_part_catalog_sap.sql).
-- ORDRE : execution_order = 11. La fonction fait un TRUNCATE de part_catalog :
--         - APRES le module Articles SAP historique (order 8), qui vide aussi
--           part_catalog ;
--         - AVANT les modules articles PHL / Composants (order 12), qui
--           ajoutent leurs articles a part_catalog.
-- Idempotent : re-execute, le script met a jour la ligne existante (reperee
-- par python_module = 'etl_article_sap.py').
-- =====================================================

DO $$
DECLARE
    v_id INTEGER;
BEGIN
    SELECT id INTO v_id
    FROM etl_target_tables
    WHERE python_module = 'etl_article_sap.py'
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
            'part_catalog',
            'Articles - Article SAP (fichier article_sap) ==> IFS',
            'Catalogue des articles IFS (clean_data.part_catalog) pour les articles du fichier raw_data.article_sap existant dans SAP (mara, mandt 700). Designation makt (F), unite mara.meins transcodee UOM (repli *), suivi par lot marc.xchar sur 9200/9000, texte de commande SAP. TRUNCATE + INSERT : a lancer avant les modules articles PHL / Composants.',
            'raw_data',
            'clean_data',
            'etl_article_sap.py',
            11,
            null,
            true,
            'package',
            CURRENT_TIMESTAMP,
            CURRENT_TIMESTAMP,
            'ETL_SYSTEM',
            'IFS_Articles',
            28
        );

        RAISE NOTICE 'Module ETL Article SAP insere avec id = %', v_id;
    ELSE
        UPDATE etl_target_tables SET
            table_name          = 'part_catalog',
            display_name        = 'Articles - Article SAP (fichier article_sap) ==> IFS',
            description         = 'Catalogue des articles IFS (clean_data.part_catalog) pour les articles du fichier raw_data.article_sap existant dans SAP (mara, mandt 700). Designation makt (F), unite mara.meins transcodee UOM (repli *), suivi par lot marc.xchar sur 9200/9000, texte de commande SAP. TRUNCATE + INSERT : a lancer avant les modules articles PHL / Composants.',
            source_schema       = 'raw_data',
            target_schema       = 'clean_data',
            python_module       = 'etl_article_sap.py',
            execution_order     = 11,
            dependent_on        = null,
            is_active           = true,
            icon_name           = 'package',
            last_modified       = CURRENT_TIMESTAMP,
            domaine_fonctionnel = 'IFS_Articles',
            display_order       = 28
        WHERE id = v_id;

        RAISE NOTICE 'Module ETL Article SAP mis a jour (id = %)', v_id;
    END IF;
END $$;

SELECT id, table_name, display_name, domaine_fonctionnel, python_module,
       execution_order, display_order, is_active
FROM etl_target_tables
WHERE python_module = 'etl_article_sap.py';
