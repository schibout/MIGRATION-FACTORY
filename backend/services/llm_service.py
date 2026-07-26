"""
llm_service — Façade d'aiguillage entre le modèle LOCAL (Ollama) et un modèle
EXTERNE (API OpenAI-compatible), selon la clé de configuration ``AI_PROVIDER``.

C'est le SEUL point d'entrée utilisé par l'API Assistant IA (api/ai_assistant) :
elle importe ``generate_sql`` / ``repair_sql`` / ``check_health`` et les
exceptions d'ici, sans savoir quel fournisseur est actif. Le prompt RAG est
construit en amont par ai_assistant et passé tel quel : les deux fournisseurs
reçoivent donc EXACTEMENT le même prompt.

Bascule : ``AI_PROVIDER`` (DB > env > défaut) =
  - ``ollama`` (défaut) → services.ollama_service
  - ``openai``          → services.external_llm_service (OpenAI-compatible)

Exceptions : on réutilise les classes définies dans ollama_service et on les
ré-exporte sous des alias neutres (LLMBusyError / LLMUnavailableError /
LLMError) pour que l'appelant ne dépende plus du nom « Ollama ».
"""

import logging

from services.config_service import get_config
from services import ollama_service, external_llm_service
from services.ollama_service import (
    OllamaBusyError as LLMBusyError,
    OllamaUnavailableError as LLMUnavailableError,
    OllamaError as LLMError,
)

logger = logging.getLogger(__name__)

__all__ = [
    "generate_sql", "repair_sql", "check_health", "active_provider",
    "LLMBusyError", "LLMUnavailableError", "LLMError",
]


def active_provider() -> str:
    """Fournisseur actif normalisé : 'openai' ou 'ollama' (défaut)."""
    return "openai" if (get_config("AI_PROVIDER", "ollama") or "ollama").strip().lower() == "openai" else "ollama"


def _backend():
    """Renvoie le module de service correspondant au fournisseur actif."""
    return external_llm_service if active_provider() == "openai" else ollama_service


def generate_sql(question: str, system_prompt: str) -> dict:
    """Génère le SQL via le fournisseur actif. Retour : {'sql','explication'}."""
    return _backend().generate_sql(question, system_prompt)


def repair_sql(question: str, system_prompt: str, bad_sql: str, erreur: str) -> dict:
    """Tente une correction SQL via le fournisseur actif."""
    return _backend().repair_sql(question, system_prompt, bad_sql, erreur)


def check_health() -> dict:
    """Statut du fournisseur actif, enrichi de la clé 'provider'."""
    provider = active_provider()
    status = _backend().check_health()
    status["provider"] = provider
    return status
