-- Vue clean_data.v_fournisseurs
-- Récupéré depuis la base de données

CREATE OR REPLACE VIEW clean_data.v_fournisseurs AS
SELECT a.lifnr AS "Numéro de compte fournisseur",
    a.name1 AS "Nom 1",
    a.stras AS "N° de rue et nom de la rue",
    a.ort01 AS "Localité",
    a.pstlz AS "Code postal",
    a.land1 AS "Clé de pays",
    a.stcd1 AS "N° SIRET",
    a.stceg AS "Numéro d'identification de la TVA sur chiffres d'affaires",
    string_agg(DISTINCT b.bukrs::text, ', '::text ORDER BY (b.bukrs::text)) AS "Société",
    m.ekorg AS "Organisation d'achats",
    min(b.zterm::text) AS "Clé conditions de paiement (Comptabilité)",
    m.zterm AS "Clé conditions de paiement (Achats)",
    m.inco1 AS "Incoterms 1ère partie",
    m.inco2 AS "Incoterms 2nde partie",
    a.telf1 AS "1er numéro de téléphone",
    a.telf2 AS "2ème numéro de téléphone"
FROM raw_data.lfa1 a
JOIN raw_data.lfb1 b ON a.mandt::text = b.mandt::text AND a.lifnr::text = b.lifnr::text
JOIN raw_data.lfm1 m ON a.mandt::text = m.mandt::text AND a.lifnr::text = m.lifnr::text
WHERE m.ekorg::text = (
    SELECT min(m2.ekorg::text) AS min
    FROM raw_data.lfm1 m2
    WHERE m2.mandt::text = m.mandt::text AND m2.lifnr::text = m.lifnr::text
)
GROUP BY a.lifnr, a.name1, a.stras, a.ort01, a.pstlz, a.land1, a.stcd1, a.stceg, m.ekorg, m.zterm, m.inco1, m.inco2, a.telf1, a.telf2
ORDER BY a.lifnr;

