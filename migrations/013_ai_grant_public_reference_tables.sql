-- =====================================================
-- Migration: Assistant IA — accès lecture aux tables public de référence
-- Description: Le system prompt enrichi expose des tables de référence du
--              schéma public (fournisseurs retenus pour la migration,
--              dictionnaire des champs SAP). On accorde à readonly_ai un
--              SELECT *uniquement* sur ces tables non sensibles.
--              Les tables sensibles (users, system_config, ai_query_log,
--              password reset...) restent inaccessibles.
-- Date: 2026-06-12
-- Idempotent: GRANT répétables
-- Dépend de: 012_create_ai_assistant.sql
--
-- ⚠️ Doit rester cohérent avec ALLOWED_PUBLIC_TABLES dans services/sql_guard.py
-- =====================================================

-- USAGE sur public (déjà acquis via le pseudo-rôle PUBLIC, rendu explicite ici).
GRANT USAGE ON SCHEMA public TO readonly_ai;

-- SELECT ciblé sur les seules tables de référence.
GRANT SELECT ON public.fournisseurs_a_conserver TO readonly_ai;
GRANT SELECT ON public.sap_table_properties     TO readonly_ai;
GRANT SELECT ON public.sap_table_fields         TO readonly_ai;

DO $$
BEGIN
    RAISE NOTICE 'readonly_ai : SELECT accordé sur public.{fournisseurs_a_conserver, sap_table_properties, sap_table_fields}.';
END $$;
