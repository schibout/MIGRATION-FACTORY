#!/usr/bin/env python
# -*- coding: utf-8 -*-

"""
Script de test pour valider l'API de configuration d'import
"""

import requests
import json
import sys

# Configuration
BASE_URL = "http://localhost:5000/api/v1"
LOGIN_URL = f"{BASE_URL}/auth/login"
CONFIG_URL = f"{BASE_URL}/import-types"
STATS_URL = f"{BASE_URL}/import/stats"

def get_auth_token():
    """Obtenir un token d'authentification"""
    try:
        # Credentials par défaut (à adapter selon votre base)
        login_data = {
            "email": "admin@migration-factory.com",
            "password": "admin123"
        }
        
        response = requests.post(LOGIN_URL, json=login_data)
        
        if response.status_code == 200:
            data = response.json()
            return data.get('access_token')
        else:
            print(f"❌ Erreur login: {response.status_code} - {response.text}")
            return None
            
    except Exception as e:
        print(f"❌ Erreur connexion: {e}")
        return None

def test_import_config_api(token):
    """Tester l'API de configuration d'import"""
    headers = {'Authorization': f'Bearer {token}'}
    
    print("\n🧪 Test API Configuration Import...")
    
    # Test 1: Récupérer les types d'import
    try:
        response = requests.get(CONFIG_URL, headers=headers)
        print(f"📋 GET /import-types: {response.status_code}")
        
        if response.status_code == 200:
            data = response.json()
            if data.get('success'):
                types_count = len(data.get('data', []))
                print(f"   ✅ {types_count} types configurés")
                
                # Afficher les types
                for config in data.get('data', [])[:3]:  # Premiers 3 types
                    print(f"   📄 {config['display_name']} ({config['type_code']})")
            else:
                print(f"   ❌ Réponse sans succès: {data}")
        else:
            print(f"   ❌ Erreur: {response.text}")
            
    except Exception as e:
        print(f"   ❌ Exception: {e}")

def test_import_stats_api(token):
    """Tester l'API de statistiques d'import"""
    headers = {'Authorization': f'Bearer {token}'}
    
    print("\n📊 Test API Statistiques Import...")
    
    try:
        response = requests.get(STATS_URL, headers=headers)
        print(f"📈 GET /import/stats: {response.status_code}")
        
        if response.status_code == 200:
            data = response.json()
            print(f"   ✅ Statistiques récupérées")
            stats = data.get('statistics', {})
            print(f"   📊 Total imports: {stats.get('total_imports', 0)}")
        else:
            print(f"   ❌ Erreur: {response.text}")
            
    except Exception as e:
        print(f"   ❌ Exception: {e}")

def test_database_tables():
    """Tester la présence des tables dans la base"""
    print("\n🗄️  Test Tables Base de Données...")
    
    try:
        import os
        import psycopg2
        from urllib.parse import urlparse
        
        # URL de connexion depuis les variables d'environnement
        db_url = os.environ.get('DATABASE_URI', 'postgresql://postgres:trimet2025@10.190.100.58:5432/sap_migration_db')
        parsed = urlparse(db_url)
        
        conn = psycopg2.connect(
            host=parsed.hostname,
            port=parsed.port,
            database=parsed.path[1:],  # Enlever le '/' initial
            user=parsed.username,
            password=parsed.password
        )
        
        cursor = conn.cursor()
        
        # Vérifier les tables d'import
        tables_to_check = [
            'import_file_types_config',
            'import_jobs',
            'import_details',
            'import_logs'
        ]
        
        for table in tables_to_check:
            cursor.execute("""
                SELECT EXISTS (
                    SELECT FROM information_schema.tables 
                    WHERE table_name = %s
                );
            """, (table,))
            
            exists = cursor.fetchone()[0]
            status = "✅" if exists else "❌"
            print(f"   {status} Table {table}: {'EXISTS' if exists else 'MISSING'}")
            
            if exists and table == 'import_file_types_config':
                # Compter les configurations
                cursor.execute(f"SELECT COUNT(*) FROM {table}")
                count = cursor.fetchone()[0]
                print(f"      📊 {count} configurations trouvées")
        
        cursor.close()
        conn.close()
        
    except Exception as e:
        print(f"   ❌ Erreur base de données: {e}")

def main():
    """Fonction principale de test"""
    print("🚀 Test API Migration Factory - Configuration Import")
    print("=" * 60)
    
    # Test base de données
    test_database_tables()
    
    # Test API
    token = get_auth_token()
    if not token:
        print("❌ Impossible d'obtenir un token d'authentification")
        return sys.exit(1)
    
    print(f"✅ Token obtenu: {token[:20]}...")
    
    # Tester les APIs
    test_import_config_api(token)
    test_import_stats_api(token)
    
    print("\n" + "=" * 60)
    print("🏁 Tests terminés")

if __name__ == "__main__":
    main() 