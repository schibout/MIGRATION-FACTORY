-- Test de la requête pour récupérer les site_ids
SELECT DISTINCT site_id
FROM (
    SELECT REGEXP_REPLACE(site_url, '.*asap.stjn.local/(\d+).*', '\1') as site_id
    FROM raw_data.sharepoint_projets 
    WHERE site_url IS NOT NULL 
    AND site_url ~ '/\d+'
) AS extracted_ids
WHERE site_id IS NOT NULL AND site_id != ''
ORDER BY site_id::integer
LIMIT 20;
