
-- =====================================================================
-- Valeurs par defaut ETL absentes de la base
--
-- Genere par sql/config/generer_valeurs_defaut_manquantes.py
-- Chaque INSERT est en ON CONFLICT DO NOTHING : le script est rejouable
-- et ne remplace jamais une valeur ajustee depuis l'ecran
-- /configuration/valeurs-defaut.
-- =====================================================================

BEGIN;

-- --- module inventory (12 ligne(s)) -----------------------------------------
-- 12 de ces lignes ne sont appelees par aucun get_default_value du depot :
-- elles ne changent rien au chargement, elles rendent la constante visible et modifiable dans l'ecran.
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('inventory', 'clean_data.ifs_article_maitre', 'actif_achat', 'STANDARD', 'CONSTANTE', 'NON', 'Source : alimenter_ifs_article_phl.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('inventory', 'clean_data.ifs_article_maitre', 'actif_commercial', 'STANDARD', 'CONSTANTE', 'NON', 'Source : alimenter_ifs_article_phl.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('inventory', 'clean_data.ifs_article_maitre', 'actif_dans_centre', 'STANDARD', 'CONSTANTE', 'NON', 'Source : alimenter_ifs_article_phl.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('inventory', 'clean_data.ifs_article_maitre', 'actif_evaluation', 'STANDARD', 'CONSTANTE', 'NON', 'Source : alimenter_ifs_article_phl.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('inventory', 'clean_data.ifs_article_maitre', 'avec_stock', 'STANDARD', 'CONSTANTE', 'NON', 'Source : alimenter_ifs_article_phl.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('inventory', 'clean_data.ifs_article_maitre', 'langue', 'STANDARD', 'CONSTANTE', 'FR', 'Source : alimenter_ifs_article_phl.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('inventory', 'clean_data.ifs_article_maitre', 'nombre_centres_actifs', 'STANDARD', 'CONSTANTE', '0', 'Source : alimenter_ifs_article_phl.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('inventory', 'clean_data.ifs_article_maitre', 'nombre_magasins', 'STANDARD', 'CONSTANTE', '0', 'Source : alimenter_ifs_article_phl.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('inventory', 'clean_data.ifs_article_maitre', 'stock_total_bloque', 'STANDARD', 'CONSTANTE', '0', 'Source : alimenter_ifs_article_phl.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('inventory', 'clean_data.ifs_article_maitre', 'stock_total_controle', 'STANDARD', 'CONSTANTE', '0', 'Source : alimenter_ifs_article_phl.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('inventory', 'clean_data.ifs_article_maitre', 'stock_total_libre', 'STANDARD', 'CONSTANTE', '0', 'Source : alimenter_ifs_article_phl.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('inventory', 'clean_data.ifs_article_maitre', 'valeur_stock_magasins_total', 'STANDARD', 'CONSTANTE', '0', 'Source : alimenter_ifs_article_phl.sql', 'migration_032')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;

-- Controle : doit afficher 0 ligne manquante.
DO $$
DECLARE v_manquantes integer;
BEGIN
    SELECT count(*) INTO v_manquantes FROM (VALUES
        ('clean_data.ifs_article_maitre', 'actif_achat', 'STANDARD'),
        ('clean_data.ifs_article_maitre', 'actif_commercial', 'STANDARD'),
        ('clean_data.ifs_article_maitre', 'actif_dans_centre', 'STANDARD'),
        ('clean_data.ifs_article_maitre', 'actif_evaluation', 'STANDARD'),
        ('clean_data.ifs_article_maitre', 'avec_stock', 'STANDARD'),
        ('clean_data.ifs_article_maitre', 'langue', 'STANDARD'),
        ('clean_data.ifs_article_maitre', 'nombre_centres_actifs', 'STANDARD'),
        ('clean_data.ifs_article_maitre', 'nombre_magasins', 'STANDARD'),
        ('clean_data.ifs_article_maitre', 'stock_total_bloque', 'STANDARD'),
        ('clean_data.ifs_article_maitre', 'stock_total_controle', 'STANDARD'),
        ('clean_data.ifs_article_maitre', 'stock_total_libre', 'STANDARD'),
        ('clean_data.ifs_article_maitre', 'valeur_stock_magasins_total', 'STANDARD')
    ) AS attendu(table_cible, colonne, variante)
    WHERE NOT EXISTS (
        SELECT 1 FROM public.etl_default_values d
        WHERE d.table_cible = attendu.table_cible
          AND d.colonne = attendu.colonne
          AND COALESCE(d.variante, 'STANDARD') = attendu.variante);
    IF v_manquantes > 0 THEN
        RAISE EXCEPTION 'Il reste % valeur(s) par defaut absente(s)', v_manquantes;
    END IF;
    RAISE NOTICE 'Valeurs par defaut : les % lignes attendues sont presentes', 12;
END $$;

COMMIT;
