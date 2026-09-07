-- =====================================================================
-- clean_data.backfill_etats_status_report_fk()
-- ---------------------------------------------------------------------
-- Re-matérialise raw_data.sharepoint_etats_avancement.status_report_fk,
-- le GUID qui relie chaque état d'avancement à ses listes filles
-- (statut_jalons / statut_cfv / statut_couts via raw_data->>'Status_x0020_Report').
--
-- CONTEXTE : la migration 011 faisait ce backfill UNE fois. Or l'import
-- des états (TRUNCATE + ré-insert) remet la colonne à NULL et l'upsert ne
-- la renseigne pas -> l'écran "État d'avancement" affiche alors
-- "Aucun jalon / Aucune commission / Aucun coût" pour TOUS les projets.
--
-- => Cette fonction est IDEMPOTENTE : à rejouer après chaque import des
--    états + listes filles (idéalement appelée en fin d'import).
--
-- Résolution du FK : jointure (site_id, title) parent <-> enfants, car les
-- enfants portent le title du parent + le bon Status_x0020_Report.
--
-- Retourne : le nombre d'états dont le FK a été (re)renseigné.
-- =====================================================================
CREATE OR REPLACE FUNCTION clean_data.backfill_etats_status_report_fk()
RETURNS integer
LANGUAGE plpgsql
AS $function$
DECLARE
    v_maj INTEGER := 0;
BEGIN
    WITH fk_resolved AS (
        SELECT site_id, title, raw_data->>'Status_x0020_Report' AS fk
        FROM raw_data.sharepoint_statut_jalons
        WHERE raw_data->>'Status_x0020_Report' IS NOT NULL AND title IS NOT NULL
        UNION
        SELECT site_id, title, raw_data->>'Status_x0020_Report' AS fk
        FROM raw_data.sharepoint_statut_couts
        WHERE raw_data->>'Status_x0020_Report' IS NOT NULL AND title IS NOT NULL
    ),
    fk_dedup AS (
        SELECT DISTINCT ON (site_id, title) site_id, title, fk
        FROM fk_resolved
        ORDER BY site_id, title, fk
    )
    UPDATE raw_data.sharepoint_etats_avancement ea
    SET status_report_fk = fk_dedup.fk
    FROM fk_dedup
    WHERE ea.site_id = fk_dedup.site_id
      AND ea.title   = fk_dedup.title
      AND ea.status_report_fk IS DISTINCT FROM fk_dedup.fk;

    GET DIAGNOSTICS v_maj = ROW_COUNT;
    RAISE NOTICE 'status_report_fk (re)renseigné pour % états', v_maj;
    RETURN v_maj;
END;
$function$;

COMMENT ON FUNCTION clean_data.backfill_etats_status_report_fk() IS
'Re-matérialise etats_avancement.status_report_fk (lien parent->listes filles). Idempotente, à rejouer après chaque import des états d''avancement.';

-- Exécution immédiate (répare l'existant) :
-- SELECT clean_data.backfill_etats_status_report_fk();
