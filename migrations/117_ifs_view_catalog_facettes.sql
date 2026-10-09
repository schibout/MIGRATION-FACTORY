-- Vues IFS : colonnes calculees pour les filtres et etiquettes de l'ecran
-- (Donnees IFS > Vues IFS). Generees : toujours a jour apres un import. Rejouable.
BEGIN;

ALTER TABLE public.ifs_view_catalog
    -- Nature deduite du suffixe IFS du nom de vue (libelles dans api/ifs_dictionary.py)
    ADD COLUMN IF NOT EXISTS nature TEXT GENERATED ALWAYS AS (
        CASE
            WHEN owner NOT LIKE 'IFS%' THEN 'SYSTEME'
            WHEN view_name ~ '_(CFV|CLV|CFT)$' THEN 'CF'
            WHEN view_name ~ '_TAB$' THEN 'TAB'
            WHEN view_name ~ '_VRT$' THEN 'VRT'
            WHEN view_name ~ '_LOV[0-9]*$' THEN 'LOV'
            WHEN view_name ~ '_DM$' THEN 'DM'
            WHEN view_name ~ '_OL$' THEN 'OL'
            WHEN view_name ~ '_MV[STB]$' THEN 'MV'
            WHEN view_name ~ '_(REP|RPV)$' THEN 'REP'
            WHEN view_name ~ '_PUB$' THEN 'PUB'
            WHEN view_name ~ '_UIV$' THEN 'UIV'
            WHEN view_name ~ '_(QRY|QUERY)$' THEN 'QRY'
            WHEN view_name ~ '_(TMP|TEMP)$' THEN 'TMP'
            WHEN view_name ~ '_EXT$' THEN 'EXT'
            ELSE 'METIER'
        END) STORED,
    ADD COLUMN IF NOT EXISTS taille TEXT GENERATED ALWAYS AS (
        CASE
            WHEN view_text IS NULL THEN NULL
            WHEN length(view_text) < 1000 THEN 'XS'
            WHEN length(view_text) < 5000 THEN 'S'
            WHEN length(view_text) < 20000 THEN 'M'
            ELSE 'L'
        END) STORED,
    ADD COLUMN IF NOT EXISTS has_union BOOLEAN GENERATED ALWAYS AS
        (COALESCE(view_text ~* '\yunion\y', FALSE)) STORED,
    ADD COLUMN IF NOT EXISTS calls_api BOOLEAN GENERATED ALWAYS AS
        (COALESCE(view_text ~* '\w+_api\.', FALSE)) STORED,
    ADD COLUMN IF NOT EXISTS custom_fields BOOLEAN GENERATED ALWAYS AS
        (COALESCE(view_text ~* '_(cfv|clv|cft)\y', FALSE)) STORED;

COMMIT;
