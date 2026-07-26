-- =====================================================================
-- 01_ifs_domain_tables.sql
-- Associations mot-cle -> tables cibles IFS (clean_data) pour l'Assistant IA.
-- Cible : public.ai_domain_tables (lue par ai_schema_retriever / ai_config_store).
--
-- Idempotent : supprime puis reinsere UNIQUEMENT les domaines ifs_* gerees ici
-- (la config SAP existante n'est pas touchee).
-- keywords / tables sont du JSONB. tables = noms schema-qualifies (clean_data.*).
-- Structure verifiee en base le 2026-07-07 (pas de table/colonne inventee).
-- =====================================================================
BEGIN;

-- Gere TOUS les domaines ifs_* (idempotent, ne touche pas la config SAP).
DELETE FROM public.ai_domain_tables WHERE domain_id LIKE 'ifs_%';

INSERT INTO public.ai_domain_tables (domain_id, keywords, tables, position, actif) VALUES
-- Articles / catalogue IFS -------------------------------------------------
('ifs_articles',
 '["catalogue","part_catalog","inventory_part","purchase_part","sales_part","partcatalog"]'::jsonb,
 '["clean_data.part_catalog","clean_data.inventory_part","clean_data.purchase_part","clean_data.sales_part","clean_data.purchase_part_supplier","clean_data.inventory_part_in_stock"]'::jsonb,
 100, TRUE),

-- Fournisseurs IFS ---------------------------------------------------------
('ifs_fournisseurs',
 '["supplier","vendor_no","vendorno","supplier_info_general"]'::jsonb,
 '["clean_data.supplier","clean_data.supplier_info_general","clean_data.purchase_part_supplier"]'::jsonb,
 101, TRUE),

-- Clients IFS --------------------------------------------------------------
('ifs_clients',
 '["customer","ifs_customer","customer_info"]'::jsonb,
 '["clean_data.ifs_customer"]'::jsonb,
 102, TRUE),

-- Projets IFS --------------------------------------------------------------
('ifs_projet',
 '["project","project_base","project_activity","sub_project","activity","wbs"]'::jsonb,
 '["clean_data.project_base","clean_data.sub_project","clean_data.project_activity","clean_data.project_role_assignment"]'::jsonb,
 103, TRUE),

-- Personnes / ressources IFS ----------------------------------------------
('ifs_personnes',
 '["person","ifs_person","personne","personnes"]'::jsonb,
 '["clean_data.ifs_person","clean_data.project_role_assignment"]'::jsonb,
 104, TRUE),

-- Maintenance / equipements IFS -------------------------------------------
('ifs_maintenance',
 '["maintenance","equipement","equipements","equipment","maintenance_object","equipment_functional"]'::jsonb,
 '["clean_data.maintenance_object","clean_data.equipment_functional"]'::jsonb,
 105, TRUE),

-- Plan de maintenance preventive (PM actions) IFS -------------------------
('ifs_pm_actions',
 '["pm_action","preventive","preventif","entretien","gamme","pm_no"]'::jsonb,
 '["clean_data.pm_action","clean_data.pm_action_resource","clean_data.pm_action_work_step","clean_data.pm_action_job"]'::jsonb,
 106, TRUE),

-- Article maitre (synthese denormalisee) IFS ------------------------------
('ifs_article_maitre',
 '["article_maitre","numero_article","fichearticle"]'::jsonb,
 '["clean_data.ifs_article_maitre"]'::jsonb,
 107, TRUE),

-- Taxes IFS ----------------------------------------------------------------
('ifs_taxes',
 '["taxe","taxes","tax","tva","fiscal","exoneration"]'::jsonb,
 '["clean_data.supplier_tax_info","clean_data.customer_tax_info","clean_data.customer_tax_free_tax_code"]'::jsonb,
 108, TRUE),

-- Adresses IFS -------------------------------------------------------------
('ifs_adresses',
 '["adresse","adresses","address"]'::jsonb,
 '["clean_data.supplier_address","clean_data.customer_info_address","clean_data.supplier_info_address"]'::jsonb,
 109, TRUE),

-- Paiement / donnees bancaires IFS ----------------------------------------
('ifs_paiement',
 '["paiement","payment","reglement","iban","bic"]'::jsonb,
 '["clean_data.identity_pay_info","clean_data.payment_address","clean_data.income_type_per_identity"]'::jsonb,
 110, TRUE),

-- Ressources de planification (maintenance) IFS ---------------------------
('ifs_ressources',
 '["resource_availability","maint_person_resource","disponibilite"]'::jsonb,
 '["clean_data.maint_person_resource","clean_data.resource_availability","clean_data.resource_parent"]'::jsonb,
 111, TRUE);

COMMIT;

-- Verification :
--   SELECT domain_id, jsonb_array_length(tables) FROM public.ai_domain_tables
--   WHERE domain_id LIKE 'ifs_%' ORDER BY position;
