-- =====================================================================
-- clean_data.v_fl_nomenclature  (recree en VUE SIMPLE)
-- Compatibilite descendante : memes colonnes que l'ancienne vue
-- materialisee, mais lues depuis la table unique maintenance_object.
--
-- Avantages :
--   - plus de REFRESH MATERIALIZED VIEW apres chaque edition de BOM ;
--   - toujours a jour (vue simple).
--
-- Consommateurs a verifier :  grep -r v_fl_nomenclature backend/ sql/
--   - backend/api/ih02_hierarchy.py  (route /bom/<tplnr>, /bom-counts)
--   - sql/maintenance/proc_load_equipment_object_spare.sql
--   - sql/maintenance/proc_load_equipment_spare_structure.sql
--   - public.etl_export_queries (requetes d'export dynamiques)
-- =====================================================================

-- Rejouable quel que soit l'objet en place. L'ancienne version etait une vue
-- MATERIALISEE, l'actuelle une vue simple : DROP MATERIALIZED VIEW IF EXISTS
-- echoue ("is not a materialized view") des lors que l'objet est deja une vue
-- simple -- le script n'etait donc executable qu'une seule fois. On ne detruit
-- plus que la matview historique, et seulement si c'en est une.
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM pg_class c
        JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE n.nspname = 'clean_data'
          AND c.relname = 'v_fl_nomenclature'
          AND c.relkind = 'm'
    ) THEN
        EXECUTE 'DROP MATERIALIZED VIEW clean_data.v_fl_nomenclature CASCADE';
    END IF;
END $$;

-- CREATE OR REPLACE (et non DROP + CREATE) : pas de CASCADE, donc aucun risque
-- d'emporter un futur objet dependant. Impose de conserver la meme liste de
-- colonnes, ce qui est le comportement souhaite pour une vue de compatibilite.
CREATE OR REPLACE VIEW clean_data.v_fl_nomenclature AS
SELECT
    fl.sap_key                          AS tplnr,
    fl.code                             AS tplnr_display,
    fl.designation                      AS fl_designation,
    b.attributes->>'stlnr'              AS stlnr,
    b.attributes->>'stlal'              AS stlal,
    b.attributes->>'stlan'              AS stlan,
    b.attributes->>'base_quantity'      AS base_quantity,
    b.attributes->>'base_unit'          AS base_unit,
    b.attributes->>'posnr'              AS posnr,
    a.sap_key                           AS idnrk,
    a.code                              AS matnr_short,
    b.category                          AS item_category,
    b.quantity::text                    AS quantity,
    b.unit                              AS unit,
    a.type_code                         AS material_type,
    a.designation                       AS designation,
    b.sort_order                        AS sort_order
FROM clean_data.maintenance_object b
JOIN clean_data.maintenance_object fl
    ON fl.id = b.parent_id AND fl.object_type = 'FUNC_LOC'
JOIN clean_data.maintenance_object a
    ON a.id = b.ref_object_id AND a.object_type = 'ARTICLE'
-- Pas de filtre sur attributes->>'stlty' : la jointure sur un parent FUNC_LOC
-- exprime deja « nomenclature portee par un poste technique ». Filtrer
-- stlty='T' excluait les lignes issues du TYPE DE CONSTRUCTION IBAU
-- (origin='SUBMT', cf. passe 5c du chargement), qui sont pourtant de vraies
-- pieces de rechange du poste : plus de la moitie des postes techniques n'ont
-- aucune entree dans tpst et ne recevaient donc rien dans l'export IFS.
-- Les BOM matiere de la passe 5b ne rentrent pas ici : leur parent est un
-- ARTICLE, pas un FUNC_LOC.
WHERE b.object_type = 'BOM_ITEM'
  AND b.is_active;

COMMENT ON VIEW clean_data.v_fl_nomenclature IS
'BOM des postes techniques (compat) : vue simple sur maintenance_object
 (BOM_ITEM dont le parent est un FUNC_LOC, quel que soit stlty : voie tpst
 stlty=T ET voie type de construction IBAU origin=SUBMT).
 Memes colonnes que l''ancienne vue materialisee.
 Plus de REFRESH necessaire.';

-- Verifications :
--   SELECT COUNT(*) FROM clean_data.v_fl_nomenclature;
--   SELECT * FROM clean_data.v_fl_nomenclature WHERE tplnr_display = 'T340-E100-1005';
