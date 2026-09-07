-- =====================================================================
-- clean_data.ifs_model_project
-- ---------------------------------------------------------------------
-- Stocke le PROJET MODÈLE IFS (référence / template) tel qu'il existe
-- dans IFS Cloud : MOD_PRJ_TN - MODEL PROJET TRAVAUX NEUFS.
--
-- Table À PLAT : un node_type discrimine le niveau de la hiérarchie
--   SUB_PROJECT   -> sous-projet (10 / 20 / 30)
--   ACTIVITY      -> activité rattachée à un sous-projet (activity_no)
--   ACTIVITY_CLASS-> activity class d'une activité (PORTE / STATUT_PORTE / QUAL_PORTE) + value
--
-- On reconstruit l'arbre via (sub_project_id, activity_no, activity_class_id).
--
-- Sert de référence pour l'ETL (structure standard des activités/classes,
-- valeurs par défaut, ordre).
-- =====================================================================
CREATE TABLE IF NOT EXISTS clean_data.ifs_model_project (
    id                  SERIAL PRIMARY KEY,
    project_id          VARCHAR(20)  NOT NULL,      -- 'MOD_PRJ_TN'
    project_name        VARCHAR(100),               -- 'MODEL PROJET TRAVAUX NEUFS'
    node_type           VARCHAR(20)  NOT NULL,      -- SUB_PROJECT | ACTIVITY | ACTIVITY_CLASS
    sub_project_id      VARCHAR(20),                -- '10' / '20' / '30'
    sub_project_desc    VARCHAR(200),               -- 'Suivi des Portes' ...
    activity_no         VARCHAR(20),                -- '000-P0', '001-LOT 1', 'REP', '001-H_ING'
    activity_desc       VARCHAR(200),               -- 'Porte P0', 'Lot 1' ...
    activity_class_id   VARCHAR(30),                -- 'PORTE' / 'STATUT_PORTE' / 'QUAL_PORTE'
    activity_class_desc VARCHAR(200),               -- 'Numéro de porte' ...
    value               VARCHAR(255),               -- '2 - Porte P2', '0 - à Définir', '0 - 0'
    validity            VARCHAR(20),                -- 'GLOBAL'
    sort_order          INTEGER,
    created_at          TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

COMMENT ON TABLE clean_data.ifs_model_project IS
'Projet modèle IFS (MOD_PRJ_TN - MODEL PROJET TRAVAUX NEUFS) à plat : sous-projets, activités et activity classes de référence.';

-- Rechargement idempotent
TRUNCATE TABLE clean_data.ifs_model_project RESTART IDENTITY;

-- ---------------------------------------------------------------------
-- SOUS-PROJETS
-- ---------------------------------------------------------------------
INSERT INTO clean_data.ifs_model_project
    (project_id, project_name, node_type, sub_project_id, sub_project_desc, sort_order)
VALUES
    ('MOD_PRJ_TN', 'MODEL PROJET TRAVAUX NEUFS', 'SUB_PROJECT', '10', 'Suivi des Portes',       10),
    ('MOD_PRJ_TN', 'MODEL PROJET TRAVAUX NEUFS', 'SUB_PROJECT', '20', 'Suivi des coûts CAPEX',  20),
    ('MOD_PRJ_TN', 'MODEL PROJET TRAVAUX NEUFS', 'SUB_PROJECT', '30', 'Suivi des coûts OPEX',   30);

-- ---------------------------------------------------------------------
-- ACTIVITÉS
-- ---------------------------------------------------------------------
INSERT INTO clean_data.ifs_model_project
    (project_id, project_name, node_type, sub_project_id, activity_no, activity_desc, sort_order)
VALUES
    -- 10 - Suivi des Portes
    ('MOD_PRJ_TN', 'MODEL PROJET TRAVAUX NEUFS', 'ACTIVITY', '10', '000-P0',    'Porte P0', 1),
    ('MOD_PRJ_TN', 'MODEL PROJET TRAVAUX NEUFS', 'ACTIVITY', '10', '001-P1',    'Porte P1', 2),
    ('MOD_PRJ_TN', 'MODEL PROJET TRAVAUX NEUFS', 'ACTIVITY', '10', '002-P2',    'Porte P2', 3),
    ('MOD_PRJ_TN', 'MODEL PROJET TRAVAUX NEUFS', 'ACTIVITY', '10', '003-P3',    'Porte P3', 4),
    ('MOD_PRJ_TN', 'MODEL PROJET TRAVAUX NEUFS', 'ACTIVITY', '10', '004-P4',    'Porte P4', 5),
    ('MOD_PRJ_TN', 'MODEL PROJET TRAVAUX NEUFS', 'ACTIVITY', '10', '005-P5',    'Porte P5', 6),
    ('MOD_PRJ_TN', 'MODEL PROJET TRAVAUX NEUFS', 'ACTIVITY', '10', '006-P6',    'Porte P6', 7),
    -- 20 - Suivi des coûts CAPEX
    ('MOD_PRJ_TN', 'MODEL PROJET TRAVAUX NEUFS', 'ACTIVITY', '20', '001-LOT 1', 'Lot 1',              1),
    ('MOD_PRJ_TN', 'MODEL PROJET TRAVAUX NEUFS', 'ACTIVITY', '20', 'REP',       'Reprise Données SAP', 2),
    -- 30 - Suivi des coûts OPEX
    ('MOD_PRJ_TN', 'MODEL PROJET TRAVAUX NEUFS', 'ACTIVITY', '30', '001-H_ING', 'Heures Ingénierie',   1),
    ('MOD_PRJ_TN', 'MODEL PROJET TRAVAUX NEUFS', 'ACTIVITY', '30', 'REP',       'Reprise Données SAP', 2);

-- ---------------------------------------------------------------------
-- ACTIVITY CLASSES (par porte : PORTE / STATUT_PORTE / QUAL_PORTE)
--   PORTE.value = 'N - Porte PN' (confirmé pour P2 = '2 - Porte P2', déduit pour les autres)
--   STATUT_PORTE.value = '0 - à Définir' ; QUAL_PORTE.value = '0 - 0'
-- ---------------------------------------------------------------------
INSERT INTO clean_data.ifs_model_project
    (project_id, project_name, node_type, sub_project_id, activity_no, activity_class_id, activity_class_desc, value, validity, sort_order)
SELECT
    'MOD_PRJ_TN', 'MODEL PROJET TRAVAUX NEUFS', 'ACTIVITY_CLASS', '10', a.activity_no, cls.id, cls.descr,
    CASE cls.id
        WHEN 'PORTE'        THEN a.n || ' - Porte P' || a.n
        WHEN 'STATUT_PORTE' THEN '0 - à Définir'
        WHEN 'QUAL_PORTE'   THEN '0 - 0'
    END,
    'GLOBAL',
    cls.ord
FROM (VALUES
        ('000-P0','0'), ('001-P1','1'), ('002-P2','2'), ('003-P3','3'),
        ('004-P4','4'), ('005-P5','5'), ('006-P6','6')
     ) AS a(activity_no, n)
CROSS JOIN (VALUES
        ('PORTE',        'Numéro de porte',            1),
        ('STATUT_PORTE', 'Statut de la porte',         2),
        ('QUAL_PORTE',   'Qualité de la porte (note)', 3)
     ) AS cls(id, descr, ord);

-- Commission Feu Vert : 4e activity class, UNIQUEMENT sur P3 / P4 / P6 (comme dans IFS)
INSERT INTO clean_data.ifs_model_project
    (project_id, project_name, node_type, sub_project_id, activity_no, activity_class_id, activity_class_desc, value, validity, sort_order)
VALUES
    ('MOD_PRJ_TN', 'MODEL PROJET TRAVAUX NEUFS', 'ACTIVITY_CLASS', '10', '003-P3', 'CFV', 'Commission Feu Vert', '0 - Prévue', 'GLOBAL', 4),
    ('MOD_PRJ_TN', 'MODEL PROJET TRAVAUX NEUFS', 'ACTIVITY_CLASS', '10', '004-P4', 'CFV', 'Commission Feu Vert', '0 - Prévue', 'GLOBAL', 4),
    ('MOD_PRJ_TN', 'MODEL PROJET TRAVAUX NEUFS', 'ACTIVITY_CLASS', '10', '006-P6', 'CFV', 'Commission Feu Vert', '0 - Prévue', 'GLOBAL', 4);

-- Contrôle
-- SELECT node_type, count(*) FROM clean_data.ifs_model_project GROUP BY node_type;
-- SELECT * FROM clean_data.ifs_model_project ORDER BY sub_project_id, activity_no, activity_class_id;
