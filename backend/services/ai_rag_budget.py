# -*- coding: utf-8 -*-
"""
ai_rag_budget — Budgets RAG adaptés au fournisseur de modèle actif.

Les plafonds historiques (7 tables, 18 colonnes, 3 exemples, 1 pack, 8 arêtes)
sont calibrés pour Ollama local (num_ctx=4096, cache KV CPU : cf. CLAUDE.md,
« ne pas gonfler le prompt »). Le fournisseur EXTERNE (AI_PROVIDER=openai,
contexte 128k+) n'a pas cette contrainte : un prompt plus riche réduit les
hallucinations et améliore les jointures.

Profils :
  compact — valeurs historiques (Ollama). NE PAS AUGMENTER sans retirer ailleurs.
  large   — fournisseur externe.
Sélection : AI_RAG_PROFILE (auto|compact|large, défaut auto = selon AI_PROVIDER).
Surcharges fines : AI_RAG_MAX_TABLES, AI_RAG_MAX_COLS, AI_RAG_NB_EXEMPLES,
AI_SKILL_MAX_PACKS, AI_SKILL_MAX_CHARS, AI_RAG_MAX_EDGES (0/absent = profil).
"""
from services.config_service import get_config, get_config_int

_PROFILS = {
    "compact": {"max_tables": 7,  "max_cols": 18, "nb_exemples": 3,
                "max_packs": 1, "pack_chars": 700,  "max_edges": 8},
    "large":   {"max_tables": 14, "max_cols": 40, "nb_exemples": 6,
                "max_packs": 3, "pack_chars": 2500, "max_edges": 20},
}

_SURCHARGES = [
    ("max_tables", "AI_RAG_MAX_TABLES"),
    ("max_cols", "AI_RAG_MAX_COLS"),
    ("nb_exemples", "AI_RAG_NB_EXEMPLES"),
    ("max_packs", "AI_SKILL_MAX_PACKS"),
    ("pack_chars", "AI_SKILL_MAX_CHARS"),
    ("max_edges", "AI_RAG_MAX_EDGES"),
]


def get_budget() -> dict:
    """Budget RAG effectif : {profil, max_tables, max_cols, nb_exemples,
    max_packs, pack_chars, max_edges}. Lecture dynamique (DB > env > défaut)."""
    profil = (get_config("AI_RAG_PROFILE", "auto") or "auto").strip().lower()
    if profil not in ("compact", "large"):
        provider = (get_config("AI_PROVIDER", "ollama") or "ollama").strip().lower()
        profil = "large" if provider == "openai" else "compact"
    budget = dict(_PROFILS[profil])
    for cle, param in _SURCHARGES:
        v = get_config_int(param, 0)
        if v > 0:
            budget[cle] = v
    budget["profil"] = profil
    return budget
