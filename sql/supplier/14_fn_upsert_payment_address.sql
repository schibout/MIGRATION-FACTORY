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
    
    FOR rec IN (
        SELECT DISTINCT
            COALESCE(f.company, 'TRIMET') as company,
            f.numero_compte_fournisseur as lifnr,
            f.address_id,
            l.banks,
            l.bankl,
            l.bankn,
            l.bkont,
            l.bvtyp,
            l.xezer,
            l.koinh,
            b.banka as bank_name,
            b.swift,
            b.stras as bank_street,
            b.ort01 as bank_city,
            b.provz as bank_region,
            ROW_NUMBER() OVER (PARTITION BY f.numero_compte_fournisseur, l.bankn ORDER BY l.bankl) as bank_seq
        FROM clean_data.ifs_fournisseurs f
        INNER JOIN raw_data.lfbk l ON f.numero_compte_fournisseur = l.lifnr
        LEFT JOIN raw_data.bnka b ON l.banks = b.banks AND l.bankl = b.bankl
        WHERE f.numero_compte_fournisseur IS NOT NULL
          AND l.bankn IS NOT NULL 
          AND TRIM(l.bankn) != ''
        ORDER BY f.numero_compte_fournisseur, l.bankn
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
                -- Calculer l'IBAN pour les comptes français (FR)
                IF rec.banks = 'FR' AND rec.bankl IS NOT NULL AND rec.bankn IS NOT NULL THEN
                    v_iban := clean_data.fn_calculate_iban('FR', rec.bankl, '00000', rec.bankn);
                ELSE
                    v_iban := NULL;
                END IF;
                
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
                    rec.lifnr,  -- supplier_id (numéro de compte fournisseur)
                    public.get_default_value('clean_data.payment_address', 'party_type_db', 'BANQUE'),
                    public.get_default_value('clean_data.payment_address', 'way_id', 'BANQUE'),
                    rec.lifnr,  -- address_id
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
