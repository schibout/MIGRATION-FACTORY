#!/bin/bash

# Arrêter le script en cas d'erreur
set -e

# Installer les dépendances si besoin
if [ ! -d "node_modules" ]; then
  echo "Installation des dépendances..."
  npm install
fi

# Démarrer l'application en mode développement
npm run dev 