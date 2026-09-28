-- Aides communes du module Operations (compilees avant les loaders).

-- Ordres SAP CLOS : un ordre est clos quand il porte, ACTIF dans JEST (objet
-- AUFK.OBJNR), un statut I0045 (TECO, cloture technique), I0046 (CLSD, cloture)
-- ou I0076 (DLFL, indicateur de suppression). Les 3 loaders (jt_task,
-- jt_task_resource, maint_material_req_line) ne reprennent que les operations
-- des ordres NON clos = « en cours ou futures » (2026-09-18, demande
-- explicite), sans plus aucun filtre de date : l'ancien critere
-- « AFKO.GSTRP en 2026 » gardait 8 648 operations d'ordres deja clos et
-- excluait les ordres 2027+ ainsi que les ordres anciens jamais clotures.
--
-- Vue (et non fonction) pour que le planificateur garde ses estimations sur
-- les tables SAP ; pas de DISTINCT pour qu'elle reste aplatissable dans un
-- NOT EXISTS. On passe par AUFK.OBJNR et non par 'OR' || AUFNR : 7 ordres
-- derogent a cette convention.
-- Ordre present dans AFKO mais absent d'AUFK (trou d'extraction : 99 ordres
-- <= 2013 le 2026-09-28) : on lit JEST sur l'objet 'OR' || AUFNR. Ils etaient
-- jusque-la consideres ouverts alors qu'ils sont TOUS clos (seconde branche).
CREATE OR REPLACE VIEW clean_data.v_sap_ordre_clos AS
SELECT a.mandt, a.aufnr
FROM raw_data.aufk a
JOIN raw_data.jest j
  ON j.mandt = a.mandt
 AND j.objnr = a.objnr
WHERE (j.inact IS NULL OR trim(j.inact) <> 'X')
  AND j.stat IN ('I0045', 'I0046', 'I0076')
UNION ALL
SELECT k.mandt, k.aufnr
FROM raw_data.afko k
JOIN raw_data.jest j
  ON j.mandt = k.mandt
 AND j.objnr = 'OR' || k.aufnr
WHERE NOT EXISTS (SELECT 1 FROM raw_data.aufk a WHERE a.mandt = k.mandt AND a.aufnr = k.aufnr)
  AND (j.inact IS NULL OR trim(j.inact) <> 'X')
  AND j.stat IN ('I0045', 'I0046', 'I0076');

COMMENT ON VIEW clean_data.v_sap_ordre_clos IS
'Ordres SAP clos (statut actif TECO/CLSD/DLFL dans JEST). Les loaders du module Operations excluent leurs operations.';
