import os
from datetime import timedelta
from dotenv import load_dotenv

# Charger les variables d'environnement du fichier .env du projet
project_env = os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(__file__))), '.env')
if os.path.exists(project_env):
    load_dotenv(project_env)
else:
    # Fallback vers le fichier .env dans le dossier backend
    backend_env = os.path.join(os.path.dirname(os.path.dirname(__file__)), '.env')
    if os.path.exists(backend_env):
        load_dotenv(backend_env)

class Config:
    """Configuration de base partagée par tous les environnements"""
    VERSION = "1.0.0"
    SECRET_KEY = os.getenv("SECRET_KEY", "dev-key-change-in-production")
    JWT_SECRET_KEY = os.getenv("JWT_SECRET_KEY", os.getenv("SECRET_KEY", "dev-key-change-in-production"))
    JWT_ACCESS_TOKEN_EXPIRES = timedelta(hours=8)
    JWT_REFRESH_TOKEN_EXPIRES = timedelta(days=30)
    JWT_ALGORITHM = "HS256"  # Spécifie explicitement l'algorithme JWT
    
    # Chemins d'accès
    SAP_EXTRACTION_PATH = os.getenv("SAP_EXTRACTION_PATH")
    
    # Configuration de la base de données
    SQLALCHEMY_TRACK_MODIFICATIONS = False
    
    # Configuration CORS
    CORS_ORIGINS = os.getenv("CORS_ORIGINS", "*").split(",")
    
    # Limites d'export
    MAX_EXPORT_ROWS = int(os.getenv("MAX_EXPORT_ROWS", 100000))
    EXPORT_CHUNK_SIZE = int(os.getenv("EXPORT_CHUNK_SIZE", 5000))
    
    # Configuration Redis pour le rate limiting et le cache
    REDIS_URL = os.getenv("REDIS_URL")
    # Cache applicatif (Redis si REDIS_URL, sinon repli memoire). Desactivable.
    CACHE_ENABLED = os.getenv("CACHE_ENABLED", "true").lower() == "true"
    # TTL (secondes) du cache des articles de maintenance (liste + stats)
    MAINTENANCE_CACHE_TTL = int(os.getenv("MAINTENANCE_CACHE_TTL", 300))
    
    # SMTP (mot de passe oublié)
    SMTP_SERVER = os.getenv("SMTP_SERVER", "")
    SMTP_PORT = int(os.getenv("SMTP_PORT", 587))
    SMTP_USE_TLS = os.getenv("SMTP_USE_TLS", "true").lower() == "true"
    SMTP_USERNAME = os.getenv("SMTP_USERNAME", "")
    SMTP_PASSWORD = os.getenv("SMTP_PASSWORD", "")
    SMTP_FROM_EMAIL = os.getenv("SMTP_FROM_EMAIL", "")
    SMTP_FROM_NAME = os.getenv("SMTP_FROM_NAME", "Migration Factory")
    PASSWORD_RESET_EXPIRY = int(os.getenv("PASSWORD_RESET_EXPIRY", 3600))
    FRONTEND_URL = os.getenv("FRONTEND_URL", "http://localhost:3000")

    # Backup automatique
    BACKUP_ENABLED = os.getenv("BACKUP_ENABLED", "true").lower() == "true"
    BACKUP_DIR = os.getenv("BACKUP_DIR", "/backups")
    BACKUP_HOUR = int(os.getenv("BACKUP_HOUR", "2"))
    BACKUP_MINUTE = int(os.getenv("BACKUP_MINUTE", "0"))
    BACKUP_RETENTION_DAYS = int(os.getenv("BACKUP_RETENTION_DAYS", "30"))

    # Niveaux de log
    LOG_LEVEL = os.getenv("LOG_LEVEL", "INFO")

    # Assistant IA (Ollama local + rôle PostgreSQL lecture seule)
    OLLAMA_URL = os.getenv("OLLAMA_URL", "http://localhost:11434")
    OLLAMA_MODEL = os.getenv("OLLAMA_MODEL", "qwen2.5-coder:7b")
    AI_DB_USER = os.getenv("AI_DB_USER", "readonly_ai")
    AI_DB_PASSWORD = os.getenv("AI_DB_PASSWORD", "")
    AI_MAX_ROWS = int(os.getenv("AI_MAX_ROWS", 500))
    AI_EXPORT_MAX_ROWS = int(os.getenv("AI_EXPORT_MAX_ROWS", 50000))
    AI_TIMEOUT_SECONDS = int(os.getenv("AI_TIMEOUT_SECONDS", 240))

    # Assistant IA — recherche sémantique (pgvector + embeddings locaux)
    AI_EMBED_MODEL = os.getenv("AI_EMBED_MODEL", "bge-m3")
    AI_EMBED_ENABLED = os.getenv("AI_EMBED_ENABLED", "true").lower() == "true"
    AI_EMBED_TIMEOUT_SECONDS = int(os.getenv("AI_EMBED_TIMEOUT_SECONDS", 30))
    # Cache sémantique des réponses (réutilise le SQL d'une question proche)
    AI_CACHE_ENABLED = os.getenv("AI_CACHE_ENABLED", "true").lower() == "true"
    AI_CACHE_THRESHOLD = float(os.getenv("AI_CACHE_THRESHOLD", 0.94))
    # Auto-correction d'une requête SQL fautive (colonne/table inexistante)
    AI_SELFHEAL_ENABLED = os.getenv("AI_SELFHEAL_ENABLED", "true").lower() == "true"
    # Traitement des questions en arrière-plan (file public.ai_jobs + worker)
    AI_JOBS_ENABLED = os.getenv("AI_JOBS_ENABLED", "true").lower() == "true"
    AI_JOBS_POLL_SECONDS = float(os.getenv("AI_JOBS_POLL_SECONDS", 1.0))
    # Prompting structuré 2 phases (CoT) : le modèle raisonne avant de produire le SQL
    AI_COT_ENABLED = os.getenv("AI_COT_ENABLED", "true").lower() == "true"
    AI_NUM_PREDICT_COT = int(os.getenv("AI_NUM_PREDICT_COT", 640))
    # Packs de connaissances métier (skills) injectés par domaine dans le prompt
    AI_SKILL_ENABLED = os.getenv("AI_SKILL_ENABLED", "true").lower() == "true"
    AI_SKILL_MAX_PACKS = int(os.getenv("AI_SKILL_MAX_PACKS", 1))
    AI_SKILL_MAX_CHARS = int(os.getenv("AI_SKILL_MAX_CHARS", 700))
    AI_SKILLS_PATH = os.getenv(
        "AI_SKILLS_PATH",
        os.path.join(os.path.dirname(__file__), "skills"),
    )
    # Knowledge cards (cards granulaires dérivées des packs, classées par pertinence)
    # et Knowledge Graph (sous-graphe de jointures FK DDIC) injectés dans le prompt.
    AI_KNOWLEDGE_ENABLED = os.getenv("AI_KNOWLEDGE_ENABLED", "true").lower() == "true"
    AI_KNOWLEDGE_MAX_CHARS = int(os.getenv("AI_KNOWLEDGE_MAX_CHARS", 500))
    AI_KG_ENABLED = os.getenv("AI_KG_ENABLED", "true").lower() == "true"
    # Few-shots vivants : une réponse votée 👍 (ai_query_log.feedback='up') devient
    # un exemple few-shot, récupéré directement du journal (sans réindexation).
    AI_FEEDBACK_FEWSHOT_ENABLED = os.getenv("AI_FEEDBACK_FEWSHOT_ENABLED", "true").lower() == "true"

    # Construction de l'URI de connexion PostgreSQL à partir des variables .env
    @staticmethod
    def get_postgres_uri():
        pg_host = os.getenv("DB_HOST", "localhost")
        pg_port = os.getenv("DB_PORT", "5432")
        pg_database = os.getenv("DB_NAME", "sap_migration_db")
        pg_user = os.getenv("DB_USER", "postgres")
        # Pas de mot de passe en dur : doit provenir de l'environnement (.env / compose)
        pg_password = os.getenv("DB_PASSWORD", "")
        
        return f"postgresql://{pg_user}:{pg_password}@{pg_host}:{pg_port}/{pg_database}"

class DevelopmentConfig(Config):
    """Configuration de développement"""
    DEBUG = True
    SQLALCHEMY_DATABASE_URI = os.getenv("DATABASE_URI", Config.get_postgres_uri())
    SQLALCHEMY_ECHO = True

class TestingConfig(Config):
    """Configuration de test"""
    TESTING = True
    DEBUG = True
    SQLALCHEMY_DATABASE_URI = os.getenv("TEST_DATABASE_URI", Config.get_postgres_uri().replace(os.getenv("DB_NAME", "sap_migration_db"), os.getenv("DB_NAME", "sap_migration_db") + "_test"))
    JWT_ACCESS_TOKEN_EXPIRES = timedelta(minutes=5)

class ProductionConfig(Config):
    """Configuration de production"""
    DEBUG = False
    SQLALCHEMY_DATABASE_URI = os.getenv("DATABASE_URI", Config.get_postgres_uri())
    
    # Renforcement de la sécurité en production
    JWT_COOKIE_SECURE = True
    JWT_COOKIE_CSRF_PROTECT = True
    
    # Taille de pool de connexion SQL optimisée
    SQLALCHEMY_ENGINE_OPTIONS = {
        "pool_size": int(os.getenv("DB_POOL_SIZE", 10)),
        "max_overflow": int(os.getenv("DB_MAX_OVERFLOW", 20)),
        "pool_timeout": int(os.getenv("DB_POOL_TIMEOUT", 30)),
        "pool_recycle": int(os.getenv("DB_POOL_RECYCLE", 1800)),
        # Vérifie chaque connexion avant usage : évite les
        # "SSL SYSCALL error: EOF detected" sur connexion coupée côté serveur.
        "pool_pre_ping": True,
    }

# Mapping des configurations par nom d'environnement
config_by_name = {
    "dev": DevelopmentConfig,
    "development": DevelopmentConfig,  # Ajouté pour compatibilité FLASK_ENV
    "test": TestingConfig,
    "prod": ProductionConfig,
    "production": ProductionConfig,  # FLASK_ENV=production -> ProductionConfig (DEBUG=False)
}