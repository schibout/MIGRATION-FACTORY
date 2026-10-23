-- =====================================================================
-- raw_data.sp_delete_equipment_reserve()  —  PURGE SAP (demande explicite)
--
-- Supprime des tables SAP de raw_data les equipements dont une designation
-- (eqkt.eqktx, toutes langues) commence par '*RESERVE', ainsi que leurs
-- sous-equipements (equz.hequi, recursif) :
--   equi, eqkt, equz, jest (statuts, objnr de l'equipement)
--
-- AUCUNE sauvegarde (demande explicite) : seule une extraction SAP
-- (« Synchroniser avec SAP ») recharge ces equipements.
-- Les tables clean_data (maintenance_object, equipment_serial) ne suivent
-- qu'apres rechargement du module maintenance.
--
-- Non compile par compile.sh.
-- Usage        : CALL raw_data.sp_delete_equipment_reserve();
-- Essai a blanc: BEGIN; CALL raw_data.sp_delete_equipment_reserve(); ROLLBACK;
-- =====================================================================
CREATE OR REPLACE PROCEDURE raw_data.sp_delete_equipment_reserve()
LANGUAGE plpgsql
AS $procedure$
DECLARE
    v_n integer;
BEGIN
    CREATE TEMP TABLE _eq_reserve ON COMMIT DROP AS
    WITH RECURSIVE cible AS (
        SELECT DISTINCT k.mandt, k.equnr, ARRAY[k.equnr::text] AS chemin
        FROM raw_data.eqkt k
        WHERE k.eqktx LIKE '*RESERVE%'
        UNION ALL
        SELECT z.mandt, z.equnr, c.chemin || z.equnr::text
        FROM cible c
        JOIN raw_data.equz z ON z.mandt = c.mandt AND z.hequi = c.equnr
        WHERE z.equnr::text <> ALL (c.chemin)
    )
    SELECT DISTINCT c.mandt, c.equnr, e.objnr
    FROM cible c
    LEFT JOIN raw_data.equi e ON e.mandt = c.mandt AND e.equnr = c.equnr;

    SELECT count(*) INTO v_n FROM _eq_reserve;
    RAISE NOTICE 'Equipements *RESERVE (+ sous-equipements) vises : %', v_n;

    DELETE FROM raw_data.jest t USING _eq_reserve p WHERE t.mandt = p.mandt AND t.objnr = p.objnr;
    GET DIAGNOSTICS v_n = ROW_COUNT;
    RAISE NOTICE 'jest : % lignes supprimees', v_n;

    DELETE FROM raw_data.equz t USING _eq_reserve p WHERE t.mandt = p.mandt AND t.equnr = p.equnr;
    GET DIAGNOSTICS v_n = ROW_COUNT;
    RAISE NOTICE 'equz : % lignes supprimees', v_n;

    DELETE FROM raw_data.eqkt t USING _eq_reserve p WHERE t.mandt = p.mandt AND t.equnr = p.equnr;
    GET DIAGNOSTICS v_n = ROW_COUNT;
    RAISE NOTICE 'eqkt : % lignes supprimees', v_n;

    DELETE FROM raw_data.equi t USING _eq_reserve p WHERE t.mandt = p.mandt AND t.equnr = p.equnr;
    GET DIAGNOSTICS v_n = ROW_COUNT;
    RAISE NOTICE 'equi : % lignes supprimees', v_n;
END;
$procedure$;
