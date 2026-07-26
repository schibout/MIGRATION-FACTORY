#!/usr/bin/env python3
"""
Script de test pour le service d'export mis à jour avec architecture dynamique
"""

import sys
import os
import logging
from pathlib import Path
from datetime import datetime

# Ajouter le répertoire parent au path pour importer les modules
sys.path.append(str(Path(__file__).parent))

from services.export_service import ExportService

def setup_logging():
    """Configure les logs pour les tests"""
    logging.basicConfig(
        level=logging.INFO,
        format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
        handlers=[
            logging.StreamHandler(sys.stdout)
        ]
    )

def test_service_initialization():
    """Test l'initialisation du service"""
    print("\n" + "="*60)
    print("🔍 TEST 1: Initialisation du service d'export")
    print("="*60)
    
    try:
        service = ExportService()
        print("✅ Service initialisé avec succès")
        
        # Vérifier les caches
        print(f"📊 Tables configurées: {len(service.table_categories)}")
        print(f"📂 Schémas utilisés: {len(set(service.table_schemas.values()))}")
        print(f"📋 Tables disponibles: {list(service.table_categories.keys())[:5]}...")
        
        return service
        
    except Exception as e:
        print(f"❌ Erreur lors de l'initialisation: {e}")
        return None

def test_metadata_loading(service):
    """Test le chargement des métadonnées"""
    print("\n" + "="*60)
    print("🔍 TEST 2: Chargement des métadonnées")
    print("="*60)
    
    try:
        # Vérifier que les métadonnées sont chargées
        service.ensure_queries_loaded()
        
        print(f"✅ Métadonnées chargées: {len(service.table_categories)} tables")
        
        # Afficher les schémas utilisés
        schemas = set(service.table_schemas.values())
        print(f"📂 Schémas trouvés: {list(schemas)}")
        
        # Afficher quelques exemples
        for table_name in list(service.table_categories.keys())[:3]:
            table_info = service.get_table_info(table_name)
            print(f"📋 {table_name}:")
            print(f"   - Nom affiché: {table_info['display_name']}")
            print(f"   - Schéma: {table_info['schema']}")
            print(f"   - Colonnes: {table_info['column_count']}")
            print(f"   - Catégorie: {table_info['category']}")
        
        return True
        
    except Exception as e:
        print(f"❌ Erreur lors du chargement des métadonnées: {e}")
        return False

def test_dynamic_query_building(service):
    """Test la construction dynamique des requêtes"""
    print("\n" + "="*60)
    print("🔍 TEST 3: Construction dynamique des requêtes")
    print("="*60)
    
    try:
        # Tester avec une table existante
        table_name = list(service.table_categories.keys())[0]
        table_schema = service.table_schemas[table_name]
        column_list = service.table_columns[table_name]
        
        print(f"📋 Test avec la table: {table_name}")
        print(f"📂 Schéma: {table_schema}")
        print(f"📝 Colonnes: {column_list[:100]}...")
        
        # Construire la requête
        query = service.build_dynamic_query(table_name, table_schema, column_list)
        
        print(f"✅ Requête générée:")
        print(f"   {query[:150]}...")
        
        return True
        
    except Exception as e:
        print(f"❌ Erreur lors de la construction de la requête: {e}")
        return False

def test_query_execution(service):
    """Test l'exécution d'une requête"""
    print("\n" + "="*60)
    print("🔍 TEST 4: Exécution d'une requête")
    print("="*60)
    
    try:
        # Sélectionner une table avec peu de données pour le test
        table_name = list(service.table_categories.keys())[0]
        table_info = service.get_table_info(table_name)
        
        print(f"📋 Test avec: {table_info['display_name']}")
        
        # Exécuter la requête avec une limite
        custom_query = f"SELECT * FROM {table_info['schema']}.{table_name} LIMIT 5"
        data, error = service.execute_query(table_name, custom_query)
        
        if error:
            print(f"❌ Erreur: {error}")
            return False
        
        print(f"✅ Requête réussie: {len(data)} lignes récupérées")
        
        if data:
            print(f"📊 Colonnes: {list(data[0].keys())[:10]}...")
            print(f"📝 Exemple (première ligne): {str(data[0])[:200]}...")
        
        return True
        
    except Exception as e:
        print(f"❌ Erreur lors de l'exécution: {e}")
        return False

def test_export_functionality(service):
    """Test de la fonctionnalité d'export complète"""
    print("\n" + "="*60)
    print("🔍 TEST 5: Export complet")
    print("="*60)
    
    try:
        # Sélectionner 3 tables pour l'export
        available_tables = list(service.table_categories.keys())[:3]
        
        config = {
            'selectedTables': available_tables,
            'includeInactive': False
        }
        
        print(f"📋 Tables sélectionnées: {config['selectedTables']}")
        
        # Exécuter l'export
        results = service.export_supplier_data(config)
        
        print(f"✅ Export terminé:")
        print(f"   - Tables réussies: {results['summary']['successful_tables']}")
        print(f"   - Tables échouées: {results['summary']['failed_tables']}")
        print(f"   - Total lignes: {results['summary']['total_rows']}")
        
        # Afficher les détails
        for table_name, table_data in results['results'].items():
            metadata = results['metadata'][table_name]
            print(f"📊 {metadata['display_name']}: {len(table_data)} lignes")
        
        if results['errors']:
            print("❌ Erreurs:")
            for table_name, error in results['errors'].items():
                print(f"   - {table_name}: {error}")
        
        return True
        
    except Exception as e:
        print(f"❌ Erreur lors de l'export: {e}")
        return False

def test_error_handling(service):
    """Test de la gestion d'erreurs"""
    print("\n" + "="*60)
    print("🔍 TEST 6: Gestion d'erreurs")
    print("="*60)
    
    try:
        # Test avec une table inexistante
        print("📋 Test avec table inexistante...")
        data, error = service.execute_query("table_inexistante")
        
        if error:
            print(f"✅ Erreur correctement gérée: {error}")
        else:
            print("❌ Erreur non détectée")
        
        # Test avec une requête invalide
        print("📋 Test avec requête invalide...")
        data, error = service.execute_query("supplier", "SELECT * FROM table_inexistante")
        
        if error:
            print(f"✅ Erreur SQL correctement gérée: {error[:100]}...")
        else:
            print("❌ Erreur SQL non détectée")
        
        return True
        
    except Exception as e:
        print(f"❌ Erreur lors du test de gestion d'erreurs: {e}")
        return False

def main():
    """Fonction principale de test"""
    print("🧪 SUITE DE TESTS - SERVICE D'EXPORT DYNAMIQUE")
    print("="*60)
    
    # Configuration des logs
    setup_logging()
    
    # Série de tests
    tests = [
        ("Initialisation", test_service_initialization),
        ("Métadonnées", lambda service: test_metadata_loading(service)),
        ("Requêtes dynamiques", lambda service: test_dynamic_query_building(service)),
        ("Exécution", lambda service: test_query_execution(service)),
        ("Export complet", lambda service: test_export_functionality(service)),
        ("Gestion d'erreurs", lambda service: test_error_handling(service))
    ]
    
    service = None
    passed = 0
    failed = 0
    
    for test_name, test_func in tests:
        print(f"\n🔍 Exécution du test: {test_name}")
        
        try:
            if test_name == "Initialisation":
                service = test_func()
                if service:
                    passed += 1
                    print(f"✅ Test {test_name} réussi")
                else:
                    failed += 1
                    print(f"❌ Test {test_name} échoué")
                    break
            else:
                if service and test_func(service):
                    passed += 1
                    print(f"✅ Test {test_name} réussi")
                else:
                    failed += 1
                    print(f"❌ Test {test_name} échoué")
                    
        except Exception as e:
            failed += 1
            print(f"❌ Test {test_name} échoué avec exception: {e}")
    
    # Résumé final
    print("\n" + "="*60)
    print("📊 RÉSULTATS DES TESTS")
    print("="*60)
    print(f"✅ Tests réussis: {passed}")
    print(f"❌ Tests échoués: {failed}")
    print(f"📊 Total: {passed + failed}")
    
    if failed == 0:
        print("🎉 TOUS LES TESTS SONT RÉUSSIS!")
        print("✅ Le service d'export dynamique fonctionne correctement")
    else:
        print("⚠️ CERTAINS TESTS ONT ÉCHOUÉ")
        print("❌ Vérifiez les erreurs ci-dessus")
    
    return failed == 0

if __name__ == "__main__":
    success = main()
    sys.exit(0 if success else 1) 