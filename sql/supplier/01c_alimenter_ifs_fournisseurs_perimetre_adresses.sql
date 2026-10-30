-- ============================================================================
-- Adresses et moyens de communication des fournisseurs du perimetre
-- (clean_data.ifs_fournisseurs_perimetre, script 01b), uniquement depuis SAP :
--   adresses       : adresse propre (lfa1.adrnr) + adresses des partenaires
--                    (wyt3 RS / BA / VA / SP -> lfa1 du partenaire -> adrc),
--                    une ligne par (fournisseur, adresse)
--   communications : adr2 telephone / portable, adr3 fax, adr4 teletex,
--                    adr5 telex, adr6 e-mail, pour chacune de ces adresses ;
--                    seulement les numeros de l'adresse (persnumber vide), pas
--                    ceux des personnes de contact
-- Appelee par clean_data.alimenter_ifs_fournisseurs_perimetre() (ecran Finance >
-- Fournisseurs, onglets Adresses et Méthodes de communication).
-- ============================================================================

CREATE TABLE IF NOT EXISTS clean_data.ifs_fournisseurs_perimetre_adresse (
    numero_compte_fournisseur VARCHAR      NOT NULL,
    numero_compte_ifs         VARCHAR(20),
    source                    VARCHAR(20)  NOT NULL,
    address_id                VARCHAR(10)  NOT NULL,
    fonction                  VARCHAR(2),           -- NULL = adresse propre, sinon wyt3.parvw
    fonction_libelle          VARCHAR(40)  NOT NULL,
    partenaire_sap            VARCHAR(10),          -- wyt3.lifn2 (NULL = adresse propre)
    nom                       VARCHAR(160),
    rue                       VARCHAR(120),
    complement_adresse        VARCHAR(120),
    code_postal               VARCHAR(10),
    localite                  VARCHAR(40),
    region                    VARCHAR(3),
    pays                      VARCHAR(3),
    langue                    VARCHAR(2),
    boite_postale             VARCHAR(10),
    valide_du                 DATE,
    valide_au                 DATE,
    CONSTRAINT pk_ifs_fournisseurs_perimetre_adresse PRIMARY KEY (numero_compte_fournisseur, address_id)
);

CREATE TABLE IF NOT EXISTS clean_data.ifs_fournisseurs_perimetre_communication (
    numero_compte_fournisseur VARCHAR      NOT NULL,
    numero_compte_ifs         VARCHAR(20),
    source                    VARCHAR(20)  NOT NULL,
    address_id                VARCHAR(10)  NOT NULL,
    fonction_libelle          VARCHAR(40)  NOT NULL,
    methode                   VARCHAR(10)  NOT NULL
        CONSTRAINT ck_ifs_fournisseurs_perimetre_comm_methode
        CHECK (methode IN ('TELEPHONE', 'PORTABLE', 'FAX', 'TELETEX', 'TELEX', 'EMAIL')),
    valeur                    VARCHAR(241) NOT NULL,
    extension                 VARCHAR(10),
    pays                      VARCHAR(3),
    par_defaut                BOOLEAN      NOT NULL,
    num_sequence              VARCHAR(3)   NOT NULL,  -- consnumber SAP
    CONSTRAINT pk_ifs_fournisseurs_perimetre_communication
        PRIMARY KEY (numero_compte_fournisseur, address_id, methode, num_sequence)
);

COMMENT ON TABLE clean_data.ifs_fournisseurs_perimetre_adresse IS
    'Adresses SAP des fournisseurs de ifs_fournisseurs_perimetre : adresse propre + partenaires wyt3. Rechargee par alimenter_ifs_fournisseurs_perimetre_adresses().';
COMMENT ON TABLE clean_data.ifs_fournisseurs_perimetre_communication IS
    'Moyens de communication SAP (adr2 a adr6) des adresses de ifs_fournisseurs_perimetre_adresse. Rechargee par alimenter_ifs_fournisseurs_perimetre_adresses().';

CREATE OR REPLACE FUNCTION clean_data.alimenter_ifs_fournisseurs_perimetre_adresses()
 RETURNS void
 LANGUAGE plpgsql
AS $function$
DECLARE
   v_nb_adr INTEGER;
   v_nb_comm INTEGER;
BEGIN
   -- DELETE et non TRUNCATE (verrou exclusif) : l'ecran lit ces tables pendant
   -- le calcul, TRUNCATE provoquait un interblocage (deadlock du 30/10/2026)
   DELETE FROM clean_data.ifs_fournisseurs_perimetre_communication;
   DELETE FROM clean_data.ifs_fournisseurs_perimetre_adresse;

   INSERT INTO clean_data.ifs_fournisseurs_perimetre_adresse (
      numero_compte_fournisseur, numero_compte_ifs, source, address_id, fonction,
      fonction_libelle, partenaire_sap, nom, rue, complement_adresse, code_postal,
      localite, region, pays, langue, boite_postale, valide_du, valide_au
   )
   WITH liens AS (
       -- Adresse propre du fournisseur
       SELECT p.numero_compte_fournisseur, p.numero_compte_ifs, p.source,
              a.adrnr, NULL::varchar AS fonction, NULL::varchar AS partenaire
         FROM clean_data.ifs_fournisseurs_perimetre p
         JOIN raw_data.lfa1 a ON a.lifnr::text = p.numero_compte_fournisseur
        WHERE NULLIF(TRIM(a.adrnr), '') IS NOT NULL
       UNION ALL
       -- Adresses des partenaires : une fonction par (fournisseur, adresse),
       -- RS > BA > VA > SP comme le script 04 ; l'adresse propre (RS = lui-meme,
       -- cas le plus frequent) n'est pas repetee
       (SELECT DISTINCT ON (p.numero_compte_fournisseur, a2.adrnr)
               p.numero_compte_fournisseur, p.numero_compte_ifs, p.source,
               a2.adrnr, w.parvw::varchar, a2.lifnr::varchar
          FROM clean_data.ifs_fournisseurs_perimetre p
          JOIN raw_data.lfa1 a  ON a.lifnr::text = p.numero_compte_fournisseur
          JOIN raw_data.wyt3 w  ON w.lifnr = a.lifnr AND w.parvw IN ('RS', 'BA', 'VA', 'SP')
          JOIN raw_data.lfa1 a2 ON a2.lifnr = w.lifn2 AND COALESCE(a2.loevm, '') <> 'X'
         WHERE NULLIF(TRIM(a2.adrnr), '') IS NOT NULL
           AND a2.adrnr IS DISTINCT FROM a.adrnr
         ORDER BY p.numero_compte_fournisseur, a2.adrnr,
                  array_position(ARRAY['RS', 'BA', 'VA', 'SP'], w.parvw::text))
   )
   SELECT l.numero_compte_fournisseur, l.numero_compte_ifs, l.source, l.adrnr, l.fonction,
          CASE l.fonction
              WHEN 'RS' THEN 'Auteur de la facture'
              WHEN 'BA' THEN 'Adresse de commande'
              WHEN 'VA' THEN 'Adresse contrat'
              WHEN 'SP' THEN 'Transporteur'
              ELSE 'Adresse du fournisseur'
          END,
          LTRIM(l.partenaire, '0'),
          NULLIF(CONCAT_WS(' ', NULLIF(TRIM(c.name1), ''), NULLIF(TRIM(c.name2), '')), ''),
          NULLIF(CONCAT_WS(' ', NULLIF(TRIM(c.house_num1), ''), NULLIF(TRIM(c.street), '')), ''),
          NULLIF(CONCAT_WS(' ', NULLIF(TRIM(c.str_suppl1), ''), NULLIF(TRIM(c.str_suppl2), ''),
                           NULLIF(TRIM(c.str_suppl3), '')), ''),
          NULLIF(TRIM(c.post_code1), ''),
          NULLIF(TRIM(c.city1), ''),
          NULLIF(TRIM(c.region), ''),
          COALESCE(public.get_transcodification('COUNTRY', c.country), NULLIF(TRIM(c.country), '')),
          NULLIF(TRIM(c.langu), ''),
          NULLIF(TRIM(c.po_box), ''),
          clean_data.fn_date_sap(c.date_from),
          CASE WHEN c.date_to < '99991231' THEN clean_data.fn_date_sap(c.date_to) END
     FROM liens l
     -- Version d'adresse la plus recente (adrc est versionnee par date_from)
     JOIN LATERAL (
         SELECT * FROM raw_data.adrc c
          WHERE c.addrnumber = l.adrnr
          ORDER BY c.date_from DESC
          LIMIT 1
     ) c ON TRUE;

   GET DIAGNOSTICS v_nb_adr = ROW_COUNT;

   INSERT INTO clean_data.ifs_fournisseurs_perimetre_communication (
      numero_compte_fournisseur, numero_compte_ifs, source, address_id, fonction_libelle,
      methode, valeur, extension, pays, par_defaut, num_sequence
   )
   WITH comm AS (
       -- adr2 : r3_user = '3' -> portable (SAP « numero de telephone mobile »)
       SELECT addrnumber, persnumber, consnumber, date_from,
              CASE WHEN r3_user = '3' THEN 'PORTABLE' ELSE 'TELEPHONE' END AS methode,
              tel_number AS valeur, tel_extens AS extension, country, flgdefault
         FROM raw_data.adr2
       UNION ALL
       SELECT addrnumber, persnumber, consnumber, date_from, 'FAX',
              fax_number, fax_extens, country, flgdefault FROM raw_data.adr3
       UNION ALL
       SELECT addrnumber, persnumber, consnumber, date_from, 'TELETEX',
              ttx_number, NULL, NULL, flgdefault FROM raw_data.adr4
       UNION ALL
       SELECT addrnumber, persnumber, consnumber, date_from, 'TELEX',
              tlx_number, NULL, NULL, flgdefault FROM raw_data.adr5
       UNION ALL
       SELECT addrnumber, persnumber, consnumber, date_from, 'EMAIL',
              smtp_addr, NULL, NULL, flgdefault FROM raw_data.adr6
   )
   SELECT DISTINCT ON (ad.numero_compte_fournisseur, ad.address_id, m.methode, m.consnumber)
          ad.numero_compte_fournisseur, ad.numero_compte_ifs, ad.source, ad.address_id,
          ad.fonction_libelle, m.methode, TRIM(m.valeur), NULLIF(TRIM(m.extension), ''),
          COALESCE(public.get_transcodification('COUNTRY', m.country), NULLIF(TRIM(m.country), '')),
          COALESCE(m.flgdefault, '') = 'X',
          m.consnumber
     FROM clean_data.ifs_fournisseurs_perimetre_adresse ad
     JOIN comm m ON m.addrnumber = ad.address_id
    WHERE COALESCE(TRIM(m.persnumber), '') = ''
      AND NULLIF(TRIM(m.valeur), '') IS NOT NULL
    -- Version la plus recente de chaque numero (versionne par date_from)
    ORDER BY ad.numero_compte_fournisseur, ad.address_id, m.methode, m.consnumber, m.date_from DESC;

   GET DIAGNOSTICS v_nb_comm = ROW_COUNT;

   RAISE NOTICE 'ifs_fournisseurs_perimetre : % adresses, % moyens de communication', v_nb_adr, v_nb_comm;
END;
$function$;
