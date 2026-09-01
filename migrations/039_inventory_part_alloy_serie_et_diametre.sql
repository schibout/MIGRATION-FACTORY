-- Migration 039 : clean_data.inventory_part -- elargissement c_alloy_serie_code
--                 et passage de c_diameter en numeric(4,2)
--
-- POURQUOI :
--
-- 1) c_alloy_serie_code etait alimente par SUBSTRING("ALLIAGE", 1, 4), ce qui produisait
--    la nuance tronquee (6056, 5754, 3103...) au lieu de la serie d'alliage. La source PHL
--    porte une colonne dediee "SERIE ALL" (1000.0 .. 8000.0), reprise desormais TELLE QUELLE
--    par clean_data.alimenter_inventory_part_phl(). Les 6 caracteres de '6000.0' ne tiennent
--    pas dans le VARCHAR(4) d'origine -> passage en VARCHAR(10).
--    Verifie sur raw_data.v_phl_article_retenu : "SERIE ALL" correspond toujours au premier
--    chiffre de "ALLIAGE" (668 lignes renseignees, 77 NULL la ou "ALLIAGE" est vide).
--
-- 2) c_diameter etait declare numeric(4,0) : les diametres decimaux etaient ARRONDIS a
--    l'insertion (9.5 -> 10, 12.2 -> 12, 15.2 -> 15...), soit 621 des 745 lignes source.
--    Passage en numeric(4,2) ; les valeurs vont de 0 a 30 avec une seule decimale, elles
--    tiennent donc largement dans la nouvelle precision.
--
-- Les autres colonnes dimensionnelles (c_epaisseur_brut, c_longueur_brut, c_largeur_brut,
-- c_commercial_weight) restent en numeric(4,0) : aucune valeur source n'a de decimale et
-- le maximum (3670) tient sur 4 chiffres.
--
-- ATTENTION : la valeur deja chargee de c_diameter est arrondie de maniere irreversible.
-- Un rechargement du module articlePhl est necessaire apres cette migration pour recuperer
-- les decimales (le bloc UPSERT compare c_diameter et c_alloy_serie_code : les lignes
-- concernees seront bien reecrites).

BEGIN;

ALTER TABLE clean_data.inventory_part
    ALTER COLUMN c_alloy_serie_code TYPE VARCHAR(10);

ALTER TABLE clean_data.inventory_part
    ALTER COLUMN c_diameter TYPE numeric(4,2);

COMMIT;
