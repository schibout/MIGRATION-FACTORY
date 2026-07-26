#!/usr/bin/env python3
"""
Script de test pour l'API d'import
Test des endpoints principaux sans authentification JWT
"""

import os
import sys
import requests
import json
from datetime import datetime

# Configuration
BASE_URL = "http://localhost:5000/api/v1"
TEST_FILES_DIR = "test_files"

def create_test_files():
    """Crée des fichiers de test pour les imports"""
    os.makedirs(TEST_FILES_DIR, exist_ok=True)
    
    # Fichier clients test (CSV)
    clients_csv = """name,email,phone,address
John Doe,john@example.com,0123456789,123 Main St
Jane Smith,jane@example.com,0987654321,456 Oak Ave
Bob Johnson,bob@example.com,0555123456,789 Pine St
"""
    with open(f"{TEST_FILES_DIR}/clients_test.csv", "w", encoding="utf-8") as f:
        f.write(clients_csv)
    
    # Fichier produits test (CSV)
    products_csv = """code,name,price,description
PROD001,Laptop,999.99,High-performance laptop
PROD002,Mouse,29.99,Wireless optical mouse
PROD003,Keyboard,79.99,Mechanical gaming keyboard
"""
    with open(f"{TEST_FILES_DIR}/products_test.csv", "w", encoding="utf-8") as f:
        f.write(products_csv)
    
    # Fichier commandes test (CSV)
    orders_csv = """order_number,customer_id,total,order_date
ORD001,1,1099.98,2024-01-15
ORD002,2,59.98,2024-01-16
ORD003,1,79.99,2024-01-17
"""
    with open(f"{TEST_FILES_DIR}/orders_test.csv", "w", encoding="utf-8") as f:
        f.write(orders_csv)
    
    print(f"✅ Fichiers de test créés dans {TEST_FILES_DIR}/")


def test_connection():
    """Test de connexion basique"""
    try:
        # Test d'un endpoint qui ne nécessite pas d'authentification
        response = requests.get(f"{BASE_URL}/auth/status", timeout=5)
        print(f"✅ Connexion OK - Status: {response.status_code}")
        return True
    except requests.exceptions.RequestException as e:
        print(f"❌ Erreur de connexion: {e}")
        return False


def test_file_types_config():
    """Test de récupération de la configuration des types de fichiers"""
    try:
        # Ce endpoint nécessite une authentification, on s'attend à une 401
        response = requests.get(f"{BASE_URL}/import/config/file-types")
        
        if response.status_code == 401:
            print("✅ Endpoint file-types protégé correctement (401 Unauthorized)")
            return True
        elif response.status_code == 200:
            print("✅ Endpoint file-types accessible")
            data = response.json()
            print(f"   Types de fichiers configurés: {len(data.get('file_types', []))}")
            return True
        else:
            print(f"⚠️  Endpoint file-types - Status inattendu: {response.status_code}")
            return False
            
    except requests.exceptions.RequestException as e:
        print(f"❌ Erreur test file-types: {e}")
        return False


def test_import_upload():
    """Test d'upload de fichier (sans authentification, on s'attend à une 401)"""
    try:
        # Préparer un fichier de test
        test_file_path = f"{TEST_FILES_DIR}/clients_test.csv"
        
        if not os.path.exists(test_file_path):
            print(f"❌ Fichier de test manquant: {test_file_path}")
            return False
        
        with open(test_file_path, 'rb') as f:
            files = {'file': ('clients_test.csv', f, 'text/csv')}
            data = {'file_type': 'customers'}
            
            response = requests.post(
                f"{BASE_URL}/import/upload",
                files=files,
                data=data
            )
        
        if response.status_code == 401:
            print("✅ Endpoint upload protégé correctement (401 Unauthorized)")
            return True
        else:
            print(f"⚠️  Endpoint upload - Status inattendu: {response.status_code}")
            if response.status_code != 200:
                print(f"   Réponse: {response.text}")
            return False
            
    except requests.exceptions.RequestException as e:
        print(f"❌ Erreur test upload: {e}")
        return False


def test_import_jobs():
    """Test de récupération des jobs d'import"""
    try:
        response = requests.get(f"{BASE_URL}/import/jobs")
        
        if response.status_code == 401:
            print("✅ Endpoint jobs protégé correctement (401 Unauthorized)")
            return True
        elif response.status_code == 200:
            print("✅ Endpoint jobs accessible")
            data = response.json()
            print(f"   Nombre de jobs: {data.get('total', 0)}")
            return True
        else:
            print(f"⚠️  Endpoint jobs - Status inattendu: {response.status_code}")
            return False
            
    except requests.exceptions.RequestException as e:
        print(f"❌ Erreur test jobs: {e}")
        return False


def test_import_stats():
    """Test de récupération des statistiques"""
    try:
        response = requests.get(f"{BASE_URL}/import/stats")
        
        if response.status_code == 401:
            print("✅ Endpoint stats protégé correctement (401 Unauthorized)")
            return True
        elif response.status_code == 200:
            print("✅ Endpoint stats accessible")
            data = response.json()
            stats = data.get('statistics', {})
            print(f"   Jobs totaux: {stats.get('total_jobs', 0)}")
            return True
        else:
            print(f"⚠️  Endpoint stats - Status inattendu: {response.status_code}")
            return False
            
    except requests.exceptions.RequestException as e:
        print(f"❌ Erreur test stats: {e}")
        return False


def cleanup_test_files():
    """Nettoie les fichiers de test"""
    try:
        import shutil
        if os.path.exists(TEST_FILES_DIR):
            shutil.rmtree(TEST_FILES_DIR)
            print(f"✅ Fichiers de test supprimés")
    except Exception as e:
        print(f"⚠️  Erreur nettoyage: {e}")


def main():
    """Fonction principale de test"""
    print("🧪 Test de l'API Import - Migration Factory")
    print("=" * 50)
    
    # Créer les fichiers de test
    create_test_files()
    
    # Tests
    tests = [
        ("Connexion au serveur", test_connection),
        ("Configuration types de fichiers", test_file_types_config),
        ("Upload de fichier", test_import_upload),
        ("Liste des jobs", test_import_jobs),
        ("Statistiques d'import", test_import_stats),
    ]
    
    results = []
    
    for test_name, test_func in tests:
        print(f"\n🔍 Test: {test_name}")
        try:
            result = test_func()
            results.append((test_name, result))
        except Exception as e:
            print(f"❌ Erreur inattendue: {e}")
            results.append((test_name, False))
    
    # Nettoyage
    cleanup_test_files()
    
    # Résumé
    print("\n" + "=" * 50)
    print("📊 RÉSUMÉ DES TESTS")
    print("=" * 50)
    
    passed = 0
    for test_name, result in results:
        status = "✅ PASS" if result else "❌ FAIL"
        print(f"{status} {test_name}")
        if result:
            passed += 1
    
    print(f"\nRésultat: {passed}/{len(results)} tests réussis")
    
    if passed == len(results):
        print("🎉 Tous les tests sont passés!")
        return 0
    else:
        print("⚠️  Certains tests ont échoué")
        return 1


if __name__ == "__main__":
    exit_code = main()
    sys.exit(exit_code) 