CREATE OR REPLACE PROCEDURE clean_data.populate_ifs_person()
 LANGUAGE plpgsql
AS $procedure$
DECLARE
    v_count INTEGER := 0;
BEGIN
    TRUNCATE TABLE clean_data.ifs_person;
    
    INSERT INTO clean_data.ifs_person (
        person_id,
        first_name,
        middle_name,
        prefix,
        last_name,
        birth_name,
        alias,
        initials,
        title,
        internal_display_name,
        external_display_name,
        date_of_birth,
        place_of_birth,
        gender,
        ssn,
        blood_type,
        marital_status,
        have_children,
        protected,
        currently_employed,
        loaded_at,
        source_file
    )
    SELECT 
        person_id,
        first_name,
        middle_name,
        prefix,
        last_name,
        birth_name,
        alias,
        initials,
        title,
        internal_display_name,
        external_display_name,
        date_of_birth,
        place_of_birth,
        gender,
        ssn,
        blood_type,
        marital_status,
        have_children,
        protected,
        currently_employed,
        CURRENT_TIMESTAMP,
        'Populated from raw_data.ifs_person'
    FROM raw_data.ifs_person;
    
    GET DIAGNOSTICS v_count = ROW_COUNT;
    RAISE NOTICE 'ifs_person: % lignes insérées', v_count;
END;
$procedure$
;
