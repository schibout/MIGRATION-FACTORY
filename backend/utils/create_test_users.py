#!/usr/bin/env python3
"""
Script pour créer des utilisateurs de test en développement
Utilisez ce script pour créer des comptes Admin et Operator de test
"""

import sys
import os

# Ajouter le répertoire parent au path pour importer les modules
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from models import db, User
from app import create_app

def create_test_users():
    """Créer des utilisateurs de test pour le développement"""
    
    # Créer l'application Flask
    app = create_app()
    
    with app.app_context():
        print("🚀 Création des utilisateurs de test...")
        
        # Vérifier si les utilisateurs existent déjà
        admin_exists = User.query.filter_by(username='admin').first()
        operator_exists = User.query.filter_by(username='operator').first()
        
        if admin_exists:
            print("ℹ️  Utilisateur 'admin' existe déjà")
        else:
            # Créer un utilisateur Admin
            admin_user = User(
                username='admin',
                email='admin@migration-factory.com',
                role='admin'
            )
            admin_user.password = 'admin123'  # Mot de passe simple pour le dev
            
            db.session.add(admin_user)
            print("✅ Utilisateur Admin créé: admin / admin123")
        
        if operator_exists:
            print("ℹ️  Utilisateur 'operator' existe déjà")
        else:
            # Créer un utilisateur Operator
            operator_user = User(
                username='operator',
                email='operator@migration-factory.com',
                role='operator'
            )
            operator_user.password = 'operator123'  # Mot de passe simple pour le dev
            
            db.session.add(operator_user)
            print("✅ Utilisateur Operator créé: operator / operator123")
        
        try:
            db.session.commit()
            print("\n🎉 Utilisateurs de test créés avec succès!")
            print("\n📋 Identifiants de connexion:")
            print("   👑 Admin:    admin / admin123")
            print("   👤 Operator: operator / operator123")
            print("\n⚠️  Ces comptes sont uniquement pour le développement!")
            
        except Exception as e:
            db.session.rollback()
            print(f"❌ Erreur lors de la création des utilisateurs: {e}")

if __name__ == '__main__':
    create_test_users() 