-- Migration 101 : jt_task_resource.resource_seq porte l'organisation de
-- maintenance (SJ-MATC, SJ-MCAR...) de la tache, demande explicite du 2026-10-07.
-- La colonne etait NUMERIC (jamais alimentee) : passage en texte.
-- A jouer AVANT sql/operation/compile.sh.
ALTER TABLE clean_data.jt_task_resource
    ALTER COLUMN resource_seq TYPE varchar(20) USING resource_seq::text;

COMMENT ON COLUMN clean_data.jt_task_resource.resource_seq IS
    'Organisation de maintenance de la tache (jt_task.organization_id, ex. SJ-MATC)';
