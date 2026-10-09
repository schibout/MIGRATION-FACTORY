#!/usr/bin/env python
# -*- coding: utf-8 -*-

"""
Module ETL Article SAP : catalogue des articles (part_catalog).
Perimetre : articles de raw_data.article_sap existant dans SAP (mara, mandt 700).
Infos     : SAP uniquement (mara, makt, marc, texte long de commande).
Cible     : clean_data.part_catalog.

Alimente d'abord clean_data.article_sap (clean_data.alimenter_article_sap(),
1 ligne par article de ifs_article_maitre), puis
appelle la fonction stockee clean_data.alimenter_part_catalog_sap()
(voir sql/articleSap/alimenter_part_catalog_sap.sql) : TRUNCATE + INSERT (idempotent).
A executer AVANT les modules articles PHL / Composants, qui completent part_catalog.
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
        log_file = os.path.join(log_dir, 'etl_article_sap.log')

        if os.access(log_dir, os.W_OK):
            log_handlers.append(logging.FileHandler(log_file))
        else:
            raise PermissionError(f"Pas de permission d'ecriture dans {log_dir}")

    except (OSError, PermissionError) as e:
        print(f"Impossible d'ecrire dans le repertoire logs: {e}")
        try:
            temp_log_file = '/tmp/etl_article_sap.log'
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


class ArticleSapETL:
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
        """Execution de la fonction de chargement avec capture des NOTICE/WARNING PostgreSQL"""
        start_time = time.time()
        logger.info("Demarrage du processus ETL Article SAP")
        self._add_log_message("Demarrage du processus ETL Article SAP", "info")
        records = 0

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
                    # Fichier article IFS (1 ligne par article du perimetre
                    # ifs_article_maitre, recharge par le module Articles, order 8)
                    self._add_log_message("Alimentation de article_sap...", "info")
                    cursor.execute("SELECT clean_data.alimenter_article_sap()")
                    self._add_log_message(
                        f"✅ article_sap alimentee : {cursor.fetchone()[0] or 0} articles", "success"
                    )

                    sql = "SELECT clean_data.alimenter_part_catalog_sap()"
                    logger.info(f"Appel de la fonction Article SAP: {sql}")
                    self._add_log_message("Alimentation de part_catalog (Article SAP)...", "info")
                    cursor.execute(sql)
                    records = cursor.fetchone()[0] or 0
                    logger.info(f"part_catalog alimentee avec succes ({records} lignes)")

                    # Le WARNING "table vide" doit ressortir en avertissement dans l'ecran
                    for notice in conn_psycopg2.notices:
                        notice_text = notice.strip()
                        logger.info(f"PostgreSQL NOTICE: {notice_text}")
                        msg_type = "warning" if notice_text.upper().startswith("WARNING") else "info"
                        self._add_log_message(notice_text, msg_type)
                    conn_psycopg2.notices[:] = []

                    self._add_log_message(
                        f"✅ part_catalog alimentee avec succes : {records} lignes", "success"
                    )

            conn_psycopg2.close()

            execution_time = time.time() - start_time
            logger.info(f"Processus ETL Article SAP termine en {execution_time:.2f} secondes")
            self._add_log_message(
                f"✅ Processus ETL Article SAP termine avec succes en {execution_time:.2f} secondes",
                "success"
            )

            return {
                "success": True,
                "records_processed": records,
                "execution_time_seconds": execution_time,
                "log_messages": self.log_messages
            }

        except Exception as e:
            execution_time = time.time() - start_time
            error_msg = f"Erreur lors du processus ETL Article SAP: {str(e)}"
            logger.error(error_msg)
            self._add_log_message(f"❌ {error_msg}", "error")
            return {
                "success": False,
                "error": str(e),
                "execution_time_seconds": execution_time,
                "log_messages": self.log_messages
            }


def run_etl():
    """Point d'entree de l'interface ETL (api/etl.py)"""
    try:
        etl = ArticleSapETL()
        return etl.run_etl_with_psycopg2_logs()
    except Exception as e:
        logger.error(f"Erreur dans le processus ETL Article SAP: {str(e)}")
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
        etl = ArticleSapETL()
        result = etl.run_etl_with_psycopg2_logs()

        if result["success"]:
            print("Traitement ETL Article SAP termine avec succes")
            print(f"Temps d'execution: {result['execution_time_seconds']:.2f} secondes")
            exit(0)
        else:
            print(f"Erreur: {result.get('error', 'Une erreur inconnue est survenue')}")
            exit(1)
    except Exception as e:
        print(f"Erreur: {str(e)}")
        exit(1)
