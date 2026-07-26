-- Script de test pour vérifier les champs disponibles dans clean_data.v_article
-- À exécuter pour diagnostiquer l'erreur

-- Test 1: Vérifier si la vue existe
SELECT 
    schemaname,
    viewname,
    definition
FROM pg_views 
WHERE schemaname = 'clean_data' 
AND viewname = 'v_article';

-- Test 2: Vérifier la structure de la vue si elle existe
SELECT 
    column_name,
    data_type,
    is_nullable
FROM information_schema.columns 
WHERE table_schema = 'clean_data' 
AND table_name = 'v_article'
ORDER BY ordinal_position;

-- Test 3: Tester un SELECT simple sur la vue
SELECT 
    numero_article,
    designation_article,
    type_article,
    unite_mesure
FROM clean_data.v_article 
LIMIT 5;

-- Test 4: Vérifier les tables sources
SELECT 
    table_name,
    column_name,
    data_type
FROM information_schema.columns 
WHERE table_schema = 'raw_data' 
AND table_name = 'mara'
AND column_name IN ('matnr', 'maktx', 'mtart', 'msehi')
ORDER BY ordinal_position;
