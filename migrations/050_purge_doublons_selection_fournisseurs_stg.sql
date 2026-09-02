-- ============================================================================
-- 050 : purge des doublons de raw_data.selection_fournisseurs_stg
-- ----------------------------------------------------------------------------
-- INCIDENT du 2026-09-02 :
--   duplicate key value violates unique constraint "pk_ifs_fournisseurs"
--   DETAIL: Key (numero_compte_fournisseur)=(0000045036) already exists.
--
-- Cause : le fichier metier a ete importe une SECONDE fois dans le staging
-- sans purge prealable -> les lignes se sont EMPILEES.
--   3557 lignes = 1716 (ancien fichier) + 1841 (nouveau fichier)
--   1716 fournisseurs presents deux fois, 125 nouveaux presents une fois
--   (verifie par l'ordre physique ctid : lignes 1-1716 = lot 1, 1717-3557 = lot 2)
-- Les deux versions d'un meme fournisseur different (l'une porte l'adresse,
-- l'autre le telephone) : ce ne sont pas des copies exactes.
--
-- Bonne nouvelle : AUCUN fournisseur n'a deux numero_compte_ifs differents
-- entre les deux lots -> clean_data.ifs_fournisseur_id_map est intacte, aucun
-- identifiant IFS n'a ete mal attribue.
--
-- Deux correctifs, complementaires :
--   * CE SCRIPT nettoie les donnees (une ligne par fournisseur) ;
--   * sql/supplier/01_alimenter_ifs_fournisseurs.sql dedoublonne desormais sa
--     source (DISTINCT ON) : l'ETL ne plantera plus sur ce motif, meme si le
--     staging est a nouveau empile.
-- La regle de selection est LA MEME dans les deux : on garde la ligne la plus
-- renseignee, puis la plus recemment inseree. Le contenu charge est donc
-- identique que ce script soit joue ou non -- il evite juste de garder un
-- ancien fichier dans le staging.
--
-- A L'AVENIR : vider le staging avant chaque import du fichier metier
--   TRUNCATE TABLE raw_data.selection_fournisseurs_stg;
-- (aucun code applicatif n'alimente cette table : l'import est manuel.)
--
-- OPERATION DESTRUCTIVE : une sauvegarde horodatee est faite avant.
-- ============================================================================

BEGIN;

-- --- 1. Sauvegarde ----------------------------------------------------------
DROP TABLE IF EXISTS raw_data.selection_fournisseurs_stg_bak_20260902;
CREATE TABLE raw_data.selection_fournisseurs_stg_bak_20260902 AS
SELECT * FROM raw_data.selection_fournisseurs_stg;

COMMENT ON TABLE raw_data.selection_fournisseurs_stg_bak_20260902 IS
'Sauvegarde du staging fournisseurs AVANT purge des doublons du double import (migration 050, 2026-09-02). Supprimable une fois le chargement supplier valide.';

-- --- 2. Purge ---------------------------------------------------------------
-- On conserve, pour chaque numero SAP, la ligne la plus renseignee puis la plus
-- recemment inseree : exactement la ligne que le script 01 aurait retenue.
DELETE FROM raw_data.selection_fournisseurs_stg t
WHERE t.ctid NOT IN (
    SELECT DISTINCT ON (LPAD(TRIM(stg.numero_compte_sap), 10, '0')) stg.ctid
      FROM raw_data.selection_fournisseurs_stg stg
     ORDER BY LPAD(TRIM(stg.numero_compte_sap), 10, '0'),
              (SELECT COUNT(*)
                 FROM jsonb_each_text(to_jsonb(stg)) j
                WHERE NULLIF(TRIM(j.value), '') IS NOT NULL) DESC,
              stg.ctid DESC
);

-- --- 3. Controle : doit renvoyer 1841 / 1841 --------------------------------
SELECT COUNT(*) AS lignes,
       COUNT(DISTINCT LPAD(TRIM(numero_compte_sap), 10, '0')) AS fournisseurs
FROM raw_data.selection_fournisseurs_stg;

COMMIT;

-- =====================================================
-- ROLLBACK
-- =====================================================
-- BEGIN;
-- TRUNCATE TABLE raw_data.selection_fournisseurs_stg;
-- INSERT INTO raw_data.selection_fournisseurs_stg
-- SELECT * FROM raw_data.selection_fournisseurs_stg_bak_20260902;
-- COMMIT;
