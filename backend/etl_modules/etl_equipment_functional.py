#!/usr/bin/env python
# -*- coding: utf-8 -*-

"""
Module ETL pour le chargement des postes techniques et équipements (EQUIPMENT_FUNCTIONAL).
Appelle la fonction clean_data.alimenter_equipment_functional() qui alimente la table
clean_data.equipment_functional depuis les tables SAP standard
(raw_data.iflot / iflotx / iflos / iloa pour les postes techniques, raw_data.itob
pour les équipements). La table raw_data.ih02_capgemini n'est PAS utilisée.
"""

import os
import time
import logging
import psycopg2
from dotenv import load_dotenv

def setup_logging():
    log_handlers = [logging.StreamHandler()]
    try:
        log_dir = os.path.join(os.path.dirname(__file__), '..', 'logs')
        os.makedirs(log_dir, exist_ok=True)
        log_file = os.path.join(log_dir, 'etl_equipment_functional.log')
        if os.access(log_dir, os.W_OK):
            log_handlers.append(logging.FileHandler(log_file))
    except (OSError, PermissionError):
        pass

    logging.basicConfig(
        level=logging.INFO,
        format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
        handlers=log_handlers,
        force=True
    )

setup_logging()
logger = logging.getLogger(__name__)

load_dotenv()


class EquipmentFunctionalETL:
    def __init__(self):
        self.pg_host = os.environ.get("PG_HOST", os.environ.get("DB_HOST", "10.190.100.58"))
        self.pg_port = os.environ.get("PG_PORT", os.environ.get("DB_PORT", "5432"))
        self.pg_database = os.environ.get("PG_DATABASE", os.environ.get("DB_NAME", "sap_migration_db"))
        self.pg_user = os.environ.get("PG_USER", os.environ.get("DB_USER", "postgres"))
        self.pg_password = os.environ.get("PG_PASSWORD", os.environ.get("DB_PASSWORD", "trimet2025"))
        self.log_messages = []
        logger.info("ETL Equipment Functional initialisé")
        self._add_log("Connexion PostgreSQL initialisée", "info")

    def _add_log(self, message, msg_type="info"):
        self.log_messages.append({
            'time': time.time(),
            'message': message,
            'type': msg_type
        })

    def run_etl(self):
        return self.run_etl_with_psycopg2_logs()

    def run_etl_with_psycopg2_logs(self):
        start_time = time.time()
        start_dt = time.strftime('%Y-%m-%d %H:%M:%S')
        logger.info(f"Démarrage ETL Equipment Functional - {start_dt}")
        self._add_log(f"Démarrage ETL Equipment Functional - {start_dt}", "info")
        self._add_log("Traitement des postes techniques et équipements (iflot/iflotx/iflos/iloa + itob)", "info")

        try:
            conn = psycopg2.connect(
                host=self.pg_host,
                port=self.pg_port,
                database=self.pg_database,
                user=self.pg_user,
                password=self.pg_password
            )

            with conn:
                with conn.cursor() as cursor:
                    self._add_log("Appel de clean_data.alimenter_equipment_functional()...", "info")
                    logger.info("Appel de clean_data.alimenter_equipment_functional()")

                    cursor.execute("SELECT clean_data.alimenter_equipment_functional()")

                    for notice in conn.notices:
                        notice_text = notice.strip()
                        logger.info(f"PostgreSQL: {notice_text}")
                        self._add_log(notice_text, "info")
                    conn.notices[:] = []

            conn.close()

            duration = time.time() - start_time
            end_dt = time.strftime('%Y-%m-%d %H:%M:%S')
            logger.info(f"ETL Equipment Functional terminé - {end_dt} - {duration:.2f}s")
            self._add_log(f"ETL terminé avec succès - {end_dt}", "success")
            self._add_log(f"Durée totale: {duration:.2f} secondes", "info")

            return {
                "success": True,
                "execution_time_seconds": duration,
                "log_messages": self.log_messages
            }

        except Exception as e:
            duration = time.time() - start_time
            error_msg = f"Erreur ETL Equipment Functional: {str(e)}"
            logger.error(error_msg)
            self._add_log(f"ERREUR: {error_msg}", "error")
            return {
                "success": False,
                "error": str(e),
                "execution_time_seconds": duration,
                "log_messages": self.log_messages
            }


def run_etl():
    """Fonction de compatibilité pour l'interface ETL existante"""
    try:
        etl = EquipmentFunctionalETL()
        return etl.run_etl_with_psycopg2_logs()
    except Exception as e:
        logger.error(f"Erreur fatale ETL: {str(e)}")
        return {
            "success": False,
            "error": str(e),
            "log_messages": [{
                'time': time.time(),
                'message': f"Erreur fatale: {str(e)}",
                'type': 'error'
            }]
        }


if __name__ == "__main__":
    result = run_etl()
    if result["success"]:
        print(f"ETL terminé - {result['execution_time_seconds']:.2f}s")
    else:
        print(f"Erreur: {result.get('error')}")
        exit(1)
