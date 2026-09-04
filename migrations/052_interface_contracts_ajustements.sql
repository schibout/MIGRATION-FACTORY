-- =====================================================================
-- Migration 052 : ajustements du modele "contrats d'interface" (051) au
-- format REEL du classeur contrat_interface_SAP_IFS_Supplier.xlsx, decouvert
-- en ecrivant le script de reprise (scripts/seed_interface_contracts.py).
--
-- Trois corrections / ajouts :
--
-- 1. interface_contract_column.target_column etait en VARCHAR(100). Le
--    classeur regroupe sur une meme ligne les colonnes qui partagent la meme
--    regle ("code_tva_ifs / code_tva_sap / france_etranger / ...") : jusqu'a
--    173 caracteres. -> VARCHAR(255).
--
-- 2. Deux colonnes du classeur n'avaient pas d'equivalent en base et etaient
--    donc perdues a la reprise :
--      - "Systeme source" (SAP / IFS / Config / Technique) -> systeme_source
--      - "Exemple de valeur"                               -> exemple_valeur
--    ("Type / Longueur" reste calcule a la volee depuis information_schema :
--     c'est une donnee de la base, pas du contrat.)
--
-- 3. La jointure vers etl_default_values de la vue v_interface_contract ne
--    pouvait JAMAIS matcher : etl_default_values.table_cible stocke le nom
--    QUALIFIE ('clean_data.supplier_info_general') alors que
--    interface_contract_table.table_cible stocke le nom nu + schema_cible a
--    part. De plus une ligne CONFIG_SUMMARY resume N colonnes parametrables
--    (pas une seule), parfois pour plusieurs variantes a la fois
--    ('TVA_UE/SIREN/SIRET') : un LEFT JOIN 1-1 n'a pas de sens. On remplace
--    donc par un agregat lateral (nb_default_values) et l'ecran va chercher
--    le detail via l'API.
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1 + 2. Colonnes
-- ---------------------------------------------------------------------
-- Les vues de la 051 referencent target_column : PostgreSQL refuse d'en
-- changer le type tant qu'elles existent. On les supprime ici, elles sont
-- reconstruites plus bas (§3).
DROP VIEW IF EXISTS public.v_interface_contract_summary;
DROP VIEW IF EXISTS public.v_interface_contract;

ALTER TABLE public.interface_contract_column
    ALTER COLUMN target_column TYPE VARCHAR(255);

ALTER TABLE public.interface_contract_column
    ADD COLUMN IF NOT EXISTS systeme_source VARCHAR(50),
    ADD COLUMN IF NOT EXISTS exemple_valeur TEXT;

-- ---------------------------------------------------------------------
-- 3. Vues reconstruites
-- ---------------------------------------------------------------------
CREATE VIEW public.v_interface_contract AS
SELECT
    t.id            AS contract_table_id,
    t.module,
    t.schema_cible,
    t.table_cible,
    t.libelle       AS table_libelle,
    t.description   AS table_description,
    t.source_procedure,
    t.ordre         AS table_ordre,
    t.owner_metier,
    t.date_limite,
    t.signe_par,
    t.signe_le,
    c.id            AS contract_column_id,
    c.section,
    c.target_column,
    c.field_label,
    c.systeme_source,
    c.source_schema,
    c.source_table,
    c.source_column,
    c.source_expression,
    c.transformation_rule,
    c.condition_application,
    c.exemple_valeur,
    c.row_type,
    c.default_value_column,
    c.default_value_variante,
    c.sort_order,
    c.updated_at    AS definition_updated_at,
    COALESCE(v.statut, 'A_VALIDER')   AS statut,
    v.remarque_metier,
    v.validated_by,
    v.validated_at,
    -- une validation est obsolete si la definition technique a change apres
    COALESCE(v.statut = 'VALIDE' AND c.updated_at > v.validated_at, FALSE) AS validation_obsolete,
    -- nombre de valeurs par defaut parametrables resumees par la ligne
    -- (uniquement pour les lignes CONFIG_SUMMARY ; 0 partout ailleurs)
    dv.nb_default_values,
    (SELECT COUNT(*) FROM public.interface_contract_event e
      WHERE e.contract_column_id = c.id AND e.event_type = 'COMMENTAIRE') AS nb_commentaires
FROM public.interface_contract_table t
JOIN public.interface_contract_column c
  ON c.contract_table_id = t.id
LEFT JOIN public.interface_contract_validation v
  ON v.contract_column_id = c.id
LEFT JOIN LATERAL (
    SELECT COUNT(*) AS nb_default_values
    FROM public.etl_default_values edv
    WHERE c.row_type = 'CONFIG_SUMMARY'
      AND edv.table_cible = t.schema_cible || '.' || t.table_cible
      AND (c.default_value_variante IS NULL
           OR edv.variante = ANY (string_to_array(c.default_value_variante, '/')))
) dv ON TRUE
WHERE t.is_active;

CREATE VIEW public.v_interface_contract_summary AS
SELECT
    t.id            AS contract_table_id,
    t.module,
    t.schema_cible,
    t.table_cible,
    t.libelle,
    t.description,
    t.source_procedure,
    t.ordre,
    t.owner_metier,
    t.date_limite,
    t.signe_par,
    t.signe_le,
    COUNT(c.id) FILTER (WHERE c.row_type <> 'NOTE')                               AS nb_lignes,
    COUNT(c.id) FILTER (WHERE c.row_type <> 'NOTE' AND v.statut = 'VALIDE')        AS nb_valide,
    COUNT(c.id) FILTER (WHERE c.row_type <> 'NOTE' AND v.statut = 'A_CORRIGER')    AS nb_a_corriger,
    COUNT(c.id) FILTER (WHERE c.row_type <> 'NOTE'
                          AND (v.statut IS NULL OR v.statut = 'A_VALIDER'))        AS nb_a_valider,
    COUNT(c.id) FILTER (WHERE c.row_type <> 'NOTE' AND v.statut = 'NON_APPLICABLE') AS nb_non_applicable,
    COUNT(c.id) FILTER (WHERE c.row_type <> 'NOTE'
                          AND v.statut = 'VALIDE'
                          AND c.updated_at > v.validated_at)                       AS nb_obsolete,
    ROUND(100.0 * COUNT(c.id) FILTER (WHERE c.row_type <> 'NOTE'
                                        AND v.statut IN ('VALIDE', 'NON_APPLICABLE'))
          / NULLIF(COUNT(c.id) FILTER (WHERE c.row_type <> 'NOTE'), 0), 1)         AS pct_valide
FROM public.interface_contract_table t
LEFT JOIN public.interface_contract_column c ON c.contract_table_id = t.id
LEFT JOIN public.interface_contract_validation v ON v.contract_column_id = c.id
WHERE t.is_active
GROUP BY t.id;

-- ---------------------------------------------------------------------
-- 4. Cle naturelle des lignes de contrat : (table, SECTION, colonne)
--
-- La 051 posait UNIQUE(contract_table_id, target_column). Le classeur reel
-- invalide cette hypothese : un onglet peut documenter DEUX FOIS la meme
-- colonne cible quand le chargement se fait en plusieurs etapes. Exemple,
-- onglet 14_PAYMENT_ADDRESS :
--     « Étape 1 — adresse par defaut »  -> identity / address_id
--     « Étape 2 — donnees bancaires »   -> identity / address_id
-- Avec l'ancienne cle, la seconde ligne ecrasait silencieusement la premiere
-- (137 lignes du classeur -> 136 en base) et le metier ne relisait qu'une des
-- deux etapes. La section fait donc partie de l'identite de la ligne.
-- ---------------------------------------------------------------------
ALTER TABLE public.interface_contract_column
    DROP CONSTRAINT IF EXISTS uq_interface_contract_column;

CREATE UNIQUE INDEX IF NOT EXISTS uq_interface_contract_column
    ON public.interface_contract_column (contract_table_id, COALESCE(section, ''), target_column);
