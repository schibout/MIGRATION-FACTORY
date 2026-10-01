-- =====================================================================
-- clean_data.alimenter_all_projet
-- ---------------------------------------------------------------------
-- Enchaîne toutes les fonctions de chargement du module PROJET dans
-- l'ordre des dépendances (même ordre que etl_modules/etl_project.py,
-- plus l'association des utilisateurs SharePoint). project_margin_matrix
-- est obsolète et volontairement absente.
--
-- Tout s'exécute dans UNE transaction : la première erreur annule
-- l'ensemble (chaque fonction fait un RAISE après son log d'erreur).
--
-- Usage : SELECT clean_data.alimenter_all_projet();
-- =====================================================================
CREATE OR REPLACE FUNCTION clean_data.alimenter_all_projet()
 RETURNS void
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_etapes TEXT[] := ARRAY[
        'associer_sharepoint_users_ifs_person', -- person_id des responsables, lu par les loaders
        'alimenter_ifs_project_base',           -- base : toutes les autres en dépendent
        'alimenter_ifs_project_site_ext',
        'alimenter_ifs_project_role',
        'alimenter_ifs_project_role_assignment',
        'alimenter_sub_project',
        'alimenter_activity',
        'alimenter_project_activity',
        'alimenter_project_activity_class'      -- lit project_activity
    ];
    v_etape TEXT;
    v_debut TIMESTAMP := clock_timestamp();
    v_t     TIMESTAMP;
BEGIN
    FOREACH v_etape IN ARRAY v_etapes LOOP
        v_t := clock_timestamp();
        RAISE NOTICE '>>> clean_data.%() ...', v_etape;
        EXECUTE format('SELECT clean_data.%I()', v_etape);
        RAISE NOTICE '<<< clean_data.%() terminé en %', v_etape, clock_timestamp() - v_t;
    END LOOP;

    RAISE NOTICE 'Module PROJET chargé en %', clock_timestamp() - v_debut;
END;
$function$;
