-- =====================================================================
-- clean_data.associer_sharepoint_users_ifs_person
-- ---------------------------------------------------------------------
-- Backfill de raw_data.sharepoint_users.person_id à partir de
-- clean_data.ifs_person, en 2 passes complémentaires.
--
-- PASSE 1 — par LOGIN (prioritaire, = clé IFS exacte) :
--   La partie du login après le dernier "\" (ex : "stjn\prenom.nom")
--   est comparée en UPPER au person_id IFS (avec troncature à 20 car.).
--   Très fiable : sur les associations existantes, 93 retrouvées, 0 conflit.
--   Attrape notamment les personnes dont first_name/last_name sont NULL
--   dans ifs_person (le matching par nom est alors impossible).
--
-- PASSE 2 — par NOM (pour les lignes encore NULL) :
--   title SharePoint "Nom, Prénom" comparé à first_name + last_name,
--   normalisés (UPPER + TRIM + suppression espaces/traits d'union :
--   récupère "Da Costa", "Quezel-Peron", "Di Donfrancesco"...).
--
-- Garde-fous (les deux passes) :
--   * ne mettent à jour QUE les lignes person_id IS NULL
--     (n'écrasent jamais une association déjà posée)
--   * ne posent QUE les correspondances UNIQUES (1 seul ifs_person)
--
-- Retourne : le nombre total de nouvelles associations (passe 1 + passe 2).
--
-- NB : les utilisateurs restant NULL ne sont pas des personnes IFS
--      (comptes système, externes teamsquare.fr, personnes non chargées
--      dans ifs_person) — c'est attendu.
-- =====================================================================
CREATE OR REPLACE FUNCTION clean_data.associer_sharepoint_users_ifs_person()
RETURNS integer
LANGUAGE plpgsql
AS $function$
DECLARE
    v_login INTEGER := 0;
    v_nom   INTEGER := 0;
BEGIN
    ---------------------------------------------------------------------
    -- PASSE 1 : par login (partie après le dernier backslash) = person_id
    ---------------------------------------------------------------------
    WITH sp AS (
        SELECT
            su.sharepoint_user_id,
            UPPER(TRIM(regexp_replace(su.login_name, '^.*\\', ''))) AS lg
        FROM raw_data.sharepoint_users su
        WHERE su.person_id IS NULL
          AND su.login_name LIKE '%\\%'
    ),
    cand AS (
        SELECT
            sp.sharepoint_user_id,
            ip.person_id,
            COUNT(*) OVER (PARTITION BY sp.sharepoint_user_id) AS nb
        FROM sp
        JOIN clean_data.ifs_person ip
          ON UPPER(TRIM(ip.person_id)) = sp.lg
          OR UPPER(TRIM(ip.person_id)) = LEFT(sp.lg, 20)   -- person_id IFS tronqué à 20
        WHERE ip.person_id IS NOT NULL
    ),
    uniq AS (
        SELECT DISTINCT sharepoint_user_id, person_id FROM cand WHERE nb = 1
    )
    UPDATE raw_data.sharepoint_users su
    SET person_id = uniq.person_id
    FROM uniq
    WHERE su.sharepoint_user_id = uniq.sharepoint_user_id
      AND su.person_id IS NULL;

    GET DIAGNOSTICS v_login = ROW_COUNT;

    ---------------------------------------------------------------------
    -- PASSE 2 : par nom (title "Nom, Prénom") pour les NULL restants
    ---------------------------------------------------------------------
    WITH sp AS (
        SELECT
            su.sharepoint_user_id,
            regexp_replace(UPPER(TRIM(split_part(su.title, ',', 2))), '[ \-]', '', 'g') AS first_n,
            regexp_replace(UPPER(TRIM(split_part(su.title, ',', 1))), '[ \-]', '', 'g') AS last_n
        FROM raw_data.sharepoint_users su
        WHERE su.person_id IS NULL
          AND su.title LIKE '%,%'
    ),
    cand AS (
        SELECT
            sp.sharepoint_user_id,
            ip.person_id,
            COUNT(*) OVER (PARTITION BY sp.sharepoint_user_id) AS nb
        FROM sp
        JOIN clean_data.ifs_person ip
          ON regexp_replace(UPPER(TRIM(ip.first_name)), '[ \-]', '', 'g') = sp.first_n
         AND regexp_replace(UPPER(TRIM(ip.last_name)),  '[ \-]', '', 'g') = sp.last_n
        WHERE ip.person_id IS NOT NULL
    ),
    uniq AS (
        SELECT DISTINCT sharepoint_user_id, person_id FROM cand WHERE nb = 1
    )
    UPDATE raw_data.sharepoint_users su
    SET person_id = uniq.person_id
    FROM uniq
    WHERE su.sharepoint_user_id = uniq.sharepoint_user_id
      AND su.person_id IS NULL;

    GET DIAGNOSTICS v_nom = ROW_COUNT;

    RAISE NOTICE 'Association SharePoint -> IFS Person : % (login) + % (nom) = % nouvelles',
        v_login, v_nom, v_login + v_nom;

    RETURN v_login + v_nom;

EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'ERREUR associer_sharepoint_users_ifs_person : % (%)', SQLERRM, SQLSTATE;
        RAISE;
END;
$function$;

COMMENT ON FUNCTION clean_data.associer_sharepoint_users_ifs_person() IS
'Backfill raw_data.sharepoint_users.person_id depuis clean_data.ifs_person en 2 passes : (1) login après "\" = person_id IFS (prioritaire), (2) nom title "Nom, Prénom" vs first_name/last_name. Ne touche que les NULL, correspondances uniques. Retourne le nombre de nouvelles associations.';

-- Exécution :
-- SELECT clean_data.associer_sharepoint_users_ifs_person();
