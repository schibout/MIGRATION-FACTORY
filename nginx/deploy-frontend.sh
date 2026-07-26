#!/bin/bash

# Script de build et déploiement Frontend Migration Factory
# Version: 1.0
# Usage: ./deploy-frontend.sh [server_ip] [user]

set -e

# Configuration par défaut
SERVER_IP=${1:-"10.190.100.58"}
SERVER_USER=${2:-"user"}
FRONTEND_DIR="frontend"
BUILD_DIR="dist"
REMOTE_DIR="/var/www/migration-factory"

# Couleurs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

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

# Vérifier les prérequis
check_prerequisites() {
    log_info "🔍 Vérification des prérequis..."
    
    # Vérifier Node.js
    if ! command -v node &> /dev/null; then
        log_error "Node.js n'est pas installé"
        exit 1
    fi
    
    # Vérifier npm
    if ! command -v npm &> /dev/null; then
        log_error "npm n'est pas installé"
        exit 1
    fi
    
    # Vérifier que le dossier frontend existe
    if [ ! -d "$FRONTEND_DIR" ]; then
        log_error "Dossier frontend non trouvé: $FRONTEND_DIR"
        exit 1
    fi
    
    # Vérifier package.json
    if [ ! -f "$FRONTEND_DIR/package.json" ]; then
        log_error "package.json non trouvé dans $FRONTEND_DIR"
        exit 1
    fi
    
    log_success "✅ Prérequis vérifiés"
}

# Installer les dépendances
install_dependencies() {
    log_info "📦 Installation des dépendances..."
    
    cd "$FRONTEND_DIR"
    
    if [ ! -d "node_modules" ]; then
        log_info "Installation des dépendances npm..."
        npm install
    else
        log_info "Mise à jour des dépendances..."
        npm install
    fi
    
    cd ..
    log_success "✅ Dépendances installées"
}

# Builder le frontend
build_frontend() {
    log_info "🏗️ Build du frontend React..."
    
    cd "$FRONTEND_DIR"
    
    # Supprimer le build précédent
    if [ -d "$BUILD_DIR" ]; then
        rm -rf "$BUILD_DIR"
        log_info "🗑️ Ancien build supprimé"
    fi
    
    # Lancer le build
    npm run build
    
    # Vérifier que le build a réussi
    if [ ! -d "$BUILD_DIR" ]; then
        log_error "❌ Build échoué - dossier $BUILD_DIR non créé"
        exit 1
    fi
    
    # Vérifier que index.html existe
    if [ ! -f "$BUILD_DIR/index.html" ]; then
        log_error "❌ Build échoué - index.html non trouvé"
        exit 1
    fi
    
    cd ..
    log_success "✅ Build réussi"
}

# Déployer vers le serveur
deploy_to_server() {
    log_info "🚀 Déploiement vers le serveur $SERVER_IP..."
    
    # Créer un dossier temporaire pour le transfert
    TEMP_DIR="/tmp/migration-factory-$(date +%s)"
    
    # Transférer les fichiers
    log_info "📁 Transfert des fichiers..."
    scp -r "$FRONTEND_DIR/$BUILD_DIR" "$SERVER_USER@$SERVER_IP:$TEMP_DIR"
    
    # Commandes à exécuter sur le serveur
    SSH_COMMANDS="
        echo '🔄 Sauvegarde de l\'ancien déploiement...'
        sudo cp -r $REMOTE_DIR $REMOTE_DIR.backup.\$(date +%Y%m%d_%H%M%S) 2>/dev/null || true
        
        echo '📂 Déploiement des nouveaux fichiers...'
        sudo rm -rf $REMOTE_DIR/*
        sudo cp -r $TEMP_DIR/* $REMOTE_DIR/
        
        echo '🔒 Configuration des permissions...'
        sudo chown -R www-data:www-data $REMOTE_DIR
        sudo chmod -R 755 $REMOTE_DIR
        
        echo '🧹 Nettoyage...'
        rm -rf $TEMP_DIR
        
        echo '✅ Déploiement terminé'
    "
    
    # Exécuter les commandes sur le serveur
    log_info "⚙️ Exécution des commandes de déploiement..."
    ssh "$SERVER_USER@$SERVER_IP" "$SSH_COMMANDS"
    
    log_success "✅ Déploiement terminé"
}

# Vérifier le déploiement
verify_deployment() {
    log_info "🧪 Vérification du déploiement..."
    
    # Tester la connexion HTTP
    if curl -s -o /dev/null -w "%{http_code}" "http://$SERVER_IP:8080" | grep -q "200"; then
        log_success "✅ Application accessible sur http://$SERVER_IP:8080"
    else
        log_warning "⚠️ Application non accessible - vérifiez nginx et le backend"
    fi
    
    # Tester la page d'accueil
    if curl -s -o /dev/null -w "%{http_code}" "http://$SERVER_IP" | grep -q "200"; then
        log_success "✅ Page d'accueil accessible sur http://$SERVER_IP"
    else
        log_warning "⚠️ Page d'accueil non accessible"
    fi
}

# Fonction principale
main() {
    log_info "🚀 Démarrage du déploiement Frontend Migration Factory"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "🎯 Serveur cible: $SERVER_IP"
    echo "👤 Utilisateur: $SERVER_USER"
    echo "📁 Dossier frontend: $FRONTEND_DIR"
    echo "🏗️ Dossier build: $BUILD_DIR"
    echo "📍 Destination: $REMOTE_DIR"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    # Demander confirmation
    read -p "Continuer avec le déploiement? [y/N] " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_info "Déploiement annulé"
        exit 0
    fi
    
    # Étapes du déploiement
    check_prerequisites
    install_dependencies
    build_frontend
    deploy_to_server
    verify_deployment
    
    # Résumé final
    log_info "📋 Résumé du déploiement:"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "🌐 Application: http://$SERVER_IP:8080"
    echo "🏠 Page d'accueil: http://$SERVER_IP"
    echo "📁 Fichiers déployés: $REMOTE_DIR"
    echo "🔍 Logs nginx: /var/log/nginx/migration-factory-8080.*.log"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    log_success "🎉 Déploiement terminé avec succès!"
}

# Gestion des paramètres
if [ "$1" = "--help" ] || [ "$1" = "-h" ]; then
    echo "Usage: $0 [server_ip] [user]"
    echo ""
    echo "Paramètres:"
    echo "  server_ip    IP du serveur (défaut: 10.190.100.58)"
    echo "  user         Nom d'utilisateur SSH (défaut: user)"
    echo ""
    echo "Exemples:"
    echo "  $0                              # Utilise les valeurs par défaut"
    echo "  $0 10.190.100.58 ubuntu        # Serveur et utilisateur personnalisés"
    echo ""
    echo "Prérequis:"
    echo "  - Node.js et npm installés"
    echo "  - Accès SSH au serveur"
    echo "  - Nginx configuré sur le serveur"
    echo "  - Dossier frontend/ avec package.json"
    exit 0
fi

# Exécuter le script principal
main 