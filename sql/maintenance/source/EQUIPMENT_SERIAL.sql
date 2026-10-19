-- =====================================================================
-- clean_data.equipment_serial
-- Source  : spec IFS EQUIPMENT_SERIAL (EQUIPMENT_OBJECT_SEQ / CONTRACT / MCH_CODE + attributs objet)
-- Conventions clean_data : snake_case, VARCHAR2(n)->VARCHAR(n),
--   NUMBER(n)->NUMERIC(n,0), DATE->DATE, CHAR(n)->CHAR(n),
--   colonnes NULLABLE, sans DEFAULT/PK/provenance.
-- 83 colonnes.
--
-- Infos complémentaires de la spec reportées en commentaires :
--   oblig.  = champ obligatoire côté IFS
--   défaut  = valeur par défaut de la spec (à porter dans
--             Configuration -> Valeurs par défaut, pas en DEFAULT SQL)
--   LOV     = liste de valeurs / table de référence IFS
--   enum    = énumération IFS (valeur DB <=> valeur client)
--   NOCHECK = LOV sans contrôle d'existence
-- =====================================================================
CREATE TABLE IF NOT EXISTS clean_data.equipment_serial (
    equipment_object_seq           NUMERIC(20, 0),   -- clé (séquence IFS)
    contract                       VARCHAR(5),       -- oblig. | défaut 'SJ' | LOV Site
    mch_code                       VARCHAR(100),     -- oblig.
    mch_name                       VARCHAR(200),
    part_no                        VARCHAR(25),      -- oblig. | LOV PartCatalog
    mch_loc                        VARCHAR(60),      -- LOV EquipmentRoom(contract)
    area_id                        VARCHAR(100),     -- LOV EquipmentArea(contract)
    deck_id                        VARCHAR(60),      -- LOV EquipmentDeck(contract)
    mch_pos                        VARCHAR(15),
    mch_doc                        VARCHAR(20),
    maintenance_strategy_id        VARCHAR(20),      -- LOV MaintenanceStrategy
    technical_lifetime             NUMERIC(20, 0),
    model_id                       VARCHAR(200),
    model_ver                      NUMERIC(20, 0),   -- LOV ServiceModel(model_id) NOCHECK
    safety_critical_element_db     VARCHAR(20),
    functional_object_seq          NUMERIC(20, 0),   -- LOV EquipmentObject NOCHECK
    purch_price                    NUMERIC(20, 0),
    purch_date                     DATE,
    warr_exp                       DATE,
    note                           VARCHAR(2000),
    info                           VARCHAR(2000),
    data                           VARCHAR(2000),
    production_date                DATE,
    company                        VARCHAR(4000),    -- défaut 'TRIMET'
    has_structure                  VARCHAR(4000),    -- enum TranslateBoolean : FALSE=No, TRUE=Yes
    has_connection                 VARCHAR(4000),    -- enum TranslateBoolean : FALSE=No, TRUE=Yes
    mch_code_key_value             VARCHAR(4000),
    type_key_value                 VARCHAR(4000),
    serial_no                      VARCHAR(50),      -- oblig. | LOV PartSerialCatalog(part_no)
    manufacturer_no                VARCHAR(20),      -- LOV PartManufacturer(part_no)
    vendor_no                      VARCHAR(20),      -- LOV SupplierInfo
    part_rev                       VARCHAR(6),
    equipment_main_position        VARCHAR(4000),    -- enum EquipmentMainPosition : N=No, Y=Yes
    equipment_main_position_db     VARCHAR(20),      -- enum EquipmentMainPosition : N=No, Y=Yes
    type                           VARCHAR(30),      -- LOV TypeDesignation
    mch_type                       VARCHAR(20),      -- LOV EquipmentObjType
    obj_level                      VARCHAR(30),
    group_id                       VARCHAR(10),      -- LOV EquipmentObjGroup
    cost_center                    VARCHAR(10),      -- LOV CodeB(company) NOCHECK
    object_no                      VARCHAR(10),      -- LOV CodeE(company) NOCHECK
    category_id                    VARCHAR(10),      -- LOV EquipmentObjCategory
    sup_mch_code                   VARCHAR(100),
    sup_contract                   VARCHAR(5),       -- défaut 'SJ'
    lu_name                        CHAR(60),
    key_ref                        VARCHAR(4000),
    criticality                    VARCHAR(10),      -- LOV EquipmentCriticality
    latest_transaction             VARCHAR(200),
    serial_state                   VARCHAR(4000),
    operational_condition          VARCHAR(4000),    -- oblig. | LOV SerialOperationalCond
    operational_status             VARCHAR(4000),
    operational_status_db          VARCHAR(20),      -- oblig. | LOV SerialOperationalStatus
    manufactured_date              DATE,
    owner                          VARCHAR(20),
    ownership_db                   VARCHAR(20),      -- enum Ownership : CUSTOMER OWNED, COMPANY OWNED, SUPPLIER LOANED, SUPPLIER RENTED, COMPANY RENTAL ASSET
    ownership                      VARCHAR(4000),    -- défaut 'Company Owned' | enum Ownership (idem ownership_db, valeurs client)
    location_mch_code              VARCHAR(4000),
    location_contract              VARCHAR(4000),
    from_mch_code                  VARCHAR(4000),
    from_contract                  VARCHAR(4000),
    to_mch_code                    VARCHAR(4000),
    to_contract                    VARCHAR(4000),
    process_mch_code               VARCHAR(4000),
    process_contract               VARCHAR(4000),
    pipe_mch_code                  VARCHAR(4000),
    pipe_contract                  VARCHAR(4000),
    circuit_mch_code               VARCHAR(4000),
    circuit_contract               VARCHAR(4000),
    location_id                    VARCHAR(30),      -- défaut '1' | LOV Location
    item_class_id                  VARCHAR(10),      -- LOV ItemClass
    safe_access_code               VARCHAR(4000),    -- défaut 'Not Required' | enum SafeAccessCode : REQUIRED=Required, NOT_REQUIRED=Not Required
    safe_access_code_db            VARCHAR(20),      -- enum SafeAccessCode : REQUIRED=Required, NOT_REQUIRED=Not Required
    process_class_id               VARCHAR(10),      -- LOV ProcessClass NOCHECK
    not_applicable_set_date        DATE,
    not_applicable_set_user        VARCHAR(20),
    not_applicable_reason          VARCHAR(2000),
    pm_prog_application_status     VARCHAR(5),       -- défaut 'FALSE'
    applied_date                   DATE,
    applied_pm_program_rev         VARCHAR(6),       -- LOV PmProgram(applied_pm_program_id) NOCHECK
    applied_pm_program_id          VARCHAR(100),
    is_geographic_object           VARCHAR(5),       -- défaut 'FAUX'
    is_category_object             VARCHAR(5),
    cluster_id                     VARCHAR(10),      -- LOV WopsObjectCluster(contract)
    proxy_object_seq               NUMERIC(20, 0)
);

-- =====================================================================
-- Commentaires de colonnes (libellé IFS + description de la spec)
-- =====================================================================
COMMENT ON TABLE clean_data.equipment_serial IS 'Objets d''équipement série IFS (EQUIPMENT_SERIAL) - 83 colonnes';

COMMENT ON COLUMN clean_data.equipment_serial.equipment_object_seq IS 'Equipment Object Seq - clé (séquence IFS).';
COMMENT ON COLUMN clean_data.equipment_serial.contract IS 'Object Site - L''identité du site auquel l''objet est associé.';
COMMENT ON COLUMN clean_data.equipment_serial.mch_code IS 'Object ID - L''objet auquel le bon de travail est destiné. Valeur renseignée automatiquement si le cas a un objet d''équipement, un actif linéaire ou un équipement d''outil comme objet métier pour lequel la case Réf. copier vers passation est cochée.';
COMMENT ON COLUMN clean_data.equipment_serial.mch_name IS 'Description - Champ de texte libre utilisé pour entrer une description.';
COMMENT ON COLUMN clean_data.equipment_serial.part_no IS 'Part No - Article maître.';
COMMENT ON COLUMN clean_data.equipment_serial.mch_loc IS 'Room - Informations sur la pièce où l''objet d''équipement actuel est situé dans l''installation.';
COMMENT ON COLUMN clean_data.equipment_serial.area_id IS 'Area/Zone - Informations sur la zone où se trouve l''objet d''équipement.';
COMMENT ON COLUMN clean_data.equipment_serial.deck_id IS 'Deck/Floor - Informations sur le pont ou l''étage où se trouve l''objet d''équipement.';
COMMENT ON COLUMN clean_data.equipment_serial.mch_pos IS 'Position - ID de poste et nom/titre de l''ID de poste attribué à l''employé.';
COMMENT ON COLUMN clean_data.equipment_serial.mch_doc IS 'Documents - Indique si des documents sont connectés à la désignation du type.';
COMMENT ON COLUMN clean_data.equipment_serial.maintenance_strategy_id IS 'Maintenance Strategy - Identité de la stratégie de maintenance de l''objet (exécuter jusqu''à la défaillance, préventif, prédictif, préventif et prédictif).';
COMMENT ON COLUMN clean_data.equipment_serial.technical_lifetime IS 'Technical Lifetime - Durée de vie prévue de l''objet en années, utilisée avec la date d''installation pour calculer la durée de vie utile restante.';
COMMENT ON COLUMN clean_data.equipment_serial.model_id IS 'Model Id.';
COMMENT ON COLUMN clean_data.equipment_serial.model_ver IS 'Version (du modèle).';
COMMENT ON COLUMN clean_data.equipment_serial.safety_critical_element_db IS 'Safety and Environmental Critical Element - Si activé, l''objet (ou une partie) a un composant dont la défaillance entraîne une situation critique pour la sécurité et l''environnement, ou dont le but est d''éviter une telle situation.';
COMMENT ON COLUMN clean_data.equipment_serial.functional_object_seq IS 'Functional Object Seq.';
COMMENT ON COLUMN clean_data.equipment_serial.purch_price IS 'Purchase Price - Prix d''achat exprimé dans la devise d''achat. Utilisé lors de la création de contrats fournisseur via des campagnes.';
COMMENT ON COLUMN clean_data.equipment_serial.purch_date IS 'Purchase Date - Date d''achat de l''objet, le cas échéant. Non modifiable après la saisie initiale.';
COMMENT ON COLUMN clean_data.equipment_serial.warr_exp IS 'Warranty Expires - Date d''expiration de la garantie.';
COMMENT ON COLUMN clean_data.equipment_serial.note IS 'Note - Note ou remarque relative à l''enregistrement.';
COMMENT ON COLUMN clean_data.equipment_serial.info IS 'Info - Informations libres (champ en lecture seule).';
COMMENT ON COLUMN clean_data.equipment_serial.data IS 'Data.';
COMMENT ON COLUMN clean_data.equipment_serial.production_date IS 'Production Date.';
COMMENT ON COLUMN clean_data.equipment_serial.company IS 'Company - Société source (spec : valeur par défaut TRIMET).';
COMMENT ON COLUMN clean_data.equipment_serial.has_structure IS 'Has Structure - Booléen traduit (FALSE=No, TRUE=Yes).';
COMMENT ON COLUMN clean_data.equipment_serial.has_connection IS 'Has Connection - Booléen traduit (FALSE=No, TRUE=Yes).';
COMMENT ON COLUMN clean_data.equipment_serial.mch_code_key_value IS 'Mch Code Key Value.';
COMMENT ON COLUMN clean_data.equipment_serial.type_key_value IS 'Type Key Value.';
COMMENT ON COLUMN clean_data.equipment_serial.serial_no IS 'Serial No - Numéro de série de l''article, s''il en possède un (articles série du catalogue article).';
COMMENT ON COLUMN clean_data.equipment_serial.manufacturer_no IS 'Manufacturer - Identité du fabricant. Non modifiable ultérieurement.';
COMMENT ON COLUMN clean_data.equipment_serial.vendor_no IS 'Supplier - Identité du fournisseur.';
COMMENT ON COLUMN clean_data.equipment_serial.part_rev IS 'Serial Revision.';
COMMENT ON COLUMN clean_data.equipment_serial.equipment_main_position IS 'Equipment Main Position - Indique si l''objet est une position principale (position de fonction la plus basse avant le premier niveau de série ; niveau du rapport de défauts). N=No, Y=Yes.';
COMMENT ON COLUMN clean_data.equipment_serial.equipment_main_position_db IS 'Main Pos - Valeur DB de equipment_main_position (N/Y).';
COMMENT ON COLUMN clean_data.equipment_serial.type IS 'Type Designation - Identité de la désignation du type connectée à l''objet d''équipement (données de conception centralisées : moteurs, pompes...).';
COMMENT ON COLUMN clean_data.equipment_serial.mch_type IS 'Object Type - Nom de l''unité logique du type d''objet. Non modifiable.';
COMMENT ON COLUMN clean_data.equipment_serial.obj_level IS 'Object Level - Si activé, les informations de taxe sont requises sur les éléments de vente.';
COMMENT ON COLUMN clean_data.equipment_serial.group_id IS 'Group ID - Identifiant du groupe d''objets (valeurs utilisateur à partir de 100).';
COMMENT ON COLUMN clean_data.equipment_serial.cost_center IS 'Cost Center - Centre de coûts de l''objet.';
COMMENT ON COLUMN clean_data.equipment_serial.object_no IS 'Object No.';
COMMENT ON COLUMN clean_data.equipment_serial.category_id IS 'Category - Catégorie de l''objet.';
COMMENT ON COLUMN clean_data.equipment_serial.sup_mch_code IS 'Belongs to Object ID - Objet d''équipement parent dans la structure. Modifiable ultérieurement seulement s''il est vide ; n''accepte qu''une identité objet existante.';
COMMENT ON COLUMN clean_data.equipment_serial.sup_contract IS 'Belongs to Site - Site de l''objet parent. Non modifiable après sauvegarde.';
COMMENT ON COLUMN clean_data.equipment_serial.lu_name IS 'Lu Name - Type d''objet métier dans lequel les positions de carte sont définies.';
COMMENT ON COLUMN clean_data.equipment_serial.key_ref IS 'Key Ref - Valeur interne identifiant l''objet métier dans lequel les positions de carte sont définies.';
COMMENT ON COLUMN clean_data.equipment_serial.criticality IS 'Criticality - ID de la criticité de l''objet (impact sur la production ou d''autres activités ; sert à prioriser le travail).';
COMMENT ON COLUMN clean_data.equipment_serial.latest_transaction IS 'Latest Transaction.';
COMMENT ON COLUMN clean_data.equipment_serial.serial_state IS 'Serial State.';
COMMENT ON COLUMN clean_data.equipment_serial.operational_condition IS 'Operational Condition.';
COMMENT ON COLUMN clean_data.equipment_serial.operational_status IS 'Operational Status - Statut opérationnel de l''objet lorsque le travail est exécuté (valeurs des données de base Bon de travail et MP / Statut opérationnel).';
COMMENT ON COLUMN clean_data.equipment_serial.operational_status_db IS 'Operational Status Db - Valeur DB du statut opérationnel.';
COMMENT ON COLUMN clean_data.equipment_serial.manufactured_date IS 'Manufactured Date - Date de fabrication de l''objet ; doit précéder la date d''achat.';
COMMENT ON COLUMN clean_data.equipment_serial.owner IS 'Owner.';
COMMENT ON COLUMN clean_data.equipment_serial.ownership_db IS 'Ownership - Valeur DB : CUSTOMER OWNED, COMPANY OWNED, SUPPLIER LOANED, SUPPLIER RENTED, COMPANY RENTAL ASSET.';
COMMENT ON COLUMN clean_data.equipment_serial.ownership IS 'Ownership - Valeur client (spec : défaut Company Owned).';
COMMENT ON COLUMN clean_data.equipment_serial.location_mch_code IS 'Locational Parent - Identité de l''objet emplacement parent (bâtiment, étage/niveau, pièce).';
COMMENT ON COLUMN clean_data.equipment_serial.location_contract IS 'Locational Parent Site.';
COMMENT ON COLUMN clean_data.equipment_serial.from_mch_code IS 'From Object - Objet d''où provient l''objet actuel (objet-source, ex. système de tuyau).';
COMMENT ON COLUMN clean_data.equipment_serial.from_contract IS 'From Object Site - Site de l''objet-source.';
COMMENT ON COLUMN clean_data.equipment_serial.to_mch_code IS 'To Object - Objet de destination de l''objet actuel.';
COMMENT ON COLUMN clean_data.equipment_serial.to_contract IS 'To Object Site - Site de l''objet-destination.';
COMMENT ON COLUMN clean_data.equipment_serial.process_mch_code IS 'Process Object - Identité de l''objet traitement parent (conditions du traitement initial servant de base aux équipements connectés).';
COMMENT ON COLUMN clean_data.equipment_serial.process_contract IS 'Process Object Site - Site de l''objet traitement.';
COMMENT ON COLUMN clean_data.equipment_serial.pipe_mch_code IS 'Pipe System - Identité du système de tuyau parent (principales canalisations d''une installation).';
COMMENT ON COLUMN clean_data.equipment_serial.pipe_contract IS 'Pipe System Site - Site du système de tuyau.';
COMMENT ON COLUMN clean_data.equipment_serial.circuit_mch_code IS 'Circuit/Loop.';
COMMENT ON COLUMN clean_data.equipment_serial.circuit_contract IS 'Circuit/Loop Site.';
COMMENT ON COLUMN clean_data.equipment_serial.location_id IS 'Location ID - Emplacement à partir duquel le document d''origine est accessible.';
COMMENT ON COLUMN clean_data.equipment_serial.item_class_id IS 'Item Class Id - Classe d''élément contenant les données d''analyse des échecs (composants défaillants, causes, symptômes, actions correctives, fonctions, types de défaut).';
COMMENT ON COLUMN clean_data.equipment_serial.safe_access_code IS 'Safe Access Code - Exigence d''accessibilité de l''objet (accès sécurisé requis : pas de maintenance en fonctionnement). REQUIRED=Required, NOT_REQUIRED=Not Required.';
COMMENT ON COLUMN clean_data.equipment_serial.safe_access_code_db IS 'Safe Access Code - Valeur DB (REQUIRED / NOT_REQUIRED).';
COMMENT ON COLUMN clean_data.equipment_serial.process_class_id IS 'Process Class ID - Identifiant de classe de processus regroupant des classes d''élément pour une analyse RCM.';
COMMENT ON COLUMN clean_data.equipment_serial.not_applicable_set_date IS 'Not Applicable Set Date.';
COMMENT ON COLUMN clean_data.equipment_serial.not_applicable_set_user IS 'Not Applicable Set User.';
COMMENT ON COLUMN clean_data.equipment_serial.not_applicable_reason IS 'Not Applicable Reason.';
COMMENT ON COLUMN clean_data.equipment_serial.pm_prog_application_status IS 'Pm Prog Application Status (spec : défaut FALSE).';
COMMENT ON COLUMN clean_data.equipment_serial.applied_date IS 'Applied Date - Date d''application du programme MP à l''objet.';
COMMENT ON COLUMN clean_data.equipment_serial.applied_pm_program_rev IS 'Applied Pm Program Rev.';
COMMENT ON COLUMN clean_data.equipment_serial.applied_pm_program_id IS 'Applied Pm Program Id.';
COMMENT ON COLUMN clean_data.equipment_serial.is_geographic_object IS 'Is Geographic Object (spec : défaut FAUX).';
COMMENT ON COLUMN clean_data.equipment_serial.is_category_object IS 'Category Object - Indique si l''objet est défini comme objet de catégorie.';
COMMENT ON COLUMN clean_data.equipment_serial.cluster_id IS 'WPS Cluster ID - Cluster de maintenance auquel l''équipement appartient (groupe d''objets arrêtés ensemble pour maintenance).';
COMMENT ON COLUMN clean_data.equipment_serial.proxy_object_seq IS 'Proxy Object Seq.';