-- Vue clean_data.v_fournisseurs_enrichis (alignée sur v_fournisseurs_enrichis.sql)
-- LFA1 en master ; LFB1 et LFM1 en LEFT JOIN pour éviter une vue vide si extraction partielle.
--
-- Si l'objet existe déjà comme vue matérialisée (historique), CREATE VIEW échoue :
-- ERROR: "v_fournisseurs_enrichis" is not a view — on supprime l'ancien type puis on recrée.

DO $drop$
DECLARE
  rkind "char";
BEGIN
  SELECT c.relkind INTO rkind
  FROM pg_catalog.pg_class c
  JOIN pg_catalog.pg_namespace n ON n.oid = c.relnamespace
  WHERE n.nspname = 'clean_data' AND c.relname = 'v_fournisseurs_enrichis';

  IF rkind = 'm' THEN
    EXECUTE 'DROP MATERIALIZED VIEW clean_data.v_fournisseurs_enrichis CASCADE';
  ELSIF rkind = 'v' THEN
    EXECUTE 'DROP VIEW clean_data.v_fournisseurs_enrichis CASCADE';
  END IF;
END;
$drop$;

CREATE OR REPLACE VIEW clean_data.v_fournisseurs_enrichis AS
SELECT 
    a.lifnr AS "Numéro de compte fournisseur",
    a.name1 AS "Nom 1",
    COALESCE(a.name2, ''::character varying) AS "Nom 2",
    COALESCE(a.name3, ''::character varying) AS "Nom 3",
    COALESCE(a.name4, ''::character varying) AS "Nom 4",
    COALESCE(a.stras, ''::character varying) AS "N° de rue et nom de la rue",
    COALESCE(a.ort01, ''::character varying) AS "Localité",
    COALESCE(a.ort02, ''::character varying) AS "District",
    COALESCE(a.pstlz, ''::character varying) AS "Code postal",
    COALESCE(a.land1, ''::character varying) AS "Clé de pays",
    COALESCE(a.regio, ''::character varying) AS "Région",
    COALESCE(a.stcd1, ''::character varying) AS "N° SIRET",
    COALESCE(a.stceg, ''::character varying) AS "Numéro d'identification de la TVA sur chiffres d'affaires",
    COALESCE(a.stcd2, ''::character varying) AS "N° identification fiscale 2",
    COALESCE(a.stcd3, ''::character varying) AS "N° identification fiscale 3",
    COALESCE(a.telf1, ''::character varying) AS "1er numéro de téléphone",
    COALESCE(a.telf2, ''::character varying) AS "2ème numéro de téléphone",
    COALESCE(a.telfx, ''::character varying) AS "Fax",
    COALESCE(adr6.smtp_addr, ''::character varying) AS "Email",
    COALESCE(a.ktokk, ''::character varying) AS "Classe de fournisseur",
    COALESCE(a.brsch, ''::character varying) AS "Secteur d'activité",
    COALESCE(a.spras, 'FR'::character varying) AS "Langue par défaut",
    string_agg(DISTINCT b.bukrs::text, ', '::text ORDER BY (b.bukrs::text)) AS "Société",
    CASE
        WHEN count(DISTINCT CASE
            WHEN b.sperr IS NOT NULL AND b.sperr::text <> ''::text THEN 1
            ELSE NULL::integer
        END) > 0 THEN true
        ELSE false
    END AS "Bloqué comptabilité",
    m.ekorg AS "Organisation d'achats",
    COALESCE(m.ekgrp, ''::character varying) AS "Groupe d'acheteurs",
    CASE
        WHEN m.sperm IS NOT NULL AND m.sperm::text <> ''::text THEN true
        ELSE false
    END AS "Bloqué achats",
    COALESCE(m.plifz::numeric::integer, 0) AS "Délai de livraison prévu",
    COALESCE(m.minbw::numeric, 0::numeric) AS "Valeur commande minimale",
    COALESCE(min(b.zterm::text), ''::text) AS "Clé conditions de paiement (Comptabilité)",
    COALESCE(m.zterm, ''::character varying) AS "Clé conditions de paiement (Achats)",
    COALESCE(m.inco1, ''::character varying) AS "Incoterms 1ère partie",
    COALESCE(m.inco2, ''::character varying) AS "Incoterms 2nde partie",
    COALESCE(m.verkf, ''::character varying) AS "Mode de transport",
    COALESCE(m.zolla, ''::character varying) AS "Bureau de douane",
    a.erdat AS "Date création SAP",
    COALESCE(a.ernam, ''::character varying) AS "Utilisateur création SAP",
    GREATEST(
        COALESCE(a.updat, '19000101'::character varying), 
        COALESCE(b.updat, '19000101'::character varying), 
        COALESCE(m.erdat, '19000101'::character varying)
    ) AS "Dernière modification SAP",
    CASE
        WHEN GREATEST(
            COALESCE(a.updat, '19000101'::character varying), 
            COALESCE(b.updat, '19000101'::character varying), 
            COALESCE(m.erdat, '19000101'::character varying)
        )::text = COALESCE(a.updat, '19000101'::character varying)::text 
            THEN COALESCE(a.uptim, ''::character varying)
        WHEN GREATEST(
            COALESCE(a.updat, '19000101'::character varying), 
            COALESCE(b.updat, '19000101'::character varying), 
            COALESCE(m.erdat, '19000101'::character varying)
        )::text = COALESCE(b.updat, '19000101'::character varying)::text 
            THEN COALESCE(b.uptim, ''::character varying)
        ELSE COALESCE(m.ernam, ''::character varying)
    END AS "Utilisateur modification SAP",
    CASE
        WHEN a.loevm IS NOT NULL AND a.loevm::text <> ''::text THEN 'SUPPRIMÉ'::text
        WHEN count(DISTINCT CASE
            WHEN b.sperr IS NOT NULL AND b.sperr::text <> ''::text THEN 1
            ELSE NULL::integer
        END) > 0 THEN 'BLOQUÉ'::text
        WHEN count(DISTINCT CASE
            WHEN m.sperm IS NOT NULL AND m.sperm::text <> ''::text THEN 1
            ELSE NULL::integer
        END) > 0 THEN 'BLOQUÉ_ACHATS'::text
        ELSE 'ACTIF'::text
    END AS "Statut fournisseur",
    CURRENT_TIMESTAMP AS derniere_maj_vue
FROM raw_data.lfa1 a
LEFT JOIN raw_data.lfb1 b
    ON a.mandt::text = b.mandt::text AND a.lifnr::text = b.lifnr::text
LEFT JOIN raw_data.lfm1 m
    ON a.mandt::text = m.mandt::text
   AND a.lifnr::text = m.lifnr::text
   AND m.ekorg::text = (
       SELECT min(m2.ekorg::text)
       FROM raw_data.lfm1 m2
       WHERE m2.mandt::text = a.mandt::text AND m2.lifnr::text = a.lifnr::text
   )
LEFT JOIN raw_data.adr6 adr6
    ON a.adrnr::text = adr6.addrnumber::text
   AND adr6.persnumber::text = '0000000000'::text
GROUP BY 
    a.lifnr, a.name1, a.name2, a.name3, a.name4, a.stras, a.ort01, a.ort02, 
    a.pstlz, a.land1, a.regio, a.stcd1, a.stceg, a.stcd2, a.stcd3, 
    a.telf1, a.telf2, a.telfx, adr6.smtp_addr, a.ktokk, a.brsch, a.spras, 
    m.ekorg, m.ekgrp, m.sperm, m.plifz, m.minbw, m.zterm, m.inco1, m.inco2, 
    m.verkf, m.zolla, a.erdat, a.ernam, a.updat, a.uptim, b.updat, b.uptim, 
    m.erdat, m.ernam, a.loevm
ORDER BY a.lifnr;
