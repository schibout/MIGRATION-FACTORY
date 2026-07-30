-- =====================================================================
-- 028 — Unicite du code dans clean_data.maintenance_object
--
-- Contexte : l'ecran IH02 bascule sur la table unique et le code d'un objet
-- devient modifiable depuis l'interface. Jusqu'ici l'unicite etait verifiee
-- par un SELECT en Python juste avant l'UPDATE : deux renommages simultanes
-- pouvaient creer un doublon. La garantie passe au niveau base.
--
-- `id` reste la cle primaire ; cet index est une contrainte metier, pas une
-- cle. Quatre choix a connaitre :
--
--   * (object_type, parent_id, code) et non parent_code : donne exactement la
--     meme garantie -- « code unique parmi les freres » -- sans denormaliser,
--     et reste juste automatiquement quand un parent est renomme.
--
--   * NULLS NOT DISTINCT (PostgreSQL 15+) : les racines ET tous les articles
--     ont parent_id IS NULL. Sans cette clause, PostgreSQL considere deux NULL
--     comme distincts et ces lignes echapperaient completement a l'unicite.
--
--   * object_type <> 'BOM_ITEM' : un meme article se repete LEGITIMEMENT dans
--     une nomenclature a des positions (posnr) differentes -- constate sur les
--     donnees SAP : 199 cas dans les nomenclatures de postes (jusqu'a 3 fois)
--     et 17 480 dans les nomenclatures matiere (jusqu'a 12 fois). Inclure
--     BOM_ITEM rendrait l'index impossible a creer.
--
--   * WHERE is_active : un objet supprime (soft delete de l'UI) ne doit pas
--     bloquer la reutilisation de son code.
--
-- Idempotente. A jouer AVANT la bascule de l'ecran.
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1. Pre-requis : lever les doublons de code entre freres
--
-- 6 paires « code lisible + jumeau a tplnr corrompu (?01...) » existent dans
-- l'extraction SAP : le meme poste technique present deux fois, une fois avec
-- son tplnr lisible, une fois avec un tplnr interne dont l'encodage a ete
-- perdu, les deux portant le meme strno (= code) sous le meme parent.
--
-- Les jumeaux ?01... sont des coquilles vides (0 enfant, 0 nomenclature,
-- 0 equipement -- verifie) : on les desactive. Operation REVERSIBLE
-- (is_active = false, aucune ligne supprimee).
-- ---------------------------------------------------------------------
UPDATE clean_data.maintenance_object
SET is_active  = false,
    updated_at = NOW(),
    attributes = attributes || jsonb_build_object(
        'desactive_motif', 'doublon de code entre freres (jumeau tplnr corrompu) — migration 028')
WHERE object_type = 'FUNC_LOC'
  AND is_active
  AND sap_key IN (
      '?0100000000000000050',
      '?0100000000000000051',
      '?0100000000000000116',
      '?0100000000000000117',
      '?0100000000000000287',
      '?0100000000000000507'
  );

-- ---------------------------------------------------------------------
-- 2. Garde-fou : refuser de creer l'index s'il reste des doublons.
-- Sans ce bloc, la creation echouerait avec une erreur d'index peu parlante ;
-- ici on liste explicitement ce qui coince.
-- ---------------------------------------------------------------------
DO $$
DECLARE
    v_doublons TEXT;
BEGIN
    SELECT string_agg(
               FORMAT('%s / parent_id=%s / code=%s (%s lignes)',
                      object_type, COALESCE(parent_id::text, 'racine'), code, n),
               E'\n  ')
    INTO v_doublons
    FROM (
        SELECT object_type, parent_id, code, COUNT(*) AS n
        FROM clean_data.maintenance_object
        WHERE is_active AND object_type <> 'BOM_ITEM'
        GROUP BY object_type, parent_id, code
        HAVING COUNT(*) > 1
    ) d;

    IF v_doublons IS NOT NULL THEN
        RAISE EXCEPTION
            'Doublons de code restants — index non cree. A arbitrer :%s%s',
            E'\n  ', v_doublons;
    END IF;
END;
$$;

-- ---------------------------------------------------------------------
-- 3. L'index
-- ---------------------------------------------------------------------
CREATE UNIQUE INDEX IF NOT EXISTS uq_mo_code_sibling
ON clean_data.maintenance_object (object_type, parent_id, code)
NULLS NOT DISTINCT
WHERE is_active AND object_type <> 'BOM_ITEM';

COMMENT ON INDEX clean_data.uq_mo_code_sibling IS
'Code unique parmi les freres (meme parent_id), par nature d''objet, pour les
 seules lignes actives. Exclut BOM_ITEM : un article se repete legitimement
 dans une nomenclature. NULLS NOT DISTINCT pour couvrir les racines et les
 articles, tous a parent_id NULL.';

-- =====================================================================
-- Verifications
--   -- doit renvoyer 0 ligne :
--   SELECT object_type, parent_id, code, COUNT(*)
--     FROM clean_data.maintenance_object
--     WHERE is_active AND object_type <> 'BOM_ITEM'
--     GROUP BY 1,2,3 HAVING COUNT(*) > 1;
--
--   -- les 6 desactives :
--   SELECT sap_key, code, is_active FROM clean_data.maintenance_object
--     WHERE attributes ? 'desactive_motif';
-- =====================================================================
