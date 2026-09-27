#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Extraction des textes longs SAP (tout objet STXH) vers raw_data.sap_long_text.

Execution en 1-shot
-------------------
    python extract_textes_longs_sap.py

Sans aucun argument, le script traite l'objet MATERIAL et enchaine tout :
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
SQL (et de type LRAW, que RFC_READ_TABLE ne sait pas renvoyer : la colonne est
NULL dans raw_data.stxl). Le contenu s'obtient exclusivement par module fonction.
Sur PRO (R/3 4.6C), READ_TEXT en RFC repond NOT_FOUND (DA 300) sur toutes les
cles : la lecture passe par RFC_READ_TEXT, par lots de 500 cles (~0,7 s/lot),
cf. lire_textes_par_lot(). READ_TEXT ne sert plus qu'au --diagnostic.

Configuration par variables d'environnement (ou .env)
-----------------------------------------------------
    SAP_ASHOST SAP_USER SAP_PASSWORD   (obligatoires)
    SAP_SYSNR=00 SAP_CLIENT=100 SAP_LANG=FR SAP_TRACE=0   (defauts)
    SAP_FM_READ_TEXT_LOT (defaut RFC_READ_TEXT, lecture par lot)
    SAP_FM_READ_TEXT   (defaut READ_TEXT, utilise par --diagnostic seulement)
    SAP_FM_READ_TABLE  (defaut RFC_READ_TABLE)
    PG_DSN             (ex: postgresql://user:pwd@host:5432/base)
    ou, a defaut de PG_DSN : PG_HOST PG_PORT PG_DATABASE PG_USER PG_PASSWORD

Variantes
---------
    python extract_textes_longs_sap.py --dry-run           # volumetrie seule
    python extract_textes_longs_sap.py --tdid BEST --langue F
    python extract_textes_longs_sap.py --objet EINA        # fiches-info d'achat, tous ID, toutes langues
    python extract_textes_longs_sap.py --objet EINE --tdid BT
    python extract_textes_longs_sap.py --source rfc --limit 200 --no-load
    python extract_textes_longs_sap.py --purge             # TRUNCATE avant chargement
"""

from __future__ import annotations

import argparse
import csv
import logging
import os
import sys
import threading
import time
from collections import Counter
from concurrent.futures import ThreadPoolExecutor
from contextlib import closing
from datetime import datetime
from itertools import islice
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

OBJET_DEFAUT = "MATERIAL"
SCHEMA_CIBLE = "raw_data"
TABLE_CIBLE = f"{SCHEMA_CIBLE}.sap_long_text"
FICHIER_DDL = RACINE / "01_ddl_raw_data_sap_long_text.sql"
CSV_COLONNES = [
    "tdobject", "tdname", "tdid", "tdspras",
    "tdtitle", "line_no", "tdformat", "tdline",
    "source_file", "loaded_at",
]

# DDL de secours si le fichier .sql n'est pas a cote du script.
DDL_SECOURS = f"""
CREATE TABLE IF NOT EXISTS {TABLE_CIBLE} (
    raw_id       BIGINT GENERATED ALWAYS AS IDENTITY,
    tdobject     TEXT,
    tdname       TEXT,
    tdid         TEXT,
    tdspras      TEXT,
    tdtitle      TEXT,
    line_no      TEXT,
    tdformat     TEXT,
    tdline       TEXT,
    source_file  TEXT,
    loaded_at    TIMESTAMP
);
CREATE INDEX IF NOT EXISTS idx_sap_long_text_cle
    ON {TABLE_CIBLE} (tdobject, tdid, tdspras, tdname);
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
    """Meme convention de nommage que sap_extraction/config/connection_config.py.

    Le mot de passe se lit dans SAP_PASSWORD (nom du projet et du .env) ;
    SAP_PASSWD reste accepte en repli pour les environnements deja parametres.
    """
    passwd = os.environ.get("SAP_PASSWORD") or os.environ.get("SAP_PASSWD")
    manquantes = [k for k in ("SAP_ASHOST", "SAP_USER") if not os.environ.get(k)]
    if not passwd:
        manquantes.append("SAP_PASSWORD")
    if manquantes:
        raise SystemExit(f"Variables d'environnement SAP manquantes : {', '.join(manquantes)}")
    return Connection(
        ashost=os.environ["SAP_ASHOST"],
        sysnr=os.environ.get("SAP_SYSNR", "00"),
        client=os.environ.get("SAP_CLIENT", "100"),
        user=os.environ["SAP_USER"],
        passwd=passwd,
        lang=os.environ.get("SAP_LANG", "FR"),
        # >= 1 ecrit les mots de passe en clair dans les .trc : 0 par defaut.
        trace=os.environ.get("SAP_TRACE", "0"),
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
def inventaire_depuis_stxh(objet: str, tdids: list[str] | None, langues: list[str] | None,
                           limit: int | None, exclure_vides: bool = False) -> list[dict]:
    """Lit les cles dans raw_data.stxh (deja chargee). Aucun acces SAP.

    STXH.TDTXTLINES n'est PAS fiable sur PRO : le 19/09/2026, 2 024 en-tetes
    MATERIAL/BEST/F a zero ligne annoncee portaient 3 332 lignes reelles, et
    3 181 autres annoncaient un nombre different du contenu. On lit donc tout
    l'inventaire par defaut ; --exclure-vides ne sert qu'a raccourcir un essai.
    """
    sql = f"""
        SELECT h.tdobject, h.tdname, h.tdid, h.tdspras, coalesce(h.tdtitle, ''),
               coalesce(h.tdtxtlines, '')
        FROM   {SCHEMA_CIBLE}.stxh h
        WHERE  h.tdobject = %s
    """
    params: list = [objet]
    if tdids:
        sql += " AND h.tdid = ANY(%s)"
        params.append(tdids)
    if langues:
        sql += " AND h.tdspras = ANY(%s)"
        params.append(langues)
    if exclure_vides:
        sql += " AND coalesce(h.tdtxtlines, '0')::int > 0"
    sql += " ORDER BY h.tdid, h.tdspras, h.tdname"
    if limit:
        sql += f" LIMIT {int(limit)}"

    with closing(connexion_pg()) as cnx, cnx.cursor() as cur:
        cur.execute(sql, params)
        return [
            {"tdobject": r[0], "tdname": r[1], "tdid": r[2],
             "tdspras": r[3], "tdtitle": r[4], "tdtxtlines": r[5]}
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


def inventaire_depuis_rfc(conn: Connection, objet: str, tdids: list[str] | None,
                          langues: list[str] | None, limit: int | None) -> list[dict]:
    """RFC_READ_TABLE pagine sur STXH. Jamais sur STXL (CLUSTD compresse,
    et troncature a 512 octets par ligne)."""
    fm = os.environ.get("SAP_FM_READ_TABLE", "RFC_READ_TABLE")
    condition = f"TDOBJECT = '{objet}'"
    if tdids:
        condition += " AND TDID IN ( " + ", ".join(f"'{t}'" for t in tdids) + " )"
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
# Diagnostic - a lancer AVANT toute extraction longue
# ---------------------------------------------------------------------------
def _verifier_stxh_en_direct(conn: Connection, cle: dict) -> None:
    """Relit STXH dans le systeme, pour la cle exacte, via RFC_READ_TABLE.

    READ_TEXT ne fait qu'un SELECT SINGLE sur STXH dans le client de logon.
    Si la ligne existe dans raw_data.stxh mais pas ici, la copie locale vient
    d'un autre client ou d'un autre systeme : le probleme est l'inventaire,
    pas l'appel READ_TEXT.
    """
    fm = os.environ.get("SAP_FM_READ_TABLE", "RFC_READ_TABLE")
    condition = (f"TDOBJECT = '{cle['tdobject']}' AND TDNAME = '{cle['tdname']}' "
                 f"AND TDID = '{cle['tdid']}' AND TDSPRAS = '{cle['tdspras']}'")
    try:
        rep = conn.call(
            fm,
            QUERY_TABLE="STXH",
            DELIMITER="|",
            FIELDS=[{"FIELDNAME": c} for c in ("MANDT", "TDOBJECT", "TDNAME",
                                               "TDID", "TDSPRAS", "TDTXTLINES")],
            OPTIONS=_decouper_options(condition),
            ROWCOUNT=5,
        )
        lignes = rep.get("DATA", [])
        if lignes:
            for ligne in lignes:
                LOG.info("    STXH en direct       -> PRESENTE : %s", ligne["WA"].strip())
        else:
            LOG.info("    STXH en direct       -> ABSENTE du systeme pour cette cle "
                     "(la copie raw_data.stxh ne correspond pas au client de logon)")
    except Exception as exc:  # noqa: BLE001
        LOG.info("    STXH en direct       -> ECHEC [%s] %s",
                 getattr(exc, "key", type(exc).__name__), exc)


def diagnostic(conn: Connection, cles: list[dict], nb: int = 5) -> None:
    """Teste quelques cles en affichant l'erreur SAP brute, sans rien avaler.

    Un run complet qui ne renvoie que des 'absents' signifie que les parametres
    envoyes a READ_TEXT ne correspondent pas a ce qu'attend le systeme. On teste
    donc plusieurs formes de NAME sur un echantillon etale sur tout l'inventaire.
    """
    fm = os.environ.get("SAP_FM_READ_TEXT", "READ_TEXT")
    # On teste en priorite des cles dont l'en-tete annonce des lignes : un
    # NOT_FOUND y est forcement anormal, donc concluant.
    avec_contenu = [c for c in cles if (c.get("tdtxtlines") or "0").strip("0") != ""]
    vivier = avec_contenu or cles
    pas = max(1, len(vivier) // nb)
    echantillon = list(islice(vivier, 0, len(vivier), pas))[:nb]

    # Le client de connexion doit correspondre au MANDT des lignes STXH lues :
    # un ecart explique a lui seul un NOT_FOUND sur 100% des cles.
    try:
        attrs = conn.get_connection_attributes()
        LOG.info("Connexion SAP : client=%s user=%s host=%s sysnr=%s langue=%s",
                 attrs.get("client"), attrs.get("user"), attrs.get("host"),
                 attrs.get("sysNumber"), attrs.get("language"))
    except Exception as exc:  # noqa: BLE001
        LOG.info("Attributs de connexion indisponibles : %s", exc)
    LOG.info("Comparez ce client au MANDT de raw_data.stxh "
             "(SELECT DISTINCT mandt FROM raw_data.stxh).")
    LOG.info("Correspondance des langues (T002) : %s",
             {k: v for k, v in sorted(_LANGUES_ISO.items())} or "indisponible")

    LOG.info("=== DIAGNOSTIC : %s sur %d cles ===", fm, len(echantillon))
    for cle in echantillon:
        _verifier_stxh_en_direct(conn, cle)
        LOG.info("--- OBJECT=%s ID=%s LANGUAGE=%s NAME=%r",
                 cle["tdobject"], cle["tdid"], cle["tdspras"], cle["tdname"])
        client_stxh = os.environ.get("SAP_CLIENT", "100")
        interne = cle["tdspras"]
        iso = langue_pour_read_text(interne)
        variantes = [
            ("langue ISO", cle["tdname"], iso, {}),
            ("langue ISO + CLIENT", cle["tdname"], iso, {"CLIENT": client_stxh}),
            ("langue interne", cle["tdname"], interne, {}),
            ("langue ISO + MATN1", conversion_exit_matn1(cle["tdname"]), iso, {}),
            ("langue ISO + sans zeros", matnr_lisible(cle["tdname"]), iso, {}),
        ]
        for etiquette, nom, langue, extra in variantes:
            try:
                rep = conn.call(fm, OBJECT=cle["tdobject"], ID=cle["tdid"],
                                NAME=nom, LANGUAGE=langue, **extra)
                lignes = rep.get("LINES", [])
                apercu = (lignes[0].get("TDLINE", "") if lignes else "")[:60]
                LOG.info("    %-24s LANGUAGE=%r NAME=%r -> %d ligne(s) %s",
                         etiquette, langue, nom, len(lignes),
                         f"| {apercu!r}" if apercu else "")
            except Exception as exc:  # noqa: BLE001
                cle_erreur = getattr(exc, "key", type(exc).__name__)
                LOG.info("    %-24s LANGUAGE=%r NAME=%r -> ECHEC [%s] %s",
                         etiquette, langue, nom, cle_erreur, exc)
    fm_lot = os.environ.get("SAP_FM_READ_TEXT_LOT", "RFC_READ_TEXT")
    LOG.info("=== DIAGNOSTIC : %s (lecture par lot, mode nominal) ===", fm_lot)
    try:
        for cle, lignes in lire_textes_par_lot(conn, echantillon):
            apercu = (lignes[0]["TDLINE"] if lignes else "")[:60]
            LOG.info("    NAME=%r -> %s %s", cle["tdname"],
                     "absent" if lignes is None else f"{len(lignes)} ligne(s)",
                     f"| {apercu!r}" if apercu else "")
    except Exception as exc:  # noqa: BLE001
        LOG.info("    ECHEC [%s] %s", getattr(exc, "key", type(exc).__name__), exc)
    LOG.info("=== FIN DIAGNOSTIC ===")


# ---------------------------------------------------------------------------
# Phase 2 - lecture des contenus
# ---------------------------------------------------------------------------
_LANGUES_ISO: dict[str, str] = {}


def _mapping_langues_depuis_pg() -> dict[str, str]:
    """T002 depuis raw_data si elle y est deja : aucun aller-retour SAP."""
    with closing(connexion_pg()) as cnx, cnx.cursor() as cur:
        cur.execute(f"SELECT to_regclass('{SCHEMA_CIBLE}.t002')")
        if cur.fetchone()[0] is None:
            return {}
        # La table peut contenir des doublons de chargement.
        cur.execute(f"""
            SELECT DISTINCT btrim(spras), btrim(laiso)
            FROM {SCHEMA_CIBLE}.t002
            WHERE coalesce(btrim(spras), '') <> '' AND coalesce(btrim(laiso), '') <> ''
        """)
        return {interne: iso for interne, iso in cur.fetchall()}


def charger_mapping_langues(conn: Connection) -> dict[str, str]:
    """Correspondance langue interne SAP -> code ISO, lue dans T002.

    Les parametres typés SPRAS/LANG sont convertis par la couche RFC entre code
    ISO a 2 caracteres et code interne a 1 caractere. Envoyer 'F' a READ_TEXT
    donne une langue vide cote ABAP, donc NOT_FOUND. Il faut envoyer 'FR'.
    T002 porte la table de correspondance : on la lit plutot que de la figer.

    raw_data.t002 est privilegiee quand elle existe : le run standard ne fait
    alors plus aucun RFC_READ_TABLE, seulement des READ_TEXT.
    """
    try:
        mapping = _mapping_langues_depuis_pg()
        if mapping:
            LOG.info("Langues lues dans %s.t002 (aucun appel RFC).", SCHEMA_CIBLE)
            return mapping
    except Exception as exc:  # noqa: BLE001
        LOG.debug("Lecture de %s.t002 impossible (%s), repli sur RFC.", SCHEMA_CIBLE, exc)

    fm = os.environ.get("SAP_FM_READ_TABLE", "RFC_READ_TABLE")
    mapping = {}
    try:
        rep = conn.call(fm, QUERY_TABLE="T002", DELIMITER="|",
                        FIELDS=[{"FIELDNAME": "SPRAS"}, {"FIELDNAME": "LAISO"}])
        for ligne in rep.get("DATA", []):
            interne, _, iso = ligne["WA"].partition("|")
            interne, iso = interne.strip(), iso.strip()
            if interne and iso:
                mapping[interne] = iso
    except Exception as exc:  # noqa: BLE001
        LOG.warning("Lecture de T002 impossible (%s) : les langues seront "
                    "envoyees telles quelles.", exc)
    return mapping


def langue_pour_read_text(tdspras: str) -> str:
    """Code ISO si connu, sinon la valeur telle quelle."""
    return _LANGUES_ISO.get(tdspras, tdspras)


FORMES_NOM = {
    "stxh": lambda v: v,                       # tel quel, tel que stocke dans STXH
    "matn1": conversion_exit_matn1,            # conversion externe -> interne
    "court": matnr_lisible,                    # sans zeros de tete
}


def lire_texte(conn: Connection, cle: dict, forme_nom: str = "stxh",
               tentatives: int = 3) -> list[dict] | None:
    """Retourne les lignes du texte, ou None si le texte n'existe pas.

    READ_TEXT leve NOT_FOUND (ABAPApplicationError) quand le texte est absent :
    ce n'est pas un retour vide, et ca ne doit pas tuer la boucle.
    """
    fm = os.environ.get("SAP_FM_READ_TEXT", "READ_TEXT")
    nom = FORMES_NOM[forme_nom](cle["tdname"])
    attente = 2.0
    for essai in range(1, tentatives + 1):
        try:
            rep = conn.call(
                fm,
                OBJECT=cle["tdobject"],
                ID=cle["tdid"],
                NAME=nom,
                LANGUAGE=langue_pour_read_text(cle["tdspras"]),
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


# ---------------------------------------------------------------------------
# Phase 2 bis - lecture par lot via RFC_READ_TEXT
# ---------------------------------------------------------------------------
# Sur le systeme PRO (R/3 4.6C), READ_TEXT appele en RFC repond NOT_FOUND
# (DA 300) sur TOUTES les cles, meme celles dont l'en-tete STXH existe.
# RFC_READ_TEXT, prevu pour l'appel distant, sert des centaines de cles par
# appel (500 cles en ~0,7 s) et renvoie le contenu correctement.
#   - une cle absente est renvoyee en ECHO dans TEXT_LINES (TDLINE vide) et
#     signalee dans MESSAGES (TD 600, PARAMETER = TDNAME) : c'est MESSAGES
#     qui fait foi pour l'ecarter ;
#   - COUNTER vaut toujours '000' : l'ordre des lignes est celui de la table.
TAILLE_LOT_DEFAUT = 500


def _cle_tuple(cle: dict) -> tuple[str, str, str, str]:
    return (cle["tdobject"].strip(), cle["tdname"].strip(),
            cle["tdid"].strip(), cle["tdspras"].strip())


def regrouper_reponse(cles: list[dict], reponse: dict) -> dict[tuple, list[dict] | None]:
    """Regroupe TEXT_LINES par cle demandee, dans l'ordre renvoye par SAP.

    Retourne, pour CHAQUE cle demandee, la liste de ses lignes, ou None si
    le texte n'existe pas (cle signalee dans MESSAGES ou sans aucune ligne).
    """
    absentes = set()
    for msg in reponse.get("MESSAGES", []) or []:
        if (msg.get("TYPE") or "").upper() != "E":
            continue
        nom = (msg.get("PARAMETER") or msg.get("MESSAGE_V1") or "").strip()
        tdid = (msg.get("MESSAGE_V2") or "").strip()
        absentes.add((nom, tdid))

    resultat: dict[tuple, list[dict] | None] = {_cle_tuple(c): None for c in cles}
    for ligne in reponse.get("TEXT_LINES", []) or []:
        k = (ligne.get("TDOBJECT", "").strip(), ligne.get("TDNAME", "").strip(),
             ligne.get("TDID", "").strip(), ligne.get("TDSPRAS", "").strip())
        if k not in resultat or (k[1], k[2]) in absentes:
            continue
        if resultat[k] is None:
            resultat[k] = []
        resultat[k].append({"TDFORMAT": ligne.get("TDFORMAT", ""),
                            "TDLINE": ligne.get("TDLINE", "")})
    return resultat


def lire_textes_par_lot(conn: Connection, cles: list[dict], forme_nom: str = "stxh",
                        tentatives: int = 3) -> list[tuple[dict, list[dict] | None]]:
    """Un appel RFC_READ_TEXT pour tout le lot ; retourne [(cle, lignes|None)]."""
    fm = os.environ.get("SAP_FM_READ_TEXT_LOT", "RFC_READ_TEXT")
    demande = [{"TDOBJECT": c["tdobject"], "TDNAME": FORMES_NOM[forme_nom](c["tdname"]),
                "TDID": c["tdid"], "TDSPRAS": c["tdspras"]} for c in cles]
    attente = 2.0
    for essai in range(1, tentatives + 1):
        try:
            reponse = conn.call(fm, TEXT_LINES=demande)
            break
        except (CommunicationError, LogonError) as exc:
            if essai == tentatives:
                raise
            LOG.warning("Incident de communication (essai %d/%d) : %s — reprise dans %.0fs",
                        essai, tentatives, exc, attente)
            time.sleep(attente)
            attente *= 2
    # Les cles sont demandees sous leur forme convertie : on regroupe sur
    # cette forme puis on rend la cle d'origine (celle de l'inventaire).
    cles_forme = [dict(c, tdname=FORMES_NOM[forme_nom](c["tdname"])) for c in cles]
    groupes = regrouper_reponse(cles_forme, reponse)
    return [(c, groupes[_cle_tuple(cf)]) for c, cf in zip(cles, cles_forme)]


_LOCAL = threading.local()
_CONNEXIONS: list[Connection] = []
_VERROU = threading.Lock()


def _connexion_du_thread() -> Connection:
    """Une connexion SAP par thread : pyrfc n'est pas thread-safe."""
    conn = getattr(_LOCAL, "conn", None)
    if conn is None:
        conn = connexion_sap()
        _LOCAL.conn = conn
        with _VERROU:
            _CONNEXIONS.append(conn)
    return conn


def _fermer_connexions_threads() -> None:
    with _VERROU:
        for conn in _CONNEXIONS:
            try:
                conn.close()
            except Exception:  # noqa: BLE001
                LOG.debug("Fermeture d'une connexion SAP de thread en echec, ignore.")
        _CONNEXIONS.clear()


class ExtractionSterile(RuntimeError):
    """Aucun texte trouve sur les premieres cles : inutile de continuer."""


def _par_tranches(pool: ThreadPoolExecutor, fonction, elements: list,
                  taille: int):
    """map() paresseux : ne met en file qu'une tranche a la fois.

    pool.map() soumettrait les 130 000 taches immediatement ; sortir de la
    boucle imposerait alors d'attendre la file entiere a la fermeture du pool.
    """
    for debut in range(0, len(elements), taille):
        tranche = elements[debut:debut + taille]
        futures = [pool.submit(fonction, e) for e in tranche]
        try:
            for future in futures:
                yield future.result()
        except GeneratorExit:
            for future in futures:
                future.cancel()
            raise
        except BaseException:
            for future in futures:
                future.cancel()
            raise


def extraire(cles: list[dict], chemin_csv: Path, forme_nom: str = "stxh",
             workers: int = 8, seuil_sterile: int = 300,
             taille_tranche: int = 2000, taille_lot: int = TAILLE_LOT_DEFAUT,
             progression=None, doit_arreter=None) -> Counter:
    """Lit les textes par lots RFC_READ_TEXT (une connexion SAP par thread) et ecrit le CSV.

    progression(idx, total, stats) est appele tous les 500 textes (suivi API) ;
    doit_arreter() -> True interrompt proprement apres la tranche en cours
    (annulation API) : le CSV partiel est conserve, stats["interrompu"] = 1.

    Le travail est soumis par tranches, et non d'un bloc : une interruption ou
    un arret anticipe ne draine alors qu'une tranche au lieu d'attendre les
    130 000 taches deja mises en file. Le CSV est ecrit depuis le thread
    principal, dans l'ordre de l'inventaire, avec flush regulier : une
    interruption laisse toujours un fichier exploitable.
    """
    horodatage = datetime.now().isoformat(timespec="seconds")
    stats = Counter()
    total = len(cles)
    depart = time.time()

    def travail(lot: list[dict]):
        return lire_textes_par_lot(_connexion_du_thread(), lot, forme_nom)

    lots = [cles[i:i + taille_lot] for i in range(0, total, taille_lot)]

    try:
        with chemin_csv.open("w", encoding="utf-8", newline="") as fh, \
                ThreadPoolExecutor(max_workers=workers) as pool:
            writer = csv.DictWriter(fh, fieldnames=CSV_COLONNES)
            writer.writeheader()

            idx = 0
            for resultats_lot in _par_tranches(pool, travail, lots,
                                                   max(1, taille_tranche // taille_lot)):
                for cle, lignes in resultats_lot:
                    idx += 1
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

                    # Garde-fou : ne pas laisser tourner des heures pour rien.
                    if idx == seuil_sterile and stats["textes_lus"] == 0:
                        raise ExtractionSterile(
                            f"{idx} cles lues, aucun texte trouve (forme de NAME "
                            f"'{forme_nom}'). Lancez --diagnostic pour voir l'erreur "
                            "SAP brute et identifier la bonne forme, puis relancez "
                            "avec --forme-nom."
                        )

                    if idx % 500 == 0 or idx == total:
                        ecoule = time.time() - depart
                        cadence = idx / ecoule if ecoule else 0
                        reste = (total - idx) / cadence if cadence else 0
                        fh.flush()
                        LOG.info("Progression %d/%d (%.0f cles/s, reste ~%s) — "
                                 "lus %d, absents %d, lignes %d",
                                 idx, total, cadence, _duree_lisible(reste),
                                 stats["textes_lus"], stats["absents"],
                                 stats["lignes_ecrites"])
                        if progression is not None:
                            progression(idx, total, stats)
                if doit_arreter is not None and doit_arreter():
                    stats["interrompu"] = 1
                    LOG.warning("Arret demande : %d/%d textes traites, CSV partiel conserve.",
                                idx, total)
                    break
    finally:
        _fermer_connexions_threads()
    return stats


def _duree_lisible(secondes: float) -> str:
    secondes = int(secondes)
    if secondes < 60:
        return f"{secondes}s"
    if secondes < 3600:
        return f"{secondes // 60}min"
    return f"{secondes // 3600}h{(secondes % 3600) // 60:02d}"


def cles_deja_chargees() -> set[tuple[str, str, str]]:
    """Cles (tdid, tdspras, tdname) deja presentes dans la table cible."""
    with closing(connexion_pg()) as cnx, cnx.cursor() as cur:
        cur.execute(f"SELECT DISTINCT tdid, tdspras, tdname FROM {TABLE_CIBLE}")
        return {(r[0], r[1], r[2]) for r in cur.fetchall()}


# ---------------------------------------------------------------------------
# Phase 3 - chargement
# ---------------------------------------------------------------------------
def charger(chemin_csv: Path, purger: bool, remplacer_lot: bool = True) -> int:
    """COPY en staging temporaire puis chargement, en une transaction.

    remplacer_lot=True : les lignes des couples (tdobject, tdid, tdspras) presents
    dans le CSV sont d'abord supprimees — run complet rejouable sans doublon.
    remplacer_lot=False : simple ajout, utilise en mode --reprise ou le CSV ne
    contient par construction que des cles absentes de la cible.
    """
    colonnes = ", ".join(CSV_COLONNES)
    with closing(connexion_pg()) as cnx, cnx.cursor() as cur:
        if purger:
            cur.execute(f"TRUNCATE {TABLE_CIBLE} RESTART IDENTITY")
            LOG.info("Table %s purgee.", TABLE_CIBLE)

        cur.execute("""
            CREATE TEMP TABLE stg_material_text (
                tdobject TEXT, tdname TEXT, tdid TEXT, tdspras TEXT,
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

        if not purger and remplacer_lot:
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
# Orchestration (partagee par la CLI et l'API sap-extraction)
# ---------------------------------------------------------------------------
class ExtractionInterrompue(RuntimeError):
    """Arret demande pendant la lecture : rien n'a ete charge en base."""


def executer(objet: str = OBJET_DEFAUT, tdids: list[str] | None = None,
             langues: list[str] | None = None, *, purge: bool = False,
             limit: int | None = None, source: str = "auto", workers: int = 8,
             exclure_vides: bool = False, reprise: bool = False, no_load: bool = False,
             forme_nom: str = "stxh", langue_interne: bool = False,
             sortie: Path | None = None, progression=None, doit_arreter=None) -> dict:
    """Inventaire -> lecture RFC_READ_TEXT -> chargement. Retourne un bilan.

    Bilan : {"objet", "cles", "textes_lus", "absents", "lignes", "inserees",
    "csv", "duree_s"}. Leve ExtractionInterrompue si doit_arreter() a coupe
    la lecture (le CSV partiel n'est PAS charge : un lot incomplet effacerait
    les textes deja presents pour les memes tdid/langue).
    """
    objet = objet.strip().upper()
    depart = time.time()
    preparer_schema()

    if source == "auto":
        source = "stxh" if stxh_utilisable() else "rfc"
        LOG.info("Source d'inventaire retenue automatiquement : %s", source)

    conn_sap: Connection | None = None
    try:
        if source == "stxh":
            cles = inventaire_depuis_stxh(objet, tdids, langues, limit, exclure_vides=exclure_vides)
        else:
            conn_sap = connexion_sap()
            cles = inventaire_depuis_rfc(conn_sap, objet, tdids, langues, limit)

        repartition = Counter((c["tdid"], c["tdspras"]) for c in cles)
        LOG.info("Inventaire %s : %d cles", objet, len(cles))
        for (tdid, spras), nb in sorted(repartition.items(), key=lambda x: -x[1]):
            LOG.info("    %s / %s : %d", tdid, spras, nb)

        bilan = {"objet": objet, "cles": len(cles), "textes_lus": 0, "absents": 0,
                 "lignes": 0, "inserees": 0, "csv": None, "duree_s": 0.0}
        if not cles:
            LOG.warning("Aucune cle a traiter, arret.")
            return bilan

        if conn_sap is None:
            conn_sap = connexion_sap()
        if not langue_interne:
            _LANGUES_ISO.update(charger_mapping_langues(conn_sap))
            LOG.info("Langues T002 chargees : %d correspondances", len(_LANGUES_ISO))

        if reprise:
            deja = cles_deja_chargees()
            avant = len(cles)
            cles = [c for c in cles if (c["tdid"], c["tdspras"], c["tdname"]) not in deja]
            LOG.info("Reprise : %d cles deja chargees ignorees, %d a traiter.",
                     avant - len(cles), len(cles))
            if not cles:
                LOG.info("Rien a reprendre, tout est deja charge.")
                return bilan
    finally:
        if conn_sap is not None:
            try:
                conn_sap.close()
            except Exception:  # noqa: BLE001
                LOG.debug("Fermeture de la connexion SAP en echec, ignore.")

    repertoire = Path(sortie) if sortie else RACINE / "sorties"
    repertoire.mkdir(parents=True, exist_ok=True)
    horo = datetime.now().strftime("%Y%m%d_%H%M%S")
    chemin = repertoire / f"textes_longs_{objet.lower()}_{horo}.csv"

    stats = extraire(cles, chemin, forme_nom=forme_nom, workers=workers,
                     progression=progression, doit_arreter=doit_arreter)
    bilan.update(textes_lus=stats["textes_lus"], absents=stats["absents"],
                 lignes=stats["lignes_ecrites"], csv=str(chemin))
    LOG.info("CSV produit : %s", chemin)
    LOG.info("Textes lus %d | absents %d | vides %d | lignes %d",
             stats["textes_lus"], stats["absents"], stats["vides"], stats["lignes_ecrites"])
    if stats.get("interrompu"):
        raise ExtractionInterrompue(f"lecture interrompue, CSV partiel : {chemin}")

    if no_load:
        LOG.info("--no-load : chargement ignore.")
    else:
        bilan["inserees"] = charger(chemin, purge, remplacer_lot=not reprise)
        LOG.info("Chargement %s : %d lignes.", TABLE_CIBLE, bilan["inserees"])

    bilan["duree_s"] = round(time.time() - depart, 1)
    LOG.info("Termine en %.1fs.", bilan["duree_s"])
    return bilan


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------
def main() -> int:
    ap = argparse.ArgumentParser(
        description="Extraction 1-shot des textes longs SAP (objet STXH au choix).",
        epilog="Sans argument : prepare le schema, choisit la source, extrait et charge.",
    )
    ap.add_argument("--objet", default=OBJET_DEFAUT,
                    help="Objet de texte SAP (STXH.TDOBJECT) : MATERIAL (defaut), EINA, EINE, ...")
    ap.add_argument("--tdid", default=None,
                    help="Types de texte (STXH.TDID) separes par des virgules "
                         "(defaut : tous ceux de l'objet)")
    ap.add_argument("--langue", default=None,
                    help="Langues SAP separees par des virgules (defaut : toutes)")
    ap.add_argument("--source", choices=("auto", "stxh", "rfc"), default="auto",
                    help="Origine de l'inventaire des cles (defaut : auto, stxh si peuplee sinon rfc)")
    ap.add_argument("--limit", type=int, default=None, help="Plafond de cles, pour les essais")
    ap.add_argument("--dry-run", action="store_true",
                    help="Phase 1 seule : volumetrie, aucun READ_TEXT, aucune ecriture")
    ap.add_argument("--diagnostic", nargs="?", type=int, const=5, default=None,
                    metavar="N",
                    help="Teste N cles (defaut 5) en affichant l'erreur SAP brute "
                         "et les formes de NAME qui fonctionnent, puis s'arrete")
    ap.add_argument("--forme-nom", choices=tuple(FORMES_NOM), default="stxh",
                    help="Forme du parametre NAME envoye a READ_TEXT (defaut : stxh, "
                         "la valeur telle que stockee dans STXH)")
    ap.add_argument("--workers", type=int, default=8,
                    help="Connexions SAP paralleles pour READ_TEXT (defaut : 8)")
    ap.add_argument("--langue-interne", action="store_true",
                    help="Envoie la langue SAP interne ('F') a READ_TEXT au lieu du "
                         "code ISO T002 ('FR'). A n'utiliser que si T002 est illisible.")
    ap.add_argument("--exclure-vides", action="store_true",
                    help="Ecarte les en-tetes STXH annonçant 0 ligne (TDTXTLINES). "
                         "Par defaut tout est lu : ce compteur n'est pas fiable sur PRO "
                         "(2 024 textes a '0 ligne' ont du contenu)")
    ap.add_argument("--reprise", action="store_true",
                    help="Ne traite que les cles absentes de la table cible "
                         "(relance apres interruption)")
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

    tdids = [t.strip().upper() for t in args.tdid.split(",") if t.strip()] if args.tdid else None
    langues = [l.strip().upper() for l in args.langue.split(",")] if args.langue else None
    objet = args.objet.strip().upper()

    # Dry-run / diagnostic : inventaire seul, aucune ecriture en base.
    if args.dry_run or args.diagnostic is not None:
        source = args.source
        if source == "auto":
            source = "stxh" if stxh_utilisable() else "rfc"
        if source == "stxh":
            cles = inventaire_depuis_stxh(objet, tdids, langues, args.limit,
                                          exclure_vides=args.exclure_vides)
            conn_sap = None
        else:
            conn_sap = connexion_sap()
            cles = inventaire_depuis_rfc(conn_sap, objet, tdids, langues, args.limit)
        repartition = Counter((c["tdid"], c["tdspras"]) for c in cles)
        LOG.info("Inventaire %s : %d cles", objet, len(cles))
        for (tdid, spras), nb in sorted(repartition.items(), key=lambda x: -x[1]):
            LOG.info("    %s / %s : %d", tdid, spras, nb)
        if args.dry_run or not cles:
            LOG.info("Dry-run termine — aucune ecriture.")
            return 0
        if conn_sap is None:
            conn_sap = connexion_sap()
        try:
            if not args.langue_interne:
                _LANGUES_ISO.update(charger_mapping_langues(conn_sap))
            diagnostic(conn_sap, cles, args.diagnostic)
        finally:
            conn_sap.close()
        return 0

    try:
        executer(objet, tdids, langues, purge=args.purge, limit=args.limit,
                 source=args.source, workers=args.workers,
                 exclure_vides=args.exclure_vides, reprise=args.reprise,
                 no_load=args.no_load, forme_nom=args.forme_nom,
                 langue_interne=args.langue_interne, sortie=Path(args.sortie))
    except ExtractionSterile as exc:
        LOG.error("Extraction interrompue : %s", exc)
        return 2
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
