# -*- coding: utf-8 -*-
"""Tests unitaires (sans SAP) du regroupement des reponses RFC_READ_TEXT.

Lancement dans le conteneur pyrfc_app :
    docker exec -w /app/texteSurCommande pyrfc_app python -m unittest test_extract_textes_longs_sap
"""
import unittest

from extract_textes_longs_sap import regrouper_reponse


def cle(tdname, tdid="BEST", tdspras="F"):
    return {"tdobject": "MATERIAL", "tdname": tdname, "tdid": tdid, "tdspras": tdspras}


def ligne(tdname, texte, fmt="*", tdid="BEST", tdspras="F"):
    return {"MANDT": "700", "TDOBJECT": "MATERIAL", "TDNAME": tdname, "TDID": tdid,
            "TDSPRAS": tdspras, "COUNTER": "000", "TDFORMAT": fmt, "TDLINE": texte}


class RegrouperReponseTest(unittest.TestCase):

    def test_lignes_regroupees_par_cle_dans_l_ordre_renvoye(self):
        cles = [cle("000000000000101760"), cle("000000000000229863")]
        reponse = {
            "MESSAGES": [],
            "TEXT_LINES": [
                ligne("000000000000101760", "ALUMINIUM CALCIUM 4%"),
                ligne("000000000000101760", "ID 360 mm", fmt="/"),
                ligne("000000000000229863", "Lunette de presse"),
            ],
        }
        resultat = regrouper_reponse(cles, reponse)
        self.assertEqual(
            [(l["TDFORMAT"], l["TDLINE"]) for l in resultat[("MATERIAL", "000000000000101760", "BEST", "F")]],
            [("*", "ALUMINIUM CALCIUM 4%"), ("/", "ID 360 mm")],
        )
        self.assertEqual(
            [l["TDLINE"] for l in resultat[("MATERIAL", "000000000000229863", "BEST", "F")]],
            ["Lunette de presse"],
        )

    def test_cle_signalee_absente_dans_messages_vaut_none_malgre_l_echo(self):
        # RFC_READ_TEXT renvoie la ligne de demande en echo (TDLINE vide) pour
        # une cle inexistante, et la signale dans MESSAGES (TD 600).
        cles = [cle("000000000000999999"), cle("000000000000101760")]
        reponse = {
            "MESSAGES": [{"TYPE": "E", "ID": "TD", "NUMBER": "600",
                          "MESSAGE_V1": "000000000000999999", "MESSAGE_V2": "BEST",
                          "MESSAGE_V3": "FR", "PARAMETER": "000000000000999999"}],
            "TEXT_LINES": [
                ligne("000000000000999999", "", fmt=""),
                ligne("000000000000101760", "ALUMINIUM CALCIUM 4%"),
            ],
        }
        resultat = regrouper_reponse(cles, reponse)
        self.assertIsNone(resultat[("MATERIAL", "000000000000999999", "BEST", "F")])
        self.assertEqual(len(resultat[("MATERIAL", "000000000000101760", "BEST", "F")]), 1)

    def test_cle_demandee_sans_aucune_ligne_vaut_none(self):
        cles = [cle("000000000000101760"), cle("000000000000555555")]
        reponse = {"MESSAGES": [], "TEXT_LINES": [ligne("000000000000101760", "x")]}
        resultat = regrouper_reponse(cles, reponse)
        self.assertIsNone(resultat[("MATERIAL", "000000000000555555", "BEST", "F")])
        self.assertEqual(len(resultat), 2)

    def test_tdname_rembourre_par_sap_est_rattache_a_la_cle(self):
        # TDNAME est un CHAR70 : SAP peut le renvoyer complete d'espaces.
        cles = [cle("000000000000101760")]
        reponse = {"MESSAGES": [], "TEXT_LINES": [ligne("000000000000101760      ", "x")]}
        resultat = regrouper_reponse(cles, reponse)
        self.assertEqual(len(resultat[("MATERIAL", "000000000000101760", "BEST", "F")]), 1)


if __name__ == "__main__":
    unittest.main()
