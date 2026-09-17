#!/usr/bin/env python
# -*- coding: utf-8 -*-

"""
Module ETL « Structures de maintenance » : export IFS de la structure PRÉPARÉE
dans l'écran IH02 (clean_data.maintenance_object), jamais de raw_data.

Enchaîne trois traitements, dans cet ordre imposé (chaque étape lit la précédente) :
  1. clean_data.alimenter_equipment_functional() : postes techniques (FUNC_LOC actifs,
     hiérarchie par parent_id, code/désignation de l'écran) -> clean_data.equipment_functional.
  2. clean_data.load_equipment_object_spare('FULL') : nomenclature des postes techniques
     (BOM_ITEM sous FUNC_LOC via v_fl_nomenclature, catégorie L) -> clean_data.equipment_object_spare.
  3. clean_data.load_equipment_spare_structure('FULL') : structure kit -> composants des
     articles de l'étape 2 (BOM_ITEM sous ARTICLE, récursif) -> clean_data.equipment_spare_structure.

Mode FULL uniquement (TRUNCATE + rechargement) : snapshot de la structure. Les équipements
(objets série) ne sont pas couverts par ce module.
"""

import os
import time
import logging
import psycopg2
from dotenv import load_dotenv
from config.database import get_etl_db_params

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
        # Identifiants issus de la source UNIQUE (config.database, variables DB_*
        # du .env), comme les autres modules ETL : aucun repli en dur.
        _db = get_etl_db_params()
        self.pg_host = _db['host']
        self.pg_port = _db['port']
        self.pg_database = _db['database']
        self.pg_user = _db['user']
        self.pg_password = _db['password']
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
        self._add_log("Source : structure IH02 (clean_data.maintenance_object)", "info")

        # Ordre contraint : load_equipment_object_spare lit equipment_functional,
        # load_equipment_spare_structure lit equipment_object_spare.
        etapes = [
            ("SELECT clean_data.alimenter_equipment_functional()",
             "clean_data.alimenter_equipment_functional()"),
            ("CALL clean_data.load_equipment_object_spare('FULL')",
             "clean_data.load_equipment_object_spare('FULL')"),
            ("CALL clean_data.load_equipment_spare_structure('FULL')",
             "clean_data.load_equipment_spare_structure('FULL')"),
        ]

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
                    for sql, libelle in etapes:
                        self._add_log(f"Appel de {libelle}...", "info")
                        logger.info(f"Appel de {libelle}")

                        cursor.execute(sql)

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
