-- =====================================================
-- 041 - Vider les colonnes libelle qui ont une jumelle _db
--
-- Pour CHAQUE table de base du schema clean_data possedant un couple
--   <colonne>  (libelle traduit)  +  <colonne>_db  (code IFS)
-- la colonne libelle est videe ; seule la colonne _db reste renseignee.
-- Exemple : activity.exclude_from_integrations      -> vide
--           activity.exclude_from_integrations_db   -> inchangee
--
-- Regle de remplissage :
--   - colonne NULLABLE -> NULL
--   - colonne NOT NULL -> '' (chaine vide), le NULL etant interdit.
--     23 colonnes concernees, toutes de type character varying :
--     customer_agreement (7), project_margin_matrix (6), project_base (4),
--     pm_action_planning (2), pm_action, pm_action_resource,
--     inventory_part_in_stock, routing_head.
--
-- Perimetre mesure le 2026-09-01 : 460 colonnes sur 65 tables
-- (437 nullables + 23 NOT NULL). Les VUES sont exclues
-- (table_type = 'BASE TABLE') : elles se recalculent d'elles-memes.
--
-- Ne touche QUE les donnees deja chargees. Pour que les prochains
-- chargements ETL n'alimentent plus ces colonnes, il faut aussi la
-- modification des procedures (faite pour sql/customerFile/).
--
-- Idempotent : une colonne deja vide n'est pas reecrite.
-- =====================================================

DO $$
DECLARE
    r            RECORD;
    v_sql        TEXT;
    v_lignes     BIGINT;
    v_total      BIGINT  := 0;
    v_colonnes   INTEGER := 0;
    v_tables     INTEGER := 0;
    v_table_prec TEXT    := '';
BEGIN
    FOR r IN
        SELECT c.table_name,
               c.column_name,
               c.is_nullable
        FROM information_schema.columns c
        JOIN information_schema.columns d
          ON  d.table_schema = c.table_schema
          AND d.table_name   = c.table_name
          AND d.column_name  = c.column_name || '_db'
        JOIN information_schema.tables t
          ON  t.table_schema = c.table_schema
          AND t.table_name   = c.table_name
          AND t.table_type   = 'BASE TABLE'
        WHERE c.table_schema = 'clean_data'
        ORDER BY c.table_name, c.column_name
    LOOP
        IF r.table_name <> v_table_prec THEN
            v_tables     := v_tables + 1;
            v_table_prec := r.table_name;
        END IF;

        IF r.is_nullable = 'YES' THEN
            v_sql := format(
                'UPDATE clean_data.%I SET %I = NULL WHERE %I IS NOT NULL',
                r.table_name, r.column_name, r.column_name);
        ELSE
            v_sql := format(
                'UPDATE clean_data.%I SET %I = '''' WHERE %I <> ''''',
                r.table_name, r.column_name, r.column_name);
        END IF;

        EXECUTE v_sql;
        GET DIAGNOSTICS v_lignes = ROW_COUNT;

        v_colonnes := v_colonnes + 1;
        v_total    := v_total + v_lignes;

        IF v_lignes > 0 THEN
            RAISE NOTICE '  clean_data.%.% -> % ligne(s) videe(s)',
                         r.table_name, r.column_name, v_lignes;
        END IF;
    END LOOP;

    RAISE NOTICE '--------------------------------------------------';
    RAISE NOTICE 'TERMINE : % colonne(s) traitee(s) sur % table(s), % ligne(s) mise(s) a jour',
                 v_colonnes, v_tables, v_total;
END $$;

-- =====================================================
-- CONTROLE : ne doit signaler aucune colonne restante.
-- =====================================================
DO $$
DECLARE
    r       RECORD;
    v_reste BIGINT;
    v_ko    INTEGER := 0;
BEGIN
    FOR r IN
        SELECT c.table_name, c.column_name
        FROM information_schema.columns c
        JOIN information_schema.columns d
          ON  d.table_schema = c.table_schema
          AND d.table_name   = c.table_name
          AND d.column_name  = c.column_name || '_db'
        JOIN information_schema.tables t
          ON  t.table_schema = c.table_schema
          AND t.table_name   = c.table_name
          AND t.table_type   = 'BASE TABLE'
        WHERE c.table_schema = 'clean_data'
        ORDER BY 1, 2
    LOOP
        EXECUTE format(
            'SELECT count(*) FROM clean_data.%I WHERE %I IS NOT NULL AND %I <> ''''',
            r.table_name, r.column_name, r.column_name) INTO v_reste;
        IF v_reste > 0 THEN
            v_ko := v_ko + 1;
            RAISE WARNING 'RESTE clean_data.%.% : % ligne(s)', r.table_name, r.column_name, v_reste;
        END IF;
    END LOOP;

    IF v_ko = 0 THEN
        RAISE NOTICE 'CONTROLE OK : aucune colonne libelle jumelee ne reste renseignee';
    ELSE
        RAISE EXCEPTION 'CONTROLE KO : % colonne(s) encore renseignee(s)', v_ko;
    END IF;
END $$;
