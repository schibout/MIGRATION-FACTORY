-- Compte SAP (ERNAM, AFNAM...) -> personne IFS (clean_data.ifs_person.person_id,
-- format PRENOM.NOM). USR21 n'etant pas extraite, le lien passe par la convention
-- de nommage des comptes SAP : NOM ou NOM-<initiale du prenom> (GIRARD-K ->
-- KEVIN.GIRARD), compare au nom IFS sans espaces/tirets/accents.
--   1. Transcodification 'USER' (SAP -> IFS), saisie dans l'ecran Transcodification :
--      arbitre les homonymes (GIRARD -> 3 personnes) et les comptes non reconnus.
--   2. Personne IFS UNIQUE correspondant a la convention.
--   3. Sinon NULL (homonymes, comptes techniques USERBATCH / IP10..., inconnus).
CREATE OR REPLACE FUNCTION public.get_username(p_sap_user varchar)
RETURNS varchar
LANGUAGE plpgsql
STABLE
AS $$
DECLARE
    v_user   varchar := UPPER(NULLIF(TRIM(p_sap_user), ''));
    v_nom    text;
    v_ini    text;
    v_result varchar;
BEGIN
    IF v_user IS NULL THEN
        RETURN NULL;
    END IF;

    v_result := public.get_transcodification('USER', v_user);
    IF v_result IS NOT NULL THEN
        RETURN v_result;
    END IF;

    v_nom := split_part(v_user, '-', 1);
    v_ini := NULLIF(split_part(v_user, '-', 2), '');

    -- ifs_person porte chaque personne en double : on compte les person_id distincts.
    SELECT CASE WHEN count(DISTINCT p.person_id) = 1 THEN min(p.person_id) END
    INTO v_result
    FROM clean_data.ifs_person p
    WHERE regexp_replace(
              translate(UPPER(p.last_name), 'ÀÂÄÇÉÈÊËÎÏÔÖÙÛÜŸ', 'AAACEEEEIIOOUUUY'),
              '[^A-Z]', '', 'g') = v_nom
      AND (v_ini IS NULL
           OR LEFT(translate(UPPER(p.first_name), 'ÀÂÄÇÉÈÊËÎÏÔÖÙÛÜŸ', 'AAACEEEEIIOOUUUY'), 1) = v_ini);

    RETURN v_result;
END;
$$;
