"""
Configuration pytest partagée : garantit que le dossier `backend/` est sur
le sys.path pour que les tests puissent importer `services.*`, `api.*`, etc.
comme le fait l'application (cwd = backend).
"""
import os
import sys

BACKEND_DIR = os.path.dirname(os.path.abspath(__file__))
if BACKEND_DIR not in sys.path:
    sys.path.insert(0, BACKEND_DIR)
