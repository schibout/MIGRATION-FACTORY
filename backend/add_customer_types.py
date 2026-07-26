#!/usr/bin/env python3
"""
Script pour ajouter les types de fichiers clients
"""

import sys
import os
sys.path.append(os.path.dirname(os.path.abspath(__file__)))

from config.database import db
from app import create_app
from models.import_config import ImportFileTypesConfig

def add_customer_types():
    """Ajouter les types de fichiers clients"""
    
    app = create_app()
    
    with app.app_context():
        try:
            # Vérifier si des types clients existent déjà
            existing_customer_types = ImportFileTypesConfig.query.filter(
                ImportFileTypesConfig.type_name.like('%customer%')
            ).count()
            
            if existing_customer_types > 0:
                print(f"ℹ️  {existing_customer_types} types clients déjà présents")
                return True
            
            # Définir les nouveaux types clients
            customer_configs = [
                {
                    'type_name': 'customer_info',
                    'display_name': 'Informations Client',
                    'description': 'Données principales du client (nom, email, téléphone)',
                    'target_table': 'clean_data.customer_info',
                    'processor_class': 'CustomerInfoProcessor',
                    'required_columns': ['client_id', 'name', 'email'],
                    'validation_rules': {
                        'email': 'email_format',
                        'client_id': 'unique'
                    },
                    'column_mapping': {
                        'nom': 'name',
                        'email': 'email',
                        'id_client': 'client_id',
                        'telephone': 'phone'
                    },
                    'is_active': True
                },
                {
                    'type_name': 'customer_address',
                    'display_name': 'Adresses Client',
                    'description': 'Adresses de facturation et livraison des clients',
                    'target_table': 'clean_data.customer_addresses',
                    'processor_class': 'CustomerAddressProcessor',
                    'required_columns': ['client_id', 'address_line1', 'city', 'postal_code'],
                    'validation_rules': {
                        'postal_code': 'postal_format',
                        'client_id': 'exists_in_customers'
                    },
                    'column_mapping': {
                        'id_client': 'client_id',
                        'adresse1': 'address_line1',
                        'adresse2': 'address_line2',
                        'ville': 'city',
                        'code_postal': 'postal_code',
                        'pays': 'country'
                    },
                    'is_active': True
                },
                {
                    'type_name': 'customer_tax',
                    'display_name': 'Informations Fiscales',
                    'description': 'TVA, SIRET et codes fiscaux des clients',
                    'target_table': 'clean_data.customer_tax_info',
                    'processor_class': 'CustomerTaxProcessor',
                    'required_columns': ['client_id', 'tax_number'],
                    'validation_rules': {
                        'tax_number': 'tax_format',
                        'vat_rate': 'numeric_range:0,100'
                    },
                    'column_mapping': {
                        'id_client': 'client_id',
                        'numero_tva': 'tax_number',
                        'taux_tva': 'vat_rate',
                        'siret': 'siret',
                        'exemption_tva': 'tax_exemption'
                    },
                    'is_active': True
                },
                {
                    'type_name': 'customer_commercial',
                    'display_name': 'Informations Commerciales',
                    'description': 'Conditions commerciales et remises clients',
                    'target_table': 'clean_data.customer_commercial',
                    'processor_class': 'CustomerCommercialProcessor',
                    'required_columns': ['client_id', 'commercial_id'],
                    'validation_rules': {
                        'discount_rate': 'numeric_range:0,100',
                        'credit_limit': 'positive_number'
                    },
                    'column_mapping': {
                        'id_client': 'client_id',
                        'id_commercial': 'commercial_id',
                        'taux_remise': 'discount_rate',
                        'conditions_paiement': 'payment_terms',
                        'limite_credit': 'credit_limit'
                    },
                    'is_active': True
                }
            ]
            
            # Ajouter chaque configuration
            for config_data in customer_configs:
                config = ImportFileTypesConfig(**config_data)
                db.session.add(config)
                print(f"➕ Ajout: {config_data['display_name']}")
            
            db.session.commit()
            print(f"✅ {len(customer_configs)} configurations clients ajoutées avec succès")
            
            # Vérifier les données créées
            total_count = ImportFileTypesConfig.query.count()
            customer_count = ImportFileTypesConfig.query.filter(
                ImportFileTypesConfig.type_name.like('%customer%')
            ).count()
            print(f"📊 Total configurations: {total_count}")
            print(f"📊 Configurations customer: {customer_count}")
            
            return True
            
        except Exception as e:
            print(f"❌ Erreur lors de l'ajout: {e}")
            db.session.rollback()
            return False

if __name__ == "__main__":
    print("🚀 Ajout des types de fichiers clients...")
    success = add_customer_types()
    if success:
        print("✅ Script terminé avec succès")
    else:
        print("❌ Script terminé avec des erreurs")
        sys.exit(1) 