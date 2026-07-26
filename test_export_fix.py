#!/usr/bin/env python
# -*- coding: utf-8 -*-

import sys
sys.path.append('/app')

from services.export_service import ExportService

print("🔄 Test du service d'export avec connexion ETL...")

# Test du service
service = ExportService()
config = {'selectedTables': ['SUPPLIER'], 'includeHeaders': True, 'includeInactive': False}

try:
    result = service.export_supplier_data(config)
    print(f"✅ Lignes SUPPLIER: {len(result['results'].get('SUPPLIER', []))}")
    print(f"📊 Erreurs: {result['errors']}")
    print(f"📈 Total lignes: {result['summary']['total_rows']}")
    print(f"📋 Tables réussies: {result['summary']['successful_tables']}")
    
    if len(result['results'].get('SUPPLIER', [])) > 0:
        print("🎉 Export fonctionne correctement!")
        # Test du format ZIP
        zip_content, mime_type, metadata = service.generate_export_file(config)
        print(f"📦 ZIP généré: {len(zip_content)} bytes")
        print(f"📂 Catégorie: {metadata.get('primary_category')}")
    else:
        print("⚠️ Aucune donnée extraite")
        
except Exception as e:
    print(f"❌ Erreur: {e}")
    import traceback
    traceback.print_exc() 