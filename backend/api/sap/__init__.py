from flask import Blueprint
from .articles_routes import articles_bp

# Création d'un blueprint parent pour les routes SAP
sap_blueprint = Blueprint('sap', __name__)

# Enregistrement des sous-blueprints
def register_sap_blueprints(app, api_prefix):
    """
    Enregistre les blueprints liés aux données SAP
    """
    app.register_blueprint(articles_bp)
    app.logger.info('SAP blueprints enregistrés') 