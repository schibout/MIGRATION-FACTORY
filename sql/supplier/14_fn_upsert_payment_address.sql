-- ============================================================================
-- Contrainte d'unicite requise par le ON CONFLICT de l'etape 2
-- ----------------------------------------------------------------------------
-- Sans elle, l'INSERT ... ON CONFLICT (company, identity, party_type_db,
-- way_id, address_id) leve
--   there is no unique or exclusion constraint matching the ON CONFLICT
--   specification
-- sur CHAQUE ligne. L'erreur etait avalee par le EXCEPTION WHEN OTHERS de la
-- boucle : l'etape 2 traitait ses lignes, n'en inserait aucune, et la fonction
-- se terminait sans echec visible -- aucune donnee bancaire dans IFS.
-- Les 5 colonnes sont deja sans NULL et la cle est deja unique sur les donnees
-- en place (verifie : 1854 lignes, 1854 cles distinctes).
-- ============================================================================
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint
         WHERE conrelid = 'clean_data.payment_address'::regclass
           AND conname  = 'uq_payment_address'
    ) THEN
        ALTER TABLE clean_data.payment_address
            ADD CONSTRAINT uq_payment_address
            UNIQUE (company, identity, party_type_db, way_id, address_id);
        RAISE NOTICE 'Contrainte uq_payment_address creee';
    END IF;
END $$;

CREATE OR REPLACE FUNCTION clean_data.fn_upsert_payment_address()
 RETURNS integer
 LANGUAGE plpgsql
AS $function$
DECLARE
    processed_count INTEGER := 0;
    upserted_count INTEGER := 0;
    default_count INTEGER := 0;
    error_count INTEGER := 0;
    v_start_time TIMESTAMP;
    rec RECORD;
    error_msg TEXT;
BEGIN
    v_start_time := CURRENT_TIMESTAMP;
    
    RAISE NOTICE '=== DÉBUT ALIMENTATION PAYMENT_ADDRESS ===';
    RAISE NOTICE 'Heure de début: %', v_start_time;
    
    -- Truncate de la table pour un chargement complet
    TRUNCATE TABLE clean_data.payment_address;
    RAISE NOTICE 'Table PAYMENT_ADDRESS vidée';
    
    -- ÉTAPE 1: Créer une adresse de paiement par défaut pour TOUS les fournisseurs depuis supplier_info_address (première adresse)
    RAISE NOTICE 'Étape 1: Création des adresses de paiement par défaut depuis supplier_info_address...';
    
    INSERT INTO clean_data.payment_address (
        company,
        identity,
        party_type_db,
        way_id,
        address_id,
        party_type,
        description,
        default_address,
        account,
        bic_code,
        blocked_for_use,
        mapping_type,
        bank_account_validated,
        bank_account_validated_db,
        created_timestamp,
        updated_timestamp
    )
    SELECT DISTINCT ON (sia.supplier_id)
        public.get_default_value('clean_data.payment_address', 'company', 'ADRESSE_DEFAUT') as company,
        sia.supplier_id as identity,
        public.get_default_value('clean_data.payment_address', 'party_type_db', 'ADRESSE_DEFAUT') as party_type_db,
        public.get_default_value('clean_data.payment_address', 'way_id', 'ADRESSE_DEFAUT') as way_id,
        sia.address_id as address_id,
        public.get_default_value('clean_data.payment_address', 'party_type', 'ADRESSE_DEFAUT') as party_type,
        public.get_default_value('clean_data.payment_address', 'description', 'ADRESSE_DEFAUT') as description,
        public.get_default_value('clean_data.payment_address', 'default_address', 'ADRESSE_DEFAUT') as default_address,
        public.get_default_value('clean_data.payment_address', 'account', 'ADRESSE_DEFAUT') as account,
        public.get_default_value('clean_data.payment_address', 'bic_code', 'ADRESSE_DEFAUT') as bic_code,
        public.get_default_value('clean_data.payment_address', 'blocked_for_use', 'ADRESSE_DEFAUT') as blocked_for_use,
        public.get_default_value('clean_data.payment_address', 'mapping_type', 'ADRESSE_DEFAUT') as mapping_type,
        public.get_default_value('clean_data.payment_address', 'bank_account_validated', 'ADRESSE_DEFAUT') as bank_account_validated,
        public.get_default_value('clean_data.payment_address', 'bank_account_validated_db', 'ADRESSE_DEFAUT') as bank_account_validated_db,
        CURRENT_TIMESTAMP as created_timestamp,
        CURRENT_TIMESTAMP as updated_timestamp
    FROM clean_data.supplier_info_address sia
    WHERE sia.supplier_id IS NOT NULL
      AND sia.is_deleted = FALSE
    ORDER BY sia.supplier_id, sia.address_id;
    
    GET DIAGNOSTICS default_count = ROW_COUNT;
    RAISE NOTICE 'Adresses par défaut créées: %', default_count;
    
    -- ÉTAPE 2: Ajouter les données bancaires si disponibles dans lfbk
    RAISE NOTICE 'Étape 2: Ajout des données bancaires depuis lfbk...';
    
    -- Chaine SAP des donnees bancaires :
    --   LFBK  = lien fournisseur -> compte (banks, bankl, bankn, bkont)
    --   TIBAN = IBAN reel, meme cle
    --   BNKA  = referentiel banques : nom (banka) et code SWIFT
    --
    -- DISTINCT ON : un fournisseur peut avoir plusieurs comptes (1065 cas),
    -- mais address_id vaut lfa1.adrnr, donc UN identifiant par fournisseur ;
    -- plusieurs comptes viseraient la meme cle ON CONFLICT et seul le dernier
    -- survivrait. On retient donc un compte, avec la meme regle deterministe
    -- que clean_data.fn_coordonnees_bancaires_sap (script 01) pour que
    -- payment_address et ifs_fournisseurs portent le MEME compte :
    -- d'abord celui qui a un IBAN, puis bvtyp, bankl, bankn.
    -- Les coordonnees bancaires sont deja resolues et stockees dans
    -- ifs_fournisseurs par le script 01, via
    -- clean_data.fn_coordonnees_bancaires_sap (chaine LFBK -> TIBAN -> BNKA,
    -- un compte par fournisseur car address_id = lfa1.adrnr en porte un seul).
    -- On relit ces colonnes au lieu de refaire la jointure : les deux tables
    -- ne peuvent plus diverger sur le compte retenu ni sur l'IBAN.
    FOR rec IN (
        SELECT
            COALESCE(f.company, 'TRIMET') as company,
            -- identity = numéro IFS du fichier (voir script 02) ; lifnr reste
            -- le numéro SAP, utilisé uniquement dans les traces.
            f.numero_compte_ifs       as identity_ifs,
            f.numero_compte_fournisseur as lifnr,
            f.address_id,
            f.pays_banque            as banks,
            f.code_banque            as bankl,
            f.numero_compte_bancaire as bankn,
            f.titulaire_compte       as koinh,
            f.nom_banque             as bank_name,
            f.swift_bic              as swift,
            f.iban_paiement          as iban_sap,
            1 as bank_seq
        FROM clean_data.ifs_fournisseurs f
        WHERE f.numero_compte_fournisseur IS NOT NULL
          AND NULLIF(TRIM(f.numero_compte_bancaire), '') IS NOT NULL
        ORDER BY f.numero_compte_fournisseur
    ) LOOP
        BEGIN
            processed_count := processed_count + 1;
            
            IF processed_count = 1 THEN
                RAISE NOTICE 'Premier enregistrement traité: lifnr=%, bankn=%', 
                            rec.lifnr, rec.bankn;
            END IF;
            
            -- Calculer l'IBAN si les données sont disponibles
            DECLARE
                v_iban TEXT;
            BEGIN
                -- IBAN deja resolu dans ifs_fournisseurs : TIBAN en priorite,
                -- repli sur le calcul pour les comptes FR absents de TIBAN.
                -- La regle vit dans fn_coordonnees_bancaires_sap, pas ici.
                v_iban := rec.iban_sap;
                
                -- Insertion/mise à jour des données bancaires
                INSERT INTO clean_data.payment_address (
                    company,
                    identity,
                    party_type_db,
                    way_id,
                    address_id,
                    party_type,
                    description,
                    default_address,
                    account,     -- IBAN ou numéro de compte
                    -- (cols supprimées comme demandé)
                    bic_code,
                    blocked_for_use,
                    mapping_type,
                    bank_account_validated,
                    bank_account_validated_db,
                    created_timestamp,
                    updated_timestamp
                ) VALUES (
                    rec.company,
                    rec.identity_ifs,  -- identity = numéro de compte IFS
                    public.get_default_value('clean_data.payment_address', 'party_type_db', 'BANQUE'),
                    public.get_default_value('clean_data.payment_address', 'way_id', 'BANQUE'),
                    -- address_id : le meme identifiant qu'a l'etape 1
                    -- (ifs_fournisseurs.address_id = lfa1.adrnr). On y ecrivait
                    -- le numero de fournisseur, qui ne correspond a aucune ligne
                    -- de supplier_info_address : la cle ON CONFLICT portant sur
                    -- address_id, l'etape 2 creait une 2e ligne au lieu de
                    -- completer celle de l'etape 1 avec les donnees bancaires.
                    rec.address_id,
                    public.get_default_value('clean_data.payment_address', 'party_type', 'BANQUE'),
                    COALESCE(rec.bank_name, 'Compte bancaire ' || rec.bank_seq),
                    CASE WHEN rec.bank_seq = 1 THEN 'TRUE' ELSE 'FALSE' END,
                    COALESCE(v_iban, rec.bankn),  -- IBAN si disponible, sinon numéro de compte
                    rec.swift,  -- Code SWIFT dans bic_code
                    public.get_default_value('clean_data.payment_address', 'blocked_for_use', 'BANQUE'),
                    public.get_default_value('clean_data.payment_address', 'mapping_type', 'BANQUE'),
                    public.get_default_value('clean_data.payment_address', 'bank_account_validated', 'BANQUE'),
                    public.get_default_value('clean_data.payment_address', 'bank_account_validated_db', 'BANQUE'),
                    CURRENT_TIMESTAMP,
                    CURRENT_TIMESTAMP
                )
                ON CONFLICT (company, identity, party_type_db, way_id, address_id) 
                DO UPDATE SET
                    description = EXCLUDED.description,
                    default_address = EXCLUDED.default_address,
                    account = EXCLUDED.account,
                    bic_code = EXCLUDED.bic_code,
                    blocked_for_use = EXCLUDED.blocked_for_use,
                    mapping_type = EXCLUDED.mapping_type,
                    bank_account_validated = EXCLUDED.bank_account_validated,
                    bank_account_validated_db = EXCLUDED.bank_account_validated_db,
                    updated_timestamp = EXCLUDED.updated_timestamp;
            END;
            
            upserted_count := upserted_count + 1;
            
            IF processed_count <= 3 THEN
                RAISE NOTICE 'Enregistrement % inséré avec succès', processed_count;
            END IF;
            
        EXCEPTION 
            WHEN OTHERS THEN
                error_count := error_count + 1;
                error_msg := SQLERRM;
                RAISE NOTICE 'Erreur lors du traitement du fournisseur % (compte %): %', 
                            rec.lifnr, rec.bankn, error_msg;
        END;
    END LOOP;
    
    -- Statistiques finales
    RAISE NOTICE '';
    RAISE NOTICE '=== ALIMENTATION PAYMENT_ADDRESS TERMINÉE ===';
    RAISE NOTICE 'Durée: % secondes', EXTRACT(EPOCH FROM (CURRENT_TIMESTAMP - v_start_time));
    RAISE NOTICE 'Adresses par défaut créées: %', default_count;
    RAISE NOTICE 'Données bancaires traitées: %', processed_count;
    RAISE NOTICE 'Données bancaires insérées: %', upserted_count;
    RAISE NOTICE 'Erreurs rencontrées: %', error_count;
    RAISE NOTICE 'Total adresses: %', (SELECT COUNT(*) FROM clean_data.payment_address);
    RAISE NOTICE '';
    
    -- Statistiques par société
    RAISE NOTICE '=== STATISTIQUES PAR SOCIÉTÉ ===';
    FOR rec IN (
        SELECT 
            company,
            COUNT(*) as nb_payment_addresses,
            COUNT(CASE WHEN default_address = 'TRUE' THEN 1 END) as nb_default
        FROM clean_data.payment_address
        GROUP BY company
        ORDER BY company
    ) LOOP
        RAISE NOTICE 'Société %: % adresses de paiement (% par défaut)', 
            rec.company, rec.nb_payment_addresses, rec.nb_default;
    END LOOP;
    RAISE NOTICE '';
    
    -- Statistiques par type de mapping
    RAISE NOTICE '=== STATISTIQUES PAR TYPE DE MAPPING ===';
    FOR rec IN (
        SELECT 
            mapping_type,
            COUNT(*) as nb_addresses,
            COUNT(CASE WHEN default_address = 'TRUE' THEN 1 END) as nb_default
        FROM clean_data.payment_address
        GROUP BY mapping_type
        ORDER BY mapping_type
    ) LOOP
        RAISE NOTICE 'Type %: % adresses (% par défaut)', rec.mapping_type, rec.nb_addresses, rec.nb_default;
    END LOOP;
    RAISE NOTICE '';
    
    -- Statistiques par pays bancaire
    RAISE NOTICE '=== STATISTIQUES PAR PAYS BANCAIRE (TOP 10) ===';
    FOR rec IN (
        SELECT 
            data5 as country,
            COUNT(*) as nb_banks,
            COUNT(DISTINCT identity) as nb_suppliers
        FROM clean_data.payment_address
        WHERE data5 IS NOT NULL
        GROUP BY data5
        ORDER BY COUNT(*) DESC
        LIMIT 10
    ) LOOP
        RAISE NOTICE 'Pays %: % comptes bancaires pour % fournisseurs', rec.country, rec.nb_banks, rec.nb_suppliers;
    END LOOP;
    RAISE NOTICE '';
    
    -- Statistiques IBAN
    RAISE NOTICE '=== STATISTIQUES IBAN ===';
    FOR rec IN (
        SELECT 
            COUNT(*) as total_addresses,
            COUNT(CASE WHEN account LIKE 'FR%' THEN 1 END) as iban_fr_generated,
            COUNT(CASE WHEN account NOT LIKE 'FR%' AND account IS NOT NULL THEN 1 END) as account_other
        FROM clean_data.payment_address
    ) LOOP
        RAISE NOTICE 'Total adresses: %', rec.total_addresses;
        RAISE NOTICE 'IBAN français générés: %', rec.iban_fr_generated;
        RAISE NOTICE 'Autres comptes bancaires: %', rec.account_other;
    END LOOP;
    
    RETURN default_count + upserted_count;
    
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'Erreur générale dans fn_upsert_payment_address: %', SQLERRM;
        RAISE NOTICE 'État SQL: %', SQLSTATE;
        RETURN -1;
END;
$function$;
