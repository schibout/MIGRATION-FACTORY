#!/usr/bin/env python3
"""
Script pour corriger les noms de tables dans les requêtes d'export
Convertit les noms en majuscules vers les noms en minuscules existants dans PostgreSQL
"""

import sys
sys.path.append('backend')

from config.database import get_db_connection
import logging

# Configuration du logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

def fix_table_names():
    """Corrige tous les noms de tables dans les requêtes SQL"""
    
    # Mapping des noms de tables (MAJUSCULES -> minuscules)
    table_mappings = {
        'SUPPLIER_INFO_GENERAL': 'supplier_info_general',
        'SUPPLIER_INFO_ADDRESS': 'supplier_info_address', 
        'SUPPLIER_INFO_ADDRESS_TYPE': 'supplier_info_address_type',
        'SUPPLIER_INFO_OUR_ID': 'supplier_info_our_id',
        'SUPPLIER_INFO_CONTACT': 'supplier_info_contact',
        'SUPPLIER': 'supplier',
        'COMM_METHOD': 'comm_method',
        'SUPPLIER_ADDRESS': 'supplier_address',
        'IDENTITY_PAY_INFO': 'identity_pay_info',
        'PAYMENT_WAY_PER_IDENTITY': 'payment_way_per_identity',
        'PAYMENT_ADDRESS': 'payment_address',
        'IDENTITY_INVOICE_INFO': 'identity_invoice_info',
        'SUPPLIER_DOCUMENT_TAX_INFO': 'supplier_document_tax_info',
        'SUPPLIER_DELIVERY_TAX_CODE': 'supplier_delivery_tax_code',
        'SUPPLIER_TAX_INFO': 'supplier_tax_info'
    }
    
    try:
        with get_db_connection() as conn:
            cursor = conn.cursor()
            
            logger.info("🔄 Début de la correction des noms de tables...")
            
            for old_name, new_name in table_mappings.items():
                logger.info(f"🔧 Correction: {old_name} -> {new_name}")
                
                # Corriger la requête SQL
                update_query = """
                UPDATE etl_export_queries 
                SET sql_query = REPLACE(sql_query, %s, %s)
                WHERE table_name = %s AND sql_query LIKE %s
                """
                
                from_old = f'FROM {old_name}'
                from_new = f'FROM {new_name}'
                search_pattern = f'%{from_old}%'
                
                cursor.execute(update_query, (from_old, from_new, old_name, search_pattern))
                affected_rows = cursor.rowcount
                
                if affected_rows > 0:
                    logger.info(f"✅ {old_name}: {affected_rows} requête(s) mise(s) à jour")
                else:
                    logger.info(f"ℹ️ {old_name}: Aucune correction nécessaire")
            
            # Valider les changements
            conn.commit()
            logger.info("✅ Toutes les corrections ont été appliquées avec succès!")
            
            # Vérifier les résultats
            cursor.execute("SELECT table_name, LEFT(sql_query, 100) FROM etl_export_queries WHERE table_name IN %s", 
                          (tuple(table_mappings.keys()),))
            
            logger.info("\n📋 Aperçu des requêtes corrigées:")
            for row in cursor.fetchall():
                table_name, query_preview = row
                logger.info(f"   {table_name}: {query_preview}...")
                
    except Exception as e:
        logger.error(f"❌ Erreur lors de la correction: {str(e)}")
        raise

if __name__ == "__main__":
    fix_table_names() 