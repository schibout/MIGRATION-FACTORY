-- =====================================================
-- Migration 123 : immobilisations, n° projet SN et Projet Id IFS
--   numero_projet_sn : ANLA-POSNR -> PRPS-PSPHI -> PROJ-PSPID (ex. SN11006 pour
--                      l'element d'OTP SN11006IM)
--   projet_id        : project_number SharePoint (= project_id IFS, ex. 16.001)
--                      dont le code (SN.16044) correspond au projet SN
-- Colonnes ajoutees EN FIN de table : la fonction insere sans liste de colonnes.
-- A jouer AVANT sql/immobilisation/compile.sh. Idempotent.
-- =====================================================
ALTER TABLE clean_data.immobilisation ADD COLUMN IF NOT EXISTS numero_projet_sn varchar(24);
ALTER TABLE clean_data.immobilisation ADD COLUMN IF NOT EXISTS projet_id varchar(10);

COMMENT ON COLUMN clean_data.immobilisation.numero_projet_sn IS 'Definition de projet SAP : ANLA-POSNR -> PRPS-PSPHI -> PROJ-PSPID';
COMMENT ON COLUMN clean_data.immobilisation.projet_id IS 'Projet IFS : raw_data.sharepoint_projets.project_number dont le code (sans ponctuation) = numero_projet_sn ; projet annule ecarte si doublon';
