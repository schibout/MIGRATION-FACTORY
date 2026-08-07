#!/bin/bash

# Script à exécuter SUR LE SERVEUR DISTANT après avoir copié les fichiers
# Ce script installe les configurations nginx depuis le dossier ~/nginx

echo "========================================="
echo "INSTALLATION CONFIGURATIONS NGINX"
echo "========================================="
echo ""

# Définir le chemin du dossier nginx source
NGINX_SOURCE="$HOME/nginx"  # Ou ajustez selon où vous avez copié les fichiers

echo "1. Vérification des fichiers source..."
if [ ! -f "$NGINX_SOURCE/sites-available/default" ]; then
    echo "❌ Fichier default introuvable dans $NGINX_SOURCE/sites-available/"
    exit 1
fi
if [ ! -f "$NGINX_SOURCE/sites-available/migration-factory-8080.conf" ]; then
    echo "❌ Fichier migration-factory-8080.conf introuvable dans $NGINX_SOURCE/sites-available/"
    exit 1
fi
echo "✅ Fichiers source OK"
echo ""

echo "2. Sauvegarde des configurations actuelles..."
if [ -f /etc/nginx/sites-available/default ]; then
    sudo cp /etc/nginx/sites-available/default \
           /etc/nginx/sites-available/default.backup.$(date +%Y%m%d_%H%M%S)
    echo "✅ Configuration default sauvegardée"
fi

if [ -f /etc/nginx/sites-available/migration-factory-8080.conf ]; then
    sudo cp /etc/nginx/sites-available/migration-factory-8080.conf \
           /etc/nginx/sites-available/migration-factory-8080.conf.backup.$(date +%Y%m%d_%H%M%S)
    echo "✅ Configuration migration-factory-8080 sauvegardée"
fi
echo ""

echo "3. Installation de la configuration default (port 80)..."
sudo cp "$NGINX_SOURCE/sites-available/default" /etc/nginx/sites-available/default
echo "✅ Configuration default installée"
echo ""

echo "4. Installation de la configuration port 8080..."
sudo cp "$NGINX_SOURCE/sites-available/migration-factory-8080.conf" \
        /etc/nginx/sites-available/migration-factory-8080.conf
echo "✅ Configuration migration-factory-8080.conf installée"
echo ""

echo "5. Activation de la configuration port 8080..."
sudo ln -sf /etc/nginx/sites-available/migration-factory-8080.conf \
            /etc/nginx/sites-enabled/migration-factory-8080.conf
echo "✅ Configuration port 8080 activée"
echo ""

echo "6. Vérification de la configuration default..."
if [ ! -L /etc/nginx/sites-enabled/default ]; then
    echo "⚠️  Activation de la configuration default..."
    sudo ln -sf /etc/nginx/sites-available/default /etc/nginx/sites-enabled/default
    echo "✅ Configuration default activée"
else
    echo "✅ Configuration default déjà activée"
fi
echo ""

echo "7. Installation du contenu HTML..."
if [ -f "$NGINX_SOURCE/var/www/html/index.html" ]; then
    sudo mkdir -p /var/www/html
    sudo cp "$NGINX_SOURCE/var/www/html/index.html" /var/www/html/index.html
    echo "✅ index.html installé"
else
    echo "⚠️  index.html non trouvé (il existe peut-être déjà)"
fi
echo ""

echo "8. Test de la configuration nginx..."
sudo nginx -t

if [ $? -ne 0 ]; then
    echo "❌ Erreur de configuration nginx"
    echo ""
    echo "Pour revenir en arrière :"
    echo "  sudo cp /etc/nginx/sites-available/default.backup.* /etc/nginx/sites-available/default"
    exit 1
fi
echo "✅ Configuration valide"
echo ""

echo "9. Rechargement de nginx..."
sudo systemctl reload nginx

if [ $? -ne 0 ]; then
    echo "❌ Erreur lors du rechargement"
    exit 1
fi
echo "✅ Nginx rechargé"
echo ""

echo "10. Vérification du statut nginx..."
sudo systemctl status nginx --no-pager | head -10
echo ""

echo "11. Ports en écoute..."
sudo ss -tlnp | grep nginx
echo ""

echo "========================================="
echo "✅ INSTALLATION TERMINÉE AVEC SUCCÈS"
echo "========================================="
echo ""
echo "Configurations actives :"
echo "  - Port 80  : Toutes les requêtes → /var/www/html/index.html"
echo "  - Port 8080: Toutes les requêtes → /var/www/html/index.html"
echo ""
echo "Configurations disponibles :"
echo "  /etc/nginx/sites-available/default"
echo "  /etc/nginx/sites-available/migration-factory-8080.conf"
echo ""
echo "Configurations activées :"
echo "  /etc/nginx/sites-enabled/default"
echo "  /etc/nginx/sites-enabled/migration-factory-8080.conf"
echo ""
echo "Testez maintenant :"
echo "  http://10.190.100.58"
echo "  http://10.190.100.58:8080"
echo ""
