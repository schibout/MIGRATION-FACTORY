-- 030 — Referentiel IBAU editable, decouple de SAP
--
-- Demande (mail maintenance) : une liste avec SEULEMENT les IBAU, qui n'est
-- PAS mise a jour depuis SAP mais reste modifiable par les equipes (ajout,
-- suppression, modification).
--
-- Principe : une table clean_data.ibau_article, alimentee UNE FOIS depuis
-- raw_data.mara (type IBAU, actifs, presents dans la structure IH02 — meme
-- perimetre que la page /maintenance/articles/ibau, ~8 450 articles), puis
-- autonome : ni le rechargement SAP ni les snapshots maintenance n'y touchent.
--
-- Idempotent : rejouable sans risque. Le seed n'insere que les matnr absents
-- (WHERE NOT EXISTS) et ne fait JAMAIS d'UPDATE -> les modifications des
-- equipes sont preservees a chaque rejeu.

BEGIN;

-- 1. Table ----------------------------------------------------------------
CREATE TABLE IF NOT EXISTS clean_data.ibau_article (
    id          BIGSERIAL PRIMARY KEY,
    matnr       TEXT,                          -- cle SAP d'origine (18 car., NULL si ajout manuel)
    code        TEXT NOT NULL,                 -- identifiant affiche (matnr sans zeros, ou saisie)
    description TEXT,
    matkl       TEXT,                          -- groupe d'articles SAP
    matkl_label TEXT,
    meins       TEXT,                          -- unite de base
    bismt       TEXT,                          -- ancien numero d'article
    commentaire TEXT,                          -- champ libre equipe
    source      TEXT NOT NULL DEFAULT 'MANUAL' CHECK (source IN ('SAP', 'MANUAL')),
    is_active   BOOLEAN NOT NULL DEFAULT TRUE, -- soft delete
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by  TEXT,
    updated_at  TIMESTAMPTZ,
    updated_by  TEXT
);

COMMENT ON TABLE clean_data.ibau_article IS
    'Referentiel IBAU decouple de SAP : seed unique depuis mara (migration 030), '
    'puis vie propre via l''ecran /maintenance/ibau (ajout/modif/suppression equipe). '
    'Ne JAMAIS re-synchroniser depuis raw_data.';

-- Unicite du code parmi les lignes actives (les lignes supprimees liberent le code)
CREATE UNIQUE INDEX IF NOT EXISTS uq_ibau_article_code_active
    ON clean_data.ibau_article (UPPER(code)) WHERE is_active;

-- Une seule ligne active par matnr SAP (le seed s'appuie dessus)
CREATE UNIQUE INDEX IF NOT EXISTS uq_ibau_article_matnr
    ON clean_data.ibau_article (matnr) WHERE matnr IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_ibau_article_matkl ON clean_data.ibau_article (matkl);

-- 2. Seed unique depuis SAP ------------------------------------------------
-- Perimetre = IBAU actifs presents dans la structure IH02 (noeud ARTICLE ou
-- materiau d'un EQUIPMENT), identique a _st_jean_scope_clause de
-- backend/api/maintenance_articles.py.
INSERT INTO clean_data.ibau_article
    (matnr, code, description, matkl, matkl_label, meins, bismt, source, created_by)
SELECT
    m.matnr,
    LTRIM(m.matnr, '0'),
    COALESCE(k_fr.maktx, k_any.maktx),
    NULLIF(TRIM(m.matkl), ''),
    g.wgbez,
    NULLIF(TRIM(m.meins), ''),
    NULLIF(TRIM(m.bismt), ''),
    'SAP',
    'MIGRATION_030'
FROM raw_data.mara m
LEFT JOIN raw_data.makt k_fr
    ON k_fr.mandt = m.mandt AND k_fr.matnr = m.matnr AND k_fr.spras = 'F'
LEFT JOIN LATERAL (
    SELECT maktx FROM raw_data.makt
    WHERE mandt = m.mandt AND matnr = m.matnr
    ORDER BY (CASE WHEN spras='F' THEN 0 WHEN spras='E' THEN 1 ELSE 2 END)
    LIMIT 1
) k_any ON TRUE
LEFT JOIN LATERAL (
    SELECT wgbez FROM raw_data.t023t
    WHERE mandt = m.mandt AND matkl = m.matkl
    ORDER BY (CASE WHEN spras='F' THEN 0 WHEN spras='E' THEN 1 ELSE 2 END)
    LIMIT 1
) g ON TRUE
WHERE TRIM(m.mtart) = 'IBAU'
  AND TRIM(COALESCE(m.lvorm, '')) <> 'X'
  AND (
      EXISTS (SELECT 1 FROM clean_data.maintenance_object mo
              WHERE mo.object_type = 'ARTICLE' AND mo.is_active AND mo.sap_key = m.matnr)
      OR EXISTS (SELECT 1 FROM clean_data.maintenance_object mo
                 WHERE mo.object_type = 'EQUIPMENT' AND mo.is_active
                   AND mo.attributes->>'matnr' = m.matnr)
  )
  AND NOT EXISTS (
      SELECT 1 FROM clean_data.ibau_article i WHERE i.matnr = m.matnr
  )
ON CONFLICT DO NOTHING;  -- collision de code (LTRIM) improbable mais non bloquante

COMMIT;
