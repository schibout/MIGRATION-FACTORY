-- Source: /opt/data/ifs_files/Lot11_Maintenance_Opérations_V2.0.xlsx / feuille JT_TASK
-- Généré depuis /opt/data/ifs_model_analysis/ifs_fields_catalog.csv
CREATE SCHEMA IF NOT EXISTS clean_data;

CREATE TABLE IF NOT EXISTS clean_data.jt_task (
    task_seq numeric(20,0),
    order_no numeric(20,0),
    wo_no numeric(20,0),
    site varchar(5),
    company varchar(4000),
    organization_site varchar(5),
    organization_id varchar(8),
    priority_id varchar(10),
    work_type_id varchar(20),
    description varchar(200),
    long_description varchar(4000),
    created_by varchar(30),
    created_date timestamp without time zone,
    prepared_by varchar(20),
    reported_by varchar(20),
    reported_date timestamp without time zone,
    mpb_latest_update timestamp without time zone,
    planned_start timestamp without time zone,
    planned_finish timestamp without time zone,
    duration numeric(20,0),
    actual_start timestamp without time zone,
    actual_finish timestamp without time zone,
    earliest_start timestamp without time zone,
    latest_start timestamp without time zone,
    latest_finish timestamp without time zone,
    fixed_start timestamp without time zone,
    sla_order_no numeric(20,0),
    sla_order_line_no numeric(20,0),
    sla_latest_start timestamp without time zone,
    sla_latest_finish timestamp without time zone,
    responded_date timestamp without time zone,
    resolved_date timestamp without time zone,
    exclude_from_scheduling varchar(4000),
    exclude_from_scheduling_db varchar(20),
    adjusted_duration varchar(5),
    remark varchar(2000),
    internal_remark varchar(2000),
    action_taken varchar(4000),
    cancel_cause varchar(10),
    source_connection_lu_name varchar(4000),
    source_connection_lu_name_db varchar(20),
    source_connection_rowkey varchar(50),
    reported_connection_type varchar(4000),
    reported_connection_type_db varchar(20),
    reported_obj_conn_lu_name varchar(4000),
    reported_obj_conn_lu_name_db varchar(20),
    reported_obj_conn_rowkey varchar(50),
    actual_connection_type varchar(4000),
    actual_connection_type_db varchar(20),
    actual_obj_conn_lu_name varchar(4000),
    actual_obj_conn_lu_name_db varchar(20),
    actual_obj_conn_rowkey varchar(50),
    operational_status_id varchar(3),
    test_point_seq numeric(20,0),
    error_cause_long varchar(2000),
    error_type varchar(3),
    error_class varchar(3),
    error_discover_code varchar(3),
    error_symptom varchar(3),
    item_class_id varchar(10),
    error_cause varchar(3),
    item_class_function varchar(35),
    failing_component varchar(200),
    performed_action_id varchar(3),
    performed_work varchar(2000),
    customer_no varchar(20),
    vendor_no varchar(20),
    contract_id varchar(15),
    line_no numeric(20,0),
    contact varchar(100),
    contact_phone_no varchar(200),
    e_mail varchar(100),
    cust_order_type varchar(3),
    currency_code varchar(3),
    delivery_address varchar(50),
    cust_order_no varchar(12),
    authorize_code varchar(20),
    reference_no varchar(25),
    cust_warr_type varchar(20),
    cust_warranty numeric(20,0),
    obj_cust_warranty numeric(20,0),
    sup_warr_type varchar(20),
    sup_warranty numeric(20,0),
    obj_sup_warranty numeric(20,0),
    contractor_owner varchar(20),
    job_id numeric(20,0),
    maint_team_site varchar(5),
    team_id varchar(100),
    pre_accounting_id numeric(20,0),
    note_id numeric(20,0),
    source_ref1 varchar(30),
    source_ref2 varchar(30),
    source_ref3 varchar(30),
    source_ref4 varchar(30),
    master_task_seq numeric(20,0),
    duplicate_type varchar(4000),
    duplicate_type_db varchar(20),
    cost_code varchar(50),
    project_id varchar(4000),
    activity_seq numeric(20,0),
    quotation_no varchar(12),
    quotation_rev numeric(20,0),
    quo_task_seq numeric(20,0),
    mobile_task_id varchar(50),
    inspection_note varchar(2000),
    generate_note varchar(5),
    work_stage_id varchar(20),
    pm_group_id varchar(8),
    changed_date timestamp without time zone,
    allow_multiple_visits varchar(4000),
    allow_multiple_visits_db varchar(20),
    min_visit_duration numeric(20,0),
    srv_request_scope_id numeric(20,0),
    event_id varchar(30),
    event_period_seq numeric(20,0),
    hm_contract_id varchar(15),
    hm_contract_line_no numeric(20,0),
    postponed_reason varchar(2000),
    original_latest_finish timestamp without time zone,
    split_min_priority numeric(20,0),
    interrupt_priority numeric(20,0),
    interrupt_multiplier numeric(20,0),
    interrupt varchar(4000),
    interrupt_db varchar(20),
    duration_override numeric(20,0),
    activity_type_id varchar(20),
    service_organization_id varchar(20),
    service_delivery_unit varchar(20),
    displacement_priority numeric(20,0),
    dataset_id varchar(32),
    fmeca_anal_id numeric(20,0),
    fmeca_anal_revision numeric(20,0),
    function_id varchar(100),
    functional_failure_id varchar(100),
    failure_mode_id varchar(100),
    fmeca_failing_component varchar(40),
    trigger_seq_no numeric(20,0),
    effect varchar(4000),
    fmeca_cause varchar(3),
    fmeca_symptom varchar(3),
    external_id varchar(500),
    created_date_ofs numeric(20,0),
    reported_date_ofs numeric(20,0),
    mpb_latest_update_ofs numeric(20,0),
    planned_start_ofs numeric(20,0),
    planned_finish_ofs numeric(20,0),
    actual_start_ofs numeric(20,0),
    actual_finish_ofs numeric(20,0),
    earliest_start_ofs numeric(20,0),
    latest_start_ofs numeric(20,0),
    latest_finish_ofs numeric(20,0),
    fixed_start_ofs numeric(20,0),
    changed_date_ofs numeric(20,0),
    original_latest_finish_ofs numeric(20,0),
    custom_metric_id varchar(32),
    custom_metric_value numeric(20,0),
    report_proj_planned_cost varchar(4000),
    report_proj_planned_cost_db varchar(20),
    appointment_required varchar(5),
    warranty_assessment_id varchar(40),
    remotely_fulfilled varchar(5),
    scheduled_manually varchar(5),
    c_part_no varchar(25),
    c_serial_no varchar(50),
    c_risk_level numeric(20,0),
    state varchar(4000),
    objtype varchar(30),
    objversion varchar(40),
    objid varchar(10)
);

COMMENT ON TABLE clean_data.jt_task IS 'IFS JT_TASK - tâches/opérations de maintenance, source Lot11_Maintenance_Opérations_V2.0.xlsx';
COMMENT ON COLUMN clean_data.jt_task.task_seq IS 'N° tâche; N° ligne demande';
COMMENT ON COLUMN clean_data.jt_task.order_no IS 'N° cde; Numéro de commande du client, qui est l''identification principale de la source de la demande de modification de la configuration.';
COMMENT ON COLUMN clean_data.jt_task.wo_no IS 'N° BT; Affiche le numéro du bon de travail, une fois généré.';
COMMENT ON COLUMN clean_data.jt_task.site IS 'Site; Code court du site.';
COMMENT ON COLUMN clean_data.jt_task.company IS 'Société; Les informations sur la société source où le type de taux de devise connecté est mis à jour à l''aide du workflow.';
COMMENT ON COLUMN clean_data.jt_task.organization_site IS 'Site org. maint.; Site auquel l''organisation de maintenance appartient.';
COMMENT ON COLUMN clean_data.jt_task.organization_id IS 'Organisation maintenance; Identité de l''organisation de maintenance à laquelle l''employé est connecté. L''identité doit exister dans ***Données de base/Organisations de maintenance*** à partir de ***Organisation***. Pour saisir une nouvelle valeur, sélectionnez-la dans la liste de valeurs.';
COMMENT ON COLUMN clean_data.jt_task.priority_id IS 'ID priorité; Degré de priorité que vous voulez attribuer au bon de travail. Ce champ est lié à l''onglet Données base bon travail et PM/Priorités et autorise uniquement les valeurs saisies ici';
COMMENT ON COLUMN clean_data.jt_task.work_type_id IS 'Type de travail; Type de travail défini avec le modèle d''élément d''exécution.  Ce champ est lié à ***Données base ***bon travail et ***PM*** et autorise uniquement les valeurs saisies ici.';
COMMENT ON COLUMN clean_data.jt_task.description IS 'Description; Champ de texte libre utilisé pour entrer une description';
COMMENT ON COLUMN clean_data.jt_task.long_description IS 'Description détaillée; Des informations supplémentaires sur le travail devant être effectué peuvent être saisies dans ce champ.';
COMMENT ON COLUMN clean_data.jt_task.created_by IS 'Créé par; Le créateur d''un média est enregistré dans le champ **Créé par**. Le créateur obtient automatiquement l''accès à un média, qu''il soit privé ou non privé. Seul le créateur ou un administrateur système peut modifier le champ **Créé par**.';
COMMENT ON COLUMN clean_data.jt_task.created_date IS 'Date de création; Date de création de l''enregistrement. Cette valeur est déterminée automatiquement lors de la création de l''enregistrement. Ce champ ne peut pas être mis à jour.';
COMMENT ON COLUMN clean_data.jt_task.prepared_by IS 'Préparé par; La signature de la **personne** qui a préparé la commande d''isolation. Utilisez la liste de valeurs pour sélectionner une valeur appropriée. Si ce champ est vide, la signature de l''utilisateur connecté est extraite lorsque l''ordre d''isolation du statut est défini sur **Préparé**.';
COMMENT ON COLUMN clean_data.jt_task.reported_by IS 'Rapporté par; ID utilisateur de l''utilisateur qui a signalé les informations relatives aux temps d''arrêt de l''équipement.';
COMMENT ON COLUMN clean_data.jt_task.reported_date IS 'Date rapport; Date et heure auxquelles l''utilisateur a signalé les informations relatives aux temps d''arrêt de l''équipement.';
COMMENT ON COLUMN clean_data.jt_task.mpb_latest_update IS 'Dernière màj MPB';
COMMENT ON COLUMN clean_data.jt_task.planned_start IS 'Début prévu; Date à laquelle le travail planifié sur l''élément d''exécution doit commencer.';
COMMENT ON COLUMN clean_data.jt_task.planned_finish IS 'Fin prévue; Date à laquelle le travail planifié sur l''élément d''exécution doit être terminé.';
COMMENT ON COLUMN clean_data.jt_task.duration IS 'Durée; Nombre d''heures planifiées pour l''opération.';
COMMENT ON COLUMN clean_data.jt_task.actual_start IS 'Début réel; Lorsque le statut du projet devient **Démarré**, cette valeur est automatiquement définie sur la date du jour (date système). Cette valeur n''est pas modifiable.';
COMMENT ON COLUMN clean_data.jt_task.actual_finish IS 'Fin réelle; Date de fin réelle d''une activité. Lorsque ce champ est défini, la date du champ **Fin proche** est identique. Lorsque l''activité est définie sur fermée, l''option **Fin réelle** est définie sur **Fin au plus tôt** si elle n''a pas été définie manuellement. Cette valeur peut être modifiée.';
COMMENT ON COLUMN clean_data.jt_task.earliest_start IS 'Début au plus tôt; Date de début demandé pour le bon de travail. Ce n''est pas une date contraignante, mais une indication, par exemple, d''une échéance de date de début de l''activité connectée.';
COMMENT ON COLUMN clean_data.jt_task.latest_start IS 'Début au plus tard; Dernières date et heure auxquelles le début du travail sur la tâche a été planifié.';
COMMENT ON COLUMN clean_data.jt_task.latest_finish IS 'Fin au plus tard; Date de fin demandée pour le bon de travail. Ce n''est pas une date contraignante, mais une indication, par exemple, d''une échéance de date de fin de l''activité connectée.';
COMMENT ON COLUMN clean_data.jt_task.fixed_start IS 'Début fixé; Date et heure fixes auxquelles le bon de travail ou la demande de service doit commencer. Il s''agit d''une date contraignante, et la valeur indiquée dans ce champ remplace les date et heure de début demandées comme premier point de départ possible pour le bon de travail ou la demande de service. La valeur saisie dans ce champ sera transférée comme fixe dans le temps vers le moteur de planification PSO ou CBS, s''ils sont utilisés.';
COMMENT ON COLUMN clean_data.jt_task.sla_order_no IS 'N° commande CNS; Numéro unique de la commande de contrat de niveau de service (CNS) associée au bon de travail.';
COMMENT ON COLUMN clean_data.jt_task.sla_order_line_no IS 'N° ligne cde CNS; Numéro de ligne de la commande de contrat de niveau de service (CNS) connectée à l''opération de bon de travail.';
COMMENT ON COLUMN clean_data.jt_task.sla_latest_start IS 'Début au plus tard CNS; Dernières date et heure auxquelles le début du travail sur la tâche a été planifié.';
COMMENT ON COLUMN clean_data.jt_task.sla_latest_finish IS 'Fin au plus tard CNS; Dernières date et heure auxquelles la fin du travail sur la tâche a été planifiée.';
COMMENT ON COLUMN clean_data.jt_task.responded_date IS 'Date réponse; Cette date indique quand la ligne de commande CNS a effectivement reçu une réponse et elle est définie lorsque le statut de l''affectation de travail au plus tôt est défini sur **En attente sur place** ou lorsque le statut de la première opération de bon de travail connectée au CNS, est modifié par **Travail commencé**.';
COMMENT ON COLUMN clean_data.jt_task.resolved_date IS 'Date résolution; Date et heure de résolution de l''élément de pointage. Une valeur dans ce champ est définie automatiquement lorsque le statut de l''élément de pointage passe à **Résolu**.';
COMMENT ON COLUMN clean_data.jt_task.exclude_from_scheduling IS 'Exclure de la planification; Contrôle si l''opération BT doit être envoyée ou non au moteur de planification PSO. Si une opération BT est exclue de la planification, les opérations BT dépendantes seront également exclues. Les opérations BT exclues n''apparaîtront pas dans la liste des opérations BT de la console de répartition, mais les utilisateurs ont accès à la création d''affectations de travail via la commande Affecter les tâches ; ces affectations apparaîtront dans le diagramme de Gantt de la console de répartition.';
COMMENT ON COLUMN clean_data.jt_task.exclude_from_scheduling_db IS 'Exclure de la planification; Contrôle si l''opération BT doit être envoyée ou non au moteur de planification PSO. Si une opération BT est exclue de la planification, les opérations BT dépendantes seront également exclues. Les opérations BT exclues n''apparaîtront pas dans la liste des opérations BT de la console de répartition, mais les utilisateurs ont accès à la création d''affectations de travail via la commande Affecter les tâches ; ces affectations apparaîtront dans le diagramme de Gantt de la console de répartition.';
COMMENT ON COLUMN clean_data.jt_task.adjusted_duration IS 'Durée ajustée; L''option **Ajuster la durée** permet à un service d''archivage d''ajuster automatiquement la durée en fonction des durées moyennes historiques. Le service d''archivage calcule les durées à partir des tâches terminées du même jeu de données, du même type d''activité et du même emplacement. La durée calculée est ensuite utilisée lorsque l''option **Ajuster la durée** est activée sur les tâches du même jeu de données, du même emplacement et du même type de travail. L''option **Ajuster la durée** se trouve dans les pages ***Tâche de travail***. Le champ de durée se trouve sur les tâches dans l''onglet ***Informations de planification/Allocations***. La valeur **Oui** ou **Non** du champ **Durée ajustée**, dans ***Informations de planification/Allocations*** indique si la valeur a été ajustée ou non.';
COMMENT ON COLUMN clean_data.jt_task.remark IS 'Remarque; Zone de texte facultative pour vos commentaires.';
COMMENT ON COLUMN clean_data.jt_task.internal_remark IS 'Remarque interne; Toute information supplémentaire concernant l''employé. Ces informations ne sont affichées nulle part ailleurs dans le système.';
COMMENT ON COLUMN clean_data.jt_task.action_taken IS 'Action entreprise; Description de l''action prise.';
COMMENT ON COLUMN clean_data.jt_task.cancel_cause IS 'Raison d''annulation; ID de la cause d''annulation. Ce champ est obligatoire et ne peut être mis à jour. La longueur maximale du champ est de 10 caractères.';
COMMENT ON COLUMN clean_data.jt_task.source_connection_lu_name IS 'Nom UL connexion source';
COMMENT ON COLUMN clean_data.jt_task.source_connection_lu_name_db IS 'Nom UL connexion source';
COMMENT ON COLUMN clean_data.jt_task.source_connection_rowkey IS 'Clé interne connexion source';
COMMENT ON COLUMN clean_data.jt_task.reported_connection_type IS 'Type connexion déclarée; Ce champ indique l''origine de l''opération de bon de travail et si l''objet déclaré est un objet de type Equipement, VIM, Actif linéaire, Unité compatible, Catégorie, Conception ou Outil/Equipement. Lors de la création d''une opération de bon de travail sur cette page, seules les connexions de type **EQUIPEMENT**, **CATEGORIE**, **OUTIL/EQUIPEMENT** ou **ACTIF LINEAIRE** peuvent être utilisées. Les types de connexion déclarée possibles sont : **EQUIPEMENT**, **VIM**, **ACTIF LINEAIRE**, **UNITE COMPATIBLE**, **CATEGORIE**, **OBJET DE CONCEPTION**, **GROUPE DE TRAVAIL** et **OUTIL/EQUIPEMENT**.';
COMMENT ON COLUMN clean_data.jt_task.reported_connection_type_db IS 'Type connexion déclarée; Ce champ indique l''origine de l''opération de bon de travail et si l''objet déclaré est un objet de type Equipement, VIM, Actif linéaire, Unité compatible, Catégorie, Conception ou Outil/Equipement. Lors de la création d''une opération de bon de travail sur cette page, seules les connexions de type **EQUIPEMENT**, **CATEGORIE**, **OUTIL/EQUIPEMENT** ou **ACTIF LINEAIRE** peuvent être utilisées. Les types de connexion déclarée possibles sont : **EQUIPEMENT**, **VIM**, **ACTIF LINEAIRE**, **UNITE COMPATIBLE**, **CATEGORIE**, **OBJET DE CONCEPTION**, **GROUPE DE TRAVAIL** et **OUTIL/EQUIPEMENT**.';
COMMENT ON COLUMN clean_data.jt_task.reported_obj_conn_lu_name IS 'Nom UL connectée obj déclaré';
COMMENT ON COLUMN clean_data.jt_task.reported_obj_conn_lu_name_db IS 'Nom UL connectée obj déclaré';
COMMENT ON COLUMN clean_data.jt_task.reported_obj_conn_rowkey IS 'Clé ligne connectée obj déclaré';
COMMENT ON COLUMN clean_data.jt_task.actual_connection_type IS 'Type connexion réelle; Ce champ indique le type d''objet sur lequel le travail lié à l''opération de bon de travail est réellement effectué. Selon le type de connexion réelle, l''ID objet réel peut être un objet de type Equipement, VIM, Actif linéaire, Unité compatible, Catégorie, Conception ou Outil/Equipement. Les types de connexion réelle possibles sont : **EQUIPEMENT**, **VIM**, **ACTIF LINEAIRE**, **UNITE COMPATIBLE**, **CATEGORIE**, **OBJET DE CONCEPTION**, **GROUPE DE TRAVAIL** et **OUTIL/EQUIPEMENT**. Ce champ ne peut être modifié que lorsque le type de connexion indiqué est **EQUIPEMENT**, **ACTIF LINEAIRE** ou **CATEGORIE**.';
COMMENT ON COLUMN clean_data.jt_task.actual_connection_type_db IS 'Type connexion réelle; Ce champ indique le type d''objet sur lequel le travail lié à l''opération de bon de travail est réellement effectué. Selon le type de connexion réelle, l''ID objet réel peut être un objet de type Equipement, VIM, Actif linéaire, Unité compatible, Catégorie, Conception ou Outil/Equipement. Les types de connexion réelle possibles sont : **EQUIPEMENT**, **VIM**, **ACTIF LINEAIRE**, **UNITE COMPATIBLE**, **CATEGORIE**, **OBJET DE CONCEPTION**, **GROUPE DE TRAVAIL** et **OUTIL/EQUIPEMENT**. Ce champ ne peut être modifié que lorsque le type de connexion indiqué est **EQUIPEMENT**, **ACTIF LINEAIRE** ou **CATEGORIE**.';
COMMENT ON COLUMN clean_data.jt_task.actual_obj_conn_lu_name IS 'Nom UL connectée obj réel';
COMMENT ON COLUMN clean_data.jt_task.actual_obj_conn_lu_name_db IS 'Nom UL connectée obj réel';
COMMENT ON COLUMN clean_data.jt_task.actual_obj_conn_rowkey IS 'Clé interne connectée obj réel';
COMMENT ON COLUMN clean_data.jt_task.operational_status_id IS 'Statut opérationnel; Statut opérationnel de l''objet lorsque le travail est exécuté. Ce champ est lié à ***Bon de travail et données de base MP/Statut opérationnel*** et n''accepte que les valeurs qui y sont saisies.';
COMMENT ON COLUMN clean_data.jt_task.test_point_seq IS 'Séq point test';
COMMENT ON COLUMN clean_data.jt_task.error_cause_long IS 'Détails cause défaut';
COMMENT ON COLUMN clean_data.jt_task.error_type IS 'Type de défaut; ID du type de défaut. L''identité peut être utilisée dans ***Rapport du bon de travail*** pour indiquer le type de défaut de l''action sur le bon de travail.';
COMMENT ON COLUMN clean_data.jt_task.error_class IS 'ID classe; Identité du motif du défaut utilisée pour la classification du défaut signalé';
COMMENT ON COLUMN clean_data.jt_task.error_discover_code IS 'ID découverte; Code détection qui affiche comment le défaut a été découvert. Ce champ est lié aux valeurs définies sur la page **Bon de travail** et **Données de base MP/Détections** et n''accepte que les valeurs qui y sont saisies.';
COMMENT ON COLUMN clean_data.jt_task.error_symptom IS 'ID symptôme; Code du symptôme. Le code peut être utilisé pour indiquer les symptômes du défaut signalé. Ce champ est lié à ***Symptômes*** et accepte uniquement les valeurs qui y sont saisies. Utilisez la Liste de valeurs pour sélectionner la valeur adéquate.';
COMMENT ON COLUMN clean_data.jt_task.item_class_id IS 'ID classe élément; Identité de la classe d''élément utilisée pour contenir les données d''analyse des échecs. Une classe d''élément peut contenir des données telles que les composants défaillants, les causes, les symptômes, les actions correctives, les fonctions et les types de défaut.';
COMMENT ON COLUMN clean_data.jt_task.error_cause IS 'Raison; Une ou plusieurs conditions résultant en défaillances de conception ou de fabrication Les défaillances principales ont seulement une cause, mais la plupart en ont plusieurs.';
COMMENT ON COLUMN clean_data.jt_task.item_class_function IS 'Fonction; La fonction, le processus ou le fonctionnement de l''élément analysé dans le cadre de l''AMDEC.';
COMMENT ON COLUMN clean_data.jt_task.failing_component IS 'Composant défaillant; Identité du composant dans lequel un défaut peut survenir. Un seul composant défaillant peut être connecté à chaque motif dans la structure d''analyse des défaillances.';
COMMENT ON COLUMN clean_data.jt_task.performed_action_id IS 'Action exécutée; Affiche le type et la description de l''action saisie pour classification du défaut corrigé sur l''opération de bon de travail.';
COMMENT ON COLUMN clean_data.jt_task.performed_work IS 'Travail exécuté; Ce champ peut être utilisé pour saisir des informations sur le travail qui a été effectué sur l''opération de bon de travail.';
COMMENT ON COLUMN clean_data.jt_task.customer_no IS 'N° client; Le nom abrégé ou le numéro d''identification du client. Vous pouvez saisir cette valeur manuellement ou sélectionner le client dans la Liste de valeurs.';
COMMENT ON COLUMN clean_data.jt_task.vendor_no IS 'Contractant; Identité de l''entrepreneur ou du fournisseur de travail externe qui exécute le travail.';
COMMENT ON COLUMN clean_data.jt_task.contract_id IS 'N° Contrat; Identité du contrat de location. Il est au format alphanumérique. Vous ne pouvez pas modifier l''identité après avoir sauvegardé les informations. Vous pouvez supprimer toutes les informations pour le contrat si l''information n''a pas été utilisée dans le système. L''identité de location doit être unique pour chaque société et ne peut pas exister dans ***IFS/Comptabilité location***.';
COMMENT ON COLUMN clean_data.jt_task.line_no IS 'N° ligne; Ordre de tri des événements généré par le système.';
COMMENT ON COLUMN clean_data.jt_task.contact IS 'Relation; Identité ou nom de la personne à contacter pour la demande de service ou le bon de travail. Lors d''une nouvelle saisie, saisissez les informations facultatives.';
COMMENT ON COLUMN clean_data.jt_task.contact_phone_no IS 'N° tél contact';
COMMENT ON COLUMN clean_data.jt_task.e_mail IS '!>E-mail; Adresse e-mail de l''utilisateur de l''organisation de support. Elle est automatiquement renseignée lors de la sélection de l''utilisateur.';
COMMENT ON COLUMN clean_data.jt_task.cust_order_type IS 'Type cde client; Type de commande client qui sera utilisé lors de la création de la commande client. Le type de commande client contrôle le processus de commande client et définit les étapes du processus de commande client qui sont exécutées automatiquement et celles qui sont exécutées manuellement. Les étapes sont définies dans la fenêtre données de base Type commande client. Le type de commande client SEO est utilisé et requis pour le processus de gestion des services.';
COMMENT ON COLUMN clean_data.jt_task.currency_code IS 'Code devise; Le code devise est un code ISO. La liste des valeurs affiche les codes ISO spécifiés dans ***Configuration d''IFS Cloud/Application Base***. Le nom de la devise est aussi affiché.';
COMMENT ON COLUMN clean_data.jt_task.delivery_address IS 'Adresse livraison; Adresse de livraison du client à laquelle les marchandises seront envoyées. L''adresse de livraison par défaut spécifiée dans l''onglet ***Compte-CRM/Adresse*** est ajoutée automatiquement lorsque l''opportunité est créée.';
COMMENT ON COLUMN clean_data.jt_task.cust_order_no IS 'Numéro cde client';
COMMENT ON COLUMN clean_data.jt_task.authorize_code IS 'Coordinateur; L''ID du coordinateur généralement responsable des dossiers du comité d''examen des produits (CEP).';
COMMENT ON COLUMN clean_data.jt_task.reference_no IS 'N° référence; Tout numéro de référence est utilisé pour relier des messages d''annonce d''expédition. Par exemple, lorsqu''une commande est divisée en plusieurs messages d''annonce d''expédition.';
COMMENT ON COLUMN clean_data.jt_task.cust_warr_type IS 'Type de garantie client';
COMMENT ON COLUMN clean_data.jt_task.cust_warranty IS 'Garantie client';
COMMENT ON COLUMN clean_data.jt_task.obj_cust_warranty IS 'Garantie client obj';
COMMENT ON COLUMN clean_data.jt_task.sup_warr_type IS 'Type garantie fournisseur';
COMMENT ON COLUMN clean_data.jt_task.sup_warranty IS 'Garantie fourn.';
COMMENT ON COLUMN clean_data.jt_task.obj_sup_warranty IS 'Garantie fourn obj';
COMMENT ON COLUMN clean_data.jt_task.contractor_owner IS 'Coordinateur contractant; Identité du coordinateur du contractant auquel l''opération de bon de travail est sous-traitée/attribué.';
COMMENT ON COLUMN clean_data.jt_task.job_id IS 'ID tâche; Un numéro d''identification interne de la tâche de fond. Ce numéro est automatiquement attribué par IFS Cloud.';
COMMENT ON COLUMN clean_data.jt_task.maint_team_site IS 'Site équipe maint.';
COMMENT ON COLUMN clean_data.jt_task.team_id IS 'ID équipe; ID de l''équipe. Si une équipe est saisie, les opérations du bon de travail non affectées ayant les exigences de cette équipe s''afficheront dans la page ***Portails techniques/Tâches non affectées***. La saisie d''une valeur dans ce champ est facultative. Utilisez la liste de valeurs pour sélectionner une valeur valide.';
COMMENT ON COLUMN clean_data.jt_task.pre_accounting_id IS 'ID précompta.';
COMMENT ON COLUMN clean_data.jt_task.note_id IS 'ID note';
COMMENT ON COLUMN clean_data.jt_task.source_ref1 IS 'Réf d''origine 1; Référence à l''origine, en fonction du type de référence de l''origine. Par exemple, le numéro d''ordre de fabrication est affiché si la référence d''origine est de type Commande d''achat.

Remarque : applicable aux ordres de fabrication ouverts, rattachés à l''unité de manutention. Une fois les articles reçus en stock, la référence est effacée.';
COMMENT ON COLUMN clean_data.jt_task.source_ref2 IS 'Réf d''origine 2; Référence à l''origine, en fonction du type de référence de l''origine. Par exemple, le numéro de libération de l''ordre de fabrication est affiché si la référence d''origine est de type Commande d''achat.

Remarque : applicable aux ordres de fabrication ouverts, rattachés à l''unité de manutention. Une fois les articles reçus en stock, la référence est effacée.';
COMMENT ON COLUMN clean_data.jt_task.source_ref3 IS 'Réf d''origine 3; Référence à l''origine, le cas échéant. Les données spécifiques affichées sont liées à la valeur dans la colonne Type référence origine. Par exemple, le numéro de séquence d''ordre de fabrication est affiché si la référence d''origine est de type Commande d''achat.

Remarque : applicable aux ordres de fabrication ouverts, rattachés à l''unité de manutention. Une fois les articles reçus en stock, la référence est effacée.';
COMMENT ON COLUMN clean_data.jt_task.source_ref4 IS 'Réf d''origine 4; Selon le type d''ordre, une référence de l''origine est indiquée. Le numéro de ligne d''article est affiché pour les ordres de fabrication et les bons de travaux. Le numéro de séquence de demande diverse est affiché pour les projets. Le numéro d''élément est affiché pour les éléments de livraison de projet.';
COMMENT ON COLUMN clean_data.jt_task.master_task_seq IS 'Tâche maître';
COMMENT ON COLUMN clean_data.jt_task.duplicate_type IS 'Type duplicata; Type de duplication pour l''opération de bon de travail. Les valeurs valides sont **Maître** et **Double**.';
COMMENT ON COLUMN clean_data.jt_task.duplicate_type_db IS 'Type duplicata; Type de duplication pour l''opération de bon de travail. Les valeurs valides sont **Maître** et **Double**.';
COMMENT ON COLUMN clean_data.jt_task.cost_code IS 'Code coût; Identité du code de coût. L''identité est utilisée lorsque vous déclarez un coût sur une opération de bon de travail.';
COMMENT ON COLUMN clean_data.jt_task.project_id IS 'ID projet; Identifiant du projet associé à l''unité compatible. Utilisez la liste de valeurs pour sélectionner un projet adéquat parmi les projets appartenant à la société à laquelle l''unité compatible est associée. Les projets sont créés dans ***Bases du projet/Programme du projet***.';
COMMENT ON COLUMN clean_data.jt_task.activity_seq IS 'Séq activité; Le numéro de séquence de l''activité de projet d''approvisionnement liée à l''élément d''exécution de l''unité compatible.';
COMMENT ON COLUMN clean_data.jt_task.quotation_no IS 'N° d''offre; Le numéro d''identification du devis commercial. Quand vous saisissez un nouveau devis, vous pouvez saisir manuellement le numéro de devis ou laisser le système créer le numéro automatiquement. L''ID du groupe des coordinateurs et la série de numéros utilisée sont déterminés par le groupe de coordinateurs de l''utilisateur. Dès que le devis est créé, le numéro ne peut pas être changé.';
COMMENT ON COLUMN clean_data.jt_task.quotation_rev IS 'Rév. devis; Numéro de révision du devis de service. Le numéro de révision est généré lorsque le devis est créé ou lorsqu’une nouvelle révision est générée. C''est un numéro séquentiel qui commence par 1 pour chaque devis et est incrémenté de 1. Il ne peut pas être modifié manuellement.';
COMMENT ON COLUMN clean_data.jt_task.quo_task_seq IS 'Séq tâche devis';
COMMENT ON COLUMN clean_data.jt_task.mobile_task_id IS 'ID tâche mobile; ID de l''opération de bon de travail dans le client mobile.';
COMMENT ON COLUMN clean_data.jt_task.inspection_note IS 'Note de contrôle; Note de contrôle saisie sur l''opération BT ou l''étape de l''opération BT dans le bon de travail généré pour l''action MP. Cette note de contrôle s''affichera sur la ligne du plan de maintenance correspondant à l''opération BT ou à l''étape de l''opération BT. Si la case **Générer notes** est cochée avec les notes de contrôle sur l''opération BT ou à l''étape de l''opération BT, la note de contrôle sera également incluse à l''opération BT correspondante ou à l''étape de l''opération BT dans le bon de travail suivant.';
COMMENT ON COLUMN clean_data.jt_task.generate_note IS 'Générer note; Indique si le texte figurant dans le champ **Note de contrôle**, qui a été transféré de l''opération de bon de travail ou de l''étape de l''opération de bon de travail vers ***Plan de maintenance*** sur la page ***Action MP***, sera aussi inclus dans le prochain bon de travail généré pour l''action MP.';
COMMENT ON COLUMN clean_data.jt_task.work_stage_id IS 'ID étape travail; Etape de travail du **bon de travail**. Celle-ci est extraite de la **tâche standard** et peut être modifiée ici.';
COMMENT ON COLUMN clean_data.jt_task.pm_group_id IS 'ID groupe MP; Groupe auquel l''action MP est connectée. Ce champ est lié à ***Bon de travail et données de base MP*** et n''accepte que les valeurs qui y sont saisies. Cliquez sur **Liste** pour choisir une valeur appropriée.';
COMMENT ON COLUMN clean_data.jt_task.changed_date IS 'Date modifiée';
COMMENT ON COLUMN clean_data.jt_task.allow_multiple_visits IS 'Autoriser multiples visites; Si cette option est activée, par défaut, il est permis de diviser le travail en plusieurs visites dans la **tâche de demande de travail** lors de la planification. La valeur peut être remplacée dans la page **Demande de tâche de travail**/ **Demande de tâche de travail - planification et allocation**.';
COMMENT ON COLUMN clean_data.jt_task.allow_multiple_visits_db IS 'Autoriser multiples visites; Si cette option est activée, par défaut, il est permis de diviser le travail en plusieurs visites dans la **tâche de demande de travail** lors de la planification. La valeur peut être remplacée dans la page **Demande de tâche de travail**/ **Demande de tâche de travail - planification et allocation**.';
COMMENT ON COLUMN clean_data.jt_task.min_visit_duration IS 'Durée min visite (heures); Durée minimale d''une visite. Aucune visite d''une chaîne de plusieurs visites ne sera planifiée pour une durée inférieure à cette valeur. La valeur est saisie par défaut sur les nouvelles opérations de bon de travail avec ce type d''activité.';
COMMENT ON COLUMN clean_data.jt_task.srv_request_scope_id IS 'ID de portée de la dde SRV';
COMMENT ON COLUMN clean_data.jt_task.event_id IS 'ID événement; ID unique de l''événement. Cet ID d''événement est utilisé dans la configuration de l''entité d''événement et sera visible dans le journal des événements avec la description.';
COMMENT ON COLUMN clean_data.jt_task.event_period_seq IS 'N° période événement; Numéro de séquence donné à une certaine période de date pour l''événement. Ce numéro est utilisé pour déterminer la période de date d''événement liée à une tâche de travail.';
COMMENT ON COLUMN clean_data.jt_task.hm_contract_id IS 'Contrat de maintenance lourde';
COMMENT ON COLUMN clean_data.jt_task.hm_contract_line_no IS 'N° ligne contrat maintenance lourde';
COMMENT ON COLUMN clean_data.jt_task.postponed_reason IS 'Motif de report; La raison d''avancer la date de **dernière fin** si la tâche de travail a déjà été **préparée**. La saisie d''un motif est obligatoire.';
COMMENT ON COLUMN clean_data.jt_task.original_latest_finish IS 'Fin d''origine au plus tard; La date/heure d''origine définie comme la dernière fin de la tâche de travail. Ce champ de date est défini à la suite de l''extension de la date de **dernière fin** déjà définie sur une tâche de travail avec un type de travail configuré pour enregistrer la raison du report.';
COMMENT ON COLUMN clean_data.jt_task.split_min_priority IS 'Priorité min. fractionnée; Toute opération BT fractionnable peut se voir attribuer une priorité de fractionnement minimale. Elle ne sera alors fractionnée dans une équipe ultérieure que si la priorité de fractionnement de l''équipe est au moins la priorité minimale. La priorité de fractionnement sur l''équipe est définie à l''aide d''un attribut d''équipe appelé SPLIT_PRIORITY.
Supposons que les équipes du lundi puissent toutes se voir attribuer une priorité fractionnée de 1, tandis que les autres équipes de la semaine ont une priorité fractionnée de 2. Les opérations BT qui doivent être accomplies au cours d''une seule semaine se voient alors attribuer une priorité de fractionnement minimale de 2, ce qui signifie qu''elles ne peuvent pas être fractionnées sur le week-end et sur l''équipe du lundi. Pendant ce temps, les autres opérations BT fractionnables ont une priorité partagée de 1 et peuvent donc être fractionnées pendant le week-end. De même, les opérations BT autorisées à s''int';
COMMENT ON COLUMN clean_data.jt_task.interrupt_priority IS 'Priorité interruption; Spécifie la priorité d''une opération BT de ce type lorsqu''il s''agit de déterminer s''il convient de l''utiliser pour interrompre une opération BT fractionnable. Cela s''applique uniquement si Interruption est défini sur Oui.';
COMMENT ON COLUMN clean_data.jt_task.interrupt_multiplier IS 'Multiplicateur interruption; Il est possible d''exercer un contrôle plus fin sur le coût appliqué lorsqu''une opération BT est interrompue par une autre opération BT. Cette opération s''effectue à l''aide d''un multiplicateur sur le coût du fractionnement qui dépend de l''opération BT interrompue. La valeur par défaut est 1, mais peut être définie sur n''importe quelle valeur supérieure ou égale à 0. Par exemple, si nous appliquons un *Coût de planification du fractionnement* de 100, mais que nous ne souhaitons appliquer aucune pénalité si l''opération BT est interrompue par une pause. Nous pouvons définir le multiplicateur de partage sur la pause sur 0 pour y parvenir, ce qui signifie que le coût partagé serait de 0. 
Supposons que nous avons également un rendez-vous qui permet d''interrompre la planification, mais que nous souhaitons le faire uniquement s''il n''y a pas d''autre alternative. Nous pouvons donc définir le multiplicateur de partage sur l''opération BT du rendez-vous à p';
COMMENT ON COLUMN clean_data.jt_task.interrupt IS 'Interruption; Définit si les opérations BT ou les pauses de ce type peuvent être utilisées pour fractionner une opération BT, où Autoriser plusieurs visites est défini sur Oui. Lorsque Autoriser plusieurs visites est défini sur Oui pour une opération BT, la planification est libre de fractionner l''opération BT dans des équipes consécutives ou autour d''activités marquées comme pouvant être interrompues.';
COMMENT ON COLUMN clean_data.jt_task.interrupt_db IS 'Interruption; Définit si les opérations BT ou les pauses de ce type peuvent être utilisées pour fractionner une opération BT, où Autoriser plusieurs visites est défini sur Oui. Lorsque Autoriser plusieurs visites est défini sur Oui pour une opération BT, la planification est libre de fractionner l''opération BT dans des équipes consécutives ou autour d''activités marquées comme pouvant être interrompues.';
COMMENT ON COLUMN clean_data.jt_task.duration_override IS 'Remplacement durée; Si elle est spécifiée, cette durée sera utilisée directement comme durée attendue de l''opération BT, en ignorant tout autre paramètre affectant la durée (Ajuster la durée, maîtrise des ressources, etc.).';
COMMENT ON COLUMN clean_data.jt_task.activity_type_id IS 'Type d''activité; Le type de coût assigné à l''activité. Le type de coût est défini quand vous enregistrez l''activité, et peut avoir une des valeurs suivantes : **Unité liée à l''activité**, **Lot lié à l''activité**, **Produit lié à l''activité**, **Installation nécessaire à l''activité** ou **Non utilisé**.';
COMMENT ON COLUMN clean_data.jt_task.service_organization_id IS 'Organisation du service; Organisation de services qui possède la propriété organisationnelle de la ressource.';
COMMENT ON COLUMN clean_data.jt_task.service_delivery_unit IS 'Unité de livraison service; Unité de prestation de services au sein de l''organisation de services qui est propriétaire organisationnel de la ressource.';
COMMENT ON COLUMN clean_data.jt_task.displacement_priority IS 'Priorité de déplacement; Lors de la prise de rendez-vous pour cette activité, PSO tentera de déplacer toute autre activité de cette priorité ou d''une priorité inférieure.';
COMMENT ON COLUMN clean_data.jt_task.dataset_id IS 'ID ens. données; Identifiant unique pour l''ensemble de données. Un ensemble de données est utilisé pour définir un ensemble discret de données à planifier par IFS Planning and Scheduling Optimization.';
COMMENT ON COLUMN clean_data.jt_task.fmeca_anal_id IS 'ID analyse; L''ID de l''analyse flux de trésorerie pour l''exposition du flux de trésorerie créée.';
COMMENT ON COLUMN clean_data.jt_task.fmeca_anal_revision IS 'Révision; Numéro de révision de l''article parent.';
COMMENT ON COLUMN clean_data.jt_task.function_id IS 'Fonction; La fonction, le processus ou le fonctionnement de l''élément analysé dans le cadre de l''AMDEC.';
COMMENT ON COLUMN clean_data.jt_task.functional_failure_id IS 'Défaillance fonctionnelle';
COMMENT ON COLUMN clean_data.jt_task.failure_mode_id IS 'Mode échec';
COMMENT ON COLUMN clean_data.jt_task.fmeca_failing_component IS 'Composant défectueux FMECA';
COMMENT ON COLUMN clean_data.jt_task.trigger_seq_no IS 'N° séq déclencheur';
COMMENT ON COLUMN clean_data.jt_task.effect IS 'Effets';
COMMENT ON COLUMN clean_data.jt_task.fmeca_cause IS 'Cause FMECA';
COMMENT ON COLUMN clean_data.jt_task.fmeca_symptom IS 'Symptôme FMECA';
COMMENT ON COLUMN clean_data.jt_task.external_id IS 'Id externe; L''identifiant externe de l''objet est affiché, le cas échéant.';
COMMENT ON COLUMN clean_data.jt_task.created_date_ofs IS 'Décalage horaire de la date de création du serveur';
COMMENT ON COLUMN clean_data.jt_task.reported_date_ofs IS 'Décalage horaire de la date de rapport du serveur';
COMMENT ON COLUMN clean_data.jt_task.mpb_latest_update_ofs IS 'Décalage horaire de dernière mise à jour MPB du serveur';
COMMENT ON COLUMN clean_data.jt_task.planned_start_ofs IS 'Décalage horaire de démarrage prévu du serveur';
COMMENT ON COLUMN clean_data.jt_task.planned_finish_ofs IS 'Décalage horaire de fin prévue du serveur';
COMMENT ON COLUMN clean_data.jt_task.actual_start_ofs IS 'Décalage horaire de démarrage réel du serveur';
COMMENT ON COLUMN clean_data.jt_task.actual_finish_ofs IS 'Décalage horaire de fin réelle du serveur';
COMMENT ON COLUMN clean_data.jt_task.earliest_start_ofs IS 'Décalage horaire du démarrage au plus tôt du serveur';
COMMENT ON COLUMN clean_data.jt_task.latest_start_ofs IS 'Décalage horaire de démarrage au plus tard du serveur';
COMMENT ON COLUMN clean_data.jt_task.latest_finish_ofs IS 'Décalage horaire de fin au plus tard du serveur';
COMMENT ON COLUMN clean_data.jt_task.fixed_start_ofs IS 'Décalage horaire du démarrage prévu du serveur';
COMMENT ON COLUMN clean_data.jt_task.changed_date_ofs IS 'Décalage horaire de la date de modification du serveur';
COMMENT ON COLUMN clean_data.jt_task.original_latest_finish_ofs IS 'Décalage horaire de fin au plus tard d''origine du serveur';
COMMENT ON COLUMN clean_data.jt_task.custom_metric_id IS 'ID mesure personnalisée';
COMMENT ON COLUMN clean_data.jt_task.custom_metric_value IS 'Valeur de mesure personnalisée';
COMMENT ON COLUMN clean_data.jt_task.report_proj_planned_cost IS 'Report Proj Planned Cost';
COMMENT ON COLUMN clean_data.jt_task.report_proj_planned_cost_db IS 'Report Proj Planned Cost';
COMMENT ON COLUMN clean_data.jt_task.appointment_required IS 'Appointment Required';
COMMENT ON COLUMN clean_data.jt_task.warranty_assessment_id IS 'Warranty Assessment ID';
COMMENT ON COLUMN clean_data.jt_task.remotely_fulfilled IS 'Remotely Fulfilled';
COMMENT ON COLUMN clean_data.jt_task.scheduled_manually IS 'Scheduled Manually';
COMMENT ON COLUMN clean_data.jt_task.c_part_no IS 'C Part No';
COMMENT ON COLUMN clean_data.jt_task.c_serial_no IS 'C Serial No';
COMMENT ON COLUMN clean_data.jt_task.c_risk_level IS 'C Risk Level';
COMMENT ON COLUMN clean_data.jt_task.state IS 'Statut; Etat actuel des critères **(En cours** ou **Prêt**)';
COMMENT ON COLUMN clean_data.jt_task.objtype IS '0; 0';
COMMENT ON COLUMN clean_data.jt_task.objversion IS '0; 0';
COMMENT ON COLUMN clean_data.jt_task.objid IS '0; 0';
