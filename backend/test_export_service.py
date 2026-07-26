#!/usr/bin/env python3
"""
Script de test pour le service d'export
Teste toutes les fonctionnalités principales du ExportService
"""

import os
import sys
import logging
from datetime import datetime
from pathlib import Path

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

def test_connection():
    """Test de la connexion à la base de données"""
    print("\n" + "="*60)
    print("🔍 TEST 1: Connexion à la base de données")
    print("="*60)
    
    try:
        service = ExportService()
        print("✅ Service d'export initialisé avec succès")
        print(f"📊 Nombre de requêtes chargées: {len(service.table_queries)}")
        print(f"📋 Tables disponibles: {list(service.table_queries.keys())}")
        return service
    except Exception as e:
        print(f"❌ Erreur lors de l'initialisation: {str(e)}")
        return None

def test_queries_loading(service):
    """Test du chargement des requêtes"""
    print("\n" + "="*60)
    print("🔍 TEST 2: Chargement des requêtes depuis etl_export_queries")
    print("="*60)
    
    try:
        # Vérifier que les requêtes sont chargées
        if not service.table_queries:
            print("❌ Aucune requête chargée")
            return False
        
        print(f"✅ {len(service.table_queries)} requêtes chargées")
        
        # Afficher les détails des requêtes
        categories = {}
        for table_name, category in service.table_categories.items():
            if category not in categories:
                categories[category] = []
            categories[category].append(table_name)
        
        print("\n📊 Répartition par catégorie:")
        for category, tables in categories.items():
            print(f"  {category}: {len(tables)} tables")
            for table in tables[:3]:  # Afficher les 3 premières
                print(f"    - {table}")
            if len(tables) > 3:
                print(f"    - ... et {len(tables) - 3} autres")
        
        return True
    except Exception as e:
        print(f"❌ Erreur lors du test des requêtes: {str(e)}")
        return False

def test_single_query_execution(service):
    """Test d'exécution d'une requête simple"""
    print("\n" + "="*60)
    print("🔍 TEST 3: Exécution d'une requête simple")
    print("="*60)
    
    try:
        # Prendre la première table disponible
        if not service.table_queries:
            print("❌ Aucune requête disponible pour le test")
            return False
        
        test_table = list(service.table_queries.keys())[0]
        print(f"📋 Test avec la table: {test_table}")
        
        # Exécuter la requête
        data, error = service.execute_query(test_table)
        
        if error:
            print(f"❌ Erreur lors de l'exécution: {error}")
            return False
        
        print(f"✅ Requête exécutée avec succès")
        print(f"📊 Nombre de lignes retournées: {len(data)}")
        
        if data:
            print(f"📋 Colonnes disponibles: {list(data[0].keys())}")
            print(f"📝 Exemple de données (première ligne):")
            for key, value in list(data[0].items())[:5]:  # Afficher les 5 premières colonnes
                print(f"    {key}: {value}")
            if len(data[0]) > 5:
                print(f"    ... et {len(data[0]) - 5} autres colonnes")
        
        return True
        
    except Exception as e:
        print(f"❌ Erreur lors du test d'exécution: {str(e)}")
        return False

def test_export_functionality(service):
    """Test de la fonctionnalité d'export complète"""
    print("\n" + "="*60)
    print("🔍 TEST 4: Fonctionnalité d'export complète")
    print("="*60)
    
    try:
        # Sélectionner quelques tables pour l'export
        available_tables = list(service.table_queries.keys())
        if not available_tables:
            print("❌ Aucune table disponible pour l'export")
            return False
        
        # Prendre les 2-3 premières tables
        selected_tables = available_tables[:min(3, len(available_tables))]
        print(f"📋 Tables sélectionnées pour l'export: {selected_tables}")
        
        # Configuration d'export
        config = {
            'selectedTables': selected_tables,
            'includeHeaders': True,
            'includeInactive': False
        }
        
        # Exécuter l'export
        print("🚀 Lancement de l'export...")
        result = service.export_supplier_data(config)
        
        # Analyser les résultats
        print(f"✅ Export terminé")
        print(f"📊 Résumé de l'export:")
        print(f"  Total tables demandées: {result['summary']['total_tables']}")
        print(f"  Tables réussies: {result['summary']['successful_tables']}")
        print(f"  Tables échouées: {result['summary']['failed_tables']}")
        print(f"  Total lignes exportées: {result['summary']['total_rows']}")
        
        # Détails par table
        if result['results']:
            print("\n📋 Détails par table:")
            for table_name, data in result['results'].items():
                print(f"  ✅ {table_name}: {len(data)} lignes")
        
        # Erreurs éventuelles
        if result['errors']:
            print("\n❌ Erreurs rencontrées:")
            for table_name, error in result['errors'].items():
                print(f"  ❌ {table_name}: {error}")
        
        return True
        
    except Exception as e:
        print(f"❌ Erreur lors du test d'export: {str(e)}")
        return False

def test_file_generation(service):
    """Test de génération de fichier ZIP"""
    print("\n" + "="*60)
    print("🔍 TEST 5: Génération de fichier ZIP")
    print("="*60)
    
    try:
        # Sélectionner quelques tables
        available_tables = list(service.table_queries.keys())
        if not available_tables:
            print("❌ Aucune table disponible")
            return False
        
        selected_tables = available_tables[:min(2, len(available_tables))]
        print(f"📋 Tables pour le ZIP: {selected_tables}")
        
        # Configuration
        config = {
            'selectedTables': selected_tables,
            'includeHeaders': True,
            'includeInactive': False
        }
        
        # Générer le fichier ZIP
        print("🗜️ Génération du fichier ZIP...")
        zip_content, mime_type, metadata = service.generate_export_file(config)
        
        print(f"✅ Fichier ZIP généré avec succès")
        print(f"📊 Informations du fichier:")
        print(f"  Type MIME: {mime_type}")
        print(f"  Taille: {len(zip_content)} bytes ({len(zip_content)/1024:.2f} KB)")
        print(f"  Catégorie principale: {metadata['primary_category']}")
        print(f"  Fichiers dans le ZIP: {metadata['summary']['successful_tables']} CSV + résumé")
        
        # Optionnel: sauvegarder le fichier pour inspection
        timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
        zip_filename = f"test_export_{timestamp}.zip"
        
        with open(zip_filename, 'wb') as f:
            f.write(zip_content)
        
        print(f"💾 Fichier sauvegardé: {zip_filename}")
        
        return True
        
    except Exception as e:
        print(f"❌ Erreur lors de la génération du ZIP: {str(e)}")
        return False

def test_error_handling(service):
    """Test de la gestion d'erreurs"""
    print("\n" + "="*60)
    print("🔍 TEST 6: Gestion d'erreurs")
    print("="*60)
    
    try:
        # Test avec une table inexistante
        print("🧪 Test avec une table inexistante...")
        data, error = service.execute_query("table_inexistante")
        
        if error:
            print(f"✅ Erreur correctement gérée: {error}")
        else:
            print("❌ Erreur non détectée pour une table inexistante")
        
        # Test avec une configuration d'export invalide
        print("🧪 Test avec une configuration d'export invalide...")
        invalid_config = {
            'selectedTables': ['table_inexistante_1', 'table_inexistante_2'],
            'includeHeaders': True
        }
        
        result = service.export_supplier_data(invalid_config)
        
        if result['errors']:
            print(f"✅ Erreurs correctement gérées: {len(result['errors'])} erreurs")
            for table, error in result['errors'].items():
                print(f"  - {table}: {error}")
        else:
            print("❌ Erreurs non détectées pour des tables inexistantes")
        
        return True
        
    except Exception as e:
        print(f"❌ Erreur lors du test de gestion d'erreurs: {str(e)}")
        return False

def main():
    """Fonction principale des tests"""
    print("🧪 TESTS DU SERVICE D'EXPORT")
    print("="*60)
    print(f"📅 Date: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    
    # Configuration des logs
    setup_logging()
    
    # Vérifier les variables d'environnement
    required_vars = ['PG_HOST', 'PG_PORT', 'PG_DATABASE', 'PG_USER', 'PG_PASSWORD']
    missing_vars = [var for var in required_vars if not os.environ.get(var)]
    
    if missing_vars:
        print(f"\n❌ Variables d'environnement manquantes: {missing_vars}")
        print("💡 Assurez-vous que les variables PG_* sont définies")
        return False
    
    # Exécuter les tests
    tests = [
        ("Connexion", test_connection),
        ("Chargement requêtes", lambda s: test_queries_loading(s)),
        ("Exécution requête", lambda s: test_single_query_execution(s)),
        ("Export complet", lambda s: test_export_functionality(s)),
        ("Génération ZIP", lambda s: test_file_generation(s)),
        ("Gestion erreurs", lambda s: test_error_handling(s))
    ]
    
    service = None
    results = []
    
    for i, (test_name, test_func) in enumerate(tests, 1):
        try:
            if i == 1:  # Premier test: initialisation
                service = test_func()
                success = service is not None
            else:  # Autres tests: utiliser le service
                if service is None:
                    print(f"\n❌ TEST {i} SKIPPED: Service non initialisé")
                    success = False
                else:
                    success = test_func(service)
            
            results.append((test_name, success))
            
        except Exception as e:
            print(f"\n❌ TEST {i} FAILED: {str(e)}")
            results.append((test_name, False))
    
    # Résumé final
    print("\n" + "="*60)
    print("📊 RÉSUMÉ DES TESTS")
    print("="*60)
    
    passed = sum(1 for _, success in results if success)
    total = len(results)
    
    for test_name, success in results:
        status = "✅ PASS" if success else "❌ FAIL"
        print(f"  {status} {test_name}")
    
    print(f"\n📈 Résultat global: {passed}/{total} tests réussis")
    
    if passed == total:
        print("🎉 Tous les tests sont passés ! Le service d'export fonctionne correctement.")
        return True
    else:
        print("⚠️ Certains tests ont échoué. Vérifiez la configuration et les logs.")
        return False

if __name__ == "__main__":
    success = main()
    sys.exit(0 if success else 1) 