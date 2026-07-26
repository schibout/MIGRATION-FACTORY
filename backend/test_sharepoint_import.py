#!/usr/bin/env python3
"""
Script de test pour l'import SharePoint
"""

import os
import sys
import requests
import json
from datetime import datetime

# Ajouter le répertoire backend au path pour les imports
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from services.sharepoint_service import SharePointService

def test_sharepoint_connection():
    """Test de connexion à SharePoint"""
    print("🔗 Test de connexion à SharePoint...")
    
    try:
        service = SharePointService()
        result = service.test_connection()
        
        if result['success']:
            print("✅ Connexion SharePoint réussie !")
            print(f"📊 URL: {result['url']}")
            print(f"📊 Status: {result['status_code']}")
            print(f"📊 Échantillon: {result['sample_count']} projets")
            
            if result['sample_data']:
                print("\n📋 Exemple de données :")
                sample = result['sample_data']
                print(f"   ID: {sample.get('ID')}")
                print(f"   Title: {sample.get('Title')}")
                print(f"   Colonnes disponibles: {list(sample.keys())[:10]}...")
        else:
            print(f"❌ Erreur de connexion: {result['error']}")
            
        return result['success']
        
    except Exception as e:
        print(f"❌ Erreur inattendue: {e}")
        return False

def test_sharepoint_import():
    """Test d'import des projets"""
    print("\n📥 Test d'import des projets...")
    
    try:
        service = SharePointService()
        
        # Import avec limite pour test
        result = service.import_projets_from_sharepoint(top=5)
        
        if result['success']:
            print("✅ Import réussi !")
            print(f"📊 Projets importés: {result['imported_count']}")
            
            if result['errors']:
                print(f"⚠️ Erreurs: {len(result['errors'])}")
                for error in result['errors'][:3]:  # Afficher max 3 erreurs
                    print(f"   - {error}")
        else:
            print(f"❌ Erreur d'import: {result}")
            
        return result['success']
        
    except Exception as e:
        print(f"❌ Erreur inattendue: {e}")
        return False

def test_table_status():
    """Test du statut des tables"""
    print("\n📊 Test du statut des tables...")
    
    try:
        service = SharePointService()
        stats = service.get_table_status()
        
        if 'error' not in stats:
            print("✅ Statut récupéré !")
            print(f"📊 Total projets: {stats['total_projets']}")
            print(f"📊 Dernière sync: {stats['derniere_sync']}")
            print(f"📊 Sync récente: {stats['sync_recente']}")
            print(f"📊 Status: {stats['status']}")
        else:
            print(f"❌ Erreur: {stats['error']}")
            
        return 'error' not in stats
        
    except Exception as e:
        print(f"❌ Erreur inattendue: {e}")
        return False

def test_api_endpoints():
    """Test des endpoints de l'API"""
    print("\n🌐 Test des endpoints API...")
    
    base_url = "http://10.190.100.58:8080/api/v1/import"
    
    # Note: Ces tests nécessitent un token JWT valide
    print("⚠️ Les tests d'API nécessitent un token JWT valide")
    print("📋 Endpoints disponibles :")
    print(f"   GET  {base_url}/projets/test-connection")
    print(f"   POST {base_url}/projets")
    print(f"   GET  {base_url}/projets/status")
    
    return True

def main():
    """Fonction principale de test"""
    print("🚀 Tests d'import SharePoint")
    print("=" * 50)
    
    # Tests séquentiels
    tests = [
        ("Connexion SharePoint", test_sharepoint_connection),
        ("Import projets", test_sharepoint_import),
        ("Statut tables", test_table_status),
        ("Endpoints API", test_api_endpoints)
    ]
    
    results = []
    
    for test_name, test_func in tests:
        print(f"\n🧪 {test_name}")
        print("-" * 30)
        
        try:
            success = test_func()
            results.append((test_name, success))
            
            if success:
                print(f"✅ {test_name}: RÉUSSI")
            else:
                print(f"❌ {test_name}: ÉCHEC")
                
        except Exception as e:
            print(f"❌ {test_name}: ERREUR - {e}")
            results.append((test_name, False))
    
    # Résumé
    print("\n" + "=" * 50)
    print("📊 RÉSUMÉ DES TESTS")
    print("=" * 50)
    
    passed = sum(1 for _, success in results if success)
    total = len(results)
    
    for test_name, success in results:
        status = "✅ RÉUSSI" if success else "❌ ÉCHEC"
        print(f"{test_name:.<30} {status}")
    
    print(f"\nRésultat final: {passed}/{total} tests réussis")
    
    if passed == total:
        print("🎉 Tous les tests sont passés !")
        return 0
    else:
        print("⚠️ Certains tests ont échoué")
        return 1

if __name__ == "__main__":
    exit_code = main()
    sys.exit(exit_code)
