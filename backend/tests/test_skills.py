# -*- coding: utf-8 -*-
"""
Tests des packs de connaissances (skills) : structure des fichiers + SQL des
requêtes-types valide (sql_guard) + déclenchement par domaine.

Entièrement hors-ligne : build_skill_block / detect_domains ne touchent pas la
base, et sql_guard est du parsing pur (sqlparse).
"""
import glob
import json
import os

import pytest

from services.sql_guard import validate_and_wrap
from services import ai_prompt_builder
from services.ai_schema_retriever import detect_domains

SKILLS_DIR = os.path.join(os.path.dirname(os.path.dirname(__file__)), "config", "skills")
PACK_FILES = sorted(glob.glob(os.path.join(SKILLS_DIR, "*.json")))
PACK_IDS = [os.path.basename(p) for p in PACK_FILES]


def test_au_moins_un_pack():
    assert PACK_FILES, "aucun pack de connaissances trouvé dans config/skills/"


@pytest.mark.parametrize("chemin", PACK_FILES, ids=PACK_IDS)
def test_pack_structure(chemin):
    with open(chemin, encoding="utf-8") as fh:
        pack = json.load(fh)
    stem = os.path.splitext(os.path.basename(chemin))[0]
    assert pack.get("domain") == stem, "le champ 'domain' doit valoir le nom de fichier"
    assert pack.get("keywords"), "un pack doit déclarer des keywords"
    for champ in ("joins", "enums", "rules", "patterns", "docs"):
        assert isinstance(pack.get(champ, []), list)


@pytest.mark.parametrize("chemin", PACK_FILES, ids=PACK_IDS)
def test_patterns_passent_sql_guard(chemin):
    with open(chemin, encoding="utf-8") as fh:
        pack = json.load(fh)
    for p in pack.get("patterns", []):
        sql = (p.get("sql") or "").strip()
        assert sql, f"pattern sans SQL dans {os.path.basename(chemin)}"
        wrapped = validate_and_wrap(sql, 500)  # ne doit pas lever SqlGuardError
        assert "limit" in wrapped.lower()


def test_detect_domains_fournisseurs():
    assert "fournisseurs" in detect_domains("liste des fournisseurs actifs")


def test_build_skill_block_injecte_le_bon_pack():
    bloc = ai_prompt_builder.build_skill_block("liste des fournisseurs actifs")
    assert "[fournisseurs]" in bloc
    assert "JOINTURES" in bloc


def test_build_skill_block_vide_hors_domaine():
    assert ai_prompt_builder.build_skill_block("bonjour comment ca va") == ""
