CREATE TABLE IF NOT EXISTS raw_data.file_customer (
    -- clé technique de staging (non métier) ; retirer si staging purement source
    raw_id            bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    -- ---- 60 colonnes du fichier (ordre d'origine) -------------------------
    kunnr                   text,  -- source: « Numéro client SAP (KUNNR) »
    num_corrige             text,  -- source: « Num corrigé »
    nouveau_compte_ifs      text,  -- source: « Nouveau n° de compte IFS »
    account_group           text,
    vendor_number           text,  -- (vide dans ce fichier)
    code_tva_ifs            text,  -- source: « Code TVA IFS »
    terme_reglement         text,  -- source: « Terme de règlement »
    name_1                  text,
    name_2                  text,
    name_3                  text,
    name_4                  text,  -- (vide dans ce fichier)
    street                  text,
    postal_code             text,
    city                    text,
    country                 text,
    region                  text,
    search_term             text,
    telephone               text,
    fax                     text,
    telephone_2             text,
    teletex                 text,  -- (vide dans ce fichier)
    telex                   text,
    language                text,
    tax_number_1            text,
    tax_number_2            text,
    vat_number              text,
    siren                   text,  -- source: « Siren »
    industry                text,  -- (vide dans ce fichier)
    created_on              text,
    created_by              text,
    customer_classification text,  -- (vide dans ce fichier)
    order_block             text,  -- (vide dans ce fichier)
    delivery_block          text,  -- (vide dans ce fichier)
    billing_block           text,  -- (vide dans ce fichier)
    central_block           text,  -- (vide dans ce fichier)
    deletion_flag           text,  -- (vide dans ce fichier)
    bukrs                   text,  -- source: « Code société (BUKRS) »
    reconciliation_account  text,
    payment_methods         text,
    accounting_delete_flag  text,  -- (vide dans ce fichier)
    accounting_created_on   text,  -- (vide dans ce fichier)
    accounting_created_by   text,
    vkorg                   text,  -- source: « Organisation commerciale (VKORG) »
    distribution_channel    text,
    division                text,
    customer_group          text,  -- (vide dans ce fichier)
    sales_district          text,
    pricing_procedure       text,
    incoterms_1             text,
    incoterms_2             text,  -- (vide dans ce fichier)
    sales_delivery_block    text,  -- (vide dans ce fichier)
    sales_billing_block     text,  -- (vide dans ce fichier)
    sales_order_block       text,  -- (vide dans ce fichier)
    sales_delete_flag       text,  -- (vide dans ce fichier)
    sales_created_on        text,
    sales_created_by        text,
    inserted_at             text,
    updated_at              text,
    numero_adresse          text,
    association_number      text,
    -- ---- métadonnées de chargement ETL ------------------------------------
    source_file       text,
    loaded_at         timestamptz NOT NULL DEFAULT now()
);
