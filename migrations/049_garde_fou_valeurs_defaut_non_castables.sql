-- ============================================================================
-- 049 : empecher qu'une valeur par defaut non castable casse un chargement ETL
-- ----------------------------------------------------------------------------
-- INCIDENT du 2026-09-02 18:52 :
--   Erreur dans alimenter_supplier_info_general:
--   invalid input syntax for type numeric: ""
--
-- Cause : public.etl_default_values ligne id=17
--   clean_data.supplier_info_general / picture_id / STANDARD
--   type_valeur='CONSTANTE', valeur='', is_active=true
-- et l'appelant caste : get_default_value(...,'picture_id')::NUMERIC(20,0)
-- (sql/supplier/02_alimenter_supplier_info_general.sql:85).
-- get_default_value renvoie du TEXT et PostgreSQL n'a aucun cast ''->numeric.
--
-- C'est EXACTEMENT ce que la migration 042 avait corrige... le 2026-09-01.
-- Les deux lignes concernees ont ete REACTIVEES depuis l'ecran
-- /configuration/valeurs-defaut (updated_by = un UUID utilisateur,
-- le 2026-09-01 pour customer_info.picture_id et le 2026-09-02 12:20 pour
-- supplier_info_general.picture_id). Une desactivation ponctuelle ne tient
-- donc pas : il faut que la base refuse le cas.
--
-- Cette migration fait deux choses :
--   1. neutralise les 2 lignes en type_valeur='NULL' (plutot que is_active=false) :
--      la ligne reste visible ET activable a l'ecran, mais get_default_value
--      renvoie NULL, qui se caste vers n'importe quel type. Reactivable sans
--      danger, contrairement au correctif 042.
--   2. installe un garde-fou : un trigger refuse desormais toute ligne active
--      dont la valeur ne peut pas etre castee vers le type reel de la colonne
--      cible, avec un message qui dit quoi faire.
--
-- Perimetre mesure sur la base le 2026-09-02 : 2 lignes non castables
-- (les deux picture_id), aucune autre sur numeric / date / timestamp / boolean.
-- ============================================================================

BEGIN;

-- --- 1. Neutraliser les lignes fautives -------------------------------------
UPDATE public.etl_default_values v
SET type_valeur = 'NULL',
    valeur      = NULL,
    description = COALESCE(NULLIF(description, ''), 'Aucune image : la colonne reste vide')
                  || ' [migration_049 : valeur vide impossible a caster en '
                  || c.data_type || ', passee en type NULL]',
    updated_at  = CURRENT_TIMESTAMP,
    updated_by  = 'migration_049'
FROM information_schema.columns c
WHERE c.table_schema = split_part(v.table_cible, '.', 1)
  AND c.table_name   = split_part(v.table_cible, '.', 2)
  AND c.column_name  = v.colonne
  AND c.data_type NOT IN ('character varying', 'text', 'character')
  AND v.type_valeur <> 'NULL'
  AND COALESCE(v.valeur, '') = '';

-- --- 2. Le garde-fou --------------------------------------------------------
CREATE OR REPLACE FUNCTION public.trg_etl_default_values_valider()
RETURNS trigger
LANGUAGE plpgsql
AS $function$
DECLARE
    v_udt       TEXT;
    v_data_type TEXT;
BEGIN
    -- Type 'NULL' ou ligne inactive : rien a caster, on laisse passer.
    IF NEW.type_valeur = 'NULL' OR NEW.is_active IS DISTINCT FROM TRUE THEN
        RETURN NEW;
    END IF;

    -- Type reel de la colonne cible. Table ou colonne inconnue (module pas
    -- encore charge, faute de frappe assumee) : on ne bloque pas.
    SELECT c.udt_name, c.data_type
    INTO v_udt, v_data_type
    FROM information_schema.columns c
    WHERE c.table_schema = split_part(NEW.table_cible, '.', 1)
      AND c.table_name   = split_part(NEW.table_cible, '.', 2)
      AND c.column_name  = NEW.colonne;

    IF NOT FOUND THEN
        RETURN NEW;
    END IF;

    -- Colonnes textuelles : tout passe, get_default_value renvoie deja du TEXT.
    IF v_data_type IN ('character varying', 'text', 'character') THEN
        RETURN NEW;
    END IF;

    -- Valeur vide sur colonne non textuelle : le cas de l'incident.
    IF COALESCE(NEW.valeur, '') = '' THEN
        RAISE EXCEPTION
            'Valeur vide interdite sur %.% (colonne de type %) : get_default_value renvoie du TEXT et PostgreSQL ne sait pas caster '''' vers %. Choisissez le type de valeur "NULL" pour laisser la colonne vide.',
            NEW.table_cible, NEW.colonne, v_data_type, v_data_type
            USING ERRCODE = '22P02';
    END IF;

    -- Valeur renseignee : on tente reellement le cast.
    BEGIN
        EXECUTE format('SELECT %L::%s', NEW.valeur, v_udt);
    EXCEPTION
        WHEN OTHERS THEN
            RAISE EXCEPTION
                'Valeur % incompatible avec %.% (colonne de type %) : le chargement ETL echouerait avec "%". Corrigez la valeur ou choisissez le type "NULL".',
                quote_literal(NEW.valeur), NEW.table_cible, NEW.colonne, v_data_type, SQLERRM
                USING ERRCODE = '22P02';
    END;

    RETURN NEW;
END;
$function$;

COMMENT ON FUNCTION public.trg_etl_default_values_valider() IS
'Refuse une valeur par defaut active qui ne peut pas etre castee vers le type reel de la colonne cible (incident du 2026-09-02 : picture_id = '''' sur une colonne numeric).';

DROP TRIGGER IF EXISTS trg_etl_default_values_valider ON public.etl_default_values;
CREATE TRIGGER trg_etl_default_values_valider
    BEFORE INSERT OR UPDATE ON public.etl_default_values
    FOR EACH ROW EXECUTE FUNCTION public.trg_etl_default_values_valider();

COMMIT;

-- --- Controle : doit renvoyer 0 ligne ---------------------------------------
-- SELECT e.table_cible, e.colonne, e.valeur, c.data_type
-- FROM public.etl_default_values e
-- JOIN information_schema.columns c
--   ON  c.table_schema = split_part(e.table_cible,'.',1)
--   AND c.table_name   = split_part(e.table_cible,'.',2)
--   AND c.column_name  = e.colonne
-- WHERE e.is_active AND e.type_valeur <> 'NULL'
--   AND COALESCE(e.valeur,'') = ''
--   AND c.data_type NOT IN ('character varying','text','character');

-- =====================================================
-- ROLLBACK
-- =====================================================
-- BEGIN;
-- DROP TRIGGER IF EXISTS trg_etl_default_values_valider ON public.etl_default_values;
-- DROP FUNCTION IF EXISTS public.trg_etl_default_values_valider();
-- -- les lignes picture_id restent en type NULL (les remettre en CONSTANTE ''
-- -- reproduirait l'incident).
-- COMMIT;
