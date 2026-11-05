-- Vide les tables propres a l'ecran Finance > Articles (/finance/articles) :
--   clean_data.article_perimetre            : perimetre, recalculable (bouton Calculer)
--   clean_data.article_perimetre_validation : fichiers valides importes, NON recalculable,
--                                             donc copiee avant suppression
-- Non touchees : clean_data.article_sap (partagee avec Donnees SAP > Articles et le
-- navigateur d'equipements) et la date d'arrete (public.etl_default_values).
--
-- p_appliquer : FALSE (defaut) = affiche les volumes sans rien modifier ;
--               TRUE = copie les fichiers valides dans backup_article_perimetre.validation_<horodatage>,
--               puis vide les deux tables, le tout dans une seule transaction.
--
-- Restauration : INSERT INTO clean_data.article_perimetre_validation
--                SELECT * FROM backup_article_perimetre.validation_<horodatage>;
--                puis bouton Calculer de l'ecran.
-- A lancer quand aucun calcul ni import de l'ecran n'est en cours.
--
-- Usage : CALL clean_data.sp_vider_article_perimetre();      -- volumes
--         CALL clean_data.sp_vider_article_perimetre(TRUE);  -- vidage
CREATE OR REPLACE PROCEDURE clean_data.sp_vider_article_perimetre(
    p_appliquer BOOLEAN DEFAULT FALSE
)
 LANGUAGE plpgsql
AS $procedure$
DECLARE
    v_sauvegarde CONSTANT TEXT := 'validation_' || to_char(clock_timestamp(), 'YYYYMMDD_HH24MISS');
    v_perimetre  BIGINT;
    v_validation BIGINT;
BEGIN
    IF p_appliquer THEN
        -- Bloque les ecritures, pas la lecture par l'ecran : rien ne se glisse entre copie et DELETE.
        LOCK TABLE clean_data.article_perimetre_validation, clean_data.article_perimetre IN EXCLUSIVE MODE;
    END IF;

    SELECT count(*) INTO v_perimetre FROM clean_data.article_perimetre;
    SELECT count(*) INTO v_validation FROM clean_data.article_perimetre_validation;

    IF NOT p_appliquer THEN
        RAISE NOTICE 'A supprimer : article_perimetre % lignes, article_perimetre_validation % lignes',
            v_perimetre, v_validation;
        RETURN;
    END IF;

    CREATE SCHEMA IF NOT EXISTS backup_article_perimetre;
    EXECUTE format('CREATE TABLE backup_article_perimetre.%I AS TABLE clean_data.article_perimetre_validation',
                   v_sauvegarde);

    -- DELETE et non TRUNCATE : l'ecran lit ces tables (cf. alimenter_article_perimetre)
    DELETE FROM clean_data.article_perimetre;
    DELETE FROM clean_data.article_perimetre_validation;

    RAISE NOTICE 'Supprimees : article_perimetre % lignes, article_perimetre_validation % lignes (copie : backup_article_perimetre.%)',
        v_perimetre, v_validation, v_sauvegarde;
END;
$procedure$
;
