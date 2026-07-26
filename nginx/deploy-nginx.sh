#!/bin/bash

# Script de déploiement Nginx pour Migration Factory
# Version: 1.0
# Date: $(date +%Y-%m-%d)

set -e  # Arrêter le script en cas d'erreur

# Couleurs pour les messages
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Fonction pour afficher les messages
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Vérifier que le script est exécuté en tant que root
if [[ $EUID -ne 0 ]]; then
   log_error "Ce script doit être exécuté en tant que root (sudo)"
   exit 1
fi

log_info "🚀 Démarrage du déploiement Nginx pour Migration Factory"

# 1. Vérifier que Nginx est installé
if ! command -v nginx &> /dev/null; then
    log_error "Nginx n'est pas installé. Installez-le d'abord avec:"
    echo "sudo apt update && sudo apt install nginx"
    exit 1
fi

log_success "✅ Nginx est installé"

# 2. Créer les répertoires nécessaires
log_info "📁 Création des répertoires web..."

mkdir -p /var/www/html
mkdir -p /var/www/migration-factory
mkdir -p /var/log/nginx

# 3. Copier les fichiers de configuration
log_info "📄 Copie des fichiers de configuration..."

# Sauvegarder le nginx.conf existant
if [ ! -f /etc/nginx/nginx.conf.backup ]; then
    cp /etc/nginx/nginx.conf /etc/nginx/nginx.conf.backup
    log_info "💾 Sauvegarde du nginx.conf existant"
fi

# Ajouter les définitions de rate limiting au nginx.conf principal
log_info "🔧 Configuration des zones de rate limiting..."

# Créer un fichier temporaire avec les définitions de rate limiting
cat > /tmp/rate_limiting.conf << 'EOF'
    # Rate Limiting Zones pour Migration Factory
    limit_req_zone $binary_remote_addr zone=global:10m rate=20r/s;
    limit_req_zone $binary_remote_addr zone=login:10m rate=3r/m;
    limit_req_zone $binary_remote_addr zone=api:10m rate=50r/s;
    limit_req_zone $binary_remote_addr zone=export:10m rate=2r/m;
EOF

# Vérifier si les définitions existent déjà
if ! grep -q "zone=global" /etc/nginx/nginx.conf; then
    # Ajouter les définitions après la ligne "http {"
    sed -i '/^http {/r /tmp/rate_limiting.conf' /etc/nginx/nginx.conf
    log_info "✅ Zones de rate limiting ajoutées"
else
    log_info "ℹ️ Zones de rate limiting déjà présentes"
fi

# Nettoyer le fichier temporaire
rm -f /tmp/rate_limiting.conf

# Copier les configurations de sites
cp migration-factory-8080.conf /etc/nginx/sites-available/
cp main-80.conf /etc/nginx/sites-available/

# Copier la page d'accueil
cp index.html /var/www/html/

log_success "✅ Fichiers copiés"

# 4. Activer les sites
log_info "🔗 Activation des sites..."

# Supprimer le lien symbolique default s'il existe
if [ -L /etc/nginx/sites-enabled/default ]; then
    rm /etc/nginx/sites-enabled/default
    log_info "🗑️ Site default désactivé"
fi

# Créer les liens symboliques
ln -sf /etc/nginx/sites-available/main-80.conf /etc/nginx/sites-enabled/
ln -sf /etc/nginx/sites-available/migration-factory-8080.conf /etc/nginx/sites-enabled/

log_success "✅ Sites activés"

# 5. Configurer les permissions
log_info "🔒 Configuration des permissions..."

chown -R www-data:www-data /var/www/html
chown -R www-data:www-data /var/www/migration-factory
chmod -R 755 /var/www/html
chmod -R 755 /var/www/migration-factory

log_success "✅ Permissions configurées"

# 6. Tester la configuration Nginx
log_info "🧪 Test de la configuration Nginx..."

if nginx -t; then
    log_success "✅ Configuration Nginx valide"
else
    log_error "❌ Erreur dans la configuration Nginx"
    log_info "Vérifiez les logs avec: sudo journalctl -u nginx"
    exit 1
fi

# 7. Recharger Nginx
log_info "🔄 Rechargement de Nginx..."

systemctl reload nginx

if systemctl is-active --quiet nginx; then
    log_success "✅ Nginx rechargé avec succès"
else
    log_error "❌ Erreur lors du rechargement de Nginx"
    log_info "Vérifiez le statut avec: sudo systemctl status nginx"
    exit 1
fi

# 8. Vérifier que les ports sont ouverts
log_info "🔍 Vérification des ports..."

if netstat -tuln | grep -q ":80 "; then
    log_success "✅ Port 80 ouvert"
else
    log_warning "⚠️ Port 80 non détecté"
fi

if netstat -tuln | grep -q ":8080 "; then
    log_success "✅ Port 8080 ouvert"
else
    log_warning "⚠️ Port 8080 non détecté"
fi

# 9. Afficher le résumé
log_info "📋 Résumé du déploiement:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🌐 Page d'accueil: http://10.190.100.58"
echo "🏭 Migration Factory: http://10.190.100.58:8080"
echo "📁 Répertoire web principal: /var/www/html"
echo "📁 Répertoire Migration Factory: /var/www/migration-factory"
echo "📊 Logs nginx: /var/log/nginx/"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# 10. Afficher les commandes utiles
log_info "🛠️ Commandes utiles:"
echo "• Redémarrer Nginx: sudo systemctl restart nginx"
echo "• Recharger Nginx: sudo systemctl reload nginx"
echo "• Vérifier le statut: sudo systemctl status nginx"
echo "• Tester la config: sudo nginx -t"
echo "• Voir les logs: sudo tail -f /var/log/nginx/error.log"
echo "• Voir les logs access: sudo tail -f /var/log/nginx/access.log"
echo "• Restaurer l'ancien nginx.conf: sudo cp /etc/nginx/nginx.conf.backup /etc/nginx/nginx.conf"

log_success "🎉 Déploiement terminé avec succès!"
log_info "Vous pouvez maintenant accéder à vos applications via les URLs ci-dessus"
log_info "✅ Problèmes corrigés : Format de log 'main' et zones de rate limiting" 