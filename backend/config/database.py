import psycopg2
import pandas as pd
from contextlib import contextmanager
import logging
import os
from config.settings import Config

logger = logging.getLogger(__name__)

def get_db_params() -> dict:
    """
    Paramètres de connexion PostgreSQL (host/port/database/user/password) résolus
    depuis les variables d'environnement, avec les défauts historiques qui
    fonctionnent sans .env explicite. Source UNIQUE des identifiants DB : réutilisée
    par get_db_connection ET par l'engine lecture seule de l'IA (ai_readonly_db),
    pour éviter les divergences de mot de passe entre mécanismes de connexion.
    """
    return {
        'host': os.getenv("DB_HOST", "10.190.100.58"),
        'port': os.getenv("DB_PORT", "5432"),
        'database': os.getenv("DB_NAME", "sap_migration_db"),
        'user': os.getenv("DB_USER", "postgres"),
        'password': os.getenv("DB_PASSWORD", "trimet2025"),
    }


def get_etl_db_params() -> dict:
    """
    Paramètres de connexion pour les modules ETL (etl_modules/).

    Ces modules lisaient chacun leur propre jeu de variables ``PG_*`` avec
    ``localhost`` par défaut. Or docker-compose ne transmet PAS ``PG_HOST`` au
    conteneur : tous les chargements échouaient donc sur
    « connection to server at "localhost" (::1), port 5432 failed » — depuis le
    conteneur, localhost désigne le conteneur lui-même, pas le serveur PostgreSQL.

    On repart de get_db_params() (source UNIQUE des identifiants, celle qui fait
    fonctionner le reste de l'application) tout en respectant une surcharge
    ``PG_*`` si elle est explicitement fournie — utile pour exécuter un module
    ETL en direct, hors conteneur.
    """
    params = get_db_params()
    return {
        'host': os.getenv("PG_HOST") or params['host'],
        'port': os.getenv("PG_PORT") or params['port'],
        'database': os.getenv("PG_DATABASE") or params['database'],
        'user': os.getenv("PG_USER") or params['user'],
        'password': os.getenv("PG_PASSWORD") or params['password'],
    }


@contextmanager
def get_db_connection():
    """
    Context manager pour les connexions à la base de données PostgreSQL

    Utilise les paramètres de configuration depuis les variables d'environnement
    """
    connection = None
    try:
        # ✅ Utilise le même hôte que les autres services (10.190.100.58)
        db_params = get_db_params()

        logger.debug(f"🔗 Connexion à la base de données : {db_params['user']}@{db_params['host']}:{db_params['port']}/{db_params['database']}")
        
        # Créer la connexion
        connection = psycopg2.connect(**db_params)
        
        logger.debug("✅ Connexion établie avec succès")
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
            logger.debug("🔒 Connexion fermée")

def test_connection():
    """
    Teste la connexion à la base de données
    
    Returns:
        bool: True si la connexion est réussie, False sinon
    """
    try:
        with get_db_connection() as conn:
            # Test simple avec une requête
            cursor = conn.cursor()
            cursor.execute("SELECT 1")
            result = cursor.fetchone()
            cursor.close()
            
            if result and result[0] == 1:
                logger.info("✅ Test de connexion réussi")
                return True
            else:
                logger.error("❌ Test de connexion échoué - résultat inattendu")
                return False
                
    except Exception as e:
        logger.error(f"❌ Test de connexion échoué: {e}")
        return False

def execute_query(query: str, params=None):
    """
    Exécute une requête SQL et retourne les résultats
    
    Args:
        query (str): Requête SQL à exécuter
        params: Paramètres pour la requête (optionnel)
        
    Returns:
        list: Liste des résultats
    """
    try:
        with get_db_connection() as conn:
            df = pd.read_sql_query(query, conn, params=params)
            return df.to_dict('records')
            
    except Exception as e:
        logger.error(f"❌ Erreur lors de l'exécution de la requête: {e}")
        raise

def get_table_info(table_name: str):
    """
    Récupère les informations sur une table (colonnes, types, etc.)
    
    Args:
        table_name (str): Nom de la table
        
    Returns:
        list: Informations sur les colonnes
    """
    query = """
        SELECT 
            column_name,
            data_type,
            is_nullable,
            column_default
        FROM information_schema.columns 
        WHERE table_name = %s 
        ORDER BY ordinal_position
    """
    
    try:
        return execute_query(query, (table_name,))
    except Exception as e:
        logger.error(f"❌ Erreur lors de la récupération des infos de table {table_name}: {e}")
        return []

def get_table_count(table_name: str) -> int:
    """
    Récupère le nombre de lignes dans une table
    
    Args:
        table_name (str): Nom de la table
        
    Returns:
        int: Nombre de lignes
    """
    query = f"SELECT COUNT(*) as count FROM {table_name}"
    
    try:
        with get_db_connection() as conn:
            cursor = conn.cursor()
            cursor.execute(query)
            result = cursor.fetchone()
            cursor.close()
            return result[0] if result else 0
            
    except Exception as e:
        logger.error(f"❌ Erreur lors du comptage de {table_name}: {e}")
        return 0 