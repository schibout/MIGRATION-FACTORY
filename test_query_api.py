import requests
import json

# Test du nouvel endpoint de test de requête
def test_query_endpoint():
    try:
        # Récupérer une requête SQL existante
        response = requests.get('http://localhost:5000/export/queries')
        if response.status_code == 200:
            queries = response.json()['queries']
            if queries:
                first_query = queries[0]
                sql_query = first_query['sql_query']
                table_name = first_query['table_name']
                
                print(f"🔍 Test de la requête pour: {table_name}")
                print(f"📝 SQL: {sql_query[:100]}...")
                
                # Tester la requête avec le nouvel endpoint
                test_response = requests.post('http://localhost:5000/export/test-query', 
                    json={'sql_query': sql_query})
                
                if test_response.status_code == 200:
                    result = test_response.json()
                    if result.get('success'):
                        print(f"✅ Test réussi!")
                        print(f"📊 Total de lignes: {result.get('total_rows', 0)}")
                        print(f"👁️ Aperçu: {result.get('preview_rows', 0)} lignes")
                        print(f"📋 Colonnes: {len(result.get('columns', []))}")
                        
                        # Afficher un échantillon des données
                        if result.get('data'):
                            print(f"🔍 Première ligne d'aperçu:")
                            print(json.dumps(result['data'][0], indent=2, ensure_ascii=False))
                        else:
                            print("⚠️ Aucune donnée dans l'aperçu")
                    else:
                        print(f"❌ Erreur: {result.get('error')}")
                else:
                    print(f"❌ Erreur HTTP {test_response.status_code}: {test_response.text}")
            else:
                print("❌ Aucune requête trouvée")
        else:
            print(f"❌ Erreur lors de la récupération des requêtes: {response.status_code}")
            
    except Exception as e:
        print(f"❌ Erreur de connexion: {e}")

if __name__ == "__main__":
    test_query_endpoint() 