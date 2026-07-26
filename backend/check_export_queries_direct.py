#!/usr/bin/env python3
"""
Script pour examiner la structure de la table etl_export_queries
Utilise directement les variables PG_ du fichier .env
"""

import psycopg2
import psycopg2.extras
import os
from dotenv import load_dotenv

# Charger les variables d'environnement
load_dotenv()

def get_connection():
    """Créer une connexion PostgreSQL avec les variables PG_"""
    return psycopg2.connect(
        host=os.getenv("PG_HOST", "localhost"),
        port=os.getenv("PG_PORT", "5432"),
        database=os.getenv("PG_DATABASE", "sap_migration_db"),
        user=os.getenv("PG_USER", "postgres"),
        password=os.getenv("PG_PASSWORD", "trimet2025")
    )

def execute_query(query, params=None):
    """Exécuter une requête et retourner les résultats"""
    with get_connection() as conn:
        with conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor) as cursor:
            cursor.execute(query, params)
            return cursor.fetchall()

def main():
    """Examine la structure de la table etl_export_queries"""
    print("🔍 Examen de la table etl_export_queries")
    print("="*60)
    
    # Afficher la configuration
    print(f"Configuration PostgreSQL:")
    print(f"  Host: {os.getenv('PG_HOST')}")
    print(f"  Port: {os.getenv('PG_PORT')}")
    print(f"  Database: {os.getenv('PG_DATABASE')}")
    print(f"  User: {os.getenv('PG_USER')}")
    
    # Test de connexion
    print("\n1. Test de connexion...")
    try:
        with get_connection() as conn:
            with conn.cursor() as cursor:
                cursor.execute("SELECT 1")
                result = cursor.fetchone()
                if result and result[0] == 1:
                    print("✅ Connexion réussie")
                else:
                    print("❌ Test de connexion échoué")
                    return False
    except Exception as e:
        print(f"❌ Erreur de connexion: {e}")
        return False
    
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
            
            # Afficher toutes les colonnes disponibles
            print("Colonnes disponibles dans la table:")
            for key in first_query.keys():
                value = first_query[key]
                if key == 'sql_query' and value:
                    print(f"  {key}: {str(value)[:100]}..." if len(str(value)) > 100 else f"  {key}: {value}")
                else:
                    print(f"  {key}: {value}")
        
        print(f"\n✅ Examen terminé - {len(results)} requêtes actives disponibles")
        
        # Sauvegarder les détails pour analyse
        print(f"\n5. Sauvegarde des détails pour analyse...")
        
        # Créer un fichier de sortie avec tous les détails
        with open('export_queries_analysis.txt', 'w', encoding='utf-8') as f:
            f.write("=== ANALYSE DE LA TABLE etl_export_queries ===\n\n")
            
            f.write("STRUCTURE:\n")
            for col in columns:
                nullable = "NULL" if col['is_nullable'] == 'YES' else "NOT NULL"
                default = f" DEFAULT {col['column_default']}" if col['column_default'] else ""
                f.write(f"  - {col['column_name']}: {col['data_type']} {nullable}{default}\n")
            
            f.write(f"\nRÉSULTATS ({len(results)} requêtes actives):\n")
            for i, row in enumerate(results):
                f.write(f"\n--- Requête {i+1} ---\n")
                for key, value in row.items():
                    f.write(f"{key}: {value}\n")
                f.write("\n")
        
        print("📄 Détails sauvegardés dans export_queries_analysis.txt")
        return True
        
    except Exception as e:
        print(f"❌ Erreur lors de la récupération des données: {e}")
        return False

if __name__ == "__main__":
    main() 