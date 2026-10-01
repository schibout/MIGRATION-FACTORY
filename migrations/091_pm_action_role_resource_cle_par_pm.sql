-- Migration 091 : row_no / pm_action_resource_seq numerotes PAR action
--
-- pm_action_role.row_no et pm_action_resource.pm_action_resource_seq valent
-- desormais 1, 2, 3... dans chaque (pm_no, pm_revision) au lieu d'un compteur
-- global : 1 pour toute action a une seule operation. La cle primaire, qui
-- portait le seul compteur, passe a (pm_no, pm_revision, compteur) comme cote IFS.
-- A jouer AVANT sql/pm_actions/compile.sh (les tables sont rechargees en TRUNCATE).

BEGIN;

ALTER TABLE clean_data.pm_action_role DROP CONSTRAINT IF EXISTS pm_action_role_pkey;
ALTER TABLE clean_data.pm_action_role ADD CONSTRAINT pm_action_role_pkey
    PRIMARY KEY (pm_no, pm_revision, row_no);

ALTER TABLE clean_data.pm_action_resource DROP CONSTRAINT IF EXISTS pm_action_resource_pkey;
ALTER TABLE clean_data.pm_action_resource ADD CONSTRAINT pm_action_resource_pkey
    PRIMARY KEY (pm_no, pm_revision, pm_action_resource_seq);

COMMIT;
