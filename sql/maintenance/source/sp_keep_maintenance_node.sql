-- =====================================================================
-- clean_data.sp_keep_maintenance_node(VARIADIC p_mch_codes)  —  ONE-SHOT DE TEST
--
-- Reduit les tables d'export IFS de la structure de maintenance a UN OU PLUSIEURS
-- noeuds, leurs PARENTS (jusqu'a la racine) et tous ses ENFANTS :
--   equipment_functional (postes techniques) + equipment_serial (equipements)
--     -> noeud + ascendants + descendants (lien mch_code / sup_mch_code, les
--        deux tables formant un seul arbre : un equipement pointe sur son poste)
--   equipment_object_spare      -> lignes dont l'objet (equipment_object_seq =
--                                  mch_code du poste) est conserve
--   equipment_spare_structure   -> structures kit -> composants atteignables
--                                  depuis les articles conserves (recursif)
--
-- DESTRUCTIF (DELETE) et non compile par compile.sh : un rechargement du module
-- ETL « Maintenance - Structure de maintenance et equipements » remet tout.
-- maintenance_object (ecran IH02) n'est PAS touchee.
--
-- Usage : CALL clean_data.sp_keep_maintenance_node('T200-X060');
--         CALL clean_data.sp_keep_maintenance_node('T650-A', 'T200-X060', '10001234');
-- Un code absent des deux tables -> erreur, rien n'est supprime.
-- Essai a blanc : BEGIN; CALL ...; <controles>; ROLLBACK;
-- =====================================================================
DROP PROCEDURE IF EXISTS clean_data.sp_keep_maintenance_node(varchar);

CREATE OR REPLACE PROCEDURE clean_data.sp_keep_maintenance_node(VARIADIC p_mch_codes varchar[])
LANGUAGE plpgsql
AS $procedure$
DECLARE
    v_n        integer;
    v_absents  text;
BEGIN
    SELECT string_agg(c, ', ') INTO v_absents
    FROM unnest(p_mch_codes) c
    WHERE NOT EXISTS (SELECT 1 FROM clean_data.equipment_functional f WHERE f.mch_code = c)
      AND NOT EXISTS (SELECT 1 FROM clean_data.equipment_serial s WHERE s.mch_code = c);
    IF v_absents IS NOT NULL THEN
        RAISE EXCEPTION 'Noeud(s) absent(s) de equipment_functional et de equipment_serial : % -- rien n''est supprime', v_absents;
    END IF;

    CREATE TEMP TABLE _keep_obj ON COMMIT DROP AS
    WITH RECURSIVE arbre AS (
        SELECT mch_code, sup_mch_code FROM clean_data.equipment_functional
        UNION
        SELECT mch_code, sup_mch_code FROM clean_data.equipment_serial
    ),
    ascendants AS (
        SELECT a.mch_code, a.sup_mch_code, ARRAY[a.mch_code::text] AS chemin
        FROM arbre a WHERE a.mch_code = ANY (p_mch_codes)
        UNION ALL
        SELECT a.mch_code, a.sup_mch_code, s.chemin || a.mch_code::text
        FROM ascendants s JOIN arbre a ON a.mch_code = s.sup_mch_code
        WHERE a.mch_code::text <> ALL (s.chemin)
    ),
    descendants AS (
        SELECT a.mch_code, ARRAY[a.mch_code::text] AS chemin
        FROM arbre a WHERE a.mch_code = ANY (p_mch_codes)
        UNION ALL
        SELECT a.mch_code, d.chemin || a.mch_code::text
        FROM descendants d JOIN arbre a ON a.sup_mch_code = d.mch_code
        WHERE a.mch_code::text <> ALL (d.chemin)
    )
    SELECT mch_code FROM ascendants
    UNION
    SELECT mch_code FROM descendants;

    SELECT count(*) INTO v_n FROM _keep_obj;
    RAISE NOTICE 'Noeud(s) % : % objets conserves (parents + noeuds + enfants)', array_to_string(p_mch_codes, ', '), v_n;

    DELETE FROM clean_data.equipment_functional t
    WHERE NOT EXISTS (SELECT 1 FROM _keep_obj k WHERE k.mch_code = t.mch_code);
    GET DIAGNOSTICS v_n = ROW_COUNT;
    RAISE NOTICE 'equipment_functional : % lignes supprimees', v_n;

    DELETE FROM clean_data.equipment_serial t
    WHERE NOT EXISTS (SELECT 1 FROM _keep_obj k WHERE k.mch_code = t.mch_code);
    GET DIAGNOSTICS v_n = ROW_COUNT;
    RAISE NOTICE 'equipment_serial : % lignes supprimees', v_n;

    DELETE FROM clean_data.equipment_object_spare t
    WHERE NOT EXISTS (SELECT 1 FROM _keep_obj k WHERE k.mch_code::text = t.equipment_object_seq::text);
    GET DIAGNOSTICS v_n = ROW_COUNT;
    RAISE NOTICE 'equipment_object_spare : % lignes supprimees', v_n;

    -- Structures kit -> composants atteignables depuis les articles restants
    CREATE TEMP TABLE _keep_kit ON COMMIT DROP AS
    WITH RECURSIVE kit AS (
        SELECT DISTINCT spare_id::text AS spare_id FROM clean_data.equipment_object_spare
        UNION
        SELECT s.component_spare_id::text
        FROM kit JOIN clean_data.equipment_spare_structure s ON s.spare_id::text = kit.spare_id
    )
    SELECT spare_id FROM kit;

    DELETE FROM clean_data.equipment_spare_structure t
    WHERE NOT EXISTS (SELECT 1 FROM _keep_kit k WHERE k.spare_id = t.spare_id::text);
    GET DIAGNOSTICS v_n = ROW_COUNT;
    RAISE NOTICE 'equipment_spare_structure : % lignes supprimees', v_n;
END;
$procedure$;
