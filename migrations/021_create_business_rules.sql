-- =====================================================
-- Migration: Règles de gestion (mappings métier)
-- Description: Crée la table public.business_rules qui stocke les règles
--              de gestion / mappings illustrés sur la page /regles-gestion.
--              Chaque règle décrit un mapping Source SAP -> Cible IFS pour
--              un objet métier donné (Client, Fournisseur, Article, ...).
-- Date: 2026-06-15
-- Idempotent: CREATE TABLE/INDEX IF NOT EXISTS
-- =====================================================

CREATE TABLE IF NOT EXISTS public.business_rules (
    id              SERIAL PRIMARY KEY,
    business_object VARCHAR(100) NOT NULL,              -- Objet métier (Client, Fournisseur, Article, Projet, ...)
    rule_name       VARCHAR(200) NOT NULL,              -- Libellé de la règle
    source_table    VARCHAR(150),                       -- Table source SAP
    source_field    VARCHAR(150),                       -- Champ source SAP
    transformation  TEXT,                               -- Description / type de transformation appliquée
    target_table    VARCHAR(150),                       -- Table cible IFS
    target_field    VARCHAR(150),                       -- Champ cible IFS
    description     TEXT,                               -- Détail / commentaire de la règle
    is_active       BOOLEAN DEFAULT TRUE,
    created_at      TIMESTAMP DEFAULT NOW(),
    updated_at      TIMESTAMP DEFAULT NOW(),
    created_by      VARCHAR(50),
    updated_by      VARCHAR(50)
);

CREATE INDEX IF NOT EXISTS idx_business_rules_object    ON public.business_rules (business_object);
CREATE INDEX IF NOT EXISTS idx_business_rules_is_active ON public.business_rules (is_active);
CREATE INDEX IF NOT EXISTS idx_business_rules_source    ON public.business_rules (source_table);
CREATE INDEX IF NOT EXISTS idx_business_rules_target    ON public.business_rules (target_table);
