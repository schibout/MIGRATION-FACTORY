#!/usr/bin/env python
# -*- coding: utf-8 -*-

"""
Module ETL pour le chargement des OPERATIONS DE MAINTENANCE (JT TASK).
Sources : raw_data.afvc / afko / crhd (operations d'ordres SAP PM) et raw_data.resb (besoins matiere).
Cibles : clean_data.jt_task, jt_task_resource, maint_material_req_line.

Utilise les fonctions stockees clean_data.alimenter_*() (voir sql/operation/).
Chaque fonction fait un TRUNCATE + INSERT (idempotent).
Ordre : jt_task d'abord (les tables filles filtrent via EXISTS sur jt_task).
"""

import os
import time
import logging
from sqlalchemy import create_engine, event
from dotenv import load_dotenv
import psycopg2
from config.database import get_etl_db_params


def setup_logging():
    """Configuration du logging avec gestion des erreurs de permissions"""
    log_handlers = [logging.StreamHandler()]

    try:
        log_dir = os.path.join(os.path.dirname(__file__), '..', 'logs')
        if not os.path.exists(log_dir):
            os.makedirs(log_dir, exist_ok=True)
        log_file = os.path.join(log_dir, 'etl_operation.log')

        if os.access(log_dir, os.W_OK):
            log_handlers.append(logging.FileHandler(log_file))
        else:
            raise PermissionError(f"Pas de permission d'ecriture dans {log_dir}")

    except (OSError, PermissionError) as e:
        print(f"Impossible d'ecrire dans le repertoire logs: {e}")
        try:
            temp_log_file = '/tmp/etl_operation.log'
            if os.access('/tmp', os.W_OK):
                log_handlers.append(logging.FileHandler(temp_log_file))
                print(f"Utilisation du fichier de log temporaire: {temp_log_file}")
            else:
                raise PermissionError("Pas de permission d'ecriture dans /tmp")
        except (OSError, PermissionError) as e2:
            print(f"Attention: Impossible de creer un fichier de log ({e2}), console uniquement")

    logging.basicConfig(
        level=logging.INFO,
        format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
        handlers=log_handlers,
        force=True
    )


setup_logging()
logger = logging.getLogger(__name__)

load_dotenv()


class OperationETL:
    # Fonctions a appeler, dans l'ordre (jt_task = parent, puis les tables filles)
    STEPS = [
        ("jt_task", "SELECT clean_data.alimenter_jt_task()"),
        ("jt_task_resource", "SELECT clean_data.alimenter_jt_task_resource()"),
        ("maint_material_req_line", "SELECT clean_data.alimenter_maint_material_req_line()"),
    ]

    def __init__(self):
        # Identifiants issus de la source UNIQUE (config.database), qui lit les
        # variables DB_* de l'environnement. Auparavant ce bloc resolvait des
        # variables PG_* que docker-compose ne transmet pas au conteneur, d'ou un
        # repli sur "localhost" et l'echec de TOUS les chargements
        # (connection refused sur localhost:5432). Une surcharge PG_* explicite
        # reste honoree pour lancer un module hors conteneur.
        _db = get_etl_db_params()
        self.pg_host = _db['host']
        self.pg_port = _db['port']
        self.pg_database = _db['database']
        self.pg_user = _db['user']
        self.pg_password = _db['password']

        self.postgres_connection_string = (
            f"postgresql://{self.pg_user}:{self.pg_password}@"
            f"{self.pg_host}:{self.pg_port}/{self.pg_database}"
        )
        self.pg_engine = create_engine(self.postgres_connection_string)
        self._setup_postgres_logging()

        self.log_messages = []
        logger.info("Connexion PostgreSQL initialisee")
        self._add_log_message("Connexion PostgreSQL initialisee", "info")

    def _setup_postgres_logging(self):
        @event.listens_for(self.pg_engine, "before_cursor_execute")
        def receive_before_cursor_execute(conn, cursor, statement, parameters, context, executemany):
            if hasattr(cursor.connection, 'set_isolation_level'):
                cursor.connection.set_isolation_level(psycopg2.extensions.ISOLATION_LEVEL_AUTOCOMMIT)

    def _add_log_message(self, message, msg_type="info"):
        self.log_messages.append({
            'time': time.time(),
            'message': message,
            'type': msg_type
        })

    def run_etl_with_psycopg2_logs(self):
        """Execution des fonctions Operations de maintenance avec capture des NOTICE PostgreSQL"""
        start_time = time.time()
        logger.info("Demarrage du processus ETL Operations de maintenance")
        self._add_log_message("Demarrage du processus ETL Operations de maintenance", "info")

        try:
            conn_psycopg2 = psycopg2.connect(
                host=self.pg_host,
                port=self.pg_port,
                database=self.pg_database,
                user=self.pg_user,
                password=self.pg_password
            )

            with conn_psycopg2:
                with conn_psycopg2.cursor() as cursor:
                    for label, sql in self.STEPS:
                        logger.info(f"Appel de la fonction Operation: {sql}")
                        self._add_log_message(f"Alimentation de {label}...", "info")
                        cursor.execute(sql)
                        logger.info(f"{label} alimente avec succes")
                        self._add_log_message(f"✅ {label} alimente avec succes", "success")

                    for notice in conn_psycopg2.notices:
                        notice_text = notice.strip()
                        logger.info(f"PostgreSQL NOTICE: {notice_text}")
                        self._add_log_message(notice_text, "info")
                    conn_psycopg2.notices[:] = []

            conn_psycopg2.close()

            execution_time = time.time() - start_time
            logger.info(f"Processus ETL Operations de maintenance termine en {execution_time:.2f} secondes")
            self._add_log_message(
                f"✅ Processus ETL Operations de maintenance termine avec succes en {execution_time:.2f} secondes",
                "success"
            )

            return {
                "success": True,
                "execution_time_seconds": execution_time,
                "log_messages": self.log_messages
            }

        except Exception as e:
            execution_time = time.time() - start_time
            error_msg = f"Erreur lors du processus ETL Operations de maintenance: {str(e)}"
            logger.error(error_msg)
            self._add_log_message(f"❌ {error_msg}", "error")
            return {
                "success": False,
                "error": str(e),
                "execution_time_seconds": execution_time,
                "log_messages": self.log_messages
            }


def run_etl():
    """Fonction de compatibilite pour l'interface ETL existante"""
    try:
        etl = OperationETL()
        return etl.run_etl_with_psycopg2_logs()
    except Exception as e:
        logger.error(f"Erreur dans le processus ETL Operations de maintenance: {str(e)}")
        return {
            "success": False,
            "error": str(e),
            "log_messages": [{
                'time': time.time(),
                'message': f"❌ Erreur fatale: {str(e)}",
                'type': 'error'
            }]
        }


if __name__ == "__main__":
    try:
        etl = OperationETL()
        result = etl.run_etl_with_psycopg2_logs()

        if result["success"]:
            print("Traitement ETL Operations de maintenance termine avec succes")
            print(f"Temps d'execution: {result['execution_time_seconds']:.2f} secondes")
            exit(0)
        else:
            print(f"Erreur: {result.get('error', 'Une erreur inconnue est survenue')}")
            exit(1)
    except Exception as e:
        print(f"Erreur: {str(e)}")
        exit(1)
