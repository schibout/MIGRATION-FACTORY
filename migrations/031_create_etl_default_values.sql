-- Migration 031 : table des valeurs par défaut ETL paramétrables
-- Pattern calqué sur la transcodification. Seed généré depuis
-- sql/supplier/inventaire_colonnes_valeurs_defaut.csv (voir Task 2).

CREATE TABLE IF NOT EXISTS public.etl_default_values (
    id            SERIAL PRIMARY KEY,
    module        VARCHAR(50)  NOT NULL,
    table_cible   VARCHAR(100) NOT NULL,
    colonne       VARCHAR(100) NOT NULL,
    variante      VARCHAR(30)  NOT NULL DEFAULT 'STANDARD',
    type_valeur   VARCHAR(20)  NOT NULL CHECK (type_valeur IN ('CONSTANTE','NULL')),
    valeur        TEXT,
    description   TEXT,
    is_active     BOOLEAN NOT NULL DEFAULT TRUE,
    created_at    TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at    TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    created_by    VARCHAR(50),
    updated_by    VARCHAR(50),
    CONSTRAINT uq_etl_default_values UNIQUE (table_cible, colonne, variante)
);

CREATE INDEX IF NOT EXISTS idx_edv_module ON public.etl_default_values(module);
CREATE INDEX IF NOT EXISTS idx_edv_table  ON public.etl_default_values(table_cible);

COMMENT ON TABLE public.etl_default_values IS
'Valeurs par défaut paramétrables injectées par les fonctions ETL via public.get_default_value(). Éditées depuis l''écran Configuration > Valeurs par défaut.';

-- Clé logique : constante intégrée dans une expression (03_alimenter_supplier_info_our_id.sql)
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.supplier_info_our_id', 'our_id_prefix', 'STANDARD', 'CONSTANTE', 'TRIMET',
        'Préfixe de OUR_ID (concaténé : <prefixe>-<numero_compte_fournisseur>)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;

-- === SEED GÉNÉRÉ (Task 2) : coller ci-dessous le contenu de seed_supplier.sql ===
