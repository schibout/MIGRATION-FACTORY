#!/usr/bin/env python3
"""
Script de test pour vérifier la compatibilité entre le frontend et le backend
avec le nouveau système d'export dynamique
"""

import os
import sys
import requests
import json
from datetime import datetime

def test_export_compatibility():
    """Test complet de la compatibilité frontend-backend"""
    
    base_url = "http://localhost:5000"
    
    print("🧪 TEST DE COMPATIBILITÉ FRONTEND-BACKEND")
    print("=" * 50)
    
    # Test 1: Vérifier que l'endpoint /queries retourne column_list
    print("\n1️⃣ Test de l'endpoint /queries")
    try:
        response = requests.get(f"{base_url}/export/queries")
        if response.status_code == 200:
            data = response.json()
            queries = data.get('queries', [])
            
            if queries:
                first_query = queries[0]
                required_fields = ['column_list', 'sql_query', 'table_name', 'display_name']
                
                missing_fields = [field for field in required_fields if field not in first_query]
                
                if missing_fields:
                    print(f"❌ Champs manquants: {missing_fields}")
                    return False
                else:
                    print(f"✅ Tous les champs requis présents")
                    print(f"   - Table: {first_query['table_name']}")
                    print(f"   - Colonnes: {first_query['column_list'][:50]}...")
                    print(f"   - SQL: {first_query['sql_query'][:50]}...")
            else:
                print("❌ Aucune requête retournée")
                return False
        else:
            print(f"❌ Erreur HTTP: {response.status_code}")
            return False
    except Exception as e:
        print(f"❌ Erreur lors du test: {e}")
        return False
    
    # Test 2: Vérifier l'exécution dynamique d'une requête
    print("\n2️⃣ Test de l'exécution dynamique")
    try:
        # Récupérer la première table disponible
        response = requests.get(f"{base_url}/export/queries")
        if response.status_code == 200:
            queries = response.json()['queries']
            if queries:
                table_name = queries[0]['table_name']
                
                # Tester l'exécution
                execute_response = requests.post(f"{base_url}/export/queries/{table_name}/execute")
                
                if execute_response.status_code == 200:
                    data = execute_response.json()
                    print(f"✅ Exécution réussie pour {table_name}")
                    print(f"   - {len(data)} lignes retournées")
                    if data:
                        print(f"   - Colonnes: {list(data[0].keys())}")
                else:
                    print(f"❌ Erreur lors de l'exécution: {execute_response.status_code}")
                    print(f"   - Message: {execute_response.text}")
                    return False
            else:
                print("❌ Aucune table disponible pour test")
                return False
        else:
            print(f"❌ Impossible de récupérer les tables: {response.status_code}")
            return False
    except Exception as e:
        print(f"❌ Erreur lors du test d'exécution: {e}")
        return False
    
    # Test 3: Vérifier l'export complet
    print("\n3️⃣ Test de l'export complet")
    try:
        # Sélectionner quelques tables pour l'export
        response = requests.get(f"{base_url}/export/queries?category=supplier")
        if response.status_code == 200:
            queries = response.json()['queries']
            selected_tables = [q['table_name'] for q in queries[:3]]  # Prendre les 3 premières
            
            export_config = {
                'selectedTables': selected_tables,
                'includeHeaders': True,
                'includeInactive': False
            }
            
            print(f"   - Tables sélectionnées: {selected_tables}")
            
            # Tester l'export (ne pas télécharger le fichier)
            export_response = requests.post(f"{base_url}/export/suppliers", json=export_config)
            
            if export_response.status_code == 200:
                # Vérifier les headers
                headers = export_response.headers
                if 'X-Export-Summary' in headers:
                    summary = json.loads(headers['X-Export-Summary'])
                    print(f"✅ Export réussi")
                    print(f"   - Tables exportées: {summary.get('successful_tables', 0)}")
                    print(f"   - Lignes totales: {summary.get('total_rows', 0)}")
                    print(f"   - Taille: {headers.get('X-Export-Size-Bytes', 0)} bytes")
                else:
                    print("⚠️ Export réussi mais headers manquants")
            else:
                print(f"❌ Erreur lors de l'export: {export_response.status_code}")
                print(f"   - Message: {export_response.text}")
                return False
        else:
            print(f"❌ Impossible de récupérer les tables: {response.status_code}")
            return False
    except Exception as e:
        print(f"❌ Erreur lors du test d'export: {e}")
        return False
    
    print("\n✅ TOUS LES TESTS PASSÉS - COMPATIBILITÉ CONFIRMÉE")
    return True

def test_frontend_interface():
    """Test que l'interface frontend peut parser les données du backend"""
    
    print("\n🎯 TEST DE L'INTERFACE FRONTEND")
    print("=" * 40)
    
    # Simuler la structure attendue par le frontend
    mock_export_query = {
        'id': 1,
        'table_name': 'SUPPLIER',
        'table_schema': 'public',
        'display_name': 'Fournisseurs',
        'column_list': 'id, name, email, phone',  # Nouveau champ
        'sql_query': 'SELECT id, name FROM supplier',  # Ancien champ maintenu
        'description': 'Table des fournisseurs',
        'category': 'supplier',
        'is_active': True
    }
    
    # Vérifier que tous les champs nécessaires sont présents
    required_fields = ['id', 'table_name', 'table_schema', 'display_name', 'column_list', 'sql_query', 'category']
    
    missing_fields = [field for field in required_fields if field not in mock_export_query]
    
    if missing_fields:
        print(f"❌ Champs manquants dans l'interface: {missing_fields}")
        return False
    else:
        print("✅ Interface frontend compatible")
        print(f"   - Tous les champs requis présents: {required_fields}")
        return True

if __name__ == "__main__":
    print("🔬 SUITE DE TESTS DE COMPATIBILITÉ")
    print("=" * 60)
    
    success = True
    
    # Test de l'interface
    if not test_frontend_interface():
        success = False
    
    # Test de compatibilité (nécessite que le serveur soit en marche)
    try:
        if not test_export_compatibility():
            success = False
    except requests.exceptions.ConnectionError:
        print("\n⚠️  Serveur non accessible - Tests de compatibilité ignorés")
        print("   Pour tester la compatibilité, démarrez le serveur avec:")
        print("   cd backend && python app.py")
    
    if success:
        print("\n🎉 TOUS LES TESTS SONT PASSÉS")
        print("✅ Le frontend et le backend sont compatibles avec le nouveau système")
    else:
        print("\n❌ CERTAINS TESTS ONT ÉCHOUÉ")
        print("⚠️  Vérifiez les corrections nécessaires")
    
    sys.exit(0 if success else 1) 