# -*- coding: utf-8 -*-
"""Jobs d'extraction des textes longs SAP (textes_jobs.py), sans SAP ni base.

    docker exec -w /app pyrfc_app python -m unittest tests.test_textes_jobs
"""
import threading
import time
import unittest

import textes_jobs


def _attendre_fin(jobs, job_id, delai=5.0):
    limite = time.time() + delai
    while time.time() < limite:
        j = jobs.statut(job_id)
        if j["status"] not in ("pending", "running"):
            return j
        time.sleep(0.02)
    raise AssertionError("le job ne s'est pas termine")


class TextesJobsTest(unittest.TestCase):

    def test_job_termine_avec_bilan_et_progression(self):
        def executer(objet, tdids, langues, **kw):
            kw["progression"](500, 1000, {"textes_lus": 500, "absents": 0, "lignes_ecrites": 900})
            kw["progression"](1000, 1000, {"textes_lus": 990, "absents": 10, "lignes_ecrites": 1800})
            return {"objet": objet, "cles": 1000, "textes_lus": 990, "absents": 10,
                    "lignes": 1800, "inserees": 1800, "csv": "/tmp/x.csv", "duree_s": 1.2}
        jobs = textes_jobs.TextesJobs(executer=executer)
        job_id = jobs.demarrer(objet="eina", tdids=["at"], langues=None, purge=False)
        j = _attendre_fin(jobs, job_id)
        self.assertEqual(j["status"], "completed")
        self.assertEqual(j["objet"], "EINA")
        self.assertEqual(j["tdids"], ["AT"])
        self.assertEqual(j["progress"], 100)
        self.assertEqual(j["clesLues"], 1000)
        self.assertEqual(j["textesLus"], 990)
        self.assertEqual(j["lignesInserees"], 1800)
        self.assertIsNotNone(j["completedAt"])

    def test_progression_partielle_pendant_le_job(self):
        barriere = threading.Event()

        def executer(objet, tdids, langues, **kw):
            kw["progression"](250, 1000, {"textes_lus": 250, "absents": 0, "lignes_ecrites": 300})
            barriere.wait(5)
            return {"objet": objet, "cles": 1000, "textes_lus": 1000, "absents": 0,
                    "lignes": 1200, "inserees": 1200, "csv": None, "duree_s": 0.1}
        jobs = textes_jobs.TextesJobs(executer=executer)
        job_id = jobs.demarrer(objet="MATERIAL", tdids=None, langues=["F"], purge=False)
        time.sleep(0.1)
        j = jobs.statut(job_id)
        self.assertEqual(j["status"], "running")
        self.assertEqual(j["progress"], 25)
        self.assertEqual(j["clesTotal"], 1000)
        barriere.set()
        self.assertEqual(_attendre_fin(jobs, job_id)["status"], "completed")

    def test_echec_de_l_executeur_donne_un_job_failed(self):
        def executer(objet, tdids, langues, **kw):
            raise RuntimeError("SAP injoignable")
        jobs = textes_jobs.TextesJobs(executer=executer)
        j = _attendre_fin(jobs, jobs.demarrer(objet="EINE", tdids=None, langues=None, purge=False))
        self.assertEqual(j["status"], "failed")
        self.assertIn("SAP injoignable", j["error"])

    def test_annulation_transmise_a_l_executeur(self):
        def executer(objet, tdids, langues, **kw):
            limite = time.time() + 5
            while time.time() < limite and not kw["doit_arreter"]():
                time.sleep(0.01)
            raise textes_jobs.ExtractionInterrompue("lecture interrompue")
        jobs = textes_jobs.TextesJobs(executer=executer)
        job_id = jobs.demarrer(objet="EKPO", tdids=None, langues=None, purge=False)
        time.sleep(0.05)
        jobs.annuler(job_id)
        self.assertEqual(_attendre_fin(jobs, job_id)["status"], "cancelled")

    def test_un_seul_job_a_la_fois(self):
        barriere = threading.Event()

        def executer(objet, tdids, langues, **kw):
            barriere.wait(5)
            return {"objet": objet, "cles": 0, "textes_lus": 0, "absents": 0,
                    "lignes": 0, "inserees": 0, "csv": None, "duree_s": 0}
        jobs = textes_jobs.TextesJobs(executer=executer)
        premier = jobs.demarrer(objet="EINA", tdids=None, langues=None, purge=False)
        with self.assertRaises(textes_jobs.JobEnCours):
            jobs.demarrer(objet="EINE", tdids=None, langues=None, purge=False)
        barriere.set()
        _attendre_fin(jobs, premier)
        self.assertEqual(len(jobs.lister()), 1)

    def test_logs_du_job_captures(self):
        def executer(objet, tdids, langues, **kw):
            textes_jobs.LOG_EXTRACTION.info("Inventaire %s : 42 cles", objet)
            return {"objet": objet, "cles": 42, "textes_lus": 42, "absents": 0,
                    "lignes": 50, "inserees": 50, "csv": None, "duree_s": 0}
        jobs = textes_jobs.TextesJobs(executer=executer)
        job_id = jobs.demarrer(objet="EINA", tdids=None, langues=None, purge=False)
        _attendre_fin(jobs, job_id)
        logs = jobs.logs(job_id)
        self.assertTrue(any("Inventaire EINA : 42 cles" in l for l in logs), logs)


if __name__ == "__main__":
    unittest.main()
