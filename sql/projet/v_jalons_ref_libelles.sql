-- =====================================================================
-- Vue : raw_data.v_jalons_ref_libelles
-- ---------------------------------------------------------------------
-- Aplatit les LIBELLÉS (texte affiché) des jalons, issus du bloc
-- FieldValuesAsText récupéré à l'import via $expand=FieldValuesAsText
-- (cf. sharepoint_service.RELATED_LISTS['jalons_ref'].expand).
--
-- Différence brut vs libellé :
--   raw_data->>'Checkmark'                    = '1'        (technique)
--   raw_data->'FieldValuesAsText'->>'Checkmark' = 'Oui'   (affiché)
--
-- PRÉREQUIS : ré-importer la liste "Jalons" après l'ajout du $expand,
--             sinon FieldValuesAsText reste un lien __deferred et les
--             colonnes ci-dessous seront NULL.
-- =====================================================================
CREATE OR REPLACE VIEW raw_data.v_jalons_ref_libelles AS
SELECT
    jr.id                                                      AS jalon_ref_id,
    jr.site_id,
    jr.sharepoint_id,
    (jr.raw_data ->> 'ID')::int                                AS item_id,
    jr.raw_data ->> 'Gate'                                      AS gate,
    -- Valeurs brutes (déjà présentes avant l'expand)
    (jr.raw_data ->> 'PhaseId')::int                           AS phase_id,
    jr.raw_data ->> 'Status'                                    AS statut_brut,
    -- Libellés (FieldValuesAsText) — nécessitent le ré-import avec $expand
    jr.raw_data -> 'FieldValuesAsText' ->> 'Title'             AS titre,
    jr.raw_data -> 'FieldValuesAsText' ->> 'Phase'             AS phase_libelle,
    jr.raw_data -> 'FieldValuesAsText' ->> 'Status'            AS statut_libelle,
    jr.raw_data -> 'FieldValuesAsText' ->> 'Checkmark'         AS checkmark,        -- Oui / Non
    jr.raw_data -> 'FieldValuesAsText' ->> 'PercentComplete'   AS avancement,       -- ex. '100 %'
    jr.raw_data -> 'FieldValuesAsText' ->> 'Priority'          AS priorite,         -- ex. '(2) Normal'
    jr.raw_data -> 'FieldValuesAsText' ->> 'StartDate'         AS date_debut_txt,
    jr.raw_data -> 'FieldValuesAsText' ->> 'DueDate'           AS date_fin_txt,
    jr.raw_data -> 'FieldValuesAsText' ->> 'RetroplanningShifting' AS decalage_txt,
    -- Nom réel de la phase (lookup PhaseId -> sharepoint_phases, par site)
    ph.title                                                   AS phase_nom
FROM raw_data.sharepoint_jalons_ref jr
LEFT JOIN raw_data.sharepoint_phases ph
       ON ph.site_id = jr.site_id
      AND ph.sharepoint_id = (jr.raw_data ->> 'PhaseId')::int;

COMMENT ON VIEW raw_data.v_jalons_ref_libelles IS
'Libellés (FieldValuesAsText) des jalons aplatis en colonnes. Nécessite l''import des jalons avec $expand=FieldValuesAsText.';

-- Exemple d'exploitation :
-- SELECT gate, phase_libelle, statut_libelle, checkmark, avancement
-- FROM raw_data.v_jalons_ref_libelles
-- WHERE site_id = '255' ORDER BY item_id;
