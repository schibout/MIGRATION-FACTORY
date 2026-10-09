-- 114 : l'export « Hierarchie de maintenance complete » (migration 113) prend la
-- structure IFS de equipment_functional (memes 65 colonnes, meme ordre).
--
-- Meme arbre que la 113 (postes techniques, equipements, nomenclatures deroulees,
-- niveau par niveau). Regles reprises de clean_data.alimenter_equipment_functional :
--   contract / sup_contract = 'SJ', mch_code = code, mch_name = designation (200 car.),
--   sup_mch_code = code du parent, obj_level = transcodification ObjectLevel (1..8),
--   is_category_object / is_geographic_object = 'FALSE', operational_status_db = 'IN_OPERATION'.
-- En plus, pour cet export :
--   note        = nature de la ligne (Poste technique / Equipement / Article (nomenclature)) ;
--   part_no     = article de l'equipement (equi.matnr) ou article de la ligne de nomenclature ;
--   cost_center = centre de couts IH02 (NULL volontaire dans equipment_functional) ;
--   equipements : fabricant, n° de serie, type, prix / date d'achat, fin de garantie,
--                 fournisseur (get_vendor_no_ifs) lus dans les attributs SAP.
-- Les colonnes non alimentees sortent a NULL : l'export complete la liste
-- (column_list) par des NULL, la vue ne porte donc que les colonnes alimentees.
-- ATTENTION : un article utilise dans plusieurs nomenclatures donne plusieurs lignes
-- avec le meme mch_code (une par usage).

DROP VIEW IF EXISTS clean_data.v_hierarchie_maintenance;

CREATE VIEW clean_data.v_hierarchie_maintenance AS
WITH RECURSIVE arbre AS (
    SELECT o.id, 1 AS niveau, NULL::bigint AS parent_affiche,
           ARRAY[o.id] AS ids,
           ARRAY[CASE o.object_type WHEN 'FUNC_LOC' THEN '1' || o.code ELSE '2' || o.sap_key END] AS tri
    FROM clean_data.maintenance_object o
    WHERE o.is_active AND o.parent_id IS NULL AND o.object_type IN ('FUNC_LOC', 'EQUIPMENT')
    UNION ALL
    SELECT c.id, a.niveau + 1, a.id, a.ids || c.id,
           a.tri || CASE c.object_type
                        WHEN 'FUNC_LOC'  THEN '1' || c.code
                        WHEN 'EQUIPMENT' THEN '2' || c.sap_key
                        ELSE '3' || lpad(COALESCE(c.sort_order, 0)::text, 8, '0') || COALESCE(c.attributes->>'stlkn', '')
                    END
    FROM arbre a
    JOIN clean_data.maintenance_object n ON n.id = a.id
    JOIN clean_data.maintenance_object c
      ON c.is_active
     AND c.parent_id = CASE WHEN n.object_type = 'BOM_ITEM' THEN n.ref_object_id ELSE n.id END
    WHERE c.id <> ALL (a.ids) AND a.niveau < 50
),
-- Dates SAP YYYYMMDD ('00000000' / vide -> NULL)
eq AS (
    SELECT o.id,
           CASE WHEN o.attributes->>'ansdt' ~ '^[0-9]{8}$' AND o.attributes->>'ansdt' <> '00000000'
                THEN to_date(o.attributes->>'ansdt', 'YYYYMMDD') END AS purch_date,
           CASE WHEN o.attributes->>'gwlen' ~ '^[0-9]{8}$' AND o.attributes->>'gwlen' <> '00000000'
                THEN to_date(o.attributes->>'gwlen', 'YYYYMMDD') END AS warr_exp,
           NULLIF(NULLIF(o.attributes->>'answt', ''), '0.0')::numeric AS purch_price,
           NULLIF(TRIM(o.attributes->>'herst'), '') AS manufacturer_no,
           NULLIF(TRIM(o.attributes->>'sernr'), '') AS serial_no,
           NULLIF(TRIM(o.attributes->>'typbz'), '') AS type,
           NULLIF(LTRIM(o.attributes->>'matnr', '0'), '') AS part_no,
           public.get_vendor_no_ifs(NULLIF(TRIM(o.attributes->>'elief'), '')) AS vendor_no
    FROM clean_data.maintenance_object o
    WHERE o.object_type = 'EQUIPMENT'
),
-- ObjectLevel resolu une fois par niveau (et non 148 000 fois)
niv AS (
    SELECT n, public.get_transcodification('ObjectLevel', n::varchar) AS obj_level
    FROM generate_series(1, 8) n
)
SELECT ROW_NUMBER() OVER (ORDER BY a.niveau, a.tri) AS equipment_object_seq,
       'SJ'::varchar                                AS contract,
       o.code                                       AS mch_code,
       SUBSTRING(COALESCE(o.designation, r.designation, o.code), 1, 200) AS mch_name,
       eq.type,
       eq.manufacturer_no,
       eq.serial_no,
       COALESCE(eq.part_no, r.code)                 AS part_no,
       o.cost_center,
       'FALSE'::varchar                             AS is_category_object,
       'FALSE'::varchar                             AS is_geographic_object,
       niv.obj_level,
       eq.purch_price,
       eq.purch_date,
       eq.warr_exp,
       CASE o.object_type
           WHEN 'FUNC_LOC'  THEN 'Poste technique'
           WHEN 'EQUIPMENT' THEN 'Equipement'
           WHEN 'BOM_ITEM'  THEN 'Article (nomenclature)'
           ELSE o.object_type
       END                                          AS note,
       eq.vendor_no,
       'IN_OPERATION'::varchar                      AS operational_status_db,
       CASE WHEN p.id IS NOT NULL THEN 'SJ' END::varchar AS sup_contract,
       p.code                                       AS sup_mch_code
FROM arbre a
JOIN clean_data.maintenance_object o ON o.id = a.id
LEFT JOIN clean_data.maintenance_object p ON p.id = a.parent_affiche
LEFT JOIN clean_data.maintenance_object r ON r.id = o.ref_object_id
LEFT JOIN eq ON eq.id = o.id
JOIN niv ON niv.n = LEAST(a.niveau, 8)
ORDER BY a.niveau, a.tri;

UPDATE public.etl_export_queries
SET column_list = 'equipment_object_seq,contract,mch_code,mch_name,mch_loc,mch_pos,equipment_main_position,equipment_main_position_db,group_id,mch_type,cost_center,object_no,category_id,manufacturer_no,serial_no,type,part_no,is_category_object,is_geographic_object,criticality,item_class_id,cluster_id,location_id,applied_pm_program_id,applied_pm_program_rev,applied_date,pm_prog_application_status,not_applicable_reason,not_applicable_set_user,not_applicable_set_date,safe_access_code,safe_access_code_db,process_class_id,functional_object_seq,location_object_seq,from_object_seq,to_object_seq,process_object_seq,pipe_object_seq,circuit_object_seq,model_id,safety_critical_element,safety_critical_element_db,area_id,deck_id,maintenance_strategy_id,obj_level,mch_doc,purch_price,purch_date,warr_exp,note,info,data,production_date,technical_lifetime,vendor_no,plant_design_id,operational_status,operational_status_db,plant_design_projphase,plant_design_cotproj_projid,manufactured_date,sup_contract,sup_mch_code',
    description = 'Arbre IH02 complet (postes techniques, équipements, nomenclatures) au format IFS equipment_functional, niveau par niveau ; note = nature de la ligne',
    updated_at = now(),
    updated_by = 'migration_114'
WHERE table_name = 'v_hierarchie_maintenance';
