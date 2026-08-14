-- =====================================================
-- Fonction : clean_data.get_legacy_as400_id
-- Retourne le code client AS400/PHL (raw_data.client_phl.customer_id)
-- a partir d'un identifiant SAP et, a defaut, d'un nom de client.
--
-- Parametres
--   p_sap_id : numero SAP (client_phl.numero_sap, ex. 'S0000221')
--   p_name   : nom du client, utilise seulement si p_sap_id ne donne rien
--
-- Retour : le code AS400 (ex. 'CIRRA'), ou NULL si aucune correspondance.
--
-- Strategie de recherche, du plus sur au plus permissif :
--   1. numero SAP exact
--   2. nom normalise identique
--   3. nom normalise inclus dans l'autre (dans un sens ou dans l'autre),
--      les deux chaines faisant au moins 5 caracteres
--
-- Normalisation du nom : majuscules, accents replies sur leur lettre de base,
-- puis suppression de tout ce qui n'est pas [A-Z0-9] (espaces, points, tirets,
-- apostrophes). La comparaison est donc insensible a la casse, aux accents et
-- a la ponctuation : 'ECO GREEN S.R.L.' == 'Eco Green SRL'.
--
-- Volontairement PAS de rapprochement flou (pg_trgm) : sur le jeu de donnees
-- reel, le meilleur score des clients non apparies plafonne a 0.23, ce qui ne
-- produirait que de faux rapprochements (ex. 'ALUDIUM FRANCE' -> 'TRIMET FRANCE').
--
-- Determinisme : quand plusieurs codes PHL repondent (3 numero_sap portent
-- 2 codes : S0002113, S0003237, S0003272), on retient le plus petit par ordre
-- alphabetique afin que deux executions donnent le meme resultat.
--
-- Utilisee par clean_data.sp_insert_customer_info_from_file_customer
-- pour alimenter customer_info.cf_legacy_customer_as400_mn.
-- =====================================================

-- Normalisation d'un nom de client, isolee pour rester coherente des deux cotes
-- de la comparaison.
CREATE OR REPLACE FUNCTION clean_data.normalize_customer_name(p_name VARCHAR)
RETURNS VARCHAR
LANGUAGE sql
IMMUTABLE
AS $function$
    SELECT regexp_replace(
               translate(
                   UPPER(COALESCE(p_name, '')),
                   'ÀÁÂÃÄÅÇÈÉÊËÌÍÎÏÑÒÓÔÕÖØÙÚÛÜÝ',
                   'AAAAAACEEEEIIIINOOOOOOUUUUY'
               ),
               '[^A-Z0-9]', '', 'g'
           );
$function$;

COMMENT ON FUNCTION clean_data.normalize_customer_name(VARCHAR) IS
'Nom client normalise pour comparaison : majuscules, sans accents, sans ponctuation ni espaces.';


CREATE OR REPLACE FUNCTION clean_data.get_legacy_as400_id(
    p_sap_id VARCHAR,
    p_name   VARCHAR DEFAULT NULL
)
RETURNS VARCHAR
LANGUAGE plpgsql
STABLE
AS $function$
DECLARE
    v_result VARCHAR;
    v_name   VARCHAR;
BEGIN
    -- 1. Recherche par numero SAP (voie principale)
    IF NULLIF(TRIM(COALESCE(p_sap_id, '')), '') IS NOT NULL THEN
        SELECT MIN(TRIM(p.customer_id))
          INTO v_result
          FROM raw_data.client_phl p
         WHERE TRIM(p.numero_sap) = TRIM(p_sap_id)
           AND NULLIF(TRIM(p.customer_id), '') IS NOT NULL;

        IF v_result IS NOT NULL THEN
            RETURN v_result;
        END IF;
    END IF;

    v_name := clean_data.normalize_customer_name(p_name);

    IF v_name = '' THEN
        RETURN NULL;
    END IF;

    -- 2. Nom normalise identique
    SELECT MIN(TRIM(p.customer_id))
      INTO v_result
      FROM raw_data.client_phl p
     WHERE clean_data.normalize_customer_name(p.name) = v_name
       AND NULLIF(TRIM(p.customer_id), '') IS NOT NULL;

    IF v_result IS NOT NULL THEN
        RETURN v_result;
    END IF;

    -- 3. Inclusion d'un nom dans l'autre. Le seuil de 5 caracteres evite qu'un
    --    nom tres court ne s'accroche a n'importe quelle raison sociale.
    IF length(v_name) >= 5 THEN
        SELECT MIN(TRIM(p.customer_id))
          INTO v_result
          FROM raw_data.client_phl p
         WHERE NULLIF(TRIM(p.customer_id), '') IS NOT NULL
           AND length(clean_data.normalize_customer_name(p.name)) >= 5
           AND (
                    position(v_name in clean_data.normalize_customer_name(p.name)) > 0
                 OR position(clean_data.normalize_customer_name(p.name) in v_name) > 0
               );

        IF v_result IS NOT NULL THEN
            RETURN v_result;
        END IF;
    END IF;

    RETURN NULL;
END;
$function$;

COMMENT ON FUNCTION clean_data.get_legacy_as400_id(VARCHAR, VARCHAR) IS
'Code client AS400/PHL depuis raw_data.client_phl : numero SAP, puis nom normalise exact, puis inclusion de nom. NULL si introuvable.';

-- Controle rapide
-- SELECT clean_data.get_legacy_as400_id('S0000221');                        -- CIRRA
-- SELECT clean_data.get_legacy_as400_id('S0002113');                        -- NEXANJE (2 candidats)
-- SELECT clean_data.get_legacy_as400_id(NULL, 'eco green s.r.l.');          -- ECOGR   (casse + ponctuation)
-- SELECT clean_data.get_legacy_as400_id(NULL, 'NICHE FUSED ALUMINA');       -- ALTEO   (inclusion)
-- SELECT clean_data.get_legacy_as400_id(NULL, 'ETABLISSEMENTS H. CLAUSER'); -- CLAUSER (inclusion)
-- SELECT clean_data.get_legacy_as400_id('INCONNU', 'INCONNU');              -- NULL
