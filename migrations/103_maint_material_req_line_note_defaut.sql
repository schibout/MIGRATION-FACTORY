-- Migration 103 : valeur par defaut de clean_data.maint_material_req_line.note
--
-- note recevait le texte du poste de reservation (resb.sgtxt). Elle lit desormais
-- public.get_default_value('clean_data.maint_material_req_line', 'note') =
-- 'Déjà sortie SAP', modifiable dans l'ecran Valeurs par defaut.
-- A jouer AVANT sql/operation/compile.sh (sinon le repli code en dur s'applique).

BEGIN;

INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('operation', 'clean_data.maint_material_req_line', 'note', 'STANDARD', 'CONSTANTE', 'Déjà sortie SAP', 'Source : create_alimenter_maint_material_req_line.sql', 'migration_103')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;

COMMIT;
