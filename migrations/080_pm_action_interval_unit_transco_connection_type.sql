-- ============================================================================
-- 080 : PM Actions - unite d'intervalle par transcodification, type de
--       connexion dans le domaine IFS, fournisseur principal calcule
--       (demandes explicites du 2026-09-18)
--
-- 1. Transcodification PM_INTERVAL_UNIT (PETOOLS -> IFS)
--    clean_data.populate_pm_action() ne traduit plus la lettre de frequence des
--    fichiers PE Tools (derniere lettre de freq_norm : S / M / A / H) par un CASE
--    code en dur, mais par public.get_transcodification('PM_INTERVAL_UNIT', lettre,
--    'PETOOLS', 'IFS'), modifiable depuis l'ecran Transcodification (la categorie
--    apparait automatiquement : les categories sont lues par DISTINCT).
--    Sans repli : une lettre absente de la table donne pm_interval_unit_db NULL.
--    Le libelle pm_interval_unit n'est plus alimente (NULL).
--
-- 2. connection_type_db doit etre l'une des valeurs du domaine IFS
--    (DB <==> client) : EQUIPMENT<==>EQUIPMENT, VIM<==>VIM, CATEGORY<==>CATEGORY,
--    PLD<==>DESIGN OBJECT, CMPUNT<==>COMPATIBLE UNIT, LINAST<==>LINEAR ASSET,
--    TOOLEQ<==>TOOL/EQUIPMENT, PRJWORKPACKAGE<==>WORK PACKAGE, MODEL<==>MODEL.
--    La valeur seedee par la 035 ('FUNCTIONAL') n'en fait pas partie ; les
--    pm_action pointent des postes techniques (equipment_functional), donc
--    EQUIPMENT. La procedure refuse desormais toute valeur hors domaine et
--    derive elle-meme le libelle client : la ligne connection_type n'est plus
--    lue et est desactivee (elle reste visible dans l'ecran, inactive).
--    pm_action_work_step partage le meme domaine IFS : meme correction.
--
-- 3. purchase_part_supplier.primary_vendor_db n'est plus une constante : la
--    procedure alimenter_purchase_part_supplier() elit UN fournisseur principal
--    par (site, article) (liste de sources SAP eord, puis derniere commande).
--    La ligne de parametrage 'Y' est desactivee pour ne pas laisser croire
--    qu'elle s'applique.
--
-- Idempotent. A jouer AVANT `sql/pm_actions/compile.sh` et
-- `sql/inventory/compile.sh`.
-- ============================================================================

BEGIN;

-- 1. Transcodification de l'unite d'intervalle PE Tools -> IFS
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by)
VALUES ('PM_INTERVAL_UNIT', 'PETOOLS', 'IFS', 'S', 'WEEKS',  'Frequence PE Tools en semaines -> pm_action.pm_interval_unit_db', 'migration_080')
ON CONFLICT (category, source_system, target_system, source_value) DO NOTHING;
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by)
VALUES ('PM_INTERVAL_UNIT', 'PETOOLS', 'IFS', 'M', 'MONTHS', 'Frequence PE Tools en mois -> pm_action.pm_interval_unit_db', 'migration_080')
ON CONFLICT (category, source_system, target_system, source_value) DO NOTHING;
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by)
VALUES ('PM_INTERVAL_UNIT', 'PETOOLS', 'IFS', 'A', 'YEARS',  'Frequence PE Tools en annees -> pm_action.pm_interval_unit_db', 'migration_080')
ON CONFLICT (category, source_system, target_system, source_value) DO NOTHING;
INSERT INTO public."TranscodificationTable" (category, source_system, target_system, source_value, target_value, description, created_by)
VALUES ('PM_INTERVAL_UNIT', 'PETOOLS', 'IFS', 'H', 'HOURS',  'Frequence PE Tools en heures -> pm_action.pm_interval_unit_db', 'migration_080')
ON CONFLICT (category, source_system, target_system, source_value) DO NOTHING;

-- 2. Type de connexion : domaine IFS
UPDATE public.etl_default_values
SET valeur = 'EQUIPMENT',
    description = 'Domaine IFS (EQUIPMENT, VIM, CATEGORY, PLD, CMPUNT, LINAST, TOOLEQ, PRJWORKPACKAGE, MODEL) ; les pm_action pointent des postes techniques. Migration 080.',
    updated_at = CURRENT_TIMESTAMP,
    updated_by = 'migration_080'
WHERE table_cible IN ('clean_data.pm_action', 'clean_data.pm_action_work_step')
  AND colonne = 'connection_type_db'
  AND variante = 'STANDARD'
  AND valeur = 'FUNCTIONAL';

UPDATE public.etl_default_values
SET is_active = FALSE,
    description = 'Plus lue : le libelle client est derive de connection_type_db par la procedure (migration 080).',
    updated_at = CURRENT_TIMESTAMP,
    updated_by = 'migration_080'
WHERE table_cible IN ('clean_data.pm_action', 'clean_data.pm_action_work_step')
  AND colonne = 'connection_type'
  AND variante = 'STANDARD'
  AND is_active;

-- 3. Fournisseur principal calcule
UPDATE public.etl_default_values
SET is_active = FALSE,
    description = 'Plus lue : primary_vendor_db est calcule par alimenter_purchase_part_supplier() (un seul Y par site/article, migration 080).',
    updated_at = CURRENT_TIMESTAMP,
    updated_by = 'migration_080'
WHERE table_cible = 'clean_data.purchase_part_supplier'
  AND colonne = 'primary_vendor_db'
  AND variante = 'STANDARD'
  AND is_active;

COMMIT;
