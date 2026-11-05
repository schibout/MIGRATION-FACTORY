-- Catalogue IFS : libelles francais des champs d'activite de projet, absents de la spec
-- Lot09_Projet_PerimetreEtPlanning_V3.0.xlsx (les 69 champs de ACTIVITY y sont vides).
-- Proposes par l'assistant et valides par Samir le 2026-11-05 : ce ne sont pas des libelles issus d'IFS.
-- Ne remplit que les libelles vides. Rejouable. Une reimportation de la spec peut les ecraser :
-- rejouer alors cette migration.
BEGIN;

UPDATE public.ifs_field_catalog c
   SET field_label_fr = v.libelle
  FROM (VALUES
    ('ACTIVITY_RESPONSIBLE', 'Responsable activité'),
    ('AMOUNT_PLANNED', 'Montant planifié'),
    ('AMOUNT_USED', 'Montant consommé'),
    ('BASELINE_PCD', 'Inducteur de coût de référence'),
    ('BASELINE_PCD_DB', 'Inducteur de coût de référence'),
    ('CLOSED_DATE', 'Date de clôture'),
    ('CONSTRAINT_DATE', 'Date de contrainte'),
    ('CONSTRAINT_TYPE', 'Type de contrainte'),
    ('CONSTRAINT_TYPE_DB', 'Type de contrainte'),
    ('EARLY_START', 'Début au plus tôt'),
    ('EARLY_FINISH', 'Fin au plus tôt'),
    ('ESTIMATED_PROGRESS', 'Avancement estimé'),
    ('EXCLUDE_PERIODICAL_CAP', 'Exclu de la capitalisation périodique'),
    ('EXCLUDE_PERIODICAL_CAP_DB', 'Exclu de la capitalisation périodique'),
    ('EXCLUDE_RESOURCE_PROGRESS', 'Exclu de l''avancement ressources'),
    ('EXCLUDE_RESOURCE_PROGRESS_DB', 'Exclu de l''avancement ressources'),
    ('FREE_FLOAT', 'Marge libre'),
    ('GENERATE_SAFETY_STOCK', 'Générer stock de sécurité'),
    ('LATE_START', 'Début au plus tard'),
    ('LATE_FINISH', 'Fin au plus tard'),
    ('MANUAL_PROGRESS_COST', 'Avancement manuel coût'),
    ('MANUAL_PROGRESS_HOURS', 'Avancement manuel heures'),
    ('MANUAL_PROGRESS_LEVEL', 'Niveau d''avancement manuel'),
    ('MANUAL_PROGRESS_LEVEL_DB', 'Niveau d''avancement manuel'),
    ('NODE_TYPE', 'Type de nœud'),
    ('NODE_TYPE_DB', 'Type de nœud'),
    ('PLANNED_COST_DRIVER', 'Inducteur de coût planifié'),
    ('PLANNED_COST_DRIVER_DB', 'Inducteur de coût planifié'),
    ('PROGRESS_METHOD', 'Méthode d''avancement'),
    ('PROGRESS_METHOD_DB', 'Méthode d''avancement'),
    ('RELEASED_DATE', 'Date de lancement'),
    ('SET_ACTIVITY_CHANGED', 'Activité modifiée'),
    ('SET_ACTIVITY_CHANGED_DB', 'Activité modifiée'),
    ('SET_IN_BASELINE', 'Dans la référence'),
    ('SHORT_NAME', 'Nom abrégé'),
    ('TOTAL_DURATION_DAYS', 'Durée totale (jours)'),
    ('TOTAL_WORK_DAYS', 'Jours ouvrés totaux'),
    ('TOTAL_FLOAT', 'Marge totale'),
    ('TOTAL_KEY_PATH', 'Chemin de clé complet')
  ) AS v(champ, libelle)
 WHERE upper(c.entity) = 'ACTIVITY'
   AND upper(c.field_name) = v.champ
   AND COALESCE(trim(c.field_label_fr), '') = '';

-- Champs de clean_data.project_activity_class absents de ACTIVITY : hors perimetre pour ne pas
-- entrer dans ce qui est genere a partir du catalogue, ils ne servent qu'au libelle.
INSERT INTO public.ifs_field_catalog (lot_id, entity, field_name, field_label_fr, in_scope, comments, source_file)
VALUES ('LOT09', 'PROJECT_ACTIVITY_CLASS', 'ACTIVITY_CLASS_ID', 'Classe d''activité', false,
        'Libellé validé le 2026-11-05, absent de la spec', 'migrations/131_libelles_catalogue_activity.sql'),
       ('LOT09', 'PROJECT_ACTIVITY_CLASS', 'ACTIVITY_CLASS_SEQ', 'Séq. classe d''activité', false,
        'Libellé validé le 2026-11-05, absent de la spec', 'migrations/131_libelles_catalogue_activity.sql')
ON CONFLICT ON CONSTRAINT uq_ifs_field_catalog DO NOTHING;

COMMIT;
