#!/usr/bin/env python
# -*- coding: utf-8 -*-

"""
Module ETL simplifié pour le chargement des données fournisseurs.
Utilise la procédure stockée public.alimenter_ifs_fournisseurs.
Version mise à jour avec procédures sans paramètres:
- sp_insert_identity_invoice_info_from_sap() (sans paramètres, avec données bancaires LFBK)
- sp_insert_identity_pay_info_from_sap() (sans paramètres, utilise vue enrichie)
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
    
    # Tentative d'ajout du fichier de log
    try:
        # Essayer d'abord dans le répertoire logs du backend
        log_dir = os.path.join(os.path.dirname(__file__), '..', 'logs')
        if not os.path.exists(log_dir):
            os.makedirs(log_dir, exist_ok=True)
        log_file = os.path.join(log_dir, 'etl_supplier_base.log')
        
        # Vérifier les permissions d'écriture avant d'essayer de créer le fichier
        if os.access(log_dir, os.W_OK):
            log_handlers.append(logging.FileHandler(log_file))
        else:
            raise PermissionError(f"Pas de permission d'écriture dans {log_dir}")
            
    except (OSError, PermissionError) as e:
        print(f"Impossible d'écrire dans le répertoire logs: {e}")
        try:
            # Fallback vers /tmp si disponible
            temp_log_file = '/tmp/etl_supplier_base.log'
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

class SupplierBaseETL:
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
        Version alternative avec psycopg2 pour capturer les logs
        """
        start_time = time.time()
        logger.info("Démarrage du processus ETL avec capture de logs PostgreSQL")
        self._add_log_message("Démarrage du processus ETL fournisseurs", "info")
        
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
                    
                    # 1. Alimenter les tables IFS (PRÉREQUIS pour supplier_info_general)
                    logger.info("Appel de la fonction clean_data.alimenter_ifs_fournisseurs")
                    self._add_log_message("Alimentation de ifs_fournisseurs...", "info")
                    cursor.execute("SELECT clean_data.alimenter_ifs_fournisseurs()")
                    logger.info("Fonction alimenter_ifs_fournisseurs exécutée avec succès")
                    self._add_log_message("✅ ifs_fournisseurs alimenté avec succès", "success")
                    
                    # Capturer les notices
                    for notice in conn_psycopg2.notices:
                        notice_text = notice.strip()
                        logger.info(f"PostgreSQL NOTICE: {notice_text}")
                        self._add_log_message(notice_text, "info")
                    conn_psycopg2.notices[:] = []
                    
                    # 2. Alimenter supplier_info_general
                    logger.info("Appel de la fonction clean_data.alimenter_supplier_info_general")
                    self._add_log_message("Alimentation de supplier_info_general...", "info")
                    cursor.execute("SELECT clean_data.alimenter_supplier_info_general()")
                    logger.info("Fonction alimenter_supplier_info_general exécutée avec succès")
                    self._add_log_message("✅ supplier_info_general alimenté avec succès", "success")
                    
                    # Capturer les notices
                    for notice in conn_psycopg2.notices:
                        notice_text = notice.strip()
                        logger.info(f"PostgreSQL NOTICE: {notice_text}")
                        self._add_log_message(notice_text, "info")
                    conn_psycopg2.notices[:] = []
                    
                    # 2. Alimenter supplier_info_our_id
                    logger.info("Appel de la fonction clean_data.alimenter_supplier_info_our_id")
                    self._add_log_message("Alimentation de supplier_info_our_id...", "info")
                    cursor.execute("SELECT clean_data.alimenter_supplier_info_our_id()")
                    logger.info("Fonction alimenter_supplier_info_our_id exécutée avec succès")
                    self._add_log_message("✅ supplier_info_our_id alimenté avec succès", "success")
                    
                    # Capturer les notices
                    for notice in conn_psycopg2.notices:
                        notice_text = notice.strip()
                        logger.info(f"PostgreSQL NOTICE: {notice_text}")
                        self._add_log_message(notice_text, "info")
                    conn_psycopg2.notices[:] = []
                    
                    # 3. Alimenter supplier_info_address
                    logger.info("Appel de la fonction clean_data.alimenter_supplier_info_address")
                    self._add_log_message("Alimentation de supplier_info_address...", "info")
                    cursor.execute("SELECT clean_data.alimenter_supplier_info_address()")
                    logger.info("Fonction alimenter_supplier_info_address exécutée avec succès")
                    self._add_log_message("✅ supplier_info_address alimenté avec succès", "success")
                    
                    # Capturer les notices
                    for notice in conn_psycopg2.notices:
                        notice_text = notice.strip()
                        logger.info(f"PostgreSQL NOTICE: {notice_text}")
                        self._add_log_message(notice_text, "info")
                    conn_psycopg2.notices[:] = []
                    
                    # 4. Insérer les types d'adresses fournisseurs
                    logger.info("Appel de la fonction clean_data.insert_supplier_address_types")
                    cursor.execute("SELECT clean_data.insert_supplier_address_types()")
                    logger.info("Fonction insert_supplier_address_types exécutée avec succès")
                    
                    # Capturer les notices
                    for notice in conn_psycopg2.notices:
                        notice_text = notice.strip()
                        logger.info(f"PostgreSQL NOTICE: {notice_text}")
                        self._add_log_message(notice_text, "info")
                    conn_psycopg2.notices[:] = []
                    
                    # 5. Alimenter les méthodes de communication
                    logger.info("Appel de la fonction clean_data.alimenter_comm_method")
                    cursor.execute("SELECT clean_data.alimenter_comm_method()")
                    logger.info("Fonction alimenter_comm_method exécutée avec succès")
                    
                    # Capturer les notices
                    for notice in conn_psycopg2.notices:
                        notice_text = notice.strip()
                        logger.info(f"PostgreSQL NOTICE: {notice_text}")
                        self._add_log_message(notice_text, "info")
                    conn_psycopg2.notices[:] = []
                    
                    # 6. Alimenter les adresses fournisseurs
                    logger.info("Appel de la fonction clean_data.alimenter_supplier_address")
                    self._add_log_message("Alimentation des adresses fournisseurs...", "info")
                    cursor.execute("SELECT clean_data.alimenter_supplier_address()")
                    logger.info("Fonction alimenter_supplier_address exécutée avec succès")
                    self._add_log_message("✅ Adresses fournisseurs alimentées avec succès", "success")
                    
                    # Capturer les notices
                    for notice in conn_psycopg2.notices:
                        notice_text = notice.strip()
                        logger.info(f"PostgreSQL NOTICE: {notice_text}")
                        self._add_log_message(notice_text, "info")
                    conn_psycopg2.notices[:] = []
                    
                    # 7. Insérer les informations fiscales des documents fournisseurs
                    logger.info("Appel de la fonction clean_data.insert_supplier_document_tax_info")
                    cursor.execute("SELECT clean_data.insert_supplier_document_tax_info()")
                    logger.info("Fonction insert_supplier_document_tax_info exécutée avec succès")
                    
                    # Capturer les notices
                    for notice in conn_psycopg2.notices:
                        notice_text = notice.strip()
                        logger.info(f"PostgreSQL NOTICE: {notice_text}")
                        self._add_log_message(notice_text, "info")
                    conn_psycopg2.notices[:] = []
                    
                    # 8. Insérer les données dans la table SUPPLIER
                    logger.info("Appel de la procédure clean_data.sp_insert_supplier_from_sap")
                    self._add_log_message("Insertion dans la table SUPPLIER...", "info")
                    cursor.execute("CALL clean_data.sp_insert_supplier_from_sap()")
                    logger.info("Procédure sp_insert_supplier_from_sap exécutée avec succès")
                    self._add_log_message("✅ Table SUPPLIER alimentée avec succès", "success")
                    
                    # Capturer les notices
                    for notice in conn_psycopg2.notices:
                        notice_text = notice.strip()
                        logger.info(f"PostgreSQL NOTICE: {notice_text}")
                        self._add_log_message(notice_text, "info")
                    conn_psycopg2.notices[:] = []
                    
                    # 9. Insérer les informations de facturation des identités SAP (avec données bancaires)
                    logger.info("Appel de la procédure clean_data.sp_insert_identity_invoice_info_from_sap")
                    self._add_log_message("Insertion des informations de facturation (IDENTITY_INVOICE_INFO)...", "info")
                    cursor.execute("CALL clean_data.sp_insert_identity_invoice_info_from_sap()")
                    logger.info("Procédure sp_insert_identity_invoice_info_from_sap exécutée avec succès")
                    self._add_log_message("✅ IDENTITY_INVOICE_INFO alimenté avec succès", "success")
                    
                    # Capturer les notices
                    for notice in conn_psycopg2.notices:
                        notice_text = notice.strip()
                        logger.info(f"PostgreSQL NOTICE: {notice_text}")
                        self._add_log_message(notice_text, "info")
                    conn_psycopg2.notices[:] = []
                    
                    # 10. Insérer les informations de paiement des identités SAP
                    logger.info("Appel de la procédure clean_data.sp_insert_identity_pay_info_from_sap")
                    self._add_log_message("Insertion des informations de paiement (IDENTITY_PAY_INFO)...", "info")
                    cursor.execute("CALL clean_data.sp_insert_identity_pay_info_from_sap()")
                    logger.info("Procédure sp_insert_identity_pay_info_from_sap exécutée avec succès")
                    self._add_log_message("✅ IDENTITY_PAY_INFO alimenté avec succès", "success")
                    
                    # Capturer les notices
                    for notice in conn_psycopg2.notices:
                        notice_text = notice.strip()
                        logger.info(f"PostgreSQL NOTICE: {notice_text}")
                        self._add_log_message(notice_text, "info")
                    conn_psycopg2.notices[:] = []
                    
                    # 11. Alimenter les moyens de paiement par identité
                    logger.info("Appel de la fonction clean_data.fn_upsert_payment_way_per_identity")
                    self._add_log_message("Alimentation des moyens de paiement par identité...", "info")
                    cursor.execute("SELECT clean_data.fn_upsert_payment_way_per_identity()")
                    result = cursor.fetchone()
                    processed_count = result[0] if result else 0
                    logger.info(f"Fonction fn_upsert_payment_way_per_identity exécutée avec succès: {processed_count} enregistrements traités")
                    self._add_log_message(f"✅ Moyens de paiement alimentés: {processed_count} enregistrements", "success")
                    
                    # Capturer les notices
                    for notice in conn_psycopg2.notices:
                        notice_text = notice.strip()
                        logger.info(f"PostgreSQL NOTICE: {notice_text}")
                        self._add_log_message(notice_text, "info")
                    conn_psycopg2.notices[:] = []
                    
                    # 12. Alimenter les codes fiscaux de livraison fournisseurs
                    logger.info("Appel de la fonction clean_data.fn_upsert_supplier_delivery_tax_code")
                    cursor.execute("SELECT clean_data.fn_upsert_supplier_delivery_tax_code()")
                    result = cursor.fetchone()
                    processed_count = result[0] if result else 0
                    logger.info(f"Fonction fn_upsert_supplier_delivery_tax_code exécutée avec succès: {processed_count} enregistrements traités")
                    
                    # Capturer les notices
                    for notice in conn_psycopg2.notices:
                        notice_text = notice.strip()
                        logger.info(f"PostgreSQL NOTICE: {notice_text}")
                        self._add_log_message(notice_text, "info")
                    conn_psycopg2.notices[:] = []
                    
                    # 13. Alimenter les adresses de paiement fournisseurs
                    logger.info("Appel de la fonction clean_data.fn_upsert_payment_address")
                    self._add_log_message("Alimentation des adresses de paiement...", "info")
                    cursor.execute("SELECT clean_data.fn_upsert_payment_address()")
                    result = cursor.fetchone()
                    processed_count = result[0] if result else 0
                    logger.info(f"Fonction fn_upsert_payment_address exécutée avec succès: {processed_count} enregistrements traités")
                    self._add_log_message(f"✅ Adresses de paiement alimentées: {processed_count} enregistrements", "success")
                    
                    # Capturer les notices
                    for notice in conn_psycopg2.notices:
                        notice_text = notice.strip()
                        logger.info(f"PostgreSQL NOTICE: {notice_text}")
                        self._add_log_message(notice_text, "info")
                    conn_psycopg2.notices[:] = []
                    
                    # 14. Alimenter les informations fiscales fournisseurs
                    logger.info("Appel de la fonction clean_data.fn_upsert_supplier_tax_info")
                    self._add_log_message("Alimentation des informations fiscales fournisseurs...", "info")
                    cursor.execute("SELECT clean_data.fn_upsert_supplier_tax_info()")
                    result = cursor.fetchone()
                    processed_count = result[0] if result else 0
                    logger.info(f"Fonction fn_upsert_supplier_tax_info exécutée avec succès: {processed_count} enregistrements traités")
                    self._add_log_message(f"✅ Informations fiscales fournisseurs alimentées: {processed_count} enregistrements", "success")
                    
                    # Capturer les notices
                    for notice in conn_psycopg2.notices:
                        notice_text = notice.strip()
                        logger.info(f"PostgreSQL NOTICE: {notice_text}")
                        self._add_log_message(notice_text, "info")
                    conn_psycopg2.notices[:] = []
                    
                    # 15. DERNIÈRE ÉTAPE: Renuméroter tous les supplier_id (tables clean_data uniquement)
                    logger.info("Appel de la procédure clean_data.sp_renumber_all_suppliers")
                    self._add_log_message("Renumérotation des IDs fournisseurs (clean_data uniquement)...", "info")
                    cursor.execute("CALL clean_data.sp_renumber_all_suppliers()")
                    logger.info("Procédure sp_renumber_all_suppliers exécutée avec succès")
                    self._add_log_message("✅ IDs fournisseurs renumérotés avec succès", "success")
                    
                    # Capturer les notices
                    for notice in conn_psycopg2.notices:
                        notice_text = notice.strip()
                        logger.info(f"PostgreSQL NOTICE: {notice_text}")
                        self._add_log_message(notice_text, "info")
                    conn_psycopg2.notices[:] = []
            
            conn_psycopg2.close()
            
            execution_time = time.time() - start_time
            logger.info(f"Processus ETL terminé en {execution_time:.2f} secondes")
            self._add_log_message(f"✅ Processus ETL terminé avec succès en {execution_time:.2f} secondes", "success")
            
            return {
                "success": True,
                "execution_time_seconds": execution_time,
                "log_messages": self.log_messages,
                # "refresh_status": refresh_result[0] if refresh_result else "N/A",
                # "refresh_rows": refresh_result[2] if refresh_result else 0
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
        Exécution du processus ETL via les fonctions/procédures stockées
        """
        start_time = time.time()
        logger.info("Démarrage du processus ETL via fonctions/procédures stockées")
        
        try:
            with self.pg_engine.connect() as conn:
                with conn.begin():
                    
                    # 2. Appel de la procédure alimenter_ifs_fournisseurs
                    logger.info("Appel de la fonction clean_data.alimenter_ifs_fournisseurs")
                    result = conn.execute(text("SELECT clean_data.alimenter_ifs_fournisseurs()"))
                    processed_count = result.fetchone()[0] if result else 0
                    logger.info(f"Fonction alimenter_ifs_fournisseurs exécutée avec succès: {processed_count} enregistrements traités")
                    
                    # Capturer les notices PostgreSQL après la procédure
                    self._capture_postgres_notices(conn)
                    
                    # 3. Alimenter supplier_info_general
                    logger.info("Appel de la fonction clean_data.alimenter_supplier_info_general")
                    conn.execute(text("SELECT clean_data.alimenter_supplier_info_general()"))
                    logger.info("Fonction alimenter_supplier_info_general exécutée avec succès")
                    
                    # Capturer les notices PostgreSQL
                    self._capture_postgres_notices(conn)
                    
                    # 4. Alimenter supplier_info_our_id
                    logger.info("Appel de la fonction clean_data.alimenter_supplier_info_our_id")
                    conn.execute(text("SELECT clean_data.alimenter_supplier_info_our_id()"))
                    logger.info("Fonction alimenter_supplier_info_our_id exécutée avec succès")
                    
                    # Capturer les notices PostgreSQL
                    self._capture_postgres_notices(conn)
                    
                    # 5. Alimenter les adresses fournisseurs
                    logger.info("Appel de la fonction clean_data.alimenter_supplier_address")
                    conn.execute(text("SELECT clean_data.alimenter_supplier_address()"))
                    logger.info("Fonction alimenter_supplier_address exécutée avec succès")
                    
                    # Capturer les notices PostgreSQL
                    self._capture_postgres_notices(conn)
                    
                    # 6. Insérer les types d'adresses fournisseurs
                    logger.info("Appel de la fonction clean_data.insert_supplier_address_types")
                    conn.execute(text("SELECT clean_data.insert_supplier_address_types()"))
                    logger.info("Fonction insert_supplier_address_types exécutée avec succès")
                    
                    # Capturer les notices PostgreSQL
                    self._capture_postgres_notices(conn)
                    
                    # 7. Alimenter les méthodes de communication
                    logger.info("Appel de la fonction clean_data.alimenter_comm_method")
                    conn.execute(text("SELECT clean_data.alimenter_comm_method()"))
                    logger.info("Fonction alimenter_comm_method exécutée avec succès")
                    
                    # Capturer les notices PostgreSQL
                    self._capture_postgres_notices(conn)
                    
                    # 8. Insérer les informations fiscales des documents fournisseurs
                    logger.info("Appel de la fonction clean_data.insert_supplier_document_tax_info")
                    conn.execute(text("SELECT clean_data.insert_supplier_document_tax_info()"))
                    logger.info("Fonction insert_supplier_document_tax_info exécutée avec succès")
                    
                    # Capturer les notices PostgreSQL
                    self._capture_postgres_notices(conn)
                    
                    # 9. Insérer les données dans la table SUPPLIER
                    logger.info("Appel de la procédure clean_data.sp_insert_supplier_from_sap")
                    conn.execute(text("CALL clean_data.sp_insert_supplier_from_sap()"))
                    logger.info("Procédure sp_insert_supplier_from_sap exécutée avec succès")
                    
                    # Capturer les notices PostgreSQL
                    self._capture_postgres_notices(conn)
                    
                    # 10. Insérer les informations de facturation des identités SAP (avec données bancaires)
                    logger.info("Appel de la procédure clean_data.sp_insert_identity_invoice_info_from_sap")
                    conn.execute(text("CALL clean_data.sp_insert_identity_invoice_info_from_sap()"))
                    logger.info("Procédure sp_insert_identity_invoice_info_from_sap exécutée avec succès")
                    
                    # Capturer les notices PostgreSQL
                    self._capture_postgres_notices(conn)
                    
                    # 11. Insérer les informations de paiement des identités SAP
                    logger.info("Appel de la procédure clean_data.sp_insert_identity_pay_info_from_sap")
                    conn.execute(text("CALL clean_data.sp_insert_identity_pay_info_from_sap()"))
                    logger.info("Procédure sp_insert_identity_pay_info_from_sap exécutée avec succès")
                    
                    # Capturer les notices PostgreSQL
                    self._capture_postgres_notices(conn)
                    
                    # 12. Alimenter les moyens de paiement par identité
                    logger.info("Appel de la fonction clean_data.fn_upsert_payment_way_per_identity")
                    result = conn.execute(text("SELECT clean_data.fn_upsert_payment_way_per_identity()"))
                    processed_count = result.fetchone()[0] if result else 0
                    logger.info(f"Fonction fn_upsert_payment_way_per_identity exécutée avec succès: {processed_count} enregistrements traités")
                    
                    # Capturer les notices PostgreSQL
                    self._capture_postgres_notices(conn)
                    
                    # 13. Alimenter les codes fiscaux de livraison fournisseurs
                    logger.info("Appel de la fonction clean_data.fn_upsert_supplier_delivery_tax_code")
                    result = conn.execute(text("SELECT clean_data.fn_upsert_supplier_delivery_tax_code()"))
                    processed_count = result.fetchone()[0] if result else 0
                    logger.info(f"Fonction fn_upsert_supplier_delivery_tax_code exécutée avec succès: {processed_count} enregistrements traités")
                    
                    # Capturer les notices PostgreSQL
                    self._capture_postgres_notices(conn)
                    
                    # 14. Alimenter les informations fiscales fournisseurs
                    logger.info("Appel de la fonction clean_data.fn_upsert_supplier_tax_info")
                    result = conn.execute(text("SELECT clean_data.fn_upsert_supplier_tax_info()"))
                    processed_count = result.fetchone()[0] if result else 0
                    logger.info(f"Fonction fn_upsert_supplier_tax_info exécutée avec succès: {processed_count} enregistrements traités")
                    
                    # Capturer les notices PostgreSQL
                    self._capture_postgres_notices(conn)
                    
                    # 15. Alimenter les adresses de paiement fournisseurs
                    logger.info("Appel de la fonction clean_data.fn_upsert_payment_address")
                    result = conn.execute(text("SELECT clean_data.fn_upsert_payment_address()"))
                    processed_count = result.fetchone()[0] if result else 0
                    logger.info(f"Fonction fn_upsert_payment_address exécutée avec succès: {processed_count} enregistrements traités")
                    
                    # Capturer les notices PostgreSQL
                    self._capture_postgres_notices(conn)
                    
                    # 16. DERNIÈRE ÉTAPE: Renuméroter tous les supplier_id (tables clean_data uniquement)
                    logger.info("Appel de la procédure clean_data.sp_renumber_all_suppliers")
                    conn.execute(text("CALL clean_data.sp_renumber_all_suppliers()"))
                    logger.info("Procédure sp_renumber_all_suppliers exécutée avec succès")
                    
                    # Capturer les notices PostgreSQL
                    self._capture_postgres_notices(conn)
            
            execution_time = time.time() - start_time
            logger.info(f"Processus ETL terminé en {execution_time:.2f} secondes")
            self._add_log_message(f"✅ Processus ETL terminé avec succès en {execution_time:.2f} secondes", "success")
            
            return {
                "success": True,
                "execution_time_seconds": execution_time,
                "log_messages": self.log_messages,
                # "refresh_status": refresh_result[0] if refresh_result else "N/A",
                # "refresh_rows": refresh_result[2] if refresh_result else 0
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
        etl = SupplierBaseETL()
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
        etl = SupplierBaseETL()
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
