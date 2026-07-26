#!/usr/bin/env python3
"""
Script pour créer la table import_file_types_config
"""

import sys
import os
sys.path.append(os.path.dirname(os.path.abspath(__file__)))

from config.database import db, get_db_connection
from app import create_app
from models.import_config import ImportFileTypesConfig

def create_import_config_table():
    """Créer la table import_file_types_config et insérer les données initiales"""
    
    app = create_app()
    
    with app.app_context():
        try:
            # Créer la table
            db.create_all()
            print("✅ Table import_file_types_config créée avec succès")
            
            # Vérifier si des données existent déjà
            existing_count = ImportFileTypesConfig.query.count()
            if existing_count > 0:
                print(f"ℹ️  {existing_count} configurations déjà présentes")
                return
            
            # Insérer les données initiales
            configs = [
                {
                    'type_code': 'customer_info',
                    'display_name': 'Informations Client',
                    'description': 'Données principales du client',
                    'category': 'customer',
                    'required_columns': ['client_id', 'name', 'email'],
                    'optional_columns': ['phone', 'company'],
                    'validation_rules': {'email': 'email_format', 'client_id': 'unique'},
                    'target_table': 'clean_data.customer_info',
                    'processor_class': 'CustomerInfoProcessor',
                    'icon': 'person'
                },
                {
                    'type_code': 'customer_info_address',
                    'display_name': 'Adresses Client',
                    'description': 'Adresses de facturation et livraison',
                    'category': 'customer',
                    'required_columns': ['client_id', 'address_line1', 'city', 'postal_code'],
                    'optional_columns': ['address_line2', 'country'],
                    'validation_rules': {'postal_code': 'postal_format', 'client_id': 'exists_in_customers'},
                    'target_table': 'clean_data.customer_addresses',
                    'processor_class': 'CustomerAddressProcessor',
                    'icon': 'location_on'
                },
                {
                    'type_code': 'customer_info_address_type',
                    'display_name': 'Types Adresses',
                    'description': 'Classification des adresses',
                    'category': 'customer',
                    'required_columns': ['client_id', 'address_id', 'address_type'],
                    'optional_columns': ['is_default', 'priority'],
                    'validation_rules': {'address_type': 'enum:billing,shipping,both'},
                    'target_table': 'clean_data.customer_address_types',
                    'processor_class': 'CustomerAddressTypeProcessor',
                    'icon': 'category'
                },
                {
                    'type_code': 'customer_info_tax',
                    'display_name': 'Informations Fiscales',
                    'description': 'TVA, SIRET, codes fiscaux',
                    'category': 'customer',
                    'required_columns': ['client_id', 'tax_number'],
                    'optional_columns': ['vat_rate', 'tax_exemption', 'siret'],
                    'validation_rules': {'tax_number': 'tax_format', 'vat_rate': 'numeric_range:0,100'},
                    'target_table': 'clean_data.customer_tax_info',
                    'processor_class': 'CustomerTaxProcessor',
                    'icon': 'receipt'
                },
                {
                    'type_code': 'customer_delivery_tax_info',
                    'display_name': 'Fiscalité Livraison',
                    'description': 'Règles fiscales par zone',
                    'category': 'customer',
                    'required_columns': ['client_id', 'delivery_zone', 'tax_rate'],
                    'optional_columns': ['tax_exemption', 'special_rules'],
                    'validation_rules': {'tax_rate': 'numeric_range:0,100'},
                    'target_table': 'clean_data.customer_delivery_tax',
                    'processor_class': 'CustomerDeliveryTaxProcessor',
                    'icon': 'local_shipping'
                },
                {
                    'type_code': 'customer_commercial_info',
                    'display_name': 'Infos Commerciales',
                    'description': 'Conditions et remises',
                    'category': 'customer',
                    'required_columns': ['client_id', 'commercial_id'],
                    'optional_columns': ['discount_rate', 'payment_terms', 'credit_limit'],
                    'validation_rules': {'discount_rate': 'numeric_range:0,100', 'credit_limit': 'positive_number'},
                    'target_table': 'clean_data.customer_commercial',
                    'processor_class': 'CustomerCommercialProcessor',
                    'icon': 'business'
                }
            ]
            
            for config_data in configs:
                config = ImportFileTypesConfig(**config_data)
                db.session.add(config)
            
            db.session.commit()
            print(f"✅ {len(configs)} configurations d'import ajoutées avec succès")
            
            # Vérifier les données créées
            total_count = ImportFileTypesConfig.query.count()
            customer_count = ImportFileTypesConfig.query.filter_by(category='customer').count()
            print(f"📊 Total configurations: {total_count}")
            print(f"📊 Configurations customer: {customer_count}")
            
        except Exception as e:
            print(f"❌ Erreur lors de la création: {e}")
            db.session.rollback()
            return False
            
    return True

if __name__ == "__main__":
    print("🚀 Création de la table import_file_types_config...")
    success = create_import_config_table()
    if success:
        print("✅ Script terminé avec succès")
    else:
        print("❌ Script terminé avec des erreurs")
        sys.exit(1) 