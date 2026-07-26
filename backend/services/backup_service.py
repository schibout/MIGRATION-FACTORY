"""
Service de backup automatique de la base PostgreSQL.
Gère les exports pg_dump, l'archivage et la rétention.
"""
import os
import subprocess
import logging
import gzip
import shutil
from datetime import datetime, timedelta
from pathlib import Path
from threading import Thread

logger = logging.getLogger(__name__)

BACKUP_DIR = os.getenv("BACKUP_DIR", "/backups")
BACKUP_RETENTION_DAYS = int(os.getenv("BACKUP_RETENTION_DAYS", "30"))

DB_HOST = os.getenv("DB_HOST", "10.190.100.58")
DB_PORT = os.getenv("DB_PORT", "5432")
DB_NAME = os.getenv("DB_NAME", "sap_migration_db")
DB_USER = os.getenv("DB_USER", "postgres")
DB_PASSWORD = os.getenv("DB_PASSWORD", "trimet2025")


def _ensure_backup_dir():
    Path(BACKUP_DIR).mkdir(parents=True, exist_ok=True)


def run_backup(schemas=None, compress=True) -> dict:
    """
    Lance un pg_dump et retourne le résultat.
    schemas: liste de schémas à sauvegarder (None = base complète)
    """
    _ensure_backup_dir()
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    label = "_".join(schemas) if schemas else "full"
    filename = f"{DB_NAME}_{label}_{timestamp}.dump"
    filepath = os.path.join(BACKUP_DIR, filename)

    env = os.environ.copy()
    env["PGPASSWORD"] = DB_PASSWORD

    cmd = [
        "pg_dump",
        "-h", DB_HOST,
        "-p", DB_PORT,
        "-U", DB_USER,
        "-F", "c",
        "-b",
        "-v",
    ]
    if schemas:
        for s in schemas:
            cmd.extend(["-n", s])
    cmd.extend(["-f", filepath, DB_NAME])

    logger.info(f"Backup démarré: {filename}")
    start = datetime.now()

    try:
        result = subprocess.run(
            cmd, env=env, capture_output=True, text=True, timeout=1800
        )
        duration = (datetime.now() - start).total_seconds()

        if result.returncode != 0:
            logger.error(f"pg_dump échoué: {result.stderr}")
            return {
                "success": False,
                "error": result.stderr[:500],
                "duration_seconds": duration,
            }

        file_size = os.path.getsize(filepath)
        final_path = filepath

        if compress:
            gz_path = filepath + ".gz"
            with open(filepath, "rb") as f_in, gzip.open(gz_path, "wb") as f_out:
                shutil.copyfileobj(f_in, f_out)
            os.remove(filepath)
            final_path = gz_path
            file_size = os.path.getsize(gz_path)
            filename = filename + ".gz"

        logger.info(f"Backup terminé: {filename} ({file_size / 1024 / 1024:.1f} MB, {duration:.0f}s)")

        return {
            "success": True,
            "filename": filename,
            "filepath": final_path,
            "size_bytes": file_size,
            "size_mb": round(file_size / 1024 / 1024, 2),
            "duration_seconds": round(duration, 1),
            "timestamp": timestamp,
            "schemas": schemas or ["all"],
            "compressed": compress,
        }

    except subprocess.TimeoutExpired:
        logger.error("pg_dump timeout (30 min)")
        return {"success": False, "error": "Timeout après 30 minutes"}
    except FileNotFoundError:
        logger.error("pg_dump introuvable dans le PATH")
        return {"success": False, "error": "pg_dump non trouvé - vérifier l'installation de PostgreSQL client"}


def run_backup_async(schemas=None, compress=True):
    """Lance le backup dans un thread séparé"""
    thread = Thread(target=run_backup, args=(schemas, compress), daemon=True)
    thread.start()
    return {"success": True, "message": "Backup lancé en arrière-plan"}


def list_backups() -> list:
    """Liste les fichiers de backup existants"""
    _ensure_backup_dir()
    backups = []
    for f in sorted(Path(BACKUP_DIR).iterdir(), key=lambda p: p.stat().st_mtime, reverse=True):
        if f.suffix in (".dump", ".gz") or f.name.endswith(".dump.gz"):
            stat = f.stat()
            backups.append({
                "filename": f.name,
                "size_bytes": stat.st_size,
                "size_mb": round(stat.st_size / 1024 / 1024, 2),
                "created_at": datetime.fromtimestamp(stat.st_mtime).isoformat(),
                "age_days": (datetime.now() - datetime.fromtimestamp(stat.st_mtime)).days,
            })
    return backups


def delete_backup(filename: str) -> dict:
    """Supprime un backup spécifique"""
    filepath = os.path.join(BACKUP_DIR, os.path.basename(filename))
    if not os.path.exists(filepath):
        return {"success": False, "error": "Fichier non trouvé"}
    os.remove(filepath)
    logger.info(f"Backup supprimé: {filename}")
    return {"success": True, "message": f"Backup {filename} supprimé"}


def cleanup_old_backups(retention_days=None) -> dict:
    """Supprime les backups plus anciens que retention_days"""
    days = retention_days or BACKUP_RETENTION_DAYS
    cutoff = datetime.now() - timedelta(days=days)
    deleted = []

    for f in Path(BACKUP_DIR).iterdir():
        if f.suffix in (".dump", ".gz") or f.name.endswith(".dump.gz"):
            if datetime.fromtimestamp(f.stat().st_mtime) < cutoff:
                f.unlink()
                deleted.append(f.name)
                logger.info(f"Ancien backup supprimé: {f.name}")

    return {
        "success": True,
        "deleted_count": len(deleted),
        "deleted_files": deleted,
        "retention_days": days,
    }


def restore_backup(filename: str, target_schemas=None) -> dict:
    """
    Restaure un backup (pg_restore).
    ATTENTION : opération destructive.
    """
    filepath = os.path.join(BACKUP_DIR, os.path.basename(filename))
    if not os.path.exists(filepath):
        return {"success": False, "error": "Fichier non trouvé"}

    restore_file = filepath
    if filepath.endswith(".gz"):
        restore_file = filepath[:-3]
        with gzip.open(filepath, "rb") as f_in, open(restore_file, "wb") as f_out:
            shutil.copyfileobj(f_in, f_out)

    env = os.environ.copy()
    env["PGPASSWORD"] = DB_PASSWORD

    cmd = [
        "pg_restore",
        "-h", DB_HOST,
        "-p", DB_PORT,
        "-U", DB_USER,
        "-d", DB_NAME,
        "--clean",
        "--if-exists",
        "-v",
    ]
    if target_schemas:
        for s in target_schemas:
            cmd.extend(["-n", s])
    cmd.append(restore_file)

    logger.info(f"Restauration démarrée: {filename}")
    start = datetime.now()

    try:
        result = subprocess.run(
            cmd, env=env, capture_output=True, text=True, timeout=3600
        )
        duration = (datetime.now() - start).total_seconds()

        if restore_file != filepath:
            os.remove(restore_file)

        if result.returncode != 0 and "ERROR" in result.stderr:
            logger.error(f"pg_restore erreurs: {result.stderr[:500]}")
            return {
                "success": False,
                "error": result.stderr[:500],
                "duration_seconds": round(duration, 1),
            }

        logger.info(f"Restauration terminée: {filename} ({duration:.0f}s)")
        return {
            "success": True,
            "message": f"Restauration de {filename} terminée",
            "duration_seconds": round(duration, 1),
        }

    except subprocess.TimeoutExpired:
        return {"success": False, "error": "Timeout après 60 minutes"}
    except FileNotFoundError:
        return {"success": False, "error": "pg_restore non trouvé"}
