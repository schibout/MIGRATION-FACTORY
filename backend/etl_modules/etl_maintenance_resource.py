#!/usr/bin/env python
# -*- coding: utf-8 -*-

"""
Module ETL pour le chargement des données de maintenance (RESOURCE).
Utilise les procédures stockées clean_data.populate_* pour alimenter les tables:
- ifs_person
- resource_detail_file
- resource_connection
- resource_availability
- resource_parent
- maint_person_resource
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
        log_file = os.path.join(log_dir, 'etl_maintenance_resource.log')
        
        # Vérifier les permissions d'écriture avant d'essayer de créer le fichier
        if os.access(log_dir, os.W_OK):
            log_handlers.append(logging.FileHandler(log_file))
        else:
            raise PermissionError(f"Pas de permission d'écriture dans {log_dir}")
            
    except (OSError, PermissionError) as e:
        print(f"Impossible d'écrire dans le répertoire logs: {e}")
        try:
            # Fallback vers /tmp si disponible
            temp_log_file = '/tmp/etl_maintenance_resource.log'
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

class MaintenanceResourceETL:
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
        logger.info(f"Démarrage du processus ETL Maintenance Resource - {start_datetime}")
        self._add_log_message(f"🚀 Démarrage du processus ETL Maintenance Resource - {start_datetime}", "info")
        self._add_log_message("📊 Traitement séquentiel des données de ressources de maintenance", "info")
        
        # Compteur d'étapes
        step_counter = 0
        total_steps = 6
        
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
                    # 1. Alimenter les personnes IFS
                    step_counter += 1
                    step_start = time.time()
                    step_datetime = time.strftime('%Y-%m-%d %H:%M:%S')
                    logger.info(f"Étape {step_counter}/{total_steps} - Appel de la procédure clean_data.populate_ifs_person - {step_datetime}")
                    self._add_log_message(f"👤 Étape {step_counter}/{total_steps} - Alimentation des personnes IFS - {step_datetime}", "info")
                    try:
                        cursor.execute("CALL clean_data.populate_ifs_person()")
                        step_duration = time.time() - step_start
                        logger.info(f"Procédure populate_ifs_person exécutée avec succès en {step_duration:.2f}s")
                        self._add_log_message(f"✅ Personnes IFS alimentées avec succès en {step_duration:.2f}s", "success")
                    except Exception as proc_error:
                        error_msg = f"Erreur à l'étape {step_counter}/{total_steps} (populate_ifs_person): {str(proc_error)}"
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
                    
                    # 2. Alimenter les détails des ressources
                    step_counter += 1
                    step_start = time.time()
                    step_datetime = time.strftime('%Y-%m-%d %H:%M:%S')
                    logger.info(f"Étape {step_counter}/{total_steps} - Appel de la procédure clean_data.populate_resource_detail_file - {step_datetime}")
                    self._add_log_message(f"📋 Étape {step_counter}/{total_steps} - Alimentation des détails des ressources - {step_datetime}", "info")
                    try:
                        cursor.execute("CALL clean_data.populate_resource_detail_file()")
                        step_duration = time.time() - step_start
                        logger.info(f"Procédure populate_resource_detail_file exécutée avec succès en {step_duration:.2f}s")
                        self._add_log_message(f"✅ Détails des ressources alimentés avec succès en {step_duration:.2f}s", "success")
                    except Exception as proc_error:
                        error_msg = f"Erreur à l'étape {step_counter}/{total_steps} (populate_resource_detail_file): {str(proc_error)}"
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
                    
                    # 3. Alimenter les connexions des ressources
                    step_counter += 1
                    step_start = time.time()
                    step_datetime = time.strftime('%Y-%m-%d %H:%M:%S')
                    logger.info(f"Étape {step_counter}/{total_steps} - Appel de la procédure clean_data.populate_resource_connection - {step_datetime}")
                    self._add_log_message(f"🔗 Étape {step_counter}/{total_steps} - Alimentation des connexions des ressources - {step_datetime}", "info")
                    try:
                        cursor.execute("CALL clean_data.populate_resource_connection()")
                        step_duration = time.time() - step_start
                        logger.info(f"Procédure populate_resource_connection exécutée avec succès en {step_duration:.2f}s")
                        self._add_log_message(f"✅ Connexions des ressources alimentées avec succès en {step_duration:.2f}s", "success")
                    except Exception as proc_error:
                        error_msg = f"Erreur à l'étape {step_counter}/{total_steps} (populate_resource_connection): {str(proc_error)}"
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
                    
                    # 4. Alimenter la disponibilité des ressources
                    step_counter += 1
                    step_start = time.time()
                    step_datetime = time.strftime('%Y-%m-%d %H:%M:%S')
                    logger.info(f"Étape {step_counter}/{total_steps} - Appel de la procédure clean_data.populate_resource_availability - {step_datetime}")
                    self._add_log_message(f"📅 Étape {step_counter}/{total_steps} - Alimentation de la disponibilité des ressources - {step_datetime}", "info")
                    try:
                        cursor.execute("CALL clean_data.populate_resource_availability()")
                        step_duration = time.time() - step_start
                        logger.info(f"Procédure populate_resource_availability exécutée avec succès en {step_duration:.2f}s")
                        self._add_log_message(f"✅ Disponibilité des ressources alimentée avec succès en {step_duration:.2f}s", "success")
                    except Exception as proc_error:
                        error_msg = f"Erreur à l'étape {step_counter}/{total_steps} (populate_resource_availability): {str(proc_error)}"
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
                    
                    # 5. Alimenter la hiérarchie des ressources parentes
                    step_counter += 1
                    step_start = time.time()
                    step_datetime = time.strftime('%Y-%m-%d %H:%M:%S')
                    logger.info(f"Étape {step_counter}/{total_steps} - Appel de la procédure clean_data.populate_resource_parent - {step_datetime}")
                    self._add_log_message(f"🏠 Étape {step_counter}/{total_steps} - Alimentation de la hiérarchie des ressources parentes - {step_datetime}", "info")
                    try:
                        cursor.execute("CALL clean_data.populate_resource_parent()")
                        step_duration = time.time() - step_start
                        logger.info(f"Procédure populate_resource_parent exécutée avec succès en {step_duration:.2f}s")
                        self._add_log_message(f"✅ Hiérarchie des ressources parentes alimentée avec succès en {step_duration:.2f}s", "success")
                    except Exception as proc_error:
                        error_msg = f"Erreur à l'étape {step_counter}/{total_steps} (populate_resource_parent): {str(proc_error)}"
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
                    
                    # 6. Alimenter les ressources de maintenance par personne
                    step_counter += 1
                    step_start = time.time()
                    step_datetime = time.strftime('%Y-%m-%d %H:%M:%S')
                    logger.info(f"Étape {step_counter}/{total_steps} - Appel de la procédure clean_data.populate_maint_person_resource - {step_datetime}")
                    self._add_log_message(f"🔧 Étape {step_counter}/{total_steps} - Alimentation des ressources de maintenance par personne - {step_datetime}", "info")
                    try:
                        cursor.execute("CALL clean_data.populate_maint_person_resource()")
                        step_duration = time.time() - step_start
                        logger.info(f"Procédure populate_maint_person_resource exécutée avec succès en {step_duration:.2f}s")
                        self._add_log_message(f"✅ Ressources de maintenance par personne alimentées avec succès en {step_duration:.2f}s", "success")
                    except Exception as proc_error:
                        error_msg = f"Erreur à l'étape {step_counter}/{total_steps} (populate_maint_person_resource): {str(proc_error)}"
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
            logger.info(f"🎉 Processus ETL Maintenance Resource terminé - {end_datetime} - Durée totale: {execution_time:.2f} secondes")
            self._add_log_message(f"🎉 Processus ETL Maintenance Resource terminé avec succès - {end_datetime}", "success")
            self._add_log_message(f"⏱️ Durée totale d'exécution: {execution_time:.2f} secondes", "info")
            self._add_log_message(f"📊 Toutes les données de ressources de maintenance ont été traitées avec succès ({total_steps} étapes)", "success")
            
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

    def run_etl_all_tables(self):
        """
        Version simplifiée utilisant populate_all_tables
        """
        start_time = time.time()
        start_datetime = time.strftime('%Y-%m-%d %H:%M:%S')
        logger.info(f"Démarrage du processus ETL Maintenance Resource (all tables) - {start_datetime}")
        self._add_log_message(f"🚀 Démarrage du processus ETL Maintenance Resource - {start_datetime}", "info")
        
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
                    logger.info("Appel de la procédure clean_data.populate_all_tables")
                    self._add_log_message("📊 Appel de populate_all_tables (toutes les tables de ressources)", "info")
                    
                    cursor.execute("CALL clean_data.populate_all_tables()")
                    
                    # Capturer les notices
                    for notice in conn_psycopg2.notices:
                        notice_text = notice.strip()
                        logger.info(f"PostgreSQL NOTICE: {notice_text}")
                        self._add_log_message(notice_text, "info")
                    conn_psycopg2.notices[:] = []
            
            conn_psycopg2.close()
            
            execution_time = time.time() - start_time
            end_datetime = time.strftime('%Y-%m-%d %H:%M:%S')
            logger.info(f"🎉 Processus ETL terminé - {end_datetime} - Durée: {execution_time:.2f}s")
            self._add_log_message(f"🎉 Processus ETL terminé avec succès - {end_datetime}", "success")
            self._add_log_message(f"⏱️ Durée totale: {execution_time:.2f} secondes", "info")
            
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
        return self.run_etl_with_psycopg2_logs()

def run_etl():
    """
    Fonction de compatibilité pour l'interface ETL existante
    """
    try:
        etl = MaintenanceResourceETL()
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
        etl = MaintenanceResourceETL()
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
