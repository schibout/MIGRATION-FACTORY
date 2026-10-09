-- 113 : export de toute la hierarchie de maintenance (ecran /export/maintenance)
--
-- Vue clean_data.v_hierarchie_maintenance : l'arbre IH02 (clean_data.maintenance_object)
-- aplati, une ligne par noeud dans l'ordre de l'arbre :
--   racines = postes techniques sans parent (T) + equipements sans parent ;
--   enfants = postes techniques, equipements, lignes de nomenclature (parent_id) ;
--   sous une ligne de nomenclature, la nomenclature de l'article reference
--   (ref_object_id) est deroulee a son tour (garde anti-cycle sur le chemin).
-- Un article present dans plusieurs nomenclatures apparait donc a chaque usage.
-- Lignes inactives (soft delete) exclues avec tout leur sous-arbre.
-- Ordre : niveau par niveau (tous les parents avant leurs enfants), puis dans un niveau
-- ordre de l'arbre IH02 : postes par code, equipements par sap_key, nomenclature par position.

CREATE OR REPLACE VIEW clean_data.v_hierarchie_maintenance AS
WITH RECURSIVE arbre AS (
    SELECT o.id, 1 AS niveau, NULL::bigint AS parent_affiche,
           ARRAY[o.id] AS ids, o.code AS chemin,
           ARRAY[CASE o.object_type WHEN 'FUNC_LOC' THEN '1' || o.code ELSE '2' || o.sap_key END] AS tri
    FROM clean_data.maintenance_object o
    WHERE o.is_active AND o.parent_id IS NULL AND o.object_type IN ('FUNC_LOC', 'EQUIPMENT')
    UNION ALL
    SELECT c.id, a.niveau + 1, a.id, a.ids || c.id, a.chemin || ' / ' || c.code,
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
)
SELECT a.niveau,
       a.chemin,
       CASE o.object_type
           WHEN 'FUNC_LOC'  THEN 'Poste technique'
           WHEN 'EQUIPMENT' THEN 'Equipement'
           WHEN 'BOM_ITEM'  THEN 'Article (nomenclature)'
           ELSE o.object_type
       END                    AS type_objet,
       o.code,
       COALESCE(o.designation, r.designation) AS designation,
       p.code                 AS code_parent,
       p.object_type          AS type_parent,
       o.sap_key,
       o.type_code,
       o.category             AS categorie,
       r.code                 AS article,
       r.designation          AS designation_article,
       r.type_code            AS type_article,
       o.quantity             AS quantite,
       o.unit                 AS unite,
       o.plant                AS division,
       o.cost_center          AS centre_couts,
       o.work_center          AS poste_travail,
       o.work_center_txt      AS poste_travail_libelle,
       o.resp_work_center     AS poste_responsable,
       o.resp_work_center_txt AS poste_responsable_libelle,
       o.planner_group        AS groupe_planification,
       o.zone,
       o.risk_factor          AS facteur_risque,
       COALESCE(o.cas_ibau, r.cas_ibau) AS cas_ibau,
       o.attributes->>'origin' AS origine_nomenclature,
       o.source
FROM arbre a
JOIN clean_data.maintenance_object o ON o.id = a.id
LEFT JOIN clean_data.maintenance_object p ON p.id = a.parent_affiche
LEFT JOIN clean_data.maintenance_object r ON r.id = o.ref_object_id
ORDER BY a.niveau, a.tri;

-- Declaration de l'export (categorie lue par la page /export/maintenance)
DELETE FROM public.etl_export_queries WHERE table_name = 'v_hierarchie_maintenance';
INSERT INTO public.etl_export_queries
    (table_name, table_schema, display_name, column_list, description, category, is_active, created_at, created_by)
VALUES
    ('v_hierarchie_maintenance', 'clean_data', 'Hiérarchie de maintenance complète',
     'niveau,chemin,type_objet,code,designation,code_parent,type_parent,sap_key,type_code,categorie,article,designation_article,type_article,quantite,unite,division,centre_couts,poste_travail,poste_travail_libelle,poste_responsable,poste_responsable_libelle,groupe_planification,zone,facteur_risque,cas_ibau,origine_nomenclature,source',
     'Arbre IH02 aplati : postes techniques, équipements, nomenclatures et nomenclatures des articles, une ligne par noeud dans l''ordre de l''arbre',
     'Structure Maintenance', TRUE, now(), 'migration_113');
