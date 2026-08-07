#!/bin/bash

# Script de déploiement des configurations nginx
# Port 80 et Port 8080 - Redirection vers index.html

echo "========================================="
echo "DÉPLOIEMENT CONFIGURATIONS NGINX"
echo "========================================="
echo ""

# Variables
SERVER_IP="10.190.100.58"
SERVER_USER="votre_user"  # À MODIFIER avec votre nom d'utilisateur
NGINX_SITES_AVAILABLE="/etc/nginx/sites-available"
NGINX_SITES_ENABLED="/etc/nginx/sites-enabled"

echo "Serveur cible: $SERVER_IP"
echo ""

echo "1. Vérification des fichiers locaux..."
if [ ! -f "../sites-available/default" ]; then
    echo "❌ Fichier default introuvable"
    exit 1
fi
if [ ! -f "../sites-available/migration-factory-8080.conf" ]; then
    echo "❌ Fichier migration-factory-8080.conf introuvable"
    exit 1
fi
echo "✅ Fichiers locaux OK"
echo ""

echo "2. Copie des fichiers vers le serveur..."
scp ../sites-available/default ${SERVER_USER}@${SERVER_IP}:/tmp/default
scp ../sites-available/migration-factory-8080.conf ${SERVER_USER}@${SERVER_IP}:/tmp/migration-factory-8080.conf
echo "✅ Fichiers copiés"
echo ""

echo "3. Installation des configurations sur le serveur..."
ssh ${SERVER_USER}@${SERVER_IP} << 'ENDSSH'
    echo "   - Sauvegarde des anciennes configs..."
    sudo cp /etc/nginx/sites-available/default /etc/nginx/sites-available/default.backup.$(date +%Y%m%d_%H%M%S)
    
    echo "   - Installation de la nouvelle config default..."
    sudo cp /tmp/default /etc/nginx/sites-available/default
    
    echo "   - Installation de la config migration-factory-8080..."
    sudo cp /tmp/migration-factory-8080.conf /etc/nginx/sites-available/migration-factory-8080.conf
    
    echo "   - Activation de la config port 8080..."
    sudo ln -sf /etc/nginx/sites-available/migration-factory-8080.conf /etc/nginx/sites-enabled/migration-factory-8080.conf
    
    echo "   - Nettoyage des fichiers temporaires..."
    rm /tmp/default /tmp/migration-factory-8080.conf
    
    echo ""
    echo "4. Test de la configuration nginx..."
    sudo nginx -t
    
    if [ $? -ne 0 ]; then
        echo "❌ Erreur de configuration nginx"
        exit 1
    fi
    echo "✅ Configuration valide"
    echo ""
    
    echo "5. Rechargement de nginx..."
    sudo systemctl reload nginx
    
    if [ $? -ne 0 ]; then
        echo "❌ Erreur lors du rechargement"
        exit 1
    fi
    echo "✅ Nginx rechargé"
    echo ""
    
    echo "6. Vérification du statut nginx..."
    sudo systemctl status nginx --no-pager | head -10
    echo ""
    
    echo "7. Ports en écoute..."
    sudo ss -tlnp | grep nginx
    echo ""
ENDSSH

if [ $? -eq 0 ]; then
    echo "========================================="
    echo "✅ DÉPLOIEMENT TERMINÉ AVEC SUCCÈS"
    echo "========================================="
    echo ""
    echo "Configurations actives :"
    echo "  - Port 80  : http://${SERVER_IP} → /var/www/html/index.html"
    echo "  - Port 8080: http://${SERVER_IP}:8080 → /var/www/html/index.html"
    echo ""
    echo "Testez les URLs :"
    echo "  curl http://${SERVER_IP}"
    echo "  curl http://${SERVER_IP}:8080"
    echo ""
else
    echo "========================================="
    echo "❌ ERREUR LORS DU DÉPLOIEMENT"
    echo "========================================="
    exit 1
fi
