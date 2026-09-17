-- =====================================================
-- Aligne column_list de l'export 'equipment_functional' (Structure Maintenance)
-- sur la structure REELLE de la table clean_data.equipment_functional.
-- =====================================================

-- 1. Voir l'ecart : colonnes actuelles dans column_list vs colonnes reelles
WITH
declared AS (
    SELECT UNNEST(string_to_array(replace(column_list, E'\t', ''), ',')) AS col
    FROM public.etl_export_queries
    WHERE table_name = 'equipment_functional'
      AND category   = 'Structure Maintenance'
),
declared_norm AS (
    SELECT LOWER(TRIM(col)) AS col FROM declared WHERE TRIM(col) <> ''
),
actual AS (
    SELECT LOWER(column_name) AS col
    FROM information_schema.columns
    WHERE table_schema = 'clean_data'
      AND table_name   = 'equipment_functional'
)
SELECT
    'EN TROP (declaree mais inexistante)' AS statut,
    d.col AS colonne
FROM declared_norm d
LEFT JOIN actual a USING (col)
WHERE a.col IS NULL
UNION ALL
SELECT
    'MANQUANTE (existe mais pas exportee)' AS statut,
    a.col
FROM actual a
LEFT JOIN declared_norm d USING (col)
WHERE d.col IS NULL
ORDER BY 1, 2;


-- 2. Mettre a jour column_list pour qu'il colle exactement aux colonnes de la table
--    (l'ordre d'ordinal_position est conserve pour rester lisible).
UPDATE public.etl_export_queries
SET column_list = (
        SELECT string_agg(UPPER(column_name), ',' ORDER BY ordinal_position)
        FROM information_schema.columns
        WHERE table_schema = 'clean_data'
          AND table_name   = 'equipment_functional'
    ),
    updated_at = NOW(),
    updated_by = 'system'
WHERE table_name = 'equipment_functional'
  AND category   = 'Structure Maintenance';

-- 3. Verification : nouvelle column_list
SELECT table_name, category, column_list
FROM public.etl_export_queries
WHERE table_name = 'equipment_functional'
  AND category   = 'Structure Maintenance';
