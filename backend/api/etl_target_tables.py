from flask import Blueprint, jsonify, request
from sqlalchemy import text
from api.database import get_db_connection
from api.auth import token_required
import logging

# Configuration du logger
logger = logging.getLogger(__name__)

# Création du blueprint pour les tables cibles ETL
etl_target_tables_bp = Blueprint('etl_target_tables', __name__)

@etl_target_tables_bp.route('/data/etl_target_tables', methods=['GET'])
@token_required
def get_etl_target_tables():
    """
    Retourne la liste des tables cibles ETL
    """
    try:
        # Connexion à la base de données
        conn = get_db_connection()
        
        # Requête SQL pour obtenir toutes les tables cibles
        query = text("""
            SELECT 
                id, 
                table_name, 
                display_name, 
                description, 
                source_schema, 
                target_schema, 
                python_module, 
                execution_order, 
                dependent_on, 
                is_active, 
                icon_name, 
                last_modified, 
                created_at, 
                created_by, 
                domaine_fonctionnel, 
                display_order 
            FROM 
                etl_target_tables 
            ORDER BY 
                display_order, table_name
        """)
        
        # Exécution de la requête
        result = conn.execute(query)
        tables = []
        
        # Conversion des résultats en liste de dictionnaires
        for row in result:
            tables.append({
                'id': row[0],
                'table_name': row[1],
                'display_name': row[2],
                'description': row[3],
                'source_schema': row[4],
                'target_schema': row[5],
                'python_module': row[6],
                'execution_order': row[7],
                'dependent_on': row[8],
                'is_active': row[9],
                'icon_name': row[10],
                'last_modified': row[11].isoformat() if row[11] else None,
                'created_at': row[12].isoformat() if row[12] else None,
                'created_by': row[13],
                'domaine_fonctionnel': row[14],
                'display_order': row[15]
            })
        
        # Fermeture de la connexion
        conn.close()
        
        return jsonify(tables)
    
    except Exception as e:
        logger.error(f"Erreur lors de la récupération des tables cibles ETL: {e}")
        return jsonify({'error': 'Erreur lors de la récupération des tables cibles ETL'}), 500

@etl_target_tables_bp.route('/data/etl_target_tables/<int:table_id>', methods=['GET'])
@token_required
def get_etl_target_table(table_id):
    """
    Retourne les détails d'une table cible ETL spécifique
    """
    try:
        # Connexion à la base de données
        conn = get_db_connection()
        
        # Requête SQL pour obtenir une table cible spécifique
        query = text("""
            SELECT 
                id, 
                table_name, 
                display_name, 
                description, 
                source_schema, 
                target_schema, 
                python_module, 
                execution_order, 
                dependent_on, 
                is_active, 
                icon_name, 
                last_modified, 
                created_at, 
                created_by, 
                domaine_fonctionnel, 
                display_order 
            FROM 
                etl_target_tables 
            WHERE 
                id = :table_id
        """)
        
        # Exécution de la requête avec le paramètre table_id
        result = conn.execute(query, {'table_id': table_id})
        row = result.fetchone()
        
        # Si aucune table n'est trouvée, retourner une erreur 404
        if not row:
            conn.close()
            return jsonify({'error': 'Table cible ETL non trouvée'}), 404
        
        # Conversion du résultat en dictionnaire
        table = {
            'id': row[0],
            'table_name': row[1],
            'display_name': row[2],
            'description': row[3],
            'source_schema': row[4],
            'target_schema': row[5],
            'python_module': row[6],
            'execution_order': row[7],
            'dependent_on': row[8],
            'is_active': row[9],
            'icon_name': row[10],
            'last_modified': row[11].isoformat() if row[11] else None,
            'created_at': row[12].isoformat() if row[12] else None,
            'created_by': row[13],
            'domaine_fonctionnel': row[14],
            'display_order': row[15]
        }
        
        # Fermeture de la connexion
        conn.close()
        
        return jsonify(table)
    
    except Exception as e:
        logger.error(f"Erreur lors de la récupération de la table cible ETL {table_id}: {e}")
        return jsonify({'error': f'Erreur lors de la récupération de la table cible ETL {table_id}'}), 500

@etl_target_tables_bp.route('/data/etl_target_tables/<int:table_id>', methods=['PUT'])
@token_required
def update_etl_target_table(table_id):
    """
    Met à jour une table cible ETL existante
    """
    try:
        # Récupération des données JSON de la requête
        data = request.get_json()
        if not data:
            return jsonify({'error': 'Aucune donnée fournie'}), 400
        
        # Vérification des champs requis
        required_fields = ['display_name', 'domaine_fonctionnel', 'display_order']
        for field in required_fields:
            if field not in data:
                return jsonify({'error': f'Le champ {field} est requis'}), 400
        
        # Connexion à la base de données
        conn = get_db_connection()
        
        # Requête SQL pour mettre à jour la table cible
        query = text("""
            UPDATE etl_target_tables
            SET 
                display_name = :display_name,
                domaine_fonctionnel = :domaine_fonctionnel,
                display_order = :display_order,
                source_schema = :source_schema,
                target_schema = :target_schema,
                last_modified = CURRENT_TIMESTAMP
            WHERE 
                id = :table_id
            RETURNING id
        """)
        
        # Exécution de la requête avec les paramètres
        result = conn.execute(query, {
            'table_id': table_id,
            'display_name': data['display_name'],
            'domaine_fonctionnel': data['domaine_fonctionnel'],
            'display_order': data['display_order'],
            'source_schema': data.get('source_schema', ''),
            'target_schema': data.get('target_schema', '')
        })
        
        # Vérification que la mise à jour a bien été effectuée
        updated_id = result.fetchone()
        if not updated_id:
            conn.close()
            return jsonify({'error': 'Table cible ETL non trouvée ou non mise à jour'}), 404
        
        # Validation de la transaction
        conn.commit()
        
        # Fermeture de la connexion
        conn.close()
        
        return jsonify({'id': updated_id[0], 'message': 'Table cible ETL mise à jour avec succès'})
    
    except Exception as e:
        logger.error(f"Erreur lors de la mise à jour de la table cible ETL {table_id}: {e}")
        return jsonify({'error': f'Erreur lors de la mise à jour de la table cible ETL {table_id}'}), 500 