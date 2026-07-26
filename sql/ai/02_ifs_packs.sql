-- =====================================================================
-- 02_ifs_packs.sql
-- Packs de connaissances metier IFS (clean_data) pour l'Assistant IA.
-- Cible : public.ai_packs (content JSONB, lue par ai_prompt_builder / knowledge_service).
--
-- Idempotent : INSERT ... ON CONFLICT (domain) DO UPDATE (domain = PK).
-- Le domain de chaque pack correspond a un domain_id de 01_ifs_domain_tables.sql.
-- Jointures / colonnes / volumes verifies en base le 2026-07-07.
-- Contenu JSON en dollar-quoting (evite d'echapper les apostrophes francaises).
-- =====================================================================
BEGIN;

-- Articles / catalogue IFS -------------------------------------------------
INSERT INTO public.ai_packs (domain, content, actif) VALUES ('ifs_articles', $json$
{
  "domain": "ifs_articles",
  "keywords": ["catalogue", "article", "part_catalog", "inventory_part", "purchase_part", "sales_part"],
  "synonyms": ["part catalog", "catalogue ifs", "article ifs", "article migre", "article transforme", "inventory part", "purchase part", "sales part"],
  "docs": [
    "part_catalog = table de BASE du catalogue article IFS (1 ligne par part_no, ~1750). Les tables filles (inventory_part, purchase_part, sales_part) sont PAR SITE (colonne contract, ex 'SJ') et ne contiennent que des part_no presents dans part_catalog.",
    "Beaucoup de colonnes booleennes IFS existent en double : xxx (texte lisible) et xxx_db (code IFS). Le libelle article = part_catalog.description."
  ],
  "tables": ["clean_data.part_catalog", "clean_data.inventory_part", "clean_data.purchase_part", "clean_data.sales_part", "clean_data.purchase_part_supplier"],
  "joins": [
    "part_catalog<->inventory_part sur part_no [inventory_part par site: contract]",
    "part_catalog<->purchase_part sur part_no [purchase_part par site: contract]",
    "part_catalog<->sales_part sur part_no [sales_part.catalog_no, par site: contract]",
    "purchase_part<->purchase_part_supplier sur (contract, part_no) [fournisseur: vendor_no]"
  ],
  "enums": [
    "part_catalog.part_no = cle article ; part_catalog.description = libelle ; part_catalog.unit_code = unite",
    "inventory_part/purchase_part/sales_part.contract = site (ex 'SJ') ; inventory_part.part_status, part_product_family = statut/famille"
  ],
  "rules": [
    "COUNT(*) sur clean_data.part_catalog = nombre d'articles du catalogue IFS. Ne PAS compter sur les tables par site (plusieurs lignes par article si plusieurs sites).",
    "Pour le libelle d'un article IFS, utiliser part_catalog.description (pas les tables filles)."
  ],
  "patterns": [
    {"intent": "nombre d'articles dans le catalogue IFS", "sql": "SELECT COUNT(*) AS nb_articles FROM clean_data.part_catalog"},
    {"intent": "articles achetables par site", "sql": "SELECT contract, COUNT(*) AS nb FROM clean_data.purchase_part GROUP BY contract ORDER BY nb DESC"}
  ]
}
$json$::jsonb, TRUE)
ON CONFLICT (domain) DO UPDATE SET content = EXCLUDED.content, actif = TRUE, date_maj = CURRENT_TIMESTAMP;

-- Fournisseurs IFS ---------------------------------------------------------
INSERT INTO public.ai_packs (domain, content, actif) VALUES ('ifs_fournisseurs', $json$
{
  "domain": "ifs_fournisseurs",
  "keywords": ["supplier", "fournisseur", "vendor_no", "supplier_info_general"],
  "synonyms": ["fournisseur ifs", "fournisseur migre", "supplier ifs", "fournisseur transforme", "dans supplier"],
  "docs": [
    "Fournisseurs migres dans IFS : clean_data.supplier (identifiant vendor_no, RENUMEROTE a partir de 600000). L'ancien code LIFNR SAP est conserve dans clean_data.supplier_info_general.supplier_legacy_sap_id (relation 1:1 avec supplier, ~1716 lignes)."
  ],
  "tables": ["clean_data.supplier", "clean_data.supplier_info_general", "clean_data.purchase_part_supplier"],
  "joins": [
    "supplier<->supplier_info_general sur supplier.vendor_no = supplier_info_general.supplier_id",
    "supplier<->purchase_part_supplier sur vendor_no [article fourni: part_no, contract]"
  ],
  "enums": [
    "supplier.vendor_no = identifiant IFS (renumerote 600000+) ; supplier.name = raison sociale ; supplier.vat_no = TVA ; supplier.status ; supplier.is_deleted = supprime",
    "supplier_info_general.supplier_legacy_sap_id = ancien code fournisseur SAP (LIFNR)"
  ],
  "rules": [
    "Pour retrouver un fournisseur par son ANCIEN code SAP (LIFNR), joindre supplier_info_general.supplier_legacy_sap_id.",
    "COUNT(*) sur clean_data.supplier = nombre de fournisseurs migres dans IFS."
  ],
  "patterns": [
    {"intent": "nombre de fournisseurs migres dans IFS", "sql": "SELECT COUNT(*) AS nb FROM clean_data.supplier"},
    {"intent": "mapping ancien LIFNR SAP vers nouveau vendor_no IFS", "sql": "SELECT g.supplier_legacy_sap_id AS lifnr_sap, s.vendor_no, s.name FROM clean_data.supplier s JOIN clean_data.supplier_info_general g ON g.supplier_id = s.vendor_no ORDER BY s.vendor_no"}
  ]
}
$json$::jsonb, TRUE)
ON CONFLICT (domain) DO UPDATE SET content = EXCLUDED.content, actif = TRUE, date_maj = CURRENT_TIMESTAMP;

-- Clients IFS --------------------------------------------------------------
INSERT INTO public.ai_packs (domain, content, actif) VALUES ('ifs_clients', $json$
{
  "domain": "ifs_clients",
  "keywords": ["customer", "client", "ifs_customer"],
  "synonyms": ["client ifs", "client migre", "customer ifs", "dans ifs_customer"],
  "docs": [
    "Clients migres dans IFS : clean_data.ifs_customer (identifiant customer_number, ~243 lignes)."
  ],
  "tables": ["clean_data.ifs_customer"],
  "joins": [
    "Pas de jointure requise pour le denombrement ; ifs_customer est autoportante (raison sociale name_1..name_4, adresse, TVA)."
  ],
  "enums": [
    "ifs_customer.customer_number = id client IFS ; name_1..name_4 = raison sociale ; vat_number = TVA ; country = pays ; customer_group = groupe client",
    "Indicateurs de blocage : order_block, delivery_block, billing_block ; deletion_flag = supprime"
  ],
  "rules": [
    "COUNT(*) sur clean_data.ifs_customer = nombre de clients migres dans IFS.",
    "Le nom du client est reparti sur name_1..name_4 : concatener si besoin avec ||."
  ],
  "patterns": [
    {"intent": "nombre de clients migres dans IFS", "sql": "SELECT COUNT(*) AS nb FROM clean_data.ifs_customer"},
    {"intent": "clients IFS par pays", "sql": "SELECT country, COUNT(*) AS nb FROM clean_data.ifs_customer GROUP BY country ORDER BY nb DESC"}
  ]
}
$json$::jsonb, TRUE)
ON CONFLICT (domain) DO UPDATE SET content = EXCLUDED.content, actif = TRUE, date_maj = CURRENT_TIMESTAMP;

-- Projets IFS --------------------------------------------------------------
INSERT INTO public.ai_packs (domain, content, actif) VALUES ('ifs_projet', $json$
{
  "domain": "ifs_projet",
  "keywords": ["project", "projet", "activity", "activite", "sub_project", "wbs"],
  "synonyms": ["projet ifs", "activite projet", "sous-projet", "project activity", "project base", "structure projet"],
  "docs": [
    "Structure projet IFS : project_base (~390 projets) -> sub_project (sous-projets) -> project_activity (~1954 activites). project_role_assignment relie un projet/activite a une personne via un role."
  ],
  "tables": ["clean_data.project_base", "clean_data.sub_project", "clean_data.project_activity", "clean_data.project_role_assignment"],
  "joins": [
    "project_base<->sub_project sur project_id",
    "sub_project<->project_activity sur (project_id, sub_project_id)",
    "project_base<->project_role_assignment sur project_id [role_id, person_id]",
    "project_role_assignment<->ifs_person sur person_id"
  ],
  "enums": [
    "project_base.project_id = cle projet ; name = libelle ; manager ; customer_id = client ; plan_start/plan_finish = dates planifiees",
    "project_activity.activity_seq = cle technique ; activity_no = numero ; description ; project_id, sub_project_id = rattachement"
  ],
  "rules": [
    "Hierarchie : project_base (1) -> sub_project (N) -> project_activity (N). Compter les activites d'un projet = COUNT(*) sur project_activity filtre par project_id.",
    "Un projet peut ne pas avoir de sous-projet/activite -> LEFT JOIN si on liste tous les projets."
  ],
  "patterns": [
    {"intent": "nombre d'activites par projet", "sql": "SELECT project_id, COUNT(*) AS nb_activites FROM clean_data.project_activity GROUP BY project_id ORDER BY nb_activites DESC"},
    {"intent": "projets et leur manager", "sql": "SELECT project_id, name, manager FROM clean_data.project_base ORDER BY project_id"}
  ]
}
$json$::jsonb, TRUE)
ON CONFLICT (domain) DO UPDATE SET content = EXCLUDED.content, actif = TRUE, date_maj = CURRENT_TIMESTAMP;

-- Personnes / ressources IFS ----------------------------------------------
INSERT INTO public.ai_packs (domain, content, actif) VALUES ('ifs_personnes', $json$
{
  "domain": "ifs_personnes",
  "keywords": ["person", "personne", "personnes", "resource", "ressource"],
  "synonyms": ["personne ifs", "ressource projet", "employe", "intervenant", "ifs person"],
  "docs": [
    "Personnes migrees dans IFS : clean_data.ifs_person (identifiant person_id, ~966). Reliees aux projets/activites via project_role_assignment (role_id, person_id)."
  ],
  "tables": ["clean_data.ifs_person", "clean_data.project_role_assignment"],
  "joins": [
    "ifs_person<->project_role_assignment sur person_id [role_id, project_id, activity_seq]"
  ],
  "enums": [
    "ifs_person.person_id = identifiant ; first_name, last_name = nom/prenom ; internal_display_name = nom affiche ; resource_id = lien ressource",
    "project_role_assignment.role_id = role sur le projet ; system_generated = affectation auto"
  ],
  "rules": [
    "COUNT(*) sur clean_data.ifs_person = nombre de personnes dans IFS.",
    "Pour les personnes affectees a un projet, joindre project_role_assignment sur person_id (une personne peut avoir plusieurs affectations)."
  ],
  "patterns": [
    {"intent": "nombre de personnes dans IFS", "sql": "SELECT COUNT(*) AS nb FROM clean_data.ifs_person"},
    {"intent": "personnes affectees a un projet", "sql": "SELECT p.person_id, p.first_name, p.last_name, a.project_id, a.role_id FROM clean_data.ifs_person p JOIN clean_data.project_role_assignment a ON a.person_id = p.person_id ORDER BY a.project_id"}
  ]
}
$json$::jsonb, TRUE)
ON CONFLICT (domain) DO UPDATE SET content = EXCLUDED.content, actif = TRUE, date_maj = CURRENT_TIMESTAMP;

-- Maintenance / equipements IFS -------------------------------------------
INSERT INTO public.ai_packs (domain, content, actif) VALUES ('ifs_maintenance', $json$
{
  "domain": "ifs_maintenance",
  "keywords": ["maintenance", "equipement", "equipment", "maintenance_object", "equipment_functional"],
  "synonyms": ["objet de maintenance", "equipement fonctionnel", "materiel", "machine", "equipment functional"],
  "docs": [
    "clean_data.maintenance_object (~96000) = hierarchie generique des objets de maintenance (parent_id -> id). clean_data.equipment_functional (~11000) = equipements / objets fonctionnels IFS (cle equipment_object_seq, par site contract)."
  ],
  "tables": ["clean_data.maintenance_object", "clean_data.equipment_functional"],
  "joins": [
    "maintenance_object hierarchie : maintenance_object.parent_id -> maintenance_object.id (self-join)"
  ],
  "enums": [
    "maintenance_object: id (cle), object_type, code, designation, category, work_center, cost_center, plant, is_active, parent_id",
    "equipment_functional: equipment_object_seq (cle), mch_code, mch_name, contract (site), part_no (article), vendor_no (fournisseur), manufacturer_no, serial_no, criticality, operational_status"
  ],
  "rules": [
    "COUNT(*) sur maintenance_object = nombre d'objets de maintenance (hierarchie complete). Racines = parent_id IS NULL.",
    "equipment_functional.contract = site ; un equipement est identifie par equipment_object_seq."
  ],
  "patterns": [
    {"intent": "nombre d'objets de maintenance", "sql": "SELECT COUNT(*) AS nb FROM clean_data.maintenance_object"},
    {"intent": "equipements par site", "sql": "SELECT contract, COUNT(*) AS nb FROM clean_data.equipment_functional GROUP BY contract ORDER BY nb DESC"}
  ]
}
$json$::jsonb, TRUE)
ON CONFLICT (domain) DO UPDATE SET content = EXCLUDED.content, actif = TRUE, date_maj = CURRENT_TIMESTAMP;

-- Plan de maintenance preventive (PM actions) IFS -------------------------
INSERT INTO public.ai_packs (domain, content, actif) VALUES ('ifs_pm_actions', $json$
{
  "domain": "ifs_pm_actions",
  "keywords": ["pm_action", "preventive", "preventif", "entretien", "pm_no"],
  "synonyms": ["action de maintenance", "plan de maintenance", "maintenance preventive", "pm action", "gamme de maintenance"],
  "docs": [
    "Plan de maintenance preventive IFS : clean_data.pm_action (cle COMPOSEE pm_no + pm_revision). Chaque action a des ressources (pm_action_resource), des etapes de travail (pm_action_work_step) et des jobs (pm_action_job)."
  ],
  "tables": ["clean_data.pm_action", "clean_data.pm_action_resource", "clean_data.pm_action_work_step", "clean_data.pm_action_job"],
  "joins": [
    "pm_action<->pm_action_resource sur (pm_no, pm_revision)",
    "pm_action<->pm_action_work_step sur (pm_no, pm_revision)",
    "pm_action<->pm_action_job sur (pm_no, pm_revision)"
  ],
  "enums": [
    "pm_action: pm_no + pm_revision (cle), description, work_type_id, interval + pm_interval_unit (periodicite), mch_code, equipment_object_seq, vendor_no",
    "pm_action_resource: resource_id, resource_description, planned_hours ; pm_action_work_step: description, order_no ; pm_action_job: job_id, std_job_id, qty"
  ],
  "rules": [
    "La cle d'une action PM est (pm_no, pm_revision) : TOUJOURS joindre les tables filles sur ces DEUX colonnes.",
    "COUNT(*) sur pm_action = nombre d'actions de maintenance preventive."
  ],
  "patterns": [
    {"intent": "nombre d'actions de maintenance preventive", "sql": "SELECT COUNT(*) AS nb FROM clean_data.pm_action"},
    {"intent": "nombre d'etapes de travail par action PM", "sql": "SELECT s.pm_no, COUNT(*) AS nb_etapes FROM clean_data.pm_action_work_step s GROUP BY s.pm_no ORDER BY nb_etapes DESC"}
  ]
}
$json$::jsonb, TRUE)
ON CONFLICT (domain) DO UPDATE SET content = EXCLUDED.content, actif = TRUE, date_maj = CURRENT_TIMESTAMP;

-- Article maitre (synthese denormalisee) IFS ------------------------------
INSERT INTO public.ai_packs (domain, content, actif) VALUES ('ifs_article_maitre', $json$
{
  "domain": "ifs_article_maitre",
  "keywords": ["article_maitre", "numero_article", "article"],
  "synonyms": ["article maitre", "fiche article ifs", "synthese article", "master article"],
  "docs": [
    "clean_data.ifs_article_maitre (~16000) = synthese DENORMALISEE par article (numero_article) : type, groupe, stock total, valorisation, fournisseur principal, centres actifs. Pratique pour interroger un article sans multiples jointures. NB: clean_data.ifs_article a des colonnes en francais avec espaces (moins pratique a requeter)."
  ],
  "tables": ["clean_data.ifs_article_maitre"],
  "joins": [
    "Table autoportante (denormalisee) : pas de jointure requise pour la plupart des questions."
  ],
  "enums": [
    "ifs_article_maitre: numero_article (cle), designation, ancien_numero (code SAP), type_article + libelle_type_article, groupe_article, unite_base, fournisseur_principal + nom_fournisseur_principal, statut_utilisation",
    "Agrege : stock_quantite_total, stock_total_libre, valeur_stock_total, prix_moyen_pondere_moyen (PMP), nombre_centres_actifs, nombre_magasins"
  ],
  "rules": [
    "COUNT(*) sur ifs_article_maitre = nombre d'articles (fiche maitre).",
    "Pour l'ancien code SAP d'un article, colonne ancien_numero."
  ],
  "patterns": [
    {"intent": "nombre d'articles (fiche maitre)", "sql": "SELECT COUNT(*) AS nb FROM clean_data.ifs_article_maitre"},
    {"intent": "articles par type", "sql": "SELECT type_article, libelle_type_article, COUNT(*) AS nb FROM clean_data.ifs_article_maitre GROUP BY type_article, libelle_type_article ORDER BY nb DESC"}
  ]
}
$json$::jsonb, TRUE)
ON CONFLICT (domain) DO UPDATE SET content = EXCLUDED.content, actif = TRUE, date_maj = CURRENT_TIMESTAMP;

-- Taxes IFS ----------------------------------------------------------------
INSERT INTO public.ai_packs (domain, content, actif) VALUES ('ifs_taxes', $json$
{
  "domain": "ifs_taxes",
  "keywords": ["taxe", "tax", "tva", "fiscal", "exoneration"],
  "synonyms": ["taxe fournisseur", "taxe client", "information fiscale", "tax info", "exoneration de taxe"],
  "docs": [
    "Informations fiscales IFS : clean_data.supplier_tax_info (par fournisseur, ~1716) et clean_data.customer_tax_info (par client). clean_data.customer_tax_free_tax_code = codes d'exoneration client."
  ],
  "tables": ["clean_data.supplier_tax_info", "clean_data.customer_tax_info", "clean_data.customer_tax_free_tax_code"],
  "joins": [
    "supplier_tax_info<->supplier sur supplier_tax_info.supplier_id = supplier.vendor_no"
  ],
  "enums": [
    "supplier_tax_info: supplier_id (= vendor_no), company, tax_calc_structure_id, icms_tax_payer",
    "customer_tax_info: customer_id, company, tax_exempt (+ tax_exempt_db), tax_office_id, fiscal_no"
  ],
  "rules": [
    "Joindre les infos fiscales fournisseur au fournisseur via supplier_id = supplier.vendor_no.",
    "Les colonnes booleennes IFS existent en double (xxx et xxx_db) : le suffixe _db porte le code (ex 'TRUE'/'FALSE')."
  ],
  "patterns": [
    {"intent": "nombre de fournisseurs avec info fiscale", "sql": "SELECT COUNT(*) AS nb FROM clean_data.supplier_tax_info"},
    {"intent": "fournisseurs et leur structure de calcul de taxe", "sql": "SELECT s.vendor_no, s.name, t.tax_calc_structure_id FROM clean_data.supplier s JOIN clean_data.supplier_tax_info t ON t.supplier_id = s.vendor_no ORDER BY s.vendor_no"}
  ]
}
$json$::jsonb, TRUE)
ON CONFLICT (domain) DO UPDATE SET content = EXCLUDED.content, actif = TRUE, date_maj = CURRENT_TIMESTAMP;

-- Adresses IFS -------------------------------------------------------------
INSERT INTO public.ai_packs (domain, content, actif) VALUES ('ifs_adresses', $json$
{
  "domain": "ifs_adresses",
  "keywords": ["adresse", "adresses", "address"],
  "synonyms": ["adresse fournisseur", "adresse client", "adresse de livraison", "address"],
  "docs": [
    "Adresses IFS : clean_data.supplier_address (par fournisseur, cle vendor_no + addr_no) et clean_data.customer_info_address (par client, customer_id + address_id, avec adresse postale detaillee)."
  ],
  "tables": ["clean_data.supplier_address", "clean_data.customer_info_address", "clean_data.supplier_info_address"],
  "joins": [
    "supplier_address<->supplier sur vendor_no",
    "customer_info_address<->customer_info sur customer_id"
  ],
  "enums": [
    "customer_info_address: customer_id, address_id, name, address1..address6, zip_code, city, county, state, country",
    "supplier_address: vendor_no, addr_no, delivery_terms, ship_via_code, route_id, contact"
  ],
  "rules": [
    "Adresse postale detaillee client = customer_info_address (address1..6, zip_code, city, country).",
    "customer_info_address se joint a customer_info (customer_id), PAS a ifs_customer (espaces d'identifiants differents)."
  ],
  "patterns": [
    {"intent": "adresses clients par pays", "sql": "SELECT country, COUNT(*) AS nb FROM clean_data.customer_info_address GROUP BY country ORDER BY nb DESC"},
    {"intent": "adresses fournisseurs", "sql": "SELECT s.vendor_no, s.name, a.addr_no, a.delivery_terms FROM clean_data.supplier s JOIN clean_data.supplier_address a ON a.vendor_no = s.vendor_no ORDER BY s.vendor_no"}
  ]
}
$json$::jsonb, TRUE)
ON CONFLICT (domain) DO UPDATE SET content = EXCLUDED.content, actif = TRUE, date_maj = CURRENT_TIMESTAMP;

-- Paiement / donnees bancaires IFS ----------------------------------------
INSERT INTO public.ai_packs (domain, content, actif) VALUES ('ifs_paiement', $json$
{
  "domain": "ifs_paiement",
  "keywords": ["paiement", "payment", "reglement", "iban", "bic"],
  "synonyms": ["mode de paiement", "donnees bancaires", "reglement fournisseur", "payment"],
  "docs": [
    "Donnees de paiement IFS (modele 'identity') : clean_data.identity_pay_info (parametres de paiement par identite/societe), clean_data.payment_address (coordonnees bancaires : account, bic_code), clean_data.income_type_per_identity (types de revenu / retenue)."
  ],
  "tables": ["clean_data.identity_pay_info", "clean_data.payment_address", "clean_data.income_type_per_identity"],
  "joins": [
    "Modele 'identity' : cle (company, identity, party_type). identity_pay_info.supplier_id / customer_id relient a un tiers."
  ],
  "enums": [
    "identity_pay_info: company, identity, party_type, payment_mode, blocked_for_payment, default_payment_method, supplier_id, customer_id",
    "payment_address: company, identity, way_id, address_id, account (compte), bic_code, blocked_for_use"
  ],
  "rules": [
    "party_type distingue fournisseur et client dans le modele identity.",
    "COUNT(*) sur payment_address = nombre de coordonnees de paiement."
  ],
  "patterns": [
    {"intent": "nombre de coordonnees de paiement", "sql": "SELECT COUNT(*) AS nb FROM clean_data.payment_address"},
    {"intent": "identites et leur mode de paiement", "sql": "SELECT company, identity, party_type, payment_mode FROM clean_data.identity_pay_info ORDER BY company, identity"}
  ]
}
$json$::jsonb, TRUE)
ON CONFLICT (domain) DO UPDATE SET content = EXCLUDED.content, actif = TRUE, date_maj = CURRENT_TIMESTAMP;

-- Ressources de planification (maintenance) IFS ---------------------------
INSERT INTO public.ai_packs (domain, content, actif) VALUES ('ifs_ressources', $json$
{
  "domain": "ifs_ressources",
  "keywords": ["resource_availability", "maint_person_resource", "disponibilite", "ressource"],
  "synonyms": ["disponibilite ressource", "ressource de maintenance", "ressource de planification", "resource availability"],
  "docs": [
    "Ressources de planification (maintenance) IFS : clean_data.maint_person_resource (ressources personnes / vendeurs), clean_data.resource_availability (disponibilite : available_percentage, efficiency, periodes), clean_data.resource_parent (hierarchie des ressources)."
  ],
  "tables": ["clean_data.maint_person_resource", "clean_data.resource_availability", "clean_data.resource_parent"],
  "joins": [
    "Ressources reperees par resource_id / resource_seq (identifiants IFS de ressource)."
  ],
  "enums": [
    "resource_availability: resource_id, company, site, start_date, end_date, available_percentage, efficiency",
    "maint_person_resource: resource_connection_seq, vendor_no, org_code, primary_resource, avail_for_scheduling"
  ],
  "rules": [
    "resource_availability.available_percentage = taux de disponibilite d'une ressource sur une periode (start_date / end_date)."
  ],
  "patterns": [
    {"intent": "nombre de ressources personnes de maintenance", "sql": "SELECT COUNT(*) AS nb FROM clean_data.maint_person_resource"},
    {"intent": "disponibilite des ressources par site", "sql": "SELECT site, COUNT(*) AS nb FROM clean_data.resource_availability GROUP BY site ORDER BY nb DESC"}
  ]
}
$json$::jsonb, TRUE)
ON CONFLICT (domain) DO UPDATE SET content = EXCLUDED.content, actif = TRUE, date_maj = CURRENT_TIMESTAMP;

COMMIT;

-- Verification :
--   SELECT domain, jsonb_array_length(content->'patterns') AS patterns,
--          jsonb_array_length(content->'joins') AS joins
--   FROM public.ai_packs WHERE domain LIKE 'ifs_%' ORDER BY domain;
