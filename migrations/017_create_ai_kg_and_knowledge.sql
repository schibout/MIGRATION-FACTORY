-- =====================================================
-- Migration: Assistant IA — Knowledge Graph (relations DDIC) + cards de connaissances
-- Description:
--   1. public.ai_table_relationships (VUE) : graphe des relations inter-tables
--      déduit des clés étrangères du DDIC (sap_table_fields.check_table).
--      Sert à build_dynamic_prompt (sous-graphe des jointures pertinentes).
--      VUE simple (pas matérialisée) : sap_table_fields change rarement et la
--      requête est filtrée par quelques tables -> rapide, et pas de REFRESH à gérer.
--      (Passera en MATERIALIZED quand on y ajoutera les co-occurrences de ai_query_log.)
--   2. public.ai_embeddings.metadata (JSONB) : métadonnées des « knowledge cards »
--      (type, domaine, tables, priorité, keywords) pour le filtrage au retrieval.
--      On réutilise la table ai_embeddings existante avec kind='knowledge'.
-- Date: 2026-06-14
-- Idempotent: CREATE OR REPLACE VIEW + ADD COLUMN IF NOT EXISTS
-- =====================================================

-- ----------------------------------------------------
-- 1. Colonne metadata pour les cards de connaissances
-- ----------------------------------------------------
ALTER TABLE public.ai_embeddings
    ADD COLUMN IF NOT EXISTS metadata JSONB;

-- ----------------------------------------------------
-- 2. Graphe des relations inter-tables (clés étrangères DDIC)
-- ----------------------------------------------------
-- src_table.src_field  ->  dst_table   (check_table = table de contrôle = FK)
-- On exclut T000 (mandant) : présent sur quasiment toutes les tables = bruit.
CREATE OR REPLACE VIEW public.ai_table_relationships AS
SELECT DISTINCT
       lower(trim(f.table_name))  AS src_table,
       lower(trim(f.field_name))  AS src_field,
       lower(trim(f.check_table)) AS dst_table,
       'ddic_fk'                  AS source
FROM public.sap_table_fields f
WHERE f.check_table IS NOT NULL
  AND trim(f.check_table) <> ''
  AND upper(trim(f.check_table)) <> 'T000';

COMMENT ON VIEW public.ai_table_relationships IS
    'Graphe des relations inter-tables SAP (FK = sap_table_fields.check_table). Source du sous-graphe de jointures injecté dans le prompt de l''Assistant IA.';

-- ----------------------------------------------------
-- 3. Droits : le rôle applicatif lit la vue ; readonly_ai par cohérence
-- ----------------------------------------------------
GRANT SELECT ON public.ai_table_relationships TO readonly_ai;

-- ----------------------------------------------------
-- 4. Confirmation
-- ----------------------------------------------------
DO $$
DECLARE v_rel INTEGER;
BEGIN
    SELECT COUNT(*) INTO v_rel FROM public.ai_table_relationships;
    RAISE NOTICE 'Knowledge Graph prêt : % relation(s) FK dans ai_table_relationships.', v_rel;
    RAISE NOTICE 'Colonne ai_embeddings.metadata prête (cards de connaissances).';
    RAISE NOTICE 'Pensez à indexer les cards : python backend/build_ai_index.py --only knowledge';
END $$;
