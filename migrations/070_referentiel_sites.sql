-- ============================================================================
-- 070 : referentiel des sites (contracts) de la matrice Site x Famille
--
-- Troisieme table de reference de Configuration > Parametres de la matrice,
-- aux cotes de etl_part_family (067) et etl_matrix_target_table (067).
--
-- POURQUOI : l'axe des sites de l'ecran etait deduit du RESULTAT de l'ETL
-- (SELECT DISTINCT contract FROM clean_data.inventory_part). Seule la passe
-- Castel ayant ete chargee, la base ne contenait que des lignes 'CS' : la
-- colonne 'SJ' disparaissait de la grille, emportant avec elle 36 regles deja
-- saisies pour Saint-Jean -- invisibles et non modifiables, alors qu'elles
-- restaient appliquees par public.get_default_value_ctx() au chargement
-- suivant. Un ecran de PARAMETRAGE s'utilise avant le chargement : ses axes ne
-- peuvent pas dependre de ce qui est deja charge.
--
-- Ces sites ne sont lus par AUCUNE procedure ETL (le site vient de
-- etl_target_tables.module_params cote chargement) : ils ne pilotent que ce
-- que l'ecran propose.
--
-- NEUTRE A L'INSTALLATION : une table VIDE fait retomber l'API sur les sites
-- deduits des donnees puis sur le repli code en dur ('SJ', 'CS'). L'ecran
-- reste donc utilisable si la migration n'est pas jouee.
--
-- Rollback en bas de fichier.
-- ============================================================================

BEGIN;

CREATE TABLE IF NOT EXISTS public.etl_site (
    id          SERIAL PRIMARY KEY,
    code        VARCHAR(50)  NOT NULL,   -- valeur stockee dans .contract (SJ, CS)
    libelle     VARCHAR(120),            -- nom du site affiche sous le code
    description TEXT,                    -- explication longue (infobulle)
    ordre       INTEGER NOT NULL DEFAULT 100,
    is_active   BOOLEAN NOT NULL DEFAULT TRUE,
    created_at  TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at  TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    created_by  VARCHAR(50),
    updated_by  VARCHAR(50)
);

CREATE UNIQUE INDEX IF NOT EXISTS uq_etl_site_code
    ON public.etl_site (code);

COMMENT ON TABLE public.etl_site IS
'Sites (contracts) proposes en groupes de colonnes de la matrice Site x Famille. L''API affiche l''union de cette table et des sites reellement presents (charges dans clean_data, livres dans le fichier PHL, ou deja utilises par une regle) : un site present mais non declare reste visible, et signale comme tel.';
COMMENT ON COLUMN public.etl_site.code IS
'Code du site, tel que stocke dans etl_default_value_matrix.contract et etl_part_type_matrix.contract. Pas de cle etrangere entre les deux : une regle peut porter sur un site non declare. Corollaire : renommer un code ne se propage pas aux regles, l''API refuse donc de le modifier tant que des regles l''utilisent.';
COMMENT ON COLUMN public.etl_site.ordre IS
'Ordre d''affichage des groupes de colonnes de la grille. A egalite, tri par code.';

-- ---------------------------------------------------------------------------
-- Seed : les deux sites du projet, ceux que l'API codait en dur (SITES_REPLI).
-- ON CONFLICT DO NOTHING : rejouer la migration n'ecrase pas un libelle edite
-- depuis l'ecran.
-- ---------------------------------------------------------------------------
INSERT INTO public.etl_site (code, libelle, description, ordre, created_by, updated_by)
VALUES ('SJ', 'Saint-Jean', 'Site de Saint-Jean. Source articles : raw_data.phl_article (migration 068). Premiere passe de la chaine articles PHL : elle vide les tables cibles avant de les remplir.', 10, 'migration_070', 'migration_070')
ON CONFLICT (code) DO NOTHING;

INSERT INTO public.etl_site (code, libelle, description, ordre, created_by, updated_by)
VALUES ('CS', 'Castel', 'Site de Castel. Source articles : raw_data.phl_article_cs (migration 068). Passe en append : elle n''efface rien.', 20, 'migration_070', 'migration_070')
ON CONFLICT (code) DO NOTHING;

COMMIT;

-- ============================================================================
-- ROLLBACK
-- ============================================================================
-- BEGIN;
-- DROP TABLE IF EXISTS public.etl_site;
-- COMMIT;
