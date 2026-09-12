-- =====================================================
-- Enregistrement du module ETL Commandes d'achat dans etl_target_tables
-- Description : chargement des commandes d'achat SAP ouvertes (EKKO/EKPO/EKBE/
--               EKET/EKPA/EKKN) vers clean_data.commande_achat_ifs, format de
--               reprise IFS (module etl_commande_achat.py, fonction
--               sql/commandeAchat/02_alimenter_commande_achat_ifs.sql).
--
-- ORDRE : execution_order = 15 (apres Operations de maintenance, order 14).
--         Pas de dependance de module : le fournisseur IFS est lu dans le
--         FICHIER clean_data.ifs_fournisseurs (get_vendor_no_ifs), pas dans les
--         tables du module fournisseur.
--
-- module_params (optionnel) : {"date_debut": "2026-01-01", "date_fin": "2026-08-31"}
--         -> bornes sur EKKO-AEDAT transmises a run_etl(). NULL = toutes les
--         commandes ouvertes.
--
-- Idempotent : l'id est calcule (MAX(id)+1) ; re-execute, le script met a jour
-- la ligne existante (reperee par python_module = 'etl_commande_achat.py').
-- =====================================================

DO $$
DECLARE
    v_id INTEGER;
BEGIN
    SELECT id INTO v_id
    FROM etl_target_tables
    WHERE python_module = 'etl_commande_achat.py'
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
            'commande_achat_ifs',
            'Commandes d''achat SAP (ouvertes)',
            'Module ETL pour le chargement des commandes d''achat SAP ouvertes (reliquat a livrer > 0) depuis raw_data.ekko/ekpo/ekbe/eket/ekpa/ekkn vers clean_data.commande_achat_ifs (format de reprise IFS, une ligne par poste). Fournisseur IFS via le fichier de selection (get_vendor_no_ifs), site deduit de la division (9200=SJ, 9000=CS), unite transcodee UOM (repli ''*''). Si raw_data.ekpo est vide, repli en-tete (une ligne par commande) avec avertissement. TRUNCATE + INSERT (idempotent). module_params optionnel : {"date_debut","date_fin"} sur la date de creation SAP.',
            'raw_data',
            'clean_data',
            'etl_commande_achat.py',
            15,
            null,
            true,
            'shopping_cart',
            CURRENT_TIMESTAMP,
            CURRENT_TIMESTAMP,
            'ETL_SYSTEM',
            'IFS_Purchasing',
            26
        );

        RAISE NOTICE 'Module ETL Commandes d''achat insere avec id = %', v_id;
    ELSE
        UPDATE etl_target_tables SET
            table_name          = 'commande_achat_ifs',
            display_name        = 'Commandes d''achat SAP (ouvertes)',
            description         = 'Module ETL pour le chargement des commandes d''achat SAP ouvertes (reliquat a livrer > 0) depuis raw_data.ekko/ekpo/ekbe/eket/ekpa/ekkn vers clean_data.commande_achat_ifs (format de reprise IFS, une ligne par poste). Fournisseur IFS via le fichier de selection (get_vendor_no_ifs), site deduit de la division (9200=SJ, 9000=CS), unite transcodee UOM (repli ''*''). Si raw_data.ekpo est vide, repli en-tete (une ligne par commande) avec avertissement. TRUNCATE + INSERT (idempotent). module_params optionnel : {"date_debut","date_fin"} sur la date de creation SAP.',
            source_schema       = 'raw_data',
            target_schema       = 'clean_data',
            python_module       = 'etl_commande_achat.py',
            execution_order     = 15,
            dependent_on        = null,
            is_active           = true,
            icon_name           = 'shopping_cart',
            last_modified       = CURRENT_TIMESTAMP,
            domaine_fonctionnel = 'IFS_Purchasing',
            display_order       = 26
        WHERE id = v_id;

        RAISE NOTICE 'Module ETL Commandes d''achat mis a jour (id = %)', v_id;
    END IF;
END $$;

SELECT id, table_name, display_name, domaine_fonctionnel, python_module,
       execution_order, display_order, is_active, module_params
FROM etl_target_tables
WHERE python_module = 'etl_commande_achat.py';
