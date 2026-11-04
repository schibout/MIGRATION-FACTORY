/* =====================================================================
   Extraction pour le contrôle de gestion :
   Postes techniques et équipements exportés vers IFS + centre de coûts SAP
   ---------------------------------------------------------------------
   Périmètre  : exactement ce qui part vers IFS
                - clean_data.equipment_functional (postes techniques)
                - clean_data.equipment_serial     (équipements)
   Centre de coûts : SAP ILOA.KOSTL (données de localisation/imputation)
                - poste technique : IFLOT.ILOAN -> ILOA
                - équipement      : EQUZ.ILOAN (période la plus récente) -> ILOA
   Libellé    : CSKT (langue F), version la plus récente
   CC IFS     : get_transcodification('COST_CENTER', kostl, 'SAP', 'IFS')
                -> NULL si le centre de coûts SAP n'est pas transcodé
   NB : clean_data.*.cost_center est aujourd'hui vide (non alimenté par les
        loaders) -> le centre de coûts est relu dans SAP.
   Clé de réimport : SITE + CODE_IFS (= contract + mch_code dans IFS).
   Colonnes CENTRE_COUTS_CORRIGE / COMMENTAIRE_CDG laissées vides
   pour la saisie du contrôle de gestion.
   ===================================================================== */


/* ---------------------------------------------------------------------
   1. POSTES TECHNIQUES  (11 138 lignes au 02/11/2026, 10 891 avec CC)
   --------------------------------------------------------------------- */
SELECT
    ef.contract                                   AS "SITE",
    ef.mch_code                                   AS "CODE_IFS",
    o.sap_key                                     AS "CODE_SAP_TPLNR",
    ef.mch_name                                   AS "DESIGNATION",
    ef.sup_mch_code                               AS "POSTE_TECHNIQUE_PARENT",
    ef.obj_level                                  AS "NIVEAU_IFS",
    cc.kokrs                                      AS "PERIMETRE_ANALYTIQUE",
    cc.kostl                                      AS "CENTRE_COUTS_ACTUEL",
    cc.libelle                                    AS "LIBELLE_CENTRE_COUTS",
    public.get_transcodification('COST_CENTER', cc.kostl, 'SAP', 'IFS')
                                                  AS "CENTRE_COUTS_IFS",
    NULL::varchar                                 AS "CENTRE_COUTS_CORRIGE",
    NULL::varchar                                 AS "COMMENTAIRE_CDG"
FROM clean_data.equipment_functional ef
LEFT JOIN clean_data.maintenance_object o
       ON o.object_type = 'FUNC_LOC'
      AND o.is_active
      AND o.code = ef.mch_code
      -- désambiguïse les codes en double dans la source (ex. T095)
      AND SUBSTRING(COALESCE(o.designation, o.code), 1, 200) = ef.mch_name
LEFT JOIN LATERAL (
    SELECT
        NULLIF(TRIM(lo.kostl), '') AS kostl,
        lo.kokrs,
        (SELECT COALESCE(NULLIF(TRIM(t.ltext), ''), t.ktext)
           FROM raw_data.cskt t
          WHERE t.mandt = lo.mandt
            AND t.kokrs = lo.kokrs
            AND t.kostl = lo.kostl
            AND t.spras = 'F'
          ORDER BY t.datbi DESC
          LIMIT 1)                 AS libelle
    FROM raw_data.iflot il
    JOIN raw_data.iloa lo
      ON lo.mandt = il.mandt
     AND lo.iloan = il.iloan
    WHERE il.tplnr = o.sap_key
    LIMIT 1
) cc ON TRUE
ORDER BY ef.equipment_object_seq;


/* ---------------------------------------------------------------------
   2. ÉQUIPEMENTS  (5 201 lignes au 02/11/2026, 4 596 avec CC)
   --------------------------------------------------------------------- */
SELECT
    es.contract                                   AS "SITE",
    es.mch_code                                   AS "CODE_IFS",
    o.sap_key                                     AS "CODE_SAP_EQUNR",
    es.mch_name                                   AS "DESIGNATION",
    es.sup_mch_code                               AS "OBJET_PARENT",
    es.part_no                                    AS "ARTICLE",
    es.serial_no                                  AS "NUMERO_SERIE",
    cc.kokrs                                      AS "PERIMETRE_ANALYTIQUE",
    cc.kostl                                      AS "CENTRE_COUTS_ACTUEL",
    cc.libelle                                    AS "LIBELLE_CENTRE_COUTS",
    public.get_transcodification('COST_CENTER', cc.kostl, 'SAP', 'IFS')
                                                  AS "CENTRE_COUTS_IFS",
    NULL::varchar                                 AS "CENTRE_COUTS_CORRIGE",
    NULL::varchar                                 AS "COMMENTAIRE_CDG"
FROM clean_data.equipment_serial es
LEFT JOIN clean_data.maintenance_object o
       ON o.object_type = 'EQUIPMENT'
      AND o.is_active
      AND o.code = es.mch_code
LEFT JOIN LATERAL (
    SELECT
        NULLIF(TRIM(lo.kostl), '') AS kostl,
        lo.kokrs,
        (SELECT COALESCE(NULLIF(TRIM(t.ltext), ''), t.ktext)
           FROM raw_data.cskt t
          WHERE t.mandt = lo.mandt
            AND t.kokrs = lo.kokrs
            AND t.kostl = lo.kostl
            AND t.spras = 'F'
          ORDER BY t.datbi DESC
          LIMIT 1)                 AS libelle
    FROM raw_data.equz z
    JOIN raw_data.iloa lo
      ON lo.mandt = z.mandt
     AND lo.iloan = z.iloan
    WHERE z.equnr = o.sap_key
    -- période d'utilisation la plus récente (31 % des équipements n'ont
    -- pas de période ouverte 99991231 dans EQUZ)
    ORDER BY z.datbi DESC, z.eqlfn DESC
    LIMIT 1
) cc ON TRUE
ORDER BY es.equipment_object_seq;
