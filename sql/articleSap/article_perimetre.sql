-- ============================================================================
-- Alimentation de clean_data.article_perimetre (ecran Finance > Articles)
-- Meme logique que clean_data.ifs_fournisseurs_perimetre (sql/supplier/01b_*),
-- sur les articles de clean_data.article_sap (ecran Donnees SAP > Articles) :
--   FICHIER     : article cree dans SAP avant la date d'arrete, ou present dans
--                 le fichier valide par le metier (article_perimetre_validation)
--   SAP_NOUVEAU : article cree dans SAP (mara.ersda) a partir de la date
--                 d'arrete, absent du fichier valide
-- Les colonnes affichees sont lues dans clean_data.v_article_sap : la table ne
-- porte que la cle, la source et la date d'arrete.
-- Prerequis : article_sap charge (module ETL Article SAP).
-- ============================================================================

CREATE TABLE IF NOT EXISTS clean_data.article_perimetre (
    numero_article    VARCHAR     NOT NULL PRIMARY KEY,
    source            VARCHAR(20) NOT NULL
        CONSTRAINT ck_article_perimetre_source CHECK (source IN ('FICHIER', 'SAP_NOUVEAU')),
    date_creation_sap DATE,
    date_arrete       DATE,
    charge_le         TIMESTAMP   NOT NULL DEFAULT CURRENT_TIMESTAMP
);
COMMENT ON TABLE clean_data.article_perimetre IS
    'Perimetre articles (ecran Finance > Articles) : articles de article_sap, SAP_NOUVEAU = crees dans SAP depuis la date d''arrete. Rechargee par clean_data.alimenter_article_perimetre().';

-- Articles du fichier valide par le metier (import ecran Finance > Articles),
-- jamais alimentee par le recalcul : un article present ici est FICHIER.
CREATE TABLE IF NOT EXISTS clean_data.article_perimetre_validation (
    numero_article  VARCHAR      NOT NULL PRIMARY KEY,
    date_validation DATE         NOT NULL,
    importe_le      TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    importe_par     VARCHAR(100)
);
-- Autres colonnes du fichier, telles que mappees dans l'assistant d'import
-- (nom de colonne -> valeur texte) ; affichees « Fichier · <nom> » dans l'ecran
ALTER TABLE clean_data.article_perimetre_validation ADD COLUMN IF NOT EXISTS donnees JSONB NOT NULL DEFAULT '{}';
ALTER TABLE clean_data.article_perimetre_validation ADD COLUMN IF NOT EXISTS nom_fichier VARCHAR(255);

-- p_date_arrete : saisie dans l'ecran ; NULL = valeur de l'ecran Valeurs par
-- defaut (clean_data.article_perimetre / date_arrete), a defaut celle des
-- fournisseurs. Retourne le nombre de lignes chargees.
CREATE OR REPLACE FUNCTION clean_data.alimenter_article_perimetre(p_date_arrete DATE DEFAULT NULL)
 RETURNS integer
 LANGUAGE plpgsql
AS $function$
DECLARE
   v_date_arrete CONSTANT DATE := COALESCE(
       p_date_arrete,
       NULLIF(TRIM(public.get_default_value('clean_data.article_perimetre', 'date_arrete')), '')::DATE,
       NULLIF(TRIM(public.get_default_value('clean_data.ifs_fournisseurs', 'date_arrete')), '')::DATE,
       DATE '2025-10-07');
   v_nb_fichier INTEGER;
   v_nb_sap INTEGER;
BEGIN
   -- DELETE et non TRUNCATE : l'ecran lit la table pendant le calcul (cf. fournisseurs)
   DELETE FROM clean_data.article_perimetre;

   INSERT INTO clean_data.article_perimetre (numero_article, source, date_creation_sap, date_arrete)
   SELECT a."N° article",
          CASE WHEN val.numero_article IS NULL AND d.creation >= v_date_arrete
               THEN 'SAP_NOUVEAU' ELSE 'FICHIER' END,
          d.creation,
          v_date_arrete
     FROM clean_data.article_sap a
     -- "Date de création" = mara.ersda au format JJ/MM/AAAA (texte)
     CROSS JOIN LATERAL (
         SELECT CASE WHEN a."Date de création" ~ '^[0-9]{2}/[0-9]{2}/[0-9]{4}$'
                     THEN TO_DATE(a."Date de création", 'DD/MM/YYYY') END AS creation
     ) d
     LEFT JOIN clean_data.article_perimetre_validation val ON val.numero_article = a."N° article"
    WHERE a."N° article" IS NOT NULL
   ON CONFLICT (numero_article) DO NOTHING;

   SELECT COUNT(*) FILTER (WHERE source = 'FICHIER'),
          COUNT(*) FILTER (WHERE source = 'SAP_NOUVEAU')
     INTO v_nb_fichier, v_nb_sap
     FROM clean_data.article_perimetre;

   RAISE NOTICE 'article_perimetre : % FICHIER + % SAP_NOUVEAU (crees depuis le %)',
                v_nb_fichier, v_nb_sap, v_date_arrete;
   RETURN v_nb_fichier + v_nb_sap;
END;
$function$;
