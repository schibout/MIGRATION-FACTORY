#!/bin/bash

# Script de déploiement du backend Migration Factory
# Usage: ./deploybackend.sh [options]

set -e  # Arrêter le script en cas d'erreur

# Couleurs pour les messages
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration par défaut
SERVICE_NAME="backend"
CONTAINER_NAME="migration-app-backend"
DOCKERFILE_PATH="./backend/Dockerfile"
BUILD_CONTEXT="./backend"
IMAGE_NAME="migration-factory-backend"
TAG="latest"

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

# Fonction d'aide
show_help() {
    echo "Script de déploiement du backend Migration Factory"
    echo ""
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -h, --help              Afficher cette aide"
    echo "  -b, --build             Forcer la reconstruction de l'image"
    echo "  -r, --restart           Redémarrer le conteneur"
    echo "  -s, --stop              Arrêter le conteneur"
    echo "  -l, --logs              Afficher les logs du conteneur"
    echo "  -c, --clean             Nettoyer les images et conteneurs inutilisés"
    echo "  -t, --tag TAG           Utiliser un tag spécifique (défaut: latest)"
    echo "  --no-cache              Construire sans utiliser le cache Docker"
    echo ""
    echo "Exemples:"
    echo "  $0                      # Déploiement standard"
    echo "  $0 -b                   # Forcer la reconstruction"
    echo "  $0 -r                   # Redémarrer le conteneur"
    echo "  $0 -l                   # Voir les logs"
    echo "  $0 -c                   # Nettoyer Docker"
}

# Fonction pour vérifier les prérequis
check_prerequisites() {
    log_info "Vérification des prérequis..."
    
    # Vérifier Docker
    if ! command -v docker &> /dev/null; then
        log_error "Docker n'est pas installé ou n'est pas dans le PATH"
        exit 1
    fi
    
    # Vérifier Docker Compose
    if ! command -v docker-compose &> /dev/null; then
        log_error "Docker Compose n'est pas installé ou n'est pas dans le PATH"
        exit 1
    fi
    
    # Vérifier le fichier .env
    if [ ! -f "./backend/.env" ]; then
        log_error "Fichier .env manquant dans le répertoire backend/"
        exit 1
    fi
    
    # Vérifier le Dockerfile
    if [ ! -f "$DOCKERFILE_PATH" ]; then
        log_error "Dockerfile manquant: $DOCKERFILE_PATH"
        exit 1
    fi
    
    log_success "Prérequis vérifiés"
}

# Fonction pour arrêter le conteneur existant
stop_container() {
    log_info "Arrêt du conteneur existant..."
    
    if docker ps -q -f name=$CONTAINER_NAME | grep -q .; then
        docker stop $CONTAINER_NAME
        log_success "Conteneur arrêté"
    else
        log_info "Aucun conteneur en cours d'exécution"
    fi
    
    if docker ps -aq -f name=$CONTAINER_NAME | grep -q .; then
        docker rm $CONTAINER_NAME
        log_success "Conteneur supprimé"
    fi
}

# Fonction pour construire l'image
build_image() {
    local build_args=""
    if [ "$NO_CACHE" = true ]; then
        build_args="--no-cache"
    fi
    
    log_info "Construction de l'image via docker-compose (service $SERVICE_NAME)..."

    # IMPORTANT : on build via docker-compose, pas `docker build -t migration-factory-backend`.
    # docker-compose.yml n'a pas de clé `image:` -> il gère SA propre image ; une image
    # construite à la main serait ignorée par `docker-compose up`.
    docker-compose build $build_args $SERVICE_NAME

    log_success "Image construite avec succès"
}

# Fonction pour démarrer le conteneur
start_container() {
    log_info "Démarrage du conteneur backend (recréation forcée)..."

    # Charger les variables d'environnement (substitution docker-compose)
    source .env

    # --force-recreate : recrée TOUJOURS le conteneur. Indispensable car le code est
    # monté en volume (./backend:/app) : sans recréation, un conteneur déjà en cours
    # ne recharge ni le code Python ni les variables d'environnement à jour.
    docker-compose up -d --force-recreate $SERVICE_NAME

    # Attendre que le conteneur soit prêt
    log_info "Attente du démarrage du conteneur..."
    sleep 10
    
    # Vérifier le statut
    if docker ps -q -f name=$CONTAINER_NAME | grep -q .; then
        log_success "Conteneur backend démarré avec succès"
        log_info "Nom du conteneur: $CONTAINER_NAME"
        log_info "Image: $IMAGE_NAME:$TAG"
    else
        log_error "Échec du démarrage du conteneur"
        docker logs $CONTAINER_NAME
        exit 1
    fi
}

# Fonction pour afficher les logs
show_logs() {
    log_info "Affichage des logs du conteneur backend..."
    docker logs -f $CONTAINER_NAME
}

# Fonction pour nettoyer Docker
clean_docker() {
    log_info "Nettoyage des ressources Docker inutilisées..."
    
    # Arrêter et supprimer le conteneur
    stop_container
    
    # Supprimer l'image
    if docker images -q $IMAGE_NAME:$TAG | grep -q .; then
        docker rmi $IMAGE_NAME:$TAG
        log_success "Image supprimée"
    fi
    
    # Nettoyer les ressources inutilisées
    docker system prune -f
    log_success "Nettoyage terminé"
}

# Fonction pour afficher le statut
show_status() {
    log_info "Statut du déploiement:"
    echo ""
    
    # Statut du conteneur
    if docker ps -q -f name=$CONTAINER_NAME | grep -q .; then
        log_success "Conteneur: EN COURS D'EXÉCUTION"
        docker ps -f name=$CONTAINER_NAME --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
    else
        log_warning "Conteneur: ARRÊTÉ"
    fi
    
    echo ""
    
    # Informations sur l'image
    if docker images -q $IMAGE_NAME:$TAG | grep -q .; then
        log_success "Image: DISPONIBLE"
        docker images $IMAGE_NAME:$TAG --format "table {{.Repository}}\t{{.Tag}}\t{{.Size}}\t{{.CreatedAt}}"
    else
        log_warning "Image: NON DISPONIBLE"
    fi
}

# Variables par défaut
BUILD=false
RESTART=false
STOP=false
LOGS=false
CLEAN=false
NO_CACHE=false

# Traitement des arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            exit 0
            ;;
        -b|--build)
            BUILD=true
            shift
            ;;
        -r|--restart)
            RESTART=true
            shift
            ;;
        -s|--stop)
            STOP=true
            shift
            ;;
        -l|--logs)
            LOGS=true
            shift
            ;;
        -c|--clean)
            CLEAN=true
            shift
            ;;
        -t|--tag)
            TAG="$2"
            shift 2
            ;;
        --no-cache)
            NO_CACHE=true
            shift
            ;;
        *)
            log_error "Option inconnue: $1"
            show_help
            exit 1
            ;;
    esac
done

# Exécution principale
main() {
    log_info "=== Déploiement Backend Migration Factory ==="
    log_info "Tag: $TAG"
    log_info "Conteneur: $CONTAINER_NAME"
    echo ""
    
    # Actions spéciales
    if [ "$STOP" = true ]; then
        stop_container
        exit 0
    fi
    
    if [ "$LOGS" = true ]; then
        show_logs
        exit 0
    fi
    
    if [ "$CLEAN" = true ]; then
        clean_docker
        exit 0
    fi
    
    # Vérifications
    check_prerequisites
    
    # Arrêter le conteneur existant si nécessaire
    if [ "$RESTART" = true ] || [ "$BUILD" = true ]; then
        stop_container
    fi
    
    # Toujours (re)construire via docker-compose : avec le cache de couches c'est
    # quasi-instantané si rien n'a changé, et ça garantit que toute évolution de
    # requirements.txt ou du Dockerfile est prise en compte.
    build_image

    # Démarrer le conteneur (recréation forcée -> code + env rechargés)
    start_container
    
    # Afficher le statut final
    echo ""
    show_status
    
    echo ""
    log_success "=== Déploiement terminé avec succès ==="
    log_info "Pour voir les logs: $0 -l"
    log_info "Pour redémarrer: $0 -r"
    log_info "Pour arrêter: $0 -s"
}

# Exécuter le script principal
main "$@"
