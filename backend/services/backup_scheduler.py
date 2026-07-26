"""
Planificateur de backups automatiques.
Lance un backup quotidien + nettoyage des anciens fichiers.
Utilise threading pour éviter de bloquer le serveur Flask.
"""
import logging
import threading
import time
from datetime import datetime, timedelta

logger = logging.getLogger(__name__)

_scheduler_running = False
_scheduler_thread = None


def _daily_backup_job():
    """Exécute le backup quotidien + nettoyage"""
    from services.backup_service import run_backup, cleanup_old_backups

    logger.info("Backup quotidien automatique démarré")
    result = run_backup(compress=True)

    if result.get("success"):
        logger.info(f"Backup auto OK: {result['filename']} ({result['size_mb']} MB)")
    else:
        logger.error(f"Backup auto ECHEC: {result.get('error')}")

    cleanup = cleanup_old_backups()
    if cleanup["deleted_count"] > 0:
        logger.info(f"Nettoyage: {cleanup['deleted_count']} ancien(s) backup(s) supprimé(s)")


def _scheduler_loop(hour=2, minute=0):
    """Boucle qui attend l'heure prévue puis lance le backup"""
    global _scheduler_running
    logger.info(f"Scheduler backup démarré (exécution quotidienne à {hour:02d}:{minute:02d})")

    while _scheduler_running:
        now = datetime.now()
        target = now.replace(hour=hour, minute=minute, second=0, microsecond=0)
        if target <= now:
            target += timedelta(days=1)

        wait_seconds = (target - now).total_seconds()
        logger.info(f"Prochain backup dans {wait_seconds / 3600:.1f}h ({target.strftime('%Y-%m-%d %H:%M')})")

        slept = 0
        while slept < wait_seconds and _scheduler_running:
            time.sleep(min(60, wait_seconds - slept))
            slept += 60

        if _scheduler_running:
            try:
                _daily_backup_job()
            except Exception as e:
                logger.error(f"Erreur backup automatique: {e}")


def start_scheduler(hour=2, minute=0):
    """Démarre le scheduler de backup en arrière-plan"""
    global _scheduler_running, _scheduler_thread

    if _scheduler_running:
        logger.info("Scheduler backup déjà actif")
        return

    _scheduler_running = True
    _scheduler_thread = threading.Thread(
        target=_scheduler_loop, args=(hour, minute), daemon=True
    )
    _scheduler_thread.start()
    logger.info(f"Scheduler backup activé (quotidien à {hour:02d}:{minute:02d})")


def stop_scheduler():
    """Arrête le scheduler"""
    global _scheduler_running
    _scheduler_running = False
    logger.info("Scheduler backup arrêté")


def is_running() -> bool:
    return _scheduler_running
