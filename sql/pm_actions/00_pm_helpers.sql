CREATE OR REPLACE FUNCTION clean_data.pe_num(p_text text)
 RETURNS numeric
 LANGUAGE sql
 IMMUTABLE
AS $function$
    SELECT CASE
        WHEN p_text IS NULL THEN NULL
        WHEN btrim(p_text) ~ '^-?[0-9]+(\.[0-9]+)?$' THEN btrim(p_text)::numeric
        ELSE NULL
    END;
$function$
;

-- Vue source des procedures pm_action* : 1 ligne = 1 operation de pe_tools,
-- avec le pm_no calcule (plan d'entretien, suffixe si plusieurs combinaisons
-- poste/frequence pour un meme plan, repli 900000+raw_id sans plan).
-- organisation_maintenance (migration 077) : organisation IFS deduite du
-- fichier importe, NULL pour les lignes historiques.
-- La vue n'existait qu'en base ; versionnee ici depuis le 2026-09-15.
-- PREREQUIS : migration 077 jouee AVANT ./compile.sh (la colonne
-- raw_data.pe_tools.organisation_maintenance doit exister, sinon ce CREATE VIEW
-- echoue alors que les procedures 01/04 compilent quand meme).
CREATE OR REPLACE VIEW clean_data.v_pm_source AS
WITH base AS (
    SELECT t.raw_id,
           t.poste_technique,
           t.groupe_de_gamme,
           t.compteur_de_gamme,
           t.frequence,
           t.designation,
           t.charge,
           t.nb_intervenants,
           t.organisation_maintenance,
           clean_data.pe_num(t.plan_entretien)          AS plan_num,
           upper(btrim(COALESCE(t.frequence, '')))      AS freq_norm
    FROM raw_data.pe_tools t
), ranked AS (
    SELECT b.*,
           dense_rank() OVER (PARTITION BY b.plan_num
                              ORDER BY b.poste_technique NULLS FIRST, b.freq_norm NULLS FIRST) AS combi_rang
    FROM base b
), counted AS (
    SELECT r.*,
           max(r.combi_rang) OVER (PARTITION BY r.plan_num) AS nb_combi
    FROM ranked r
)
SELECT c.raw_id, c.poste_technique, c.groupe_de_gamme, c.compteur_de_gamme, c.frequence,
       c.freq_norm, c.designation, c.charge, c.nb_intervenants, c.plan_num, c.combi_rang, c.nb_combi,
       CASE
           WHEN c.plan_num IS NULL THEN (900000 + c.raw_id)::numeric
           WHEN c.nb_combi = 1     THEN c.plan_num
           ELSE c.plan_num * 1000::numeric + c.combi_rang::numeric
       END AS pm_no,
       -- en DERNIERE position : CREATE OR REPLACE VIEW refuse d'inserer une
       -- colonne au milieu ("cannot change name of view column")
       c.organisation_maintenance
FROM counted c;
