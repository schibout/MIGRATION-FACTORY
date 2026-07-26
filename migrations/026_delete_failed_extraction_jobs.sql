-- 026_delete_failed_extraction_jobs.sql
-- Supprime les jobs d'extraction en échec (status = 'failed').
--
-- Notes :
--  * Comparaison insensible à la casse : la table contient des statuts en
--    casse mixte (FAILED / failed).
--  * extraction_details n'a PAS de FK cascade vers extraction_history :
--    on purge d'abord les lignes de détail liées pour éviter les orphelins.
--  * Transaction : tout ou rien.

BEGIN;

-- 1) Détails liés aux jobs en échec
DELETE FROM public.extraction_details d
USING public.extraction_history h
WHERE d.job_id = h.job_id
  AND lower(h.status) = 'failed';

-- 2) Jobs en échec eux-mêmes
DELETE FROM public.extraction_history
WHERE lower(status) = 'failed';

COMMIT;
