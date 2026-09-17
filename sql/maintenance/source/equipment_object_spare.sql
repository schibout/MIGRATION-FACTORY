-- =====================================================================
-- clean_data.equipment_object_spare
-- Source  : spec IFS EQUIPMENT_OBJECT_SPARE
--           (pieces de rechange rattachees a un objet d'equipement)
-- Conventions clean_data : snake_case, VARCHAR2(n)->VARCHAR(n),
--   NUMBER(n)->NUMERIC(n,0), colonnes NULLABLE, sans DEFAULT/PK/provenance.
-- 17 colonnes.
--
-- Notes :
--   - PK source = (mch_spare_seq, contract) -> non materialisee ici (convention clean_data).
--   - qty mappe en NUMERIC(20,0) par convention NUMBER->NUMERIC(n,0) ;
--     a passer en NUMERIC(20,3) si des quantites fractionnaires sont attendues.
--   - has_spare_structure et objversion : IN_SCOPE = NO dans la spec
--     (colonnes techniques/derivees, non alimentees par l'extraction).
-- =====================================================================
CREATE TABLE IF NOT EXISTS clean_data.equipment_object_spare (
    mch_spare_seq            NUMERIC(10, 0),    -- Object Spare Sequence Number (PK source)
    contract                 VARCHAR(5),        -- Site de l'objet (PK source)
    equipment_object_seq     VARCHAR(100),      -- Code objet d'equipement = mch_code du poste technique (Equipment_Functional)
    spare_contract           VARCHAR(5),        -- Site de la piece de rechange
    spare_id                 VARCHAR(25),       -- Code article de la piece de rechange
    qty                      NUMERIC(20, 0),    -- Quantite
    note                     VARCHAR(2000),     -- Note / remarque
    mch_part                 VARCHAR(4),        -- Emplacement de l'article sur l'objet
    drawing_no               VARCHAR(16),       -- N deg plan
    drawing_pos              VARCHAR(6),        -- Position dans le dessin
    has_spare_structure      VARCHAR(10),       -- Article a une structure (IN_SCOPE=NO)
    part_ownership           VARCHAR(4000),     -- Propriete (valeur client)
    part_ownership_db        VARCHAR(20),       -- Propriete (valeur DB, ex. COMPANY OWNED)
    condition_code           VARCHAR(10),       -- Code condition
    owner                    VARCHAR(20),       -- Proprietaire (si propriete = client)
    allow_wo_mat_site        VARCHAR(5),        -- Autoriser site materiau BT
    objversion               VARCHAR(40)        -- OBJVERSION (IN_SCOPE=NO)
);