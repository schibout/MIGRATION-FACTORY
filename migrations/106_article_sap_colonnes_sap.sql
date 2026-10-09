-- 106 : clean_data.article_sap ne garde que les informations importantes venant
-- exclusivement de SAP (demande explicite du 2026-10-09). Les ~125 autres
-- colonnes du gabarit IFS sont supprimees : valeurs par defaut IFS (aucune
-- information SAP), colonnes sans equivalent SAP (toujours NULL), doublons de
-- la designation, ou champs SAP quasi vides (poids 12 lignes, volume 1, pays
-- d'origine 12, n° statistique 40, dimension 47).
-- Rejouable : ne supprime que ce qui n'est pas dans la liste conservee.
-- Ensuite : cd sql/articleSap && ./compile.sh puis SELECT clean_data.alimenter_article_sap();
DO $$
DECLARE
    v_col text;
BEGIN
    FOR v_col IN
        SELECT column_name FROM information_schema.columns
         WHERE table_schema = 'clean_data' AND table_name = 'article_sap'
           AND column_name NOT IN (
               'N° article', 'Description article', 'Site', 'Site Description',
               'Gestionnaire', 'U/M Stock',
               'Groupe produit 1', 'Groupe produit 1 Description',
               'Groupe produit 2', 'Groupe produit 2 Description',
               'Statut article', 'Classe ABC',
               'Groupe comptable', 'Groupe comptable Description',
               'EMPLACEMENT', 'Désignation du type', 'Qté en stock',
               'Créé', 'Modifié', 'Notes', 'Délai d''achat')
    LOOP
        EXECUTE format('ALTER TABLE clean_data.article_sap DROP COLUMN %I', v_col);
    END LOOP;
END $$;
