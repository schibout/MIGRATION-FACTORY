# -*- coding: utf-8 -*-
"""
Jobs d'extraction des textes longs SAP (STXH/STXL -> raw_data.sap_long_text),
pilotes par l'API sap-extraction (routes /textes/*) et l'ecran Migration
Factory « Extraction > Textes longs SAP ».

Le travail lui-meme est texteSurCommande.extract_textes_longs_sap.executer()
(inventaire STXH -> RFC_READ_TEXT par lots -> chargement) ; ce module ne fait
que l'envelopper dans un job en thread avec statut, progression, logs et
annulation, a l'image des jobs de metadonnees d'api_simple.py.

Un seul job textes a la fois : deux extractions simultanees ouvriraient deux
jeux de connexions SAP et se disputeraient le remplacement de lot dans la
table cible.
"""
from __future__ import annotations

import logging
import threading
import time
import uuid
from datetime import datetime
from typing import Any, Callable, Dict, List, Optional

# Logger du script d'extraction : ses messages sont captures dans les logs du job.
LOG_EXTRACTION = logging.getLogger("textes_sap")

_JOB_LOG_MAX_ENTRIES = 5000
_ETATS_FINAUX = ("completed", "failed", "cancelled")


class JobEnCours(RuntimeError):
    """Un job textes est deja en cours."""


try:  # l'executeur reel n'est disponible que dans le conteneur pyrfc
    from texteSurCommande.extract_textes_longs_sap import (  # type: ignore
        ExtractionInterrompue, executer as _executer_reel)
except Exception:  # noqa: BLE001  (pyrfc absent, ou script non monte)
    _executer_reel = None

    class ExtractionInterrompue(RuntimeError):  # type: ignore[no-redef]
        """Doublure : le script d'extraction n'est pas importable ici."""


class _CaptureLogs(logging.Handler):
    """Handler stdlib qui alimente les logs d'UN job (thread du job + workers)."""

    def __init__(self, jobs: "TextesJobs", job_id: str):
        super().__init__(level=logging.INFO)
        self._jobs, self._job_id = jobs, job_id

    def emit(self, record: logging.LogRecord) -> None:
        try:
            self._jobs._ajouter_log(
                self._job_id,
                f"{datetime.fromtimestamp(record.created).strftime('%Y-%m-%dT%H:%M:%S')} "
                f"[{record.levelname}] {record.getMessage()}")
        except Exception:  # noqa: BLE001  (les logs ne doivent jamais casser le job)
            pass


class TextesJobs:
    """Registre memoire des jobs textes (perdu au redemarrage, comme les metadonnees)."""

    def __init__(self, executer: Optional[Callable[..., dict]] = None):
        self._executer = executer or _executer_reel
        self._jobs: Dict[str, Dict[str, Any]] = {}
        self._logs: Dict[str, List[str]] = {}
        self._verrou = threading.Lock()

    # ------------------------------------------------------------ cycle de vie
    def demarrer(self, objet: str, tdids: Optional[List[str]], langues: Optional[List[str]],
                 purge: bool = False) -> str:
        if self._executer is None:
            raise RuntimeError("Script d'extraction des textes non disponible (pyrfc / texteSurCommande)")
        objet = objet.strip().upper()
        if not objet:
            raise ValueError("Objet de texte SAP requis")
        tdids = [t.strip().upper() for t in (tdids or []) if t and t.strip()] or None
        langues = [l.strip().upper() for l in (langues or []) if l and l.strip()] or None

        job_id = str(uuid.uuid4())
        job: Dict[str, Any] = {
            "job_id": job_id, "objet": objet, "tdids": tdids, "langues": langues,
            "purge": purge, "status": "pending", "cancel": False,
            "started_at": datetime.now().isoformat(), "completed_at": None,
            "cles_lues": 0, "cles_total": None, "textes_lus": 0, "absents": 0,
            "lignes": 0, "lignes_inserees": 0, "csv": None, "duree_s": None,
            "error_message": None,
        }
        with self._verrou:
            if any(j["status"] in ("pending", "running") for j in self._jobs.values()):
                raise JobEnCours("Une extraction de textes est deja en cours")
            self._jobs[job_id] = job
            self._logs[job_id] = []
        threading.Thread(target=self._run, args=(job_id,), daemon=True,
                         name=f"textes-{job_id[:8]}").start()
        return job_id

    def _run(self, job_id: str) -> None:
        job = self._jobs[job_id]
        job["status"] = "running"
        t0 = time.time()
        capture = _CaptureLogs(self, job_id)
        LOG_EXTRACTION.addHandler(capture)
        if LOG_EXTRACTION.level > logging.INFO or LOG_EXTRACTION.level == logging.NOTSET:
            LOG_EXTRACTION.setLevel(logging.INFO)

        def progression(idx: int, total: int, stats: Dict[str, int]) -> None:
            job["cles_lues"], job["cles_total"] = idx, total
            job["textes_lus"] = stats.get("textes_lus", 0)
            job["absents"] = stats.get("absents", 0)
            job["lignes"] = stats.get("lignes_ecrites", 0)

        try:
            self._ajouter_log(job_id, f"{datetime.now().strftime('%Y-%m-%dT%H:%M:%S')} [INFO] "
                              f"Extraction textes {job['objet']} "
                              f"(tdid={job['tdids'] or 'tous'}, langues={job['langues'] or 'toutes'})")
            bilan = self._executer(job["objet"], job["tdids"], job["langues"], purge=job["purge"],
                                   progression=progression, doit_arreter=lambda: job["cancel"])
            job["cles_lues"] = job["cles_total"] = bilan.get("cles", job["cles_lues"])
            job["textes_lus"] = bilan.get("textes_lus", job["textes_lus"])
            job["absents"] = bilan.get("absents", job["absents"])
            job["lignes"] = bilan.get("lignes", job["lignes"])
            job["lignes_inserees"] = bilan.get("inserees", 0)
            job["csv"] = bilan.get("csv")
            job["status"] = "completed"
        except ExtractionInterrompue as exc:
            job["status"] = "cancelled"
            job["error_message"] = str(exc)
        except Exception as exc:  # noqa: BLE001
            job["status"] = "failed"
            job["error_message"] = str(exc)
            self._ajouter_log(job_id, f"{datetime.now().strftime('%Y-%m-%dT%H:%M:%S')} [ERROR] {exc}")
        finally:
            LOG_EXTRACTION.removeHandler(capture)
            job["completed_at"] = datetime.now().isoformat()
            job["duree_s"] = round(time.time() - t0, 1)

    def annuler(self, job_id: str) -> None:
        job = self._jobs.get(job_id)
        if job is None:
            raise KeyError(job_id)
        if job["status"] not in ("pending", "running"):
            raise ValueError("Le job n'est pas en cours")
        job["cancel"] = True

    # ------------------------------------------------------------- consultation
    def statut(self, job_id: str) -> Dict[str, Any]:
        job = self._jobs.get(job_id)
        if job is None:
            raise KeyError(job_id)
        return self._formater(job)

    def lister(self, limit: int = 30) -> List[Dict[str, Any]]:
        with self._verrou:
            jobs = list(self._jobs.values())
        jobs.sort(key=lambda j: j["started_at"], reverse=True)
        return [self._formater(j) for j in jobs[:limit]]

    def logs(self, job_id: str) -> List[str]:
        if job_id not in self._jobs:
            raise KeyError(job_id)
        with self._verrou:
            return list(self._logs.get(job_id, []))

    def _ajouter_log(self, job_id: str, entree: str) -> None:
        with self._verrou:
            entrees = self._logs.setdefault(job_id, [])
            entrees.append(entree)
            if len(entrees) > _JOB_LOG_MAX_ENTRIES:
                del entrees[: len(entrees) - _JOB_LOG_MAX_ENTRIES]
                entrees[0] = "... (logs anterieurs tronques) ..."

    @staticmethod
    def _formater(job: Dict[str, Any]) -> Dict[str, Any]:
        total = job["cles_total"]
        if job["status"] in _ETATS_FINAUX:
            progress = 100
        elif total:
            progress = min(99, int(job["cles_lues"] / total * 100))
        else:
            progress = 0
        return {
            "id": job["job_id"], "status": job["status"], "progress": progress,
            "objet": job["objet"], "tdids": job["tdids"], "langues": job["langues"],
            "purge": job["purge"],
            "clesLues": job["cles_lues"], "clesTotal": total,
            "textesLus": job["textes_lus"], "absents": job["absents"],
            "lignes": job["lignes"], "lignesInserees": job["lignes_inserees"],
            "csv": job["csv"],
            "startedAt": job["started_at"], "completedAt": job["completed_at"],
            "duration": job["duree_s"], "error": job["error_message"],
        }
