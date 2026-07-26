# -*- coding: utf-8 -*-
"""
Worker d'arrière-plan de l'Assistant IA.

Les questions posées à l'assistant sont enregistrées dans ``public.ai_jobs``
(statut 'en_attente') par la route ``POST /api/v1/ai/ask``. Ce module démarre,
dans chaque process applicatif (gunicorn ``-w N``), un thread démon qui :

  1. tente d'acquérir un VERROU CONSULTATIF PostgreSQL global
     (``pg_try_advisory_lock``) — garantit qu'un seul job est traité à la fois
     sur tout le cluster, donc une seule génération Ollama simultanée ;
  2. réclame le plus ancien job en attente (``FOR UPDATE SKIP LOCKED``) ;
  3. exécute le pipeline complet (``api.ai_assistant.process_question``) ;
  4. écrit le résultat dans le job (statut 'termine' ou 'erreur').

Le verrou est porté par la connexion ``conn`` pendant tout le traitement et
libéré à sa fermeture (ou explicitement). Comme une seule génération tourne à la
fois, tout job resté 'en_cours' alors que le verrou est libre est forcément
orphelin (process précédent interrompu) : il est remis en file.
"""

import threading
import time
import logging

from psycopg2.extras import Json

from config.database import get_db_connection
from config.settings import Config

logger = logging.getLogger(__name__)

# Clé arbitraire stable identifiant le verrou « génération IA » côté PostgreSQL.
_ADVISORY_KEY = 778811

_started = False
_start_lock = threading.Lock()


def start_worker(process_fn):
    """
    Démarre (au plus une fois par process) le thread worker d'arrière-plan.
    ``process_fn(utilisateur, question, conversation_id) -> (payload, conv_id)``.
    Renvoie True si le thread a été démarré, False s'il l'était déjà.
    """
    global _started
    with _start_lock:
        if _started:
            return False
        _started = True

    poll = float(getattr(Config, "AI_JOBS_POLL_SECONDS", 1.0) or 1.0)
    thread = threading.Thread(
        target=_loop, args=(process_fn, poll),
        daemon=True, name="ai-job-worker",
    )
    thread.start()
    return True


def _loop(process_fn, poll):
    logger.info("🧵 Worker IA démarré (traitement des jobs en arrière-plan).")
    while True:
        processed = False
        try:
            processed = _tick(process_fn)
        except Exception as e:  # la boucle ne doit jamais mourir
            logger.error(f"⚠️ Worker IA : erreur inattendue dans la boucle : {e}")
        # Si un job vient d'être traité, on enchaîne vite ; sinon on respire.
        time.sleep(0.1 if processed else poll)


def _tick(process_fn):
    """Traite AU PLUS un job. Renvoie True si un job a été traité."""
    with get_db_connection() as conn:
        # 1) Verrou global : si un autre worker traite déjà un job, on repart.
        with conn.cursor() as cur:
            cur.execute("SELECT pg_try_advisory_lock(%s)", (_ADVISORY_KEY,))
            got_lock = cur.fetchone()[0]
        conn.commit()
        if not got_lock:
            return False

        try:
            # 2) On détient le verrou : tout job 'en_cours' est orphelin (le
            #    worker qui le traitait a été interrompu) puisqu'une seule
            #    génération tourne à la fois. On le remet en file d'attente.
            with conn.cursor() as cur:
                cur.execute(
                    "UPDATE public.ai_jobs SET statut = 'en_attente', date_debut = NULL "
                    "WHERE statut = 'en_cours'"
                )
            conn.commit()

            # 3) Réclame le plus ancien job en attente.
            with conn.cursor() as cur:
                cur.execute(
                    """UPDATE public.ai_jobs
                       SET statut = 'en_cours', date_debut = CURRENT_TIMESTAMP
                       WHERE id = (
                           SELECT id FROM public.ai_jobs
                           WHERE statut = 'en_attente'
                           ORDER BY date_creation
                           FOR UPDATE SKIP LOCKED
                           LIMIT 1
                       )
                       RETURNING id, utilisateur, question, conversation_id"""
                )
                job = cur.fetchone()
            conn.commit()

            if not job:
                return False

            job_id, utilisateur, question, conversation_id = job
            logger.info(f"🧠 Worker IA : traitement du job {job_id}.")
            try:
                payload, conv_id = process_fn(utilisateur, question, conversation_id)
                _finish_job(conn, job_id, payload, conv_id)
            except Exception as e:
                logger.error(f"❌ Worker IA : échec du job {job_id} : {e}")
                _fail_job(conn, job_id, str(e))
            return True
        finally:
            # Libération explicite du verrou (la fermeture de conn le ferait aussi).
            try:
                with conn.cursor() as cur:
                    cur.execute("SELECT pg_advisory_unlock(%s)", (_ADVISORY_KEY,))
                conn.commit()
            except Exception:
                pass


def _finish_job(conn, job_id, payload, conv_id):
    """Marque le job 'termine' et y stocke le payload final."""
    if isinstance(payload, dict) and conv_id is not None:
        payload = {**payload, "conversation_id": conv_id}
    id_log = payload.get("id_log") if isinstance(payload, dict) else None
    with conn.cursor() as cur:
        cur.execute(
            """UPDATE public.ai_jobs
               SET statut = 'termine', resultat = %s, conversation_id = %s,
                   id_log = %s, date_fin = CURRENT_TIMESTAMP
               WHERE id = %s""",
            (Json(payload), conv_id, id_log, job_id),
        )
    conn.commit()


def _fail_job(conn, job_id, erreur):
    """Marque le job 'erreur' (échec technique inattendu du pipeline)."""
    with conn.cursor() as cur:
        cur.execute(
            """UPDATE public.ai_jobs
               SET statut = 'erreur', erreur = %s, date_fin = CURRENT_TIMESTAMP
               WHERE id = %s""",
            ((erreur or "")[:1000], job_id),
        )
    conn.commit()
