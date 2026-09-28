-- Purge des ordres SAP de la division 2200 dans raw_data (demande explicite 2026-09-28 :
-- « on ne garde que 9200 »). Perimetre choisi : les ORDRES et ce qui en depend
-- uniquement ; structure technique (IFLOT/ILOA...), articles (MARC...) et achats
-- (EKPO...) ne sont PAS touches (commandes d'achat SJ, part_catalog et fournisseur
-- principal lisent encore 2200).
--
-- Ordres vises = AUFK.WERKS = '2200' (coherent a 100 % avec AFIH.IWERK et AFVC.WERKS
-- au 2026-09-28) + ordres presents dans AFKO mais absents d'AUFK avec AFIH.IWERK = '2200'.
--
-- Chaque ligne supprimee est d'abord copiee dans backup_2200.<table> (restauration :
-- INSERT INTO raw_data.<t> SELECT * FROM backup_2200.<t>). Script a usage unique :
-- une extraction SAP (bouton « Synchroniser avec SAP ») RECHARGE ces lignes tant que
-- l'extracteur n'est pas filtre sur la division.
--
-- Usage : psql -v action=ROLLBACK (essai a blanc) ou -v action=COMMIT.
\set ON_ERROR_STOP on
SET statement_timeout = 0;
SET jit = off;
SET work_mem = '256MB';
BEGIN;

CREATE SCHEMA IF NOT EXISTS backup_2200;

-- Ordres vises
CREATE TEMP TABLE p_ordre AS
SELECT a.mandt, a.aufnr, a.objnr FROM raw_data.aufk a WHERE a.werks = '2200'
UNION
SELECT k.mandt, k.aufnr, 'OR' || k.aufnr
FROM raw_data.afko k
JOIN raw_data.afih h ON h.mandt = k.mandt AND h.aufnr = k.aufnr
WHERE h.iwerk = '2200'
  AND NOT EXISTS (SELECT 1 FROM raw_data.aufk a WHERE a.mandt = k.mandt AND a.aufnr = k.aufnr)
UNION
-- Ordre absent d'AUFK sans AFIH.IWERK exploitable : division lue sur ses operations
SELECT k.mandt, k.aufnr, 'OR' || k.aufnr
FROM raw_data.afko k
WHERE NOT EXISTS (SELECT 1 FROM raw_data.aufk a WHERE a.mandt = k.mandt AND a.aufnr = k.aufnr)
  AND EXISTS (SELECT 1 FROM raw_data.afvc v WHERE v.mandt = k.mandt AND v.aufpl = k.aufpl AND v.werks = '2200');
CREATE INDEX ON p_ordre (mandt, aufnr);
ANALYZE p_ordre;

-- Gammes d'ordre (AUFPL) et reservations (RSNUM)
CREATE TEMP TABLE p_aufpl AS
SELECT DISTINCT k.mandt, k.aufpl, k.rsnum FROM raw_data.afko k JOIN p_ordre o USING (mandt, aufnr)
UNION
-- Operations 2200 orphelines (aucun en-tete AFKO)
SELECT DISTINCT v.mandt, v.aufpl, NULL::varchar FROM raw_data.afvc v
WHERE v.werks = '2200'
  AND NOT EXISTS (SELECT 1 FROM raw_data.afko k WHERE k.mandt = v.mandt AND k.aufpl = v.aufpl);
CREATE INDEX ON p_aufpl (mandt, aufpl);
ANALYZE p_aufpl;

-- Objets de statut / couts : ordres (AUFK.OBJNR et 'OR'||AUFNR) + operations (AFVC.OBJNR)
CREATE TEMP TABLE p_objnr AS
SELECT mandt, objnr FROM p_ordre WHERE objnr IS NOT NULL
UNION SELECT mandt, 'OR' || aufnr FROM p_ordre
UNION SELECT v.mandt, v.objnr FROM raw_data.afvc v JOIN p_aufpl p USING (mandt, aufpl) WHERE v.objnr IS NOT NULL;
CREATE INDEX ON p_objnr (mandt, objnr);
ANALYZE p_objnr;

-- Listes d'objets des ordres
CREATE TEMP TABLE p_obknr AS
SELECT DISTINCT h.mandt, h.obknr FROM raw_data.afih h JOIN p_ordre o USING (mandt, aufnr)
WHERE h.obknr IS NOT NULL AND trim(h.obknr, '0 ') <> '';
ANALYZE p_obknr;

SELECT (SELECT count(*) FROM p_ordre) AS ordres, (SELECT count(*) FROM p_aufpl) AS gammes,
       (SELECT count(*) FROM p_objnr) AS objets_statut, (SELECT count(*) FROM p_obknr) AS listes_objets;

-- Sauvegarde puis suppression, table par table
CREATE TEMP TABLE bilan (table_sap text, lignes_supprimees bigint);

CREATE TABLE backup_2200.aufk AS SELECT t.* FROM raw_data.aufk t JOIN p_ordre p USING (mandt, aufnr);
DELETE FROM raw_data.aufk t USING p_ordre p WHERE t.mandt = p.mandt AND t.aufnr = p.aufnr;
INSERT INTO bilan SELECT 'aufk', count(*) FROM backup_2200.aufk;

CREATE TABLE backup_2200.afih AS SELECT t.* FROM raw_data.afih t JOIN p_ordre p USING (mandt, aufnr);
DELETE FROM raw_data.afih t USING p_ordre p WHERE t.mandt = p.mandt AND t.aufnr = p.aufnr;
INSERT INTO bilan SELECT 'afih', count(*) FROM backup_2200.afih;

CREATE TABLE backup_2200.caufv AS SELECT t.* FROM raw_data.caufv t JOIN p_ordre p USING (mandt, aufnr);
DELETE FROM raw_data.caufv t USING p_ordre p WHERE t.mandt = p.mandt AND t.aufnr = p.aufnr;
INSERT INTO bilan SELECT 'caufv', count(*) FROM backup_2200.caufv;

CREATE TABLE backup_2200.afvc AS SELECT t.* FROM raw_data.afvc t JOIN p_aufpl p USING (mandt, aufpl);
DELETE FROM raw_data.afvc t USING p_aufpl p WHERE t.mandt = p.mandt AND t.aufpl = p.aufpl;
INSERT INTO bilan SELECT 'afvc', count(*) FROM backup_2200.afvc;

CREATE TABLE backup_2200.afvv AS SELECT t.* FROM raw_data.afvv t JOIN p_aufpl p USING (mandt, aufpl);
DELETE FROM raw_data.afvv t USING p_aufpl p WHERE t.mandt = p.mandt AND t.aufpl = p.aufpl;
INSERT INTO bilan SELECT 'afvv', count(*) FROM backup_2200.afvv;

CREATE TABLE backup_2200.afru AS
SELECT t.* FROM raw_data.afru t
WHERE EXISTS (SELECT 1 FROM p_ordre p WHERE p.mandt = t.mandt AND p.aufnr = t.aufnr)
   OR EXISTS (SELECT 1 FROM p_aufpl p WHERE p.mandt = t.mandt AND p.aufpl = t.aufpl);
DELETE FROM raw_data.afru t
WHERE EXISTS (SELECT 1 FROM p_ordre p WHERE p.mandt = t.mandt AND p.aufnr = t.aufnr)
   OR EXISTS (SELECT 1 FROM p_aufpl p WHERE p.mandt = t.mandt AND p.aufpl = t.aufpl);
INSERT INTO bilan SELECT 'afru', count(*) FROM backup_2200.afru;

CREATE TABLE backup_2200.resb AS
SELECT t.* FROM raw_data.resb t
WHERE EXISTS (SELECT 1 FROM p_ordre p WHERE p.mandt = t.mandt AND p.aufnr = t.aufnr)
   OR EXISTS (SELECT 1 FROM p_aufpl p WHERE p.mandt = t.mandt AND p.rsnum = t.rsnum);
DELETE FROM raw_data.resb t
WHERE EXISTS (SELECT 1 FROM p_ordre p WHERE p.mandt = t.mandt AND p.aufnr = t.aufnr)
   OR EXISTS (SELECT 1 FROM p_aufpl p WHERE p.mandt = t.mandt AND p.rsnum = t.rsnum);
INSERT INTO bilan SELECT 'resb', count(*) FROM backup_2200.resb;

CREATE TABLE backup_2200.jest AS SELECT t.* FROM raw_data.jest t JOIN p_objnr p USING (mandt, objnr);
DELETE FROM raw_data.jest t USING p_objnr p WHERE t.mandt = p.mandt AND t.objnr = p.objnr;
INSERT INTO bilan SELECT 'jest', count(*) FROM backup_2200.jest;

CREATE TABLE backup_2200.pmco AS SELECT t.* FROM raw_data.pmco t JOIN p_objnr p USING (mandt, objnr);
DELETE FROM raw_data.pmco t USING p_objnr p WHERE t.mandt = p.mandt AND t.objnr = p.objnr;
INSERT INTO bilan SELECT 'pmco', count(*) FROM backup_2200.pmco;

CREATE TABLE backup_2200.cosp AS SELECT t.* FROM raw_data.cosp t JOIN p_objnr p USING (mandt, objnr);
DELETE FROM raw_data.cosp t USING p_objnr p WHERE t.mandt = p.mandt AND t.objnr = p.objnr;
INSERT INTO bilan SELECT 'cosp', count(*) FROM backup_2200.cosp;

CREATE TABLE backup_2200.objk AS SELECT t.* FROM raw_data.objk t JOIN p_obknr p USING (mandt, obknr);
DELETE FROM raw_data.objk t USING p_obknr p WHERE t.mandt = p.mandt AND t.obknr = p.obknr;
INSERT INTO bilan SELECT 'objk', count(*) FROM backup_2200.objk;

-- AFKO en dernier : p_aufpl en depend jusque-la
CREATE TABLE backup_2200.afko AS SELECT t.* FROM raw_data.afko t JOIN p_ordre p USING (mandt, aufnr);
DELETE FROM raw_data.afko t USING p_ordre p WHERE t.mandt = p.mandt AND t.aufnr = p.aufnr;
INSERT INTO bilan SELECT 'afko', count(*) FROM backup_2200.afko;

SELECT * FROM bilan ORDER BY lignes_supprimees DESC;

-- Controle : plus aucune operation 2200
SELECT count(*) AS afvc_2200_restantes FROM raw_data.afvc WHERE werks = '2200';

:action;
