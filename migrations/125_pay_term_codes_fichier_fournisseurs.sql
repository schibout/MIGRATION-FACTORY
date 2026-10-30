-- ============================================================================
-- 125 : conditions de paiement SAP -> IFS manquantes dans la transcodification
-- PAY_TERM, lue par clean_data.alimenter_ifs_fournisseurs_perimetre (ecran
-- Finance > Fournisseurs). Correspondances reprises du fichier de selection
-- fournisseurs (colonnes condition_paiement_sap -> condition_paiement_ifs),
-- arbitre par le metier. N'ajoute que les codes absents : une ligne deja
-- saisie dans l'ecran Transcodification n'est jamais reecrite (C030 et F005,
-- ou le fichier differe de la transco existante, restent tels quels).
-- ============================================================================

INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by, is_active)
SELECT 'PAY_TERM', 'SAP', 'IFS', v.source_value, v.target_value, 'Fichier de selection fournisseurs', 'migration_125', true
  FROM (VALUES ('M115', '60NETS'),
               ('F010', '10NETS'),
               ('F045', '45NETS'),
               ('M015', '15NETS'),
               ('M100', '60NETS'),
               ('F007', '07NETS'),
               ('M025', '30NETS')) AS v (source_value, target_value)
 WHERE NOT EXISTS (SELECT 1 FROM public."TranscodificationTable" t
                    WHERE t.category = 'PAY_TERM' AND t.source_system = 'SAP'
                      AND t.target_system = 'IFS' AND t.source_value = v.source_value);
