from flask import Blueprint

# Import standard auth blueprint
from .auth import auth_blueprint
from .extraction import extraction_blueprint
from .data import data_blueprint
from .sap_views import sap_views_blueprint
from .ifs_tables import ifs_tables_blueprint
from .ifs_catalog import ifs_catalog_blueprint
from .ifs_articles import ifs_articles_blueprint
from .field_mapping import field_mapping_blueprint
from .business_rules import business_rules_blueprint
from .transcodification import transcodification_blueprint
from .users import users_blueprint
from .etl import etl_blueprint
from .export import export_bp
from .import_api import import_blueprint
from .import_config import import_config_bp
from .import_generic import import_generic_blueprint
from .sap import register_sap_blueprints
from .table_structure import table_structure_blueprint
from .resources_api import resources_blueprint
from .maintenance_hierarchy import maintenance_hierarchy_blueprint
from .maintenance_articles import maintenance_articles_blueprint
from .maintenance_snapshots import maintenance_snapshots_blueprint
from .maintenance_pe_tools import maintenance_pe_tools_blueprint
from .data_browser import data_browser_blueprint
from .sap_data_explorer import sap_data_explorer_blueprint
from .ih02_hierarchy import ih02_hierarchy_blueprint
from .backup import backup_blueprint
from .settings import settings_blueprint
from .ai_assistant import ai_blueprint
from .ai_config import ai_config_blueprint
from .hermes import hermes_blueprint

def register_blueprints(app):
    """Enregistrement des blueprints d'API dans l'application"""
    
    # Version API
    API_PREFIX = '/api/v1'
    
    # Enregistrement des blueprints avec leur préfixe
    
    # Utilisation du blueprint d'authentification standard (même configuration dev/prod)
    app.logger.info("Utilisation du blueprint d'authentification standard avec JWT")
    app.register_blueprint(auth_blueprint, url_prefix=f'{API_PREFIX}/auth')
    
    app.register_blueprint(extraction_blueprint, url_prefix=f'{API_PREFIX}/extraction')
    app.register_blueprint(data_blueprint, url_prefix=f'{API_PREFIX}/data')
    app.register_blueprint(sap_views_blueprint, url_prefix=f'{API_PREFIX}/data')
    app.register_blueprint(ifs_tables_blueprint, url_prefix=f'{API_PREFIX}/data')
    app.register_blueprint(ifs_catalog_blueprint, url_prefix=f'{API_PREFIX}/data')
    app.register_blueprint(ifs_articles_blueprint, url_prefix=f'{API_PREFIX}/data')
    app.register_blueprint(field_mapping_blueprint, url_prefix=f'{API_PREFIX}/config')
    app.register_blueprint(business_rules_blueprint, url_prefix=f'{API_PREFIX}/config')
    app.register_blueprint(transcodification_blueprint, url_prefix=f'{API_PREFIX}/config')
    app.register_blueprint(users_blueprint, url_prefix=f'{API_PREFIX}/users')
    app.register_blueprint(etl_blueprint, url_prefix=f'{API_PREFIX}/config/etl')
    app.register_blueprint(export_bp, url_prefix=f'{API_PREFIX}/export')
    app.register_blueprint(import_blueprint, url_prefix=f'{API_PREFIX}/import')
    app.register_blueprint(import_generic_blueprint, url_prefix=f'{API_PREFIX}/import-generic')
    app.register_blueprint(import_config_bp, url_prefix=f'{API_PREFIX}')
    app.register_blueprint(table_structure_blueprint, url_prefix=f'{API_PREFIX}/config/table-structure')
    app.register_blueprint(resources_blueprint, url_prefix=f'{API_PREFIX}/resources')
    app.register_blueprint(maintenance_hierarchy_blueprint, url_prefix=f'{API_PREFIX}/maintenance')
    app.register_blueprint(maintenance_articles_blueprint, url_prefix=f'{API_PREFIX}/maintenance')
    app.register_blueprint(maintenance_snapshots_blueprint, url_prefix=f'{API_PREFIX}/maintenance')
    # Gammes de maintenance preventive (raw_data.pe_tools)
    app.register_blueprint(maintenance_pe_tools_blueprint, url_prefix=f'{API_PREFIX}/maintenance')
    app.register_blueprint(data_browser_blueprint, url_prefix=f'{API_PREFIX}/data-browser')
    app.register_blueprint(sap_data_explorer_blueprint, url_prefix=f'{API_PREFIX}/sap-data-explorer')
    # Ecran IH02 : table unique clean_data.maintenance_object (raw_data en lecture seule)
    app.register_blueprint(ih02_hierarchy_blueprint, url_prefix=f'{API_PREFIX}/ih02-hierarchy')
    app.register_blueprint(backup_blueprint, url_prefix=f'{API_PREFIX}/backup')
    app.register_blueprint(settings_blueprint, url_prefix=f'{API_PREFIX}/settings')
    app.register_blueprint(ai_blueprint, url_prefix=f'{API_PREFIX}/ai')
    app.register_blueprint(ai_config_blueprint, url_prefix=f'{API_PREFIX}/ai-config')
    app.register_blueprint(hermes_blueprint, url_prefix=f'{API_PREFIX}/hermes')

    # Enregistrement des blueprints SAP
    register_sap_blueprints(app, API_PREFIX)
    
    app.logger.info('API blueprints enregistrés')