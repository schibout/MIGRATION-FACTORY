-- ============================================================================
-- 072 : articleComposant -- la matrice devient l'UNIQUE source des valeurs par defaut
--
-- DEMANDE : "les composants doivent avoir le meme comportement que les articles
-- PHL, les valeurs par defaut doivent venir exclusivement de la matrice".
-- Suite directe de la migration 071, qui a fait la meme chose pour articlePhl.
--
-- Les 5 procedures alimenter_*_cmp lisaient leurs 448 constantes dans
-- public.etl_default_values (variantes COMPOSANT, COMPOSANT_SJ, COMPOSANT_CS et
-- STANDARD). Elles n'appellent plus que public.get_matrix_value(table, colonne,
-- p_contract, famille), qui lit la SEULE public.etl_default_value_matrix.
--
-- LE POINT DELICAT -- SEPARER LES DEUX MODULES
-- 211 des 218 colonnes appelees par le composant sont AUSSI appelees par
-- articlePhl, et pour 50 d'entre elles IFS attend une valeur differente selon le
-- module (c'est la raison d'etre des variantes ARTICLEPHL vs COMPOSANT). Or la
-- matrice ne connait pas la notion de module : sa cle est
-- (table, colonne, variante, site, famille) et l'ecran n'ecrit QUE la variante
-- 'STANDARD' -- une regle posee sous une autre variante serait invisible et non
-- modifiable, tout en restant appliquee.
--
-- Le seul separateur utilisable est donc la FAMILLE, et elle s'y prete : les
-- familles des deux modules sont disjointes (PHL = 20, 21, 22, 23, 24, RF... ;
-- composant = AL, BL, CR, EB, FX, HS, MA, MP, MS, MY, RS, SC, TM). D'ou la
-- reprise ci-dessous, qui preserve exactement les valeurs actuelles :
--   *   7 colonnes propres au composant  -> regle JOKER
--   *  50 colonnes en conflit            -> une regle par famille composant (650)
--   *   6 colonnes a valeur par site     -> une regle par (site, famille) (90),
--                                           ex-variantes COMPOSANT_SJ/_CS
--   * 161 colonnes deja alignees sur la regle articlePhl -> rien
--
-- FRAGILITE A CONNAITRE : une NOUVELLE famille composant, non declaree ici,
-- heriterait sur ces 50 colonnes de la regle joker d'articlePhl. L'ecran la
-- montre comme valeur "heritee", donc c'est visible, mais il faut y penser en
-- ajoutant une famille.
--
-- Les familles MP et MY, presentes dans raw_data.composant_sj_cs mais absentes
-- du referentiel, sont declarees ici : sans cela leurs regles n'auraient aucune
-- colonne dans l'ecran.
--
-- A JOUER AVEC : cd sql/ArticleComposant && ./compile.sh
-- Rollback en bas de fichier.
-- ============================================================================

BEGIN;

-- ===========================================================================
-- 1. Familles composant manquantes au referentiel (visibilite dans l'ecran)
-- ===========================================================================
INSERT INTO public.etl_part_family (code, libelle, description, ordre, created_by, updated_by)
VALUES ('MP', NULL, 'Famille presente dans raw_data.composant_sj_cs (site CS), declaree par la migration 072 pour que ses regles soient visibles dans la matrice.', 200, 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;

INSERT INTO public.etl_part_family (code, libelle, description, ordre, created_by, updated_by)
VALUES ('MY', NULL, 'Famille presente dans raw_data.composant_sj_cs (site SJ), declaree par la migration 072 pour que ses regles soient visibles dans la matrice.', 200, 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;

-- ===========================================================================
-- 2. Reprise des constantes composant en regles de matrice
--
-- ON CONFLICT DO NOTHING : une regle deja saisie a l'ecran fait foi.
-- ===========================================================================
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.inventory_part', 'avail_activity_status', NULL, NULL, 'STANDARD', 'CONSTANTE', 'Changed', 'Composant : colonne propre au module, reprise de la constante COMPOSANT (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.inventory_part', 'oe_alloc_assign_flag', NULL, NULL, 'STANDARD', 'CONSTANTE', 'Normal reservation', 'Composant : colonne propre au module, reprise de la constante COMPOSANT (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.inventory_part', 'oe_alloc_assign_flag_db', NULL, NULL, 'STANDARD', 'CONSTANTE', 'N', 'Composant : colonne propre au module, reprise de la constante COMPOSANT (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.inventory_part', 'part_catalog_configurable', NULL, NULL, 'STANDARD', 'CONSTANTE', 'Not Configured', 'Composant : colonne propre au module, reprise de la constante COMPOSANT (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.inventory_part', 'supply_code', NULL, NULL, 'STANDARD', 'CONSTANTE', 'Inventory Order', 'Composant : colonne propre au module, reprise de la constante COMPOSANT (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.inventory_part', 'type_code', NULL, NULL, 'STANDARD', 'CONSTANTE', 'Purchased', 'Composant : colonne propre au module, reprise de la constante COMPOSANT (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.part_catalog', 'lot_quantity_rule', NULL, NULL, 'STANDARD', 'CONSTANTE', 'One Lot Per Production Order', 'Composant : colonne propre au module, reprise de la constante COMPOSANT (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.manuf_part_attribute', 'adjust_on_op_qty_deviation', NULL, 'AL', 'STANDARD', 'CONSTANTE', 'False', 'Composant famille AL : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.manuf_part_attribute', 'adjust_on_op_qty_deviation', NULL, 'BL', 'STANDARD', 'CONSTANTE', 'False', 'Composant famille BL : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.manuf_part_attribute', 'adjust_on_op_qty_deviation', NULL, 'CR', 'STANDARD', 'CONSTANTE', 'False', 'Composant famille CR : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.manuf_part_attribute', 'adjust_on_op_qty_deviation', NULL, 'EB', 'STANDARD', 'CONSTANTE', 'False', 'Composant famille EB : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.manuf_part_attribute', 'adjust_on_op_qty_deviation', NULL, 'FX', 'STANDARD', 'CONSTANTE', 'False', 'Composant famille FX : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.manuf_part_attribute', 'adjust_on_op_qty_deviation', NULL, 'HS', 'STANDARD', 'CONSTANTE', 'False', 'Composant famille HS : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.manuf_part_attribute', 'adjust_on_op_qty_deviation', NULL, 'MA', 'STANDARD', 'CONSTANTE', 'False', 'Composant famille MA : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.manuf_part_attribute', 'adjust_on_op_qty_deviation', NULL, 'MP', 'STANDARD', 'CONSTANTE', 'False', 'Composant famille MP : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.manuf_part_attribute', 'adjust_on_op_qty_deviation', NULL, 'MS', 'STANDARD', 'CONSTANTE', 'False', 'Composant famille MS : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.manuf_part_attribute', 'adjust_on_op_qty_deviation', NULL, 'MY', 'STANDARD', 'CONSTANTE', 'False', 'Composant famille MY : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.manuf_part_attribute', 'adjust_on_op_qty_deviation', NULL, 'RS', 'STANDARD', 'CONSTANTE', 'False', 'Composant famille RS : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.manuf_part_attribute', 'adjust_on_op_qty_deviation', NULL, 'SC', 'STANDARD', 'CONSTANTE', 'False', 'Composant famille SC : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.manuf_part_attribute', 'adjust_on_op_qty_deviation', NULL, 'TM', 'STANDARD', 'CONSTANTE', 'False', 'Composant famille TM : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.manuf_part_attribute', 'auto_replace_alt_comp', NULL, 'AL', 'STANDARD', 'CONSTANTE', 'False', 'Composant famille AL : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.manuf_part_attribute', 'auto_replace_alt_comp', NULL, 'BL', 'STANDARD', 'CONSTANTE', 'False', 'Composant famille BL : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.manuf_part_attribute', 'auto_replace_alt_comp', NULL, 'CR', 'STANDARD', 'CONSTANTE', 'False', 'Composant famille CR : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.manuf_part_attribute', 'auto_replace_alt_comp', NULL, 'EB', 'STANDARD', 'CONSTANTE', 'False', 'Composant famille EB : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.manuf_part_attribute', 'auto_replace_alt_comp', NULL, 'FX', 'STANDARD', 'CONSTANTE', 'False', 'Composant famille FX : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.manuf_part_attribute', 'auto_replace_alt_comp', NULL, 'HS', 'STANDARD', 'CONSTANTE', 'False', 'Composant famille HS : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.manuf_part_attribute', 'auto_replace_alt_comp', NULL, 'MA', 'STANDARD', 'CONSTANTE', 'False', 'Composant famille MA : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.manuf_part_attribute', 'auto_replace_alt_comp', NULL, 'MP', 'STANDARD', 'CONSTANTE', 'False', 'Composant famille MP : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.manuf_part_attribute', 'auto_replace_alt_comp', NULL, 'MS', 'STANDARD', 'CONSTANTE', 'False', 'Composant famille MS : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.manuf_part_attribute', 'auto_replace_alt_comp', NULL, 'MY', 'STANDARD', 'CONSTANTE', 'False', 'Composant famille MY : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.manuf_part_attribute', 'auto_replace_alt_comp', NULL, 'RS', 'STANDARD', 'CONSTANTE', 'False', 'Composant famille RS : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.manuf_part_attribute', 'auto_replace_alt_comp', NULL, 'SC', 'STANDARD', 'CONSTANTE', 'False', 'Composant famille SC : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.manuf_part_attribute', 'auto_replace_alt_comp', NULL, 'TM', 'STANDARD', 'CONSTANTE', 'False', 'Composant famille TM : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.manuf_part_attribute', 'backflush_part', NULL, 'AL', 'STANDARD', 'CONSTANTE', 'All Locations', 'Composant famille AL : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.manuf_part_attribute', 'backflush_part', NULL, 'BL', 'STANDARD', 'CONSTANTE', 'All Locations', 'Composant famille BL : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.manuf_part_attribute', 'backflush_part', NULL, 'CR', 'STANDARD', 'CONSTANTE', 'All Locations', 'Composant famille CR : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.manuf_part_attribute', 'backflush_part', NULL, 'EB', 'STANDARD', 'CONSTANTE', 'All Locations', 'Composant famille EB : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.manuf_part_attribute', 'backflush_part', NULL, 'FX', 'STANDARD', 'CONSTANTE', 'All Locations', 'Composant famille FX : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.manuf_part_attribute', 'backflush_part', NULL, 'HS', 'STANDARD', 'CONSTANTE', 'All Locations', 'Composant famille HS : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.manuf_part_attribute', 'backflush_part', NULL, 'MA', 'STANDARD', 'CONSTANTE', 'All Locations', 'Composant famille MA : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.manuf_part_attribute', 'backflush_part', NULL, 'MP', 'STANDARD', 'CONSTANTE', 'All Locations', 'Composant famille MP : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.manuf_part_attribute', 'backflush_part', NULL, 'MS', 'STANDARD', 'CONSTANTE', 'All Locations', 'Composant famille MS : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.manuf_part_attribute', 'backflush_part', NULL, 'MY', 'STANDARD', 'CONSTANTE', 'All Locations', 'Composant famille MY : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.manuf_part_attribute', 'backflush_part', NULL, 'RS', 'STANDARD', 'CONSTANTE', 'All Locations', 'Composant famille RS : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.manuf_part_attribute', 'backflush_part', NULL, 'SC', 'STANDARD', 'CONSTANTE', 'All Locations', 'Composant famille SC : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.manuf_part_attribute', 'backflush_part', NULL, 'TM', 'STANDARD', 'CONSTANTE', 'All Locations', 'Composant famille TM : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.manuf_part_attribute', 'close_tolerance', NULL, 'AL', 'STANDARD', 'CONSTANTE', '0', 'Composant famille AL : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.manuf_part_attribute', 'close_tolerance', NULL, 'BL', 'STANDARD', 'CONSTANTE', '0', 'Composant famille BL : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.manuf_part_attribute', 'close_tolerance', NULL, 'CR', 'STANDARD', 'CONSTANTE', '0', 'Composant famille CR : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.manuf_part_attribute', 'close_tolerance', NULL, 'EB', 'STANDARD', 'CONSTANTE', '0', 'Composant famille EB : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.manuf_part_attribute', 'close_tolerance', NULL, 'FX', 'STANDARD', 'CONSTANTE', '0', 'Composant famille FX : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.manuf_part_attribute', 'close_tolerance', NULL, 'HS', 'STANDARD', 'CONSTANTE', '0', 'Composant famille HS : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.manuf_part_attribute', 'close_tolerance', NULL, 'MA', 'STANDARD', 'CONSTANTE', '0', 'Composant famille MA : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.manuf_part_attribute', 'close_tolerance', NULL, 'MP', 'STANDARD', 'CONSTANTE', '0', 'Composant famille MP : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.manuf_part_attribute', 'close_tolerance', NULL, 'MS', 'STANDARD', 'CONSTANTE', '0', 'Composant famille MS : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.manuf_part_attribute', 'close_tolerance', NULL, 'MY', 'STANDARD', 'CONSTANTE', '0', 'Composant famille MY : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.manuf_part_attribute', 'close_tolerance', NULL, 'RS', 'STANDARD', 'CONSTANTE', '0', 'Composant famille RS : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.manuf_part_attribute', 'close_tolerance', NULL, 'SC', 'STANDARD', 'CONSTANTE', '0', 'Composant famille SC : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.manuf_part_attribute', 'close_tolerance', NULL, 'TM', 'STANDARD', 'CONSTANTE', '0', 'Composant famille TM : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.manuf_part_attribute', 'configuration_usage', NULL, 'AL', 'STANDARD', 'CONSTANTE', 'Common', 'Composant famille AL : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.manuf_part_attribute', 'configuration_usage', NULL, 'BL', 'STANDARD', 'CONSTANTE', 'Common', 'Composant famille BL : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.manuf_part_attribute', 'configuration_usage', NULL, 'CR', 'STANDARD', 'CONSTANTE', 'Common', 'Composant famille CR : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.manuf_part_attribute', 'configuration_usage', NULL, 'EB', 'STANDARD', 'CONSTANTE', 'Common', 'Composant famille EB : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.manuf_part_attribute', 'configuration_usage', NULL, 'FX', 'STANDARD', 'CONSTANTE', 'Common', 'Composant famille FX : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.manuf_part_attribute', 'configuration_usage', NULL, 'HS', 'STANDARD', 'CONSTANTE', 'Common', 'Composant famille HS : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.manuf_part_attribute', 'configuration_usage', NULL, 'MA', 'STANDARD', 'CONSTANTE', 'Common', 'Composant famille MA : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.manuf_part_attribute', 'configuration_usage', NULL, 'MP', 'STANDARD', 'CONSTANTE', 'Common', 'Composant famille MP : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.manuf_part_attribute', 'configuration_usage', NULL, 'MS', 'STANDARD', 'CONSTANTE', 'Common', 'Composant famille MS : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.manuf_part_attribute', 'configuration_usage', NULL, 'MY', 'STANDARD', 'CONSTANTE', 'Common', 'Composant famille MY : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.manuf_part_attribute', 'configuration_usage', NULL, 'RS', 'STANDARD', 'CONSTANTE', 'Common', 'Composant famille RS : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.manuf_part_attribute', 'configuration_usage', NULL, 'SC', 'STANDARD', 'CONSTANTE', 'Common', 'Composant famille SC : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.manuf_part_attribute', 'configuration_usage', NULL, 'TM', 'STANDARD', 'CONSTANTE', 'Common', 'Composant famille TM : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.manuf_part_attribute', 'consider_lead_time', NULL, 'AL', 'STANDARD', 'CONSTANTE', 'True', 'Composant famille AL : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.manuf_part_attribute', 'consider_lead_time', NULL, 'BL', 'STANDARD', 'CONSTANTE', 'True', 'Composant famille BL : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.manuf_part_attribute', 'consider_lead_time', NULL, 'CR', 'STANDARD', 'CONSTANTE', 'True', 'Composant famille CR : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.manuf_part_attribute', 'consider_lead_time', NULL, 'EB', 'STANDARD', 'CONSTANTE', 'True', 'Composant famille EB : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.manuf_part_attribute', 'consider_lead_time', NULL, 'FX', 'STANDARD', 'CONSTANTE', 'True', 'Composant famille FX : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.manuf_part_attribute', 'consider_lead_time', NULL, 'HS', 'STANDARD', 'CONSTANTE', 'True', 'Composant famille HS : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.manuf_part_attribute', 'consider_lead_time', NULL, 'MA', 'STANDARD', 'CONSTANTE', 'True', 'Composant famille MA : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.manuf_part_attribute', 'consider_lead_time', NULL, 'MP', 'STANDARD', 'CONSTANTE', 'True', 'Composant famille MP : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.manuf_part_attribute', 'consider_lead_time', NULL, 'MS', 'STANDARD', 'CONSTANTE', 'True', 'Composant famille MS : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.manuf_part_attribute', 'consider_lead_time', NULL, 'MY', 'STANDARD', 'CONSTANTE', 'True', 'Composant famille MY : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.manuf_part_attribute', 'consider_lead_time', NULL, 'RS', 'STANDARD', 'CONSTANTE', 'True', 'Composant famille RS : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.manuf_part_attribute', 'consider_lead_time', NULL, 'SC', 'STANDARD', 'CONSTANTE', 'True', 'Composant famille SC : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.manuf_part_attribute', 'consider_lead_time', NULL, 'TM', 'STANDARD', 'CONSTANTE', 'True', 'Composant famille TM : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.manuf_part_attribute', 'dop_pegged_so_update_flag', NULL, 'AL', 'STANDARD', 'CONSTANTE', 'Planned', 'Composant famille AL : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.manuf_part_attribute', 'dop_pegged_so_update_flag', NULL, 'BL', 'STANDARD', 'CONSTANTE', 'Planned', 'Composant famille BL : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.manuf_part_attribute', 'dop_pegged_so_update_flag', NULL, 'CR', 'STANDARD', 'CONSTANTE', 'Planned', 'Composant famille CR : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.manuf_part_attribute', 'dop_pegged_so_update_flag', NULL, 'EB', 'STANDARD', 'CONSTANTE', 'Planned', 'Composant famille EB : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.manuf_part_attribute', 'dop_pegged_so_update_flag', NULL, 'FX', 'STANDARD', 'CONSTANTE', 'Planned', 'Composant famille FX : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.manuf_part_attribute', 'dop_pegged_so_update_flag', NULL, 'HS', 'STANDARD', 'CONSTANTE', 'Planned', 'Composant famille HS : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.manuf_part_attribute', 'dop_pegged_so_update_flag', NULL, 'MA', 'STANDARD', 'CONSTANTE', 'Planned', 'Composant famille MA : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.manuf_part_attribute', 'dop_pegged_so_update_flag', NULL, 'MP', 'STANDARD', 'CONSTANTE', 'Planned', 'Composant famille MP : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.manuf_part_attribute', 'dop_pegged_so_update_flag', NULL, 'MS', 'STANDARD', 'CONSTANTE', 'Planned', 'Composant famille MS : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.manuf_part_attribute', 'dop_pegged_so_update_flag', NULL, 'MY', 'STANDARD', 'CONSTANTE', 'Planned', 'Composant famille MY : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.manuf_part_attribute', 'dop_pegged_so_update_flag', NULL, 'RS', 'STANDARD', 'CONSTANTE', 'Planned', 'Composant famille RS : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.manuf_part_attribute', 'dop_pegged_so_update_flag', NULL, 'SC', 'STANDARD', 'CONSTANTE', 'Planned', 'Composant famille SC : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.manuf_part_attribute', 'dop_pegged_so_update_flag', NULL, 'TM', 'STANDARD', 'CONSTANTE', 'Planned', 'Composant famille TM : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.manuf_part_attribute', 'engineering_info', NULL, 'AL', 'STANDARD', 'CONSTANTE', 'Not Mandatory', 'Composant famille AL : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.manuf_part_attribute', 'engineering_info', NULL, 'BL', 'STANDARD', 'CONSTANTE', 'Not Mandatory', 'Composant famille BL : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.manuf_part_attribute', 'engineering_info', NULL, 'CR', 'STANDARD', 'CONSTANTE', 'Not Mandatory', 'Composant famille CR : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.manuf_part_attribute', 'engineering_info', NULL, 'EB', 'STANDARD', 'CONSTANTE', 'Not Mandatory', 'Composant famille EB : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.manuf_part_attribute', 'engineering_info', NULL, 'FX', 'STANDARD', 'CONSTANTE', 'Not Mandatory', 'Composant famille FX : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.manuf_part_attribute', 'engineering_info', NULL, 'HS', 'STANDARD', 'CONSTANTE', 'Not Mandatory', 'Composant famille HS : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.manuf_part_attribute', 'engineering_info', NULL, 'MA', 'STANDARD', 'CONSTANTE', 'Not Mandatory', 'Composant famille MA : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.manuf_part_attribute', 'engineering_info', NULL, 'MP', 'STANDARD', 'CONSTANTE', 'Not Mandatory', 'Composant famille MP : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.manuf_part_attribute', 'engineering_info', NULL, 'MS', 'STANDARD', 'CONSTANTE', 'Not Mandatory', 'Composant famille MS : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.manuf_part_attribute', 'engineering_info', NULL, 'MY', 'STANDARD', 'CONSTANTE', 'Not Mandatory', 'Composant famille MY : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.manuf_part_attribute', 'engineering_info', NULL, 'RS', 'STANDARD', 'CONSTANTE', 'Not Mandatory', 'Composant famille RS : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.manuf_part_attribute', 'engineering_info', NULL, 'SC', 'STANDARD', 'CONSTANTE', 'Not Mandatory', 'Composant famille SC : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.manuf_part_attribute', 'engineering_info', NULL, 'TM', 'STANDARD', 'CONSTANTE', 'Not Mandatory', 'Composant famille TM : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.manuf_part_attribute', 'issue_overreported_qty', NULL, 'AL', 'STANDARD', 'CONSTANTE', 'False', 'Composant famille AL : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.manuf_part_attribute', 'issue_overreported_qty', NULL, 'BL', 'STANDARD', 'CONSTANTE', 'False', 'Composant famille BL : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.manuf_part_attribute', 'issue_overreported_qty', NULL, 'CR', 'STANDARD', 'CONSTANTE', 'False', 'Composant famille CR : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.manuf_part_attribute', 'issue_overreported_qty', NULL, 'EB', 'STANDARD', 'CONSTANTE', 'False', 'Composant famille EB : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.manuf_part_attribute', 'issue_overreported_qty', NULL, 'FX', 'STANDARD', 'CONSTANTE', 'False', 'Composant famille FX : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.manuf_part_attribute', 'issue_overreported_qty', NULL, 'HS', 'STANDARD', 'CONSTANTE', 'False', 'Composant famille HS : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.manuf_part_attribute', 'issue_overreported_qty', NULL, 'MA', 'STANDARD', 'CONSTANTE', 'False', 'Composant famille MA : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.manuf_part_attribute', 'issue_overreported_qty', NULL, 'MP', 'STANDARD', 'CONSTANTE', 'False', 'Composant famille MP : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.manuf_part_attribute', 'issue_overreported_qty', NULL, 'MS', 'STANDARD', 'CONSTANTE', 'False', 'Composant famille MS : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.manuf_part_attribute', 'issue_overreported_qty', NULL, 'MY', 'STANDARD', 'CONSTANTE', 'False', 'Composant famille MY : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.manuf_part_attribute', 'issue_overreported_qty', NULL, 'RS', 'STANDARD', 'CONSTANTE', 'False', 'Composant famille RS : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.manuf_part_attribute', 'issue_overreported_qty', NULL, 'SC', 'STANDARD', 'CONSTANTE', 'False', 'Composant famille SC : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.manuf_part_attribute', 'issue_overreported_qty', NULL, 'TM', 'STANDARD', 'CONSTANTE', 'False', 'Composant famille TM : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.manuf_part_attribute', 'issue_planned_scrap', NULL, 'AL', 'STANDARD', 'CONSTANTE', 'True', 'Composant famille AL : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.manuf_part_attribute', 'issue_planned_scrap', NULL, 'BL', 'STANDARD', 'CONSTANTE', 'True', 'Composant famille BL : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.manuf_part_attribute', 'issue_planned_scrap', NULL, 'CR', 'STANDARD', 'CONSTANTE', 'True', 'Composant famille CR : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.manuf_part_attribute', 'issue_planned_scrap', NULL, 'EB', 'STANDARD', 'CONSTANTE', 'True', 'Composant famille EB : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.manuf_part_attribute', 'issue_planned_scrap', NULL, 'FX', 'STANDARD', 'CONSTANTE', 'True', 'Composant famille FX : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.manuf_part_attribute', 'issue_planned_scrap', NULL, 'HS', 'STANDARD', 'CONSTANTE', 'True', 'Composant famille HS : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.manuf_part_attribute', 'issue_planned_scrap', NULL, 'MA', 'STANDARD', 'CONSTANTE', 'True', 'Composant famille MA : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.manuf_part_attribute', 'issue_planned_scrap', NULL, 'MP', 'STANDARD', 'CONSTANTE', 'True', 'Composant famille MP : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.manuf_part_attribute', 'issue_planned_scrap', NULL, 'MS', 'STANDARD', 'CONSTANTE', 'True', 'Composant famille MS : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.manuf_part_attribute', 'issue_planned_scrap', NULL, 'MY', 'STANDARD', 'CONSTANTE', 'True', 'Composant famille MY : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.manuf_part_attribute', 'issue_planned_scrap', NULL, 'RS', 'STANDARD', 'CONSTANTE', 'True', 'Composant famille RS : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.manuf_part_attribute', 'issue_planned_scrap', NULL, 'SC', 'STANDARD', 'CONSTANTE', 'True', 'Composant famille SC : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.manuf_part_attribute', 'issue_planned_scrap', NULL, 'TM', 'STANDARD', 'CONSTANTE', 'True', 'Composant famille TM : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.manuf_part_attribute', 'issue_type', NULL, 'AL', 'STANDARD', 'CONSTANTE', 'Reserve And Backflush', 'Composant famille AL : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.manuf_part_attribute', 'issue_type', NULL, 'BL', 'STANDARD', 'CONSTANTE', 'Reserve And Backflush', 'Composant famille BL : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.manuf_part_attribute', 'issue_type', NULL, 'CR', 'STANDARD', 'CONSTANTE', 'Reserve And Backflush', 'Composant famille CR : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.manuf_part_attribute', 'issue_type', NULL, 'EB', 'STANDARD', 'CONSTANTE', 'Reserve And Backflush', 'Composant famille EB : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.manuf_part_attribute', 'issue_type', NULL, 'FX', 'STANDARD', 'CONSTANTE', 'Reserve And Backflush', 'Composant famille FX : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.manuf_part_attribute', 'issue_type', NULL, 'HS', 'STANDARD', 'CONSTANTE', 'Reserve And Backflush', 'Composant famille HS : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.manuf_part_attribute', 'issue_type', NULL, 'MA', 'STANDARD', 'CONSTANTE', 'Reserve And Backflush', 'Composant famille MA : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.manuf_part_attribute', 'issue_type', NULL, 'MP', 'STANDARD', 'CONSTANTE', 'Reserve And Backflush', 'Composant famille MP : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.manuf_part_attribute', 'issue_type', NULL, 'MS', 'STANDARD', 'CONSTANTE', 'Reserve And Backflush', 'Composant famille MS : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.manuf_part_attribute', 'issue_type', NULL, 'MY', 'STANDARD', 'CONSTANTE', 'Reserve And Backflush', 'Composant famille MY : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.manuf_part_attribute', 'issue_type', NULL, 'RS', 'STANDARD', 'CONSTANTE', 'Reserve And Backflush', 'Composant famille RS : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.manuf_part_attribute', 'issue_type', NULL, 'SC', 'STANDARD', 'CONSTANTE', 'Reserve And Backflush', 'Composant famille SC : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.manuf_part_attribute', 'issue_type', NULL, 'TM', 'STANDARD', 'CONSTANTE', 'Reserve And Backflush', 'Composant famille TM : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.manuf_part_attribute', 'issue_type_db', NULL, 'AL', 'STANDARD', 'CONSTANTE', 'RESERVE_AND_BACKFLUSH', 'Composant famille AL : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.manuf_part_attribute', 'issue_type_db', NULL, 'BL', 'STANDARD', 'CONSTANTE', 'RESERVE_AND_BACKFLUSH', 'Composant famille BL : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.manuf_part_attribute', 'issue_type_db', NULL, 'CR', 'STANDARD', 'CONSTANTE', 'RESERVE_AND_BACKFLUSH', 'Composant famille CR : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.manuf_part_attribute', 'issue_type_db', NULL, 'EB', 'STANDARD', 'CONSTANTE', 'RESERVE_AND_BACKFLUSH', 'Composant famille EB : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.manuf_part_attribute', 'issue_type_db', NULL, 'FX', 'STANDARD', 'CONSTANTE', 'RESERVE_AND_BACKFLUSH', 'Composant famille FX : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.manuf_part_attribute', 'issue_type_db', NULL, 'HS', 'STANDARD', 'CONSTANTE', 'RESERVE_AND_BACKFLUSH', 'Composant famille HS : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.manuf_part_attribute', 'issue_type_db', NULL, 'MA', 'STANDARD', 'CONSTANTE', 'RESERVE_AND_BACKFLUSH', 'Composant famille MA : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.manuf_part_attribute', 'issue_type_db', NULL, 'MP', 'STANDARD', 'CONSTANTE', 'RESERVE_AND_BACKFLUSH', 'Composant famille MP : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.manuf_part_attribute', 'issue_type_db', NULL, 'MS', 'STANDARD', 'CONSTANTE', 'RESERVE_AND_BACKFLUSH', 'Composant famille MS : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.manuf_part_attribute', 'issue_type_db', NULL, 'MY', 'STANDARD', 'CONSTANTE', 'RESERVE_AND_BACKFLUSH', 'Composant famille MY : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.manuf_part_attribute', 'issue_type_db', NULL, 'RS', 'STANDARD', 'CONSTANTE', 'RESERVE_AND_BACKFLUSH', 'Composant famille RS : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.manuf_part_attribute', 'issue_type_db', NULL, 'SC', 'STANDARD', 'CONSTANTE', 'RESERVE_AND_BACKFLUSH', 'Composant famille SC : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.manuf_part_attribute', 'issue_type_db', NULL, 'TM', 'STANDARD', 'CONSTANTE', 'RESERVE_AND_BACKFLUSH', 'Composant famille TM : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.manuf_part_attribute', 'mrp_control_flag', NULL, 'AL', 'STANDARD', 'CONSTANTE', 'True', 'Composant famille AL : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.manuf_part_attribute', 'mrp_control_flag', NULL, 'BL', 'STANDARD', 'CONSTANTE', 'True', 'Composant famille BL : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.manuf_part_attribute', 'mrp_control_flag', NULL, 'CR', 'STANDARD', 'CONSTANTE', 'True', 'Composant famille CR : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.manuf_part_attribute', 'mrp_control_flag', NULL, 'EB', 'STANDARD', 'CONSTANTE', 'True', 'Composant famille EB : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.manuf_part_attribute', 'mrp_control_flag', NULL, 'FX', 'STANDARD', 'CONSTANTE', 'True', 'Composant famille FX : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.manuf_part_attribute', 'mrp_control_flag', NULL, 'HS', 'STANDARD', 'CONSTANTE', 'True', 'Composant famille HS : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.manuf_part_attribute', 'mrp_control_flag', NULL, 'MA', 'STANDARD', 'CONSTANTE', 'True', 'Composant famille MA : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.manuf_part_attribute', 'mrp_control_flag', NULL, 'MP', 'STANDARD', 'CONSTANTE', 'True', 'Composant famille MP : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.manuf_part_attribute', 'mrp_control_flag', NULL, 'MS', 'STANDARD', 'CONSTANTE', 'True', 'Composant famille MS : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.manuf_part_attribute', 'mrp_control_flag', NULL, 'MY', 'STANDARD', 'CONSTANTE', 'True', 'Composant famille MY : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.manuf_part_attribute', 'mrp_control_flag', NULL, 'RS', 'STANDARD', 'CONSTANTE', 'True', 'Composant famille RS : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.manuf_part_attribute', 'mrp_control_flag', NULL, 'SC', 'STANDARD', 'CONSTANTE', 'True', 'Composant famille SC : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.manuf_part_attribute', 'mrp_control_flag', NULL, 'TM', 'STANDARD', 'CONSTANTE', 'True', 'Composant famille TM : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.manuf_part_attribute', 'over_reporting', NULL, 'AL', 'STANDARD', 'CONSTANTE', 'Allowed', 'Composant famille AL : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.manuf_part_attribute', 'over_reporting', NULL, 'BL', 'STANDARD', 'CONSTANTE', 'Allowed', 'Composant famille BL : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.manuf_part_attribute', 'over_reporting', NULL, 'CR', 'STANDARD', 'CONSTANTE', 'Allowed', 'Composant famille CR : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.manuf_part_attribute', 'over_reporting', NULL, 'EB', 'STANDARD', 'CONSTANTE', 'Allowed', 'Composant famille EB : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.manuf_part_attribute', 'over_reporting', NULL, 'FX', 'STANDARD', 'CONSTANTE', 'Allowed', 'Composant famille FX : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.manuf_part_attribute', 'over_reporting', NULL, 'HS', 'STANDARD', 'CONSTANTE', 'Allowed', 'Composant famille HS : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.manuf_part_attribute', 'over_reporting', NULL, 'MA', 'STANDARD', 'CONSTANTE', 'Allowed', 'Composant famille MA : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.manuf_part_attribute', 'over_reporting', NULL, 'MP', 'STANDARD', 'CONSTANTE', 'Allowed', 'Composant famille MP : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.manuf_part_attribute', 'over_reporting', NULL, 'MS', 'STANDARD', 'CONSTANTE', 'Allowed', 'Composant famille MS : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.manuf_part_attribute', 'over_reporting', NULL, 'MY', 'STANDARD', 'CONSTANTE', 'Allowed', 'Composant famille MY : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.manuf_part_attribute', 'over_reporting', NULL, 'RS', 'STANDARD', 'CONSTANTE', 'Allowed', 'Composant famille RS : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.manuf_part_attribute', 'over_reporting', NULL, 'SC', 'STANDARD', 'CONSTANTE', 'Allowed', 'Composant famille SC : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.manuf_part_attribute', 'over_reporting', NULL, 'TM', 'STANDARD', 'CONSTANTE', 'Allowed', 'Composant famille TM : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.manuf_part_attribute', 'overhaul_scrap_rule', NULL, 'AL', 'STANDARD', 'CONSTANTE', 'Direct Scrap', 'Composant famille AL : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.manuf_part_attribute', 'overhaul_scrap_rule', NULL, 'BL', 'STANDARD', 'CONSTANTE', 'Direct Scrap', 'Composant famille BL : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.manuf_part_attribute', 'overhaul_scrap_rule', NULL, 'CR', 'STANDARD', 'CONSTANTE', 'Direct Scrap', 'Composant famille CR : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.manuf_part_attribute', 'overhaul_scrap_rule', NULL, 'EB', 'STANDARD', 'CONSTANTE', 'Direct Scrap', 'Composant famille EB : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.manuf_part_attribute', 'overhaul_scrap_rule', NULL, 'FX', 'STANDARD', 'CONSTANTE', 'Direct Scrap', 'Composant famille FX : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.manuf_part_attribute', 'overhaul_scrap_rule', NULL, 'HS', 'STANDARD', 'CONSTANTE', 'Direct Scrap', 'Composant famille HS : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.manuf_part_attribute', 'overhaul_scrap_rule', NULL, 'MA', 'STANDARD', 'CONSTANTE', 'Direct Scrap', 'Composant famille MA : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.manuf_part_attribute', 'overhaul_scrap_rule', NULL, 'MP', 'STANDARD', 'CONSTANTE', 'Direct Scrap', 'Composant famille MP : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.manuf_part_attribute', 'overhaul_scrap_rule', NULL, 'MS', 'STANDARD', 'CONSTANTE', 'Direct Scrap', 'Composant famille MS : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.manuf_part_attribute', 'overhaul_scrap_rule', NULL, 'MY', 'STANDARD', 'CONSTANTE', 'Direct Scrap', 'Composant famille MY : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.manuf_part_attribute', 'overhaul_scrap_rule', NULL, 'RS', 'STANDARD', 'CONSTANTE', 'Direct Scrap', 'Composant famille RS : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.manuf_part_attribute', 'overhaul_scrap_rule', NULL, 'SC', 'STANDARD', 'CONSTANTE', 'Direct Scrap', 'Composant famille SC : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.manuf_part_attribute', 'overhaul_scrap_rule', NULL, 'TM', 'STANDARD', 'CONSTANTE', 'Direct Scrap', 'Composant famille TM : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.manuf_part_attribute', 'overhaul_scrap_rule_db', NULL, 'AL', 'STANDARD', 'CONSTANTE', 'DIRECT', 'Composant famille AL : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.manuf_part_attribute', 'overhaul_scrap_rule_db', NULL, 'BL', 'STANDARD', 'CONSTANTE', 'DIRECT', 'Composant famille BL : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.manuf_part_attribute', 'overhaul_scrap_rule_db', NULL, 'CR', 'STANDARD', 'CONSTANTE', 'DIRECT', 'Composant famille CR : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.manuf_part_attribute', 'overhaul_scrap_rule_db', NULL, 'EB', 'STANDARD', 'CONSTANTE', 'DIRECT', 'Composant famille EB : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.manuf_part_attribute', 'overhaul_scrap_rule_db', NULL, 'FX', 'STANDARD', 'CONSTANTE', 'DIRECT', 'Composant famille FX : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.manuf_part_attribute', 'overhaul_scrap_rule_db', NULL, 'HS', 'STANDARD', 'CONSTANTE', 'DIRECT', 'Composant famille HS : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.manuf_part_attribute', 'overhaul_scrap_rule_db', NULL, 'MA', 'STANDARD', 'CONSTANTE', 'DIRECT', 'Composant famille MA : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.manuf_part_attribute', 'overhaul_scrap_rule_db', NULL, 'MP', 'STANDARD', 'CONSTANTE', 'DIRECT', 'Composant famille MP : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.manuf_part_attribute', 'overhaul_scrap_rule_db', NULL, 'MS', 'STANDARD', 'CONSTANTE', 'DIRECT', 'Composant famille MS : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.manuf_part_attribute', 'overhaul_scrap_rule_db', NULL, 'MY', 'STANDARD', 'CONSTANTE', 'DIRECT', 'Composant famille MY : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.manuf_part_attribute', 'overhaul_scrap_rule_db', NULL, 'RS', 'STANDARD', 'CONSTANTE', 'DIRECT', 'Composant famille RS : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.manuf_part_attribute', 'overhaul_scrap_rule_db', NULL, 'SC', 'STANDARD', 'CONSTANTE', 'DIRECT', 'Composant famille SC : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.manuf_part_attribute', 'overhaul_scrap_rule_db', NULL, 'TM', 'STANDARD', 'CONSTANTE', 'DIRECT', 'Composant famille TM : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.manuf_part_attribute', 'plan_manuf_sup_on_due_date', NULL, 'AL', 'STANDARD', 'CONSTANTE', 'False', 'Composant famille AL : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.manuf_part_attribute', 'plan_manuf_sup_on_due_date', NULL, 'BL', 'STANDARD', 'CONSTANTE', 'False', 'Composant famille BL : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.manuf_part_attribute', 'plan_manuf_sup_on_due_date', NULL, 'CR', 'STANDARD', 'CONSTANTE', 'False', 'Composant famille CR : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.manuf_part_attribute', 'plan_manuf_sup_on_due_date', NULL, 'EB', 'STANDARD', 'CONSTANTE', 'False', 'Composant famille EB : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.manuf_part_attribute', 'plan_manuf_sup_on_due_date', NULL, 'FX', 'STANDARD', 'CONSTANTE', 'False', 'Composant famille FX : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.manuf_part_attribute', 'plan_manuf_sup_on_due_date', NULL, 'HS', 'STANDARD', 'CONSTANTE', 'False', 'Composant famille HS : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.manuf_part_attribute', 'plan_manuf_sup_on_due_date', NULL, 'MA', 'STANDARD', 'CONSTANTE', 'False', 'Composant famille MA : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.manuf_part_attribute', 'plan_manuf_sup_on_due_date', NULL, 'MP', 'STANDARD', 'CONSTANTE', 'False', 'Composant famille MP : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.manuf_part_attribute', 'plan_manuf_sup_on_due_date', NULL, 'MS', 'STANDARD', 'CONSTANTE', 'False', 'Composant famille MS : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.manuf_part_attribute', 'plan_manuf_sup_on_due_date', NULL, 'MY', 'STANDARD', 'CONSTANTE', 'False', 'Composant famille MY : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.manuf_part_attribute', 'plan_manuf_sup_on_due_date', NULL, 'RS', 'STANDARD', 'CONSTANTE', 'False', 'Composant famille RS : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.manuf_part_attribute', 'plan_manuf_sup_on_due_date', NULL, 'SC', 'STANDARD', 'CONSTANTE', 'False', 'Composant famille SC : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.manuf_part_attribute', 'plan_manuf_sup_on_due_date', NULL, 'TM', 'STANDARD', 'CONSTANTE', 'False', 'Composant famille TM : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.manuf_part_attribute', 'plan_manuf_sup_on_due_date_db', NULL, 'AL', 'STANDARD', 'CONSTANTE', 'FALSE', 'Composant famille AL : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.manuf_part_attribute', 'plan_manuf_sup_on_due_date_db', NULL, 'BL', 'STANDARD', 'CONSTANTE', 'FALSE', 'Composant famille BL : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.manuf_part_attribute', 'plan_manuf_sup_on_due_date_db', NULL, 'CR', 'STANDARD', 'CONSTANTE', 'FALSE', 'Composant famille CR : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.manuf_part_attribute', 'plan_manuf_sup_on_due_date_db', NULL, 'EB', 'STANDARD', 'CONSTANTE', 'FALSE', 'Composant famille EB : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.manuf_part_attribute', 'plan_manuf_sup_on_due_date_db', NULL, 'FX', 'STANDARD', 'CONSTANTE', 'FALSE', 'Composant famille FX : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.manuf_part_attribute', 'plan_manuf_sup_on_due_date_db', NULL, 'HS', 'STANDARD', 'CONSTANTE', 'FALSE', 'Composant famille HS : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.manuf_part_attribute', 'plan_manuf_sup_on_due_date_db', NULL, 'MA', 'STANDARD', 'CONSTANTE', 'FALSE', 'Composant famille MA : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.manuf_part_attribute', 'plan_manuf_sup_on_due_date_db', NULL, 'MP', 'STANDARD', 'CONSTANTE', 'FALSE', 'Composant famille MP : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.manuf_part_attribute', 'plan_manuf_sup_on_due_date_db', NULL, 'MS', 'STANDARD', 'CONSTANTE', 'FALSE', 'Composant famille MS : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.manuf_part_attribute', 'plan_manuf_sup_on_due_date_db', NULL, 'MY', 'STANDARD', 'CONSTANTE', 'FALSE', 'Composant famille MY : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.manuf_part_attribute', 'plan_manuf_sup_on_due_date_db', NULL, 'RS', 'STANDARD', 'CONSTANTE', 'FALSE', 'Composant famille RS : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.manuf_part_attribute', 'plan_manuf_sup_on_due_date_db', NULL, 'SC', 'STANDARD', 'CONSTANTE', 'FALSE', 'Composant famille SC : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.manuf_part_attribute', 'plan_manuf_sup_on_due_date_db', NULL, 'TM', 'STANDARD', 'CONSTANTE', 'FALSE', 'Composant famille TM : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.manuf_part_attribute', 'prod_part_as_supply_in_mrp', NULL, 'AL', 'STANDARD', 'CONSTANTE', 'True', 'Composant famille AL : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.manuf_part_attribute', 'prod_part_as_supply_in_mrp', NULL, 'BL', 'STANDARD', 'CONSTANTE', 'True', 'Composant famille BL : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.manuf_part_attribute', 'prod_part_as_supply_in_mrp', NULL, 'CR', 'STANDARD', 'CONSTANTE', 'True', 'Composant famille CR : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.manuf_part_attribute', 'prod_part_as_supply_in_mrp', NULL, 'EB', 'STANDARD', 'CONSTANTE', 'True', 'Composant famille EB : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.manuf_part_attribute', 'prod_part_as_supply_in_mrp', NULL, 'FX', 'STANDARD', 'CONSTANTE', 'True', 'Composant famille FX : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.manuf_part_attribute', 'prod_part_as_supply_in_mrp', NULL, 'HS', 'STANDARD', 'CONSTANTE', 'True', 'Composant famille HS : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.manuf_part_attribute', 'prod_part_as_supply_in_mrp', NULL, 'MA', 'STANDARD', 'CONSTANTE', 'True', 'Composant famille MA : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.manuf_part_attribute', 'prod_part_as_supply_in_mrp', NULL, 'MP', 'STANDARD', 'CONSTANTE', 'True', 'Composant famille MP : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.manuf_part_attribute', 'prod_part_as_supply_in_mrp', NULL, 'MS', 'STANDARD', 'CONSTANTE', 'True', 'Composant famille MS : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.manuf_part_attribute', 'prod_part_as_supply_in_mrp', NULL, 'MY', 'STANDARD', 'CONSTANTE', 'True', 'Composant famille MY : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.manuf_part_attribute', 'prod_part_as_supply_in_mrp', NULL, 'RS', 'STANDARD', 'CONSTANTE', 'True', 'Composant famille RS : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.manuf_part_attribute', 'prod_part_as_supply_in_mrp', NULL, 'SC', 'STANDARD', 'CONSTANTE', 'True', 'Composant famille SC : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.manuf_part_attribute', 'prod_part_as_supply_in_mrp', NULL, 'TM', 'STANDARD', 'CONSTANTE', 'True', 'Composant famille TM : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.manuf_part_attribute', 'prod_part_as_supply_in_mrp_db', NULL, 'AL', 'STANDARD', 'CONSTANTE', 'TRUE', 'Composant famille AL : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.manuf_part_attribute', 'prod_part_as_supply_in_mrp_db', NULL, 'BL', 'STANDARD', 'CONSTANTE', 'TRUE', 'Composant famille BL : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.manuf_part_attribute', 'prod_part_as_supply_in_mrp_db', NULL, 'CR', 'STANDARD', 'CONSTANTE', 'TRUE', 'Composant famille CR : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.manuf_part_attribute', 'prod_part_as_supply_in_mrp_db', NULL, 'EB', 'STANDARD', 'CONSTANTE', 'TRUE', 'Composant famille EB : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.manuf_part_attribute', 'prod_part_as_supply_in_mrp_db', NULL, 'FX', 'STANDARD', 'CONSTANTE', 'TRUE', 'Composant famille FX : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.manuf_part_attribute', 'prod_part_as_supply_in_mrp_db', NULL, 'HS', 'STANDARD', 'CONSTANTE', 'TRUE', 'Composant famille HS : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.manuf_part_attribute', 'prod_part_as_supply_in_mrp_db', NULL, 'MA', 'STANDARD', 'CONSTANTE', 'TRUE', 'Composant famille MA : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.manuf_part_attribute', 'prod_part_as_supply_in_mrp_db', NULL, 'MP', 'STANDARD', 'CONSTANTE', 'TRUE', 'Composant famille MP : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.manuf_part_attribute', 'prod_part_as_supply_in_mrp_db', NULL, 'MS', 'STANDARD', 'CONSTANTE', 'TRUE', 'Composant famille MS : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.manuf_part_attribute', 'prod_part_as_supply_in_mrp_db', NULL, 'MY', 'STANDARD', 'CONSTANTE', 'TRUE', 'Composant famille MY : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.manuf_part_attribute', 'prod_part_as_supply_in_mrp_db', NULL, 'RS', 'STANDARD', 'CONSTANTE', 'TRUE', 'Composant famille RS : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.manuf_part_attribute', 'prod_part_as_supply_in_mrp_db', NULL, 'SC', 'STANDARD', 'CONSTANTE', 'TRUE', 'Composant famille SC : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.manuf_part_attribute', 'prod_part_as_supply_in_mrp_db', NULL, 'TM', 'STANDARD', 'CONSTANTE', 'TRUE', 'Composant famille TM : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.manuf_part_attribute', 'promise_planned', NULL, 'AL', 'STANDARD', 'CONSTANTE', 'Promised', 'Composant famille AL : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.manuf_part_attribute', 'promise_planned', NULL, 'BL', 'STANDARD', 'CONSTANTE', 'Promised', 'Composant famille BL : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.manuf_part_attribute', 'promise_planned', NULL, 'CR', 'STANDARD', 'CONSTANTE', 'Promised', 'Composant famille CR : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.manuf_part_attribute', 'promise_planned', NULL, 'EB', 'STANDARD', 'CONSTANTE', 'Promised', 'Composant famille EB : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.manuf_part_attribute', 'promise_planned', NULL, 'FX', 'STANDARD', 'CONSTANTE', 'Promised', 'Composant famille FX : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.manuf_part_attribute', 'promise_planned', NULL, 'HS', 'STANDARD', 'CONSTANTE', 'Promised', 'Composant famille HS : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.manuf_part_attribute', 'promise_planned', NULL, 'MA', 'STANDARD', 'CONSTANTE', 'Promised', 'Composant famille MA : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.manuf_part_attribute', 'promise_planned', NULL, 'MP', 'STANDARD', 'CONSTANTE', 'Promised', 'Composant famille MP : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.manuf_part_attribute', 'promise_planned', NULL, 'MS', 'STANDARD', 'CONSTANTE', 'Promised', 'Composant famille MS : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.manuf_part_attribute', 'promise_planned', NULL, 'MY', 'STANDARD', 'CONSTANTE', 'Promised', 'Composant famille MY : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.manuf_part_attribute', 'promise_planned', NULL, 'RS', 'STANDARD', 'CONSTANTE', 'Promised', 'Composant famille RS : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.manuf_part_attribute', 'promise_planned', NULL, 'SC', 'STANDARD', 'CONSTANTE', 'Promised', 'Composant famille SC : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.manuf_part_attribute', 'promise_planned', NULL, 'TM', 'STANDARD', 'CONSTANTE', 'Promised', 'Composant famille TM : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.manuf_part_attribute', 'routing_effectivity', NULL, 'AL', 'STANDARD', 'CONSTANTE', 'Date', 'Composant famille AL : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.manuf_part_attribute', 'routing_effectivity', NULL, 'BL', 'STANDARD', 'CONSTANTE', 'Date', 'Composant famille BL : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.manuf_part_attribute', 'routing_effectivity', NULL, 'CR', 'STANDARD', 'CONSTANTE', 'Date', 'Composant famille CR : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.manuf_part_attribute', 'routing_effectivity', NULL, 'EB', 'STANDARD', 'CONSTANTE', 'Date', 'Composant famille EB : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.manuf_part_attribute', 'routing_effectivity', NULL, 'FX', 'STANDARD', 'CONSTANTE', 'Date', 'Composant famille FX : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.manuf_part_attribute', 'routing_effectivity', NULL, 'HS', 'STANDARD', 'CONSTANTE', 'Date', 'Composant famille HS : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.manuf_part_attribute', 'routing_effectivity', NULL, 'MA', 'STANDARD', 'CONSTANTE', 'Date', 'Composant famille MA : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.manuf_part_attribute', 'routing_effectivity', NULL, 'MP', 'STANDARD', 'CONSTANTE', 'Date', 'Composant famille MP : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.manuf_part_attribute', 'routing_effectivity', NULL, 'MS', 'STANDARD', 'CONSTANTE', 'Date', 'Composant famille MS : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.manuf_part_attribute', 'routing_effectivity', NULL, 'MY', 'STANDARD', 'CONSTANTE', 'Date', 'Composant famille MY : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.manuf_part_attribute', 'routing_effectivity', NULL, 'RS', 'STANDARD', 'CONSTANTE', 'Date', 'Composant famille RS : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.manuf_part_attribute', 'routing_effectivity', NULL, 'SC', 'STANDARD', 'CONSTANTE', 'Date', 'Composant famille SC : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.manuf_part_attribute', 'routing_effectivity', NULL, 'TM', 'STANDARD', 'CONSTANTE', 'Date', 'Composant famille TM : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.manuf_part_attribute', 'ship_dirty', NULL, 'AL', 'STANDARD', 'CONSTANTE', 'False', 'Composant famille AL : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.manuf_part_attribute', 'ship_dirty', NULL, 'BL', 'STANDARD', 'CONSTANTE', 'False', 'Composant famille BL : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.manuf_part_attribute', 'ship_dirty', NULL, 'CR', 'STANDARD', 'CONSTANTE', 'False', 'Composant famille CR : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.manuf_part_attribute', 'ship_dirty', NULL, 'EB', 'STANDARD', 'CONSTANTE', 'False', 'Composant famille EB : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.manuf_part_attribute', 'ship_dirty', NULL, 'FX', 'STANDARD', 'CONSTANTE', 'False', 'Composant famille FX : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.manuf_part_attribute', 'ship_dirty', NULL, 'HS', 'STANDARD', 'CONSTANTE', 'False', 'Composant famille HS : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.manuf_part_attribute', 'ship_dirty', NULL, 'MA', 'STANDARD', 'CONSTANTE', 'False', 'Composant famille MA : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.manuf_part_attribute', 'ship_dirty', NULL, 'MP', 'STANDARD', 'CONSTANTE', 'False', 'Composant famille MP : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.manuf_part_attribute', 'ship_dirty', NULL, 'MS', 'STANDARD', 'CONSTANTE', 'False', 'Composant famille MS : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.manuf_part_attribute', 'ship_dirty', NULL, 'MY', 'STANDARD', 'CONSTANTE', 'False', 'Composant famille MY : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.manuf_part_attribute', 'ship_dirty', NULL, 'RS', 'STANDARD', 'CONSTANTE', 'False', 'Composant famille RS : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.manuf_part_attribute', 'ship_dirty', NULL, 'SC', 'STANDARD', 'CONSTANTE', 'False', 'Composant famille SC : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.manuf_part_attribute', 'ship_dirty', NULL, 'TM', 'STANDARD', 'CONSTANTE', 'False', 'Composant famille TM : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.manuf_part_attribute', 'structure_effectivity', NULL, 'AL', 'STANDARD', 'CONSTANTE', 'Date', 'Composant famille AL : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.manuf_part_attribute', 'structure_effectivity', NULL, 'BL', 'STANDARD', 'CONSTANTE', 'Date', 'Composant famille BL : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.manuf_part_attribute', 'structure_effectivity', NULL, 'CR', 'STANDARD', 'CONSTANTE', 'Date', 'Composant famille CR : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.manuf_part_attribute', 'structure_effectivity', NULL, 'EB', 'STANDARD', 'CONSTANTE', 'Date', 'Composant famille EB : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.manuf_part_attribute', 'structure_effectivity', NULL, 'FX', 'STANDARD', 'CONSTANTE', 'Date', 'Composant famille FX : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.manuf_part_attribute', 'structure_effectivity', NULL, 'HS', 'STANDARD', 'CONSTANTE', 'Date', 'Composant famille HS : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.manuf_part_attribute', 'structure_effectivity', NULL, 'MA', 'STANDARD', 'CONSTANTE', 'Date', 'Composant famille MA : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.manuf_part_attribute', 'structure_effectivity', NULL, 'MP', 'STANDARD', 'CONSTANTE', 'Date', 'Composant famille MP : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.manuf_part_attribute', 'structure_effectivity', NULL, 'MS', 'STANDARD', 'CONSTANTE', 'Date', 'Composant famille MS : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.manuf_part_attribute', 'structure_effectivity', NULL, 'MY', 'STANDARD', 'CONSTANTE', 'Date', 'Composant famille MY : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.manuf_part_attribute', 'structure_effectivity', NULL, 'RS', 'STANDARD', 'CONSTANTE', 'Date', 'Composant famille RS : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.manuf_part_attribute', 'structure_effectivity', NULL, 'SC', 'STANDARD', 'CONSTANTE', 'Date', 'Composant famille SC : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.manuf_part_attribute', 'structure_effectivity', NULL, 'TM', 'STANDARD', 'CONSTANTE', 'Date', 'Composant famille TM : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.manuf_part_attribute', 'use_theoritical_density', NULL, 'AL', 'STANDARD', 'CONSTANTE', 'False', 'Composant famille AL : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.manuf_part_attribute', 'use_theoritical_density', NULL, 'BL', 'STANDARD', 'CONSTANTE', 'False', 'Composant famille BL : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.manuf_part_attribute', 'use_theoritical_density', NULL, 'CR', 'STANDARD', 'CONSTANTE', 'False', 'Composant famille CR : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.manuf_part_attribute', 'use_theoritical_density', NULL, 'EB', 'STANDARD', 'CONSTANTE', 'False', 'Composant famille EB : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.manuf_part_attribute', 'use_theoritical_density', NULL, 'FX', 'STANDARD', 'CONSTANTE', 'False', 'Composant famille FX : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.manuf_part_attribute', 'use_theoritical_density', NULL, 'HS', 'STANDARD', 'CONSTANTE', 'False', 'Composant famille HS : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.manuf_part_attribute', 'use_theoritical_density', NULL, 'MA', 'STANDARD', 'CONSTANTE', 'False', 'Composant famille MA : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.manuf_part_attribute', 'use_theoritical_density', NULL, 'MP', 'STANDARD', 'CONSTANTE', 'False', 'Composant famille MP : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.manuf_part_attribute', 'use_theoritical_density', NULL, 'MS', 'STANDARD', 'CONSTANTE', 'False', 'Composant famille MS : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.manuf_part_attribute', 'use_theoritical_density', NULL, 'MY', 'STANDARD', 'CONSTANTE', 'False', 'Composant famille MY : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.manuf_part_attribute', 'use_theoritical_density', NULL, 'RS', 'STANDARD', 'CONSTANTE', 'False', 'Composant famille RS : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.manuf_part_attribute', 'use_theoritical_density', NULL, 'SC', 'STANDARD', 'CONSTANTE', 'False', 'Composant famille SC : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.manuf_part_attribute', 'use_theoritical_density', NULL, 'TM', 'STANDARD', 'CONSTANTE', 'False', 'Composant famille TM : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.part_catalog', 'allow_as_not_consumed', NULL, 'AL', 'STANDARD', 'CONSTANTE', 'False', 'Composant famille AL : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.part_catalog', 'allow_as_not_consumed', NULL, 'BL', 'STANDARD', 'CONSTANTE', 'False', 'Composant famille BL : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.part_catalog', 'allow_as_not_consumed', NULL, 'CR', 'STANDARD', 'CONSTANTE', 'False', 'Composant famille CR : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.part_catalog', 'allow_as_not_consumed', NULL, 'EB', 'STANDARD', 'CONSTANTE', 'False', 'Composant famille EB : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.part_catalog', 'allow_as_not_consumed', NULL, 'FX', 'STANDARD', 'CONSTANTE', 'False', 'Composant famille FX : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.part_catalog', 'allow_as_not_consumed', NULL, 'HS', 'STANDARD', 'CONSTANTE', 'False', 'Composant famille HS : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.part_catalog', 'allow_as_not_consumed', NULL, 'MA', 'STANDARD', 'CONSTANTE', 'False', 'Composant famille MA : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.part_catalog', 'allow_as_not_consumed', NULL, 'MP', 'STANDARD', 'CONSTANTE', 'False', 'Composant famille MP : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.part_catalog', 'allow_as_not_consumed', NULL, 'MS', 'STANDARD', 'CONSTANTE', 'False', 'Composant famille MS : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.part_catalog', 'allow_as_not_consumed', NULL, 'MY', 'STANDARD', 'CONSTANTE', 'False', 'Composant famille MY : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.part_catalog', 'allow_as_not_consumed', NULL, 'RS', 'STANDARD', 'CONSTANTE', 'False', 'Composant famille RS : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.part_catalog', 'allow_as_not_consumed', NULL, 'SC', 'STANDARD', 'CONSTANTE', 'False', 'Composant famille SC : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.part_catalog', 'allow_as_not_consumed', NULL, 'TM', 'STANDARD', 'CONSTANTE', 'False', 'Composant famille TM : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.part_catalog', 'catch_unit_enabled', NULL, 'AL', 'STANDARD', 'CONSTANTE', 'False', 'Composant famille AL : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.part_catalog', 'catch_unit_enabled', NULL, 'BL', 'STANDARD', 'CONSTANTE', 'False', 'Composant famille BL : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.part_catalog', 'catch_unit_enabled', NULL, 'CR', 'STANDARD', 'CONSTANTE', 'False', 'Composant famille CR : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.part_catalog', 'catch_unit_enabled', NULL, 'EB', 'STANDARD', 'CONSTANTE', 'False', 'Composant famille EB : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.part_catalog', 'catch_unit_enabled', NULL, 'FX', 'STANDARD', 'CONSTANTE', 'False', 'Composant famille FX : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.part_catalog', 'catch_unit_enabled', NULL, 'HS', 'STANDARD', 'CONSTANTE', 'False', 'Composant famille HS : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.part_catalog', 'catch_unit_enabled', NULL, 'MA', 'STANDARD', 'CONSTANTE', 'False', 'Composant famille MA : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.part_catalog', 'catch_unit_enabled', NULL, 'MP', 'STANDARD', 'CONSTANTE', 'False', 'Composant famille MP : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.part_catalog', 'catch_unit_enabled', NULL, 'MS', 'STANDARD', 'CONSTANTE', 'False', 'Composant famille MS : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.part_catalog', 'catch_unit_enabled', NULL, 'MY', 'STANDARD', 'CONSTANTE', 'False', 'Composant famille MY : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.part_catalog', 'catch_unit_enabled', NULL, 'RS', 'STANDARD', 'CONSTANTE', 'False', 'Composant famille RS : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.part_catalog', 'catch_unit_enabled', NULL, 'SC', 'STANDARD', 'CONSTANTE', 'False', 'Composant famille SC : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.part_catalog', 'catch_unit_enabled', NULL, 'TM', 'STANDARD', 'CONSTANTE', 'False', 'Composant famille TM : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.part_catalog', 'component_lot_rule', NULL, 'AL', 'STANDARD', 'CONSTANTE', 'Many Lots Allowed', 'Composant famille AL : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.part_catalog', 'component_lot_rule', NULL, 'BL', 'STANDARD', 'CONSTANTE', 'Many Lots Allowed', 'Composant famille BL : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.part_catalog', 'component_lot_rule', NULL, 'CR', 'STANDARD', 'CONSTANTE', 'Many Lots Allowed', 'Composant famille CR : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.part_catalog', 'component_lot_rule', NULL, 'EB', 'STANDARD', 'CONSTANTE', 'Many Lots Allowed', 'Composant famille EB : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.part_catalog', 'component_lot_rule', NULL, 'FX', 'STANDARD', 'CONSTANTE', 'Many Lots Allowed', 'Composant famille FX : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.part_catalog', 'component_lot_rule', NULL, 'HS', 'STANDARD', 'CONSTANTE', 'Many Lots Allowed', 'Composant famille HS : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.part_catalog', 'component_lot_rule', NULL, 'MA', 'STANDARD', 'CONSTANTE', 'Many Lots Allowed', 'Composant famille MA : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.part_catalog', 'component_lot_rule', NULL, 'MP', 'STANDARD', 'CONSTANTE', 'Many Lots Allowed', 'Composant famille MP : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.part_catalog', 'component_lot_rule', NULL, 'MS', 'STANDARD', 'CONSTANTE', 'Many Lots Allowed', 'Composant famille MS : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.part_catalog', 'component_lot_rule', NULL, 'MY', 'STANDARD', 'CONSTANTE', 'Many Lots Allowed', 'Composant famille MY : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.part_catalog', 'component_lot_rule', NULL, 'RS', 'STANDARD', 'CONSTANTE', 'Many Lots Allowed', 'Composant famille RS : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.part_catalog', 'component_lot_rule', NULL, 'SC', 'STANDARD', 'CONSTANTE', 'Many Lots Allowed', 'Composant famille SC : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.part_catalog', 'component_lot_rule', NULL, 'TM', 'STANDARD', 'CONSTANTE', 'Many Lots Allowed', 'Composant famille TM : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.part_catalog', 'configurable', NULL, 'AL', 'STANDARD', 'CONSTANTE', 'Not Configured', 'Composant famille AL : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.part_catalog', 'configurable', NULL, 'BL', 'STANDARD', 'CONSTANTE', 'Not Configured', 'Composant famille BL : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.part_catalog', 'configurable', NULL, 'CR', 'STANDARD', 'CONSTANTE', 'Not Configured', 'Composant famille CR : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.part_catalog', 'configurable', NULL, 'EB', 'STANDARD', 'CONSTANTE', 'Not Configured', 'Composant famille EB : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.part_catalog', 'configurable', NULL, 'FX', 'STANDARD', 'CONSTANTE', 'Not Configured', 'Composant famille FX : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.part_catalog', 'configurable', NULL, 'HS', 'STANDARD', 'CONSTANTE', 'Not Configured', 'Composant famille HS : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.part_catalog', 'configurable', NULL, 'MA', 'STANDARD', 'CONSTANTE', 'Not Configured', 'Composant famille MA : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.part_catalog', 'configurable', NULL, 'MP', 'STANDARD', 'CONSTANTE', 'Not Configured', 'Composant famille MP : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.part_catalog', 'configurable', NULL, 'MS', 'STANDARD', 'CONSTANTE', 'Not Configured', 'Composant famille MS : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.part_catalog', 'configurable', NULL, 'MY', 'STANDARD', 'CONSTANTE', 'Not Configured', 'Composant famille MY : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.part_catalog', 'configurable', NULL, 'RS', 'STANDARD', 'CONSTANTE', 'Not Configured', 'Composant famille RS : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.part_catalog', 'configurable', NULL, 'SC', 'STANDARD', 'CONSTANTE', 'Not Configured', 'Composant famille SC : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.part_catalog', 'configurable', NULL, 'TM', 'STANDARD', 'CONSTANTE', 'Not Configured', 'Composant famille TM : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.part_catalog', 'eng_serial_tracking_code', NULL, 'AL', 'STANDARD', 'CONSTANTE', 'Not Serial Tracking', 'Composant famille AL : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.part_catalog', 'eng_serial_tracking_code', NULL, 'BL', 'STANDARD', 'CONSTANTE', 'Not Serial Tracking', 'Composant famille BL : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.part_catalog', 'eng_serial_tracking_code', NULL, 'CR', 'STANDARD', 'CONSTANTE', 'Not Serial Tracking', 'Composant famille CR : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.part_catalog', 'eng_serial_tracking_code', NULL, 'EB', 'STANDARD', 'CONSTANTE', 'Not Serial Tracking', 'Composant famille EB : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.part_catalog', 'eng_serial_tracking_code', NULL, 'FX', 'STANDARD', 'CONSTANTE', 'Not Serial Tracking', 'Composant famille FX : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.part_catalog', 'eng_serial_tracking_code', NULL, 'HS', 'STANDARD', 'CONSTANTE', 'Not Serial Tracking', 'Composant famille HS : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.part_catalog', 'eng_serial_tracking_code', NULL, 'MA', 'STANDARD', 'CONSTANTE', 'Not Serial Tracking', 'Composant famille MA : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.part_catalog', 'eng_serial_tracking_code', NULL, 'MP', 'STANDARD', 'CONSTANTE', 'Not Serial Tracking', 'Composant famille MP : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.part_catalog', 'eng_serial_tracking_code', NULL, 'MS', 'STANDARD', 'CONSTANTE', 'Not Serial Tracking', 'Composant famille MS : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.part_catalog', 'eng_serial_tracking_code', NULL, 'MY', 'STANDARD', 'CONSTANTE', 'Not Serial Tracking', 'Composant famille MY : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.part_catalog', 'eng_serial_tracking_code', NULL, 'RS', 'STANDARD', 'CONSTANTE', 'Not Serial Tracking', 'Composant famille RS : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.part_catalog', 'eng_serial_tracking_code', NULL, 'SC', 'STANDARD', 'CONSTANTE', 'Not Serial Tracking', 'Composant famille SC : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.part_catalog', 'eng_serial_tracking_code', NULL, 'TM', 'STANDARD', 'CONSTANTE', 'Not Serial Tracking', 'Composant famille TM : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.part_catalog', 'position_part', NULL, 'AL', 'STANDARD', 'CONSTANTE', 'Not a Position Part', 'Composant famille AL : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.part_catalog', 'position_part', NULL, 'BL', 'STANDARD', 'CONSTANTE', 'Not a Position Part', 'Composant famille BL : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.part_catalog', 'position_part', NULL, 'CR', 'STANDARD', 'CONSTANTE', 'Not a Position Part', 'Composant famille CR : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.part_catalog', 'position_part', NULL, 'EB', 'STANDARD', 'CONSTANTE', 'Not a Position Part', 'Composant famille EB : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.part_catalog', 'position_part', NULL, 'FX', 'STANDARD', 'CONSTANTE', 'Not a Position Part', 'Composant famille FX : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.part_catalog', 'position_part', NULL, 'HS', 'STANDARD', 'CONSTANTE', 'Not a Position Part', 'Composant famille HS : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.part_catalog', 'position_part', NULL, 'MA', 'STANDARD', 'CONSTANTE', 'Not a Position Part', 'Composant famille MA : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.part_catalog', 'position_part', NULL, 'MP', 'STANDARD', 'CONSTANTE', 'Not a Position Part', 'Composant famille MP : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.part_catalog', 'position_part', NULL, 'MS', 'STANDARD', 'CONSTANTE', 'Not a Position Part', 'Composant famille MS : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.part_catalog', 'position_part', NULL, 'MY', 'STANDARD', 'CONSTANTE', 'Not a Position Part', 'Composant famille MY : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.part_catalog', 'position_part', NULL, 'RS', 'STANDARD', 'CONSTANTE', 'Not a Position Part', 'Composant famille RS : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.part_catalog', 'position_part', NULL, 'SC', 'STANDARD', 'CONSTANTE', 'Not a Position Part', 'Composant famille SC : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.part_catalog', 'position_part', NULL, 'TM', 'STANDARD', 'CONSTANTE', 'Not a Position Part', 'Composant famille TM : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.part_catalog', 'receipt_issue_serial_track', NULL, 'AL', 'STANDARD', 'CONSTANTE', 'False', 'Composant famille AL : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.part_catalog', 'receipt_issue_serial_track', NULL, 'BL', 'STANDARD', 'CONSTANTE', 'False', 'Composant famille BL : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.part_catalog', 'receipt_issue_serial_track', NULL, 'CR', 'STANDARD', 'CONSTANTE', 'False', 'Composant famille CR : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.part_catalog', 'receipt_issue_serial_track', NULL, 'EB', 'STANDARD', 'CONSTANTE', 'False', 'Composant famille EB : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.part_catalog', 'receipt_issue_serial_track', NULL, 'FX', 'STANDARD', 'CONSTANTE', 'False', 'Composant famille FX : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.part_catalog', 'receipt_issue_serial_track', NULL, 'HS', 'STANDARD', 'CONSTANTE', 'False', 'Composant famille HS : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.part_catalog', 'receipt_issue_serial_track', NULL, 'MA', 'STANDARD', 'CONSTANTE', 'False', 'Composant famille MA : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.part_catalog', 'receipt_issue_serial_track', NULL, 'MP', 'STANDARD', 'CONSTANTE', 'False', 'Composant famille MP : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.part_catalog', 'receipt_issue_serial_track', NULL, 'MS', 'STANDARD', 'CONSTANTE', 'False', 'Composant famille MS : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.part_catalog', 'receipt_issue_serial_track', NULL, 'MY', 'STANDARD', 'CONSTANTE', 'False', 'Composant famille MY : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.part_catalog', 'receipt_issue_serial_track', NULL, 'RS', 'STANDARD', 'CONSTANTE', 'False', 'Composant famille RS : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.part_catalog', 'receipt_issue_serial_track', NULL, 'SC', 'STANDARD', 'CONSTANTE', 'False', 'Composant famille SC : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.part_catalog', 'receipt_issue_serial_track', NULL, 'TM', 'STANDARD', 'CONSTANTE', 'False', 'Composant famille TM : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.part_catalog', 'serial_rule', NULL, 'AL', 'STANDARD', 'CONSTANTE', 'Manual', 'Composant famille AL : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.part_catalog', 'serial_rule', NULL, 'BL', 'STANDARD', 'CONSTANTE', 'Manual', 'Composant famille BL : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.part_catalog', 'serial_rule', NULL, 'CR', 'STANDARD', 'CONSTANTE', 'Manual', 'Composant famille CR : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.part_catalog', 'serial_rule', NULL, 'EB', 'STANDARD', 'CONSTANTE', 'Manual', 'Composant famille EB : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.part_catalog', 'serial_rule', NULL, 'FX', 'STANDARD', 'CONSTANTE', 'Manual', 'Composant famille FX : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.part_catalog', 'serial_rule', NULL, 'HS', 'STANDARD', 'CONSTANTE', 'Manual', 'Composant famille HS : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.part_catalog', 'serial_rule', NULL, 'MA', 'STANDARD', 'CONSTANTE', 'Manual', 'Composant famille MA : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.part_catalog', 'serial_rule', NULL, 'MP', 'STANDARD', 'CONSTANTE', 'Manual', 'Composant famille MP : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.part_catalog', 'serial_rule', NULL, 'MS', 'STANDARD', 'CONSTANTE', 'Manual', 'Composant famille MS : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.part_catalog', 'serial_rule', NULL, 'MY', 'STANDARD', 'CONSTANTE', 'Manual', 'Composant famille MY : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.part_catalog', 'serial_rule', NULL, 'RS', 'STANDARD', 'CONSTANTE', 'Manual', 'Composant famille RS : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.part_catalog', 'serial_rule', NULL, 'SC', 'STANDARD', 'CONSTANTE', 'Manual', 'Composant famille SC : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.part_catalog', 'serial_rule', NULL, 'TM', 'STANDARD', 'CONSTANTE', 'Manual', 'Composant famille TM : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.part_catalog', 'serial_tracking_code', NULL, 'AL', 'STANDARD', 'CONSTANTE', 'Not Serial Tracking', 'Composant famille AL : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.part_catalog', 'serial_tracking_code', NULL, 'BL', 'STANDARD', 'CONSTANTE', 'Not Serial Tracking', 'Composant famille BL : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.part_catalog', 'serial_tracking_code', NULL, 'CR', 'STANDARD', 'CONSTANTE', 'Not Serial Tracking', 'Composant famille CR : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.part_catalog', 'serial_tracking_code', NULL, 'EB', 'STANDARD', 'CONSTANTE', 'Not Serial Tracking', 'Composant famille EB : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.part_catalog', 'serial_tracking_code', NULL, 'FX', 'STANDARD', 'CONSTANTE', 'Not Serial Tracking', 'Composant famille FX : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.part_catalog', 'serial_tracking_code', NULL, 'HS', 'STANDARD', 'CONSTANTE', 'Not Serial Tracking', 'Composant famille HS : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.part_catalog', 'serial_tracking_code', NULL, 'MA', 'STANDARD', 'CONSTANTE', 'Not Serial Tracking', 'Composant famille MA : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.part_catalog', 'serial_tracking_code', NULL, 'MP', 'STANDARD', 'CONSTANTE', 'Not Serial Tracking', 'Composant famille MP : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.part_catalog', 'serial_tracking_code', NULL, 'MS', 'STANDARD', 'CONSTANTE', 'Not Serial Tracking', 'Composant famille MS : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.part_catalog', 'serial_tracking_code', NULL, 'MY', 'STANDARD', 'CONSTANTE', 'Not Serial Tracking', 'Composant famille MY : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.part_catalog', 'serial_tracking_code', NULL, 'RS', 'STANDARD', 'CONSTANTE', 'Not Serial Tracking', 'Composant famille RS : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.part_catalog', 'serial_tracking_code', NULL, 'SC', 'STANDARD', 'CONSTANTE', 'Not Serial Tracking', 'Composant famille SC : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.part_catalog', 'serial_tracking_code', NULL, 'TM', 'STANDARD', 'CONSTANTE', 'Not Serial Tracking', 'Composant famille TM : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.part_catalog', 'stop_arrival_issued_serial', NULL, 'AL', 'STANDARD', 'CONSTANTE', 'True', 'Composant famille AL : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.part_catalog', 'stop_arrival_issued_serial', NULL, 'BL', 'STANDARD', 'CONSTANTE', 'True', 'Composant famille BL : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.part_catalog', 'stop_arrival_issued_serial', NULL, 'CR', 'STANDARD', 'CONSTANTE', 'True', 'Composant famille CR : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.part_catalog', 'stop_arrival_issued_serial', NULL, 'EB', 'STANDARD', 'CONSTANTE', 'True', 'Composant famille EB : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.part_catalog', 'stop_arrival_issued_serial', NULL, 'FX', 'STANDARD', 'CONSTANTE', 'True', 'Composant famille FX : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.part_catalog', 'stop_arrival_issued_serial', NULL, 'HS', 'STANDARD', 'CONSTANTE', 'True', 'Composant famille HS : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.part_catalog', 'stop_arrival_issued_serial', NULL, 'MA', 'STANDARD', 'CONSTANTE', 'True', 'Composant famille MA : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.part_catalog', 'stop_arrival_issued_serial', NULL, 'MP', 'STANDARD', 'CONSTANTE', 'True', 'Composant famille MP : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.part_catalog', 'stop_arrival_issued_serial', NULL, 'MS', 'STANDARD', 'CONSTANTE', 'True', 'Composant famille MS : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.part_catalog', 'stop_arrival_issued_serial', NULL, 'MY', 'STANDARD', 'CONSTANTE', 'True', 'Composant famille MY : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.part_catalog', 'stop_arrival_issued_serial', NULL, 'RS', 'STANDARD', 'CONSTANTE', 'True', 'Composant famille RS : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.part_catalog', 'stop_arrival_issued_serial', NULL, 'SC', 'STANDARD', 'CONSTANTE', 'True', 'Composant famille SC : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.part_catalog', 'stop_arrival_issued_serial', NULL, 'TM', 'STANDARD', 'CONSTANTE', 'True', 'Composant famille TM : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.part_catalog', 'stop_new_serial_in_rma', NULL, 'AL', 'STANDARD', 'CONSTANTE', 'True', 'Composant famille AL : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.part_catalog', 'stop_new_serial_in_rma', NULL, 'BL', 'STANDARD', 'CONSTANTE', 'True', 'Composant famille BL : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.part_catalog', 'stop_new_serial_in_rma', NULL, 'CR', 'STANDARD', 'CONSTANTE', 'True', 'Composant famille CR : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.part_catalog', 'stop_new_serial_in_rma', NULL, 'EB', 'STANDARD', 'CONSTANTE', 'True', 'Composant famille EB : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.part_catalog', 'stop_new_serial_in_rma', NULL, 'FX', 'STANDARD', 'CONSTANTE', 'True', 'Composant famille FX : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.part_catalog', 'stop_new_serial_in_rma', NULL, 'HS', 'STANDARD', 'CONSTANTE', 'True', 'Composant famille HS : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.part_catalog', 'stop_new_serial_in_rma', NULL, 'MA', 'STANDARD', 'CONSTANTE', 'True', 'Composant famille MA : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.part_catalog', 'stop_new_serial_in_rma', NULL, 'MP', 'STANDARD', 'CONSTANTE', 'True', 'Composant famille MP : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.part_catalog', 'stop_new_serial_in_rma', NULL, 'MS', 'STANDARD', 'CONSTANTE', 'True', 'Composant famille MS : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.part_catalog', 'stop_new_serial_in_rma', NULL, 'MY', 'STANDARD', 'CONSTANTE', 'True', 'Composant famille MY : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.part_catalog', 'stop_new_serial_in_rma', NULL, 'RS', 'STANDARD', 'CONSTANTE', 'True', 'Composant famille RS : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.part_catalog', 'stop_new_serial_in_rma', NULL, 'SC', 'STANDARD', 'CONSTANTE', 'True', 'Composant famille SC : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.part_catalog', 'stop_new_serial_in_rma', NULL, 'TM', 'STANDARD', 'CONSTANTE', 'True', 'Composant famille TM : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.part_catalog', 'sub_lot_rule', NULL, 'AL', 'STANDARD', 'CONSTANTE', 'No Sub Lots Allowed', 'Composant famille AL : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.part_catalog', 'sub_lot_rule', NULL, 'BL', 'STANDARD', 'CONSTANTE', 'No Sub Lots Allowed', 'Composant famille BL : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.part_catalog', 'sub_lot_rule', NULL, 'CR', 'STANDARD', 'CONSTANTE', 'No Sub Lots Allowed', 'Composant famille CR : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.part_catalog', 'sub_lot_rule', NULL, 'EB', 'STANDARD', 'CONSTANTE', 'No Sub Lots Allowed', 'Composant famille EB : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.part_catalog', 'sub_lot_rule', NULL, 'FX', 'STANDARD', 'CONSTANTE', 'No Sub Lots Allowed', 'Composant famille FX : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.part_catalog', 'sub_lot_rule', NULL, 'HS', 'STANDARD', 'CONSTANTE', 'No Sub Lots Allowed', 'Composant famille HS : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.part_catalog', 'sub_lot_rule', NULL, 'MA', 'STANDARD', 'CONSTANTE', 'No Sub Lots Allowed', 'Composant famille MA : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.part_catalog', 'sub_lot_rule', NULL, 'MP', 'STANDARD', 'CONSTANTE', 'No Sub Lots Allowed', 'Composant famille MP : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.part_catalog', 'sub_lot_rule', NULL, 'MS', 'STANDARD', 'CONSTANTE', 'No Sub Lots Allowed', 'Composant famille MS : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.part_catalog', 'sub_lot_rule', NULL, 'MY', 'STANDARD', 'CONSTANTE', 'No Sub Lots Allowed', 'Composant famille MY : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.part_catalog', 'sub_lot_rule', NULL, 'RS', 'STANDARD', 'CONSTANTE', 'No Sub Lots Allowed', 'Composant famille RS : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.part_catalog', 'sub_lot_rule', NULL, 'SC', 'STANDARD', 'CONSTANTE', 'No Sub Lots Allowed', 'Composant famille SC : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.part_catalog', 'sub_lot_rule', NULL, 'TM', 'STANDARD', 'CONSTANTE', 'No Sub Lots Allowed', 'Composant famille TM : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.sales_part', 'activeind', NULL, 'AL', 'STANDARD', 'CONSTANTE', 'Active part', 'Composant famille AL : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.sales_part', 'activeind', NULL, 'BL', 'STANDARD', 'CONSTANTE', 'Active part', 'Composant famille BL : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.sales_part', 'activeind', NULL, 'CR', 'STANDARD', 'CONSTANTE', 'Active part', 'Composant famille CR : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.sales_part', 'activeind', NULL, 'EB', 'STANDARD', 'CONSTANTE', 'Active part', 'Composant famille EB : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.sales_part', 'activeind', NULL, 'FX', 'STANDARD', 'CONSTANTE', 'Active part', 'Composant famille FX : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.sales_part', 'activeind', NULL, 'HS', 'STANDARD', 'CONSTANTE', 'Active part', 'Composant famille HS : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.sales_part', 'activeind', NULL, 'MA', 'STANDARD', 'CONSTANTE', 'Active part', 'Composant famille MA : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.sales_part', 'activeind', NULL, 'MP', 'STANDARD', 'CONSTANTE', 'Active part', 'Composant famille MP : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.sales_part', 'activeind', NULL, 'MS', 'STANDARD', 'CONSTANTE', 'Active part', 'Composant famille MS : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.sales_part', 'activeind', NULL, 'MY', 'STANDARD', 'CONSTANTE', 'Active part', 'Composant famille MY : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.sales_part', 'activeind', NULL, 'RS', 'STANDARD', 'CONSTANTE', 'Active part', 'Composant famille RS : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.sales_part', 'activeind', NULL, 'SC', 'STANDARD', 'CONSTANTE', 'Active part', 'Composant famille SC : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.sales_part', 'activeind', NULL, 'TM', 'STANDARD', 'CONSTANTE', 'Active part', 'Composant famille TM : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.sales_part', 'catalog_type', NULL, 'AL', 'STANDARD', 'CONSTANTE', 'Inventory part', 'Composant famille AL : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.sales_part', 'catalog_type', NULL, 'BL', 'STANDARD', 'CONSTANTE', 'Inventory part', 'Composant famille BL : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.sales_part', 'catalog_type', NULL, 'CR', 'STANDARD', 'CONSTANTE', 'Inventory part', 'Composant famille CR : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.sales_part', 'catalog_type', NULL, 'EB', 'STANDARD', 'CONSTANTE', 'Inventory part', 'Composant famille EB : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.sales_part', 'catalog_type', NULL, 'FX', 'STANDARD', 'CONSTANTE', 'Inventory part', 'Composant famille FX : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.sales_part', 'catalog_type', NULL, 'HS', 'STANDARD', 'CONSTANTE', 'Inventory part', 'Composant famille HS : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.sales_part', 'catalog_type', NULL, 'MA', 'STANDARD', 'CONSTANTE', 'Inventory part', 'Composant famille MA : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.sales_part', 'catalog_type', NULL, 'MP', 'STANDARD', 'CONSTANTE', 'Inventory part', 'Composant famille MP : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.sales_part', 'catalog_type', NULL, 'MS', 'STANDARD', 'CONSTANTE', 'Inventory part', 'Composant famille MS : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.sales_part', 'catalog_type', NULL, 'MY', 'STANDARD', 'CONSTANTE', 'Inventory part', 'Composant famille MY : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.sales_part', 'catalog_type', NULL, 'RS', 'STANDARD', 'CONSTANTE', 'Inventory part', 'Composant famille RS : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.sales_part', 'catalog_type', NULL, 'SC', 'STANDARD', 'CONSTANTE', 'Inventory part', 'Composant famille SC : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.sales_part', 'catalog_type', NULL, 'TM', 'STANDARD', 'CONSTANTE', 'Inventory part', 'Composant famille TM : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.sales_part', 'create_sm_object_option', NULL, 'AL', 'STANDARD', 'CONSTANTE', 'Do not create SM object', 'Composant famille AL : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.sales_part', 'create_sm_object_option', NULL, 'BL', 'STANDARD', 'CONSTANTE', 'Do not create SM object', 'Composant famille BL : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.sales_part', 'create_sm_object_option', NULL, 'CR', 'STANDARD', 'CONSTANTE', 'Do not create SM object', 'Composant famille CR : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.sales_part', 'create_sm_object_option', NULL, 'EB', 'STANDARD', 'CONSTANTE', 'Do not create SM object', 'Composant famille EB : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.sales_part', 'create_sm_object_option', NULL, 'FX', 'STANDARD', 'CONSTANTE', 'Do not create SM object', 'Composant famille FX : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.sales_part', 'create_sm_object_option', NULL, 'HS', 'STANDARD', 'CONSTANTE', 'Do not create SM object', 'Composant famille HS : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.sales_part', 'create_sm_object_option', NULL, 'MA', 'STANDARD', 'CONSTANTE', 'Do not create SM object', 'Composant famille MA : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.sales_part', 'create_sm_object_option', NULL, 'MP', 'STANDARD', 'CONSTANTE', 'Do not create SM object', 'Composant famille MP : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.sales_part', 'create_sm_object_option', NULL, 'MS', 'STANDARD', 'CONSTANTE', 'Do not create SM object', 'Composant famille MS : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.sales_part', 'create_sm_object_option', NULL, 'MY', 'STANDARD', 'CONSTANTE', 'Do not create SM object', 'Composant famille MY : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.sales_part', 'create_sm_object_option', NULL, 'RS', 'STANDARD', 'CONSTANTE', 'Do not create SM object', 'Composant famille RS : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.sales_part', 'create_sm_object_option', NULL, 'SC', 'STANDARD', 'CONSTANTE', 'Do not create SM object', 'Composant famille SC : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.sales_part', 'create_sm_object_option', NULL, 'TM', 'STANDARD', 'CONSTANTE', 'Do not create SM object', 'Composant famille TM : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.sales_part', 'export_to_external_app', NULL, 'AL', 'STANDARD', 'CONSTANTE', 'False', 'Composant famille AL : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.sales_part', 'export_to_external_app', NULL, 'BL', 'STANDARD', 'CONSTANTE', 'False', 'Composant famille BL : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.sales_part', 'export_to_external_app', NULL, 'CR', 'STANDARD', 'CONSTANTE', 'False', 'Composant famille CR : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.sales_part', 'export_to_external_app', NULL, 'EB', 'STANDARD', 'CONSTANTE', 'False', 'Composant famille EB : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.sales_part', 'export_to_external_app', NULL, 'FX', 'STANDARD', 'CONSTANTE', 'False', 'Composant famille FX : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.sales_part', 'export_to_external_app', NULL, 'HS', 'STANDARD', 'CONSTANTE', 'False', 'Composant famille HS : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.sales_part', 'export_to_external_app', NULL, 'MA', 'STANDARD', 'CONSTANTE', 'False', 'Composant famille MA : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.sales_part', 'export_to_external_app', NULL, 'MP', 'STANDARD', 'CONSTANTE', 'False', 'Composant famille MP : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.sales_part', 'export_to_external_app', NULL, 'MS', 'STANDARD', 'CONSTANTE', 'False', 'Composant famille MS : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.sales_part', 'export_to_external_app', NULL, 'MY', 'STANDARD', 'CONSTANTE', 'False', 'Composant famille MY : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.sales_part', 'export_to_external_app', NULL, 'RS', 'STANDARD', 'CONSTANTE', 'False', 'Composant famille RS : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.sales_part', 'export_to_external_app', NULL, 'SC', 'STANDARD', 'CONSTANTE', 'False', 'Composant famille SC : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.sales_part', 'export_to_external_app', NULL, 'TM', 'STANDARD', 'CONSTANTE', 'False', 'Composant famille TM : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.sales_part', 'non_inv_part_type', NULL, 'AL', 'STANDARD', 'CONSTANTE', 'Goods', 'Composant famille AL : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.sales_part', 'non_inv_part_type', NULL, 'BL', 'STANDARD', 'CONSTANTE', 'Goods', 'Composant famille BL : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.sales_part', 'non_inv_part_type', NULL, 'CR', 'STANDARD', 'CONSTANTE', 'Goods', 'Composant famille CR : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.sales_part', 'non_inv_part_type', NULL, 'EB', 'STANDARD', 'CONSTANTE', 'Goods', 'Composant famille EB : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.sales_part', 'non_inv_part_type', NULL, 'FX', 'STANDARD', 'CONSTANTE', 'Goods', 'Composant famille FX : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.sales_part', 'non_inv_part_type', NULL, 'HS', 'STANDARD', 'CONSTANTE', 'Goods', 'Composant famille HS : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.sales_part', 'non_inv_part_type', NULL, 'MA', 'STANDARD', 'CONSTANTE', 'Goods', 'Composant famille MA : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.sales_part', 'non_inv_part_type', NULL, 'MP', 'STANDARD', 'CONSTANTE', 'Goods', 'Composant famille MP : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.sales_part', 'non_inv_part_type', NULL, 'MS', 'STANDARD', 'CONSTANTE', 'Goods', 'Composant famille MS : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.sales_part', 'non_inv_part_type', NULL, 'MY', 'STANDARD', 'CONSTANTE', 'Goods', 'Composant famille MY : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.sales_part', 'non_inv_part_type', NULL, 'RS', 'STANDARD', 'CONSTANTE', 'Goods', 'Composant famille RS : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.sales_part', 'non_inv_part_type', NULL, 'SC', 'STANDARD', 'CONSTANTE', 'Goods', 'Composant famille SC : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.sales_part', 'non_inv_part_type', NULL, 'TM', 'STANDARD', 'CONSTANTE', 'Goods', 'Composant famille TM : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.sales_part', 'non_inv_part_type_db', NULL, 'AL', 'STANDARD', 'CONSTANTE', 'GOODS', 'Composant famille AL : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.sales_part', 'non_inv_part_type_db', NULL, 'BL', 'STANDARD', 'CONSTANTE', 'GOODS', 'Composant famille BL : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.sales_part', 'non_inv_part_type_db', NULL, 'CR', 'STANDARD', 'CONSTANTE', 'GOODS', 'Composant famille CR : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.sales_part', 'non_inv_part_type_db', NULL, 'EB', 'STANDARD', 'CONSTANTE', 'GOODS', 'Composant famille EB : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.sales_part', 'non_inv_part_type_db', NULL, 'FX', 'STANDARD', 'CONSTANTE', 'GOODS', 'Composant famille FX : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.sales_part', 'non_inv_part_type_db', NULL, 'HS', 'STANDARD', 'CONSTANTE', 'GOODS', 'Composant famille HS : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.sales_part', 'non_inv_part_type_db', NULL, 'MA', 'STANDARD', 'CONSTANTE', 'GOODS', 'Composant famille MA : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.sales_part', 'non_inv_part_type_db', NULL, 'MP', 'STANDARD', 'CONSTANTE', 'GOODS', 'Composant famille MP : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.sales_part', 'non_inv_part_type_db', NULL, 'MS', 'STANDARD', 'CONSTANTE', 'GOODS', 'Composant famille MS : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.sales_part', 'non_inv_part_type_db', NULL, 'MY', 'STANDARD', 'CONSTANTE', 'GOODS', 'Composant famille MY : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.sales_part', 'non_inv_part_type_db', NULL, 'RS', 'STANDARD', 'CONSTANTE', 'GOODS', 'Composant famille RS : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.sales_part', 'non_inv_part_type_db', NULL, 'SC', 'STANDARD', 'CONSTANTE', 'GOODS', 'Composant famille SC : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.sales_part', 'non_inv_part_type_db', NULL, 'TM', 'STANDARD', 'CONSTANTE', 'GOODS', 'Composant famille TM : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.sales_part', 'primary_catalog', NULL, 'AL', 'STANDARD', 'CONSTANTE', 'True', 'Composant famille AL : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.sales_part', 'primary_catalog', NULL, 'BL', 'STANDARD', 'CONSTANTE', 'True', 'Composant famille BL : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.sales_part', 'primary_catalog', NULL, 'CR', 'STANDARD', 'CONSTANTE', 'True', 'Composant famille CR : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.sales_part', 'primary_catalog', NULL, 'EB', 'STANDARD', 'CONSTANTE', 'True', 'Composant famille EB : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.sales_part', 'primary_catalog', NULL, 'FX', 'STANDARD', 'CONSTANTE', 'True', 'Composant famille FX : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.sales_part', 'primary_catalog', NULL, 'HS', 'STANDARD', 'CONSTANTE', 'True', 'Composant famille HS : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.sales_part', 'primary_catalog', NULL, 'MA', 'STANDARD', 'CONSTANTE', 'True', 'Composant famille MA : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.sales_part', 'primary_catalog', NULL, 'MP', 'STANDARD', 'CONSTANTE', 'True', 'Composant famille MP : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.sales_part', 'primary_catalog', NULL, 'MS', 'STANDARD', 'CONSTANTE', 'True', 'Composant famille MS : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.sales_part', 'primary_catalog', NULL, 'MY', 'STANDARD', 'CONSTANTE', 'True', 'Composant famille MY : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.sales_part', 'primary_catalog', NULL, 'RS', 'STANDARD', 'CONSTANTE', 'True', 'Composant famille RS : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.sales_part', 'primary_catalog', NULL, 'SC', 'STANDARD', 'CONSTANTE', 'True', 'Composant famille SC : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.sales_part', 'primary_catalog', NULL, 'TM', 'STANDARD', 'CONSTANTE', 'True', 'Composant famille TM : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.sales_part', 'quick_registered_part', NULL, 'AL', 'STANDARD', 'CONSTANTE', 'False', 'Composant famille AL : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.sales_part', 'quick_registered_part', NULL, 'BL', 'STANDARD', 'CONSTANTE', 'False', 'Composant famille BL : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.sales_part', 'quick_registered_part', NULL, 'CR', 'STANDARD', 'CONSTANTE', 'False', 'Composant famille CR : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.sales_part', 'quick_registered_part', NULL, 'EB', 'STANDARD', 'CONSTANTE', 'False', 'Composant famille EB : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.sales_part', 'quick_registered_part', NULL, 'FX', 'STANDARD', 'CONSTANTE', 'False', 'Composant famille FX : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.sales_part', 'quick_registered_part', NULL, 'HS', 'STANDARD', 'CONSTANTE', 'False', 'Composant famille HS : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.sales_part', 'quick_registered_part', NULL, 'MA', 'STANDARD', 'CONSTANTE', 'False', 'Composant famille MA : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.sales_part', 'quick_registered_part', NULL, 'MP', 'STANDARD', 'CONSTANTE', 'False', 'Composant famille MP : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.sales_part', 'quick_registered_part', NULL, 'MS', 'STANDARD', 'CONSTANTE', 'False', 'Composant famille MS : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.sales_part', 'quick_registered_part', NULL, 'MY', 'STANDARD', 'CONSTANTE', 'False', 'Composant famille MY : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.sales_part', 'quick_registered_part', NULL, 'RS', 'STANDARD', 'CONSTANTE', 'False', 'Composant famille RS : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.sales_part', 'quick_registered_part', NULL, 'SC', 'STANDARD', 'CONSTANTE', 'False', 'Composant famille SC : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.sales_part', 'quick_registered_part', NULL, 'TM', 'STANDARD', 'CONSTANTE', 'False', 'Composant famille TM : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.sales_part', 'sales_type', NULL, 'AL', 'STANDARD', 'CONSTANTE', 'Sales Only', 'Composant famille AL : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.sales_part', 'sales_type', NULL, 'BL', 'STANDARD', 'CONSTANTE', 'Sales Only', 'Composant famille BL : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.sales_part', 'sales_type', NULL, 'CR', 'STANDARD', 'CONSTANTE', 'Sales Only', 'Composant famille CR : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.sales_part', 'sales_type', NULL, 'EB', 'STANDARD', 'CONSTANTE', 'Sales Only', 'Composant famille EB : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.sales_part', 'sales_type', NULL, 'FX', 'STANDARD', 'CONSTANTE', 'Sales Only', 'Composant famille FX : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.sales_part', 'sales_type', NULL, 'HS', 'STANDARD', 'CONSTANTE', 'Sales Only', 'Composant famille HS : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.sales_part', 'sales_type', NULL, 'MA', 'STANDARD', 'CONSTANTE', 'Sales Only', 'Composant famille MA : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.sales_part', 'sales_type', NULL, 'MP', 'STANDARD', 'CONSTANTE', 'Sales Only', 'Composant famille MP : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.sales_part', 'sales_type', NULL, 'MS', 'STANDARD', 'CONSTANTE', 'Sales Only', 'Composant famille MS : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.sales_part', 'sales_type', NULL, 'MY', 'STANDARD', 'CONSTANTE', 'Sales Only', 'Composant famille MY : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.sales_part', 'sales_type', NULL, 'RS', 'STANDARD', 'CONSTANTE', 'Sales Only', 'Composant famille RS : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.sales_part', 'sales_type', NULL, 'SC', 'STANDARD', 'CONSTANTE', 'Sales Only', 'Composant famille SC : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.sales_part', 'sales_type', NULL, 'TM', 'STANDARD', 'CONSTANTE', 'Sales Only', 'Composant famille TM : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.sales_part', 'sourcing_option', NULL, 'AL', 'STANDARD', 'CONSTANTE', 'Inventory Order', 'Composant famille AL : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.sales_part', 'sourcing_option', NULL, 'BL', 'STANDARD', 'CONSTANTE', 'Inventory Order', 'Composant famille BL : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.sales_part', 'sourcing_option', NULL, 'CR', 'STANDARD', 'CONSTANTE', 'Inventory Order', 'Composant famille CR : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.sales_part', 'sourcing_option', NULL, 'EB', 'STANDARD', 'CONSTANTE', 'Inventory Order', 'Composant famille EB : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.sales_part', 'sourcing_option', NULL, 'FX', 'STANDARD', 'CONSTANTE', 'Inventory Order', 'Composant famille FX : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.sales_part', 'sourcing_option', NULL, 'HS', 'STANDARD', 'CONSTANTE', 'Inventory Order', 'Composant famille HS : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.sales_part', 'sourcing_option', NULL, 'MA', 'STANDARD', 'CONSTANTE', 'Inventory Order', 'Composant famille MA : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.sales_part', 'sourcing_option', NULL, 'MP', 'STANDARD', 'CONSTANTE', 'Inventory Order', 'Composant famille MP : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.sales_part', 'sourcing_option', NULL, 'MS', 'STANDARD', 'CONSTANTE', 'Inventory Order', 'Composant famille MS : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.sales_part', 'sourcing_option', NULL, 'MY', 'STANDARD', 'CONSTANTE', 'Inventory Order', 'Composant famille MY : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.sales_part', 'sourcing_option', NULL, 'RS', 'STANDARD', 'CONSTANTE', 'Inventory Order', 'Composant famille RS : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.sales_part', 'sourcing_option', NULL, 'SC', 'STANDARD', 'CONSTANTE', 'Inventory Order', 'Composant famille SC : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.sales_part', 'sourcing_option', NULL, 'TM', 'STANDARD', 'CONSTANTE', 'Inventory Order', 'Composant famille TM : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.sales_part', 'sourcing_option_db', NULL, 'AL', 'STANDARD', 'CONSTANTE', 'INVENTORYORDER', 'Composant famille AL : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.sales_part', 'sourcing_option_db', NULL, 'BL', 'STANDARD', 'CONSTANTE', 'INVENTORYORDER', 'Composant famille BL : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.sales_part', 'sourcing_option_db', NULL, 'CR', 'STANDARD', 'CONSTANTE', 'INVENTORYORDER', 'Composant famille CR : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.sales_part', 'sourcing_option_db', NULL, 'EB', 'STANDARD', 'CONSTANTE', 'INVENTORYORDER', 'Composant famille EB : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.sales_part', 'sourcing_option_db', NULL, 'FX', 'STANDARD', 'CONSTANTE', 'INVENTORYORDER', 'Composant famille FX : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.sales_part', 'sourcing_option_db', NULL, 'HS', 'STANDARD', 'CONSTANTE', 'INVENTORYORDER', 'Composant famille HS : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.sales_part', 'sourcing_option_db', NULL, 'MA', 'STANDARD', 'CONSTANTE', 'INVENTORYORDER', 'Composant famille MA : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.sales_part', 'sourcing_option_db', NULL, 'MP', 'STANDARD', 'CONSTANTE', 'INVENTORYORDER', 'Composant famille MP : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.sales_part', 'sourcing_option_db', NULL, 'MS', 'STANDARD', 'CONSTANTE', 'INVENTORYORDER', 'Composant famille MS : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.sales_part', 'sourcing_option_db', NULL, 'MY', 'STANDARD', 'CONSTANTE', 'INVENTORYORDER', 'Composant famille MY : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.sales_part', 'sourcing_option_db', NULL, 'RS', 'STANDARD', 'CONSTANTE', 'INVENTORYORDER', 'Composant famille RS : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.sales_part', 'sourcing_option_db', NULL, 'SC', 'STANDARD', 'CONSTANTE', 'INVENTORYORDER', 'Composant famille SC : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.sales_part', 'sourcing_option_db', NULL, 'TM', 'STANDARD', 'CONSTANTE', 'INVENTORYORDER', 'Composant famille TM : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.sales_part', 'taxable', NULL, 'AL', 'STANDARD', 'CONSTANTE', 'True', 'Composant famille AL : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.sales_part', 'taxable', NULL, 'BL', 'STANDARD', 'CONSTANTE', 'True', 'Composant famille BL : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.sales_part', 'taxable', NULL, 'CR', 'STANDARD', 'CONSTANTE', 'True', 'Composant famille CR : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.sales_part', 'taxable', NULL, 'EB', 'STANDARD', 'CONSTANTE', 'True', 'Composant famille EB : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.sales_part', 'taxable', NULL, 'FX', 'STANDARD', 'CONSTANTE', 'True', 'Composant famille FX : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.sales_part', 'taxable', NULL, 'HS', 'STANDARD', 'CONSTANTE', 'True', 'Composant famille HS : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.sales_part', 'taxable', NULL, 'MA', 'STANDARD', 'CONSTANTE', 'True', 'Composant famille MA : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.sales_part', 'taxable', NULL, 'MP', 'STANDARD', 'CONSTANTE', 'True', 'Composant famille MP : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.sales_part', 'taxable', NULL, 'MS', 'STANDARD', 'CONSTANTE', 'True', 'Composant famille MS : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.sales_part', 'taxable', NULL, 'MY', 'STANDARD', 'CONSTANTE', 'True', 'Composant famille MY : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.sales_part', 'taxable', NULL, 'RS', 'STANDARD', 'CONSTANTE', 'True', 'Composant famille RS : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.sales_part', 'taxable', NULL, 'SC', 'STANDARD', 'CONSTANTE', 'True', 'Composant famille SC : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.sales_part', 'taxable', NULL, 'TM', 'STANDARD', 'CONSTANTE', 'True', 'Composant famille TM : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.sales_part', 'use_price_incl_tax', NULL, 'AL', 'STANDARD', 'CONSTANTE', 'False', 'Composant famille AL : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.sales_part', 'use_price_incl_tax', NULL, 'BL', 'STANDARD', 'CONSTANTE', 'False', 'Composant famille BL : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.sales_part', 'use_price_incl_tax', NULL, 'CR', 'STANDARD', 'CONSTANTE', 'False', 'Composant famille CR : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.sales_part', 'use_price_incl_tax', NULL, 'EB', 'STANDARD', 'CONSTANTE', 'False', 'Composant famille EB : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.sales_part', 'use_price_incl_tax', NULL, 'FX', 'STANDARD', 'CONSTANTE', 'False', 'Composant famille FX : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.sales_part', 'use_price_incl_tax', NULL, 'HS', 'STANDARD', 'CONSTANTE', 'False', 'Composant famille HS : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.sales_part', 'use_price_incl_tax', NULL, 'MA', 'STANDARD', 'CONSTANTE', 'False', 'Composant famille MA : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.sales_part', 'use_price_incl_tax', NULL, 'MP', 'STANDARD', 'CONSTANTE', 'False', 'Composant famille MP : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.sales_part', 'use_price_incl_tax', NULL, 'MS', 'STANDARD', 'CONSTANTE', 'False', 'Composant famille MS : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.sales_part', 'use_price_incl_tax', NULL, 'MY', 'STANDARD', 'CONSTANTE', 'False', 'Composant famille MY : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.sales_part', 'use_price_incl_tax', NULL, 'RS', 'STANDARD', 'CONSTANTE', 'False', 'Composant famille RS : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.sales_part', 'use_price_incl_tax', NULL, 'SC', 'STANDARD', 'CONSTANTE', 'False', 'Composant famille SC : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.sales_part', 'use_price_incl_tax', NULL, 'TM', 'STANDARD', 'CONSTANTE', 'False', 'Composant famille TM : valeur COMPOSANT, distincte de la regle articlePhl sur la meme colonne (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.inventory_part', 'inventory_valuation_method', 'CS', 'AL', 'STANDARD', 'CONSTANTE', 'Weighted Average', 'Composant site CS famille AL : ex-variante COMPOSANT_CS (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.inventory_part', 'inventory_valuation_method', 'CS', 'MA', 'STANDARD', 'CONSTANTE', 'Weighted Average', 'Composant site CS famille MA : ex-variante COMPOSANT_CS (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.inventory_part', 'inventory_valuation_method', 'CS', 'MP', 'STANDARD', 'CONSTANTE', 'Weighted Average', 'Composant site CS famille MP : ex-variante COMPOSANT_CS (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.inventory_part', 'inventory_valuation_method', 'CS', 'MS', 'STANDARD', 'CONSTANTE', 'Weighted Average', 'Composant site CS famille MS : ex-variante COMPOSANT_CS (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.inventory_part', 'inventory_valuation_method', 'CS', 'RS', 'STANDARD', 'CONSTANTE', 'Weighted Average', 'Composant site CS famille RS : ex-variante COMPOSANT_CS (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.inventory_part', 'inventory_valuation_method', 'SJ', 'AL', 'STANDARD', 'CONSTANTE', 'Standard Cost', 'Composant site SJ famille AL : ex-variante COMPOSANT_SJ (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.inventory_part', 'inventory_valuation_method', 'SJ', 'BL', 'STANDARD', 'CONSTANTE', 'Standard Cost', 'Composant site SJ famille BL : ex-variante COMPOSANT_SJ (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.inventory_part', 'inventory_valuation_method', 'SJ', 'CR', 'STANDARD', 'CONSTANTE', 'Standard Cost', 'Composant site SJ famille CR : ex-variante COMPOSANT_SJ (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.inventory_part', 'inventory_valuation_method', 'SJ', 'EB', 'STANDARD', 'CONSTANTE', 'Standard Cost', 'Composant site SJ famille EB : ex-variante COMPOSANT_SJ (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.inventory_part', 'inventory_valuation_method', 'SJ', 'FX', 'STANDARD', 'CONSTANTE', 'Standard Cost', 'Composant site SJ famille FX : ex-variante COMPOSANT_SJ (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.inventory_part', 'inventory_valuation_method', 'SJ', 'HS', 'STANDARD', 'CONSTANTE', 'Standard Cost', 'Composant site SJ famille HS : ex-variante COMPOSANT_SJ (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.inventory_part', 'inventory_valuation_method', 'SJ', 'MA', 'STANDARD', 'CONSTANTE', 'Standard Cost', 'Composant site SJ famille MA : ex-variante COMPOSANT_SJ (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.inventory_part', 'inventory_valuation_method', 'SJ', 'MY', 'STANDARD', 'CONSTANTE', 'Standard Cost', 'Composant site SJ famille MY : ex-variante COMPOSANT_SJ (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.inventory_part', 'inventory_valuation_method', 'SJ', 'SC', 'STANDARD', 'CONSTANTE', 'Standard Cost', 'Composant site SJ famille SC : ex-variante COMPOSANT_SJ (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.inventory_part', 'inventory_valuation_method', 'SJ', 'TM', 'STANDARD', 'CONSTANTE', 'Standard Cost', 'Composant site SJ famille TM : ex-variante COMPOSANT_SJ (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.inventory_part', 'inventory_valuation_method_db', 'CS', 'AL', 'STANDARD', 'CONSTANTE', 'AV', 'Composant site CS famille AL : ex-variante COMPOSANT_CS (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.inventory_part', 'inventory_valuation_method_db', 'CS', 'MA', 'STANDARD', 'CONSTANTE', 'AV', 'Composant site CS famille MA : ex-variante COMPOSANT_CS (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.inventory_part', 'inventory_valuation_method_db', 'CS', 'MP', 'STANDARD', 'CONSTANTE', 'AV', 'Composant site CS famille MP : ex-variante COMPOSANT_CS (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.inventory_part', 'inventory_valuation_method_db', 'CS', 'MS', 'STANDARD', 'CONSTANTE', 'AV', 'Composant site CS famille MS : ex-variante COMPOSANT_CS (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.inventory_part', 'inventory_valuation_method_db', 'CS', 'RS', 'STANDARD', 'CONSTANTE', 'AV', 'Composant site CS famille RS : ex-variante COMPOSANT_CS (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.inventory_part', 'inventory_valuation_method_db', 'SJ', 'AL', 'STANDARD', 'CONSTANTE', 'ST', 'Composant site SJ famille AL : ex-variante COMPOSANT_SJ (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.inventory_part', 'inventory_valuation_method_db', 'SJ', 'BL', 'STANDARD', 'CONSTANTE', 'ST', 'Composant site SJ famille BL : ex-variante COMPOSANT_SJ (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.inventory_part', 'inventory_valuation_method_db', 'SJ', 'CR', 'STANDARD', 'CONSTANTE', 'ST', 'Composant site SJ famille CR : ex-variante COMPOSANT_SJ (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.inventory_part', 'inventory_valuation_method_db', 'SJ', 'EB', 'STANDARD', 'CONSTANTE', 'ST', 'Composant site SJ famille EB : ex-variante COMPOSANT_SJ (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.inventory_part', 'inventory_valuation_method_db', 'SJ', 'FX', 'STANDARD', 'CONSTANTE', 'ST', 'Composant site SJ famille FX : ex-variante COMPOSANT_SJ (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.inventory_part', 'inventory_valuation_method_db', 'SJ', 'HS', 'STANDARD', 'CONSTANTE', 'ST', 'Composant site SJ famille HS : ex-variante COMPOSANT_SJ (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.inventory_part', 'inventory_valuation_method_db', 'SJ', 'MA', 'STANDARD', 'CONSTANTE', 'ST', 'Composant site SJ famille MA : ex-variante COMPOSANT_SJ (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.inventory_part', 'inventory_valuation_method_db', 'SJ', 'MY', 'STANDARD', 'CONSTANTE', 'ST', 'Composant site SJ famille MY : ex-variante COMPOSANT_SJ (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.inventory_part', 'inventory_valuation_method_db', 'SJ', 'SC', 'STANDARD', 'CONSTANTE', 'ST', 'Composant site SJ famille SC : ex-variante COMPOSANT_SJ (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.inventory_part', 'inventory_valuation_method_db', 'SJ', 'TM', 'STANDARD', 'CONSTANTE', 'ST', 'Composant site SJ famille TM : ex-variante COMPOSANT_SJ (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.part_catalog', 'condition_code_usage', 'CS', 'AL', 'STANDARD', 'CONSTANTE', 'Allow Condition Code', 'Composant site CS famille AL : ex-variante COMPOSANT_CS (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.part_catalog', 'condition_code_usage', 'CS', 'MA', 'STANDARD', 'CONSTANTE', 'Allow Condition Code', 'Composant site CS famille MA : ex-variante COMPOSANT_CS (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.part_catalog', 'condition_code_usage', 'CS', 'MP', 'STANDARD', 'CONSTANTE', 'Allow Condition Code', 'Composant site CS famille MP : ex-variante COMPOSANT_CS (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.part_catalog', 'condition_code_usage', 'CS', 'MS', 'STANDARD', 'CONSTANTE', 'Allow Condition Code', 'Composant site CS famille MS : ex-variante COMPOSANT_CS (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.part_catalog', 'condition_code_usage', 'CS', 'RS', 'STANDARD', 'CONSTANTE', 'Allow Condition Code', 'Composant site CS famille RS : ex-variante COMPOSANT_CS (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.part_catalog', 'condition_code_usage', 'SJ', 'AL', 'STANDARD', 'CONSTANTE', 'Not Allow Condition Code', 'Composant site SJ famille AL : ex-variante COMPOSANT_SJ (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.part_catalog', 'condition_code_usage', 'SJ', 'BL', 'STANDARD', 'CONSTANTE', 'Not Allow Condition Code', 'Composant site SJ famille BL : ex-variante COMPOSANT_SJ (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.part_catalog', 'condition_code_usage', 'SJ', 'CR', 'STANDARD', 'CONSTANTE', 'Not Allow Condition Code', 'Composant site SJ famille CR : ex-variante COMPOSANT_SJ (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.part_catalog', 'condition_code_usage', 'SJ', 'EB', 'STANDARD', 'CONSTANTE', 'Not Allow Condition Code', 'Composant site SJ famille EB : ex-variante COMPOSANT_SJ (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.part_catalog', 'condition_code_usage', 'SJ', 'FX', 'STANDARD', 'CONSTANTE', 'Not Allow Condition Code', 'Composant site SJ famille FX : ex-variante COMPOSANT_SJ (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.part_catalog', 'condition_code_usage', 'SJ', 'HS', 'STANDARD', 'CONSTANTE', 'Not Allow Condition Code', 'Composant site SJ famille HS : ex-variante COMPOSANT_SJ (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.part_catalog', 'condition_code_usage', 'SJ', 'MA', 'STANDARD', 'CONSTANTE', 'Not Allow Condition Code', 'Composant site SJ famille MA : ex-variante COMPOSANT_SJ (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.part_catalog', 'condition_code_usage', 'SJ', 'MY', 'STANDARD', 'CONSTANTE', 'Not Allow Condition Code', 'Composant site SJ famille MY : ex-variante COMPOSANT_SJ (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.part_catalog', 'condition_code_usage', 'SJ', 'SC', 'STANDARD', 'CONSTANTE', 'Not Allow Condition Code', 'Composant site SJ famille SC : ex-variante COMPOSANT_SJ (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.part_catalog', 'condition_code_usage', 'SJ', 'TM', 'STANDARD', 'CONSTANTE', 'Not Allow Condition Code', 'Composant site SJ famille TM : ex-variante COMPOSANT_SJ (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.part_catalog', 'condition_code_usage_db', 'CS', 'AL', 'STANDARD', 'CONSTANTE', 'ALLOW_COND_CODE', 'Composant site CS famille AL : ex-variante COMPOSANT_CS (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.part_catalog', 'condition_code_usage_db', 'CS', 'MA', 'STANDARD', 'CONSTANTE', 'ALLOW_COND_CODE', 'Composant site CS famille MA : ex-variante COMPOSANT_CS (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.part_catalog', 'condition_code_usage_db', 'CS', 'MP', 'STANDARD', 'CONSTANTE', 'ALLOW_COND_CODE', 'Composant site CS famille MP : ex-variante COMPOSANT_CS (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.part_catalog', 'condition_code_usage_db', 'CS', 'MS', 'STANDARD', 'CONSTANTE', 'ALLOW_COND_CODE', 'Composant site CS famille MS : ex-variante COMPOSANT_CS (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.part_catalog', 'condition_code_usage_db', 'CS', 'RS', 'STANDARD', 'CONSTANTE', 'ALLOW_COND_CODE', 'Composant site CS famille RS : ex-variante COMPOSANT_CS (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.part_catalog', 'condition_code_usage_db', 'SJ', 'AL', 'STANDARD', 'CONSTANTE', 'NOT_ALLOW_COND_CODE', 'Composant site SJ famille AL : ex-variante COMPOSANT_SJ (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.part_catalog', 'condition_code_usage_db', 'SJ', 'BL', 'STANDARD', 'CONSTANTE', 'NOT_ALLOW_COND_CODE', 'Composant site SJ famille BL : ex-variante COMPOSANT_SJ (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.part_catalog', 'condition_code_usage_db', 'SJ', 'CR', 'STANDARD', 'CONSTANTE', 'NOT_ALLOW_COND_CODE', 'Composant site SJ famille CR : ex-variante COMPOSANT_SJ (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.part_catalog', 'condition_code_usage_db', 'SJ', 'EB', 'STANDARD', 'CONSTANTE', 'NOT_ALLOW_COND_CODE', 'Composant site SJ famille EB : ex-variante COMPOSANT_SJ (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.part_catalog', 'condition_code_usage_db', 'SJ', 'FX', 'STANDARD', 'CONSTANTE', 'NOT_ALLOW_COND_CODE', 'Composant site SJ famille FX : ex-variante COMPOSANT_SJ (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.part_catalog', 'condition_code_usage_db', 'SJ', 'HS', 'STANDARD', 'CONSTANTE', 'NOT_ALLOW_COND_CODE', 'Composant site SJ famille HS : ex-variante COMPOSANT_SJ (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.part_catalog', 'condition_code_usage_db', 'SJ', 'MA', 'STANDARD', 'CONSTANTE', 'NOT_ALLOW_COND_CODE', 'Composant site SJ famille MA : ex-variante COMPOSANT_SJ (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.part_catalog', 'condition_code_usage_db', 'SJ', 'MY', 'STANDARD', 'CONSTANTE', 'NOT_ALLOW_COND_CODE', 'Composant site SJ famille MY : ex-variante COMPOSANT_SJ (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.part_catalog', 'condition_code_usage_db', 'SJ', 'SC', 'STANDARD', 'CONSTANTE', 'NOT_ALLOW_COND_CODE', 'Composant site SJ famille SC : ex-variante COMPOSANT_SJ (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.part_catalog', 'condition_code_usage_db', 'SJ', 'TM', 'STANDARD', 'CONSTANTE', 'NOT_ALLOW_COND_CODE', 'Composant site SJ famille TM : ex-variante COMPOSANT_SJ (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.part_catalog', 'multilevel_tracking', 'CS', 'AL', 'STANDARD', 'CONSTANTE', 'Tracking On', 'Composant site CS famille AL : ex-variante COMPOSANT_CS (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.part_catalog', 'multilevel_tracking', 'CS', 'MA', 'STANDARD', 'CONSTANTE', 'Tracking On', 'Composant site CS famille MA : ex-variante COMPOSANT_CS (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.part_catalog', 'multilevel_tracking', 'CS', 'MP', 'STANDARD', 'CONSTANTE', 'Tracking On', 'Composant site CS famille MP : ex-variante COMPOSANT_CS (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.part_catalog', 'multilevel_tracking', 'CS', 'MS', 'STANDARD', 'CONSTANTE', 'Tracking On', 'Composant site CS famille MS : ex-variante COMPOSANT_CS (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.part_catalog', 'multilevel_tracking', 'CS', 'RS', 'STANDARD', 'CONSTANTE', 'Tracking On', 'Composant site CS famille RS : ex-variante COMPOSANT_CS (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.part_catalog', 'multilevel_tracking', 'SJ', 'AL', 'STANDARD', 'CONSTANTE', 'Tracking Off', 'Composant site SJ famille AL : ex-variante COMPOSANT_SJ (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.part_catalog', 'multilevel_tracking', 'SJ', 'BL', 'STANDARD', 'CONSTANTE', 'Tracking Off', 'Composant site SJ famille BL : ex-variante COMPOSANT_SJ (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.part_catalog', 'multilevel_tracking', 'SJ', 'CR', 'STANDARD', 'CONSTANTE', 'Tracking Off', 'Composant site SJ famille CR : ex-variante COMPOSANT_SJ (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.part_catalog', 'multilevel_tracking', 'SJ', 'EB', 'STANDARD', 'CONSTANTE', 'Tracking Off', 'Composant site SJ famille EB : ex-variante COMPOSANT_SJ (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.part_catalog', 'multilevel_tracking', 'SJ', 'FX', 'STANDARD', 'CONSTANTE', 'Tracking Off', 'Composant site SJ famille FX : ex-variante COMPOSANT_SJ (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.part_catalog', 'multilevel_tracking', 'SJ', 'HS', 'STANDARD', 'CONSTANTE', 'Tracking Off', 'Composant site SJ famille HS : ex-variante COMPOSANT_SJ (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.part_catalog', 'multilevel_tracking', 'SJ', 'MA', 'STANDARD', 'CONSTANTE', 'Tracking Off', 'Composant site SJ famille MA : ex-variante COMPOSANT_SJ (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.part_catalog', 'multilevel_tracking', 'SJ', 'MY', 'STANDARD', 'CONSTANTE', 'Tracking Off', 'Composant site SJ famille MY : ex-variante COMPOSANT_SJ (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.part_catalog', 'multilevel_tracking', 'SJ', 'SC', 'STANDARD', 'CONSTANTE', 'Tracking Off', 'Composant site SJ famille SC : ex-variante COMPOSANT_SJ (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.part_catalog', 'multilevel_tracking', 'SJ', 'TM', 'STANDARD', 'CONSTANTE', 'Tracking Off', 'Composant site SJ famille TM : ex-variante COMPOSANT_SJ (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.part_catalog', 'multilevel_tracking_db', 'CS', 'AL', 'STANDARD', 'CONSTANTE', 'TRACKING_ON', 'Composant site CS famille AL : ex-variante COMPOSANT_CS (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.part_catalog', 'multilevel_tracking_db', 'CS', 'MA', 'STANDARD', 'CONSTANTE', 'TRACKING_ON', 'Composant site CS famille MA : ex-variante COMPOSANT_CS (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.part_catalog', 'multilevel_tracking_db', 'CS', 'MP', 'STANDARD', 'CONSTANTE', 'TRACKING_ON', 'Composant site CS famille MP : ex-variante COMPOSANT_CS (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.part_catalog', 'multilevel_tracking_db', 'CS', 'MS', 'STANDARD', 'CONSTANTE', 'TRACKING_ON', 'Composant site CS famille MS : ex-variante COMPOSANT_CS (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.part_catalog', 'multilevel_tracking_db', 'CS', 'RS', 'STANDARD', 'CONSTANTE', 'TRACKING_ON', 'Composant site CS famille RS : ex-variante COMPOSANT_CS (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.part_catalog', 'multilevel_tracking_db', 'SJ', 'AL', 'STANDARD', 'CONSTANTE', 'TRACKING_OFF', 'Composant site SJ famille AL : ex-variante COMPOSANT_SJ (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.part_catalog', 'multilevel_tracking_db', 'SJ', 'BL', 'STANDARD', 'CONSTANTE', 'TRACKING_OFF', 'Composant site SJ famille BL : ex-variante COMPOSANT_SJ (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.part_catalog', 'multilevel_tracking_db', 'SJ', 'CR', 'STANDARD', 'CONSTANTE', 'TRACKING_OFF', 'Composant site SJ famille CR : ex-variante COMPOSANT_SJ (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.part_catalog', 'multilevel_tracking_db', 'SJ', 'EB', 'STANDARD', 'CONSTANTE', 'TRACKING_OFF', 'Composant site SJ famille EB : ex-variante COMPOSANT_SJ (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.part_catalog', 'multilevel_tracking_db', 'SJ', 'FX', 'STANDARD', 'CONSTANTE', 'TRACKING_OFF', 'Composant site SJ famille FX : ex-variante COMPOSANT_SJ (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.part_catalog', 'multilevel_tracking_db', 'SJ', 'HS', 'STANDARD', 'CONSTANTE', 'TRACKING_OFF', 'Composant site SJ famille HS : ex-variante COMPOSANT_SJ (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.part_catalog', 'multilevel_tracking_db', 'SJ', 'MA', 'STANDARD', 'CONSTANTE', 'TRACKING_OFF', 'Composant site SJ famille MA : ex-variante COMPOSANT_SJ (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.part_catalog', 'multilevel_tracking_db', 'SJ', 'MY', 'STANDARD', 'CONSTANTE', 'TRACKING_OFF', 'Composant site SJ famille MY : ex-variante COMPOSANT_SJ (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.part_catalog', 'multilevel_tracking_db', 'SJ', 'SC', 'STANDARD', 'CONSTANTE', 'TRACKING_OFF', 'Composant site SJ famille SC : ex-variante COMPOSANT_SJ (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;
INSERT INTO public.etl_default_value_matrix (module, table_cible, colonne, contract, part_family, variante, type_valeur, valeur, description, created_by, updated_by)
VALUES ('articleComposant', 'clean_data.part_catalog', 'multilevel_tracking_db', 'SJ', 'TM', 'STANDARD', 'CONSTANTE', 'TRACKING_OFF', 'Composant site SJ famille TM : ex-variante COMPOSANT_SJ (migration 072).', 'migration_072', 'migration_072')
ON CONFLICT DO NOTHING;

COMMIT;

-- ============================================================================
-- ROLLBACK
-- ============================================================================
-- BEGIN;
-- DELETE FROM public.etl_default_value_matrix WHERE created_by = 'migration_072';
-- DELETE FROM public.etl_part_family          WHERE created_by = 'migration_072';
-- COMMIT;
-- Puis : git checkout sql/ArticleComposant && cd sql/ArticleComposant && ./compile.sh
