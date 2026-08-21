-- 031 — Purge des articles hors perimetre St-Jean (nettoyage a la source)
--
-- Demande : plutot que de filtrer les articles inactifs dans chaque page et
-- chaque procedure, on les supprime en amont dans raw_data. Les ecrans et les
-- chargeurs existants n'ont alors RIEN a modifier : ce qui n'existe plus dans
-- raw_data ne remonte nulle part.
--
-- Perimetre CONSERVE = union de 4 sources (vue raw_data.v_articles_conserves) :
--   1. clean_data.selection_articles_stjn_actifs  -- liste des actifs St-Jean
--   2. matnr references par la structure IH02 (clean_data.maintenance_object)
--      -- sans eux la nomenclature de maintenance s'effondre ; c'est ce qui
--         protege les ~8 450 IBAU rattaches a l'arbre
--   3. raw_data.article_definitif  -- perimetre des exports IFS articles
--      (part_catalog / inventory_part / purchase_part / sales_part / ...).
--      92 de ses articles sont absents de la selection : on les garde pour ne
--      pas amputer un export deja valide.
--   4. raw_data.equi.matnr  -- materiau porte par un equipement
--
-- Tables purgees : master article uniquement (liste blanche c_tables ci-dessous).
-- NON touchees, volontairement :
--   - equi / objk / itob / prps : matnr n'y est qu'un attribut, ce ne sont pas
--     des tables articles ;
--   - ekpo / ekbe / rseg / resb / anek / bseg : historique transactionnel, il
--     alimente les analyses "utilise en achat / reservation"
--     (clean_data.selection_articles_utilises) ;
--   - clean_data.* : ifs_article est une reference importee (pas derivee de
--     mara) et ibau_article est autonome depuis la migration 030.
--
-- ATTENTION : raw_data n'a AUCUNE contrainte de cle etrangere (verifie) - rien
-- ne protege d'une suppression trop large. D'ou : dry-run par defaut, sauvegarde
-- systematique des lignes supprimees dans le schema purge_backup, et procedure
-- de restauration exacte.
--
-- ATTENTION : une re-extraction SAP reecrit raw_data et ANNULE la purge. La
-- procedure est idempotente : la rejouer apres chaque extraction.
--
-- Idempotent : rejouable sans risque.

BEGIN;

-- 1. Table de selection ----------------------------------------------------
-- Creee a la main hors depot ; formalisee ici pour etre reproductible et
-- documentee dans .astro/warehouse.md.
CREATE TABLE IF NOT EXISTS clean_data.selection_articles_stjn_actifs (
    matnr TEXT
);

CREATE INDEX IF NOT EXISTS selection_articles_stjn_actifs_matnr_idx
    ON clean_data.selection_articles_stjn_actifs (matnr);

COMMENT ON TABLE clean_data.selection_articles_stjn_actifs IS
    'Liste des articles actifs du site St-Jean (matnr SAP sur 18 caracteres). '
    'Base du nettoyage du catalogue : tout article absent de cette liste ET non '
    'retenu par les 3 autres sources de raw_data.v_articles_conserves est purge '
    'de raw_data par raw_data.sp_purge_articles_hors_selection().';

-- 2. Perimetre conserve ----------------------------------------------------
CREATE OR REPLACE VIEW raw_data.v_articles_conserves AS
SELECT matnr, string_agg(DISTINCT source, '+' ORDER BY source) AS sources
FROM (
    SELECT matnr, 'SELECTION' AS source
    FROM clean_data.selection_articles_stjn_actifs
    WHERE NULLIF(TRIM(matnr), '') IS NOT NULL

    UNION ALL
    SELECT sap_key, 'IH02'
    FROM clean_data.maintenance_object
    WHERE object_type = 'ARTICLE' AND is_active
      AND NULLIF(TRIM(sap_key), '') IS NOT NULL

    UNION ALL
    SELECT attributes->>'matnr', 'IH02'
    FROM clean_data.maintenance_object
    WHERE object_type = 'EQUIPMENT' AND is_active
      AND NULLIF(TRIM(attributes->>'matnr'), '') IS NOT NULL

    UNION ALL
    -- article_definitif porte le numero sans zeros de tete : on le recadre
    SELECT LPAD(TRIM(article), 18, '0'), 'EXPORT_IFS'
    FROM raw_data.article_definitif
    WHERE NULLIF(TRIM(article), '') IS NOT NULL

    UNION ALL
    SELECT matnr, 'EQUIPEMENT'
    FROM raw_data.equi
    WHERE NULLIF(TRIM(matnr), '') IS NOT NULL
) s
GROUP BY matnr;

COMMENT ON VIEW raw_data.v_articles_conserves IS
    'Perimetre des articles conserves lors de la purge du catalogue : union de la '
    'selection St-Jean, des matnr references par la structure IH02, du perimetre '
    'des exports IFS (article_definitif) et des materiaux d''equipements. '
    'La colonne sources indique pourquoi chaque article est conserve.';

-- 3. Journal des purges ----------------------------------------------------
CREATE SEQUENCE IF NOT EXISTS public.purge_articles_run_seq;

CREATE TABLE IF NOT EXISTS public.purge_articles_log (
    id           BIGSERIAL PRIMARY KEY,
    run_id       BIGINT      NOT NULL,
    run_at       TIMESTAMP   NOT NULL DEFAULT CURRENT_TIMESTAMP,
    dry_run      BOOLEAN     NOT NULL,
    label        TEXT,
    table_name   TEXT        NOT NULL,
    rows_before  BIGINT      NOT NULL,
    rows_deleted BIGINT      NOT NULL,
    backup_table TEXT,                      -- NULL en dry-run
    executed_by  TEXT        NOT NULL DEFAULT CURRENT_USER
);

CREATE INDEX IF NOT EXISTS purge_articles_log_run_idx
    ON public.purge_articles_log (run_id);

COMMENT ON TABLE public.purge_articles_log IS
    'Journal des purges du catalogue articles : une ligne par table et par execution. '
    'backup_table pointe la copie des lignes supprimees dans le schema purge_backup, '
    'rejouable par raw_data.sp_restore_purge_articles(run_id).';

CREATE SCHEMA IF NOT EXISTS purge_backup;
COMMENT ON SCHEMA purge_backup IS
    'Copies des lignes supprimees par raw_data.sp_purge_articles_hors_selection(). '
    'Nommage : r<run_id>_<table>. Ne pas purger sans certitude : c''est le seul '
    'chemin de retour arriere de la purge articles.';

-- 4. Purge -----------------------------------------------------------------
CREATE OR REPLACE PROCEDURE raw_data.sp_purge_articles_hors_selection(
    p_dry_run BOOLEAN DEFAULT TRUE,
    p_label   TEXT    DEFAULT NULL
)
LANGUAGE plpgsql
AS $procedure$
DECLARE
    -- Liste blanche : master article uniquement. Toute table ajoutee ici doit
    -- avoir matnr pour cle (ou partie de cle) ET etre rechargeable depuis SAP.
    c_tables CONSTANT TEXT[] := ARRAY[
        'mara', 'makt', 'marc', 'mard', 'mbew', 'marm', 'mvke', 'mlan',
        'mast', 'eord', 'eina', 'mchb', 'mslb', 'mlgn', 'mlgt', 'mska'
    ];
    v_run_id      BIGINT;
    v_table       TEXT;
    v_backup      TEXT;
    v_before      BIGINT;
    v_deleted     BIGINT;
    v_keep_count  BIGINT;
    v_total_del   BIGINT := 0;
BEGIN
    v_run_id := nextval('public.purge_articles_run_seq');

    -- Le perimetre est materialise une fois : la vue agrege 5 sources, la
    -- reevaluer pour chaque ligne de chaque table serait injouable.
    DROP TABLE IF EXISTS _keep;   -- filet si deux CALL dans la meme transaction
    CREATE TEMP TABLE _keep ON COMMIT DROP AS
        SELECT matnr FROM raw_data.v_articles_conserves;
    CREATE INDEX ON _keep (matnr);
    ANALYZE _keep;

    SELECT count(*) INTO v_keep_count FROM _keep;

    IF v_keep_count = 0 THEN
        RAISE EXCEPTION 'Perimetre de conservation vide : purge refusee '
                        '(selection_articles_stjn_actifs est-elle alimentee ?)';
    END IF;

    RAISE NOTICE 'Purge articles run % (dry_run=%) : % articles conserves',
                 v_run_id, p_dry_run, v_keep_count;

    FOREACH v_table IN ARRAY c_tables LOOP
        -- Une table absente de l'extraction courante n'est pas une erreur.
        IF to_regclass('raw_data.' || v_table) IS NULL THEN
            RAISE NOTICE '  % : table absente, ignoree', v_table;
            CONTINUE;
        END IF;

        EXECUTE format('SELECT count(*) FROM raw_data.%I', v_table) INTO v_before;
        EXECUTE format(
            'SELECT count(*) FROM raw_data.%I x
              WHERE NOT EXISTS (SELECT 1 FROM _keep k WHERE k.matnr = x.matnr)',
            v_table) INTO v_deleted;

        v_backup := NULL;

        IF NOT p_dry_run AND v_deleted > 0 THEN
            v_backup := format('r%s_%s', v_run_id, v_table);
            EXECUTE format(
                'CREATE TABLE purge_backup.%I AS
                 SELECT x.* FROM raw_data.%I x
                  WHERE NOT EXISTS (SELECT 1 FROM _keep k WHERE k.matnr = x.matnr)',
                v_backup, v_table);
            EXECUTE format(
                'DELETE FROM raw_data.%I x
                  WHERE NOT EXISTS (SELECT 1 FROM _keep k WHERE k.matnr = x.matnr)',
                v_table);
        END IF;

        INSERT INTO public.purge_articles_log
            (run_id, dry_run, label, table_name, rows_before, rows_deleted, backup_table)
        VALUES
            (v_run_id, p_dry_run, p_label, v_table, v_before, v_deleted,
             CASE WHEN v_backup IS NULL THEN NULL
                  ELSE 'purge_backup.' || v_backup END);

        v_total_del := v_total_del + v_deleted;
        RAISE NOTICE '  % : % / % lignes %',
                     v_table, v_deleted, v_before,
                     CASE WHEN p_dry_run THEN 'a supprimer (dry-run)' ELSE 'supprimees' END;
    END LOOP;

    RAISE NOTICE 'Purge articles run % terminee : % lignes %',
                 v_run_id, v_total_del,
                 CASE WHEN p_dry_run THEN 'a supprimer (aucune modification)' ELSE 'supprimees' END;
END;
$procedure$;

COMMENT ON PROCEDURE raw_data.sp_purge_articles_hors_selection(BOOLEAN, TEXT) IS
    'Supprime de raw_data les articles hors perimetre (cf. raw_data.v_articles_conserves). '
    'p_dry_run=true (defaut) ne modifie rien et journalise seulement les compteurs. '
    'En mode reel, les lignes supprimees sont copiees dans purge_backup avant DELETE. '
    'A rejouer apres chaque re-extraction SAP.';

-- 5. Retour arriere --------------------------------------------------------
CREATE OR REPLACE PROCEDURE raw_data.sp_restore_purge_articles(p_run_id BIGINT)
LANGUAGE plpgsql
AS $procedure$
DECLARE
    r           RECORD;
    v_restored  BIGINT;
    v_total     BIGINT := 0;
BEGIN
    FOR r IN
        SELECT table_name, backup_table
        FROM public.purge_articles_log
        WHERE run_id = p_run_id AND NOT dry_run AND backup_table IS NOT NULL
        ORDER BY id
    LOOP
        IF to_regclass(r.backup_table) IS NULL THEN
            RAISE WARNING '  % : sauvegarde % introuvable, ignoree',
                          r.table_name, r.backup_table;
            CONTINUE;
        END IF;

        EXECUTE format('INSERT INTO raw_data.%I SELECT * FROM %s',
                       r.table_name, r.backup_table);
        GET DIAGNOSTICS v_restored = ROW_COUNT;
        v_total := v_total + v_restored;
        RAISE NOTICE '  % : % lignes restaurees', r.table_name, v_restored;
    END LOOP;

    IF v_total = 0 THEN
        RAISE WARNING 'Aucune ligne restauree pour le run % '
                      '(run inexistant, dry-run, ou sauvegardes supprimees)', p_run_id;
    ELSE
        RAISE NOTICE 'Run % restaure : % lignes au total', p_run_id, v_total;
    END IF;
END;
$procedure$;

COMMENT ON PROCEDURE raw_data.sp_restore_purge_articles(BIGINT) IS
    'Restaure dans raw_data les lignes supprimees par une execution de '
    'sp_purge_articles_hors_selection (schema purge_backup). Ne supprime pas les '
    'sauvegardes : la restauration est rejouable, mais dupliquerait les lignes.';

COMMIT;
