-- =====================================================================
-- Recette de parite : ancien monde (raw_data) vs nouveau (maintenance_object)
-- A executer apres CALL clean_data.load_maintenance_object();
-- Chaque requete doit renvoyer des volumes coherents / 0 anomalie.
-- =====================================================================

\echo '== 1. Volumes par type =='
SELECT object_type, COUNT(*) AS n
FROM clean_data.maintenance_object
GROUP BY object_type ORDER BY object_type;

\echo '== 2. FUNC_LOC : nouveau vs raw_data.iflot =='
SELECT
    (SELECT COUNT(*) FROM raw_data.iflot)                                          AS iflot_src,
    (SELECT COUNT(*) FROM clean_data.maintenance_object WHERE object_type='FUNC_LOC') AS func_loc_new;

\echo '== 3. EQUIPMENT : nouveau vs raw_data.itob =='
SELECT
    (SELECT COUNT(*) FROM raw_data.itob)                                            AS itob_src,
    (SELECT COUNT(*) FROM clean_data.maintenance_object WHERE object_type='EQUIPMENT') AS equipment_new;

\echo '== 4. Racines FL : nouveau vs raw_data (tplma vide) =='
SELECT
    (SELECT COUNT(*) FROM raw_data.iflot WHERE tplma IS NULL OR TRIM(tplma)='')     AS racines_src,
    (SELECT COUNT(*) FROM clean_data.maintenance_object
       WHERE object_type='FUNC_LOC' AND parent_id IS NULL)                          AS racines_new;

\echo '== 5. BOM_ITEM type T : nouveau vs distinct (tplnr,posnr) STPO T rattachables =='
SELECT
    (SELECT COUNT(*) FROM clean_data.maintenance_object
       WHERE object_type='BOM_ITEM' AND attributes->>'stlty'='T')                   AS bom_t_new;

\echo '== 6. FL orphelins (tplma non resolu) — doit tendre vers 0 =='
SELECT COUNT(*) AS fl_orphelins
FROM clean_data.maintenance_object c
WHERE c.object_type='FUNC_LOC'
  AND c.parent_id IS NULL
  AND NULLIF(TRIM(c.attributes->>'tplma_sap'),'') IS NOT NULL;

\echo '== 7. EQUIPMENT non rattaches (ni FL ni equipement) =='
SELECT COUNT(*) AS eq_sans_parent
FROM clean_data.maintenance_object
WHERE object_type='EQUIPMENT' AND parent_id IS NULL
  AND NULLIF(TRIM(attributes->>'tplnr_sap'),'') IS NOT NULL;

\echo '== 8. BOM_ITEM invalides (contrainte : parent + ref obligatoires) =='
SELECT COUNT(*) AS bom_invalides
FROM clean_data.maintenance_object
WHERE object_type='BOM_ITEM' AND (parent_id IS NULL OR ref_object_id IS NULL);

\echo '== 9. Doublons sap_key par type (doit etre vide) =='
SELECT object_type, sap_key, COUNT(*) n
FROM clean_data.maintenance_object
GROUP BY object_type, sap_key HAVING COUNT(*) > 1;

\echo '== 10. Echantillon : arbre d''un poste connu =='
SELECT object_type, code, designation, work_center, cost_center
FROM clean_data.maintenance_object
WHERE parent_id = (SELECT id FROM clean_data.maintenance_object
                   WHERE object_type='FUNC_LOC' AND code='T340-E100-1005' LIMIT 1)
ORDER BY object_type, code;

\echo '== 11. Parite vue compat v_fl_nomenclature =='
SELECT COUNT(*) AS lignes_v_fl_nomenclature FROM clean_data.v_fl_nomenclature;
