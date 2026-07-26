#!/usr/bin/env python
# -*- coding: utf-8 -*-

"""
Test rapide pour vérifier le backend et la base de données
"""

import requests
import json
import sys
import os

def test_backend_status():
    """Tester si le backend Flask démarre"""
    try:
        response = requests.get("http://localhost:5000/", timeout=5)
        print(f"✅ Backend accessible: {response.status_code}")
        return True
    except Exception as e:
        print(f"❌ Backend inaccessible: {e}")
        return False

def test_auth_endpoint():
    """Tester l'endpoint d'authentification"""
    try:
        # Test avec des credentials invalides pour voir si l'endpoint répond
        response = requests.post("http://localhost:5000/api/v1/auth/login", 
                               json={"email": "test", "password": "test"},
                               timeout=5)
        print(f"✅ Auth endpoint répond: {response.status_code}")
        return True
    except Exception as e:
        print(f"❌ Auth endpoint ne répond pas: {e}")
        return False

def test_database_connection():
    """Tester la connexion à la base de données"""
    try:
        import psycopg2
        from urllib.parse import urlparse
        
        db_url = os.environ.get('DATABASE_URI', 'postgresql://postgres:trimet2025@10.190.100.58:5432/sap_migration_db')
        parsed = urlparse(db_url)
        
        conn = psycopg2.connect(
            host=parsed.hostname,
            port=parsed.port,
            database=parsed.path[1:],
            user=parsed.username,
            password=parsed.password
        )
        
        cursor = conn.cursor()
        cursor.execute("SELECT 1")
        result = cursor.fetchone()
        
        cursor.close()
        conn.close()
        
        print(f"✅ Base de données accessible: {result}")
        return True
        
    except Exception as e:
        print(f"❌ Base de données inaccessible: {e}")
        return False

def test_import_tables():
    """Vérifier les tables d'import"""
    try:
        import psycopg2
        from urllib.parse import urlparse
        
        db_url = os.environ.get('DATABASE_URI', 'postgresql://postgres:trimet2025@10.190.100.58:5432/sap_migration_db')
        parsed = urlparse(db_url)
        
        conn = psycopg2.connect(
            host=parsed.hostname,
            port=parsed.port,
            database=parsed.path[1:],
            user=parsed.username,
            password=parsed.password
        )
        
        cursor = conn.cursor()
        
        # Vérifier la table de configuration
        cursor.execute("""
            SELECT EXISTS (
                SELECT FROM information_schema.tables 
                WHERE table_name = 'import_file_types_config'
            );
        """)
        
        config_table_exists = cursor.fetchone()[0]
        
        if config_table_exists:
            cursor.execute("SELECT COUNT(*) FROM import_file_types_config")
            config_count = cursor.fetchone()[0]
            print(f"✅ Table import_file_types_config: {config_count} configurations")
        else:
            print(f"❌ Table import_file_types_config manquante")
        
        cursor.close()
        conn.close()
        
        return config_table_exists
        
    except Exception as e:
        print(f"❌ Erreur vérification tables: {e}")
        return False

def main():
    """Test principal"""
    print("🔍 Diagnostic Backend Migration Factory")
    print("=" * 50)
    
    all_good = True
    
    # Test backend
    if not test_backend_status():
        print("\n💡 Solution: Démarrer le backend avec 'python app.py'")
        all_good = False
    
    # Test auth
    if not test_auth_endpoint():
        all_good = False
    
    # Test base de données
    if not test_database_connection():
        print("\n💡 Solution: Vérifier la connexion PostgreSQL")
        all_good = False
    
    # Test tables
    if not test_import_tables():
        print("\n💡 Solution: Exécuter la migration SQL")
        print("psql -h 10.190.100.58 -U postgres -d sap_migration_db -f backend/migrations/004_create_import_file_types_config.sql")
        all_good = False
    
    print("\n" + "=" * 50)
    if all_good:
        print("✅ Tout fonctionne ! Le frontend devrait marcher maintenant.")
    else:
        print("❌ Problèmes détectés. Voir les solutions ci-dessus.")
    
    return 0 if all_good else 1

if __name__ == "__main__":
    sys.exit(main()) 