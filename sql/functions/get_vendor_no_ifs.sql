-- ============================================================================
-- public.get_vendor_no_ifs : LIFNR SAP -> identifiant fournisseur IFS
-- ============================================================================
-- Toute colonne IFS qui designe un fournisseur (vendor_no, supplier_id) doit
-- porter le numero de compte IFS arbitre par le metier dans le fichier de
-- selection (clean_data.ifs_fournisseurs.numero_compte_ifs, 600001+), JAMAIS
-- le LIFNR SAP : la table supplier est renumerotee, un LIFNR brut ne pointe
-- plus sur aucun fournisseur et le lien est rejete au chargement IFS.
--
-- Source unique = le fichier (clean_data.ifs_fournisseurs), et non les tables
-- derivees supplier / supplier_info_general : celles-ci sont rechargees par le
-- module fournisseur et amputables par sp_keep_supplier_sample/_top20, alors
-- que le fichier reste la reference. Les deux donnent le meme resultat
-- (verifie : supplier_info_general.supplier_id = numero_compte_ifs sur 100 %
-- des lignes), le fichier ne depend simplement pas de l'ordre des modules.
--
-- Renvoie NULL si le fournisseur est inconnu du fichier : mieux vaut une
-- colonne vide qu'un identifiant qui ne resout pas cote IFS.
CREATE OR REPLACE FUNCTION public.get_vendor_no_ifs(p_lifnr TEXT)
RETURNS VARCHAR
LANGUAGE sql
STABLE
AS $function$
    SELECT SUBSTRING(f.numero_compte_ifs, 1, 20)
      FROM clean_data.ifs_fournisseurs f
     -- Les zeros de tete different selon la source (staging "45036",
     -- lfa1/eina "0000045036") : la comparaison se fait sans eux.
     WHERE LTRIM(TRIM(f.numero_compte_fournisseur), '0')
         = LTRIM(TRIM(p_lifnr), '0')
       AND NULLIF(LTRIM(TRIM(COALESCE(p_lifnr, '')), '0'), '') IS NOT NULL
     LIMIT 1;
$function$;

COMMENT ON FUNCTION public.get_vendor_no_ifs(TEXT) IS
    'Numero de compte IFS (600001+) du fournisseur SAP passe en LIFNR, lu dans le fichier de selection (clean_data.ifs_fournisseurs). NULL si inconnu. A utiliser pour toute colonne vendor_no / supplier_id.';
