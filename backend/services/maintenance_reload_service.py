# -*- coding: utf-8 -*-
"""
Operations longues du module Maintenance : restauration d'un etat et
rechargement depuis SAP.

Ces traitements durent de quelques secondes (restauration) a plusieurs minutes
(extraction SAP + reconstruction). Ils s'executent donc dans un thread, avec un
etat PERSISTE dans ``public.maintenance_jobs`` — et non dans un dict en memoire :
avec ``gunicorn -w 4``, le worker qui repond au polling n'est pas celui qui a
lance le job.

Deux garde-fous complementaires contre les executions concurrentes :

  * un index unique partiel (``uq_maintenance_jobs_one_active``, migration 027)
    interdit en base la creation d'un 2e job PENDING/RUNNING ;
  * un verrou consultatif PostgreSQL (``pg_advisory_lock``) detenu pendant tout
    le traitement, qui permet en plus de detecter les jobs orphelins (process
    interrompu : job RUNNING alors que le verrou est libre).

Enchainement d'un rechargement (``RELOAD``) :

  1. snapshot automatique AUTO_PRE_RELOAD (l'operation reste annulable) ;
  2. extraction SAP -> raw_data (optionnelle) via le conteneur d'extraction ;
  3. reconstruction de ``clean_data.maintenance_object`` :
       - mode ``merge`` : ``load_maintenance_object_merge()`` — preserve le travail UI,
       - mode ``reset`` : ``load_maintenance_object()`` — ecrase les lignes SAP ;
  4. rafraichissement des tables IFS aval (equipment_functional, object_spare).
"""

import json
import logging
import os
import threading
import time

from psycopg2 import errors as pg_errors

from config.database import get_db_connection
from services import maintenance_snapshot_service as snapshots

logger = logging.getLogger(__name__)

# Cle du verrou consultatif « operation maintenance » (distincte de l'IA : 778811).
_ADVISORY_KEY = 778812

# Delai avant qu'un job PENDING/RUNNING sans verrou soit considere orphelin.
_ORPHAN_GRACE = '2 minutes'

# Tables SAP a re-extraire pour reconstruire l'ecran IH02
# (cf. sources de clean_data.load_maintenance_object).
MAINTENANCE_SAP_TABLES = [
    'IFLOT', 'IFLOS', 'IFLOTX', 'IFLO', 'ILOA', 'ITOB',
    'EQUI', 'EQKT', 'EQUZ', 'CRHD', 'CRTX',
    'MARA', 'MAKT', 'MAST', 'TPST', 'STKO', 'STPO',
]

# Duree maximale d'attente de l'extraction SAP avant abandon du job.
EXTRACTION_TIMEOUT_SECONDS = 3600
EXTRACTION_POLL_SECONDS = 10

# Nombre de snapshots AUTOMATIQUES conserves (les snapshots nommes par
# l'utilisateur ne sont jamais purges). Un snapshot pese ~370 Mo.
AUTO_SNAPSHOT_RETENTION = int(os.environ.get('MAINTENANCE_AUTO_SNAPSHOT_KEEP', '3'))


class JobConflictError(RuntimeError):
    """Une operation maintenance est deja en cours."""


class JobError(RuntimeError):
    """Erreur fonctionnelle (message destine a l'utilisateur)."""


# ---------------------------------------------------------------------------
# Lecture / etat des jobs
# ---------------------------------------------------------------------------

_SELECT_JOB = """
    SELECT id, job_type, params, status, current_step, progress, steps,
           snapshot_id, created_by, created_at, started_at, finished_at,
           error_message
    FROM public.maintenance_jobs
"""


def _job_to_dict(row):
    if row is None:
        return None
    (jid, job_type, params, status, current_step, progress, steps,
     snapshot_id, created_by, created_at, started_at, finished_at,
     error_message) = row
    return {
        'id': jid,
        'job_type': job_type,
        'params': params or {},
        'status': status,
        'current_step': current_step,
        'progress': progress,
        'steps': steps or [],
        'snapshot_id': snapshot_id,
        'created_by': created_by,
        'created_at': created_at.isoformat() if created_at else None,
        'started_at': started_at.isoformat() if started_at else None,
        'finished_at': finished_at.isoformat() if finished_at else None,
        'error_message': error_message,
    }


def get_job(job_id):
    _reap_orphans()
    with get_db_connection() as conn:
        with conn.cursor() as cur:
            cur.execute(_SELECT_JOB + " WHERE id = %s", (job_id,))
            return _job_to_dict(cur.fetchone())


def peek_active_job():
    """
    Existe-t-il un job PENDING/RUNNING ? Lecture MINIMALE (une requete, aucun
    verrou) : appelee a chaque ecriture des ecrans maintenance, elle doit rester
    peu couteuse. Utiliser ``get_active_job()`` pour un etat fiable et nettoye.
    """
    with get_db_connection() as conn:
        with conn.cursor() as cur:
            cur.execute(
                "SELECT 1 FROM public.maintenance_jobs "
                "WHERE status IN ('PENDING', 'RUNNING') LIMIT 1"
            )
            return cur.fetchone() is not None


def get_active_job():
    """
    Job PENDING/RUNNING en cours, ou None.

    Appelee en boucle par la banniere de suivi du frontend : le cas nominal
    (aucune operation) coute une seule requete, le nettoyage des orphelins n'est
    tente que si une ligne active existe reellement.
    """
    if not peek_active_job():
        return None
    _reap_orphans()
    with get_db_connection() as conn:
        with conn.cursor() as cur:
            cur.execute(
                _SELECT_JOB + " WHERE status IN ('PENDING', 'RUNNING') "
                "ORDER BY created_at DESC LIMIT 1"
            )
            return _job_to_dict(cur.fetchone())


def list_jobs(limit=20):
    with get_db_connection() as conn:
        with conn.cursor() as cur:
            cur.execute(_SELECT_JOB + " ORDER BY created_at DESC LIMIT %s", (limit,))
            return [_job_to_dict(r) for r in cur.fetchall()]


def _reap_orphans():
    """
    Marque en ERROR les jobs restes RUNNING alors que plus personne ne detient le
    verrou : leur process a ete interrompu (redemarrage du conteneur, kill...).
    Sans cela, l'index unique partiel bloquerait definitivement toute operation.

    Le delai de grace evite de faucher un job tout juste cree, dont le thread
    n'a pas encore eu le temps de prendre le verrou.
    """
    with get_db_connection() as conn:
        with conn.cursor() as cur:
            cur.execute("SELECT pg_try_advisory_lock(%s)", (_ADVISORY_KEY,))
            got_lock = cur.fetchone()[0]
        conn.commit()
        if not got_lock:
            return  # un traitement est reellement en cours
        try:
            with conn.cursor() as cur:
                cur.execute(
                    """UPDATE public.maintenance_jobs
                       SET status = 'ERROR',
                           finished_at = now(),
                           error_message = COALESCE(error_message,
                               'Operation interrompue (redemarrage du serveur).')
                       WHERE status IN ('PENDING', 'RUNNING')
                         AND COALESCE(started_at, created_at) < now() - %s::interval
                       RETURNING id""",
                    (_ORPHAN_GRACE,),
                )
                reaped = [r[0] for r in cur.fetchall()]
            conn.commit()
            if reaped:
                logger.warning(
                    f"⚠️ Job(s) maintenance orphelin(s) marque(s) en erreur : {reaped}"
                )
        finally:
            with conn.cursor() as cur:
                cur.execute("SELECT pg_advisory_unlock(%s)", (_ADVISORY_KEY,))
            conn.commit()


# ---------------------------------------------------------------------------
# Creation et lancement
# ---------------------------------------------------------------------------

def create_job(job_type, params, user=None):
    """
    Cree un job PENDING. Leve ``JobConflictError`` si une operation maintenance
    est deja en cours (garanti par l'index unique partiel cote base).
    """
    if job_type not in ('SNAPSHOT', 'RESTORE', 'RELOAD'):
        raise JobError(f"Type d'operation invalide : {job_type}")

    _reap_orphans()
    try:
        with get_db_connection() as conn:
            with conn.cursor() as cur:
                cur.execute(
                    """INSERT INTO public.maintenance_jobs
                           (job_type, params, status, current_step, created_by)
                       VALUES (%s, %s::jsonb, 'PENDING', %s, %s)
                       RETURNING id""",
                    (job_type, json.dumps(params or {}), 'En attente de demarrage', user),
                )
                job_id = cur.fetchone()[0]
            conn.commit()
    except pg_errors.UniqueViolation as e:
        raise JobConflictError(
            "Une operation maintenance est deja en cours. "
            "Attendez sa fin avant d'en lancer une autre."
        ) from e

    return get_job(job_id)


def start_job(app, job_id):
    """Lance le traitement du job dans un thread (avec contexte applicatif)."""
    thread = threading.Thread(
        target=_run_with_context, args=(app, job_id),
        daemon=True, name=f"maintenance-job-{job_id}",
    )
    thread.start()
    return thread


def _run_with_context(app, job_id):
    with app.app_context():
        try:
            _execute(job_id)
        except Exception as e:  # filet : le thread ne doit jamais mourir en silence
            logger.error(f"❌ Job maintenance #{job_id} : erreur inattendue : {e}")
            _fail(job_id, str(e))


# ---------------------------------------------------------------------------
# Suivi de progression
# ---------------------------------------------------------------------------

def _step(job_id, label, progress, detail=None):
    """Enregistre l'etape courante et l'ajoute au journal d'execution."""
    entry = {'step': label, 'ts': time.strftime('%Y-%m-%dT%H:%M:%S'), 'detail': detail}
    with get_db_connection() as conn:
        with conn.cursor() as cur:
            cur.execute(
                """UPDATE public.maintenance_jobs
                   SET current_step = %s, progress = %s,
                       steps = steps || %s::jsonb
                   WHERE id = %s""",
                (label, progress, json.dumps([entry]), job_id),
            )
        conn.commit()
    logger.info(f"🔧 Job maintenance #{job_id} — {progress}% — {label}"
                + (f" ({detail})" if detail else ""))


def _fail(job_id, message):
    with get_db_connection() as conn:
        with conn.cursor() as cur:
            cur.execute(
                """UPDATE public.maintenance_jobs
                   SET status = 'ERROR', finished_at = now(), error_message = %s
                   WHERE id = %s AND status <> 'ERROR'""",
                ((message or '')[:2000], job_id),
            )
        conn.commit()


def _finish(job_id):
    with get_db_connection() as conn:
        with conn.cursor() as cur:
            cur.execute(
                """UPDATE public.maintenance_jobs
                   SET status = 'DONE', progress = 100, finished_at = now(),
                       current_step = 'Termine'
                   WHERE id = %s""",
                (job_id,),
            )
        conn.commit()


def _attach_snapshot(job_id, snapshot_id):
    with get_db_connection() as conn:
        with conn.cursor() as cur:
            cur.execute(
                "UPDATE public.maintenance_jobs SET snapshot_id = %s WHERE id = %s",
                (snapshot_id, job_id),
            )
        conn.commit()


# ---------------------------------------------------------------------------
# Execution
# ---------------------------------------------------------------------------

def _execute(job_id):
    """Traite un job de bout en bout, sous verrou consultatif."""
    with get_db_connection() as lock_conn:
        with lock_conn.cursor() as cur:
            cur.execute("SELECT pg_try_advisory_lock(%s)", (_ADVISORY_KEY,))
            if not cur.fetchone()[0]:
                _fail(job_id, "Une autre operation maintenance detient le verrou.")
                return
        lock_conn.commit()

        try:
            with get_db_connection() as conn:
                with conn.cursor() as cur:
                    cur.execute(
                        """UPDATE public.maintenance_jobs
                           SET status = 'RUNNING', started_at = now()
                           WHERE id = %s
                           RETURNING job_type, params, created_by""",
                        (job_id,),
                    )
                    row = cur.fetchone()
                conn.commit()

            if not row:
                logger.error(f"Job maintenance #{job_id} introuvable.")
                return

            job_type, params, user = row
            params = params or {}

            if job_type == 'RESTORE':
                _run_restore(job_id, params, user)
            elif job_type == 'RELOAD':
                _run_reload(job_id, params, user)
            else:
                raise JobError(f"Type d'operation non traite : {job_type}")

            _finish(job_id)
            logger.info(f"✅ Job maintenance #{job_id} ({job_type}) termine.")

            # Chaque operation cree un snapshot de securite (~370 Mo : maintenance_object
            # + les tables raw_data, dont iloa). Sans purge, l'espace disque du serveur
            # partage avec Ollama se remplirait silencieusement.
            try:
                snapshots.cleanup_auto_snapshots(keep=AUTO_SNAPSHOT_RETENTION)
            except Exception as e:
                logger.warning(f"Purge des snapshots automatiques impossible : {e}")

        except Exception as e:
            logger.error(f"❌ Job maintenance #{job_id} en echec : {e}")
            _fail(job_id, str(e))
        finally:
            try:
                with lock_conn.cursor() as cur:
                    cur.execute("SELECT pg_advisory_unlock(%s)", (_ADVISORY_KEY,))
                lock_conn.commit()
            except Exception:
                pass


def _run_restore(job_id, params, user):
    snapshot_id = params.get('snapshot_id')
    if not snapshot_id:
        raise JobError("Aucun etat a restaurer n'a ete precise.")

    _step(job_id, "Restauration de l'etat sauvegarde", 20)
    result = snapshots.restore_snapshot(snapshot_id, user=user, auto_backup=True)
    if result.get('safety_snapshot_id'):
        _attach_snapshot(job_id, result['safety_snapshot_id'])

    total = sum(result.get('restored', {}).values())
    _step(job_id, "Etat restaure", 70, f"{total} lignes restaurees")

    _refresh_downstream(job_id, 80)


def _run_reload(job_id, params, user):
    mode = (params.get('mode') or 'merge').lower()
    if mode not in ('merge', 'reset'):
        raise JobError(f"Mode de rechargement invalide : {mode}")
    with_extraction = bool(params.get('with_extraction', True))

    # 1. Filet de securite
    _step(job_id, "Sauvegarde de l'etat courant", 5)
    label = 'fusion' if mode == 'merge' else 'reinitialisation'
    safety = snapshots.create_snapshot(
        name=f"Avant rechargement SAP ({label})",
        description="Sauvegarde automatique prise avant un rechargement depuis SAP.",
        kind='AUTO_PRE_RELOAD',
        user=user,
    )
    _attach_snapshot(job_id, safety['id'])

    # 2. Extraction SAP -> raw_data
    if with_extraction:
        _run_extraction(job_id, user)
    else:
        _step(job_id, "Extraction SAP ignoree", 55,
              "reconstruction depuis les donnees raw_data existantes")

    # 3. Reconstruction de maintenance_object
    if mode == 'merge':
        _step(job_id, "Reconstruction (fusion, modifications preservees)", 60)
        procedure = "CALL clean_data.load_maintenance_object_merge()"
    else:
        _step(job_id, "Reconstruction (reinitialisation depuis SAP)", 60)
        procedure = "CALL clean_data.load_maintenance_object()"

    with get_db_connection() as conn:
        with conn.cursor() as cur:
            cur.execute(procedure)
        conn.commit()

    _step(job_id, "Reconstruction terminee", 80, _last_etl_message(mode))

    # 4. Tables IFS aval
    _refresh_downstream(job_id, 85)


def _run_extraction(job_id, user):
    """Declenche l'extraction SAP des tables maintenance et attend sa fin."""
    from services.extraction_service import extraction_service

    _step(job_id, "Extraction SAP en cours", 10,
          f"{len(MAINTENANCE_SAP_TABLES)} tables")

    result = extraction_service.start_extraction(
        tables=MAINTENANCE_SAP_TABLES,
        options={'mode': 'standard', 'clean': False},
        user_id=user or 'maintenance-reload',
    )
    extraction_id = result.get('extraction_id')
    if not extraction_id:
        raise JobError("Le conteneur d'extraction SAP n'a pas renvoye d'identifiant de job.")

    deadline = time.time() + EXTRACTION_TIMEOUT_SECONDS
    while True:
        if time.time() > deadline:
            raise JobError(
                f"L'extraction SAP n'est pas terminee apres "
                f"{EXTRACTION_TIMEOUT_SECONDS // 60} minutes ; rechargement abandonne. "
                "Les donnees n'ont pas ete modifiees."
            )
        time.sleep(EXTRACTION_POLL_SECONDS)

        try:
            status_payload = extraction_service.get_extraction_status(extraction_id)
        except Exception as e:
            logger.warning(f"Job #{job_id} : statut extraction indisponible ({e}), on reessaie.")
            continue

        status = (status_payload.get('status') or 'running').lower()
        if status in ('completed', 'success', 'done', 'finished'):
            rows = status_payload.get('rows_extracted') or status_payload.get('rowsExtracted')
            _step(job_id, "Extraction SAP terminee", 55,
                  f"{rows} lignes extraites" if rows else None)
            return
        if status in ('failed', 'error'):
            raise JobError(
                "L'extraction SAP a echoue : "
                f"{status_payload.get('error_message') or 'cause inconnue'}."
            )
        if status in ('stopped', 'cancelled', 'canceled'):
            raise JobError("L'extraction SAP a ete interrompue ; rechargement abandonne.")

        progress = status_payload.get('progress_percentage')
        if progress is not None:
            # L'extraction occupe la plage 10 % -> 55 % de la progression globale.
            _set_progress(job_id, 10 + int(float(progress) * 0.45))


def _set_progress(job_id, progress):
    """Met a jour la seule progression (sans ajouter d'entree au journal)."""
    with get_db_connection() as conn:
        with conn.cursor() as cur:
            cur.execute(
                "UPDATE public.maintenance_jobs SET progress = %s WHERE id = %s",
                (max(0, min(100, progress)), job_id),
            )
        conn.commit()


def _refresh_downstream(job_id, progress):
    """
    Recalcule les tables IFS derivees de maintenance_object :
    equipment_functional, equipment_object_spare et equipment_spare_structure.
    Un echec ici n'invalide pas le rechargement : il est signale mais le job
    reste en succes (les donnees sources sont bien a jour).
    """
    _step(job_id, "Mise a jour des tables IFS derivees", progress)
    try:
        with get_db_connection() as conn:
            with conn.cursor() as cur:
                cur.execute("SELECT clean_data.alimenter_equipment_functional()")
                cur.execute("CALL clean_data.load_equipment_object_spare('FULL')")
                # Ordre contraint : cette procedure lit equipment_object_spare,
                # elle doit donc suivre celle qui l'alimente.
                cur.execute("CALL clean_data.load_equipment_spare_structure('FULL')")
            conn.commit()
        _step(job_id, "Tables IFS derivees a jour", min(99, progress + 10))
    except Exception as e:
        logger.error(f"⚠️ Job #{job_id} : rafraichissement des tables IFS echoue : {e}")
        _step(job_id, "Tables IFS derivees non rafraichies", min(99, progress + 10),
              f"a relancer manuellement : {e}")


def _last_etl_message(mode):
    """Resume de la derniere execution de la procedure de chargement."""
    proc = ('load_maintenance_object_merge' if mode == 'merge'
            else 'load_maintenance_object')
    try:
        with get_db_connection() as conn:
            with conn.cursor() as cur:
                cur.execute(
                    """SELECT message FROM clean_data.etl_log
                       WHERE procedure_name = %s
                       ORDER BY start_ts DESC LIMIT 1""",
                    (proc,),
                )
                row = cur.fetchone()
        return row[0] if row else None
    except Exception:
        return None
