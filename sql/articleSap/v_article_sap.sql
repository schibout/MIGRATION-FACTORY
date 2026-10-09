-- Vue de lecture de clean_data.article_sap : memes colonnes, regroupees par
-- theme, chaque code suivi de son libelle (la table garde l'ordre d'ajout des
-- migrations 106 a 112). Toute nouvelle colonne de la table doit y etre ajoutee.
-- DROP + CREATE : CREATE OR REPLACE VIEW refuse de reordonner les colonnes.
DROP VIEW IF EXISTS clean_data.v_article_sap;

CREATE VIEW clean_data.v_article_sap AS
SELECT
    -- Identification
    "N° article",
    "Description article",
    "Ancien numéro article",
    "Désignation du type",
    "Site",
    "Site Description",

    -- Classification
    "Classe d'actifs",
    "Classe d'actifs Description",
    "Catégorie article",
    "Catégorie article Description",
    "Groupe produit 1",
    "Groupe produit 1 Description",
    "Hiérarchie produit",
    "Hiérarchie produit Description",
    "Groupe comptable",
    "Groupe comptable Description",
    "Classe ABC",
    "Statut article",

    -- Unite
    "U/M Stock",
    "U/M Stock Description",

    -- Achat et planification
    "Groupe d'achat",
    "Groupe d'achat Description",
    "Type approvisionnement",
    "Type approvisionnement Description",
    "Gestionnaire",
    "Type de planification",
    "Point de commande",
    "Délai d'achat",

    -- Stock
    "EMPLACEMENT",
    "Qté en stock",

    -- Textes
    "Texte de base",
    "Texte de commande",
    "Note interne",

    -- Tracabilite
    "Date de création",
    "Créé par",
    "Créé par Nom",
    "Date de dernière modification",
    "Dernière modification par",
    "Dernière modification par Nom"
FROM clean_data.article_sap;

COMMENT ON VIEW clean_data.v_article_sap IS
'Articles SAP (perimetre STJN + maintenance) : colonnes de clean_data.article_sap regroupees par theme, code puis libelle.';
