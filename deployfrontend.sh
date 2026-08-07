#!/bin/bash

# Script de déploiement du frontend Migration Factory
# Usage: ./deployfrontend.sh [options]

set -e  # Arrêter le script en cas d'erreur

# Couleurs pour les messages
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration par défaut
SERVICE_NAME="frontend"
CONTAINER_NAME="migration-app-frontend"
DOCKERFILE_PATH="./frontend/Dockerfile"
BUILD_CONTEXT="./frontend"
IMAGE_NAME="migration-factory-frontend"
TAG="latest"
# Port HOTE du conteneur frontend (docker-compose : 127.0.0.1:3100 -> 3000).
# Le port hote 3000 est pris par nginx, qui y sert le portail d'accueil.
FRONTEND_PORT="3100"
# Le conteneur n'est binde que sur la loopback : l'acces reseau passe par le
# nginx de l'hote. On teste donc la sante en loopback, mais on affiche cette
# URL publique a l'utilisateur.
PUBLIC_URL="http://10.190.100.58:8081/"

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
    echo "Script de déploiement du frontend Migration Factory"
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
    echo "  -p, --port PORT         Utiliser un port spécifique (défaut: 8080)"
    echo "  --no-cache              Construire sans utiliser le cache Docker"
    echo "  --dev                   Mode développement avec hot-reload"
    echo ""
    echo "Exemples:"
    echo "  $0                      # Déploiement standard"
    echo "  $0 -b                   # Forcer la reconstruction"
    echo "  $0 -r                   # Redémarrer le conteneur"
    echo "  $0 -l                   # Voir les logs"
    echo "  $0 -c                   # Nettoyer Docker"
    echo "  $0 --dev                # Mode développement"
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
    
    # Vérifier le Dockerfile
    if [ ! -f "$DOCKERFILE_PATH" ]; then
        log_error "Dockerfile manquant: $DOCKERFILE_PATH"
        exit 1
    fi
    
    # Vérifier le package.json
    if [ ! -f "./frontend/package.json" ]; then
        log_error "package.json manquant dans le répertoire frontend/"
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
# IMPORTANT : on construit via docker-compose (et non `docker build -t ...`),
# sinon l'image construite serait orpheline et jamais utilisee par le conteneur
# reellement lance par docker-compose.
build_image() {
    local build_args=""
    if [ "$NO_CACHE" = true ]; then
        build_args="--no-cache"
    fi

    log_info "Construction de l'image via docker-compose (service: $SERVICE_NAME)..."

    docker-compose build $build_args $SERVICE_NAME

    log_success "Image construite avec succès"
}

# Fonction pour démarrer / recréer le conteneur
start_container() {
    log_info "Démarrage / recréation du conteneur frontend..."

    # --force-recreate : recree le conteneur pour qu'il reparte du code a jour.
    # C'est le point cle : sans ca, `up -d` reutilise le conteneur existant et le
    # nouveau code (ou la nouvelle image) n'est jamais servi.
    # --no-deps : NE PAS revalider la dependance `backend` (depends_on: service_healthy).
    # Le backend chauffe Ollama sur CPU au demarrage : son /health peut timeouter et
    # passer 'unhealthy' quelques instants -> sans --no-deps, docker-compose refuse de
    # (re)creer le frontend ("dependency failed to start: backend is unhealthy") alors
    # que le frontend (dev server Vite) n'a PAS besoin d'un backend sain pour demarrer
    # (il proxie vers le backend a la requete, pas au boot). Le backend est de toute
    # facon deploye separement (deploybackend.sh / deploy_all.sh).
    docker-compose up -d --force-recreate --no-deps $SERVICE_NAME

    # Attendre que le conteneur soit prêt (Vite dev server met quelques secondes)
    log_info "Attente du démarrage du conteneur..."
    sleep 15

    # Vérifier le statut
    if docker ps -q -f name=$CONTAINER_NAME | grep -q .; then
        log_success "Conteneur frontend démarré avec succès"
        log_info "Nom du conteneur: $CONTAINER_NAME"
        log_info "URL: $PUBLIC_URL (via nginx)"
    else
        log_error "Échec du démarrage du conteneur"
        docker logs $CONTAINER_NAME
        exit 1
    fi
}

# Fonction pour démarrer en mode développement
start_dev_mode() {
    log_info "Démarrage en mode développement..."
    
    # Arrêter le conteneur de production s'il existe
    stop_container
    
    # Construire l'image de développement si nécessaire
    if ! docker images -q $IMAGE_NAME:$TAG | grep -q .; then
        log_info "Construction de l'image de développement..."
        build_image
    fi
    
    # Démarrer le conteneur frontend avec synchronisation des fichiers
    log_info "Lancement du conteneur frontend en mode développement..."
    
    # Démarrer avec docker-compose en mode développement
    NODE_ENV=development \
    CHOKIDAR_USEPOLLING=true \
    WATCHPACK_POLLING=true \
    docker-compose up -d frontend
    
    # Attendre que le conteneur soit prêt
    log_info "Attente du démarrage du conteneur de développement..."
    sleep 10
    
    # Vérifier le statut
    if docker ps -q -f name=$CONTAINER_NAME | grep -q .; then
        log_success "Conteneur frontend démarré en mode développement"
        log_info "Frontend accessible sur: $PUBLIC_URL (via nginx)"
        log_info "Les fichiers sont synchronisés - modifications en temps réel"
        log_info "Pour voir les logs: docker logs -f $CONTAINER_NAME"
    else
        log_error "Échec du démarrage du conteneur de développement"
        docker logs $CONTAINER_NAME
        exit 1
    fi
}

# Fonction pour afficher les logs
show_logs() {
    log_info "Affichage des logs du conteneur frontend..."
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

# Fonction pour tester l'accès au frontend
test_frontend() {
    log_info "Test d'accès au frontend..."
    
    local url="http://127.0.0.1:$FRONTEND_PORT"
    local max_attempts=30
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        if curl -s -f "$url" > /dev/null 2>&1; then
            log_success "Frontend accessible sur $url"
            return 0
        else
            log_info "Tentative $attempt/$max_attempts - Attente..."
            sleep 2
            ((attempt++))
        fi
    done
    
    log_error "Frontend non accessible après $max_attempts tentatives"
    return 1
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
    
    # Informations sur l'image réellement utilisée par le service docker-compose
    log_info "Image du service $SERVICE_NAME :"
    docker-compose images $SERVICE_NAME || log_warning "Image non disponible"
    
    echo ""
    
    # Test d'accès
    if test_frontend; then
        log_success "Frontend: ACCESSIBLE"
    else
        log_warning "Frontend: NON ACCESSIBLE"
    fi
}

# Variables par défaut
BUILD=false
RESTART=false
STOP=false
LOGS=false
CLEAN=false
NO_CACHE=false
DEV_MODE=false

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
        -p|--port)
            FRONTEND_PORT="$2"
            shift 2
            ;;
        --no-cache)
            NO_CACHE=true
            shift
            ;;
        --dev)
            DEV_MODE=true
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
    log_info "=== Déploiement Frontend Migration Factory ==="
    log_info "Tag: $TAG"
    log_info "Conteneur: $CONTAINER_NAME"
    log_info "Port: $FRONTEND_PORT"
    echo ""
    
    # Mode développement
    if [ "$DEV_MODE" = true ]; then
        start_dev_mode
        exit 0
    fi
    
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
    
    # Reconstruire l'image uniquement si demandé (-b) ou --no-cache.
    # Le code frontend est servi depuis le volume (Vite dev server) : pour un
    # changement .tsx/.ts, un --force-recreate suffit (Vite relit le code monté).
    # Reconstruire l'image n'est utile que si package.json / Dockerfile ont changé.
    if [ "$BUILD" = true ] || [ "$NO_CACHE" = true ]; then
        build_image
    else
        log_info "Pas de reconstruction d'image (code servi depuis le volume). Utilisez -b si package.json/Dockerfile ont changé."
    fi

    # Démarrer / recréer le conteneur (sert toujours le code à jour)
    start_container
    
    # Afficher le statut final
    echo ""
    show_status
    
    echo ""
    log_success "=== Déploiement terminé avec succès ==="
    log_info "Frontend accessible sur: $PUBLIC_URL (via nginx)"
    log_info "Pour voir les logs: $0 -l"
    log_info "Pour redémarrer: $0 -r"
    log_info "Pour arrêter: $0 -s"
    log_info "Mode développement: $0 --dev"
}

# Exécuter le script principal
main "$@"
