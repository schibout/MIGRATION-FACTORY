#!/usr/bin/env python3
"""
Script d'application de la migration pour le système d'import de fichiers
Applique la migration 004_create_import_system_tables.sql
"""

import os
import sys
import logging
from contextlib import contextmanager
import psycopg2

# Configuration du logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

@contextmanager
def get_db_connection():
    """Context manager pour les connexions à la base de données PostgreSQL"""
    connection = None
    try:
        # Récupérer les paramètres de connexion depuis les variables d'environnement
        db_params = {
            'host': os.getenv("DB_HOST", "10.190.100.58"),
            'port': os.getenv("DB_PORT", "5432"),
            'database': os.getenv("DB_NAME", "sap_migration_db"),
            'user': os.getenv("DB_USER", "postgres"),
            'password': os.getenv("DB_PASSWORD", "trimet2025")
        }
        
        logger.info(f"🔗 Connexion à la base de données : {db_params['user']}@{db_params['host']}:{db_params['port']}/{db_params['database']}")
        
        # Créer la connexion
        connection = psycopg2.connect(**db_params)
        connection.autocommit = True  # Pour les CREATE TABLE, etc.
        
        logger.info("✅ Connexion établie avec succès")
        yield connection
        
    except psycopg2.Error as e:
        logger.error(f"❌ Erreur de connexion PostgreSQL: {e}")
        raise
    except Exception as e:
        logger.error(f"❌ Erreur de connexion inattendue: {e}")
        raise
    finally:
        if connection:
            connection.close()
            logger.info("🔒 Connexion fermée")

def check_tables_exist(cursor):
    """Vérifie si les tables d'import existent déjà"""
    tables_to_check = [
        'import_jobs', 
        'import_details', 
        'file_type_configs', 
        'import_logs', 
        'import_statistics'
    ]
    
    existing_tables = []
    for table in tables_to_check:
        cursor.execute("""
            SELECT EXISTS (
                SELECT FROM information_schema.tables 
                WHERE table_schema = 'public' 
                AND table_name = %s
            );
        """, (table,))
        
        if cursor.fetchone()[0]:
            existing_tables.append(table)
    
    return existing_tables

def apply_migration():
    """Applique la migration 004_create_import_system_tables.sql"""
    
    # Chemin vers le fichier de migration
    migration_file = os.path.join(os.path.dirname(__file__), 'migrations', '004_create_import_system_tables.sql')
    
    if not os.path.exists(migration_file):
        logger.error(f"❌ Fichier de migration introuvable: {migration_file}")
        return False
    
    try:
        with get_db_connection() as connection:
            cursor = connection.cursor()
            
            # Vérifier les tables existantes
            logger.info("🔍 Vérification des tables existantes...")
            existing_tables = check_tables_exist(cursor)
            
            if existing_tables:
                logger.warning(f"⚠️ Tables déjà existantes : {', '.join(existing_tables)}")
                response = input("Continuer avec la migration (les tables existantes ne seront pas modifiées) ? (y/N): ")
                if response.lower() != 'y':
                    logger.info("❌ Migration annulée par l'utilisateur")
                    return False
            
            # Lire et exécuter le fichier de migration
            logger.info(f"📂 Lecture du fichier de migration : {migration_file}")
            with open(migration_file, 'r', encoding='utf-8') as f:
                migration_sql = f.read()
            
            logger.info("🚀 Application de la migration...")
            cursor.execute(migration_sql)
            
            # Vérifier que les tables ont été créées
            logger.info("✅ Vérification des tables créées...")
            final_tables = check_tables_exist(cursor)
            
            expected_tables = {'import_jobs', 'import_details', 'file_type_configs', 'import_logs', 'import_statistics'}
            created_tables = set(final_tables)
            
            if expected_tables.issubset(created_tables):
                logger.info("🎉 Migration appliquée avec succès !")
                logger.info(f"📊 Tables créées : {', '.join(sorted(created_tables & expected_tables))}")
                
                # Vérifier les configurations par défaut
                cursor.execute("SELECT file_type, display_name FROM file_type_configs ORDER BY file_type;")
                configs = cursor.fetchall()
                if configs:
                    logger.info("⚙️ Configurations par défaut créées :")
                    for file_type, display_name in configs:
                        logger.info(f"   - {file_type}: {display_name}")
                
                return True
            else:
                missing = expected_tables - created_tables
                logger.error(f"❌ Tables manquantes après migration : {', '.join(missing)}")
                return False
                
    except Exception as e:
        logger.error(f"❌ Erreur lors de l'application de la migration: {e}")
        return False

def main():
    """Point d'entrée principal"""
    logger.info("🔄 Début de l'application de la migration du système d'import")
    
    success = apply_migration()
    
    if success:
        logger.info("✅ Migration terminée avec succès !")
        logger.info("🎯 Prochaines étapes :")
        logger.info("   1. Vérifier les tables créées dans la base de données")
        logger.info("   2. Passer à la tâche suivante : Développer Services Backend d'Import")
        sys.exit(0)
    else:
        logger.error("❌ Échec de la migration !")
        sys.exit(1)

if __name__ == "__main__":
    main() 