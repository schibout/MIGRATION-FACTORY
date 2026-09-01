-- =====================================================
-- Procedure : clean_data.sp_enrich_file_customer_ids()
--
-- OBJET : completer les identifiants VIDES de raw_data.file_customer
--   * kunnr        numero de compte client SAP, depuis raw_data.KNA1 / KNB1
--   * siren        depuis SAP (STCD1 / STCEG), sinon raw_data.client_adresse_phl
--   * tax_number_1 le SIRET, depuis SAP (STCD1 a 14 chiffres), sinon PHL
--
-- REGLE ABSOLUE : la procedure ne REMPLACE jamais une valeur renseignee, elle
-- ne fait que combler les vides. Seule exception, l'etape 0 : elle reformate
-- kunnr (et uniquement kunnr) au format SAP a 10 caracteres, ce qui n'en
-- change pas la valeur metier. Elle est donc rejouable sans dommage.
--
-- LIEN AVEC PHL : raw_data.client_adresse_phl.mnemo = file_customer.search_term
-- (le terme de recherche du fichier porte le mnemonique du client PHL).
-- La table PHL porte le SIREN (9 caracteres) et le NIC (colonne `siret`,
-- 5 chiffres) : le SIRET complet est la concatenation des deux.
--
-- ATTENTION, raw_data.file_customer EMPILE les chargements successifs
-- (l'import ne purge pas la table). La procedure traite TOUTES les lignes, y
-- compris celles des chargements precedents : c'est voulu, l'enrichissement
-- d'une vieille ligne est sans effet puisque clean_data.v_customer_source ne
-- retient que le chargement le plus recent.
--
-- Constate au 2026-09-01 sur les 197 lignes du dernier chargement :
--   kunnr        16 vides -> 16 resolus (100%)
--   kunnr        23 valeurs a 9 caracteres reformatees en 10 (etape 0)
--   siren       112 valeurs polluees par une decimale '.0' -> nettoyees
--   siren        85 vides -> 17 resolus (12 via KNA1.STCD1, 8 via PHL, dont 3
--                communs), 68 restent vides
--   tax_number_1 63 vides ->  3 resolus, 60 restent vides
-- Le rendement SIREN/SIRET est faible parce que les SOURCES ne portent pas
-- l'information : pour ces clients KNA1.STCD1 est vide ou heteroclite, et le
-- `siren` de client_adresse_phl est souvent un code interne alphanumerique
-- ('005CON001', 'DE1141167') et non un vrai SIREN. Aucune regle ne peut
-- inventer ces numeros : il faudra une saisie ou une source externe.
-- =====================================================

CREATE OR REPLACE PROCEDURE clean_data.sp_enrich_file_customer_ids()
 LANGUAGE plpgsql
AS $procedure$
DECLARE
    v_kunnr_format  INTEGER := 0;
    v_kunnr_rempli  INTEGER := 0;
    v_siren_nettoye INTEGER := 0;
    v_siren_rempli  INTEGER := 0;
    v_siret_rempli  INTEGER := 0;
BEGIN

    RAISE NOTICE 'Enrichissement des identifiants file_customer - %',
                 TO_CHAR(NOW(), 'YYYY-MM-DD HH24:MI:SS');

    -- ------------------------------------------------------------------
    -- ETAPE 0 : format du numero de compte SAP
    -- KNA1.KUNNR est cadre a 10 caracteres avec des zeros de tete
    -- ('0100004096'). Le fichier porte tantot ce format, tantot le meme
    -- numero sans zero de tete ('100007726'), tantot un numero alphanumerique
    -- ('S0000221', 'D225222') qui, lui, n'est pas cadre.
    -- Les 20 procedures *_from_file_customer joignent SAP par
    -- `fc.kunnr = k.KUNNR` : les valeurs non cadrees ne joignent JAMAIS et
    -- perdent silencieusement tout l'enrichissement SAP (23 clients au
    -- 2026-09-01). On les recadre, uniquement quand la forme cadree existe
    -- reellement dans KNA1.
    -- ------------------------------------------------------------------
    UPDATE raw_data.file_customer f
    SET kunnr = k.kunnr
    FROM raw_data.KNA1 k
    WHERE NULLIF(TRIM(f.kunnr), '') IS NOT NULL
      AND TRIM(f.kunnr) <> TRIM(k.kunnr)
      AND TRIM(k.kunnr) = LPAD(TRIM(f.kunnr), 10, '0');

    GET DIAGNOSTICS v_kunnr_format = ROW_COUNT;
    RAISE NOTICE '  Etape 0 : % kunnr recadres au format SAP 10 caracteres', v_kunnr_format;

    -- ------------------------------------------------------------------
    -- ETAPE 1 : kunnr vide -> numero de compte SAP
    -- Le fichier porte alors le numero dans num_corrige, soit au format SAP
    -- ('D225222'), soit sans zero de tete ('100007912'). On compare donc les
    -- deux numeros zeros de tete retires -- la comparaison reste exacte, il
    -- n'y a aucun rapprochement approximatif ici.
    -- KNB1 (niveau societe) sert de CONTROLE : on privilegie un compte ouvert
    -- dans une societe et non marque a supprimer, sans exiger sa presence
    -- (certains clients n'ont pas de volet comptable).
    -- ------------------------------------------------------------------
    UPDATE raw_data.file_customer f
    SET kunnr = s.kunnr
    FROM (
        SELECT f2.raw_id, k.kunnr
        FROM raw_data.file_customer f2
        JOIN LATERAL (
            SELECT k2.kunnr
            FROM raw_data.KNA1 k2
            WHERE regexp_replace(TRIM(k2.kunnr), '^0+', '')
                = regexp_replace(TRIM(f2.num_corrige), '^0+', '')
            ORDER BY
                -- compte SAP non marque a supprimer d'abord
                CASE WHEN COALESCE(TRIM(k2.loevm), '') = '' THEN 0 ELSE 1 END,
                -- puis compte disposant d'un volet societe (KNB1) actif
                CASE WHEN EXISTS (
                        SELECT 1 FROM raw_data.KNB1 b
                        WHERE TRIM(b.kunnr) = TRIM(k2.kunnr)
                          AND COALESCE(TRIM(b.loevm), '') = ''
                     ) THEN 0 ELSE 1 END,
                k2.kunnr
            LIMIT 1
        ) k ON TRUE
        WHERE NULLIF(TRIM(f2.kunnr), '') IS NULL
          AND NULLIF(TRIM(f2.num_corrige), '') IS NOT NULL
    ) s
    WHERE f.raw_id = s.raw_id;

    GET DIAGNOSTICS v_kunnr_rempli = ROW_COUNT;
    RAISE NOTICE '  Etape 1 : % kunnr renseignes depuis SAP', v_kunnr_rempli;

    -- ------------------------------------------------------------------
    -- ETAPE 2 : nettoyage du SIREN
    -- L'export Excel a transforme le SIREN en nombre a virgule flottante :
    -- '350863791.0' (112 lignes au 2026-09-01). On retire la decimale, sans
    -- toucher aux SIREN alphanumeriques (codes internes type '005CON001').
    -- ------------------------------------------------------------------
    UPDATE raw_data.file_customer
    SET siren = split_part(TRIM(siren), '.', 1)
    WHERE TRIM(siren) ~ '^[0-9]+\.0+$';

    GET DIAGNOSTICS v_siren_nettoye = ROW_COUNT;
    RAISE NOTICE '  Etape 2 : % siren nettoyes de leur decimale ".0"', v_siren_nettoye;

    -- ------------------------------------------------------------------
    -- ETAPE 3 : siren vide -> SAP, puis PHL, puis SIRET du fichier
    --   1. KNA1.STCD1 quand il porte 9 chiffres      -> c'est le SIREN
    --   2. KNA1.STCD1 quand il porte 14 chiffres     -> SIRET, SIREN = 9 premiers
    --   3. KNA1.STCEG 'FR' + 11 chiffres             -> SIREN = 9 derniers
    --   4. client_adresse_phl.siren via le mnemonique, s'il est bien numerique
    --   5. le SIRET deja present dans le fichier     -> SIREN = 9 premiers
    -- STCD1 est heterogene dans SAP (6, 11, 13 chiffres...) : seules les
    -- longueurs 9 et 14 sont exploitables, tout le reste est ignore.
    -- ------------------------------------------------------------------
    UPDATE raw_data.file_customer f
    SET siren = s.siren
    FROM (
        SELECT f2.raw_id,
               COALESCE(
                   CASE WHEN length(regexp_replace(COALESCE(k.stcd1, ''), '\D', '', 'g')) = 9
                        THEN regexp_replace(k.stcd1, '\D', '', 'g') END,
                   CASE WHEN length(regexp_replace(COALESCE(k.stcd1, ''), '\D', '', 'g')) = 14
                        THEN left(regexp_replace(k.stcd1, '\D', '', 'g'), 9) END,
                   CASE WHEN UPPER(TRIM(COALESCE(k.stceg, ''))) ~ '^FR[0-9A-Z]{2}[0-9]{9}$'
                        THEN right(TRIM(k.stceg), 9) END,
                   CASE WHEN TRIM(COALESCE(p.siren, '')) ~ '^[0-9]{9}$'
                        THEN TRIM(p.siren) END,
                   CASE WHEN length(regexp_replace(COALESCE(f2.tax_number_1, ''), '\D', '', 'g')) = 14
                        THEN left(regexp_replace(f2.tax_number_1, '\D', '', 'g'), 9) END
               ) AS siren
        FROM raw_data.file_customer f2
        LEFT JOIN raw_data.KNA1 k
               ON TRIM(k.kunnr) = TRIM(f2.kunnr)
        LEFT JOIN LATERAL (
            SELECT a.siren
            FROM raw_data.client_adresse_phl a
            WHERE UPPER(TRIM(a.mnemo)) = UPPER(TRIM(f2.search_term))
              AND NULLIF(TRIM(a.siren), '') IS NOT NULL
            ORDER BY TRIM(a.id_client)
            LIMIT 1
        ) p ON TRUE
        WHERE NULLIF(TRIM(f2.siren), '') IS NULL
    ) s
    WHERE f.raw_id = s.raw_id
      AND s.siren IS NOT NULL;

    GET DIAGNOSTICS v_siren_rempli = ROW_COUNT;
    RAISE NOTICE '  Etape 3 : % siren renseignes', v_siren_rempli;

    -- ------------------------------------------------------------------
    -- ETAPE 4 : tax_number_1 (SIRET) vide -> SAP, puis PHL
    --   1. KNA1.STCD1 quand il porte 14 chiffres
    --   2. client_adresse_phl : SIREN (9 chiffres) || NIC (colonne `siret`,
    --      5 chiffres). Les deux doivent etre numeriques, sinon on n'ecrit
    --      rien : la table PHL loge aussi des codes internes ('005CON001')
    --      et des NIC tronques (',', '05').
    -- Le fichier n'a pas de colonne siret dediee : le SIRET vit dans
    -- tax_number_1 (14 chiffres), comme le montre le reste du module.
    -- ------------------------------------------------------------------
    UPDATE raw_data.file_customer f
    SET tax_number_1 = s.siret
    FROM (
        SELECT f2.raw_id,
               COALESCE(
                   CASE WHEN length(regexp_replace(COALESCE(k.stcd1, ''), '\D', '', 'g')) = 14
                        THEN regexp_replace(k.stcd1, '\D', '', 'g') END,
                   CASE WHEN TRIM(COALESCE(p.siren, '')) ~ '^[0-9]{9}$'
                         AND TRIM(COALESCE(p.siret, '')) ~ '^[0-9]{5}$'
                        THEN TRIM(p.siren) || TRIM(p.siret) END
               ) AS siret
        FROM raw_data.file_customer f2
        LEFT JOIN raw_data.KNA1 k
               ON TRIM(k.kunnr) = TRIM(f2.kunnr)
        LEFT JOIN LATERAL (
            SELECT a.siren, a.siret
            FROM raw_data.client_adresse_phl a
            WHERE UPPER(TRIM(a.mnemo)) = UPPER(TRIM(f2.search_term))
              AND NULLIF(TRIM(a.siren), '') IS NOT NULL
            ORDER BY TRIM(a.id_client)
            LIMIT 1
        ) p ON TRUE
        WHERE NULLIF(TRIM(f2.tax_number_1), '') IS NULL
    ) s
    WHERE f.raw_id = s.raw_id
      AND s.siret IS NOT NULL;

    GET DIAGNOSTICS v_siret_rempli = ROW_COUNT;
    RAISE NOTICE '  Etape 4 : % tax_number_1 (SIRET) renseignes', v_siret_rempli;

    RAISE NOTICE 'Termine - kunnr recadres %, kunnr remplis %, siren nettoyes %, siren remplis %, siret remplis %',
                 v_kunnr_format, v_kunnr_rempli, v_siren_nettoye, v_siren_rempli, v_siret_rempli;

EXCEPTION
    WHEN OTHERS THEN
        RAISE EXCEPTION 'Erreur lors de l''enrichissement de file_customer: %', SQLERRM;
END;
$procedure$;

COMMENT ON PROCEDURE clean_data.sp_enrich_file_customer_ids() IS
'Complete les identifiants vides de raw_data.file_customer : kunnr depuis SAP (KNA1/KNB1, via num_corrige), siren et SIRET (tax_number_1) depuis SAP puis raw_data.client_adresse_phl (mnemo = search_term). Ne remplace jamais une valeur deja renseignee ; recadre kunnr au format SAP 10 caracteres. Rejouable.';

-- Utilisation
--   CALL clean_data.sp_enrich_file_customer_ids();
--
-- Controle AVANT / APRES (dernier chargement) :
-- SELECT count(*) FILTER (WHERE NULLIF(TRIM(kunnr),'') IS NULL)        AS sans_kunnr,
--        count(*) FILTER (WHERE NULLIF(TRIM(siren),'') IS NULL)        AS sans_siren,
--        count(*) FILTER (WHERE NULLIF(TRIM(tax_number_1),'') IS NULL) AS sans_siret,
--        count(*) FILTER (WHERE siren LIKE '%.0')                      AS siren_pollues,
--        count(*) FILTER (WHERE NULLIF(TRIM(kunnr),'') IS NOT NULL
--                           AND NOT EXISTS (SELECT 1 FROM raw_data.KNA1 k
--                                            WHERE TRIM(k.kunnr) = TRIM(f.kunnr))) AS kunnr_sans_correspondance_sap
--   FROM raw_data.file_customer f
--  WHERE f.loaded_at = (SELECT max(loaded_at) FROM raw_data.file_customer);
--
-- Attendu apres execution : sans_kunnr 0, siren_pollues 0,
-- kunnr_sans_correspondance_sap 0, sans_siren ~40, sans_siret ~60.
