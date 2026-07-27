#!/usr/bin/env python
# -*- coding: utf-8 -*-

"""
Module ETL simplifié pour le chargement des données articles d'inventaire.
Utilise la fonction stockée clean_data.alimenter_part_catalog.
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
        log_file = os.path.join(log_dir, 'etl_inventory_part.log')
        
        # Vérifier les permissions d'écriture avant d'essayer de créer le fichier
        if os.access(log_dir, os.W_OK):
            log_handlers.append(logging.FileHandler(log_file))
        else:
            raise PermissionError(f"Pas de permission d'écriture dans {log_dir}")
            
    except (OSError, PermissionError) as e:
        print(f"Impossible d'écrire dans le répertoire logs: {e}")
        try:
            # Fallback vers /tmp si disponible
            temp_log_file = '/tmp/etl_inventory_part.log'
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

class InventoryPartETL:
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
        Version avec psycopg2 pour capturer les logs PostgreSQL
        """
        start_time = time.time()
        logger.info("Démarrage du processus ETL articles d'inventaire avec capture de logs PostgreSQL")
        self._add_log_message("Démarrage du processus ETL articles d'inventaire", "info")
        
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
                    # Alimenter ifs_article_maitre
                    logger.info("Appel de la fonction clean_data.alimenter_ifs_article")
                    self._add_log_message("Alimentation de ifs_article_maitre...", "info")
                    cursor.execute("SELECT clean_data.alimenter_ifs_article()")
                    logger.info("Fonction alimenter_ifs_article exécutée avec succès")
                    self._add_log_message("✅ ifs_article_maitre alimenté avec succès", "success")
                    
                    # Alimenter part_catalog
                    logger.info("Appel de la fonction clean_data.alimenter_part_catalog")
                    self._add_log_message("Alimentation de part_catalog...", "info")
                    cursor.execute("SELECT clean_data.alimenter_part_catalog()")
                    logger.info("Fonction alimenter_part_catalog exécutée avec succès")
                    self._add_log_message("✅ part_catalog alimenté avec succès", "success")
                    
                    # Alimenter inventory_part
                    logger.info("Appel de la fonction clean_data.alimenter_inventory_part")
                    self._add_log_message("Alimentation de inventory_part...", "info")
                    cursor.execute("SELECT clean_data.alimenter_inventory_part()")
                    logger.info("Fonction alimenter_inventory_part exécutée avec succès")
                    self._add_log_message("✅ inventory_part alimenté avec succès", "success")
                    
                    # Alimenter inventory_part_planning
                    logger.info("Appel de la fonction clean_data.alimenter_inventory_part_planning")
                    self._add_log_message("Alimentation de inventory_part_planning...", "info")
                    cursor.execute("SELECT clean_data.alimenter_inventory_part_planning()")
                    logger.info("Fonction alimenter_inventory_part_planning exécutée avec succès")
                    self._add_log_message("✅ inventory_part_planning alimenté avec succès", "success")
                    
                    # Alimenter purchase_part
                    logger.info("Appel de la fonction clean_data.alimenter_purchase_part")
                    self._add_log_message("Alimentation de purchase_part...", "info")
                    cursor.execute("SELECT clean_data.alimenter_purchase_part()")
                    logger.info("Fonction alimenter_purchase_part exécutée avec succès")
                    self._add_log_message("✅ purchase_part alimenté avec succès", "success")
                    
                    # Alimenter purchase_part_supplier
                    logger.info("Appel de la fonction clean_data.alimenter_purchase_part_supplier")
                    self._add_log_message("Alimentation de purchase_part_supplier...", "info")
                    cursor.execute("SELECT clean_data.alimenter_purchase_part_supplier()")
                    logger.info("Fonction alimenter_purchase_part_supplier exécutée avec succès")
                    self._add_log_message("✅ purchase_part_supplier alimenté avec succès", "success")
                    
                    # Alimenter sales_part
                    logger.info("Appel de la fonction clean_data.alimenter_sales_part")
                    self._add_log_message("Alimentation de sales_part...", "info")
                    cursor.execute("SELECT clean_data.alimenter_sales_part()")
                    logger.info("Fonction alimenter_sales_part exécutée avec succès")
                    self._add_log_message("✅ sales_part alimenté avec succès", "success")
                    
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
        Exécution du processus ETL via les fonctions stockées
        """
        start_time = time.time()
        logger.info("Démarrage du processus ETL via fonctions stockées")
        
        try:
            with self.pg_engine.connect() as conn:
                with conn.begin():
                    # Alimenter ifs_article_maitre
                    logger.info("Appel de la fonction clean_data.alimenter_ifs_article")
                    conn.execute(text("SELECT clean_data.alimenter_ifs_article()"))
                    logger.info("Fonction alimenter_ifs_article exécutée avec succès")
                    
                    # Alimenter part_catalog
                    logger.info("Appel de la fonction clean_data.alimenter_part_catalog")
                    conn.execute(text("SELECT clean_data.alimenter_part_catalog()"))
                    logger.info("Fonction alimenter_part_catalog exécutée avec succès")
                    
                    # Alimenter inventory_part
                    logger.info("Appel de la fonction clean_data.alimenter_inventory_part")
                    conn.execute(text("SELECT clean_data.alimenter_inventory_part()"))
                    logger.info("Fonction alimenter_inventory_part exécutée avec succès")
                    
                    # Alimenter inventory_part_planning
                    logger.info("Appel de la fonction clean_data.alimenter_inventory_part_planning")
                    conn.execute(text("SELECT clean_data.alimenter_inventory_part_planning()"))
                    logger.info("Fonction alimenter_inventory_part_planning exécutée avec succès")
                    
                    # Alimenter purchase_part
                    logger.info("Appel de la fonction clean_data.alimenter_purchase_part")
                    conn.execute(text("SELECT clean_data.alimenter_purchase_part()"))
                    logger.info("Fonction alimenter_purchase_part exécutée avec succès")
                    
                    # Alimenter purchase_part_supplier
                    logger.info("Appel de la fonction clean_data.alimenter_purchase_part_supplier")
                    conn.execute(text("SELECT clean_data.alimenter_purchase_part_supplier()"))
                    logger.info("Fonction alimenter_purchase_part_supplier exécutée avec succès")
                    
                    # Alimenter sales_part
                    logger.info("Appel de la fonction clean_data.alimenter_sales_part")
                    conn.execute(text("SELECT clean_data.alimenter_sales_part()"))
                    logger.info("Fonction alimenter_sales_part exécutée avec succès")
                    
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
        etl = InventoryPartETL()
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
        etl = InventoryPartETL()
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
