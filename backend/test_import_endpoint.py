#!/usr/bin/env python3
"""
Script de test simple pour diagnostiquer l'endpoint import-types
"""

import sys
import os
sys.path.append(os.path.dirname(os.path.abspath(__file__)))

def test_direct_import():
    """Tester directement l'import du modèle"""
    try:
        print("🧪 Test 1: Import du modèle...")
        from models.import_config import ImportFileTypesConfig
        print("✅ Import du modèle réussi")
        
        print("🧪 Test 2: Connexion à la base...")
        from config.database import db
        from app import create_app
        
        app = create_app()
        with app.app_context():
            # Test requête directe
            configs = ImportFileTypesConfig.query.limit(3).all()
            print(f"✅ Requête directe réussie: {len(configs)} configs trouvées")
            
            for config in configs:
                print(f"   - {config.type_name}: {config.display_name}")
        
        print("🧪 Test 3: Test de la méthode to_dict...")
        with app.app_context():
            config = ImportFileTypesConfig.query.first()
            if config:
                dict_result = config.to_dict()
                print(f"✅ to_dict() réussi, clés: {list(dict_result.keys())}")
            else:
                print("❌ Aucune configuration trouvée")
        
        return True
        
    except Exception as e:
        print(f"❌ Erreur: {e}")
        import traceback
        traceback.print_exc()
        return False

def test_api_endpoint():
    """Tester l'endpoint API directement"""
    try:
        print("🧪 Test 4: Test endpoint API...")
        from app import create_app
        
        app = create_app()
        client = app.test_client()
        
        # Test sans JWT (doit échouer)
        response = client.get('/api/v1/import-types?category=customer')
        print(f"   Sans JWT: Status {response.status_code}")
        
        # Test avec mock JWT
        with app.app_context():
            # Simuler une requête avec JWT
            from flask_jwt_extended import create_access_token
            
            # Créer un token de test
            access_token = create_access_token(identity={'user_id': 1, 'role': 'admin'})
            headers = {'Authorization': f'Bearer {access_token}'}
            
            response = client.get('/api/v1/import-types?category=customer', headers=headers)
            print(f"   Avec JWT: Status {response.status_code}")
            
            if response.status_code == 200:
                data = response.get_json()
                print(f"   ✅ Réponse API réussie: {data.get('count', 0)} éléments")
                
                if data.get('data'):
                    for item in data['data'][:2]:  # Afficher les 2 premiers
                        print(f"      - {item.get('display_name')}")
            else:
                print(f"   ❌ Erreur API: {response.data}")
        
        return True
        
    except Exception as e:
        print(f"❌ Erreur endpoint: {e}")
        import traceback
        traceback.print_exc()
        return False

if __name__ == "__main__":
    print("🚀 Test diagnostic import-types endpoint")
    print("="*50)
    
    success1 = test_direct_import()
    print("-"*30)
    success2 = test_api_endpoint()
    
    print("="*50)
    if success1 and success2:
        print("✅ Tous les tests passés")
    else:
        print("❌ Certains tests ont échoué")
        sys.exit(1) 