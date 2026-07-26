-- =====================================================
-- Script de création de la table SharePoint Resources
-- Schema: raw_data
-- Description: Table pour stocker les données des ressources SharePoint
-- Date: 2025-11-13
-- =====================================================

-- Création du schéma raw_data s'il n'existe pas
CREATE SCHEMA IF NOT EXISTS raw_data;
-- Suppression de la table si elle existe (pour recréation propre)
DROP TABLE IF EXISTS raw_data.sharepoint_resources CASCADE;
-- Création de la table principale
CREATE TABLE raw_data.sharepoint_resources (
    -- ===========================
    -- Clé primaire technique
    -- ===========================
    id SERIAL PRIMARY KEY,
   
    -- ===========================
    -- Identifiants SharePoint
    -- ===========================
    sharepoint_item_id INTEGER NOT NULL,
    etag VARCHAR(50),
    guid UUID,
    list_guid UUID DEFAULT 'bf1a480a-7bfa-4a41-bc75-301c25d3c720'::UUID,
    -- ===========================
    -- Métadonnées système SharePoint
    -- ===========================
    filesystemobjecttype INTEGER,
    contenttype_id TEXT,
    title TEXT,
    odata__uiversionstring VARCHAR(50),
    attachments BOOLEAN DEFAULT FALSE,
   
    -- ===========================
    -- Dates de gestion
    -- ===========================
    created TIMESTAMP,
    modified TIMESTAMP,
    
    -- ===========================
    -- Auteurs et Éditeurs
    -- ===========================
    author_id INTEGER,
    editor_id INTEGER,
    
    -- ===========================
    -- Propriétés spécifiques aux ressources
    -- ===========================
    resource_x0020_typeid INTEGER,
    generic BOOLEAN DEFAULT FALSE,
    maxunit NUMERIC(10, 2),
    windowsaccount_id TEXT,
    securitygroup TEXT,
    
    -- ===========================
    -- Métadonnées d'import
    -- ===========================
    imported_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    source_file VARCHAR(255),
    import_batch_id VARCHAR(100),
    
    -- ===========================
    -- Contraintes
    -- ===========================
    CONSTRAINT uk_sharepoint_resource_id UNIQUE (sharepoint_item_id),
    CONSTRAINT chk_maxunit_positive CHECK (maxunit IS NULL OR maxunit > 0)
);

-- =====================================================
-- Index pour optimisation des performances
-- =====================================================

-- Index sur le GUID pour les recherches rapides
CREATE INDEX idx_sharepoint_resources_guid 
ON raw_data.sharepoint_resources(guid) 
WHERE guid IS NOT NULL;

-- Index sur le type de ressource
CREATE INDEX idx_sharepoint_resources_resource_type 
ON raw_data.sharepoint_resources(resource_x0020_typeid) 
WHERE resource_x0020_typeid IS NOT NULL;

-- Index sur les dates de création
CREATE INDEX idx_sharepoint_resources_created 
ON raw_data.sharepoint_resources(created DESC) 
WHERE created IS NOT NULL;

-- Index sur les dates de modification
CREATE INDEX idx_sharepoint_resources_modified 
ON raw_data.sharepoint_resources(modified DESC) 
WHERE modified IS NOT NULL;

-- Index sur les auteurs
CREATE INDEX idx_sharepoint_resources_author 
ON raw_data.sharepoint_resources(author_id) 
WHERE author_id IS NOT NULL;

-- Index sur les éditeurs
CREATE INDEX idx_sharepoint_resources_editor 
ON raw_data.sharepoint_resources(editor_id) 
WHERE editor_id IS NOT NULL;

-- Index sur la date d'import
CREATE INDEX idx_sharepoint_resources_imported_at 
ON raw_data.sharepoint_resources(imported_at DESC);

-- Index composite pour les requêtes fréquentes
CREATE INDEX idx_sharepoint_resources_composite 
ON raw_data.sharepoint_resources(resource_x0020_typeid, created, generic);

-- =====================================================
-- Commentaires sur la table et les colonnes
-- =====================================================

COMMENT ON TABLE raw_data.sharepoint_resources IS 
'Table de stockage des ressources importées depuis SharePoint. Contient les données brutes des listes de ressources.';

COMMENT ON COLUMN raw_data.sharepoint_resources.id IS 
'Identifiant unique auto-incrémenté (clé primaire technique)';

COMMENT ON COLUMN raw_data.sharepoint_resources.sharepoint_item_id IS 
'ID de l''élément dans SharePoint (ID natif SharePoint)';

COMMENT ON COLUMN raw_data.sharepoint_resources.etag IS 
'Version de l''élément SharePoint pour la gestion de la concurrence';

COMMENT ON COLUMN raw_data.sharepoint_resources.guid IS 
'GUID unique de la ressource dans SharePoint';

COMMENT ON COLUMN raw_data.sharepoint_resources.list_guid IS 
'GUID de la liste SharePoint source (Resources list)';

COMMENT ON COLUMN raw_data.sharepoint_resources.contenttype_id IS 
'Identifiant du type de contenu SharePoint';

COMMENT ON COLUMN raw_data.sharepoint_resources.resource_x0020_typeid IS 
'Type de ressource (référence à une table de types de ressources)';

COMMENT ON COLUMN raw_data.sharepoint_resources.generic IS 
'Indique si la ressource est générique ou spécifique';

COMMENT ON COLUMN raw_data.sharepoint_resources.maxunit IS 
'Nombre maximum d''unités disponibles pour cette ressource';

COMMENT ON COLUMN raw_data.sharepoint_resources.windowsaccount_id IS 
'Identifiant du compte Windows associé à la ressource';

COMMENT ON COLUMN raw_data.sharepoint_resources.securitygroup IS 
'Groupe de sécurité associé à la ressource';

COMMENT ON COLUMN raw_data.sharepoint_resources.imported_at IS 
'Date et heure d''import de l''enregistrement dans la base';

COMMENT ON COLUMN raw_data.sharepoint_resources.source_file IS 
'Nom du fichier source XML utilisé pour l''import';

COMMENT ON COLUMN raw_data.sharepoint_resources.import_batch_id IS 
'Identifiant du batch d''import pour traçabilité';

-- =====================================================
-- Vue pour faciliter les requêtes courantes
-- =====================================================

CREATE OR REPLACE VIEW raw_data.v_sharepoint_resources_summary AS
SELECT 
    sr.id,
    sr.sharepoint_item_id,
    sr.title,
    sr.guid,
    sr.resource_x0020_typeid,
    sr.generic,
    sr.maxunit,
    sr.created,
    sr.modified,
    sr.author_id,
    sr.editor_id,
    sr.imported_at,
    sr.source_file,
    -- Calcul de l'ancienneté
    EXTRACT(DAY FROM (CURRENT_TIMESTAMP - sr.created)) as age_in_days,
    -- Dernière modification
    EXTRACT(DAY FROM (CURRENT_TIMESTAMP - sr.modified)) as days_since_modification,
    -- Statut
    CASE 
        WHEN sr.modified > (CURRENT_TIMESTAMP - INTERVAL '30 days') THEN 'Récent'
        WHEN sr.modified > (CURRENT_TIMESTAMP - INTERVAL '90 days') THEN 'Moyen'
        ELSE 'Ancien'
    END as status
FROM raw_data.sharepoint_resources sr
ORDER BY sr.modified DESC;

COMMENT ON VIEW raw_data.v_sharepoint_resources_summary IS 
'Vue résumée des ressources SharePoint avec calculs d''ancienneté et statut';

-- =====================================================
-- Statistiques et requêtes utiles
-- =====================================================

-- Fonction pour obtenir les statistiques
CREATE OR REPLACE FUNCTION raw_data.get_sharepoint_resources_stats()
RETURNS TABLE (
    total_resources BIGINT,
    resources_with_title BIGINT,
    generic_resources BIGINT,
    specific_resources BIGINT,
    resources_by_type JSONB,
    oldest_resource TIMESTAMP,
    newest_resource TIMESTAMP,
    last_import TIMESTAMP
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        COUNT(*)::BIGINT as total_resources,
        COUNT(title)::BIGINT as resources_with_title,
        COUNT(*) FILTER (WHERE generic = true)::BIGINT as generic_resources,
        COUNT(*) FILTER (WHERE generic = false)::BIGINT as specific_resources,
        jsonb_object_agg(
            COALESCE(resource_x0020_typeid::TEXT, 'NULL'), 
            cnt
        ) as resources_by_type,
        MIN(created) as oldest_resource,
        MAX(created) as newest_resource,
        MAX(imported_at) as last_import
    FROM (
        SELECT 
            resource_x0020_typeid,
            COUNT(*) as cnt
        FROM raw_data.sharepoint_resources
        GROUP BY resource_x0020_typeid
    ) type_counts
    CROSS JOIN raw_data.sharepoint_resources;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION raw_data.get_sharepoint_resources_stats() IS 
'Retourne des statistiques détaillées sur les ressources SharePoint';

-- =====================================================
-- Grants et permissions
-- =====================================================

-- Accorder les permissions de lecture à un rôle potentiel
-- GRANT SELECT ON raw_data.sharepoint_resources TO readonly_role;
-- GRANT SELECT ON raw_data.v_sharepoint_resources_summary TO readonly_role;

-- =====================================================
-- Affichage final
-- =====================================================

