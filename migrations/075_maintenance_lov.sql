-- ============================================================================
-- 075 : mise sous versionnement des listes de valeurs (LOV) de maintenance
--
-- ATTENTION -- CES TABLES EXISTAIENT DEJA SUR 10.190.100.58 SANS MIGRATION.
-- Elles ont ete creees directement sur le serveur : aucune trace dans git, ni
-- SQL, ni API, ni frontend. Cette migration ne fait que les DECRIRE a
-- l'identique pour qu'une base reconstruite les ait aussi. Sur le serveur
-- actuel elle est un NO-OP complet (tout est en IF NOT EXISTS).
--
-- Structure reprise telle quelle de la base de production :
--   maintenance_lov_type  : une liste (code = listCode cote API, ex 'ZONE')
--   maintenance_lov_value : ses valeurs, eventuellement par site (contract)
--                           contract NULL = valeur valable sur TOUS les sites
--
-- Le site de maintenance est 'SJM' / 'CAST' (cf. sql/operation/*), a ne pas
-- confondre avec 'SJ' / 'CS' de public.etl_site qui sert au module articlePhl.
--
-- Rejouable. Rollback en bas de fichier.
-- ============================================================================
BEGIN;

CREATE TABLE IF NOT EXISTS public.maintenance_lov_type (
    id         SERIAL PRIMARY KEY,
    code       VARCHAR(50)  NOT NULL UNIQUE,   -- listCode : 'FACTEUR_RISQUE', 'ZONE'
    libelle    VARCHAR(200) NOT NULL,
    ordre      INTEGER,
    created_at TIMESTAMP NOT NULL DEFAULT now(),
    updated_at TIMESTAMP NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.maintenance_lov_value (
    id          SERIAL PRIMARY KEY,
    lov_type_id INTEGER NOT NULL
                REFERENCES public.maintenance_lov_type(id) ON DELETE CASCADE,
    code        VARCHAR(20)  NOT NULL,         -- valeur STOCKEE (ex. 'CR1', 'Z-17')
    libelle     VARCHAR(200) NOT NULL,         -- valeur AFFICHEE
    contract    VARCHAR(5),                    -- site, NULL = tous les sites
    ordre       INTEGER,
    actif       BOOLEAN NOT NULL DEFAULT TRUE,
    created_at  TIMESTAMP NOT NULL DEFAULT now(),
    updated_at  TIMESTAMP NOT NULL DEFAULT now(),
    UNIQUE (lov_type_id, code, contract)
);

-- La contrainte UNIQUE ci-dessus ne protege PAS les valeurs tous-sites : deux
-- NULL sont distincts pour un UNIQUE, donc rien n'empeche deux lignes
-- (type, 'CR1', NULL). Meme piege que la matrice site x famille, resolu de la
-- meme facon (cf. migration 066) : un index d'expression sur COALESCE.
CREATE UNIQUE INDEX IF NOT EXISTS uq_mlv_type_code_contract
    ON public.maintenance_lov_value (lov_type_id, code, COALESCE(contract, '*'));

-- Lecture de l'ecran : toutes les valeurs actives d'une liste pour un site.
CREATE INDEX IF NOT EXISTS idx_mlv_type_actif
    ON public.maintenance_lov_value (lov_type_id, actif);

-- Les deux tables du serveur portent un trigger d'horodatage sur une fonction
-- deja presente en base ; on ne le (re)pose que si elle existe, pour ne pas
-- faire echouer la migration sur une base neuve qui ne l'aurait pas.
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_proc WHERE proname = 'update_updated_at_column') THEN
        DROP TRIGGER IF EXISTS trg_maintenance_lov_type_updated_at
            ON public.maintenance_lov_type;
        CREATE TRIGGER trg_maintenance_lov_type_updated_at
            BEFORE UPDATE ON public.maintenance_lov_type
            FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

        DROP TRIGGER IF EXISTS trg_maintenance_lov_value_updated_at
            ON public.maintenance_lov_value;
        CREATE TRIGGER trg_maintenance_lov_value_updated_at
            BEFORE UPDATE ON public.maintenance_lov_value
            FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
    END IF;
END $$;

-- Les deux listes attendues par l'ecran IH02. Seuls les TYPES sont crees :
-- les VALEURS (codes de facteur de risque, codes de zone) sont des donnees
-- metier qui doivent etre fournies par les utilisateurs, pas inventees ici.
-- Tant que maintenance_lov_value est vide, les deux listes de l'ecran
-- s'affichent vides -- c'est normal et c'est ce qu'il reste a faire.
INSERT INTO public.maintenance_lov_type (code, libelle, ordre)
VALUES ('FACTEUR_RISQUE', 'Facteur de risque', 10)
ON CONFLICT (code) DO NOTHING;

INSERT INTO public.maintenance_lov_type (code, libelle, ordre)
VALUES ('ZONE', 'Zone', 20)
ON CONFLICT (code) DO NOTHING;

COMMIT;

-- ============================================================================
-- ROLLBACK (ne supprime QUE les deux types crees ci-dessus, jamais les tables :
-- elles preexistaient a cette migration)
-- ============================================================================
-- BEGIN;
-- DELETE FROM public.maintenance_lov_type WHERE code IN ('FACTEUR_RISQUE','ZONE');
-- DROP INDEX IF EXISTS public.uq_mlv_type_code_contract;
-- DROP INDEX IF EXISTS public.idx_mlv_type_actif;
-- COMMIT;
