#!/usr/bin/env python
# -*- coding: utf-8 -*-

"""
Module ETL pour le chargement des données projets depuis SharePoint.
Utilise les fonctions stockées clean_data.alimenter_ifs_project_*.
"""

import os
import sys
import time
import logging
import psycopg2
import psycopg2.extensions
from sqlalchemy import create_engine, text, event
from dotenv import load_dotenv

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
        log_file = os.path.join(log_dir, 'etl_project.log')
        
        # Vérifier les permissions d'écriture avant d'essayer de créer le fichier
        if os.access(log_dir, os.W_OK):
            log_handlers.append(logging.FileHandler(log_file))
        else:
            raise PermissionError(f"Pas de permission d'écriture dans {log_dir}")
            
    except (OSError, PermissionError) as e:
        print(f"Impossible d'écrire dans le répertoire logs: {e}")
        try:
            # Fallback vers /tmp si disponible
            temp_log_file = '/tmp/etl_project.log'
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

class ProjectETL:
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
        Exécution du processus ETL avec psycopg2 pour capturer les logs PostgreSQL
        """
        start_time = time.time()
        start_datetime = time.strftime('%Y-%m-%d %H:%M:%S')
        logger.info(f"Démarrage du processus ETL projets - {start_datetime}")
        self._add_log_message(f"🚀 Démarrage du processus ETL projets SharePoint → IFS - {start_datetime}", "info")
        self._add_log_message("📊 Traitement séquentiel des données projets SharePoint", "info")
        
        # Compteur d'étapes
        step_counter = 0
        total_steps = 8
        
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
                    # 1. Alimenter PROJECT_BASE
                    step_counter += 1
                    step_start = time.time()
                    step_datetime = time.strftime('%Y-%m-%d %H:%M:%S')
                    logger.info(f"Étape {step_counter}/{total_steps} - Appel de la fonction clean_data.alimenter_ifs_project_base - {step_datetime}")
                    self._add_log_message(f"📋 Étape {step_counter}/{total_steps} - Alimentation PROJECT_BASE depuis SharePoint - {step_datetime}", "info")
                    try:
                        cursor.execute("SELECT clean_data.alimenter_ifs_project_base();")
                        step_duration = time.time() - step_start
                        logger.info(f"✅ Fonction alimenter_ifs_project_base exécutée avec succès en {step_duration:.2f}s")
                        self._add_log_message(f"✅ PROJECT_BASE alimenté avec succès ({step_duration:.2f}s)", "success")
                    except Exception as proc_error:
                        step_duration = time.time() - step_start
                        error_msg = f"Erreur lors de l'alimentation PROJECT_BASE: {str(proc_error)}"
                        logger.error(error_msg)
                        self._add_log_message(f"❌ {error_msg} ({step_duration:.2f}s)", "error")
                        raise
                    
                    # Capturer les notices
                    for notice in conn_psycopg2.notices:
                        notice_text = notice.strip()
                        logger.info(f"PostgreSQL: {notice_text}")
                        self._add_log_message(notice_text, "info")
                    conn_psycopg2.notices[:] = []
                    
                    # 2. Alimenter PROJECT_SITE_EXT
                    step_counter += 1
                    step_start = time.time()
                    step_datetime = time.strftime('%Y-%m-%d %H:%M:%S')
                    logger.info(f"Étape {step_counter}/{total_steps} - Appel de la fonction clean_data.alimenter_ifs_project_site_ext - {step_datetime}")
                    self._add_log_message(f"🏢 Étape {step_counter}/{total_steps} - Alimentation PROJECT_SITE_EXT - {step_datetime}", "info")
                    try:
                        cursor.execute("SELECT clean_data.alimenter_ifs_project_site_ext();")
                        step_duration = time.time() - step_start
                        logger.info(f"✅ Fonction alimenter_ifs_project_site_ext exécutée avec succès en {step_duration:.2f}s")
                        self._add_log_message(f"✅ PROJECT_SITE_EXT alimenté avec succès ({step_duration:.2f}s)", "success")
                    except Exception as proc_error:
                        step_duration = time.time() - step_start
                        error_msg = f"Erreur lors de l'alimentation PROJECT_SITE_EXT: {str(proc_error)}"
                        logger.error(error_msg)
                        self._add_log_message(f"❌ {error_msg} ({step_duration:.2f}s)", "error")
                        raise
                    
                    # Capturer les notices
                    for notice in conn_psycopg2.notices:
                        notice_text = notice.strip()
                        logger.info(f"PostgreSQL: {notice_text}")
                        self._add_log_message(notice_text, "info")
                    conn_psycopg2.notices[:] = []
                    
                    # 3. Alimenter PROJECT_ROLE
                    step_counter += 1
                    step_start = time.time()
                    step_datetime = time.strftime('%Y-%m-%d %H:%M:%S')
                    logger.info(f"Étape {step_counter}/{total_steps} - Appel de la fonction clean_data.alimenter_ifs_project_role - {step_datetime}")
                    self._add_log_message(f"👥 Étape {step_counter}/{total_steps} - Alimentation PROJECT_ROLE - {step_datetime}", "info")
                    try:
                        cursor.execute("SELECT clean_data.alimenter_ifs_project_role();")
                        step_duration = time.time() - step_start
                        logger.info(f"✅ Fonction alimenter_ifs_project_role exécutée avec succès en {step_duration:.2f}s")
                        self._add_log_message(f"✅ PROJECT_ROLE alimenté avec succès ({step_duration:.2f}s)", "success")
                    except Exception as proc_error:
                        step_duration = time.time() - step_start
                        error_msg = f"Erreur lors de l'alimentation PROJECT_ROLE: {str(proc_error)}"
                        logger.error(error_msg)
                        self._add_log_message(f"❌ {error_msg} ({step_duration:.2f}s)", "error")
                        raise
                    
                    # Capturer les notices
                    for notice in conn_psycopg2.notices:
                        notice_text = notice.strip()
                        logger.info(f"PostgreSQL: {notice_text}")
                        self._add_log_message(notice_text, "info")
                    conn_psycopg2.notices[:] = []
                    
                    # 4. Alimenter PROJECT_ROLE_ASSIGNMENT
                    step_counter += 1
                    step_start = time.time()
                    step_datetime = time.strftime('%Y-%m-%d %H:%M:%S')
                    logger.info(f"Étape {step_counter}/{total_steps} - Appel de la fonction clean_data.alimenter_ifs_project_role_assignment - {step_datetime}")
                    self._add_log_message(f"🔗 Étape {step_counter}/{total_steps} - Alimentation PROJECT_ROLE_ASSIGNMENT - {step_datetime}", "info")
                    try:
                        cursor.execute("SELECT clean_data.alimenter_ifs_project_role_assignment();")
                        step_duration = time.time() - step_start
                        logger.info(f"✅ Fonction alimenter_ifs_project_role_assignment exécutée avec succès en {step_duration:.2f}s")
                        self._add_log_message(f"✅ PROJECT_ROLE_ASSIGNMENT alimenté avec succès ({step_duration:.2f}s)", "success")
                    except Exception as proc_error:
                        step_duration = time.time() - step_start
                        error_msg = f"Erreur lors de l'alimentation PROJECT_ROLE_ASSIGNMENT: {str(proc_error)}"
                        logger.error(error_msg)
                        self._add_log_message(f"❌ {error_msg} ({step_duration:.2f}s)", "error")
                        raise
                    
                    # Capturer les notices
                    for notice in conn_psycopg2.notices:
                        notice_text = notice.strip()
                        logger.info(f"PostgreSQL: {notice_text}")
                        self._add_log_message(notice_text, "info")
                    conn_psycopg2.notices[:] = []
                    
                    # 5. Alimenter SUB_PROJECT
                    step_counter += 1
                    step_start = time.time()
                    step_datetime = time.strftime('%Y-%m-%d %H:%M:%S')
                    logger.info(f"Étape {step_counter}/{total_steps} - Appel de la fonction clean_data.alimenter_sub_project - {step_datetime}")
                    self._add_log_message(f"📁 Étape {step_counter}/{total_steps} - Alimentation SUB_PROJECT - {step_datetime}", "info")
                    try:
                        cursor.execute("SELECT clean_data.alimenter_sub_project();")
                        step_duration = time.time() - step_start
                        logger.info(f"✅ Fonction alimenter_sub_project exécutée avec succès en {step_duration:.2f}s")
                        self._add_log_message(f"✅ SUB_PROJECT alimenté avec succès ({step_duration:.2f}s)", "success")
                    except Exception as proc_error:
                        step_duration = time.time() - step_start
                        error_msg = f"Erreur lors de l'alimentation SUB_PROJECT: {str(proc_error)}"
                        logger.error(error_msg)
                        self._add_log_message(f"❌ {error_msg} ({step_duration:.2f}s)", "error")
                        raise
                    
                    # Capturer les notices
                    for notice in conn_psycopg2.notices:
                        notice_text = notice.strip()
                        logger.info(f"PostgreSQL: {notice_text}")
                        self._add_log_message(notice_text, "info")
                    conn_psycopg2.notices[:] = []
                    
                    # 6. Alimenter ACTIVITY
                    step_counter += 1
                    step_start = time.time()
                    step_datetime = time.strftime('%Y-%m-%d %H:%M:%S')
                    logger.info(f"Étape {step_counter}/{total_steps} - Appel de la fonction clean_data.alimenter_activity - {step_datetime}")
                    self._add_log_message(f"📅 Étape {step_counter}/{total_steps} - Alimentation ACTIVITY - {step_datetime}", "info")
                    try:
                        cursor.execute("SELECT clean_data.alimenter_activity();")
                        step_duration = time.time() - step_start
                        logger.info(f"✅ Fonction alimenter_activity exécutée avec succès en {step_duration:.2f}s")
                        self._add_log_message(f"✅ ACTIVITY alimenté avec succès ({step_duration:.2f}s)", "success")
                    except Exception as proc_error:
                        step_duration = time.time() - step_start
                        error_msg = f"Erreur lors de l'alimentation ACTIVITY: {str(proc_error)}"
                        logger.error(error_msg)
                        self._add_log_message(f"❌ {error_msg} ({step_duration:.2f}s)", "error")
                        raise
                    
                    # Capturer les notices
                    for notice in conn_psycopg2.notices:
                        notice_text = notice.strip()
                        logger.info(f"PostgreSQL: {notice_text}")
                        self._add_log_message(notice_text, "info")
                    conn_psycopg2.notices[:] = []
                    
                    # 7. Alimenter PROJECT_ACTIVITY
                    step_counter += 1
                    step_start = time.time()
                    step_datetime = time.strftime('%Y-%m-%d %H:%M:%S')
                    logger.info(f"Étape {step_counter}/{total_steps} - Appel de la fonction clean_data.alimenter_project_activity - {step_datetime}")
                    self._add_log_message(f"📅 Étape {step_counter}/{total_steps} - Alimentation PROJECT_ACTIVITY - {step_datetime}", "info")
                    try:
                        cursor.execute("SELECT clean_data.alimenter_project_activity();")
                        step_duration = time.time() - step_start
                        logger.info(f"✅ Fonction alimenter_project_activity exécutée avec succès en {step_duration:.2f}s")
                        self._add_log_message(f"✅ PROJECT_ACTIVITY alimenté avec succès ({step_duration:.2f}s)", "success")
                    except Exception as proc_error:
                        step_duration = time.time() - step_start
                        error_msg = f"Erreur lors de l'alimentation PROJECT_ACTIVITY: {str(proc_error)}"
                        logger.error(error_msg)
                        self._add_log_message(f"❌ {error_msg} ({step_duration:.2f}s)", "error")
                        raise

                    # Capturer les notices
                    for notice in conn_psycopg2.notices:
                        notice_text = notice.strip()
                        logger.info(f"PostgreSQL: {notice_text}")
                        self._add_log_message(notice_text, "info")
                    conn_psycopg2.notices[:] = []

                    # 8. Alimenter PROJECT_ACTIVITY_CLASS
                    step_counter += 1
                    step_start = time.time()
                    step_datetime = time.strftime('%Y-%m-%d %H:%M:%S')
                    logger.info(f"Étape {step_counter}/{total_steps} - Appel de la fonction clean_data.alimenter_project_activity_class - {step_datetime}")
                    self._add_log_message(f"🏷️ Étape {step_counter}/{total_steps} - Alimentation PROJECT_ACTIVITY_CLASS - {step_datetime}", "info")
                    try:
                        cursor.execute("SELECT clean_data.alimenter_project_activity_class();")
                        step_duration = time.time() - step_start
                        logger.info(f"✅ Fonction alimenter_project_activity_class exécutée avec succès en {step_duration:.2f}s")
                        self._add_log_message(f"✅ PROJECT_ACTIVITY_CLASS alimenté avec succès ({step_duration:.2f}s)", "success")
                    except Exception as proc_error:
                        step_duration = time.time() - step_start
                        error_msg = f"Erreur lors de l'alimentation PROJECT_ACTIVITY_CLASS: {str(proc_error)}"
                        logger.error(error_msg)
                        self._add_log_message(f"❌ {error_msg} ({step_duration:.2f}s)", "error")
                        raise

                    # Capturer les notices
                    for notice in conn_psycopg2.notices:
                        notice_text = notice.strip()
                        logger.info(f"PostgreSQL: {notice_text}")
                        self._add_log_message(notice_text, "info")
                    conn_psycopg2.notices[:] = []

            conn_psycopg2.close()
            
            execution_time = time.time() - start_time
            end_datetime = time.strftime('%Y-%m-%d %H:%M:%S')
            logger.info(f"🎉 Processus ETL projets terminé - {end_datetime} - Durée totale: {execution_time:.2f} secondes")
            self._add_log_message(f"🎉 Processus ETL projets terminé avec succès - {end_datetime}", "success")
            self._add_log_message(f"⏱️ Durée totale d'exécution: {execution_time:.2f} secondes", "info")
            self._add_log_message(f"📊 Toutes les tables projets IFS ont été alimentées avec succès ({total_steps} étapes)", "success")
            self._add_log_message("✅ Tables alimentées: PROJECT_BASE, PROJECT_SITE_EXT, PROJECT_ROLE, PROJECT_ROLE_ASSIGNMENT, SUB_PROJECT, ACTIVITY, PROJECT_ACTIVITY, PROJECT_ACTIVITY_CLASS", "info")

            return {
                "success": True,
                "execution_time_seconds": execution_time,
                "log_messages": self.log_messages,
                "tables_updated": ["PROJECT_BASE", "PROJECT_SITE_EXT", "PROJECT_ROLE", "PROJECT_ROLE_ASSIGNMENT", "SUB_PROJECT", "ACTIVITY", "PROJECT_ACTIVITY", "PROJECT_ACTIVITY_CLASS"]
            }

        except Exception as e:
            execution_time = time.time() - start_time
            error_msg = f"Erreur lors du processus ETL projets: {str(e)}"
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
        Exécution du processus ETL via les fonctions stockées
        """
        start_time = time.time()
        logger.info("Démarrage du processus ETL projets via fonctions stockées")
        
        try:
            with self.pg_engine.connect() as conn:
                with conn.begin():
                    # 1. Alimenter PROJECT_BASE
                    logger.info("Appel de la fonction clean_data.alimenter_ifs_project_base")
                    conn.execute(text("SELECT clean_data.alimenter_ifs_project_base()"))
                    logger.info("Fonction alimenter_ifs_project_base exécutée avec succès")
                    
                    # Capturer les notices PostgreSQL
                    self._capture_postgres_notices(conn)
                    
                    # 2. Alimenter PROJECT_SITE_EXT
                    logger.info("Appel de la fonction clean_data.alimenter_ifs_project_site_ext")
                    conn.execute(text("SELECT clean_data.alimenter_ifs_project_site_ext()"))
                    logger.info("Fonction alimenter_ifs_project_site_ext exécutée avec succès")
                    
                    # Capturer les notices PostgreSQL
                    self._capture_postgres_notices(conn)
                    
                    # 3. Alimenter ACTIVITY
                    logger.info("Appel de la fonction clean_data.alimenter_activity")
                    conn.execute(text("SELECT clean_data.alimenter_activity()"))
                    logger.info("Fonction alimenter_activity exécutée avec succès")
                    
                    # Capturer les notices PostgreSQL
                    self._capture_postgres_notices(conn)
            
            execution_time = time.time() - start_time
            logger.info(f"Processus ETL projets terminé en {execution_time:.2f} secondes")
            self._add_log_message(f"✅ Processus ETL projets terminé avec succès en {execution_time:.2f} secondes", "success")
            
            return {
                "success": True,
                "execution_time_seconds": execution_time,
                "log_messages": self.log_messages,
                "tables_updated": ["PROJECT_BASE", "PROJECT_SITE_EXT", "PROJECT_ROLE", "PROJECT_ROLE_ASSIGNMENT", "SUB_PROJECT", "ACTIVITY", "PROJECT_ACTIVITY", "PROJECT_ACTIVITY_CLASS"]
            }

        except Exception as e:
            execution_time = time.time() - start_time
            error_msg = f"Erreur lors du processus ETL projets: {str(e)}"
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
        etl = ProjectETL()
        # Utiliser la version avec capture de logs PostgreSQL
        result = etl.run_etl_with_psycopg2_logs()
        return result
    except Exception as e:
        logger.error(f"Erreur dans le processus ETL projets: {str(e)}")
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
        etl = ProjectETL()
        # Utiliser la version avec capture de logs pour le test direct
        result = etl.run_etl_with_psycopg2_logs()
        
        if result["success"]:
            print(f"Traitement ETL projets terminé avec succès")
            print(f"Temps d'exécution: {result['execution_time_seconds']:.2f} secondes")
            print(f"Tables mises à jour: {', '.join(result.get('tables_updated', []))}")
            exit(0)
        else:
            print(f"Erreur: {result.get('error', 'Une erreur inconnue est survenue')}")
            exit(1)
    except Exception as e:
        print(f"Erreur: {str(e)}")
        exit(1)
