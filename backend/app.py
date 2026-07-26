#!/usr/bin/env python
# -*- coding: utf-8 -*-

from flask import Flask, request, jsonify
from flask_jwt_extended import JWTManager
from flask_cors import CORS
from flask_limiter import Limiter
from flask_limiter.util import get_remote_address
import logging
from logging.handlers import RotatingFileHandler
import os
import json
import time
from datetime import datetime
from dotenv import load_dotenv
from sqlalchemy import text

from api import register_blueprints
from config.settings import config_by_name
from models import db

# Chargement des variables d'environnement
load_dotenv()

def create_app(config_name=None):
    """Initialisation de l'application Flask"""
    app = Flask(__name__)

    # Résolution de la configuration : argument explicite sinon FLASK_ENV (defaut "dev").
    # Important : sans ce repli, la factory appelée sans argument (flask run / gunicorn
    # app:create_app()) démarrait TOUJOURS en DevelopmentConfig (DEBUG=True) même en prod.
    if config_name is None:
        config_name = os.getenv("FLASK_ENV", "dev")
    if config_name not in config_by_name:
        # Repli prudent : ne jamais retomber silencieusement en dev si FLASK_ENV est mal saisi
        app.logger.warning(f"Configuration inconnue '{config_name}', repli sur 'prod'")
        config_name = "prod"

    # Configuration de l'application
    app.config.from_object(config_by_name[config_name])

    # Fail-fast : en production, refuser de démarrer avec des secrets faibles / par défaut
    if not app.config.get("DEBUG", False):
        weak_secrets = {"", None, "dev-key-change-in-production"}
        if (app.config.get("SECRET_KEY") in weak_secrets or
                app.config.get("JWT_SECRET_KEY") in weak_secrets):
            raise RuntimeError(
                "SECRET_KEY / JWT_SECRET_KEY non définis en production. "
                "Renseignez-les via les variables d'environnement (.env / docker-compose)."
            )

    # Configuration de CORS - Autoriser explicitement toutes les origines
    cors_origins = os.environ.get('CORS_ORIGINS', 'http://localhost:5173,http://localhost:3000,http://10.190.100.58').split(',')
    app.logger.info(f"CORS Origins configurés: {cors_origins}")
    app.logger.info(f"Configuration en mode: {config_name}")
    
    # CORS restreint à l'allowlist CORS_ORIGINS (plus de wildcard "*").
    CORS(app,
         resources={r"/*": {"origins": cors_origins}},
         supports_credentials=True,
         allow_headers=["Content-Type", "Authorization"],
         methods=["GET", "POST", "PUT", "DELETE", "OPTIONS"])
    
    # Configuration des logs
    setup_logging(app)
    
    # Initialisation de la base de données
    db.init_app(app)
    
    # Configuration JWT
    jwt = JWTManager(app)
    # Utiliser la configuration JWT de settings.py (qui lit JWT_SECRET_KEY depuis .env)
    
    # Configuration Rate Limiter - lue depuis RATE_LIMIT_DEFAULT (format "50000/day;5000/hour")
    # Repli élevé : outil interne temporaire, partagé par IP (réseau d'entreprise / proxy).
    rate_limit_default = os.environ.get('RATE_LIMIT_DEFAULT', '50000/day;5000/hour')
    default_limits = [lim.strip() for lim in rate_limit_default.split(';') if lim.strip()]
    app.logger.info(f"Rate limits par défaut: {default_limits}")
    limiter = Limiter(
        get_remote_address,
        app=app,
        default_limits=default_limits,
        storage_uri=app.config.get("REDIS_URL", "memory://")
    )
    
    # Enregistrement des blueprints API
    register_blueprints(app)
    
    # Middleware de sécurité - Modifié pour permettre CORS et gérer les blobs
    @app.after_request
    def add_security_headers(response):
        response.headers['X-Content-Type-Options'] = 'nosniff'
        response.headers['X-Frame-Options'] = 'DENY'
        response.headers['X-XSS-Protection'] = '1; mode=block'
        
        # Configuration CSP très permissive pour le développement
        if app.config.get('DEBUG', False):
            # En développement, désactiver complètement la CSP pour éviter les conflits
            # avec les blobs HTTP et les avertissements de sécurité
            pass  # Pas de CSP en développement
        else:
            # En production, CSP stricte avec HTTPS
            csp_directives = [
                "default-src 'self'",
                "script-src 'self' 'unsafe-inline' 'unsafe-eval'",
                "style-src 'self' 'unsafe-inline'",
                "img-src 'self' data: blob:",
                "connect-src 'self' https: wss:",
                "font-src 'self' data:",
                "object-src 'none'",
                "media-src 'self' blob:",
                "frame-src 'none'",
                "base-uri 'self'",
                "form-action 'self'",
                "upgrade-insecure-requests"
            ]
            response.headers['Content-Security-Policy'] = "; ".join(csp_directives)
            response.headers['Strict-Transport-Security'] = 'max-age=31536000; includeSubDomains'
        
        # En-têtes CORS : ne refléter l'Origin QUE si elle est dans l'allowlist
        # (ne jamais renvoyer un Origin arbitraire avec Allow-Credentials: true).
        origin = request.headers.get('Origin')
        if origin and (origin in cors_origins or '*' in cors_origins):
            response.headers['Access-Control-Allow-Origin'] = origin
            response.headers['Vary'] = 'Origin'
            response.headers['Access-Control-Allow-Methods'] = 'GET, POST, PUT, DELETE, OPTIONS'
            response.headers['Access-Control-Allow-Headers'] = 'Content-Type, Authorization'
            response.headers['Access-Control-Allow-Credentials'] = 'true'
        
        # Headers spécifiques pour les téléchargements
        if response.headers.get('Content-Disposition'):
            response.headers['X-Download-Options'] = 'noopen'
            response.headers['X-Content-Type-Options'] = 'nosniff'
        
        return response
    
    # Middleware pour logger les requêtes HTTP
    @app.before_request
    def log_request_info():
        # Ne pas logger les requêtes OPTIONS (pre-flight CORS)
        if request.method != 'OPTIONS':
            # Ne pas essayer de décoder les fichiers binaires (uploads)
            body = ''
            if request.content_type and 'multipart/form-data' not in request.content_type:
                try:
                    body = request.get_data().decode('utf-8')
                    # Redaction des champs sensibles (mot de passe, secrets) avant log
                    try:
                        parsed = json.loads(body)
                        if isinstance(parsed, dict):
                            for k in list(parsed.keys()):
                                if any(s in k.lower() for s in (
                                        'password', 'passwd', 'secret', 'token', 'mot_de_passe')):
                                    parsed[k] = '***REDACTED***'
                            body = json.dumps(parsed)
                    except (ValueError, TypeError):
                        pass
                except UnicodeDecodeError:
                    body = '<binary data>'
            else:
                body = '<file upload>'

            app.logger.info('Request: %s %s - Headers: %s - Body: %s',
                        request.method, request.path,
                        {k: v for k, v in request.headers.items() if k != 'Authorization'},
                        body)
        request.start_time = time.time()

    @app.after_request
    def log_response_info(response):
        if hasattr(request, 'start_time') and request.method != 'OPTIONS':
            duration = time.time() - request.start_time
            app.logger.info('Response: %s %s - Status: %d - Duration: %.3fs',
                          request.method, request.path,
                          response.status_code, duration)
        return response
    
    # Route de vérification de santé
    @app.route('/health')
    def health_check():
        try:
            # Tester la connexion à la base de données si possible
            try:
                with app.app_context():
                    db.session.execute(text("SELECT 1")).scalar()
                db_status = "ok"
            except Exception as db_err:
                db_status = f"error: {str(db_err)}"
                # Ne pas bloquer la vérification de santé pour une erreur DB
            
            # Version de l'application
            return {
                "status": "ok", 
                "version": app.config.get('VERSION', '1.0.0'),
                "database": db_status,
                "timestamp": datetime.now().isoformat()
            }
        except Exception as e:
            # Log l'erreur mais retourne 200 pour réussir le healthcheck Docker
            print(f"Health check error: {str(e)}")
            return {"status": "warning", "message": f"Service running with warnings: {str(e)}"}, 200
    
    # Démarrage du scheduler de backup automatique (quotidien à 2h00)
    try:
        from services.backup_scheduler import start_scheduler
        backup_hour = int(os.getenv('BACKUP_HOUR', '2'))
        backup_minute = int(os.getenv('BACKUP_MINUTE', '0'))
        if os.getenv('BACKUP_ENABLED', 'true').lower() == 'true':
            start_scheduler(hour=backup_hour, minute=backup_minute)
            app.logger.info(f"Backup automatique activé (quotidien à {backup_hour:02d}:{backup_minute:02d})")
    except Exception as e:
        app.logger.warning(f"Impossible de démarrer le scheduler de backup: {e}")

    # Démarrage du préchauffage Ollama : garde en cache KV le SOCLE (préfixe stable
    # du prompt RAG) pour éviter son évaluation à froid. Seul le suffixe dynamique
    # (schéma ciblé + exemples) est ré-évalué à chaque /ask.
    try:
        if os.getenv('AI_KEEPWARM_ENABLED', 'true').lower() == 'true':
            from services.ollama_service import start_keepwarm
            from services.ai_prompt_builder import get_socle
            if start_keepwarm(get_socle):
                app.logger.info("Préchauffage Ollama (keep-warm) activé")
    except Exception as e:
        app.logger.warning(f"Impossible de démarrer le keep-warm Ollama: {e}")

    # Démarrage du worker IA : traite en arrière-plan les questions enregistrées
    # dans public.ai_jobs (route /ai/ask). Un verrou consultatif PostgreSQL
    # garantit une seule génération Ollama à la fois sur tout le cluster gunicorn.
    try:
        if os.getenv('AI_JOBS_ENABLED', 'true').lower() == 'true':
            from services.ai_job_worker import start_worker
            from api.ai_assistant import process_question
            if start_worker(process_question):
                app.logger.info("Worker IA (jobs en arrière-plan) démarré")
    except Exception as e:
        app.logger.warning(f"Impossible de démarrer le worker IA: {e}")

    return app

def setup_logging(app):
    """Configuration des logs de l'application"""
    try:
        os.makedirs('logs', exist_ok=True)
        
        # Tester l'accès en écriture
        test_file = 'logs/test_access.txt'
        try:
            with open(test_file, 'w') as f:
                f.write('Test d\'accès en écriture')
            os.remove(test_file)
        except PermissionError:
            app.logger.warning("Impossible d'écrire dans le répertoire de logs. Utilisation de sys.stderr à la place.")
            # Configuration du handler pour la console uniquement en cas de problème de permission
            console_handler = logging.StreamHandler()
            console_handler.setFormatter(logging.Formatter(
                '%(asctime)s %(levelname)s [%(module)s] %(message)s'
            ))
            console_handler.setLevel(logging.DEBUG if app.config['DEBUG'] else logging.INFO)
            app.logger.addHandler(console_handler)
            app.logger.setLevel(logging.DEBUG if app.config['DEBUG'] else logging.INFO)
            
            # Désactivation des logs werkzeug par défaut
            werkzeug_logger = logging.getLogger('werkzeug')
            werkzeug_logger.setLevel(logging.WARNING)
            return
        
        # Configuration du handler pour le fichier de log
        file_handler = RotatingFileHandler('logs/app.log', maxBytes=10485760, backupCount=10)
        file_handler.setFormatter(logging.Formatter(
            '%(asctime)s %(levelname)s [%(module)s] %(message)s'
        ))
        file_handler.setLevel(logging.INFO)
        
        # Configuration du handler pour la console
        console_handler = logging.StreamHandler()
        console_handler.setFormatter(logging.Formatter(
            '%(asctime)s %(levelname)s [%(module)s] %(message)s'
        ))
        console_handler.setLevel(logging.DEBUG if app.config['DEBUG'] else logging.INFO)
        
        # Application des handlers
        app.logger.addHandler(file_handler)
        app.logger.addHandler(console_handler)
        app.logger.setLevel(logging.DEBUG if app.config['DEBUG'] else logging.INFO)
        
        # Désactivation des logs werkzeug par défaut
        werkzeug_logger = logging.getLogger('werkzeug')
        werkzeug_logger.setLevel(logging.WARNING)
    
    except Exception as e:
        print(f"Erreur lors de la configuration des logs: {str(e)}")
        # Configuration minimale en cas d'erreur
        console_handler = logging.StreamHandler()
        console_handler.setFormatter(logging.Formatter('%(asctime)s %(levelname)s [%(module)s] %(message)s'))
        app.logger.addHandler(console_handler)
        app.logger.setLevel(logging.INFO)

if __name__ == '__main__':
    app = create_app(os.getenv('FLASK_ENV', 'dev'))
    app.run(host='0.0.0.0', port=int(os.getenv('PORT', 5000)))