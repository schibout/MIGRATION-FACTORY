CREATE OR REPLACE FUNCTION clean_data.alimenter_ifs_fournisseurs()
 RETURNS void
 LANGUAGE plpgsql
AS $function$
BEGIN
   -- Vider et réinsérer
   TRUNCATE TABLE clean_data.ifs_fournisseurs;
   -- Insérer données de base depuis selection_fournisseurs (source principale)
   -- avec enrichissement depuis les tables SAP (LEFT JOIN)
   INSERT INTO clean_data.ifs_fournisseurs (company,
      numero_compte_fournisseur, address_id, nom_1, rue, localite, code_postal,
      cle_pays, siret, tva, code_tva_ifs, societe, organisation_achats,
      conditions_paiement_compta, conditions_paiement_achats,
      incoterms_1, incoterms_2, telephone_1, telephone_2, date_creation_sap,
      destinataire_paiement, language_sap
   )
   SELECT
      'TRIMET' as company,
      sf.numero_compte_sap as numero_compte_fournisseur,
        '01' as address_id,
      
      -- === PRIORITÉ 1: selection_fournisseurs | PRIORITÉ 2: SAP ===
      
      -- Nom: selection_fournisseurs.denomination_sociale > SAP.name1
      COALESCE(NULLIF(TRIM(sf.denomination_sociale), ''), a.name1) as nom_1,
      
      -- Rue: selection_fournisseurs (libelle_concatene ou construction) > SAP.stras
      COALESCE(
          NULLIF(TRIM(sf.libelle_concatene), ''),
          NULLIF(TRIM(CONCAT_WS(' ', sf.numero_voie, sf.indice_numero_voie, sf.type_voie, sf.libelle_voie)), ''),
          a.stras
      ) as rue,
      
      -- Localité: selection_fournisseurs.localite > SAP.ort01
      COALESCE(NULLIF(TRIM(sf.localite), ''), a.ort01) as localite,
      
      -- Code postal: selection_fournisseurs.code_postal > SAP.pstlz
      COALESCE(NULLIF(TRIM(sf.code_postal), ''), a.pstlz) as code_postal,
      
      -- Pays: selection_fournisseurs.code_pays > SAP.land1
      COALESCE(NULLIF(TRIM(sf.code_pays), ''), a.land1) as cle_pays,
      
      -- SIRET: selection_fournisseurs.numero_siret > SAP.stcd1
      COALESCE(NULLIF(TRIM(sf.numero_siret), ''), a.stcd1) as siret,
      
      -- TVA: selection_fournisseurs.numero_tva_intra > SAP.stceg
      COALESCE(NULLIF(TRIM(sf.numero_tva_intra), ''), a.stceg) as tva,
      
      -- Code TVA IFS: selection_fournisseurs.code_tva_ifs
      sf.code_tva_ifs as code_tva_ifs,
      
      -- Société: uniquement SAP (pas dans selection_fournisseurs)
      sap_data.societe as societe,
      
      -- Organisation achats: uniquement SAP
      sap_data.organisation_achats,
      
      -- Conditions paiement: selection_fournisseurs > SAP
      COALESCE(NULLIF(TRIM(sf.condition_paiement_ifs), ''), sap_data.conditions_paiement_compta) as conditions_paiement_compta,
      COALESCE(NULLIF(TRIM(sf.condition_paiement_ifs), ''), sap_data.conditions_paiement_achats) as conditions_paiement_achats,
      
      -- Incoterms: uniquement SAP
      sap_data.incoterms_1,
      sap_data.incoterms_2,
      
      -- Téléphones: selection_fournisseurs > SAP
      COALESCE(NULLIF(TRIM(sf.telephone_1), ''), a.telf1) as telephone_1,
      COALESCE(NULLIF(TRIM(sf.telephone_2), ''), NULLIF(TRIM(sf.telephone_3), ''), a.telf2) as telephone_2,
      
      -- Date création: uniquement SAP
      -- lfa1.erdat est stocké en texte : selon l'extraction il arrive au format
      -- SAP brut (YYYYMMDD) ou déjà normalisé en ISO (YYYY-MM-DD). On teste le
      -- format avant conversion, sinon TO_DATE(...,'YYYYMMDD') plante sur l'ISO
      -- ("date/time field value out of range"). Format inattendu -> fallback import.
      CASE
          WHEN TRIM(COALESCE(a.erdat, '')) ~ '^[0-9]{8}$' AND TRIM(a.erdat) <> '00000000'
              THEN TO_DATE(TRIM(a.erdat), 'YYYYMMDD')
          WHEN TRIM(COALESCE(a.erdat, '')) ~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}$'
              THEN TO_DATE(TRIM(a.erdat), 'YYYY-MM-DD')
          ELSE sf.date_import::date
      END as date_creation_sap,
      
      -- Destinataire paiement: uniquement SAP
      sap_data.destinataire_paiement,
      
      -- Langue: selection_fournisseurs.langue > SAP.spras
      COALESCE(
          public.get_transcodification('LANGUAGE', NULLIF(TRIM(sf.langue), '')), 
          public.get_transcodification('LANGUAGE', a.spras)
      ) as language_sap
      
   FROM raw_data.selection_fournisseurs sf
   LEFT JOIN raw_data.lfa1 a ON sf.numero_compte_sap::text = a.lifnr::text
   LEFT JOIN LATERAL (
       -- Sous-requête pour récupérer les données agrégées SAP (fallback si pas dans selection_fournisseurs)
       SELECT 
           string_agg(DISTINCT b.bukrs::text, ', '::text ORDER BY (b.bukrs::text)) as societe,
           m.ekorg as organisation_achats,
           min(b.zterm::text) as conditions_paiement_compta,
           m.zterm as conditions_paiement_achats,
           m.inco1 as incoterms_1,
           m.inco2 as incoterms_2,
           min(b.lnrzb) as destinataire_paiement
       FROM raw_data.lfb1 b
       JOIN raw_data.lfm1 m ON b.mandt::text = m.mandt::text AND b.lifnr::text = m.lifnr::text
       WHERE b.lifnr::text = sf.numero_compte_sap::text
         AND m.ekorg::text = (
             SELECT min(m2.ekorg::text)
             FROM raw_data.lfm1 m2
             WHERE m2.mandt::text = m.mandt::text AND m2.lifnr::text = m.lifnr::text
         )
       GROUP BY m.ekorg, m.zterm, m.inco1, m.inco2
       LIMIT 1
   ) sap_data ON TRUE;
   /*-- Mettre à jour les KPI
   UPDATE clean_data.ifs_fournisseurs
   SET
       (derniere_date_commande, devise_principale,
        ca_2025, ca_2024, ca_2023, ca_2022, ca_2021, ca_2020,
        nb_commandes_2025, nb_commandes_2024, nb_commandes_2023,
        nb_commandes_2022, nb_commandes_2021, nb_commandes_2020) =
   (
       SELECT
           MAX(e.budat::DATE),
           MODE() WITHIN GROUP (ORDER BY ek.waers),
           SUM(CASE WHEN EXTRACT(YEAR FROM e.budat::DATE) = 2025 THEN e.dmbtr::NUMERIC ELSE 0 END),
           SUM(CASE WHEN EXTRACT(YEAR FROM e.budat::DATE) = 2024 THEN e.dmbtr::NUMERIC ELSE 0 END),
           SUM(CASE WHEN EXTRACT(YEAR FROM e.budat::DATE) = 2023 THEN e.dmbtr::NUMERIC ELSE 0 END),
           SUM(CASE WHEN EXTRACT(YEAR FROM e.budat::DATE) = 2022 THEN e.dmbtr::NUMERIC ELSE 0 END),
           SUM(CASE WHEN EXTRACT(YEAR FROM e.budat::DATE) = 2021 THEN e.dmbtr::NUMERIC ELSE 0 END),
           SUM(CASE WHEN EXTRACT(YEAR FROM e.budat::DATE) = 2020 THEN e.dmbtr::NUMERIC ELSE 0 END),
           COUNT(CASE WHEN EXTRACT(YEAR FROM e.budat::DATE) = 2025 THEN 1 END),
           COUNT(CASE WHEN EXTRACT(YEAR FROM e.budat::DATE) = 2024 THEN 1 END),
           COUNT(CASE WHEN EXTRACT(YEAR FROM e.budat::DATE) = 2023 THEN 1 END),
           COUNT(CASE WHEN EXTRACT(YEAR FROM e.budat::DATE) = 2022 THEN 1 END),
           COUNT(CASE WHEN EXTRACT(YEAR FROM e.budat::DATE) = 2021 THEN 1 END),
           COUNT(CASE WHEN EXTRACT(YEAR FROM e.budat::DATE) = 2020 THEN 1 END)
       FROM raw_data.ekbe e
       JOIN raw_data.ekko ek ON e.mandt = ek.mandt AND e.ebeln = ek.ebeln
       WHERE ek.lifnr = ifs_fournisseurs.numero_compte_fournisseur
         AND e.bewtp = 'E'
         AND e.shkzg = 'S'
         AND e.budat IS NOT NULL
   );
   UPDATE clean_data.ifs_fournisseurs SET date_maj = CURRENT_TIMESTAMP;*/
   RAISE NOTICE 'Table IFS_fournisseurs alimentée avec succès';
END;
$function$
;
