#!/usr/bin/env python3
"""
Script de test pour valider le nouveau système d'import brut de données
"""

import os
import sys
import pandas as pd
from datetime import datetime
import psycopg2.extras
import logging

# Ajouter le chemin du backend
sys.path.append(os.path.dirname(os.path.abspath(__file__)))

from services.file_processors import RawDataProcessor
from config.database import get_db_connection

# Configuration des logs
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

def test_raw_data_processor():
    """Test du nouveau processeur RawDataProcessor"""
    
    print("🧪 Test du RawDataProcessor")
    print("=" * 50)
    
    # Configuration du processeur
    config = {
        'separator': ';',
        'encoding': 'utf-8',
        'has_header': True,
        'skip_rows': 0,
        'target_table': 'customer_info',
        'target_schema': 'raw_data'
    }
    
    # Création du processeur
    processor = RawDataProcessor(config)
    
    # Chemin vers le fichier de test
    test_file = "../importfichiers/customer info.csv"
    
    if not os.path.exists(test_file):
        print(f"❌ Fichier de test introuvable: {test_file}")
        return False, None, None
    
    try:
        # Traitement du fichier
        print(f"📁 Traitement du fichier: {test_file}")
        df, stats = processor.process_file(test_file)
        
        print(f"✅ Fichier traité avec succès!")
        print(f"   📊 Statistiques:")
        print(f"      - Lignes totales: {stats['total_rows']}")
        print(f"      - Lignes traitées: {stats['processed_rows']}")
        print(f"      - Lignes réussies: {stats['success_rows']}")
        print(f"      - Lignes en erreur: {stats['error_rows']}")
        
        print(f"   📋 Colonnes du DataFrame:")
        for i, col in enumerate(df.columns, 1):
            print(f"      {i:2d}. {col}")
        
        print(f"\n   📄 Aperçu des données (5 premières lignes):")
        print(df.head().to_string())
        
        return True, df, stats
        
    except Exception as e:
        print(f"❌ Erreur lors du traitement: {e}")
        return False, None, None

def test_database_connection():
    """Test de la connexion à la base de données"""
    
    print("\n🔌 Test de la connexion base de données")
    print("=" * 50)
    
    try:
        with get_db_connection() as conn:
            cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
            
            # Test de base
            cursor.execute("SELECT 1 as test")
            result = cursor.fetchone()
            
            if result and result['test'] == 1:
                print("✅ Connexion base de données OK")
                
                # Vérifier si la table raw_data.customer_info existe
                cursor.execute("""
                    SELECT EXISTS (
                        SELECT FROM information_schema.tables 
                        WHERE table_schema = 'raw_data' 
                        AND table_name = 'customer_info'
                    );
                """)
                
                table_exists = cursor.fetchone()['exists']
                
                if table_exists:
                    print("✅ Table raw_data.customer_info existe")
                    
                    # Compter les lignes existantes
                    cursor.execute("SELECT COUNT(*) as count FROM raw_data.customer_info")
                    count = cursor.fetchone()['count']
                    print(f"📊 Lignes existantes dans la table: {count}")
                    
                else:
                    print("⚠️  Table raw_data.customer_info n'existe pas encore")
                    print("   → Exécutez la migration 005_simplify_file_configs.sql")
                
                return True
            else:
                print("❌ Problème avec la connexion")
                return False
                
    except Exception as e:
        print(f"❌ Erreur de connexion: {e}")
        return False

def insert_successful_records(target_table: str, target_schema: str, 
                             successful_records: list) -> int:
    """
    Insère les enregistrements validés dans la table cible
    Utilise la même méthode que import_service.py
    
    Returns:
        Nombre d'enregistrements insérés
    """
    if not successful_records:
        return 0
    
    try:
        with get_db_connection() as conn:
            cursor = conn.cursor()
            
            # Obtenir les colonnes de la première ligne
            columns = list(successful_records[0].keys())
            
            # Construire la requête d'insertion
            placeholders = ', '.join(['%s'] * len(columns))
            columns_str = ', '.join(columns)
            
            query = f"""
                INSERT INTO {target_schema}.{target_table} ({columns_str})
                VALUES ({placeholders})
            """
            
            # Préparer les données
            data_rows = []
            for record in successful_records:
                row = [record.get(col) for col in columns]
                data_rows.append(row)
            
            # Insertion en lot
            cursor.executemany(query, data_rows)
            inserted_count = cursor.rowcount
            conn.commit()
            
            logger.info(f"Insérés {inserted_count} enregistrements dans {target_schema}.{target_table}")
            return inserted_count
            
    except Exception as e:
        logger.error(f"Erreur insertion dans {target_table}: {e}")
        raise

def test_import_to_database(df):
    """Test d'insertion des données dans la base"""
    
    print("\n💾 Test d'insertion en base de données")
    print("=" * 50)
    
    try:
        # Convertir le DataFrame en liste de dictionnaires (3 premières lignes)
        test_records = df.head(3).to_dict('records')
        
        print(f"📝 Préparation de {len(test_records)} enregistrements pour insertion")
        
        # Utiliser la méthode standard du projet
        inserted_count = insert_successful_records(
            target_table='customer_info',
            target_schema='raw_data',
            successful_records=test_records
        )
        
        print(f"✅ {inserted_count} lignes insérées avec succès!")
        
        # Vérification avec la méthode standard
        with get_db_connection() as conn:
            cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
            cursor.execute("SELECT COUNT(*) as count FROM raw_data.customer_info WHERE import_batch_id LIKE 'batch_%'")
            total_count = cursor.fetchone()['count']
            print(f"📊 Total de lignes dans la table: {total_count}")
        
        return True
        
    except Exception as e:
        print(f"❌ Erreur lors de l'insertion: {e}")
        return False

def main():
    """Fonction principale de test"""
    
    print("🚀 Tests du système d'import brut de données")
    print("=" * 60)
    print(f"⏰ Début des tests: {datetime.now()}")
    
    # Test 1: Connexion base de données
    db_ok = test_database_connection()
    
    # Test 2: Processeur de fichiers
    if db_ok:
        process_ok, df, stats = test_raw_data_processor()
        
        # Test 3: Insertion en base (optionnel)
        if process_ok and df is not None:
            insert_ok = test_import_to_database(df)
        else:
            insert_ok = False
    else:
        process_ok = False
        insert_ok = False
    
    # Résumé
    print(f"\n📋 Résumé des tests")
    print("=" * 30)
    print(f"🔌 Connexion base: {'✅ OK' if db_ok else '❌ KO'}")
    print(f"⚙️  Processeur: {'✅ OK' if process_ok else '❌ KO'}")
    print(f"💾 Insertion: {'✅ OK' if insert_ok else '❌ KO'}")
    
    if db_ok and process_ok and insert_ok:
        print("\n🎉 Tous les tests sont OK ! Le système est prêt.")
    else:
        print("\n⚠️  Certains tests ont échoué. Vérifiez les logs ci-dessus.")
    
    print(f"⏰ Fin des tests: {datetime.now()}")

if __name__ == "__main__":
    main() 