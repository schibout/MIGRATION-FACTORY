#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Extraction des textes longs SAP (objet MATERIAL) vers raw_data.sap_material_text.

Principe
--------
STXH ne contient que les clés, STXL.CLUSTD est un cluster compressé illisible en
SQL : le contenu s'obtient exclusivement via le module fonction SAP READ_TEXT.

Phase 1 - inventaire des clés
    --source stxh  (défaut) : lecture de raw_data.stxh, déjà chargée. Instantané.
    --source rfc            : RFC_READ_TABLE sur STXH, si raw_data.stxh est
                              absente ou périmée.
Phase 2 - lecture des contenus : boucle READ_TEXT, écriture CSV en flux.
Phase 3 - chargement : COPY du CSV dans raw_data.sap_material_text.

Configuration par variables d'environnement
-------------------------------------------
    SAP_ASHOST SAP_SYSNR SAP_CLIENT SAP_USER SAP_PASSWD [SAP_LANG=FR]
    SAP_FM_READ_TEXT   (défaut READ_TEXT, mettre Z_READ_TEXT si non RFC-enabled)
    SAP_FM_READ_TABLE  (défaut RFC_READ_TABLE)
    PG_DSN             (ex: postgresql://user:pwd@host:5432/base)

Exemples
--------
    python extract_textes_longs_sap.py --dry-run
    python extract_textes_longs_sap.py --tdid BEST --langue F
    python extract_textes_longs_sap.py --tdid BEST,GRUN,PRUE,IVER --langue F --no-load
"""

from __future__ import annotations

import argparse
import csv
import logging
import os
import sys
import time
from collections import Counter
from datetime import datetime
from pathlib import Path

import psycopg2
from pyrfc import (
    ABAPApplicationError,
    ABAPRuntimeError,
    CommunicationError,
    Connection,
    LogonError,
)

LOG = logging.getLogger("textes_sap")

TDID_DEFAUT = ["GRUN", "BEST", "PRUE", "IVER"]
TDOBJECT = "MATERIAL"
TABLE_CIBLE = "raw_data.sap_material_text"
CSV_COLONNES = [
    "tdobject", "tdname", "matnr", "tdid", "tdspras",
    "tdtitle", "line_no", "tdformat", "tdline",
    "source_file", "loaded_at",
]


# ---------------------------------------------------------------------------
# Conversion MATNR
# ---------------------------------------------------------------------------
def conversion_exit_matn1(matnr: str) -> str:
    """Format interne SAP du numéro d'article.

    Un article purement numérique est cadré à droite sur 18 avec des zéros de
    tête ('224069' -> '000000000000224069'). Un article alphanumérique est
    cadré à gauche, SANS zfill. Un zfill aveugle casse silencieusement toutes
    les références alphanumériques.
    """
    v = (matnr or "").strip()
    if v.isdigit():
        return v.zfill(18)
    if len(v) > 18:
        raise ValueError(f"MATNR alphanumérique de plus de 18 caractères : {v!r}")
    return v  # cadré à gauche, jamais complété


def matnr_lisible(tdname: str) -> str:
    v = (tdname or "").strip()
    return v.lstrip("0") if v.isdigit() else v


# ---------------------------------------------------------------------------
# Connexions
# ---------------------------------------------------------------------------
def connexion_sap() -> Connection:
    manquantes = [
        k for k in ("SAP_ASHOST", "SAP_SYSNR", "SAP_CLIENT", "SAP_USER", "SAP_PASSWD")
        if not os.environ.get(k)
    ]
    if manquantes:
        raise SystemExit(f"Variables d'environnement SAP manquantes : {', '.join(manquantes)}")
    return Connection(
        ashost=os.environ["SAP_ASHOST"],
        sysnr=os.environ["SAP_SYSNR"],
        client=os.environ["SAP_CLIENT"],
        user=os.environ["SAP_USER"],
        passwd=os.environ["SAP_PASSWD"],
        lang=os.environ.get("SAP_LANG", "FR"),
    )


def connexion_pg():
    dsn = os.environ.get("PG_DSN")
    if not dsn:
        raise SystemExit("Variable d'environnement PG_DSN manquante.")
    return psycopg2.connect(dsn)


# ---------------------------------------------------------------------------
# Phase 1 - inventaire des clés
# ---------------------------------------------------------------------------
def inventaire_depuis_stxh(tdids: list[str], langues: list[str] | None,
                           limit: int | None) -> list[dict]:
    """Lit les clés dans raw_data.stxh (déjà chargée). Aucun accès SAP."""
    sql = """
        SELECT h.tdobject, h.tdname, h.tdid, h.tdspras, coalesce(h.tdtitle, '')
        FROM   raw_data.stxh h
        WHERE  h.tdobject = %s
          AND  h.tdid = ANY(%s)
    """
    params: list = [TDOBJECT, tdids]
    if langues:
        sql += " AND h.tdspras = ANY(%s)"
        params.append(langues)
    sql += " ORDER BY h.tdid, h.tdspras, h.tdname"
    if limit:
        sql += f" LIMIT {int(limit)}"

    with connexion_pg() as cnx, cnx.cursor() as cur:
        cur.execute(sql, params)
        return [
            {"tdobject": r[0], "tdname": r[1], "tdid": r[2],
             "tdspras": r[3], "tdtitle": r[4]}
            for r in cur.fetchall()
        ]


def _decouper_options(condition: str, largeur: int = 72) -> list[dict]:
    """RFC_READ_TABLE n'accepte que des lignes OPTIONS de 72 caractères."""
    mots, lignes, courante = condition.split(), [], ""
    for mot in mots:
        if len(courante) + len(mot) + 1 > largeur:
            lignes.append({"TEXT": courante})
            courante = mot
        else:
            courante = f"{courante} {mot}".strip()
    if courante:
        lignes.append({"TEXT": courante})
    return lignes


def inventaire_depuis_rfc(conn: Connection, tdids: list[str],
                          langues: list[str] | None, limit: int | None) -> list[dict]:
    """RFC_READ_TABLE paginé sur STXH. Jamais sur STXL (CLUSTD compressé,
    et troncature à 512 octets par ligne)."""
    fm = os.environ.get("SAP_FM_READ_TABLE", "RFC_READ_TABLE")
    liste_id = ", ".join(f"'{t}'" for t in tdids)
    condition = f"TDOBJECT = '{TDOBJECT}' AND TDID IN ( {liste_id} )"
    if langues:
        condition += " AND TDSPRAS IN ( " + ", ".join(f"'{l}'" for l in langues) + " )"

    champs = ["TDOBJECT", "TDNAME", "TDID", "TDSPRAS", "TDTITLE"]
    resultats, skip, taille_page = [], 0, 5000

    while True:
        rep = conn.call(
            fm,
            QUERY_TABLE="STXH",
            DELIMITER="|",
            FIELDS=[{"FIELDNAME": c} for c in champs],
            OPTIONS=_decouper_options(condition),
            ROWCOUNT=taille_page,
            ROWSKIPS=skip,
        )
        lot = rep.get("DATA", [])
        if not lot:
            break
        for ligne in lot:
            valeurs = ligne["WA"].split("|")
            valeurs += [""] * (len(champs) - len(valeurs))
            resultats.append(dict(zip([c.lower() for c in champs], (v.strip() for v in valeurs))))
        LOG.info("Inventaire RFC : %d clés cumulées", len(resultats))
        if limit and len(resultats) >= limit:
            return resultats[:limit]
        if len(lot) < taille_page:
            break
        skip += taille_page

    return resultats


# ---------------------------------------------------------------------------
# Phase 2 - lecture des contenus
# ---------------------------------------------------------------------------
def lire_texte(conn: Connection, cle: dict, tentatives: int = 3) -> list[dict] | None:
    """Retourne les lignes du texte, ou None si le texte n'existe pas.

    READ_TEXT lève NOT_FOUND (ABAPApplicationError) quand le texte est absent :
    ce n'est pas un retour vide, et ça ne doit pas tuer la boucle.
    """
    fm = os.environ.get("SAP_FM_READ_TEXT", "READ_TEXT")
    attente = 2.0
    for essai in range(1, tentatives + 1):
        try:
            rep = conn.call(
                fm,
                OBJECT=cle["tdobject"],
                ID=cle["tdid"],
                NAME=cle["tdname"],
                LANGUAGE=cle["tdspras"],
            )
            return rep.get("LINES", [])
        except ABAPApplicationError as exc:
            if "NOT_FOUND" in str(exc).upper():
                return None
            LOG.warning("Erreur applicative sur %s/%s/%s : %s",
                        cle["tdid"], cle["tdname"], cle["tdspras"], exc)
            return None
        except ABAPRuntimeError as exc:
            msg = str(exc).upper()
            if "NOT_FOUND" in msg or "NOT RELEASED" in msg or "FU_NOT_FOUND" in msg:
                raise SystemExit(
                    f"Le module fonction '{fm}' n'est pas RFC-enabled sur ce système. "
                    "Faites créer un wrapper Z_READ_TEXT côté ABAP et positionnez "
                    "SAP_FM_READ_TEXT=Z_READ_TEXT."
                ) from exc
            raise
        except (CommunicationError, LogonError) as exc:
            if essai == tentatives:
                raise
            LOG.warning("Incident de communication (essai %d/%d) : %s — reprise dans %.0fs",
                        essai, tentatives, exc, attente)
            time.sleep(attente)
            attente *= 2
    return None


def extraire(conn: Connection, cles: list[dict], chemin_csv: Path) -> Counter:
    horodatage = datetime.now().isoformat(timespec="seconds")
    stats = Counter()
    total = len(cles)

    with chemin_csv.open("w", encoding="utf-8", newline="") as fh:
        writer = csv.DictWriter(fh, fieldnames=CSV_COLONNES)
        writer.writeheader()

        for idx, cle in enumerate(cles, start=1):
            lignes = lire_texte(conn, cle)
            if lignes is None:
                stats["absents"] += 1
            elif not lignes:
                stats["vides"] += 1
            else:
                stats["textes_lus"] += 1
                for rang, ligne in enumerate(lignes, start=1):
                    writer.writerow({
                        "tdobject": cle["tdobject"],
                        "tdname": cle["tdname"],
                        "matnr": matnr_lisible(cle["tdname"]),
                        "tdid": cle["tdid"],
                        "tdspras": cle["tdspras"],
                        "tdtitle": cle.get("tdtitle", ""),
                        "line_no": rang,
                        "tdformat": ligne.get("TDFORMAT", ""),
                        "tdline": ligne.get("TDLINE", ""),
                        "source_file": chemin_csv.name,
                        "loaded_at": horodatage,
                    })
                    stats["lignes_ecrites"] += 1

            if idx % 500 == 0 or idx == total:
                LOG.info("Progression %d/%d — lus %d, absents %d, lignes %d",
                         idx, total, stats["textes_lus"], stats["absents"],
                         stats["lignes_ecrites"])
    return stats


# ---------------------------------------------------------------------------
# Phase 3 - chargement
# ---------------------------------------------------------------------------
def charger(chemin_csv: Path, purger: bool) -> int:
    with connexion_pg() as cnx, cnx.cursor() as cur:
        if purger:
            cur.execute(f"TRUNCATE {TABLE_CIBLE} RESTART IDENTITY")
            LOG.info("Table %s purgée.", TABLE_CIBLE)
        colonnes = ", ".join(c for c in CSV_COLONNES)
        with chemin_csv.open("r", encoding="utf-8") as fh:
            cur.copy_expert(
                f"COPY {TABLE_CIBLE} ({colonnes}) FROM STDIN WITH (FORMAT csv, HEADER true)",
                fh,
            )
            inserees = cur.rowcount
        cnx.commit()
    return inserees


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------
def main() -> int:
    ap = argparse.ArgumentParser(description="Extraction des textes longs SAP objet MATERIAL.")
    ap.add_argument("--tdid", default=",".join(TDID_DEFAUT),
                    help="Types de texte, séparés par des virgules (défaut : GRUN,BEST,PRUE,IVER)")
    ap.add_argument("--langue", default=None,
                    help="Langues SAP séparées par des virgules (défaut : toutes)")
    ap.add_argument("--source", choices=("stxh", "rfc"), default="stxh",
                    help="Origine de l'inventaire des clés (défaut : stxh, table locale)")
    ap.add_argument("--limit", type=int, default=None, help="Plafond de clés, pour les essais")
    ap.add_argument("--dry-run", action="store_true",
                    help="Phase 1 seule : volumétrie, aucun READ_TEXT, aucune écriture")
    ap.add_argument("--no-load", action="store_true", help="Produit le CSV sans charger en base")
    ap.add_argument("--purge", action="store_true",
                    help="TRUNCATE de la table cible avant chargement")
    ap.add_argument("--sortie", default=".", help="Répertoire du CSV produit")
    args = ap.parse_args()

    logging.basicConfig(level=logging.INFO,
                        format="%(asctime)s  %(levelname)-7s %(message)s",
                        datefmt="%H:%M:%S")

    tdids = [t.strip().upper() for t in args.tdid.split(",") if t.strip()]
    langues = [l.strip().upper() for l in args.langue.split(",")] if args.langue else None
    depart = time.time()

    # Phase 1
    if args.source == "stxh":
        cles = inventaire_depuis_stxh(tdids, langues, args.limit)
    else:
        with connexion_sap() as c:
            cles = inventaire_depuis_rfc(c, tdids, langues, args.limit)

    repartition = Counter((c["tdid"], c["tdspras"]) for c in cles)
    LOG.info("Inventaire : %d clés", len(cles))
    for (tdid, spras), nb in sorted(repartition.items(), key=lambda x: -x[1]):
        LOG.info("    %s / %s : %d", tdid, spras, nb)

    if args.dry_run:
        LOG.info("Dry-run terminé en %.1fs — aucun accès SAP, aucune écriture.",
                 time.time() - depart)
        return 0
    if not cles:
        LOG.warning("Aucune clé à traiter, arrêt.")
        return 0

    # Phase 2
    horo = datetime.now().strftime("%Y%m%d_%H%M%S")
    chemin = Path(args.sortie) / f"textes_longs_material_{horo}.csv"
    with connexion_sap() as conn:
        stats = extraire(conn, cles, chemin)

    LOG.info("CSV produit : %s", chemin)
    LOG.info("Textes lus %d | absents %d | vides %d | lignes %d",
             stats["textes_lus"], stats["absents"], stats["vides"], stats["lignes_ecrites"])

    # Phase 3
    if args.no_load:
        LOG.info("--no-load : chargement ignoré.")
    else:
        inserees = charger(chemin, args.purge)
        LOG.info("Chargement %s : %d lignes.", TABLE_CIBLE, inserees)

    LOG.info("Terminé en %.1fs.", time.time() - depart)
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except KeyboardInterrupt:
        LOG.error("Interrompu par l'utilisateur.")
        sys.exit(130)
    except Exception as exc:  # noqa: BLE001
        LOG.error("Échec : %s", exc, exc_info=True)
        sys.exit(1)