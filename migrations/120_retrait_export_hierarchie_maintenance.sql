-- 120 : retire l'export « Hierarchie de maintenance complete » (v_hierarchie_maintenance,
-- migrations 113/114) de la categorie « Structure Maintenance » (demande explicite 2026-10-19).
-- La vue clean_data.v_hierarchie_maintenance reste en base, seule la declaration d'export disparait.

DELETE FROM public.etl_export_queries
WHERE table_name = 'v_hierarchie_maintenance' AND category = 'Structure Maintenance';
