#!/usr/bin/env python
# -*- coding: utf-8 -*-

"""
Module ETL pour le chargement des données clients depuis le fichier (raw_data.file_customer).

Appelle, dans l'ordre, les procédures stockées clean_data.sp_*_from_file_customer
qui alimentent les mêmes tables clean_data que les modules `customer` (SAP) et
`customer_phl`. Le module est une SOURCE ALTERNATIVE : chaque procédure fait
TRUNCATE + INSERT, on lance donc ce module seul.

À l'image de etl_customer.py / etl_phl_customer.py : même interface run_etl(),
même capture des NOTICE PostgreSQL, même structure de log_messages pour l'API.
La sous-procédure sp_insert_customer_address_type_single_file n'est PAS appelée
directement (elle l'est par l'orchestrateur sp_insert_customer_address_type_from_file_customer).
"""

import os
import time
import logging
from sqlalchemy import create_engine, text, event
from dotenv import load_dotenv
import psycopg2
from config.database import get_etl_db_params


# Configuration du logging
def setup_logging():
    """Configuration du logging avec gestion des erreurs de permissions"""
    log_handlers = [logging.StreamHandler()]  # Toujours inclure la console

    try:
        log_dir = os.path.join(os.path.dirname(__file__), '..', 'logs')
        if not os.path.exists(log_dir):
            os.makedirs(log_dir, exist_ok=True)
        log_file = os.path.join(log_dir, 'etl_file_customer.log')

        if os.access(log_dir, os.W_OK):
            log_handlers.append(logging.FileHandler(log_file))
        else:
            raise PermissionError(f"Pas de permission d'écriture dans {log_dir}")

    except (OSError, PermissionError) as e:
        print(f"Impossible d'écrire dans le répertoire logs: {e}")
        try:
            temp_log_file = '/tmp/etl_file_customer.log'
            if os.access('/tmp', os.W_OK):
                log_handlers.append(logging.FileHandler(temp_log_file))
                print(f"Utilisation du fichier de log temporaire: {temp_log_file}")
            else:
                raise PermissionError("Pas de permission d'écriture dans /tmp")
        except (OSError, PermissionError) as e2:
            print(f"Attention: Impossible de créer un fichier de log ({e2}), utilisation de la console uniquement")

    logging.basicConfig(
        level=logging.INFO,
        format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
        handlers=log_handlers,
        force=True
    )


setup_logging()
logger = logging.getLogger(__name__)

# Chargement des variables d'environnement
load_dotenv()


# Liste ordonnée des étapes ETL (ordre identique à sql/customerFile/compile.sh).
# Chaque entrée : (appel SQL CALL, emoji, libellé fonctionnel).
# NB : sp_insert_customer_address_type_single_file est volontairement absente
# (appelée en interne par l'orchestrateur). sp_update_customer_id_cascade_file
# est également absente : elle ne sert qu'à propager un changement de
# customer_id, or ce module n'en change plus aucun.
#
# PAS DE RENUMÉROTATION SUR CE MODULE. Le fichier raw_data.file_customer est le
# référentiel et porte déjà le numéro de compte IFS cible
# (« Nouveau n° de compte IFS » -> nouveau_compte_ifs, repli num_corrige puis
# kunnr, cf. clean_data.v_customer_source). Appeler
# sp_renumber_all_customer_ids_file(700000) écrasait ces identifiants métier par
# une numérotation séquentielle 700000+ et faisait perdre le travail de
# renumérotation déjà fait dans le fichier. La procédure reste compilée
# (sql/customerFile/) mais n'est plus appelée par le pipeline.
# Les modules customer (SAP) et customer_phl gardent la leur : eux n'ont pas de
# numéro IFS en source.
ETL_STEPS = [
    ("clean_data.sp_insert_customer_info_from_file_customer()", "📝", "informations clients"),
    ("clean_data.sp_insert_customer_info_cfv_from_file_customer()", "🧩", "champs personnalisés (CFV) clients"),
    ("clean_data.sp_insert_customer_info_address_from_file_customer()", "🏠", "adresses clients"),
    ("clean_data.sp_insert_customer_address_type_from_file_customer()", "🏷️", "types d'adresses clients"),
    ("clean_data.sp_insert_cus_comm_method_from_file_customer()", "📞", "méthodes de communication"),
    ("clean_data.sp_insert_customer_tax_info_from_file_customer()", "💰", "informations fiscales"),
    ("clean_data.sp_insert_customer_delivery_tax_info_from_file_customer()", "🚚", "informations fiscales de livraison"),
    ("clean_data.sp_insert_customer_delivery_fee_code_from_file_customer()", "💵", "codes de frais de livraison"),
    ("clean_data.sp_insert_customer_document_tax_info_from_file_customer()", "📄", "informations fiscales document"),
    ("clean_data.sp_insert_customer_tax_free_tax_code_from_file_customer()", "🆓", "codes fiscaux exonérés"),
    ("clean_data.sp_insert_customer_addr_tax_number_from_file_customer()", "🔢", "numéros de taxe d'adresse"),
    ("clean_data.sp_insert_customer_del_tax_exempt_from_file_customer()", "📋", "exemptions fiscales de livraison"),
    ("clean_data.sp_insert_cus_ident_invoice_info_from_file_customer()", "🧾", "informations de facturation"),
    ("clean_data.sp_insert_cus_identity_pay_info_from_file_customer()", "💳", "informations de paiement"),
    ("clean_data.sp_insert_cus_paym_way_per_ident_from_file_customer()", "💳", "méthodes de paiement par client"),
    ("clean_data.sp_insert_cus_payment_address_from_file_customer()", "🏦", "adresses de paiement"),
    ("clean_data.sp_insert_payment_way_per_identity_from_file_customer()", "💳", "méthodes de paiement par identité"),
    ("clean_data.sp_insert_customer_credit_info_from_file_customer()", "💳", "informations de crédit"),
    ("clean_data.sp_insert_cust_ord_customer_from_file_customer()", "🛒", "informations de commande"),
    ("clean_data.sp_insert_cust_ord_customer_address_from_file_customer()", "📍", "adresses de commande"),
]


class FileCustomerETL:
    def __init__(self):
        # Configuration de la connexion PostgreSQL
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
            f"postgresql://{self.pg_user}:{self.pg_password}"
            f"@{self.pg_host}:{self.pg_port}/{self.pg_database}"
        )

        self.pg_engine = create_engine(self.postgres_connection_string)
        self._setup_postgres_logging()

        # Liste pour capturer les messages de log pour l'API
        self.log_messages = []

        logger.info("Connexion PostgreSQL initialisée")
        self._add_log_message("Connexion PostgreSQL initialisée", "info")

    def _setup_postgres_logging(self):
        """Configure la capture des messages NOTICE de PostgreSQL"""
        @event.listens_for(self.pg_engine, "before_cursor_execute")
        def receive_before_cursor_execute(conn, cursor, statement, parameters, context, executemany):
            if hasattr(cursor.connection, 'set_isolation_level'):
                cursor.connection.set_isolation_level(psycopg2.extensions.ISOLATION_LEVEL_AUTOCOMMIT)

    def _add_log_message(self, message, msg_type="info"):
        """Ajoute un message au journal pour l'API"""
        self.log_messages.append({
            'time': time.time(),
            'message': message,
            'type': msg_type
        })

    def _capture_notices(self, conn_psycopg2):
        """Capture les NOTICE PostgreSQL accumulés et les journalise"""
        for notice in conn_psycopg2.notices:
            notice_text = notice.strip()
            logger.info(f"PostgreSQL NOTICE: {notice_text}")
            self._add_log_message(notice_text, "info")
        conn_psycopg2.notices[:] = []

    def run_etl_with_psycopg2_logs(self):
        """
        Exécute les procédures stockées séquentiellement avec capture des logs PostgreSQL.
        """
        start_time = time.time()
        start_datetime = time.strftime('%Y-%m-%d %H:%M:%S')
        logger.info(f"Démarrage du processus ETL clients FILE - {start_datetime}")
        self._add_log_message(f"🚀 Démarrage du processus ETL clients FILE - {start_datetime}", "info")
        self._add_log_message("📊 Traitement séquentiel des données depuis raw_data.file_customer", "info")

        total_steps = len(ETL_STEPS)

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
                    for index, (proc_call, emoji, label) in enumerate(ETL_STEPS, start=1):
                        proc_name = proc_call.split('(')[0]
                        step_start = time.time()
                        step_datetime = time.strftime('%Y-%m-%d %H:%M:%S')

                        logger.info(f"Étape {index}/{total_steps} - Appel de la procédure {proc_name} - {step_datetime}")
                        self._add_log_message(
                            f"{emoji} Étape {index}/{total_steps} - Insertion des {label} - {step_datetime}",
                            "info"
                        )

                        try:
                            cursor.execute(f"CALL {proc_call}")
                            step_duration = time.time() - step_start
                            logger.info(f"Procédure {proc_name} exécutée avec succès en {step_duration:.2f}s")
                            self._add_log_message(
                                f"✅ {label.capitalize()} traité(es) avec succès en {step_duration:.2f}s",
                                "success"
                            )
                        except Exception as proc_error:
                            error_msg = (
                                f"Erreur à l'étape {index}/{total_steps} "
                                f"({proc_name}): {str(proc_error)}"
                            )
                            logger.error(error_msg)
                            self._add_log_message(f"❌ {error_msg}", "error")
                            conn_psycopg2.rollback()
                            raise

                        # Capturer les notices après chaque procédure
                        self._capture_notices(conn_psycopg2)

            conn_psycopg2.close()

            execution_time = time.time() - start_time
            end_datetime = time.strftime('%Y-%m-%d %H:%M:%S')
            logger.info(
                f"🎉 Processus ETL clients FILE terminé - {end_datetime} - "
                f"Durée totale: {execution_time:.2f} secondes"
            )
            self._add_log_message(f"🎉 Processus ETL clients FILE terminé avec succès - {end_datetime}", "success")
            self._add_log_message(f"⏱️ Durée totale d'exécution: {execution_time:.2f} secondes", "info")
            self._add_log_message(
                f"📊 Toutes les données clients FILE ont été traitées avec succès ({total_steps} étapes)",
                "success"
            )

            return {
                "success": True,
                "execution_time_seconds": execution_time,
                "log_messages": self.log_messages
            }

        except Exception as e:
            execution_time = time.time() - start_time
            error_msg = f"Erreur lors du processus ETL: {str(e)}"
            logger.error(error_msg)
            self._add_log_message(f"❌ {error_msg}", "error")
            return {
                "success": False,
                "error": str(e),
                "execution_time_seconds": execution_time,
                "log_messages": self.log_messages
            }


def run_etl():
    """
    Fonction de compatibilité pour l'interface ETL existante (api/etl.py).
    """
    try:
        etl = FileCustomerETL()
        return etl.run_etl_with_psycopg2_logs()
    except Exception as e:
        logger.error(f"Erreur dans le processus ETL: {str(e)}")
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
        etl = FileCustomerETL()
        result = etl.run_etl_with_psycopg2_logs()

        if result["success"]:
            print("Traitement ETL clients FILE terminé avec succès")
            print(f"Temps d'exécution: {result['execution_time_seconds']:.2f} secondes")
            exit(0)
        else:
            print(f"Erreur: {result.get('error', 'Une erreur inconnue est survenue')}")
            exit(1)
    except Exception as e:
        print(f"Erreur: {str(e)}")
        exit(1)
