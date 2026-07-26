-- =====================================================================
-- Migration 025 : public.ifs_entity_theme — domaine métier par entité IFS
-- Une ligne = le domaine métier (thème) choisi manuellement pour une entité
-- d'un lot. Sert de surcharge : si absente, l'UI déduit le domaine du nom
-- d'entité (deriveTheme). Découplé de ifs_field_catalog (grain entité, pas champ)
-- pour survivre au rechargement des specs (upsert du catalogue ne l'écrase pas).
-- Rejouable sans risque (IF NOT EXISTS).
-- =====================================================================
CREATE TABLE IF NOT EXISTS public.ifs_entity_theme (
    lot_id      TEXT NOT NULL,
    entity      TEXT NOT NULL,
    theme       TEXT NOT NULL,
    updated_at  TIMESTAMP DEFAULT now(),
    CONSTRAINT uq_ifs_entity_theme UNIQUE (lot_id, entity)
);

COMMENT ON TABLE public.ifs_entity_theme IS
  'Domaine métier (thème) choisi manuellement par entité IFS. Surcharge la déduction automatique du catalogue.';
