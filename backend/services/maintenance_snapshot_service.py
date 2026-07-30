# -*- coding: utf-8 -*-
"""
Snapshots du module Maintenance : sauvegarde / restauration d'un etat de travail.

Un « etat » est une copie physique des tables editees par les ecrans maintenance :

  * ``clean_data.maintenance_object`` — ecran IH02 (postes techniques, equipements,
    articles, nomenclatures) ;
  * les tables ``raw_data`` encore ecrites en direct par les ecrans
    Hierarchie / Equipements / Articles.

Les copies vivent dans le schema ``snapshots`` (une table
``snapshots.s<id>_<schema>_<table>`` par table snapshotee), les metadonnees dans
``public.maintenance_snapshots`` (cf. migrations/027_create_maintenance_snapshots.sql).

Points d'attention :

  * la restauration conserve les ``id`` d'origine — ``parent_id`` et
    ``ref_object_id`` de ``maintenance_object`` sont des id internes. Les FK ont
    ete rendues DEFERRABLE par la migration 027 pour permettre un
    ``INSERT ... SELECT`` unique sans ordonnancement parent/enfant ;
  * les colonnes sont appariees PAR NOM (intersection copie/cible), pour qu'une
    migration ajoutant une colonne n'invalide pas les snapshots anterieurs ;
  * la sequence des cles primaires est repositionnee apres restauration.
"""

import json
import logging

from psycopg2 import sql

from config.database import get_db_connection

logger = logging.getLogger(__name__)

SNAPSHOT_SCHEMA = 'snapshots'

# Tables couvertes par un snapshot maintenance, dans l'ordre de restauration.
#
# Perimetre recentre sur clean_data le 2026-07-30 : l'ecran IH02 est passe sur
# la table unique, et raw_data redevient de la source SAP re-extractible. Ne
# sont conservees de raw_data que equi/eqkt/equz, qui portent encore les saisies
# de l'ecran Equipements et pesent 3 Mo a elles trois.
#
# Retirees (247 Mo, dont iloa 198 Mo a elle seule) : iflot, iflotx, iflos, iloa,
# mara, makt. CONSEQUENCE ASSUMEE : une restauration ne rend plus les saisies
# faites dans les ecrans Maintenance Hierarchie (iflot/iflotx/iloa) et Articles
# (mara/makt), et une extraction SAP devient irreversible depuis l'application
# pour les postes techniques et les articles. Ces ecrans sont consideres en voie
# d'abandon au profit d'IH02.
SNAPSHOT_TABLES = [
    ('clean_data', 'maintenance_object'),          # table applicative principale
    ('clean_data', 'equipment_functional'),        # export IFS : objets fonctionnels
    ('clean_data', 'equipment_object_spare'),      # export IFS : pieces de rechange
    ('clean_data', 'equipment_spare_structure'),   # export IFS : kit -> composants
    ('raw_data', 'equi'),     # equipements
    ('raw_data', 'eqkt'),     # libelles equipements
    ('raw_data', 'equz'),     # periodes equipements
]

# Tables sorties du perimetre le 2026-07-30 : elles ne sont plus copiees, mais
# restent RESTAURABLES si un snapshot anterieur en contient une copie. Sans
# cette liste, un ancien snapshot cesserait silencieusement de les rendre.
LEGACY_SNAPSHOT_TABLES = [
    ('raw_data', 'iflot'),    # postes techniques
    ('raw_data', 'iflotx'),   # libelles postes techniques
    ('raw_data', 'iflos'),    # structure / strno
    ('raw_data', 'iloa'),     # donnees de localisation
    ('raw_data', 'mara'),     # articles
    ('raw_data', 'makt'),     # libelles articles
]

# La creation itere sur SNAPSHOT_TABLES, la restauration sur celle-ci.
RESTORABLE_TABLES = SNAPSHOT_TABLES + LEGACY_SNAPSHOT_TABLES

VALID_KINDS = ('MANUAL', 'AUTO_PRE_RESTORE', 'AUTO_PRE_RELOAD')


class SnapshotError(RuntimeError):
    """Erreur fonctionnelle de snapshot (message destine a l'utilisateur)."""


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def _copy_table_name(snapshot_id, schema, table):
    """Nom de la table de copie : s<id>_<schema>_<table> (schema inclus pour
    eviter toute collision entre clean_data et raw_data)."""
    return f"s{snapshot_id}_{schema}_{table}"


def _table_exists(cursor, schema, table):
    cursor.execute("SELECT to_regclass(%s) IS NOT NULL", (f"{schema}.{table}",))
    return cursor.fetchone()[0]


def _columns_of(cursor, schema, table):
    cursor.execute(
        """SELECT column_name FROM information_schema.columns
           WHERE table_schema = %s AND table_name = %s
           ORDER BY ordinal_position""",
        (schema, table),
    )
    return [r[0] for r in cursor.fetchall()]


def _row_to_dict(row):
    """Ligne public.maintenance_snapshots -> dict expose par l'API."""
    if row is None:
        return None
    (sid, name, description, kind, status, tables, total_rows,
     size_bytes, created_by, created_at, error_message) = row
    return {
        'id': sid,
        'name': name,
        'description': description,
        'kind': kind,
        'status': status,
        'tables': tables or {},
        'total_rows': total_rows or 0,
        'size_bytes': size_bytes,
        'created_by': created_by,
        'created_at': created_at.isoformat() if created_at else None,
        'error_message': error_message,
    }


_SELECT_SNAPSHOT = """
    SELECT id, name, description, kind, status, tables, total_rows,
           size_bytes, created_by, created_at, error_message
    FROM public.maintenance_snapshots
"""


# ---------------------------------------------------------------------------
# Lecture
# ---------------------------------------------------------------------------

def list_snapshots(limit=100):
    """Liste des etats sauvegardes, du plus recent au plus ancien."""
    with get_db_connection() as conn:
        with conn.cursor() as cur:
            cur.execute(_SELECT_SNAPSHOT + " ORDER BY created_at DESC LIMIT %s", (limit,))
            return [_row_to_dict(r) for r in cur.fetchall()]


def get_snapshot(snapshot_id):
    """Un etat sauvegarde, ou None."""
    with get_db_connection() as conn:
        with conn.cursor() as cur:
            cur.execute(_SELECT_SNAPSHOT + " WHERE id = %s", (snapshot_id,))
            return _row_to_dict(cur.fetchone())


# ---------------------------------------------------------------------------
# Creation
# ---------------------------------------------------------------------------

def create_snapshot(name, description=None, kind='MANUAL', user=None):
    """
    Copie l'etat courant des tables maintenance dans le schema ``snapshots``.

    Renvoie le dict du snapshot cree (statut READY). En cas d'echec, le snapshot
    est marque FAILED, les copies partielles sont supprimees, et une
    ``SnapshotError`` est levee.
    """
    if kind not in VALID_KINDS:
        raise SnapshotError(f"Type de snapshot invalide : {kind}")
    name = (name or '').strip()
    if not name:
        raise SnapshotError("Le nom de l'etat est obligatoire.")

    with get_db_connection() as conn:
        with conn.cursor() as cur:
            cur.execute(
                """INSERT INTO public.maintenance_snapshots
                       (name, description, kind, status, created_by)
                   VALUES (%s, %s, %s, 'CREATING', %s)
                   RETURNING id""",
                (name[:200], description, kind, user),
            )
            snapshot_id = cur.fetchone()[0]
        conn.commit()

        try:
            copied = {}
            total = 0
            with conn.cursor() as cur:
                cur.execute(
                    sql.SQL("CREATE SCHEMA IF NOT EXISTS {}").format(
                        sql.Identifier(SNAPSHOT_SCHEMA))
                )
                for schema, table in SNAPSHOT_TABLES:
                    if not _table_exists(cur, schema, table):
                        logger.warning(
                            f"Snapshot {snapshot_id} : table {schema}.{table} absente, ignoree."
                        )
                        continue
                    copy_name = _copy_table_name(snapshot_id, schema, table)
                    cur.execute(
                        sql.SQL("CREATE TABLE {}.{} AS SELECT * FROM {}.{}").format(
                            sql.Identifier(SNAPSHOT_SCHEMA), sql.Identifier(copy_name),
                            sql.Identifier(schema), sql.Identifier(table),
                        )
                    )
                    nb = cur.rowcount if cur.rowcount is not None and cur.rowcount >= 0 else 0
                    copied[f"{schema}.{table}"] = nb
                    total += nb

                cur.execute(
                    """SELECT COALESCE(SUM(pg_total_relation_size(c.oid)), 0)
                       FROM pg_class c
                       JOIN pg_namespace n ON n.oid = c.relnamespace
                       WHERE n.nspname = %s AND c.relname LIKE %s""",
                    (SNAPSHOT_SCHEMA, f"s{snapshot_id}\\_%"),
                )
                size_bytes = cur.fetchone()[0]

                cur.execute(
                    """UPDATE public.maintenance_snapshots
                       SET status = 'READY', tables = %s::jsonb,
                           total_rows = %s, size_bytes = %s
                       WHERE id = %s""",
                    (json.dumps(copied), total, size_bytes, snapshot_id),
                )
            conn.commit()
            logger.info(
                f"📸 Snapshot maintenance #{snapshot_id} « {name} » cree "
                f"({total} lignes, {len(copied)} tables)."
            )
        except Exception as e:
            conn.rollback()
            logger.error(f"❌ Snapshot maintenance #{snapshot_id} echoue : {e}")
            _drop_copies(conn, snapshot_id)
            with conn.cursor() as cur:
                cur.execute(
                    """UPDATE public.maintenance_snapshots
                       SET status = 'FAILED', error_message = %s WHERE id = %s""",
                    (str(e)[:1000], snapshot_id),
                )
            conn.commit()
            raise SnapshotError(f"Echec de la creation de l'etat : {e}") from e

    return get_snapshot(snapshot_id)


# ---------------------------------------------------------------------------
# Restauration
# ---------------------------------------------------------------------------

def restore_snapshot(snapshot_id, user=None, auto_backup=True):
    """
    Remet les tables maintenance dans l'etat du snapshot.

    Prend d'abord (sauf ``auto_backup=False``) un snapshot AUTO_PRE_RESTORE de
    l'etat courant : une restauration reste donc toujours annulable.

    La restauration elle-meme est atomique (une seule transaction, contraintes
    differees). Renvoie un dict {restored: {...}, safety_snapshot_id: int|None}.
    """
    snap = get_snapshot(snapshot_id)
    if not snap:
        raise SnapshotError(f"Etat #{snapshot_id} introuvable.")
    if snap['status'] != 'READY':
        raise SnapshotError(
            f"L'etat « {snap['name']} » n'est pas exploitable (statut {snap['status']})."
        )

    safety_id = None
    if auto_backup:
        safety = create_snapshot(
            name=f"Avant restauration de « {snap['name']} »",
            description=f"Sauvegarde automatique prise avant la restauration de l'etat #{snapshot_id}.",
            kind='AUTO_PRE_RESTORE',
            user=user,
        )
        safety_id = safety['id']

    restored = {}
    with get_db_connection() as conn:
        try:
            with conn.cursor() as cur:
                cur.execute("SET CONSTRAINTS ALL DEFERRED")

                targets = []
                # RESTORABLE_TABLES et non SNAPSHOT_TABLES : un snapshot pris
                # avant le recentrage du perimetre contient des copies de tables
                # qu'on ne sauvegarde plus, et il doit continuer a les rendre.
                for schema, table in RESTORABLE_TABLES:
                    copy_name = _copy_table_name(snapshot_id, schema, table)
                    if not _table_exists(cur, SNAPSHOT_SCHEMA, copy_name):
                        continue
                    if not _table_exists(cur, schema, table):
                        logger.warning(
                            f"Restauration #{snapshot_id} : table cible {schema}.{table} "
                            "absente, ignoree."
                        )
                        continue
                    # Appariement PAR NOM : une colonne ajoutee apres le snapshot
                    # n'empeche pas la restauration (elle reprend sa valeur par defaut).
                    copy_cols = _columns_of(cur, SNAPSHOT_SCHEMA, copy_name)
                    target_cols = set(_columns_of(cur, schema, table))
                    cols = [c for c in copy_cols if c in target_cols]
                    if not cols:
                        continue
                    targets.append((schema, table, copy_name, cols))

                # Purge complete d'abord, insertion ensuite : evite les conflits
                # de FK entre tables restaurees.
                for schema, table, _copy_name, _cols in targets:
                    cur.execute(
                        sql.SQL("DELETE FROM {}.{}").format(
                            sql.Identifier(schema), sql.Identifier(table))
                    )

                for schema, table, copy_name, cols in targets:
                    col_ids = sql.SQL(', ').join(sql.Identifier(c) for c in cols)
                    cur.execute(
                        sql.SQL("INSERT INTO {}.{} ({}) SELECT {} FROM {}.{}").format(
                            sql.Identifier(schema), sql.Identifier(table), col_ids,
                            col_ids,
                            sql.Identifier(SNAPSHOT_SCHEMA), sql.Identifier(copy_name),
                        )
                    )
                    restored[f"{schema}.{table}"] = cur.rowcount

                    # Repositionne la sequence si la table en a une (id conserves).
                    _resync_sequence(cur, schema, table, cols)

            conn.commit()
        except Exception as e:
            conn.rollback()
            logger.error(f"❌ Restauration de l'etat #{snapshot_id} echouee : {e}")
            raise SnapshotError(f"Echec de la restauration : {e}") from e

    logger.info(
        f"♻️ Etat #{snapshot_id} « {snap['name']} » restaure "
        f"({sum(restored.values())} lignes)."
    )
    return {'restored': restored, 'safety_snapshot_id': safety_id}


def _resync_sequence(cursor, schema, table, cols):
    """Recale la sequence de la PK apres reinsertion d'id explicites."""
    for col in cols:
        cursor.execute(
            "SELECT pg_get_serial_sequence(%s, %s)", (f"{schema}.{table}", col)
        )
        seq = cursor.fetchone()[0]
        if not seq:
            continue
        cursor.execute(
            sql.SQL("SELECT setval(%s, COALESCE((SELECT MAX({}) FROM {}.{}), 0) + 1, false)")
            .format(sql.Identifier(col), sql.Identifier(schema), sql.Identifier(table)),
            (seq,),
        )


# ---------------------------------------------------------------------------
# Suppression / menage
# ---------------------------------------------------------------------------

def _drop_copies(conn, snapshot_id):
    """Supprime les tables de copie d'un snapshot (best effort)."""
    with conn.cursor() as cur:
        cur.execute(
            """SELECT c.relname FROM pg_class c
               JOIN pg_namespace n ON n.oid = c.relnamespace
               WHERE n.nspname = %s AND c.relname LIKE %s""",
            (SNAPSHOT_SCHEMA, f"s{snapshot_id}\\_%"),
        )
        names = [r[0] for r in cur.fetchall()]
        for name in names:
            cur.execute(
                sql.SQL("DROP TABLE IF EXISTS {}.{}").format(
                    sql.Identifier(SNAPSHOT_SCHEMA), sql.Identifier(name))
            )
    return len(names)


def delete_snapshot(snapshot_id):
    """Supprime un etat sauvegarde et ses copies."""
    with get_db_connection() as conn:
        with conn.cursor() as cur:
            cur.execute(
                "SELECT 1 FROM public.maintenance_jobs "
                "WHERE snapshot_id = %s AND status IN ('PENDING', 'RUNNING')",
                (snapshot_id,),
            )
            if cur.fetchone():
                raise SnapshotError(
                    "Cet etat est utilise par une operation en cours ; "
                    "reessayez une fois l'operation terminee."
                )
        _drop_copies(conn, snapshot_id)
        with conn.cursor() as cur:
            cur.execute(
                "DELETE FROM public.maintenance_snapshots WHERE id = %s", (snapshot_id,)
            )
            deleted = cur.rowcount
        conn.commit()
    if not deleted:
        raise SnapshotError(f"Etat #{snapshot_id} introuvable.")
    logger.info(f"🗑️ Etat #{snapshot_id} supprime.")
    return True


def cleanup_auto_snapshots(keep=5):
    """
    Ne conserve que les ``keep`` snapshots automatiques les plus recents.
    Les snapshots MANUAL ne sont jamais supprimes automatiquement.
    Renvoie le nombre de snapshots supprimes.
    """
    with get_db_connection() as conn:
        with conn.cursor() as cur:
            cur.execute(
                """SELECT id FROM public.maintenance_snapshots
                   WHERE kind IN ('AUTO_PRE_RESTORE', 'AUTO_PRE_RELOAD')
                     AND id NOT IN (
                         SELECT snapshot_id FROM public.maintenance_jobs
                         WHERE snapshot_id IS NOT NULL
                           AND status IN ('PENDING', 'RUNNING')
                     )
                   ORDER BY created_at DESC
                   OFFSET %s""",
                (keep,),
            )
            stale = [r[0] for r in cur.fetchall()]

        for snapshot_id in stale:
            _drop_copies(conn, snapshot_id)
            with conn.cursor() as cur:
                cur.execute(
                    "DELETE FROM public.maintenance_snapshots WHERE id = %s", (snapshot_id,)
                )
        conn.commit()

    if stale:
        logger.info(f"🧹 {len(stale)} snapshot(s) automatique(s) purge(s).")
    return len(stale)
