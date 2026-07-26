#!/bin/bash

# Script de démarrage alternatif pour l'application Flask
# Ce script permet de contourner gunicorn si nécessaire

echo "=== Démarrage de l'application Flask ==="

# Vérifier les dépendances Python
echo "Vérification des dépendances Python..."
python check_dependencies.py
if [ $? -ne 0 ]; then
    echo "Erreur lors de la vérification des dépendances."
    echo "Tentative d'installation des dépendances manquantes..."
    pip install --no-cache-dir -r requirements.txt
    pip install --no-cache-dir psycopg2-binary
fi

# Variables d'environnement
export FLASK_APP=app.py
# Debug désactivé par défaut (ne PAS activer le debugger Werkzeug en production)
export FLASK_DEBUG=${FLASK_DEBUG:-0}

# Deux modes de démarrage possibles
START_MODE=${START_MODE:-gunicorn}

if [ "$START_MODE" = "gunicorn" ]; then
    echo "Démarrage avec gunicorn (mode production)..."
    
    # Paramètres configurables
    BIND=${BIND:-0.0.0.0:5000}
    WORKERS=${WORKERS:-4}
    TIMEOUT=${TIMEOUT:-300}
    # gthread : indispensable pour le streaming SSE (proxy Hermes) — un worker
    # sync serait bloqué pendant toute la durée d'un stream (4 chats = app gelée).
    # Rollback possible : WORKER_CLASS=sync. gthread est natif gunicorn (0 dépendance).
    WORKER_CLASS=${WORKER_CLASS:-gthread}
    THREADS=${THREADS:-8}
    # Niveau de log gunicorn : info par défaut (debug expose trop de détails en prod)
    GUNICORN_LOG_LEVEL=${GUNICORN_LOG_LEVEL:-info}

    echo "  - Bind: $BIND"
    echo "  - Workers: $WORKERS ($WORKER_CLASS x $THREADS threads)"
    echo "  - Timeout: $TIMEOUT"
    echo "  - Log level: $GUNICORN_LOG_LEVEL"

    exec gunicorn --bind $BIND \
                 --workers $WORKERS \
                 --worker-class $WORKER_CLASS \
                 --threads $THREADS \
                 --timeout $TIMEOUT \
                 --log-level $GUNICORN_LOG_LEVEL \
                 --preload \
                 app:create_app\(\)
else
    echo "Démarrage avec Flask built-in server (mode développement)..."
    exec python -m flask run --host=0.0.0.0 --port=5000
fi