#!/usr/bin/env python
# -*- coding: utf-8 -*-

"""
Script de test pour diagnostiquer les problèmes d'authentification
"""

import requests
import json
import sys
import os
from datetime import datetime

# Configuration
BASE_URL = "http://10.190.100.58:8081/api/v1"
LOGIN_URL = f"{BASE_URL}/auth/login"
IMPORT_TYPES_URL = f"{BASE_URL}/import-types"

def test_connection():
    """Test de connexion de base"""
    try:
        # Test de santé du backend
        response = requests.get("http://10.190.100.58:8081/health", timeout=5)
        print(f"✅ Backend Health: OK (Status: {response.status_code})")
        
        # Test de l'API auth/me
        response = requests.get(f"{BASE_URL}/auth/me", timeout=5)
        print(f"✅ Connexion au serveur: OK (Status: {response.status_code})")
        return True
    except requests.exceptions.ConnectionError:
        print("❌ Impossible de se connecter au serveur")
        return False
    except Exception as e:
        print(f"❌ Erreur de connexion: {e}")
        return False

def test_login():
    """Test de l'API de connexion"""
    print("\n🔐 Test de l'API de connexion...")
    
    # Essayer avec des credentials par défaut
    test_credentials = [
        {"username": "admin", "password": "admin123"},
        {"username": "schibout", "password": "password"},
        {"username": "test", "password": "test123"}
    ]
    
    for creds in test_credentials:
        try:
            print(f"  Tentative avec {creds['username']}...")
            response = requests.post(LOGIN_URL, json=creds, timeout=10)
            
            if response.status_code == 200:
                data = response.json()
                token = data.get('access_token')
                user = data.get('user', {})
                print(f"  ✅ Connexion réussie avec {creds['username']}")
                print(f"     Token: {token[:20]}..." if token else "     Pas de token")
                print(f"     Utilisateur: {user.get('username', 'N/A')} ({user.get('role', 'N/A')})")
                return token, creds['username']
            else:
                print(f"  ❌ Échec: {response.status_code} - {response.text}")
                
        except Exception as e:
            print(f"  ❌ Erreur: {e}")
    
    print("  ❌ Aucune connexion réussie")
    return None, None

def test_import_types_api(token):
    """Test de l'API import-types avec authentification"""
    print(f"\n📁 Test de l'API import-types...")
    
    if not token:
        print("  ❌ Pas de token disponible")
        return False
    
    headers = {
        'Authorization': f'Bearer {token}',
        'Content-Type': 'application/json'
    }
    
    try:
        # Test sans paramètres
        print("  Test GET /import-types...")
        response = requests.get(IMPORT_TYPES_URL, headers=headers, timeout=10)
        
        if response.status_code == 200:
            data = response.json()
            print(f"  ✅ Succès: {response.status_code}")
            print(f"     Données: {data}")
            return True
        else:
            print(f"  ❌ Échec: {response.status_code} - {response.text}")
            return False
            
    except Exception as e:
        print(f"  ❌ Erreur: {e}")
        return False

def test_import_types_with_category(token):
    """Test de l'API import-types avec catégorie customer"""
    print(f"\n👥 Test de l'API import-types?category=customer...")
    
    if not token:
        print("  ❌ Pas de token disponible")
        return False
    
    headers = {
        'Authorization': f'Bearer {token}',
        'Content-Type': 'application/json'
    }
    
    try:
        # Test avec paramètre category=customer
        url = f"{IMPORT_TYPES_URL}?category=customer"
        print(f"  Test GET {url}...")
        response = requests.get(url, headers=headers, timeout=10)
        
        if response.status_code == 200:
            data = response.json()
            print(f"  ✅ Succès: {response.status_code}")
            print(f"     Données: {data}")
            return True
        else:
            print(f"  ❌ Échec: {response.status_code} - {response.text}")
            return False
            
    except Exception as e:
        print(f"  ❌ Erreur: {e}")
        return False

def check_database_tables():
    """Vérifier les tables de base de données"""
    print("\n🗄️ Vérification des tables de base de données...")
    
    try:
        # Test de connexion à la base
        from config.database import get_db_connection
        
        with get_db_connection() as conn:
            cursor = conn.cursor()
            
            # Vérifier la table des utilisateurs
            cursor.execute("""
                SELECT table_name 
                FROM information_schema.tables 
                WHERE table_schema = 'public' 
                AND table_name IN ('users', 'user')
                ORDER BY table_name
            """)
            
            user_tables = cursor.fetchall()
            if user_tables:
                print(f"  ✅ Tables utilisateurs trouvées: {[t[0] for t in user_tables]}")
                
                # Compter les utilisateurs
                for table in user_tables:
                    cursor.execute(f"SELECT COUNT(*) FROM {table[0]}")
                    count = cursor.fetchone()[0]
                    print(f"     {table[0]}: {count} utilisateur(s)")
            else:
                print("  ❌ Aucune table utilisateur trouvée")
            
            # Vérifier la table des types d'import
            cursor.execute("""
                SELECT table_name 
                FROM information_schema.tables 
                WHERE table_schema = 'public' 
                AND table_name LIKE '%import%'
                ORDER BY table_name
            """)
            
            import_tables = cursor.fetchall()
            if import_tables:
                print(f"  ✅ Tables d'import trouvées: {[t[0] for t in import_tables]}")
            else:
                print("  ❌ Aucune table d'import trouvée")
                
    except ImportError:
        print("  ⚠️ Impossible d'importer la configuration de base de données")
        print("  💡 Exécutez ce script depuis le conteneur backend ou installez les dépendances")
    except Exception as e:
        print(f"  ❌ Erreur base de données: {e}")
        print("  💡 Vérifiez la connexion à la base de données")

def main():
    """Fonction principale de diagnostic"""
    print("🔍 Diagnostic API Migration Factory - Authentification")
    print("=" * 60)
    print(f"⏰ Test effectué le: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    print(f"🌐 URL de base: {BASE_URL}")
    print(f"🔗 Backend URL: http://10.190.100.58:8081 (via nginx)")
    
    # Test de connexion
    if not test_connection():
        print("\n❌ Impossible de continuer - serveur inaccessible")
        print("💡 Vérifiez que le backend est démarré avec: ./deploybackend.sh")
        return
    
    # Test de la base de données
    check_database_tables()
    
    # Test d'authentification
    token, username = test_login()
    
    if token:
        # Test des APIs protégées
        test_import_types_api(token)
        test_import_types_with_category(token)
        
        print(f"\n✅ Diagnostic terminé - Utilisateur connecté: {username}")
    else:
        print("\n❌ Diagnostic terminé - Aucun utilisateur connecté")
        print("💡 Vérifiez les credentials ou créez un utilisateur")
    
    print("\n" + "=" * 60)
    print("🏁 Tests terminés")
    print("\n📋 Commandes utiles:")
    print("   - Voir les logs: docker logs migration-app-backend")
    print("   - Redémarrer: ./deploybackend.sh -r")
    print("   - Tester depuis le conteneur: docker exec -it migration-app-backend python test_auth_api.py")

if __name__ == "__main__":
    main()







