#!/usr/bin/env python
# -*- coding: utf-8 -*-

"""
Module ETL simplifié pour le chargement des données clients (CUSTOMER).
Utilise la fonction stockée clean_data.sp_insert_customer_info_from_sap.
"""

import os
import time
import logging
from sqlalchemy import create_engine, text, event
from dotenv import load_dotenv
import psycopg2

# Configuration du logging
def setup_logging():
    """Configuration du logging avec gestion des erreurs de permissions"""
    log_handlers = [logging.StreamHandler()]  # Toujours inclure la console
    
    # Tentative d'ajout du fichier de log
    try:
        # Essayer d'abord dans le répertoire logs du backend
        log_dir = os.path.join(os.path.dirname(__file__), '..', 'logs')
        if not os.path.exists(log_dir):
            os.makedirs(log_dir, exist_ok=True)
        log_file = os.path.join(log_dir, 'etl_customer.log')
        
        # Vérifier les permissions d'écriture avant d'essayer de créer le fichier
        if os.access(log_dir, os.W_OK):
            log_handlers.append(logging.FileHandler(log_file))
        else:
            raise PermissionError(f"Pas de permission d'écriture dans {log_dir}")
            
    except (OSError, PermissionError) as e:
        print(f"Impossible d'écrire dans le répertoire logs: {e}")
        try:
            # Fallback vers /tmp si disponible
            temp_log_file = '/tmp/etl_customer.log'
            if os.access('/tmp', os.W_OK):
                log_handlers.append(logging.FileHandler(temp_log_file))
                print(f"Utilisation du fichier de log temporaire: {temp_log_file}")
            else:
                raise PermissionError("Pas de permission d'écriture dans /tmp")
        except (OSError, PermissionError) as e2:
            # Si aucun fichier n'est possible, continuer sans fichier
            print(f"Attention: Impossible de créer un fichier de log ({e2}), utilisation de la console uniquement")
    
    logging.basicConfig(
        level=logging.INFO,
        format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
        handlers=log_handlers,
        force=True  # Force la reconfiguration
    )

setup_logging()
logger = logging.getLogger(__name__)

# Chargement des variables d'environnement
load_dotenv()

class CustomerETL:
    def __init__(self):
        # Configuration de la connexion PostgreSQL
        self.pg_host = os.environ.get("PG_HOST", "localhost")
        self.pg_port = os.environ.get("PG_PORT", "5432")
        self.pg_database = os.environ.get("PG_DATABASE", "sap_migration_db")
        self.pg_user = os.environ.get("PG_USER", "postgres")
        self.pg_password = os.environ.get("PG_PASSWORD", "trimet2025")
        
        # Construction de la chaîne de connexion PostgreSQL
        self.postgres_connection_string = f"postgresql://{self.pg_user}:{self.pg_password}@{self.pg_host}:{self.pg_port}/{self.pg_database}"
        
        # Initialisation de la connexion
        self.pg_engine = create_engine(self.postgres_connection_string)
        
        # Configurer la capture des NOTICE PostgreSQL
        self._setup_postgres_logging()
        
        # Liste pour capturer les messages de log pour l'API
        self.log_messages = []
        
        logger.info("Connexion PostgreSQL initialisée")
        self._add_log_message("Connexion PostgreSQL initialisée", "info")

    def _setup_postgres_logging(self):
        """Configure la capture des messages NOTICE de PostgreSQL"""
        @event.listens_for(self.pg_engine, "before_cursor_execute")
        def receive_before_cursor_execute(conn, cursor, statement, parameters, context, executemany):
            # Activer l'autocommit pour recevoir les NOTICE immédiatement
            if hasattr(cursor.connection, 'set_isolation_level'):
                cursor.connection.set_isolation_level(psycopg2.extensions.ISOLATION_LEVEL_AUTOCOMMIT)

    def _add_log_message(self, message, msg_type="info"):
        """Ajoute un message au journal pour l'API"""
        self.log_messages.append({
            'time': time.time(),
            'message': message,
            'type': msg_type
        })
    
    def _capture_postgres_notices(self, connection):
        """Capture les NOTICE PostgreSQL et les log"""
        try:
            raw_conn = connection.connection.connection
            for notice in raw_conn.notices:
                notice_text = notice.strip()
                logger.info(f"PostgreSQL NOTICE: {notice_text}")
                self._add_log_message(notice_text, "info")
            raw_conn.notices[:] = []  # Vider les notices après capture
        except Exception as e:
            logger.debug(f"Impossible de capturer les notices: {e}")

    def run_etl_with_psycopg2_logs(self):
        """
        Version avec psycopg2 pour capturer les logs PostgreSQL
        """
        start_time = time.time()
        start_datetime = time.strftime('%Y-%m-%d %H:%M:%S')
        logger.info(f"Démarrage du processus ETL clients - {start_datetime}")
        self._add_log_message(f"🚀 Démarrage du processus ETL clients - {start_datetime}", "info")
        self._add_log_message("📊 Traitement séquentiel des données clients SAP", "info")
        
        # Compteur d'étapes
        step_counter = 0
        total_steps = 19
        
        try:
            # Connexion directe avec psycopg2 pour capturer les NOTICE
            conn_psycopg2 = psycopg2.connect(
                host=self.pg_host,
                port=self.pg_port,
                database=self.pg_database,
                user=self.pg_user,
                password=self.pg_password
            )
            
            with conn_psycopg2:
                with conn_psycopg2.cursor() as cursor:
                    # 1. Insérer les données clients consolidées pour IFS
                    step_counter += 1
                    step_start = time.time()
                    step_datetime = time.strftime('%Y-%m-%d %H:%M:%S')
                    logger.info(f"Étape {step_counter}/{total_steps} - Appel de la procédure clean_data.sp_insert_ifs_customer_ref - {step_datetime}")
                    self._add_log_message(f"🏢 Étape {step_counter}/{total_steps} - Insertion des données clients consolidées IFS depuis SAP - {step_datetime}", "info")
                    try:
                        cursor.execute("CALL clean_data.sp_insert_ifs_customer_ref()")
                        step_duration = time.time() - step_start
                        logger.info(f"Procédure sp_insert_ifs_customer_ref exécutée avec succès en {step_duration:.2f}s")
                        self._add_log_message(f"✅ Données clients IFS insérées avec succès en {step_duration:.2f}s", "success")
                    except Exception as proc_error:
                        error_msg = f"Erreur à l'étape {step_counter}/{total_steps} (sp_insert_ifs_customer_ref): {str(proc_error)}"
                        logger.error(error_msg)
                        self._add_log_message(f"❌ {error_msg}", "error")
                        conn_psycopg2.rollback()
                        raise
                    
                    # Capturer les notices
                    for notice in conn_psycopg2.notices:
                        notice_text = notice.strip()
                        logger.info(f"PostgreSQL NOTICE: {notice_text}")
                        self._add_log_message(notice_text, "info")
                    conn_psycopg2.notices[:] = []
                    
                    # 2. Insérer les informations clients depuis SAP
                    step_counter += 1
                    step_start = time.time()
                    step_datetime = time.strftime('%Y-%m-%d %H:%M:%S')
                    logger.info(f"Étape {step_counter}/{total_steps} - Appel de la procédure clean_data.sp_insert_customer_info_from_sap - {step_datetime}")
                    self._add_log_message(f"📝 Étape {step_counter}/{total_steps} - Insertion des informations clients depuis SAP - {step_datetime}", "info")
                    try:
                        cursor.execute("CALL clean_data.sp_insert_customer_info_from_sap()")
                        step_duration = time.time() - step_start
                        logger.info(f"Procédure sp_insert_customer_info_from_sap exécutée avec succès en {step_duration:.2f}s")
                        self._add_log_message(f"✅ Informations clients insérées avec succès en {step_duration:.2f}s", "success")
                    except Exception as proc_error:
                        error_msg = f"Erreur à l'étape {step_counter}/{total_steps} (sp_insert_customer_info_from_sap): {str(proc_error)}"
                        logger.error(error_msg)
                        self._add_log_message(f"❌ {error_msg}", "error")
                        conn_psycopg2.rollback()
                        raise
                    
                    # Capturer les notices
                    for notice in conn_psycopg2.notices:
                        notice_text = notice.strip()
                        logger.info(f"PostgreSQL NOTICE: {notice_text}")
                        self._add_log_message(notice_text, "info")
                    conn_psycopg2.notices[:] = []
                    
                    # 3. Insérer les adresses clients depuis SAP
                    step_counter += 1
                    step_start = time.time()
                    step_datetime = time.strftime('%Y-%m-%d %H:%M:%S')
                    logger.info(f"Étape {step_counter}/{total_steps} - Appel de la procédure clean_data.sp_insert_customer_address_from_sap - {step_datetime}")
                    self._add_log_message(f"🏠 Étape {step_counter}/{total_steps} - Insertion des adresses clients depuis SAP - {step_datetime}", "info")
                    try:
                        cursor.execute("CALL clean_data.sp_insert_customer_address_from_sap()")
                        step_duration = time.time() - step_start
                        logger.info(f"Procédure sp_insert_customer_address_from_sap exécutée avec succès en {step_duration:.2f}s")
                        self._add_log_message(f"✅ Adresses clients insérées avec succès en {step_duration:.2f}s", "success")
                    except Exception as proc_error:
                        error_msg = f"Erreur à l'étape {step_counter}/{total_steps} (sp_insert_customer_address_from_sap): {str(proc_error)}"
                        logger.error(error_msg)
                        self._add_log_message(f"❌ {error_msg}", "error")
                        conn_psycopg2.rollback()
                        raise
                    
                    # Capturer les notices
                    for notice in conn_psycopg2.notices:
                        notice_text = notice.strip()
                        logger.info(f"PostgreSQL NOTICE: {notice_text}")
                        self._add_log_message(notice_text, "info")
                    conn_psycopg2.notices[:] = []
                    
                    # 4. Insérer les types d'adresses clients depuis SAP
                    step_counter += 1
                    step_start = time.time()
                    step_datetime = time.strftime('%Y-%m-%d %H:%M:%S')
                    logger.info(f"Étape {step_counter}/{total_steps} - Appel de la procédure clean_data.sp_insert_customer_address_type_from_sap - {step_datetime}")
                    self._add_log_message(f"🏷️ Étape {step_counter}/{total_steps} - Insertion des types d'adresses clients depuis SAP - {step_datetime}", "info")
                    try:
                        cursor.execute("CALL clean_data.sp_insert_customer_address_type_from_sap()")
                        step_duration = time.time() - step_start
                        logger.info(f"Procédure sp_insert_customer_address_type_from_sap exécutée avec succès en {step_duration:.2f}s")
                        self._add_log_message(f"✅ Types d'adresses clients insérées avec succès en {step_duration:.2f}s", "success")
                    except Exception as proc_error:
                        error_msg = f"Erreur à l'étape {step_counter}/{total_steps} (sp_insert_customer_address_type_from_sap): {str(proc_error)}"
                        logger.error(error_msg)
                        self._add_log_message(f"❌ {error_msg}", "error")
                        conn_psycopg2.rollback()
                        raise
                    
                    # Capturer les notices
                    for notice in conn_psycopg2.notices:
                        notice_text = notice.strip()
                        logger.info(f"PostgreSQL NOTICE: {notice_text}")
                        self._add_log_message(notice_text, "info")
                    conn_psycopg2.notices[:] = []
                    
                    # 5. Insérer les informations fiscales clients depuis SAP
                    step_counter += 1
                    step_start = time.time()
                    step_datetime = time.strftime('%Y-%m-%d %H:%M:%S')
                    logger.info(f"Étape {step_counter}/{total_steps} - Appel de la procédure clean_data.sp_insert_customer_tax_info_from_sap - {step_datetime}")
                    self._add_log_message(f"💰 Étape {step_counter}/{total_steps} - Insertion des informations fiscales clients depuis SAP - {step_datetime}", "info")
                    try:
                        cursor.execute("CALL clean_data.sp_insert_customer_tax_info_from_sap()")
                        step_duration = time.time() - step_start
                        logger.info(f"Procédure sp_insert_customer_tax_info_from_sap exécutée avec succès en {step_duration:.2f}s")
                        self._add_log_message(f"✅ Informations fiscales clients insérées avec succès en {step_duration:.2f}s", "success")
                    except Exception as proc_error:
                        error_msg = f"Erreur à l'étape {step_counter}/{total_steps} (sp_insert_customer_tax_info_from_sap): {str(proc_error)}"
                        logger.error(error_msg)
                        self._add_log_message(f"❌ {error_msg}", "error")
                        conn_psycopg2.rollback()
                        raise
                    
                    # Capturer les notices
                    for notice in conn_psycopg2.notices:
                        notice_text = notice.strip()
                        logger.info(f"PostgreSQL NOTICE: {notice_text}")
                        self._add_log_message(notice_text, "info")
                    conn_psycopg2.notices[:] = []
                    
                    # 6. Insérer les informations fiscales de livraison clients depuis SAP
                    step_counter += 1
                    step_start = time.time()
                    step_datetime = time.strftime('%Y-%m-%d %H:%M:%S')
                    logger.info(f"Étape {step_counter}/{total_steps} - Appel de la procédure clean_data.sp_insert_customer_delivery_tax_info_from_sap - {step_datetime}")
                    self._add_log_message(f"🚚 Étape {step_counter}/{total_steps} - Insertion des informations fiscales de livraison clients depuis SAP - {step_datetime}", "info")
                    try:
                        cursor.execute("CALL clean_data.sp_insert_customer_delivery_tax_info_from_sap()")
                        step_duration = time.time() - step_start
                        logger.info(f"Procédure sp_insert_customer_delivery_tax_info_from_sap exécutée avec succès en {step_duration:.2f}s")
                        self._add_log_message(f"✅ Informations fiscales de livraison clients insérées avec succès en {step_duration:.2f}s", "success")
                    except Exception as proc_error:
                        error_msg = f"Erreur à l'étape {step_counter}/{total_steps} (sp_insert_customer_delivery_tax_info_from_sap): {str(proc_error)}"
                        logger.error(error_msg)
                        self._add_log_message(f"❌ {error_msg}", "error")
                        conn_psycopg2.rollback()
                        raise
                    
                    # Capturer les notices
                    for notice in conn_psycopg2.notices:
                        notice_text = notice.strip()
                        logger.info(f"PostgreSQL NOTICE: {notice_text}")
                        self._add_log_message(notice_text, "info")
                    conn_psycopg2.notices[:] = []
                    
                    # 7. Insérer les codes fiscaux exonérés clients depuis SAP
                    step_counter += 1
                    step_start = time.time()
                    step_datetime = time.strftime('%Y-%m-%d %H:%M:%S')
                    logger.info(f"Étape {step_counter}/{total_steps} - Appel de la procédure clean_data.sp_insert_customer_tax_free_tax_code_from_sap - {step_datetime}")
                    self._add_log_message(f"🆓 Étape {step_counter}/{total_steps} - Insertion des codes fiscaux exonérés clients depuis SAP - {step_datetime}", "info")
                    try:
                        cursor.execute("CALL clean_data.sp_insert_customer_tax_free_tax_code_from_sap()")
                        step_duration = time.time() - step_start
                        logger.info(f"Procédure sp_insert_customer_tax_free_tax_code_from_sap exécutée avec succès en {step_duration:.2f}s")
                        self._add_log_message(f"✅ Codes fiscaux exonérés clients insérés avec succès en {step_duration:.2f}s", "success")
                    except Exception as proc_error:
                        error_msg = f"Erreur à l'étape {step_counter}/{total_steps} (sp_insert_customer_tax_free_tax_code_from_sap): {str(proc_error)}"
                        logger.error(error_msg)
                        self._add_log_message(f"❌ {error_msg}", "error")
                        conn_psycopg2.rollback()
                        raise
                    
                    # Capturer les notices
                    for notice in conn_psycopg2.notices:
                        notice_text = notice.strip()
                        logger.info(f"PostgreSQL NOTICE: {notice_text}")
                        self._add_log_message(notice_text, "info")
                    conn_psycopg2.notices[:] = []
                    
                    # 8. Insérer les exemptions fiscales de livraison clients depuis SAP
                    step_counter += 1
                    step_start = time.time()
                    step_datetime = time.strftime('%Y-%m-%d %H:%M:%S')
                    logger.info(f"Étape {step_counter}/{total_steps} - Appel de la procédure clean_data.sp_insert_customer_del_tax_exempt_from_sap - {step_datetime}")
                    self._add_log_message(f"📋 Étape {step_counter}/{total_steps} - Insertion des exemptions fiscales de livraison clients depuis SAP - {step_datetime}", "info")
                    try:
                        cursor.execute("CALL clean_data.sp_insert_customer_del_tax_exempt_from_sap()")
                        step_duration = time.time() - step_start
                        logger.info(f"Procédure sp_insert_customer_del_tax_exempt_from_sap exécutée avec succès en {step_duration:.2f}s")
                        self._add_log_message(f"✅ Exemptions fiscales de livraison clients insérées avec succès en {step_duration:.2f}s", "success")
                    except Exception as proc_error:
                        error_msg = f"Erreur à l'étape {step_counter}/{total_steps} (sp_insert_customer_del_tax_exempt_from_sap): {str(proc_error)}"
                        logger.error(error_msg)
                        self._add_log_message(f"❌ {error_msg}", "error")
                        conn_psycopg2.rollback()
                        raise
                    
                    # Capturer les notices
                    for notice in conn_psycopg2.notices:
                        notice_text = notice.strip()
                        logger.info(f"PostgreSQL NOTICE: {notice_text}")
                        self._add_log_message(notice_text, "info")
                    conn_psycopg2.notices[:] = []
                    
                    # 9. Insérer les numéros de taxe d'adresse clients depuis SAP
                    step_counter += 1
                    step_start = time.time()
                    step_datetime = time.strftime('%Y-%m-%d %H:%M:%S')
                    logger.info(f"Étape {step_counter}/{total_steps} - Appel de la procédure clean_data.sp_insert_customer_addr_tax_number_from_sap - {step_datetime}")
                    self._add_log_message(f"🔢 Étape {step_counter}/{total_steps} - Insertion des numéros de taxe d'adresse clients depuis SAP - {step_datetime}", "info")
                    try:
                        cursor.execute("CALL clean_data.sp_insert_customer_addr_tax_number_from_sap()")
                        step_duration = time.time() - step_start
                        logger.info(f"Procédure sp_insert_customer_addr_tax_number_from_sap exécutée avec succès en {step_duration:.2f}s")
                        self._add_log_message(f"✅ Numéros de taxe d'adresse clients insérés avec succès en {step_duration:.2f}s", "success")
                    except Exception as proc_error:
                        error_msg = f"Erreur à l'étape {step_counter}/{total_steps} (sp_insert_customer_addr_tax_number_from_sap): {str(proc_error)}"
                        logger.error(error_msg)
                        self._add_log_message(f"❌ {error_msg}", "error")
                        conn_psycopg2.rollback()
                        raise
                    
                    # Capturer les notices
                    for notice in conn_psycopg2.notices:
                        notice_text = notice.strip()
                        logger.info(f"PostgreSQL NOTICE: {notice_text}")
                        self._add_log_message(notice_text, "info")
                    conn_psycopg2.notices[:] = []
                    
                    # 10. Insérer les informations fiscales document clients depuis SAP
                    step_counter += 1
                    step_start = time.time()
                    step_datetime = time.strftime('%Y-%m-%d %H:%M:%S')
                    logger.info(f"Étape {step_counter}/{total_steps} - Appel de la procédure clean_data.sp_insert_customer_document_tax_info_from_sap - {step_datetime}")
                    self._add_log_message(f"📄 Étape {step_counter}/{total_steps} - Insertion des informations fiscales document clients depuis SAP - {step_datetime}", "info")
                    try:
                        cursor.execute("CALL clean_data.sp_insert_customer_document_tax_info_from_sap()")
                        step_duration = time.time() - step_start
                        logger.info(f"Procédure sp_insert_customer_document_tax_info_from_sap exécutée avec succès en {step_duration:.2f}s")
                        self._add_log_message(f"✅ Informations fiscales document clients insérées avec succès en {step_duration:.2f}s", "success")
                    except Exception as proc_error:
                        error_msg = f"Erreur à l'étape {step_counter}/{total_steps} (sp_insert_customer_document_tax_info_from_sap): {str(proc_error)}"
                        logger.error(error_msg)
                        self._add_log_message(f"❌ {error_msg}", "error")
                        conn_psycopg2.rollback()
                        raise
                    
                    # Capturer les notices
                    for notice in conn_psycopg2.notices:
                        notice_text = notice.strip()
                        logger.info(f"PostgreSQL NOTICE: {notice_text}")
                        self._add_log_message(notice_text, "info")
                    conn_psycopg2.notices[:] = []
                    
                    # 11. Insérer les méthodes de communication clients depuis SAP
                    step_counter += 1
                    step_start = time.time()
                    step_datetime = time.strftime('%Y-%m-%d %H:%M:%S')
                    logger.info(f"Étape {step_counter}/{total_steps} - Appel de la procédure clean_data.sp_insert_cus_comm_method_from_sap - {step_datetime}")
                    self._add_log_message(f"📞 Étape {step_counter}/{total_steps} - Insertion des méthodes de communication clients depuis SAP - {step_datetime}", "info")
                    try:
                        cursor.execute("CALL clean_data.sp_insert_cus_comm_method_from_sap()")
                        step_duration = time.time() - step_start
                        logger.info(f"Procédure sp_insert_cus_comm_method_from_sap exécutée avec succès en {step_duration:.2f}s")
                        self._add_log_message(f"✅ Méthodes de communication clients insérées avec succès en {step_duration:.2f}s", "success")
                    except Exception as proc_error:
                        error_msg = f"Erreur à l'étape {step_counter}/{total_steps} (sp_insert_cus_comm_method_from_sap): {str(proc_error)}"
                        logger.error(error_msg)
                        self._add_log_message(f"❌ {error_msg}", "error")
                        conn_psycopg2.rollback()
                        raise
                    
                    # Capturer les notices
                    for notice in conn_psycopg2.notices:
                        notice_text = notice.strip()
                        logger.info(f"PostgreSQL NOTICE: {notice_text}")
                        self._add_log_message(notice_text, "info")
                    conn_psycopg2.notices[:] = []
                    
                    # 12. Insérer les informations de facturation clients depuis SAP
                    step_counter += 1
                    step_start = time.time()
                    step_datetime = time.strftime('%Y-%m-%d %H:%M:%S')
                    logger.info(f"Étape {step_counter}/{total_steps} - Appel de la procédure clean_data.sp_insert_cus_ident_invoice_info_from_sap - {step_datetime}")
                    self._add_log_message(f"🧾 Étape {step_counter}/{total_steps} - Insertion des informations de facturation clients depuis SAP - {step_datetime}", "info")
                    try:
                        cursor.execute("CALL clean_data.sp_insert_cus_ident_invoice_info_from_sap()")
                        step_duration = time.time() - step_start
                        logger.info(f"Procédure sp_insert_cus_ident_invoice_info_from_sap exécutée avec succès en {step_duration:.2f}s")
                        self._add_log_message(f"✅ Informations de facturation clients insérées avec succès en {step_duration:.2f}s", "success")
                    except Exception as proc_error:
                        error_msg = f"Erreur à l'étape {step_counter}/{total_steps} (sp_insert_cus_ident_invoice_info_from_sap): {str(proc_error)}"
                        logger.error(error_msg)
                        self._add_log_message(f"❌ {error_msg}", "error")
                        conn_psycopg2.rollback()
                        raise
                    
                    # Capturer les notices
                    for notice in conn_psycopg2.notices:
                        notice_text = notice.strip()
                        logger.info(f"PostgreSQL NOTICE: {notice_text}")
                        self._add_log_message(notice_text, "info")
                    conn_psycopg2.notices[:] = []
                    
                    # 13. Insérer les codes de frais de livraison clients depuis SAP
                    step_counter += 1
                    step_start = time.time()
                    step_datetime = time.strftime('%Y-%m-%d %H:%M:%S')
                    logger.info(f"Étape {step_counter}/{total_steps} - Appel de la procédure clean_data.sp_insert_customer_delivery_fee_code_from_sap - {step_datetime}")
                    self._add_log_message(f"💵 Étape {step_counter}/{total_steps} - Insertion des codes de frais de livraison clients depuis SAP - {step_datetime}", "info")
                    try:
                        cursor.execute("CALL clean_data.sp_insert_customer_delivery_fee_code_from_sap()")
                        step_duration = time.time() - step_start
                        logger.info(f"Procédure sp_insert_customer_delivery_fee_code_from_sap exécutée avec succès en {step_duration:.2f}s")
                        self._add_log_message(f"✅ Codes de frais de livraison clients insérés avec succès en {step_duration:.2f}s", "success")
                    except Exception as proc_error:
                        error_msg = f"Erreur à l'étape {step_counter}/{total_steps} (sp_insert_customer_delivery_fee_code_from_sap): {str(proc_error)}"
                        logger.error(error_msg)
                        self._add_log_message(f"❌ {error_msg}", "error")
                        conn_psycopg2.rollback()
                        raise
                    
                    # Capturer les notices
                    for notice in conn_psycopg2.notices:
                        notice_text = notice.strip()
                        logger.info(f"PostgreSQL NOTICE: {notice_text}")
                        self._add_log_message(notice_text, "info")
                    conn_psycopg2.notices[:] = []
                    
                    # 14. Insérer les informations de crédit clients depuis SAP
                    step_counter += 1
                    step_start = time.time()
                    step_datetime = time.strftime('%Y-%m-%d %H:%M:%S')
                    logger.info(f"Étape {step_counter}/{total_steps} - Appel de la procédure clean_data.sp_insert_customer_credit_info_from_sap - {step_datetime}")
                    self._add_log_message(f"💳 Étape {step_counter}/{total_steps} - Insertion des informations de crédit clients depuis SAP - {step_datetime}", "info")
                    try:
                        cursor.execute("CALL clean_data.sp_insert_customer_credit_info_from_sap()")
                        step_duration = time.time() - step_start
                        logger.info(f"Procédure sp_insert_customer_credit_info_from_sap exécutée avec succès en {step_duration:.2f}s")
                        self._add_log_message(f"✅ Informations de crédit clients insérées avec succès en {step_duration:.2f}s", "success")
                    except Exception as proc_error:
                        error_msg = f"Erreur à l'étape {step_counter}/{total_steps} (sp_insert_customer_credit_info_from_sap): {str(proc_error)}"
                        logger.error(error_msg)
                        self._add_log_message(f"❌ {error_msg}", "error")
                        conn_psycopg2.rollback()
                        raise
                    
                    # Capturer les notices
                    for notice in conn_psycopg2.notices:
                        notice_text = notice.strip()
                        logger.info(f"PostgreSQL NOTICE: {notice_text}")
                        self._add_log_message(notice_text, "info")
                    conn_psycopg2.notices[:] = []
                    
                    # 15. Insérer les informations de commande clients depuis SAP
                    step_counter += 1
                    step_start = time.time()
                    step_datetime = time.strftime('%Y-%m-%d %H:%M:%S')
                    logger.info(f"Étape {step_counter}/{total_steps} - Appel de la procédure clean_data.sp_insert_cust_ord_customer_from_sap - {step_datetime}")
                    self._add_log_message(f"🛒 Étape {step_counter}/{total_steps} - Insertion des informations de commande clients depuis SAP - {step_datetime}", "info")
                    try:
                        cursor.execute("CALL clean_data.sp_insert_cust_ord_customer_from_sap()")
                        step_duration = time.time() - step_start
                        logger.info(f"Procédure sp_insert_cust_ord_customer_from_sap exécutée avec succès en {step_duration:.2f}s")
                        self._add_log_message(f"✅ Informations de commande clients insérées avec succès en {step_duration:.2f}s", "success")
                    except Exception as proc_error:
                        error_msg = f"Erreur à l'étape {step_counter}/{total_steps} (sp_insert_cust_ord_customer_from_sap): {str(proc_error)}"
                        logger.error(error_msg)
                        self._add_log_message(f"❌ {error_msg}", "error")
                        conn_psycopg2.rollback()
                        raise
                    
                    # Capturer les notices
                    for notice in conn_psycopg2.notices:
                        notice_text = notice.strip()
                        logger.info(f"PostgreSQL NOTICE: {notice_text}")
                        self._add_log_message(notice_text, "info")
                    conn_psycopg2.notices[:] = []
                    
                    # 16. Insérer les informations d'adresse de commande clients depuis SAP
                    step_counter += 1
                    step_start = time.time()
                    step_datetime = time.strftime('%Y-%m-%d %H:%M:%S')
                    logger.info(f"Étape {step_counter}/{total_steps} - Appel de la procédure clean_data.sp_insert_cust_ord_customer_address_from_sap - {step_datetime}")
                    self._add_log_message(f"📍 Étape {step_counter}/{total_steps} - Insertion des informations d'adresse de commande clients depuis SAP - {step_datetime}", "info")
                    try:
                        cursor.execute("CALL clean_data.sp_insert_cust_ord_customer_address_from_sap()")
                        step_duration = time.time() - step_start
                        logger.info(f"Procédure sp_insert_cust_ord_customer_address_from_sap exécutée avec succès en {step_duration:.2f}s")
                        self._add_log_message(f"✅ Informations d'adresse de commande clients insérées avec succès en {step_duration:.2f}s", "success")
                    except Exception as proc_error:
                        error_msg = f"Erreur à l'étape {step_counter}/{total_steps} (sp_insert_cust_ord_customer_address_from_sap): {str(proc_error)}"
                        logger.error(error_msg)
                        self._add_log_message(f"❌ {error_msg}", "error")
                        conn_psycopg2.rollback()
                        raise
                    
                    # Capturer les notices
                    for notice in conn_psycopg2.notices:
                        notice_text = notice.strip()
                        logger.info(f"PostgreSQL NOTICE: {notice_text}")
                        self._add_log_message(notice_text, "info")
                    conn_psycopg2.notices[:] = []
                    
                    # 17. Insérer les informations de paiement clients depuis SAP
                    step_counter += 1
                    step_start = time.time()
                    step_datetime = time.strftime('%Y-%m-%d %H:%M:%S')
                    logger.info(f"Étape {step_counter}/{total_steps} - Appel de la procédure clean_data.sp_insert_cus_identity_pay_info_from_sap - {step_datetime}")
                    self._add_log_message(f"💰 Étape {step_counter}/{total_steps} - Insertion des informations de paiement clients depuis SAP - {step_datetime}", "info")
                    try:
                        cursor.execute("CALL clean_data.sp_insert_cus_identity_pay_info_from_sap()")
                        step_duration = time.time() - step_start
                        logger.info(f"Procédure sp_insert_cus_identity_pay_info_from_sap exécutée avec succès en {step_duration:.2f}s")
                        self._add_log_message(f"✅ Informations de paiement clients insérées avec succès en {step_duration:.2f}s", "success")
                    except Exception as proc_error:
                        error_msg = f"Erreur à l'étape {step_counter}/{total_steps} (sp_insert_cus_identity_pay_info_from_sap): {str(proc_error)}"
                        logger.error(error_msg)
                        self._add_log_message(f"❌ {error_msg}", "error")
                        conn_psycopg2.rollback()
                        raise
                    
                    # Capturer les notices
                    for notice in conn_psycopg2.notices:
                        notice_text = notice.strip()
                        logger.info(f"PostgreSQL NOTICE: {notice_text}")
                        self._add_log_message(notice_text, "info")
                    conn_psycopg2.notices[:] = []
                    
                    # 18. Insérer les méthodes de paiement par client depuis SAP
                    step_counter += 1
                    step_start = time.time()
                    step_datetime = time.strftime('%Y-%m-%d %H:%M:%S')
                    logger.info(f"Étape {step_counter}/{total_steps} - Appel de la procédure clean_data.sp_insert_cus_paym_way_per_ident_from_sap - {step_datetime}")
                    self._add_log_message(f"💳 Étape {step_counter}/{total_steps} - Insertion des méthodes de paiement par client depuis SAP - {step_datetime}", "info")
                    try:
                        cursor.execute("CALL clean_data.sp_insert_cus_paym_way_per_ident_from_sap()")
                        step_duration = time.time() - step_start
                        logger.info(f"Procédure sp_insert_cus_paym_way_per_ident_from_sap exécutée avec succès en {step_duration:.2f}s")
                        self._add_log_message(f"✅ Méthodes de paiement par client insérées avec succès en {step_duration:.2f}s", "success")
                    except Exception as proc_error:
                        error_msg = f"Erreur à l'étape {step_counter}/{total_steps} (sp_insert_cus_paym_way_per_ident_from_sap): {str(proc_error)}"
                        logger.error(error_msg)
                        self._add_log_message(f"❌ {error_msg}", "error")
                        conn_psycopg2.rollback()
                        raise
                    
                    # Capturer les notices
                    for notice in conn_psycopg2.notices:
                        notice_text = notice.strip()
                        logger.info(f"PostgreSQL NOTICE: {notice_text}")
                        self._add_log_message(notice_text, "info")
                    conn_psycopg2.notices[:] = []
                    
                    # 19. Renuméroter tous les customer_id en cascade
                    step_counter += 1
                    step_start = time.time()
                    step_datetime = time.strftime('%Y-%m-%d %H:%M:%S')
                    logger.info(f"Étape {step_counter}/{total_steps} - Appel de la procédure clean_data.sp_renumber_all_customer_ids - {step_datetime}")
                    self._add_log_message(f"🔢 Étape {step_counter}/{total_steps} - Renumérotation de tous les customer_id en cascade - {step_datetime}", "info")
                    try:
                        cursor.execute("CALL clean_data.sp_renumber_all_customer_ids(700000)")
                        step_duration = time.time() - step_start
                        logger.info(f"Procédure sp_renumber_all_customer_ids exécutée avec succès en {step_duration:.2f}s")
                        self._add_log_message(f"✅ Renumérotation des customer_id terminée avec succès en {step_duration:.2f}s", "success")
                    except Exception as proc_error:
                        error_msg = f"Erreur à l'étape {step_counter}/{total_steps} (sp_renumber_all_customer_ids): {str(proc_error)}"
                        logger.error(error_msg)
                        self._add_log_message(f"❌ {error_msg}", "error")
                        conn_psycopg2.rollback()
                        raise
                    
                    # Capturer les notices
                    for notice in conn_psycopg2.notices:
                        notice_text = notice.strip()
                        logger.info(f"PostgreSQL NOTICE: {notice_text}")
                        self._add_log_message(notice_text, "info")
                    conn_psycopg2.notices[:] = []
            
            conn_psycopg2.close()
            
            execution_time = time.time() - start_time
            end_datetime = time.strftime('%Y-%m-%d %H:%M:%S')
            logger.info(f"🎉 Processus ETL clients terminé - {end_datetime} - Durée totale: {execution_time:.2f} secondes")
            self._add_log_message(f"🎉 Processus ETL clients terminé avec succès - {end_datetime}", "success")
            self._add_log_message(f"⏱️ Durée totale d'exécution: {execution_time:.2f} secondes", "info")
            self._add_log_message(f"📊 Toutes les données clients SAP ont été traitées avec succès ({total_steps} étapes)", "success")
            
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

    def run_etl(self):
        """
        Exécution du processus ETL via les procédures stockées
        """
        start_time = time.time()
        logger.info("Démarrage du processus ETL via procédures stockées")
        
        try:
            with self.pg_engine.connect() as conn:
                with conn.begin():
                    # 1. Insérer les informations clients depuis SAP
                    logger.info("Appel de la procédure clean_data.sp_insert_customer_info_from_sap")
                    conn.execute(text("CALL clean_data.sp_insert_customer_info_from_sap()"))
                    logger.info("Procédure sp_insert_customer_info_from_sap exécutée avec succès")
                    
                    # Capturer les notices PostgreSQL
                    self._capture_postgres_notices(conn)
                    
                    # 2. Insérer les adresses clients depuis SAP
                    logger.info("Appel de la procédure clean_data.sp_insert_customer_address_from_sap")
                    conn.execute(text("CALL clean_data.sp_insert_customer_address_from_sap()"))
                    logger.info("Procédure sp_insert_customer_address_from_sap exécutée avec succès")
                    
                    # Capturer les notices PostgreSQL
                    self._capture_postgres_notices(conn)
                    
                    # 3. Insérer les types d'adresses clients depuis SAP
                    logger.info("Appel de la procédure clean_data.sp_insert_customer_address_type_from_sap")
                    conn.execute(text("CALL clean_data.sp_insert_customer_address_type_from_sap()"))
                    logger.info("Procédure sp_insert_customer_address_type_from_sap exécutée avec succès")
                    
                    # Capturer les notices PostgreSQL
                    self._capture_postgres_notices(conn)
                    
                    # 4. Insérer les informations fiscales clients depuis SAP
                    logger.info("Appel de la procédure clean_data.sp_insert_customer_tax_info_from_sap")
                    conn.execute(text("CALL clean_data.sp_insert_customer_tax_info_from_sap()"))
                    logger.info("Procédure sp_insert_customer_tax_info_from_sap exécutée avec succès")
                    
                    # Capturer les notices PostgreSQL
                    self._capture_postgres_notices(conn)
                    
                    # 5. Insérer les informations fiscales de livraison clients depuis SAP
                    logger.info("Appel de la procédure clean_data.sp_insert_customer_delivery_tax_info_from_sap")
                    conn.execute(text("CALL clean_data.sp_insert_customer_delivery_tax_info_from_sap()"))
                    logger.info("Procédure sp_insert_customer_delivery_tax_info_from_sap exécutée avec succès")
                    
                    # Capturer les notices PostgreSQL
                    self._capture_postgres_notices(conn)
                    
                    # 6. Insérer les codes fiscaux exonérés clients depuis SAP
                    logger.info("Appel de la procédure clean_data.sp_insert_customer_tax_free_tax_code_from_sap")
                    conn.execute(text("CALL clean_data.sp_insert_customer_tax_free_tax_code_from_sap()"))
                    logger.info("Procédure sp_insert_customer_tax_free_tax_code_from_sap exécutée avec succès")
                    
                    # Capturer les notices PostgreSQL
                    self._capture_postgres_notices(conn)
                    
                    # 7. Insérer les exemptions fiscales de livraison clients depuis SAP
                    logger.info("Appel de la procédure clean_data.sp_insert_customer_del_tax_exempt_from_sap")
                    conn.execute(text("CALL clean_data.sp_insert_customer_del_tax_exempt_from_sap()"))
                    logger.info("Procédure sp_insert_customer_del_tax_exempt_from_sap exécutée avec succès")
                    
                    # Capturer les notices PostgreSQL
                    self._capture_postgres_notices(conn)
                    
                    # 8. Insérer les numéros de taxe d'adresse clients depuis SAP
                    logger.info("Appel de la procédure clean_data.sp_insert_customer_addr_tax_number_from_sap")
                    conn.execute(text("CALL clean_data.sp_insert_customer_addr_tax_number_from_sap()"))
                    logger.info("Procédure sp_insert_customer_addr_tax_number_from_sap exécutée avec succès")
                    
                    # Capturer les notices PostgreSQL
                    self._capture_postgres_notices(conn)
                    
                    # 9. Insérer les informations fiscales document clients depuis SAP
                    logger.info("Appel de la procédure clean_data.sp_insert_customer_document_tax_info_from_sap")
                    conn.execute(text("CALL clean_data.sp_insert_customer_document_tax_info_from_sap()"))
                    logger.info("Procédure sp_insert_customer_document_tax_info_from_sap exécutée avec succès")
                    
                    # Capturer les notices PostgreSQL
                    self._capture_postgres_notices(conn)
            
            execution_time = time.time() - start_time
            logger.info(f"Processus ETL terminé en {execution_time:.2f} secondes")
            self._add_log_message(f"✅ Processus ETL terminé avec succès en {execution_time:.2f} secondes", "success")
            
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
    Fonction de compatibilité pour l'interface ETL existante
    """
    try:
        etl = CustomerETL()
        # Utiliser la version avec capture de logs PostgreSQL
        result = etl.run_etl_with_psycopg2_logs()
        return result
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
        etl = CustomerETL()
        # Utiliser la version avec capture de logs pour le test direct
        result = etl.run_etl_with_psycopg2_logs()
        
        if result["success"]:
            print(f"Traitement ETL terminé avec succès")
            print(f"Temps d'exécution: {result['execution_time_seconds']:.2f} secondes")
            exit(0)
        else:
            print(f"Erreur: {result.get('error', 'Une erreur inconnue est survenue')}")
            exit(1)
    except Exception as e:
        print(f"Erreur: {str(e)}")
        exit(1)
