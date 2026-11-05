-- ============================================================================
-- Ajustements de fn_upsert_payment_way_per_identity
-- Comparaison du 2026-11-05 avec les donnees validees en UAT par le metier.
-- Remplace la fonction du script d'origine : a jouer APRES lui (cf. compile.sh).
-- Ne fait que recompiler : le rechargement des tables reste a lancer.
-- Les colonnes libelle d'un couple <col>/<col>_db restent regies par la regle du depot.
--
--   way_id selon le mode de paiement SAP : R -> VI, P et PQ -> P, sinon SEPA (etl_default_values, variantes MODE_x)
--   clean_data.fn_way_id_fournisseur : regle partagee avec payment_address (script 14b)
-- ============================================================================
-- Ancienne valeur STANDARD : 1. Seul cet etat initial est modifie : une valeur saisie
-- ensuite a l'ecran n'est pas ecrasee au rejeu.
UPDATE public.etl_default_values
   SET valeur = 'SEPA', updated_at = CURRENT_TIMESTAMP, updated_by = 'ajustement_uat_20261105'
 WHERE table_cible = 'clean_data.payment_way_per_identity' AND colonne = 'way_id'
   AND variante = 'STANDARD' AND valeur = '1';

INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, is_active, created_by)
SELECT d.module, d.table_cible, d.colonne, v.variante, 'CONSTANTE', v.valeur,
       'Mode de paiement fournisseur SAP ' || v.mode || ' (variante calculee par fn_way_id_fournisseur)', TRUE, 'ajustement_uat_20261105'
  FROM public.etl_default_values d
 CROSS JOIN (VALUES ('MODE_R', 'R', 'VI'), ('MODE_P', 'P', 'P'), ('MODE_PQ', 'PQ', 'P')) v(variante, mode, valeur)
 WHERE d.table_cible = 'clean_data.payment_way_per_identity' AND d.colonne = 'way_id' AND d.variante = 'STANDARD'
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;

CREATE OR REPLACE FUNCTION clean_data.fn_way_id_fournisseur(p_mode TEXT)
 RETURNS TEXT
 LANGUAGE sql
 STABLE
AS $function$
    SELECT COALESCE(
        public.get_default_value('clean_data.payment_way_per_identity', 'way_id', 'MODE_' || TRIM(p_mode)),
        public.get_default_value('clean_data.payment_way_per_identity', 'way_id'));
$function$;

CREATE OR REPLACE FUNCTION clean_data.fn_upsert_payment_way_per_identity()
 RETURNS integer
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_processed_count INTEGER := 0;
    v_start_time TIMESTAMP;
BEGIN
    v_start_time := CURRENT_TIMESTAMP;
    
    RAISE NOTICE '=== DÉBUT ALIMENTATION PAYMENT_WAY_PER_IDENTITY ===';
    RAISE NOTICE 'Heure de début: %', v_start_time;
    
    -- TRUNCATE de la table pour repartir à zéro
    TRUNCATE TABLE clean_data.PAYMENT_WAY_PER_IDENTITY;
    RAISE NOTICE 'Table PAYMENT_WAY_PER_IDENTITY vidée';
    
    -- Insertion basée sur la table ifs_fournisseurs
    INSERT INTO clean_data.PAYMENT_WAY_PER_IDENTITY (
        company,
        identity,
        party_type,
        party_type_db,
        way_id,
        default_payment_way,
        created_timestamp,
        updated_timestamp,
        created_by,
        updated_by,
        is_deleted
    )
    SELECT 
        COALESCE(f.company, 'TRIMET') as company,
        -- IDENTITY = numéro IFS du fichier de sélection (voir script 02).
        f.numero_compte_ifs as identity,
        public.get_default_value('clean_data.payment_way_per_identity', 'party_type') as party_type,
        public.get_default_value('clean_data.payment_way_per_identity', 'party_type_db') as party_type_db,
        clean_data.fn_way_id_fournisseur(f.mode_paiement) as way_id,
        public.get_default_value('clean_data.payment_way_per_identity', 'default_payment_way') as default_payment_way,
        CURRENT_TIMESTAMP as created_timestamp,
        CURRENT_TIMESTAMP as updated_timestamp,
        'System' as created_by,
        'System' as updated_by,
        FALSE as is_deleted
    FROM clean_data.ifs_fournisseurs f
    WHERE f.numero_compte_ifs IS NOT NULL;
    
    GET DIAGNOSTICS v_processed_count = ROW_COUNT;
    
    RAISE NOTICE '';
    RAISE NOTICE '=== ALIMENTATION PAYMENT_WAY_PER_IDENTITY TERMINÉE ===';
    RAISE NOTICE 'Durée: % secondes', EXTRACT(EPOCH FROM (CURRENT_TIMESTAMP - v_start_time));
    RAISE NOTICE 'Total enregistrements insérés: %', v_processed_count;
    
    -- Statistiques détaillées
    RAISE NOTICE '';
    RAISE NOTICE '=== STATISTIQUES DÉTAILLÉES ===';
    RAISE NOTICE 'Total fournisseurs dans ifs_fournisseurs: %', 
        (SELECT COUNT(*) FROM clean_data.ifs_fournisseurs);
    RAISE NOTICE 'Enregistrements dans PAYMENT_WAY_PER_IDENTITY: %', 
        (SELECT COUNT(*) FROM clean_data.PAYMENT_WAY_PER_IDENTITY);
    RAISE NOTICE '';
    RAISE NOTICE '=== RÉPARTITION PAR TYPE DE PAIEMENT ===';
    RAISE NOTICE 'Moyens de paiement: %', 
        (SELECT STRING_AGG(way_id || '=' || count_records::text, ', ' ORDER BY way_id) 
         FROM (SELECT way_id, COUNT(*) as count_records 
               FROM clean_data.PAYMENT_WAY_PER_IDENTITY 
               GROUP BY way_id) way_stats);
    RAISE NOTICE '';
    RAISE NOTICE '=== RÉPARTITION PAR SOCIÉTÉ ===';
    RAISE NOTICE 'Par société: %', 
        (SELECT STRING_AGG(company || '=' || count_records::text, ', ') 
         FROM (SELECT company, COUNT(*) as count_records 
               FROM clean_data.PAYMENT_WAY_PER_IDENTITY 
               GROUP BY company) company_stats);
    
    RETURN v_processed_count;
    
EXCEPTION
    WHEN OTHERS THEN
        RAISE EXCEPTION 'Erreur lors de l''alimentation payment way per identity: %', SQLERRM;
END;
$function$
;
