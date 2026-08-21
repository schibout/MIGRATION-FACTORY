#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Extraction des textes longs SAP (objet MATERIAL) vers raw_data.sap_material_text.

Execution en 1-shot
-------------------
    python extract_textes_longs_sap.py

Sans aucun argument, le script enchaine tout, sans preparation manuelle :
    0. charge le .env (repertoire du script puis parents) ;
    1. cree le schema raw_data, la table cible et ses index (DDL idempotent) ;
    2. choisit tout seul la source de l'inventaire : raw_data.stxh si elle est
       presente et peuplee, sinon RFC_READ_TABLE sur STXH ;
    3. lit les contenus via READ_TEXT (une seule connexion SAP pour tout le run) ;
    4. charge le CSV en base de facon idempotente : le lot ecrase, dans une seule
       transaction, les lignes deja presentes pour les memes couples
       (tdobject, tdid, tdspras). Relancer le script ne cree donc pas de doublon.

Principe
--------
STXH ne contient que les cles, STXL.CLUSTD est un cluster compresse illisible en
SQL : le contenu s'obtient exclusivement via le module fonction SAP READ_TEXT.

Configuration par variables d'environnement (ou .env)
-----------------------------------------------------
    SAP_ASHOST SAP_SYSNR SAP_CLIENT SAP_USER SAP_PASSWD [SAP_LANG=FR]
    SAP_FM_READ_TEXT   (defaut READ_TEXT, mettre Z_READ_TEXT si non RFC-enabled)
    SAP_FM_READ_TABLE  (defaut RFC_READ_TABLE)
    PG_DSN             (ex: postgresql://user:pwd@host:5432/base)
    ou, a defaut de PG_DSN : PG_HOST PG_PORT PG_DATABASE PG_USER PG_PASSWORD

Variantes
---------
    python extract_textes_longs_sap.py --dry-run           # volumetrie seule
    python extract_textes_longs_sap.py --tdid BEST --langue F
    python extract_textes_longs_sap.py --source rfc --limit 200 --no-load
    python extract_textes_longs_sap.py --purge             # TRUNCATE avant chargement
"""

from __future__ import annotations

import argparse
import csv
import logging
import os
import sys
import time
from collections import Counter
from contextlib import closing
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

RACINE = Path(__file__).resolve().parent

TDID_DEFAUT = ["GRUN", "BEST", "PRUE", "IVER"]
TDOBJECT = "MATERIAL"
SCHEMA_CIBLE = "raw_data"
TABLE_CIBLE = f"{SCHEMA_CIBLE}.sap_material_text"
FICHIER_DDL = RACINE / "01_ddl_raw_data_sap_material_text.sql"
CSV_COLONNES = [
    "tdobject", "tdname", "matnr", "tdid", "tdspras",
    "tdtitle", "line_no", "tdformat", "tdline",
    "source_file", "loaded_at",
]

# DDL de secours si le fichier .sql n'est pas a cote du script.
DDL_SECOURS = f"""
CREATE TABLE IF NOT EXISTS {TABLE_CIBLE} (
    raw_id       BIGINT GENERATED ALWAYS AS IDENTITY,
    tdobject     TEXT,
    tdname       TEXT,
    matnr        TEXT,
    tdid         TEXT,
    tdspras      TEXT,
    tdtitle      TEXT,
    line_no      TEXT,
    tdformat     TEXT,
    tdline       TEXT,
    source_file  TEXT,
    loaded_at    TIMESTAMP
);
CREATE INDEX IF NOT EXISTS idx_sap_material_text_cle
    ON {TABLE_CIBLE} (tdid, tdspras, tdname);
CREATE INDEX IF NOT EXISTS idx_sap_material_text_matnr
    ON {TABLE_CIBLE} (matnr);
"""


# ---------------------------------------------------------------------------
# Phase 0 - environnement
# ---------------------------------------------------------------------------
def charger_env() -> None:
    """Charge le premier .env trouve depuis le repertoire du script en remontant.

    Sans python-dotenv installe, on ne fait rien : les variables deja presentes
    dans l'environnement suffisent.
    """
    try:
        from dotenv import load_dotenv
    except ImportError:
        LOG.debug("python-dotenv absent, lecture de l'environnement seul.")
        return
    for repertoire in (RACINE, *RACINE.parents):
        candidat = repertoire / ".env"
        if candidat.is_file():
            load_dotenv(candidat, override=False)
            LOG.info("Environnement charge depuis %s", candidat)
            return
    LOG.debug("Aucun fichier .env trouve.")


# ---------------------------------------------------------------------------
# Conversion MATNR
# ---------------------------------------------------------------------------
def conversion_exit_matn1(matnr: str) -> str:
    """Format interne SAP du numero d'article.

    Un article purement numerique est cadre a droite sur 18 avec des zeros de
    tete ('224069' -> '000000000000224069'). Un article alphanumerique est
    cadre a gauche, SANS zfill. Un zfill aveugle casse silencieusement toutes
    les references alphanumeriques.
    """
    v = (matnr or "").strip()
    if v.isdigit():
        return v.zfill(18)
    if len(v) > 18:
        raise ValueError(f"MATNR alphanumerique de plus de 18 caracteres : {v!r}")
    return v  # cadre a gauche, jamais complete


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
    """PG_DSN si fourni, sinon reconstruction depuis les variables PG_*."""
    dsn = os.environ.get("PG_DSN")
    if dsn:
        return psycopg2.connect(dsn)
    if os.environ.get("PG_DATABASE"):
        return psycopg2.connect(
            host=os.environ.get("PG_HOST", "localhost"),
            port=os.environ.get("PG_PORT", "5432"),
            dbname=os.environ["PG_DATABASE"],
            user=os.environ.get("PG_USER", "postgres"),
            password=os.environ.get("PG_PASSWORD", ""),
        )
    raise SystemExit("Configuration PostgreSQL absente : renseignez PG_DSN ou PG_DATABASE.")


# ---------------------------------------------------------------------------
# Phase 1a - preparation du schema
# ---------------------------------------------------------------------------
def preparer_schema() -> None:
    """Cree schema, table cible et index. Idempotent, rejouable a chaque run."""
    ddl = FICHIER_DDL.read_text(encoding="utf-8") if FICHIER_DDL.is_file() else DDL_SECOURS
    with closing(connexion_pg()) as cnx, cnx.cursor() as cur:
        cur.execute(f"CREATE SCHEMA IF NOT EXISTS {SCHEMA_CIBLE}")
        cur.execute(ddl)
        cnx.commit()
    LOG.info("Schema pret : %s", TABLE_CIBLE)


def stxh_utilisable() -> bool:
    """raw_data.stxh existe-t-elle et contient-elle au moins une ligne ?"""
    with closing(connexion_pg()) as cnx, cnx.cursor() as cur:
        cur.execute("SELECT to_regclass(%s)", (f"{SCHEMA_CIBLE}.stxh",))
        if cur.fetchone()[0] is None:
            return False
        cur.execute(f"SELECT EXISTS (SELECT 1 FROM {SCHEMA_CIBLE}.stxh LIMIT 1)")
        return bool(cur.fetchone()[0])


# ---------------------------------------------------------------------------
# Phase 1 - inventaire des cles
# ---------------------------------------------------------------------------
def inventaire_depuis_stxh(tdids: list[str], langues: list[str] | None,
                           limit: int | None) -> list[dict]:
    """Lit les cles dans raw_data.stxh (deja chargee). Aucun acces SAP."""
    sql = f"""
        SELECT h.tdobject, h.tdname, h.tdid, h.tdspras, coalesce(h.tdtitle, '')
        FROM   {SCHEMA_CIBLE}.stxh h
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

    with closing(connexion_pg()) as cnx, cnx.cursor() as cur:
        cur.execute(sql, params)
        return [
            {"tdobject": r[0], "tdname": r[1], "tdid": r[2],
             "tdspras": r[3], "tdtitle": r[4]}
            for r in cur.fetchall()
        ]


def _decouper_options(condition: str, largeur: int = 72) -> list[dict]:
    """RFC_READ_TABLE n'accepte que des lignes OPTIONS de 72 caracteres."""
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
    """RFC_READ_TABLE pagine sur STXH. Jamais sur STXL (CLUSTD compresse,
    et troncature a 512 octets par ligne)."""
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
        LOG.info("Inventaire RFC : %d cles cumulees", len(resultats))
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

    READ_TEXT leve NOT_FOUND (ABAPApplicationError) quand le texte est absent :
    ce n'est pas un retour vide, et ca ne doit pas tuer la boucle.
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
                    f"Le module fonction '{fm}' n'est pas RFC-enabled sur ce systeme. "
                    "Faites creer un wrapper Z_READ_TEXT cote ABAP et positionnez "
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
    """COPY en staging temporaire puis remplacement du lot, en une transaction.

    Sans --purge, seules les lignes des couples (tdobject, tdid, tdspras)
    presents dans le CSV sont remplacees : le run est rejouable sans doublon et
    sans toucher aux types de texte non extraits.
    """
    colonnes = ", ".join(CSV_COLONNES)
    with closing(connexion_pg()) as cnx, cnx.cursor() as cur:
        if purger:
            cur.execute(f"TRUNCATE {TABLE_CIBLE} RESTART IDENTITY")
            LOG.info("Table %s purgee.", TABLE_CIBLE)

        cur.execute("""
            CREATE TEMP TABLE stg_material_text (
                tdobject TEXT, tdname TEXT, matnr TEXT, tdid TEXT, tdspras TEXT,
                tdtitle TEXT, line_no TEXT, tdformat TEXT, tdline TEXT,
                source_file TEXT, loaded_at TIMESTAMP
            ) ON COMMIT DROP
        """)
        with chemin_csv.open("r", encoding="utf-8") as fh:
            cur.copy_expert(
                f"COPY stg_material_text ({colonnes}) FROM STDIN WITH (FORMAT csv, HEADER true)",
                fh,
            )
        cur.execute("SELECT count(*) FROM stg_material_text")
        a_charger = cur.fetchone()[0]

        if not purger:
            cur.execute(f"""
                DELETE FROM {TABLE_CIBLE} c
                USING (SELECT DISTINCT tdobject, tdid, tdspras FROM stg_material_text) s
                WHERE  c.tdobject IS NOT DISTINCT FROM s.tdobject
                  AND  c.tdid     IS NOT DISTINCT FROM s.tdid
                  AND  c.tdspras  IS NOT DISTINCT FROM s.tdspras
            """)
            if cur.rowcount:
                LOG.info("Remplacement du lot : %d lignes anterieures supprimees.", cur.rowcount)

        cur.execute(
            f"INSERT INTO {TABLE_CIBLE} ({colonnes}) "
            f"SELECT {colonnes} FROM stg_material_text"
        )
        inserees = cur.rowcount
        cnx.commit()

    if inserees != a_charger:
        LOG.warning("Ecart staging/cible : %d lues, %d inserees.", a_charger, inserees)
    return inserees


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------
def main() -> int:
    ap = argparse.ArgumentParser(
        description="Extraction 1-shot des textes longs SAP objet MATERIAL.",
        epilog="Sans argument : prepare le schema, choisit la source, extrait et charge.",
    )
    ap.add_argument("--tdid", default=",".join(TDID_DEFAUT),
                    help="Types de texte, separes par des virgules (defaut : GRUN,BEST,PRUE,IVER)")
    ap.add_argument("--langue", default=None,
                    help="Langues SAP separees par des virgules (defaut : toutes)")
    ap.add_argument("--source", choices=("auto", "stxh", "rfc"), default="auto",
                    help="Origine de l'inventaire des cles (defaut : auto, stxh si peuplee sinon rfc)")
    ap.add_argument("--limit", type=int, default=None, help="Plafond de cles, pour les essais")
    ap.add_argument("--dry-run", action="store_true",
                    help="Phase 1 seule : volumetrie, aucun READ_TEXT, aucune ecriture")
    ap.add_argument("--no-load", action="store_true", help="Produit le CSV sans charger en base")
    ap.add_argument("--purge", action="store_true",
                    help="TRUNCATE de la table cible avant chargement (sinon remplacement du lot)")
    ap.add_argument("--sortie", default=str(RACINE / "sorties"),
                    help="Repertoire du CSV produit (cree si absent)")
    args = ap.parse_args()

    logging.basicConfig(level=logging.INFO,
                        format="%(asctime)s  %(levelname)-7s %(message)s",
                        datefmt="%H:%M:%S")

    charger_env()

    tdids = [t.strip().upper() for t in args.tdid.split(",") if t.strip()]
    langues = [l.strip().upper() for l in args.langue.split(",")] if args.langue else None
    depart = time.time()

    # Phase 0 - schema (saute en dry-run : on ne touche a rien)
    if not args.dry_run:
        preparer_schema()

    # Phase 1 - inventaire
    source = args.source
    if source == "auto":
        source = "stxh" if stxh_utilisable() else "rfc"
        LOG.info("Source d'inventaire retenue automatiquement : %s", source)

    conn_sap: Connection | None = None
    try:
        if source == "stxh":
            cles = inventaire_depuis_stxh(tdids, langues, args.limit)
        else:
            conn_sap = connexion_sap()
            cles = inventaire_depuis_rfc(conn_sap, tdids, langues, args.limit)

        repartition = Counter((c["tdid"], c["tdspras"]) for c in cles)
        LOG.info("Inventaire : %d cles", len(cles))
        for (tdid, spras), nb in sorted(repartition.items(), key=lambda x: -x[1]):
            LOG.info("    %s / %s : %d", tdid, spras, nb)

        if args.dry_run:
            LOG.info("Dry-run termine en %.1fs — aucune ecriture.", time.time() - depart)
            return 0
        if not cles:
            LOG.warning("Aucune cle a traiter, arret.")
            return 0

        # Phase 2 - lecture des contenus, sur la meme connexion SAP si deja ouverte
        repertoire = Path(args.sortie)
        repertoire.mkdir(parents=True, exist_ok=True)
        horo = datetime.now().strftime("%Y%m%d_%H%M%S")
        chemin = repertoire / f"textes_longs_material_{horo}.csv"

        if conn_sap is None:
            conn_sap = connexion_sap()
        stats = extraire(conn_sap, cles, chemin)
    finally:
        if conn_sap is not None:
            try:
                conn_sap.close()
            except Exception:  # noqa: BLE001
                LOG.debug("Fermeture de la connexion SAP en echec, ignore.")

    LOG.info("CSV produit : %s", chemin)
    LOG.info("Textes lus %d | absents %d | vides %d | lignes %d",
             stats["textes_lus"], stats["absents"], stats["vides"], stats["lignes_ecrites"])

    # Phase 3 - chargement
    if args.no_load:
        LOG.info("--no-load : chargement ignore.")
    else:
        inserees = charger(chemin, args.purge)
        LOG.info("Chargement %s : %d lignes.", TABLE_CIBLE, inserees)

    LOG.info("Termine en %.1fs.", time.time() - depart)
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except KeyboardInterrupt:
        LOG.error("Interrompu par l'utilisateur.")
        sys.exit(130)
    except Exception as exc:  # noqa: BLE001
        LOG.error("Echec : %s", exc, exc_info=True)
        sys.exit(1)
