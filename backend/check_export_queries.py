#!/usr/bin/env python3
"""
Script pour examiner la structure de la table etl_export_queries
"""

import sys
import os
from pathlib import Path

# Ajouter le répertoire parent au path pour importer les modules
sys.path.append(str(Path(__file__).parent))

from config.database import execute_query, test_connection

def main():
    """Examine la structure de la table etl_export_queries"""
    print("🔍 Examen de la table etl_export_queries")
    print("="*60)
    
    # Test de connexion
    print("1. Test de connexion...")
    if not test_connection():
        print("❌ Impossible de se connecter à la base de données")
        return False
    
    print("✅ Connexion réussie")
    
    # Examiner la structure de la table
    print("\n2. Structure de la table etl_export_queries:")
    print("-" * 40)
    
    try:
        # Requête pour voir la structure
        structure_query = """
        SELECT column_name, data_type, is_nullable, column_default
        FROM information_schema.columns
        WHERE table_name = 'etl_export_queries'
        AND table_schema = 'public'
        ORDER BY ordinal_position
        """
        
        columns = execute_query(structure_query)
        
        if not columns:
            print("❌ Table etl_export_queries non trouvée ou vide")
            return False
        
        print(f"📊 {len(columns)} colonnes trouvées:")
        for col in columns:
            nullable = "NULL" if col['is_nullable'] == 'YES' else "NOT NULL"
            default = f" DEFAULT {col['column_default']}" if col['column_default'] else ""
            print(f"  - {col['column_name']}: {col['data_type']} {nullable}{default}")
        
    except Exception as e:
        print(f"❌ Erreur lors de la récupération de la structure: {e}")
        return False
    
    # Examiner les données actives
    print("\n3. Requêtes actives dans la table:")
    print("-" * 40)
    
    try:
        # Requête pour voir les données actives
        data_query = """
        SELECT * FROM etl_export_queries 
        WHERE is_active = true 
        ORDER BY category, table_name
        """
        
        results = execute_query(data_query)
        
        if not results:
            print("❌ Aucune requête active trouvée")
            return False
        
        print(f"📋 {len(results)} requêtes actives trouvées:")
        
        # Grouper par catégorie
        categories = {}
        for row in results:
            category = row.get('category', 'unknown')
            if category not in categories:
                categories[category] = []
            categories[category].append(row)
        
        for category, tables in categories.items():
            print(f"\n📂 Catégorie: {category} ({len(tables)} tables)")
            for table in tables:
                table_name = table.get('table_name', 'unknown')
                table_schema = table.get('table_schema', 'public')
                display_name = table.get('display_name', table_name)
                print(f"  ✅ {table_name} ({table_schema}) - {display_name}")
        
        # Afficher les détails de la première requête comme exemple
        if results:
            print(f"\n4. Exemple de requête (première trouvée):")
            print("-" * 40)
            first_query = results[0]
            print(f"Table: {first_query.get('table_name')}")
            print(f"Schéma: {first_query.get('table_schema')}")
            print(f"Nom d'affichage: {first_query.get('display_name')}")
            print(f"Catégorie: {first_query.get('category')}")
            print(f"Active: {first_query.get('is_active')}")
            print(f"Créé le: {first_query.get('created_at')}")
            print(f"Modifié le: {first_query.get('updated_at')}")
            if first_query.get('description'):
                print(f"Description: {first_query.get('description')}")
            
            sql_query = first_query.get('sql_query', '')
            if sql_query:
                print(f"\nRequête SQL (100 premiers caractères):")
                print(f"  {sql_query[:100]}...")
        
        print(f"\n✅ Examen terminé - {len(results)} requêtes actives disponibles")
        return True
        
    except Exception as e:
        print(f"❌ Erreur lors de la récupération des données: {e}")
        return False

if __name__ == "__main__":
    success = main()
    sys.exit(0 if success else 1) 