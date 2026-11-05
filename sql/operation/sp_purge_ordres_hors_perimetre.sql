-- Purge dans raw_data des ORDRES hors perimetre de reprise et de leurs operations
-- (demande explicite 2026-11-05, regles : sql/operation/repriseOperation.md).
--
-- Tables purgees : AUFK, AFKO, AFIH, CAUFV, AFVC, AFVV, AFRU, et JEST pour les seuls
-- objets d'ordre (OR...) et d'operation (OV...). Non touchees : RESB (selection des
-- articles utilises), statuts d'equipements et d'avis, couts (PMCO, COSP), OBJK.
--
-- p_mode : 'date'   = garde les ordres crees depuis le 01/01/2026 (AUFK.ERDAT)
--          'regles' = garde seulement clean_data.v_sap_ordre_repris (4 regles IW39)
-- p_appliquer : FALSE (defaut) = affiche les volumes sans rien modifier ;
--               TRUE = copie les lignes dans backup_hors_perimetre.<table>, puis les
--               supprime, le tout dans une seule transaction.
--
-- Restauration : INSERT INTO raw_data.<t> SELECT * FROM backup_hors_perimetre.<t>.
-- A lancer uniquement quand aucune extraction SAP n'est en cours. Une extraction en
-- strategie complete (AFKO notamment) recharge les lignes purgees de sa table.
--
-- Usage : CALL clean_data.sp_purge_ordres_hors_perimetre('date');        -- volumes
--         CALL clean_data.sp_purge_ordres_hors_perimetre('date', TRUE);  -- purge
CREATE OR REPLACE PROCEDURE clean_data.sp_purge_ordres_hors_perimetre(
    p_mode      TEXT    DEFAULT 'date',
    p_appliquer BOOLEAN DEFAULT FALSE
)
 LANGUAGE plpgsql
AS $procedure$
DECLARE
    c_hors_ordre CONSTANT TEXT := 'NOT EXISTS (SELECT 1 FROM tmp_purge_garde p WHERE p.mandt = t.mandt AND p.aufnr = t.aufnr)';
    c_hors_gamme CONSTANT TEXT := 'NOT EXISTS (SELECT 1 FROM tmp_purge_aufpl p WHERE p.mandt = t.mandt AND p.aufpl = t.aufpl)';
    v_cible      RECORD;
    v_lignes     BIGINT;
    v_total      BIGINT;
    v_dernier    TEXT;
BEGIN
    IF p_mode IS NULL OR p_mode NOT IN ('date', 'regles') THEN
        RAISE EXCEPTION 'sp_purge_ordres_hors_perimetre : p_mode doit valoir date ou regles (recu %)', p_mode;
    END IF;

    SET LOCAL statement_timeout = 0;
    SET LOCAL jit = off;
    SET LOCAL work_mem = '256MB';

    -- Une table vide (extraction en cours) ferait tout supprimer.
    IF NOT EXISTS (SELECT 1 FROM raw_data.aufk) OR NOT EXISTS (SELECT 1 FROM raw_data.afko)
       OR NOT EXISTS (SELECT 1 FROM raw_data.afih) OR NOT EXISTS (SELECT 1 FROM raw_data.afvc) THEN
        RAISE EXCEPTION 'AUFK, AFKO, AFIH ou AFVC vide (extraction en cours ?) : purge annulee';
    END IF;

    CREATE TEMP TABLE tmp_purge_garde ON COMMIT DROP AS
        SELECT a.mandt, a.aufnr, a.objnr
        FROM raw_data.aufk a
        WHERE p_mode = 'date' AND a.erdat >= '20260101' AND a.erdat ~ '^[0-9]{8}$'
        UNION
        SELECT a.mandt, a.aufnr, a.objnr
        FROM raw_data.aufk a
        JOIN clean_data.v_sap_ordre_repris r USING (mandt, aufnr)
        WHERE p_mode = 'regles';
    CREATE INDEX ON tmp_purge_garde (mandt, aufnr);
    ANALYZE tmp_purge_garde;

    -- Tables d'une meme extraction : un ecart de plus de 30 jours les dit desynchronisees.
    SELECT max(a.erdat) INTO v_dernier
    FROM tmp_purge_garde g
    JOIN raw_data.aufk a USING (mandt, aufnr)
    JOIN raw_data.afko k USING (mandt, aufnr);
    IF v_dernier IS NULL OR v_dernier < to_char(CURRENT_DATE - 30, 'YYYYMMDD') THEN
        RAISE EXCEPTION 'Dernier ordre garde present dans AFKO cree le % : extractions desynchronisees, purge annulee', v_dernier;
    END IF;

    CREATE TEMP TABLE tmp_purge_aufpl ON COMMIT DROP AS
        SELECT DISTINCT k.mandt, k.aufpl
        FROM raw_data.afko k JOIN tmp_purge_garde g USING (mandt, aufnr);
    CREATE INDEX ON tmp_purge_aufpl (mandt, aufpl);
    ANALYZE tmp_purge_aufpl;

    CREATE TEMP TABLE tmp_purge_objnr ON COMMIT DROP AS
        SELECT mandt, objnr FROM tmp_purge_garde WHERE objnr IS NOT NULL
        UNION SELECT mandt, 'OR' || aufnr FROM tmp_purge_garde
        UNION SELECT v.mandt, v.objnr
              FROM raw_data.afvc v JOIN tmp_purge_aufpl p USING (mandt, aufpl)
              WHERE v.objnr IS NOT NULL;
    CREATE INDEX ON tmp_purge_objnr (mandt, objnr);
    ANALYZE tmp_purge_objnr;

    RAISE NOTICE 'Mode % : % ordres gardes, dernier ordre dans AFKO cree le %',
        p_mode, (SELECT count(*) FROM tmp_purge_garde), v_dernier;

    IF p_appliquer THEN
        -- Sans IF NOT EXISTS sur les tables : une purge deja faite ne s'ecrase pas.
        CREATE SCHEMA IF NOT EXISTS backup_hors_perimetre;
    END IF;

    FOR v_cible IN
        SELECT * FROM (VALUES
            ('aufk',  c_hors_ordre),
            ('afih',  c_hors_ordre),
            ('afko',  c_hors_ordre),
            ('caufv', c_hors_ordre),
            ('afvc',  c_hors_gamme),
            ('afvv',  c_hors_gamme),
            ('afru',  c_hors_gamme || ' AND ' || c_hors_ordre),
            ('jest',  $$(t.objnr LIKE 'OR%' OR t.objnr LIKE 'OV%')
                        AND NOT EXISTS (SELECT 1 FROM tmp_purge_objnr p WHERE p.mandt = t.mandt AND p.objnr = t.objnr)$$)
        ) AS c(nom, condition)
    LOOP
        EXECUTE format('SELECT count(*) FROM raw_data.%I', v_cible.nom) INTO v_total;
        IF p_appliquer THEN
            EXECUTE format('CREATE TABLE backup_hors_perimetre.%I AS SELECT t.* FROM raw_data.%I t WHERE %s',
                           v_cible.nom, v_cible.nom, v_cible.condition);
            EXECUTE format('DELETE FROM raw_data.%I t WHERE %s', v_cible.nom, v_cible.condition);
            GET DIAGNOSTICS v_lignes = ROW_COUNT;
        ELSE
            EXECUTE format('SELECT count(*) FROM raw_data.%I t WHERE %s', v_cible.nom, v_cible.condition)
                INTO v_lignes;
        END IF;
        RAISE NOTICE '% : % lignes % sur %, % restantes',
            v_cible.nom, v_lignes, CASE WHEN p_appliquer THEN 'supprimees' ELSE 'a supprimer' END,
            v_total, v_total - v_lignes;
    END LOOP;

    DROP TABLE tmp_purge_objnr;
    DROP TABLE tmp_purge_aufpl;
    DROP TABLE tmp_purge_garde;
END;
$procedure$
;
