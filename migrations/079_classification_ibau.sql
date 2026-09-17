-- ============================================================================
-- 079 : Identification automatique des cas d'IBAU
--       (document « Migration des donnees », N. Marquenet, 15/09/2026, §3)
--
-- Regle, pour chaque article IBAU (mara.mtart = 'IBAU') present dans la
-- structure IH02 (clean_data.maintenance_object, noeud ARTICLE actif) :
--   - aucun enfant                              -> ARTICLE          (rouge)
--       a transformer en article classique
--   - des enfants + UNE seule occurrence        -> POSTE_TECHNIQUE  (bleu)
--       a remplacer par un poste technique (objet fonctionnel IFS)
--   - des enfants + PLUSIEURS occurrences       -> CONSERVER        (jaune)
--       vrai IBAU reutilisable : article type IBAU + liste de pieces
--
--   enfant     = ligne BOM_ITEM active sous le noeud ARTICLE de l'IBAU
--   occurrence = ligne BOM_ITEM active qui REFERENCE l'IBAU (ref_object_id)
--              + poste technique actif dont il est le type de construction
--                (raw_data.iflo.submt, seule source lisible : iflot.submt est
--                vide, cf. proc_load_maintenance_object passe 5c)
--
-- La classification est STOCKEE (demande explicite : champ reutilisable),
-- dans les DEUX tables, et recalculee a la demande par
-- clean_data.classifier_ibau_article() (bouton sur l'ecran IH02 et sur la
-- liste fixe des IBAU ; a relancer apres une transformation manuelle ou un
-- rechargement SAP) :
--   - clean_data.maintenance_object : colonne cas_ibau sur les noeuds ARTICLE
--     de type IBAU (les autres restent NULL), details dans attributes
--     (ibau_nb_enfants, ibau_nb_occurrences, ibau_calcule_at) -> l'arbre IH02
--     colore les lignes de nomenclature qui referencent l'IBAU ;
--   - clean_data.ibau_article (liste fixe, decouplee de SAP) : cas_ibau,
--     nb_enfants, nb_occurrences, cas_calcule_at -> listes « a conserver » /
--     « a transformer » par filtre + export. Un IBAU de la liste absent de la
--     structure garde cas_ibau NULL (« hors structure »), pas un faux rouge ;
--     cas_calcule_at est renseigne quand meme : il a ete evalue.
--
-- Survie aux rechargements : la colonne n'est pas touchee par le mode fusion
-- (UPDATE colonne par colonne) ; le mode reset la perd avec le reste ->
-- relancer la fonction. Rejouable. Ordre de grandeur au 17/09 :
-- 1 364 CONSERVER / 3 345 POSTE_TECHNIQUE / 4 169 ARTICLE sur 8 878 IBAU.
-- ============================================================================
BEGIN;

ALTER TABLE clean_data.maintenance_object
    ADD COLUMN IF NOT EXISTS cas_ibau TEXT
        CHECK (cas_ibau IN ('CONSERVER', 'POSTE_TECHNIQUE', 'ARTICLE'));
COMMENT ON COLUMN clean_data.maintenance_object.cas_ibau IS
    'Cas IBAU calcule par clean_data.classifier_ibau_article() (migration 079) : CONSERVER (jaune) / POSTE_TECHNIQUE (bleu) / ARTICLE (rouge) ; NULL hors IBAU';
CREATE INDEX IF NOT EXISTS idx_mo_cas_ibau
    ON clean_data.maintenance_object (cas_ibau) WHERE cas_ibau IS NOT NULL;

ALTER TABLE clean_data.ibau_article
    ADD COLUMN IF NOT EXISTS cas_ibau TEXT
        CHECK (cas_ibau IN ('CONSERVER', 'POSTE_TECHNIQUE', 'ARTICLE')),
    ADD COLUMN IF NOT EXISTS nb_enfants     INTEGER,
    ADD COLUMN IF NOT EXISTS nb_occurrences INTEGER,
    ADD COLUMN IF NOT EXISTS cas_calcule_at TIMESTAMPTZ;
COMMENT ON COLUMN clean_data.ibau_article.cas_ibau IS
    'Cas IBAU calcule (migration 079) : CONSERVER / POSTE_TECHNIQUE / ARTICLE ; NULL = absent de la structure IH02';

CREATE OR REPLACE FUNCTION clean_data.classifier_ibau_article()
RETURNS TABLE (cas TEXT, nb BIGINT)
LANGUAGE plpgsql
AS $$
DECLARE
    v_now TIMESTAMPTZ := clock_timestamp();
BEGIN
    CREATE TEMP TABLE ibau_cls ON COMMIT DROP AS
    WITH ibau AS (
        SELECT a.id, a.sap_key AS matnr
        FROM clean_data.maintenance_object a
        WHERE a.object_type = 'ARTICLE' AND a.is_active AND a.type_code = 'IBAU'
    ),
    enfants AS (
        SELECT b.parent_id AS id, COUNT(*) AS nb
        FROM clean_data.maintenance_object b
        JOIN ibau i ON i.id = b.parent_id
        WHERE b.object_type = 'BOM_ITEM' AND b.is_active
        GROUP BY b.parent_id
    ),
    occ_bom AS (
        SELECT b.ref_object_id AS id, COUNT(*) AS nb
        FROM clean_data.maintenance_object b
        JOIN ibau i ON i.id = b.ref_object_id
        WHERE b.object_type = 'BOM_ITEM' AND b.is_active
        GROUP BY b.ref_object_id
    ),
    occ_submt AS (
        -- iflo porte ~4 lignes par poste (une par langue) : distinct sur tplnr
        SELECT i.id, COUNT(DISTINCT f.tplnr) AS nb
        FROM raw_data.iflo f
        JOIN ibau i ON i.matnr = TRIM(f.submt)
        JOIN clean_data.maintenance_object fl
          ON fl.object_type = 'FUNC_LOC' AND fl.is_active AND fl.sap_key = f.tplnr
        GROUP BY i.id
    )
    SELECT i.id, i.matnr,
           COALESCE(e.nb, 0)::int                        AS nb_enfants,
           (COALESCE(ob.nb, 0) + COALESCE(os.nb, 0))::int AS nb_occurrences,
           CASE WHEN COALESCE(e.nb, 0) = 0 THEN 'ARTICLE'
                WHEN COALESCE(ob.nb, 0) + COALESCE(os.nb, 0) <= 1 THEN 'POSTE_TECHNIQUE'
                ELSE 'CONSERVER' END                     AS cas_ibau
    FROM ibau i
    LEFT JOIN enfants   e  ON e.id  = i.id
    LEFT JOIN occ_bom   ob ON ob.id = i.id
    LEFT JOIN occ_submt os ON os.id = i.id;

    -- 1. Structure : noeuds ARTICLE IBAU
    UPDATE clean_data.maintenance_object m
    SET cas_ibau   = c.cas_ibau,
        attributes = COALESCE(m.attributes, '{}'::jsonb) || jsonb_build_object(
            'ibau_nb_enfants',     c.nb_enfants,
            'ibau_nb_occurrences', c.nb_occurrences,
            'ibau_calcule_at',     v_now)
    FROM ibau_cls c
    WHERE m.id = c.id
      AND (m.cas_ibau IS DISTINCT FROM c.cas_ibau
           OR (m.attributes->>'ibau_nb_enfants')::int IS DISTINCT FROM c.nb_enfants
           OR (m.attributes->>'ibau_nb_occurrences')::int IS DISTINCT FROM c.nb_occurrences);

    -- Un noeud qui n'est plus un IBAU classable (desactive, retype) perd son cas.
    UPDATE clean_data.maintenance_object m
    SET cas_ibau = NULL,
        attributes = m.attributes - ARRAY['ibau_nb_enfants', 'ibau_nb_occurrences', 'ibau_calcule_at']
    WHERE m.cas_ibau IS NOT NULL
      AND NOT EXISTS (SELECT 1 FROM ibau_cls c WHERE c.id = m.id);

    -- 2. Liste fixe : jointure par matnr ; absent de la structure -> NULL
    UPDATE clean_data.ibau_article a
    SET cas_ibau       = c.cas_ibau,
        nb_enfants     = c.nb_enfants,
        nb_occurrences = c.nb_occurrences,
        cas_calcule_at = v_now
    FROM (
        SELECT a2.id, c2.cas_ibau, c2.nb_enfants, c2.nb_occurrences
        FROM clean_data.ibau_article a2
        LEFT JOIN ibau_cls c2 ON c2.matnr = a2.matnr
        WHERE a2.is_active
    ) c
    WHERE a.id = c.id;

    RETURN QUERY
    SELECT c.cas_ibau, COUNT(*)::bigint
    FROM ibau_cls c
    GROUP BY c.cas_ibau
    ORDER BY c.cas_ibau;

    DROP TABLE ibau_cls;
END;
$$;

COMMENT ON FUNCTION clean_data.classifier_ibau_article() IS
    'Recalcule le cas de chaque IBAU (CONSERVER / POSTE_TECHNIQUE / ARTICLE) dans maintenance_object et ibau_article ; renvoie les compteurs par cas';

-- Premier calcul
SELECT * FROM clean_data.classifier_ibau_article();

COMMIT;

-- ============================================================================
-- ROLLBACK
-- ============================================================================
-- BEGIN;
-- DROP FUNCTION IF EXISTS clean_data.classifier_ibau_article();
-- ALTER TABLE clean_data.ibau_article
--     DROP COLUMN IF EXISTS cas_ibau, DROP COLUMN IF EXISTS nb_enfants,
--     DROP COLUMN IF EXISTS nb_occurrences, DROP COLUMN IF EXISTS cas_calcule_at;
-- ALTER TABLE clean_data.maintenance_object DROP COLUMN IF EXISTS cas_ibau;
-- COMMIT;
