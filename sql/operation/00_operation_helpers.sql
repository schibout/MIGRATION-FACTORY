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
-- Types alignes sur AUFK (varchar(20)) : CREATE OR REPLACE VIEW refuse de les changer.
SELECT k.mandt::varchar(20), k.aufnr::varchar(20)
FROM raw_data.afko k
JOIN raw_data.jest j
  ON j.mandt = k.mandt
 AND j.objnr = 'OR' || k.aufnr
WHERE NOT EXISTS (SELECT 1 FROM raw_data.aufk a WHERE a.mandt = k.mandt AND a.aufnr = k.aufnr)
  AND (j.inact IS NULL OR trim(j.inact) <> 'X')
  AND j.stat IN ('I0045', 'I0046', 'I0076');

COMMENT ON VIEW clean_data.v_sap_ordre_clos IS
'Ordres SAP clos (statut actif TECO/CLSD/DLFL dans JEST). Les loaders du module Operations excluent leurs operations.';

-- Perimetre de reprise des ordres de maintenance (regles IW39, 2026-09-28,
-- demande explicite) :
--   * date de CREATION de l'ordre (AUFK.ERDAT) au 01/01/2026 ou apres
--     (2026-10-05, demande explicite ; remplace AFKO.GSTRP 01/01/2026 ->
--     aujourd'hui : 3 334 -> 2 946 ordres) ;
--   * poste de travail responsable (AFIH.GEWRK -> CRHD, objet 'A') de la
--     division 9200 et d'un des secteurs 7.MATC, 7.MCAR, 7.MSCT, 7.MENG,
--     7.MFIE, 7.MELY, 7.MNRJ, 7.MSGX, 7.MTRO (ajout 2026-10-05, +19 ordres)
--     (AUFK.VAPLZ/WAWRK ne sont pas extraits) ;
--   * statut « en cours » : REL (I0002) actif et ordre non clos
--     (v_sap_ordre_clos).
-- Les avis SAP (QMEL) ne sont pas repris : on ne cree aucun BT a partir d'un
-- avis, seuls les ordres existants passent. Environ 2 965 ordres le 2026-10-05.
CREATE OR REPLACE VIEW clean_data.v_sap_ordre_repris AS
SELECT k.mandt, k.aufnr
FROM raw_data.afko k
JOIN raw_data.aufk a
  ON a.mandt = k.mandt
 AND a.aufnr = k.aufnr
JOIN raw_data.afih h
  ON h.mandt = k.mandt
 AND h.aufnr = k.aufnr
JOIN raw_data.crhd c
  ON c.mandt = h.mandt
 AND c.objid = h.gewrk
 AND c.objty = 'A'
WHERE a.erdat >= '20260101'
  AND c.werks = '9200'
  AND c.arbpl IN ('7.MATC', '7.MCAR', '7.MSCT', '7.MENG',
                  '7.MFIE', '7.MELY', '7.MNRJ', '7.MSGX', '7.MTRO')
  AND EXISTS (
      SELECT 1 FROM raw_data.jest j
      WHERE j.mandt = a.mandt
        AND j.objnr = a.objnr
        AND j.stat = 'I0002'
        AND (j.inact IS NULL OR trim(j.inact) <> 'X')
  )
  AND NOT EXISTS (
      SELECT 1 FROM clean_data.v_sap_ordre_clos oc
      WHERE oc.mandt = k.mandt AND oc.aufnr = k.aufnr
  );

COMMENT ON VIEW clean_data.v_sap_ordre_repris IS
'Ordres SAP repris dans jt_task (regles IW39) : ordre cree depuis le 01/01/2026, poste responsable 9200 / secteurs 7.M*, statut REL non clos.';
