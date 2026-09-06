-- ============================================================================
-- 069 : valeurs par defaut des colonnes articlePhl non alimentees par le fichier
--
-- CONSTAT
--   Les 5 tables cibles du module articlePhl totalisent 405 colonnes, dont 169
--   n'etaient ecrites par AUCUN INSERT des procedures alimenter_*_phl : elles
--   restaient NULL sans etre visibles ni pilotables depuis l'ecran
--   /configuration/valeurs-defaut.
--
-- CHANGEMENT
--   Ces colonnes passent toutes par public.get_default_value(table, colonne,
--   'ARTICLEPHL') : plus aucun NULL ni chaine vide code en dur dans les
--   procedures. Cette migration cree les 169 lignes correspondantes.
--
-- VARIANTE 'ARTICLEPHL' -- ce n'est pas cosmetique : 76 de ces cles portent
--   deja une ligne 'COMPOSANT' (module articleComposant, qui ecrit dans les
--   MEMES tables IFS). Sans variante dediee, les appels articlePhl liraient la
--   valeur d'un autre module (cf. "piege des variantes" dans CLAUDE.md).
--
-- PRE-REMPLISSAGE
--   - 76 lignes reprennent la valeur de la variante COMPOSANT (meme table cible
--     IFS, meme semantique) : point de depart, modifiable depuis l'ecran ;
--   - 4 lignes reprennent le default_value de public.ifs_field_catalog ;
--   - 89 lignes sont creees VIDES, a saisir dans l'ecran. Tant qu'elles le sont,
--     la colonne recoit NULL : PostgreSQL n'a pas d'etat intermediaire entre
--     "pas de valeur" et NULL. Ce que la migration change, c'est que ces
--     colonnes deviennent visibles et pilotables.
--   Les colonnes marquees OBLIGATOIRE cote IFS le sont dans leur description :
--     SELECT colonne, description FROM public.etl_default_values
--      WHERE variante = 'ARTICLEPHL' AND description LIKE '%OBLIGATOIRE%';
--
-- IDEMPOTENT : ON CONFLICT DO NOTHING sur (table_cible, colonne, variante).
--   Une valeur ajustee depuis l'ecran n'est jamais ecrasee par un rejeu.
--
-- A JOUER AVEC : cd sql/articlePhl && ./compile.sh (les procedures appellent
--   ces cles ; sans les lignes ci-dessous get_default_value renvoie NULL).
--
-- Rollback en bas de fichier.
-- ============================================================================

-- FORMAT : une instruction INSERT par ligne (et non un VALUES multi-lignes).
--   sql/config/apply_default_values.py::_decouper_valeurs s'arrete a la premiere
--   parenthese fermante : un bloc VALUES groupe ne serait lu qu'a moitie et
--   verifier_valeurs_defaut.py signalerait des appels orphelins.
-- ============================================================================

BEGIN;

INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.inventory_part', 'abc_class_locked_until', 'ARTICLEPHL', 'CONSTANTE', '', 'Classe ABC verrouillée jusqu''à - a saisir dans /configuration/valeurs-defaut', 'migration_069')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;

INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.inventory_part', 'acquisition_origin', 'ARTICLEPHL', 'CONSTANTE', '', 'Origine de l''acquisition - a saisir dans /configuration/valeurs-defaut', 'migration_069')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;

INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.inventory_part', 'acquisition_reason_id', 'ARTICLEPHL', 'CONSTANTE', '', 'ID motif d''acquisition - a saisir dans /configuration/valeurs-defaut', 'migration_069')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;

INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.inventory_part', 'actual_cost_activated', 'ARTICLEPHL', 'CONSTANTE', '', '!>Periodic Weighted Average Activated - a saisir dans /configuration/valeurs-defaut', 'migration_069')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;

INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.inventory_part', 'automatic_capability_check', 'ARTICLEPHL', 'CONSTANTE', 'No Automatic Capability Check', 'Contrôle autom. capabilité - repris du module articleComposant', 'migration_069')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;

INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.inventory_part', 'avail_activity_status_db', 'ARTICLEPHL', 'CONSTANTE', 'CHANGED', 'Statut activité disp. - repris du module articleComposant - OBLIGATOIRE cote IFS', 'migration_069')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;

INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.inventory_part', 'c_amma_type', 'ARTICLEPHL', 'CONSTANTE', '', 'C Amma Type - a saisir dans /configuration/valeurs-defaut', 'migration_069')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;

INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.inventory_part', 'c_amma_type_db', 'ARTICLEPHL', 'CONSTANTE', '', 'C Amma Type - a saisir dans /configuration/valeurs-defaut', 'migration_069')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;

INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.inventory_part', 'catch_unit_meas', 'ARTICLEPHL', 'CONSTANTE', '', 'Extraire U/M - a saisir dans /configuration/valeurs-defaut', 'migration_069')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;

INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.inventory_part', 'c_green_percentage', 'ARTICLEPHL', 'CONSTANTE', '', 'C Green Percentage - a saisir dans /configuration/valeurs-defaut', 'migration_069')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;

INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.inventory_part', 'c_green_percentage_db', 'ARTICLEPHL', 'CONSTANTE', '', 'C Green Percentage - a saisir dans /configuration/valeurs-defaut', 'migration_069')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;

INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.inventory_part', 'c_is_green', 'ARTICLEPHL', 'CONSTANTE', 'False', 'C Is Green - repris du module articleComposant', 'migration_069')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;

INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.inventory_part', 'c_is_green_db', 'ARTICLEPHL', 'CONSTANTE', 'FALSE', 'C Is Green - repris du module articleComposant', 'migration_069')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;

INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.inventory_part', 'consumption_tax', 'ARTICLEPHL', 'CONSTANTE', 'False', 'Consumption Tax - repris du module articleComposant', 'migration_069')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;

INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.inventory_part', 'consumption_tax_db', 'ARTICLEPHL', 'CONSTANTE', 'FALSE', 'Consumption Tax - repris du module articleComposant - OBLIGATOIRE cote IFS', 'migration_069')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;

INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.inventory_part', 'co_reserve_onh_analys_flag', 'ARTICLEPHL', 'CONSTANTE', 'No Availability Check', 'Vérifier dispon. à la réservation cde cl. - repris du module articleComposant', 'migration_069')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;

INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.inventory_part', 'c_recasting_type', 'ARTICLEPHL', 'CONSTANTE', '', 'C Recasting Type - a saisir dans /configuration/valeurs-defaut', 'migration_069')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;

INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.inventory_part', 'c_recasting_type_db', 'ARTICLEPHL', 'CONSTANTE', '', 'C Recasting Type - a saisir dans /configuration/valeurs-defaut', 'migration_069')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;

INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.inventory_part', 'cycle_code', 'ARTICLEPHL', 'CONSTANTE', 'Not Cyclic Counting', 'Cycle comptage - repris du module articleComposant', 'migration_069')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;

INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.inventory_part', 'decline_date', 'ARTICLEPHL', 'CONSTANTE', '', 'Date de refus - a saisir dans /configuration/valeurs-defaut', 'migration_069')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;

INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.inventory_part', 'decline_issue_counter', 'ARTICLEPHL', 'CONSTANTE', '', '!>Decline Issue Counter - a saisir dans /configuration/valeurs-defaut', 'migration_069')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;

INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.inventory_part', 'description_in_use', 'ARTICLEPHL', 'CONSTANTE', '', 'Description - a saisir dans /configuration/valeurs-defaut', 'migration_069')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;

INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.inventory_part', 'dim_quality', 'ARTICLEPHL', 'CONSTANTE', '', 'Dim/Qualité - a saisir dans /configuration/valeurs-defaut', 'migration_069')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;

INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.inventory_part', 'dop_connection', 'ARTICLEPHL', 'CONSTANTE', 'Automatic DOP', 'Connexion TDC - repris du module articleComposant', 'migration_069')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;

INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.inventory_part', 'dop_netting', 'ARTICLEPHL', 'CONSTANTE', 'No Netting', 'Compens. TDC - repris du module articleComposant', 'migration_069')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;

INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.inventory_part', 'durability_day', 'ARTICLEPHL', 'CONSTANTE', '', 'Durabilité en jours - a saisir dans /configuration/valeurs-defaut', 'migration_069')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;

INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.inventory_part', 'earliest_ultd_supply_date', 'ARTICLEPHL', 'CONSTANTE', '', 'Date approvisionnement illimité au plus tôt - a saisir dans /configuration/valeurs-defaut', 'migration_069')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;

INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.inventory_part', 'eng_attribute', 'ARTICLEPHL', 'CONSTANTE', '', 'Modèle Caractéristique - a saisir dans /configuration/valeurs-defaut', 'migration_069')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;

INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.inventory_part', 'estimated_material_cost', 'ARTICLEPHL', 'CONSTANTE', '0', 'Coût Matériel Estimé - repris du module articleComposant', 'migration_069')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;

INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.inventory_part', 'excl_ship_pack_proposal', 'ARTICLEPHL', 'CONSTANTE', 'False', 'Exclure de la proposition d''emballage d''expédition - repris du module articleComposant', 'migration_069')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;

INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.inventory_part', 'expired_date', 'ARTICLEPHL', 'CONSTANTE', '', 'Date expiration - a saisir dans /configuration/valeurs-defaut', 'migration_069')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;

INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.inventory_part', 'expired_issue_counter', 'ARTICLEPHL', 'CONSTANTE', '', '!>Expired Issue Counter - a saisir dans /configuration/valeurs-defaut', 'migration_069')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;

INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.inventory_part', 'ext_service_cost_method', 'ARTICLEPHL', 'CONSTANTE', 'Exclude Service Cost', 'Méth. De Coût Serv. Externe - repris du module articleComposant', 'migration_069')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;

INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.inventory_part', 'first_stat_issue_date', 'ARTICLEPHL', 'CONSTANTE', '', '!>First Stat Issue Date - a saisir dans /configuration/valeurs-defaut', 'migration_069')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;

INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.inventory_part', 'forecast_consumption_flag', 'ARTICLEPHL', 'CONSTANTE', 'No Online Consumption', 'Prévision de consommation - repris du module articleComposant', 'migration_069')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;

INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.inventory_part', 'freq_class_locked_until', 'ARTICLEPHL', 'CONSTANTE', '', 'Classe fréq. verrouillée jusqu''à - a saisir dans /configuration/valeurs-defaut', 'migration_069')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;

INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.inventory_part', 'frequency_class', 'ARTICLEPHL', 'CONSTANTE', 'Very Slow Mover', 'Classe fréquence - repris du module articleComposant', 'migration_069')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;

INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.inventory_part', 'hazard_code', 'ARTICLEPHL', 'CONSTANTE', '', 'Code de sécurité - a saisir dans /configuration/valeurs-defaut', 'migration_069')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;

INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.inventory_part', 'inventory_part_cost_level', 'ARTICLEPHL', 'CONSTANTE', 'Cost Per Part', 'Niveau coût article stock - repris du module articleComposant', 'migration_069')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;

INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.inventory_part', 'inventory_valuation_method', 'ARTICLEPHL', 'CONSTANTE', '', 'Méthode valorisation stock - a saisir dans /configuration/valeurs-defaut', 'migration_069')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;

INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.inventory_part', 'invoice_consideration', 'ARTICLEPHL', 'CONSTANTE', 'Ignore Invoice Price', 'Considération facture fourni. - repris du module articleComposant', 'migration_069')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;

INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.inventory_part', 'last_activity_date', 'ARTICLEPHL', 'CONSTANTE', '', 'Dernière date d''activité - a saisir dans /configuration/valeurs-defaut', 'migration_069')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;

INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.inventory_part', 'latest_stat_affecting_date', 'ARTICLEPHL', 'CONSTANTE', '', 'Date affectation dernières stats - a saisir dans /configuration/valeurs-defaut', 'migration_069')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;

INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.inventory_part', 'latest_stat_issue_date', 'ARTICLEPHL', 'CONSTANTE', '', '!>Latest Stat Issue Date - a saisir dans /configuration/valeurs-defaut', 'migration_069')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;

INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.inventory_part', 'lead_time_code', 'ARTICLEPHL', 'CONSTANTE', 'Purchased', 'Code délai - repris du module articleComposant', 'migration_069')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;

INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.inventory_part', 'lifecycle_stage', 'ARTICLEPHL', 'CONSTANTE', 'Development', 'Etape cycle de vie - repris du module articleComposant', 'migration_069')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;

INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.inventory_part', 'life_stage_locked_until', 'ARTICLEPHL', 'CONSTANTE', '', 'Etape cycle de vie verrouillée jusqu''à - a saisir dans /configuration/valeurs-defaut', 'migration_069')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;

INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.inventory_part', 'mandatory_expiration_date', 'ARTICLEPHL', 'CONSTANTE', 'False', 'Date d''expiration obligatoire - repris du module articleComposant', 'migration_069')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;

INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.inventory_part', 'max_actual_cost_update', 'ARTICLEPHL', 'CONSTANTE', '', 'Mise à jour coût réel max (%) - a saisir dans /configuration/valeurs-defaut', 'migration_069')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;

INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.inventory_part', 'max_storage_humidity', 'ARTICLEPHL', 'CONSTANTE', '', 'Humidité max. - a saisir dans /configuration/valeurs-defaut', 'migration_069')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;

INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.inventory_part', 'max_storage_temperature', 'ARTICLEPHL', 'CONSTANTE', '', 'Température max. - a saisir dans /configuration/valeurs-defaut', 'migration_069')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;

INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.inventory_part', 'min_durab_days_co_deliv', 'ARTICLEPHL', 'CONSTANTE', '0', 'Jours restants mini à livraison cde Client - repris du module articleComposant - OBLIGATOIRE cote IFS', 'migration_069')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;

INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.inventory_part', 'min_durab_days_planning', 'ARTICLEPHL', 'CONSTANTE', '0', 'Jours restants minimum pour planification - repris du module articleComposant - OBLIGATOIRE cote IFS', 'migration_069')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;

INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.inventory_part', 'min_storage_humidity', 'ARTICLEPHL', 'CONSTANTE', '', 'Humidité min. - a saisir dans /configuration/valeurs-defaut', 'migration_069')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;

INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.inventory_part', 'min_storage_temperature', 'ARTICLEPHL', 'CONSTANTE', '', 'Température min. - a saisir dans /configuration/valeurs-defaut', 'migration_069')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;

INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.inventory_part', 'negative_on_hand', 'ARTICLEPHL', 'CONSTANTE', 'Negative On Hand Not Allowed', 'Physique négative - repris du module articleComposant', 'migration_069')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;

INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.inventory_part', 'note_id', 'ARTICLEPHL', 'CONSTANTE', '', 'Id note - a saisir dans /configuration/valeurs-defaut', 'migration_069')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;

INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.inventory_part', 'onhand_analysis_flag', 'ARTICLEPHL', 'CONSTANTE', 'No Availability Check', 'Contrôle de disponibilité - repris du module articleComposant', 'migration_069')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;

INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.inventory_part', 'part_catalog_configurable_db', 'ARTICLEPHL', 'CONSTANTE', 'NOT CONFIGURED', 'Part Catalog Configurable - repris du module articleComposant', 'migration_069')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;

INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.inventory_part', 'part_catalog_description', 'ARTICLEPHL', 'CONSTANTE', '', 'Part Catalog Description - a saisir dans /configuration/valeurs-defaut', 'migration_069')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;

INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.inventory_part', 'part_catalog_std_name_id', 'ARTICLEPHL', 'CONSTANTE', '0', 'Part Catalog Std Name Id - repris du module articleComposant', 'migration_069')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;

INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.inventory_part', 'part_cost_group_id', 'ARTICLEPHL', 'CONSTANTE', '', 'ID groupe coûts article - a saisir dans /configuration/valeurs-defaut', 'migration_069')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;

INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.inventory_part', 'product_category_id', 'ARTICLEPHL', 'CONSTANTE', '', 'ID catégorie produit - a saisir dans /configuration/valeurs-defaut', 'migration_069')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;

INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.inventory_part', 'putaway_zone_refill_option', 'ARTICLEPHL', 'CONSTANTE', '', 'Réappro. zones rangement - a saisir dans /configuration/valeurs-defaut', 'migration_069')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;

INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.inventory_part', 'putaway_zone_refill_option_db', 'ARTICLEPHL', 'CONSTANTE', '', 'Réappro. zones rangement - a saisir dans /configuration/valeurs-defaut', 'migration_069')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;

INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.inventory_part', 'region_of_origin', 'ARTICLEPHL', 'CONSTANTE', '', 'Région d''origine - a saisir dans /configuration/valeurs-defaut', 'migration_069')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;

INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.inventory_part', 'reset_config_std_cost', 'ARTICLEPHL', 'CONSTANTE', 'False', 'Réinitialiser configuration coût standard pour le site d''approvisionnement - repris du module articleComposant', 'migration_069')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;

INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.inventory_part', 'second_commodity', 'ARTICLEPHL', 'CONSTANTE', '', 'Groupe produits 2 - a saisir dans /configuration/valeurs-defaut', 'migration_069')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;

INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.inventory_part', 'shortage_flag', 'ARTICLEPHL', 'CONSTANTE', 'No Shortage Notation', 'Avis de rupt. de stock - repris du module articleComposant', 'migration_069')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;

INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.inventory_part', 'standard_putaway_qty', 'ARTICLEPHL', 'CONSTANTE', '', 'Qté rangement std - a saisir dans /configuration/valeurs-defaut', 'migration_069')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;

INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.inventory_part', 'stock_management', 'ARTICLEPHL', 'CONSTANTE', 'System Managed Inventory', 'Gestion du stock - repris du module articleComposant', 'migration_069')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;

INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.inventory_part', 'storage_depth_requirement', 'ARTICLEPHL', 'CONSTANTE', '', 'Profondeur - a saisir dans /configuration/valeurs-defaut', 'migration_069')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;

INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.inventory_part', 'storage_height_requirement', 'ARTICLEPHL', 'CONSTANTE', '', 'Hauteur - a saisir dans /configuration/valeurs-defaut', 'migration_069')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;

INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.inventory_part', 'storage_width_requirement', 'ARTICLEPHL', 'CONSTANTE', '', 'Largeur - a saisir dans /configuration/valeurs-defaut', 'migration_069')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;

INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.inventory_part', 'supersedes', 'ARTICLEPHL', 'CONSTANTE', '', 'Remplace - a saisir dans /configuration/valeurs-defaut', 'migration_069')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;

INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.inventory_part', 'supply_chain_part_group', 'ARTICLEPHL', 'CONSTANTE', '', 'Grpe Art. Supply Chain - a saisir dans /configuration/valeurs-defaut', 'migration_069')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;

INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.inventory_part', 'tax_manuf_equivalent', 'ARTICLEPHL', 'CONSTANTE', 'False', 'Tax Manufacturing Equivalent - repris du module articleComposant', 'migration_069')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;

INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.inventory_part', 'tax_manuf_equivalent_db', 'ARTICLEPHL', 'CONSTANTE', 'FALSE', 'Tax Manufacturing Equivalent - repris du module articleComposant - OBLIGATOIRE cote IFS', 'migration_069')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;

INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.inventory_part', 'technical_coordinator_id', 'ARTICLEPHL', 'CONSTANTE', '', 'ID coordinateur technique - a saisir dans /configuration/valeurs-defaut', 'migration_069')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;

INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.inventory_part', 'zero_cost_flag', 'ARTICLEPHL', 'CONSTANTE', 'Zero Cost Forbidden', 'Coût zéro - defaut du catalogue IFS', 'migration_069')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;

INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.manuf_part_attribute', 'adjust_on_op_qty_deviation', 'ARTICLEPHL', 'CONSTANTE', 'False', '!>Adjust On Op Qty Deviation - repris du module articleComposant', 'migration_069')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;

INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.manuf_part_attribute', 'auto_replace_alt_comp', 'ARTICLEPHL', 'CONSTANTE', 'False', 'Remplacer automatiquement comp. alt - repris du module articleComposant', 'migration_069')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;

INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.manuf_part_attribute', 'backflush_part', 'ARTICLEPHL', 'CONSTANTE', 'All Locations', 'Réservation et postdéduction depuis indicateur - repris du module articleComposant', 'migration_069')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;

INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.manuf_part_attribute', 'close_tolerance', 'ARTICLEPHL', 'CONSTANTE', '0', 'Tolérance clôture - repris du module articleComposant - OBLIGATOIRE cote IFS', 'migration_069')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;

INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.manuf_part_attribute', 'configuration_usage', 'ARTICLEPHL', 'CONSTANTE', 'Common', 'Utilisation Configuration - repris du module articleComposant', 'migration_069')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;

INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.manuf_part_attribute', 'consider_lead_time', 'ARTICLEPHL', 'CONSTANTE', 'True', 'Considérer délai - repris du module articleComposant', 'migration_069')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;

INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.manuf_part_attribute', 'created_from_config_id', 'ARTICLEPHL', 'CONSTANTE', '', 'Créé depuis ID config - a saisir dans /configuration/valeurs-defaut', 'migration_069')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;

INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.manuf_part_attribute', 'created_from_contract', 'ARTICLEPHL', 'CONSTANTE', '', 'Créé depuis contrat - a saisir dans /configuration/valeurs-defaut', 'migration_069')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;

INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.manuf_part_attribute', 'created_from_part_no', 'ARTICLEPHL', 'CONSTANTE', '', 'Créé depuis n° d''article - a saisir dans /configuration/valeurs-defaut', 'migration_069')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;

INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.manuf_part_attribute', 'dop_pegged_so_update_flag', 'ARTICLEPHL', 'CONSTANTE', 'Planned', 'Màj OF lié TDC - repris du module articleComposant', 'migration_069')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;

INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.manuf_part_attribute', 'engineering_info', 'ARTICLEPHL', 'CONSTANTE', 'Not Mandatory', 'Infos Techniques - repris du module articleComposant', 'migration_069')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;

INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.manuf_part_attribute', 'issue_overreported_qty', 'ARTICLEPHL', 'CONSTANTE', 'False', '!>Issue Overreported Qty - repris du module articleComposant', 'migration_069')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;

INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.manuf_part_attribute', 'issue_planned_scrap', 'ARTICLEPHL', 'CONSTANTE', 'True', 'Réserver/sortir rebut planifié - repris du module articleComposant', 'migration_069')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;

INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.manuf_part_attribute', 'issue_type', 'ARTICLEPHL', 'CONSTANTE', 'Reserve And Backflush', 'Réserve/Méthode d''émission - repris du module articleComposant', 'migration_069')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;

INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.manuf_part_attribute', 'issue_type_db', 'ARTICLEPHL', 'CONSTANTE', 'RESERVE_AND_BACKFLUSH', 'Réserve/Méthode d''émission - repris du module articleComposant - OBLIGATOIRE cote IFS', 'migration_069')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;

INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.manuf_part_attribute', 'leadtime_source', 'ARTICLEPHL', 'CONSTANTE', '', 'Source délai - a saisir dans /configuration/valeurs-defaut', 'migration_069')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;

INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.manuf_part_attribute', 'leadtime_source_db', 'ARTICLEPHL', 'CONSTANTE', '', 'Source délai - a saisir dans /configuration/valeurs-defaut', 'migration_069')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;

INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.manuf_part_attribute', 'lot_batch_string', 'ARTICLEPHL', 'CONSTANTE', '', 'Segment de lot - a saisir dans /configuration/valeurs-defaut', 'migration_069')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;

INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.manuf_part_attribute', 'manuf_engineer', 'ARTICLEPHL', 'CONSTANTE', '', 'Ingénieur de fab - a saisir dans /configuration/valeurs-defaut', 'migration_069')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;

INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.manuf_part_attribute', 'mrp_control_flag', 'ARTICLEPHL', 'CONSTANTE', 'True', '!>Mrp Control Flag - repris du module articleComposant', 'migration_069')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;

INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.manuf_part_attribute', 'overhaul_scrap_rule_db', 'ARTICLEPHL', 'CONSTANTE', 'DIRECT', 'Règle de remise en état - repris du module articleComposant - OBLIGATOIRE cote IFS', 'migration_069')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;

INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.manuf_part_attribute', 'over_reporting', 'ARTICLEPHL', 'CONSTANTE', 'Allowed', 'Sur déclaration - repris du module articleComposant', 'migration_069')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;

INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.manuf_part_attribute', 'over_report_tolerance', 'ARTICLEPHL', 'CONSTANTE', '', 'Tolérance sur rapport - a saisir dans /configuration/valeurs-defaut', 'migration_069')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;

INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.manuf_part_attribute', 'process_type', 'ARTICLEPHL', 'CONSTANTE', '', 'Type de traitement - a saisir dans /configuration/valeurs-defaut', 'migration_069')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;

INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.manuf_part_attribute', 'prod_part_as_supply_in_mrp', 'ARTICLEPHL', 'CONSTANTE', 'True', 'Article pdt comme approv. dans MRP - repris du module articleComposant', 'migration_069')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;

INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.manuf_part_attribute', 'promise_planned', 'ARTICLEPHL', 'CONSTANTE', 'Promised', 'Date planifiée - repris du module articleComposant', 'migration_069')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;

INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.manuf_part_attribute', 'routing_effectivity', 'ARTICLEPHL', 'CONSTANTE', 'Date', 'Mise en vigueur gamme - repris du module articleComposant', 'migration_069')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;

INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.manuf_part_attribute', 'ship_dirty_repair_code', 'ARTICLEPHL', 'CONSTANTE', '', 'Code réparation Eléments expédiés non vérifiés - a saisir dans /configuration/valeurs-defaut', 'migration_069')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;

INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.manuf_part_attribute', 'structure_effectivity', 'ARTICLEPHL', 'CONSTANTE', 'Date', 'Gestion structure - repris du module articleComposant', 'migration_069')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;

INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.manuf_part_attribute', 'use_theoritical_density', 'ARTICLEPHL', 'CONSTANTE', 'False', 'Utiliser densité théorique - repris du module articleComposant', 'migration_069')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;

INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.part_catalog', 'allow_as_not_consumed', 'ARTICLEPHL', 'CONSTANTE', 'False', 'Autoriser comme non Consommé - repris du module articleComposant', 'migration_069')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;

INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.part_catalog', 'catch_unit_enabled', 'ARTICLEPHL', 'CONSTANTE', 'False', 'U/M capture activée - repris du module articleComposant', 'migration_069')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;

INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.part_catalog', 'cest_code', 'ARTICLEPHL', 'CONSTANTE', '', 'Code CEST - a saisir dans /configuration/valeurs-defaut', 'migration_069')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;

INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.part_catalog', 'component_lot_rule', 'ARTICLEPHL', 'CONSTANTE', 'Many Lots Allowed', 'Règle lot composants - repris du module articleComposant', 'migration_069')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;

INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.part_catalog', 'condition_code_usage', 'ARTICLEPHL', 'CONSTANTE', '', 'Autoriser Code Condition - a saisir dans /configuration/valeurs-defaut', 'migration_069')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;

INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.part_catalog', 'configurable', 'ARTICLEPHL', 'CONSTANTE', 'Not Configured', 'Configurable - repris du module articleComposant', 'migration_069')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;

INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.part_catalog', 'cust_warranty_id', 'ARTICLEPHL', 'CONSTANTE', '', 'Id garantie client - a saisir dans /configuration/valeurs-defaut', 'migration_069')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;

INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.part_catalog', 'eng_serial_tracking_code', 'ARTICLEPHL', 'CONSTANTE', 'Not Serial Tracking', 'Suivi des séries après livraison - repris du module articleComposant', 'migration_069')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;

INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.part_catalog', 'fci_code', 'ARTICLEPHL', 'CONSTANTE', '', 'Code FCI - a saisir dans /configuration/valeurs-defaut', 'migration_069')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;

INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.part_catalog', 'freight_factor', 'ARTICLEPHL', 'CONSTANTE', '1', 'Facteur chargement - repris du module articleComposant', 'migration_069')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;

INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.part_catalog', 'info_text', 'ARTICLEPHL', 'CONSTANTE', '', 'Texte info - a saisir dans /configuration/valeurs-defaut', 'migration_069')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;

INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.part_catalog', 'input_unit_meas_group_id', 'ARTICLEPHL', 'CONSTANTE', '', 'Entrée ID groupe U/M - a saisir dans /configuration/valeurs-defaut', 'migration_069')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;

INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.part_catalog', 'language_description', 'ARTICLEPHL', 'CONSTANTE', '', 'Description de langue - a saisir dans /configuration/valeurs-defaut', 'migration_069')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;

INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.part_catalog', 'lot_tracking_code', 'ARTICLEPHL', 'CONSTANTE', 'Not Lot Tracking', 'Traçabilité des lots - defaut du catalogue IFS', 'migration_069')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;

INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.part_catalog', 'multilevel_tracking', 'ARTICLEPHL', 'CONSTANTE', '', 'Traçabilité multi-niveau - a saisir dans /configuration/valeurs-defaut', 'migration_069')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;

INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.part_catalog', 'part_main_group', 'ARTICLEPHL', 'CONSTANTE', '', 'Groupe principal article - a saisir dans /configuration/valeurs-defaut', 'migration_069')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;

INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.part_catalog', 'position_part', 'ARTICLEPHL', 'CONSTANTE', 'Not a Position Part', 'Article Position - repris du module articleComposant', 'migration_069')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;

INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.part_catalog', 'product_type_classif', 'ARTICLEPHL', 'CONSTANTE', '', 'Classification type produit - a saisir dans /configuration/valeurs-defaut', 'migration_069')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;

INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.part_catalog', 'product_type_classif_db', 'ARTICLEPHL', 'CONSTANTE', '', 'Classification type produit - a saisir dans /configuration/valeurs-defaut', 'migration_069')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;

INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.part_catalog', 'receipt_issue_serial_track', 'ARTICLEPHL', 'CONSTANTE', 'False', 'Suivi séries à la réception et à la sortie - repris du module articleComposant', 'migration_069')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;

INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.part_catalog', 'serial_rule', 'ARTICLEPHL', 'CONSTANTE', 'Manual', 'Règle de série - repris du module articleComposant', 'migration_069')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;

INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.part_catalog', 'serial_tracking_code', 'ARTICLEPHL', 'CONSTANTE', 'Not Serial Tracking', 'Suivi des séries - repris du module articleComposant', 'migration_069')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;

INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.part_catalog', 'std_name_id', 'ARTICLEPHL', 'CONSTANTE', '0', 'Id Nom Std - repris du module articleComposant - OBLIGATOIRE cote IFS', 'migration_069')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;

INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.part_catalog', 'stop_arrival_issued_serial', 'ARTICLEPHL', 'CONSTANTE', 'True', 'Arrêt BC arrivées de numéros de série sortis - repris du module articleComposant', 'migration_069')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;

INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.part_catalog', 'stop_new_serial_in_rma', 'ARTICLEPHL', 'CONSTANTE', 'True', 'Arrêter création de nouvelles séries dans RMA - repris du module articleComposant', 'migration_069')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;

INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.part_catalog', 'sub_lot_rule', 'ARTICLEPHL', 'CONSTANTE', 'No Sub Lots Allowed', 'Règle sous-lot - repris du module articleComposant', 'migration_069')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;

INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.part_catalog', 'sup_warranty_id', 'ARTICLEPHL', 'CONSTANTE', '', 'Garantie fournisseur - a saisir dans /configuration/valeurs-defaut', 'migration_069')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;

INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.part_catalog', 'technical_drawing_no', 'ARTICLEPHL', 'CONSTANTE', '', 'N° de dessin technique - a saisir dans /configuration/valeurs-defaut', 'migration_069')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;

INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.part_catalog', 'uom_for_volume_net', 'ARTICLEPHL', 'CONSTANTE', '', 'U/M volume - a saisir dans /configuration/valeurs-defaut', 'migration_069')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;

INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.part_catalog', 'uom_for_weight_net', 'ARTICLEPHL', 'CONSTANTE', 'Kg', 'U/M poids - defaut du catalogue IFS', 'migration_069')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;

INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.part_catalog', 'volume_net', 'ARTICLEPHL', 'CONSTANTE', '', 'Volume net - a saisir dans /configuration/valeurs-defaut', 'migration_069')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;

INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.part_catalog', 'weight_net', 'ARTICLEPHL', 'CONSTANTE', '1', 'Poids net - defaut du catalogue IFS', 'migration_069')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;

INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.sales_part', 'acquisition_origin', 'ARTICLEPHL', 'CONSTANTE', '', 'Origine de l''acquisition - a saisir dans /configuration/valeurs-defaut', 'migration_069')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;

INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.sales_part', 'acquisition_reason_id', 'ARTICLEPHL', 'CONSTANTE', '', 'ID motif d''acquisition - a saisir dans /configuration/valeurs-defaut', 'migration_069')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;

INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.sales_part', 'activeind', 'ARTICLEPHL', 'CONSTANTE', 'Active part', 'Article actif - repris du module articleComposant', 'migration_069')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;

INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.sales_part', 'catalog_type', 'ARTICLEPHL', 'CONSTANTE', 'Inventory part', 'Type article de vente - repris du module articleComposant', 'migration_069')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;

INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.sales_part', 'create_sm_object_option', 'ARTICLEPHL', 'CONSTANTE', 'Do not create SM object', 'Créer un objet SMgt - repris du module articleComposant', 'migration_069')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;

INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.sales_part', 'cust_warranty_id', 'ARTICLEPHL', 'CONSTANTE', '', 'Id garantie client - a saisir dans /configuration/valeurs-defaut', 'migration_069')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;

INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.sales_part', 'date_of_replacement', 'ARTICLEPHL', 'CONSTANTE', '', 'Date remplacement - a saisir dans /configuration/valeurs-defaut', 'migration_069')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;

INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.sales_part', 'discount_group', 'ARTICLEPHL', 'CONSTANTE', '', 'Groupe de remises - a saisir dans /configuration/valeurs-defaut', 'migration_069')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;

INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.sales_part', 'eng_attribute', 'ARTICLEPHL', 'CONSTANTE', '', 'Modèle Caractéristique - a saisir dans /configuration/valeurs-defaut', 'migration_069')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;

INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.sales_part', 'export_to_external_app', 'ARTICLEPHL', 'CONSTANTE', 'False', 'Exporter vers application externe - repris du module articleComposant', 'migration_069')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;

INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.sales_part', 'hsn_sac_code', 'ARTICLEPHL', 'CONSTANTE', '', 'Code HSN/SAC - a saisir dans /configuration/valeurs-defaut', 'migration_069')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;

INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.sales_part', 'non_inv_part_type', 'ARTICLEPHL', 'CONSTANTE', 'Goods', 'Catégorie - repris du module articleComposant', 'migration_069')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;

INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.sales_part', 'note_id', 'ARTICLEPHL', 'CONSTANTE', '', 'Id note - a saisir dans /configuration/valeurs-defaut', 'migration_069')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;

INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.sales_part', 'note_text', 'ARTICLEPHL', 'CONSTANTE', '', 'Notes - a saisir dans /configuration/valeurs-defaut', 'migration_069')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;

INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.sales_part', 'primary_catalog', 'ARTICLEPHL', 'CONSTANTE', 'True', 'Article ventes principal - repris du module articleComposant', 'migration_069')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;

INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.sales_part', 'print_control_code', 'ARTICLEPHL', 'CONSTANTE', '', 'Code d''impression - a saisir dans /configuration/valeurs-defaut', 'migration_069')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;

INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.sales_part', 'purchase_part_no', 'ARTICLEPHL', 'CONSTANTE', '', 'N° article achat - a saisir dans /configuration/valeurs-defaut', 'migration_069')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;

INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.sales_part', 'quick_registered_part', 'ARTICLEPHL', 'CONSTANTE', 'False', 'Enreg. rapide d''art. - repris du module articleComposant', 'migration_069')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;

INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.sales_part', 'replacement_part_no', 'ARTICLEPHL', 'CONSTANTE', '', 'N° art. remplacement - a saisir dans /configuration/valeurs-defaut', 'migration_069')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;

INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.sales_part', 'rule_id', 'ARTICLEPHL', 'CONSTANTE', '', 'Règle d''appro. - a saisir dans /configuration/valeurs-defaut', 'migration_069')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;

INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.sales_part', 'saft_category', 'ARTICLEPHL', 'CONSTANTE', '', 'Catégorie SAF-T - a saisir dans /configuration/valeurs-defaut', 'migration_069')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;

INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.sales_part', 'saft_category_db', 'ARTICLEPHL', 'CONSTANTE', '', 'Catégorie SAF-T - a saisir dans /configuration/valeurs-defaut', 'migration_069')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;

INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.sales_part', 'sales_part_rebate_group', 'ARTICLEPHL', 'CONSTANTE', '', 'Groupe ristourne - a saisir dans /configuration/valeurs-defaut', 'migration_069')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;

INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.sales_part', 'sales_type', 'ARTICLEPHL', 'CONSTANTE', 'Sales Only', 'Type vente - repris du module articleComposant', 'migration_069')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;

INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.sales_part', 'sourcing_option', 'ARTICLEPHL', 'CONSTANTE', 'Inventory Order', 'Option appro. - repris du module articleComposant', 'migration_069')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;

INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.sales_part', 'taxable', 'ARTICLEPHL', 'CONSTANTE', 'True', 'Imposable - repris du module articleComposant', 'migration_069')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;

INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('articlePhl', 'clean_data.sales_part', 'use_price_incl_tax', 'ARTICLEPHL', 'CONSTANTE', 'False', 'Utiliser prix TTC - repris du module articleComposant', 'migration_069')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;

COMMIT;

-- Verification : 169 lignes attendues
-- SELECT count(*) FROM public.etl_default_values WHERE created_by = 'migration_069';
-- Reste a saisir :
-- SELECT table_cible, colonne, description FROM public.etl_default_values
--  WHERE created_by = 'migration_069' AND COALESCE(valeur, '') = '' ORDER BY 1, 2;
-- Colonnes obligatoires cote IFS, a traiter en priorite :
-- SELECT table_cible, colonne FROM public.etl_default_values
--  WHERE created_by = 'migration_069' AND description LIKE '%OBLIGATOIRE%' ORDER BY 1, 2;

-- ============================================================================
-- ROLLBACK
-- ============================================================================
-- DELETE FROM public.etl_default_values WHERE created_by = 'migration_069';
-- puis rejouer depuis git la version precedente des procedures alimenter_*_phl.
-- ============================================================================
