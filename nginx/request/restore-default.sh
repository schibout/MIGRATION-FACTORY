#!/bin/bash

# Script pour restaurer la configuration nginx par défaut

echo "========================================="
echo "RESTAURATION CONFIGURATION NGINX PAR DÉFAUT"
echo "========================================="
echo ""

echo "1. Sauvegarde de la configuration actuelle..."
if [ -f /etc/nginx/sites-available/migration-factory-8080.conf ]; then
    cp /etc/nginx/sites-available/migration-factory-8080.conf \
       /etc/nginx/sites-available/migration-factory-8080.conf.backup.$(date +%Y%m%d_%H%M%S)
    echo "✅ Configuration sauvegardée"
else
    echo "⚠️  Aucune configuration à sauvegarder"
fi
echo ""

echo "2. Suppression du lien symbolique migration-factory-8080..."
if [ -L /etc/nginx/sites-enabled/migration-factory-8080.conf ]; then
    rm /etc/nginx/sites-enabled/migration-factory-8080.conf
    echo "✅ Lien symbolique supprimé"
else
    echo "⚠️  Lien symbolique n'existe pas"
fi
echo ""

echo "3. Vérification du fichier default..."
if [ ! -L /etc/nginx/sites-enabled/default ]; then
    echo "⚠️  Activation de la configuration par défaut..."
    ln -s /etc/nginx/sites-available/default /etc/nginx/sites-enabled/default
    echo "✅ Configuration default activée"
else
    echo "✅ Configuration default déjà activée"
fi
echo ""

echo "4. Test de la configuration nginx..."
nginx -t
if [ $? -ne 0 ]; then
    echo "❌ Erreur de configuration"
    exit 1
fi
echo "✅ Configuration valide"
echo ""

echo "5. Rechargement de nginx..."
systemctl reload nginx
if [ $? -ne 0 ]; then
    echo "❌ Erreur lors du rechargement"
    exit 1
fi
echo "✅ Nginx rechargé"
echo ""

echo "6. Vérification du statut nginx..."
systemctl status nginx --no-pager | head -10
echo ""

echo "7. Ports en écoute..."
ss -tlnp | grep nginx
echo ""

echo "========================================="
echo "✅ RESTAURATION TERMINÉE"
echo "========================================="
echo ""
echo "Configuration nginx restaurée par défaut."
echo ""
echo "Configurations disponibles :"
echo "  - Port 80 : Configuration par défaut"
echo "  - Port 3000 : Frontend React (Docker)"
echo "  - Port 5000 : Backend API (Docker)"
echo ""
echo "La configuration migration-factory-8080 a été désactivée."
echo "Les sauvegardes sont dans : /etc/nginx/sites-available/*.backup.*"
echo ""
