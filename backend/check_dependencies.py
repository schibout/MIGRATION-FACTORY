#!/usr/bin/env python
# -*- coding: utf-8 -*-

"""
Script de vérification des dépendances Python critiques pour l'application
"""

import sys
import importlib.util
import subprocess

# Liste des dépendances critiques à vérifier
CRITICAL_DEPENDENCIES = {
    "psycopg2": "psycopg2-binary",  # Si psycopg2 échoue, utiliser psycopg2-binary
    "numpy": "numpy==1.26.2",        # Version spécifique recommandée
    "pandas": "pandas",              # Installation standard
    "flask": "flask",                # Framework web
    "flask_sqlalchemy": "Flask-SQLAlchemy"  # ORM
}

def check_dependency(module_name, fallback_package=None):
    """Vérifie si un module Python est installé et tente de l'installer si nécessaire"""
    print(f"Vérification de {module_name}...", end=" ")
    spec = importlib.util.find_spec(module_name)
    
    if spec is not None:
        print("✓ Installé")
        try:
            # Tenter d'importer pour détecter d'éventuels problèmes de compatibilité
            module = importlib.import_module(module_name)
            if hasattr(module, '__version__'):
                print(f"  - Version: {module.__version__}")
            return True
        except Exception as e:
            print(f"✗ Erreur lors de l'import: {e}")
    else:
        print("✗ Non installé")
    
    if fallback_package:
        print(f"  - Installation de {fallback_package}...")
        try:
            subprocess.check_call([sys.executable, "-m", "pip", "install", fallback_package])
            print(f"  - {fallback_package} installé avec succès.")
            return True
        except subprocess.CalledProcessError:
            print(f"  - Échec de l'installation de {fallback_package}")
    
    return False

def main():
    """Fonction principale qui vérifie toutes les dépendances critiques"""
    print("=== Vérification des dépendances Python ===")
    
    all_deps_ok = True
    for module_name, package_name in CRITICAL_DEPENDENCIES.items():
        if not check_dependency(module_name, package_name):
            all_deps_ok = False
    
    if all_deps_ok:
        print("\n✓ Toutes les dépendances critiques sont installées.")
        sys.exit(0)
    else:
        print("\n✗ Certaines dépendances sont manquantes ou incompatibles.")
        print("  Vérifiez les erreurs ci-dessus et installez les dépendances manquantes.")
        sys.exit(1)

if __name__ == "__main__":
    main()
