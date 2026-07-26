-- =====================================================================
-- SUPPRESSION de raw_data.ih02_capgemini
-- =====================================================================
-- Cette table (referentiel hierarchie "Capgemini", ~145 000 lignes) n'est
-- PLUS utilisee : l'alimentation de clean_data.equipment_functional et
-- l'API IH02 reposent desormais sur les tables SAP standard
-- (iflot / iflotx / iflos / iloa / itob).
--
-- Verifie avant ecriture : aucune vue dependante, aucune FK entrante.
--
-- C'est une donnee SOURCE (raw_data) : en cas de besoin, elle est
-- reproductible par une nouvelle extraction. Une sauvegarde prealable
-- reste recommandee (cf. option ci-dessous).
--
-- A executer manuellement sur le serveur (psql / pgAdmin).
-- =====================================================================

-- (Optionnel) Sauvegarde de securite AVANT suppression — decommentez si souhaite :
-- CREATE TABLE raw_data._backup_ih02_capgemini AS SELECT * FROM raw_data.ih02_capgemini;

-- Suppression (sans CASCADE : aucune dependance detectee, on echoue plutot
-- que de supprimer silencieusement un objet inattendu).
DROP TABLE IF EXISTS raw_data.ih02_capgemini;

-- Verification : la table ne doit plus exister
SELECT COUNT(*) AS reste_ih02_capgemini
FROM information_schema.tables
WHERE table_schema = 'raw_data' AND table_name = 'ih02_capgemini';
-- -> doit renvoyer 0
