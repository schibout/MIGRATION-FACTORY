from flask import Blueprint, jsonify, request
from sqlalchemy import text
from datetime import datetime
import logging
from models import db

articles_bp = Blueprint('articles', __name__)
logger = logging.getLogger(__name__)

@articles_bp.route('/api/v1/sap/articles', methods=['GET'])
def get_articles():
    try:
        # Récupérer les paramètres de la requête
        view_name = request.args.get('view', 'Articles - Vue générale')
        part_no = request.args.get('partNo', '')
        description = request.args.get('description', '')
        category = request.args.get('category', '')
        status = request.args.get('status', '')
        
        # Construire la requête SQL de base
        query = """
        SELECT 
            *
        FROM 
            v_article
        WHERE 1=1
        """
        
        # Ajouter les filtres si présents
        if part_no:
            query += f" AND part_no LIKE '%{part_no}%'"
        if description:
            query += f" AND description LIKE '%{description}%'"
        if category:
            query += f" AND type_code = '{category}'"
        if status:
            query += f" AND part_status = '{status}'"
            
        # Ajouter des filtres spécifiques selon la vue sélectionnée
        if view_name == 'Articles - Production':
            query += " AND type_code IN ('MANUFACTURED', 'PURCHASED')"
        elif view_name == 'Articles - Maintenance':
            query += " AND prime_commodity LIKE 'MAINT%'"
        elif view_name == 'Articles - Achats':
            query += " AND type_code = 'PURCHASED'"
            
        # Ajouter la clause ORDER BY
        query += " ORDER BY part_no, contract"
        
        # Exécuter la requête
        logger.info(f"Exécution de la requête de récupération des articles: {view_name}")
        result = db.session.execute(text(query))
        
        # Convertir le résultat en liste de dictionnaires
        articles = []
        for row in result:
            article_dict = {column: value for column, value in row._mapping.items()}
            
            # Convertir les objets datetime en chaînes de caractères
            for key, value in article_dict.items():
                if isinstance(value, datetime):
                    article_dict[key] = value.isoformat()
                    
            articles.append(article_dict)
        
        logger.info(f"Récupération de {len(articles)} articles")
        
        return jsonify({
            "success": True,
            "data": articles
        })
        
    except Exception as e:
        logger.error(f"Erreur lors de la récupération des articles: {str(e)}")
        return jsonify({
            "success": False,
            "error": str(e)
        }), 500 