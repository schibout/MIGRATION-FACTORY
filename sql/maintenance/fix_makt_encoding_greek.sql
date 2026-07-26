-- =====================================================================
-- CORRECTIF ENCODAGE : descriptions d'articles grecques (raw_data.makt)
-- =====================================================================
-- Probleme : les fichiers SAP de l'usine grecque sont en ISO-8859-7, mais
-- l'import (backend/services/file_processors.py) tombe sur le fallback
-- 'latin-1' qui accepte n'importe quel octet -> mojibake.
-- Ex. stocke : "(AL) ÕÐÅÑÄÏÌÇ ËÅÊÁÍÇÓ"  ->  reel : "(AL) ΥΠΕΡΔΟΜΗ ΛΕΚΑΝΗΣ"
--
-- La colonne makt.maktx est MIXTE : ~34 600 lignes grecques corrompues +
-- ~8 200 lignes francaises CORRECTES (à, °, Ë, MÂLE, DÉPORTÉ ...).
-- => On ne reconvertit QUE les lignes detectees grecques, le francais
--    reste intact.
--
-- Detection d'une ligne grecque (mojibake) :
--   (1) presence d'un caractere latin-1 NON francais (signature grecque) :
--       Á Ã Ä Å Æ Ì Í Ð Ñ Ó Õ Ö Ø Ú Ý Þ ß  + minuscules
--   OU (2) >= 3 caracteres non-ASCII consecutifs (mots grecs en
--          homoglyphes latins, ex. "ÊÉÂÙÔÉÏ" = "ΚΙΒΩΤΙΟ").
--
-- Conversion : convert_from(convert_to(maktx,'LATIN1'),'ISO_8859_7')
--
-- IDEMPOTENT + SUR :
--   - boucle ligne par ligne avec EXCEPTION : une ligne deja en grec reel
--     (UTF-8) fait echouer convert_to(...,'LATIN1') -> elle est ignoree ;
--     idem pour un eventuel octet indefini en ISO-8859-7 (ex. ® = 0xAE).
--
-- A executer sur la base (psql / pgAdmin). Lecture seule cote MCP : ce
-- script doit etre lance manuellement sur le serveur.
-- =====================================================================

BEGIN;

-- 1) Sauvegarde de securite (a conserver jusqu'a validation, puis DROP)
DROP TABLE IF EXISTS raw_data.makt_backup_encoding;
CREATE TABLE raw_data.makt_backup_encoding AS
SELECT * FROM raw_data.makt;

-- 2) Reconversion ciblee des seules lignes grecques
DO $$
DECLARE
    r          RECORD;
    converted  text;
    nb_ok      integer := 0;
    nb_skip    integer := 0;
BEGIN
    FOR r IN
        SELECT ctid, maktx
        FROM raw_data.makt
        WHERE maktx IS NOT NULL
          AND (
                maktx ~ '[ÁÃÄÅÆÌÍÐÑÓÕÖØÚÝÞßáãäåæìíðñóõöøúýþ]'
             OR maktx ~ '[^[:ascii:]]{3,}'
              )
    LOOP
        BEGIN
            converted := convert_from(convert_to(r.maktx, 'LATIN1'), 'ISO_8859_7');
            IF converted IS DISTINCT FROM r.maktx THEN
                UPDATE raw_data.makt SET maktx = converted WHERE ctid = r.ctid;
                nb_ok := nb_ok + 1;
            END IF;
        EXCEPTION WHEN others THEN
            -- ligne non convertible (deja en grec reel, ou octet indefini) : on ignore
            nb_skip := nb_skip + 1;
        END;
    END LOOP;

    RAISE NOTICE 'Lignes corrigees : %, lignes ignorees : %', nb_ok, nb_skip;
END $$;

-- 3) Verifications (a inspecter AVANT de COMMIT)
--    a) plus de signature mojibake grecque attendue :
-- SELECT COUNT(*) FROM raw_data.makt
--   WHERE maktx ~ '[ÁÃÄÅÆÌÍÐÑÓÕÖØÚÝÞßáãäåæìíðñóõöøúýþ]';
--    b) exemple concret :
-- SELECT matnr, maktx FROM raw_data.makt WHERE matnr = '000000000000403980';
--       -> doit afficher "(AL) ΥΠΕΡΔΟΜΗ ΛΕΚΑΝΗΣ Σ. Α-Β"
--    c) le francais est intact :
-- SELECT maktx FROM raw_data.makt WHERE maktx ILIKE '%DÉPORTÉ%' OR maktx ILIKE '%MÂLE%' LIMIT 5;

COMMIT;

-- =====================================================================
-- ROLLBACK manuel si besoin (restaure depuis la sauvegarde) :
--   UPDATE raw_data.makt m
--   SET maktx = b.maktx
--   FROM raw_data.makt_backup_encoding b
--   WHERE b.mandt = m.mandt AND b.matnr = m.matnr AND b.spras = m.spras
--     AND m.maktx IS DISTINCT FROM b.maktx;
--
-- Nettoyage apres validation :
--   DROP TABLE raw_data.makt_backup_encoding;
-- =====================================================================
