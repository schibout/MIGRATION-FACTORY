from flask import Blueprint, request, jsonify, current_app
from sqlalchemy import text
from models import db
import uuid
import time
import threading
import importlib.util
import inspect
import sys
import os
import logging

etl_blueprint = Blueprint('etl', __name__)

# Dictionnaire pour suivre les exécutions en cours
etl_executions = {}

@etl_blueprint.route('/target-tables', methods=['GET'])
def get_target_tables():
    """Récupère la liste des tables cibles ETL"""
    try:
        # Utiliser une requête SQL directe pour tirer parti de toutes les colonnes
        query = """
            SELECT
                id, table_name, display_name, description, source_schema,
                target_schema, python_module, execution_order, dependent_on,
                is_active, icon_name, module_params, last_modified, created_at, created_by
            FROM etl_target_tables
            ORDER BY execution_order, display_name
        """
        
        result = db.session.execute(text(query))
        
        tables = []
        for row in result:
            tables.append({
                'id': row.id,
                'table_name': row.table_name,
                'display_name': row.display_name,
                'description': row.description,
                'source_schema': row.source_schema,
                'target_schema': row.target_schema,
                'python_module': row.python_module,
                'execution_order': row.execution_order,
                'dependent_on': row.dependent_on,
                'is_active': row.is_active,
                'icon_name': row.icon_name,
                'module_params': row.module_params,
                'last_modified': row.last_modified.isoformat() if row.last_modified else None,
                'created_at': row.created_at.isoformat() if row.created_at else None,
                'created_by': row.created_by
            })
        
        return jsonify(tables), 200
    except Exception as e:
        current_app.logger.error(f"Erreur lors de la récupération des tables cibles: {str(e)}")
        return jsonify({'error': f'Erreur interne du serveur: {str(e)}'}), 500

@etl_blueprint.route('/execute', methods=['POST'])
def execute_etl():
    """Exécute un processus ETL"""
    try:
        data = request.get_json()
        if not data or 'table_id' not in data:
            return jsonify({'error': 'ID de table requis'}), 400
            
        table_id = data['table_id']
        
        # Récupérer les informations de la table
        query = text("""
            SELECT * FROM etl_target_tables WHERE id = :id
        """)
        result = db.session.execute(query, {'id': table_id}).fetchone()
        
        if not result:
            return jsonify({'error': 'Table cible non trouvée'}), 404
            
        if not result.is_active:
            return jsonify({'error': 'Cette table cible est inactive'}), 400
        
        # Générer un ID d'exécution unique
        execution_id = str(uuid.uuid4())
        
        # Créer une entrée pour suivre l'exécution
        etl_executions[execution_id] = {
            'table_id': table_id,
            'table_name': result.table_name,
            'display_name': result.display_name,
            'python_module': result.python_module,
            'start_time': time.time(),
            'progress': 0,
            'messages': [
                {'time': time.time(), 'message': f'Démarrage du chargement de {result.display_name}', 'type': 'info'}
            ],
            'status': 'running'
        }
        
        # Démarrer le processus ETL en arrière-plan
        thread = threading.Thread(target=run_etl_process, args=(execution_id, result))
        thread.daemon = True
        thread.start()
        
        return jsonify({
            'success': True,
            'message': f'Processus ETL démarré pour {result.display_name}',
            'details': {
                'execution_id': execution_id
            }
        }), 200
            
    except Exception as e:
        current_app.logger.error(f"Erreur lors de l'exécution du processus ETL: {str(e)}")
        return jsonify({'error': f'Erreur interne du serveur: {str(e)}'}), 500

@etl_blueprint.route('/status/<execution_id>', methods=['GET'])
def get_etl_status(execution_id):
    """Récupère le statut d'une exécution ETL en cours"""
    try:
        if execution_id not in etl_executions:
            return jsonify({'error': 'ID d\'exécution non trouvé'}), 404
            
        execution = etl_executions[execution_id]
        
        # Obtenir le dernier message
        last_message = execution['messages'][-1] if execution['messages'] else None
        
        return jsonify({
            'progress': execution['progress'],
            'message': last_message['message'] if last_message else '',
            'type': last_message['type'] if last_message else 'info',
            'status': execution['status'],
            'all_messages': execution['messages']  # Ajouter tous les messages
        }), 200
        
    except Exception as e:
        current_app.logger.error(f"Erreur lors de la récupération du statut: {str(e)}")
        return jsonify({'error': f'Erreur interne du serveur: {str(e)}'}), 500

def run_etl_process(execution_id, table_data):
    """Exécute le processus ETL en arrière-plan"""
    execution = etl_executions[execution_id]
    
    try:
        # Simuler les étapes d'ETL pour la démonstration
        # Phase 1: Extraction des données source (20%)
        execution['progress'] = 20
        execution['messages'].append({
            'time': time.time(),
            'message': f'Chargement des données depuis {table_data.source_schema}.{table_data.table_name}',
            'type': 'info'
        })
        time.sleep(2)  # Simuler un délai
        
        # Phase 2: Transformation des données (50%)
        execution['progress'] = 50
        execution['messages'].append({
            'time': time.time(),
            'message': f'Transformation des données en cours...',
            'type': 'info'
        })
        time.sleep(2)  # Simuler un délai
        
        # Phase 3: Chargement dans la table cible (80%)
        execution['progress'] = 80
        execution['messages'].append({
            'time': time.time(),
            'message': f'Chargement des données dans {table_data.target_schema}.{table_data.table_name}',
            'type': 'info'
        })
        time.sleep(2)  # Simuler un délai
        
        # Étape facultative: essayer de charger dynamiquement le module Python
        try:
            module_name = table_data.python_module.replace('.py', '')
            
            # Rechercher le module dans le dossier etl_modules
            etl_module_path = os.path.join(os.path.dirname(os.path.dirname(__file__)), 'etl_modules')
            module_path = os.path.join(etl_module_path, table_data.python_module)
            
            execution['messages'].append({
                'time': time.time(),
                'message': f'Tentative de chargement du module {module_name}',
                'type': 'info'
            })
            
            if os.path.exists(module_path):
                # Le module existe, on essaie de l'exécuter
                execution['messages'].append({
                    'time': time.time(),
                    'message': f'Module {module_name} trouvé, exécution...',
                    'type': 'info'
                })
                
                # Importer et exécuter le module ETL
                spec = importlib.util.spec_from_file_location(module_name, module_path)
                module = importlib.util.module_from_spec(spec)
                spec.loader.exec_module(module)
                
                # Exécuter la fonction run_etl du module, en lui transmettant les
                # module_params de la table cible. Seules les clés acceptées par la
                # signature sont passées : un module sans paramètre reste appelé sans
                # argument (rétrocompatibilité avec tous les modules existants).
                params = getattr(table_data, 'module_params', None) or {}
                accepted = {
                    k: v for k, v in params.items()
                    if k in inspect.signature(module.run_etl).parameters
                }
                if accepted:
                    execution['messages'].append({
                        'time': time.time(),
                        'message': f'Paramètres du module: {accepted}',
                        'type': 'info'
                    })
                etl_result = module.run_etl(**accepted)
                
                # Récupérer les logs du module si disponibles
                if 'log_messages' in etl_result and isinstance(etl_result['log_messages'], list):
                    for log_msg in etl_result['log_messages']:
                        execution['messages'].append({
                            'time': log_msg.get('time', time.time()),
                            'message': log_msg.get('message', ''),
                            'type': log_msg.get('type', 'info')
                        })
                
                # Mettre à jour le statut selon le résultat
                if etl_result.get('success', False):
                    execution['progress'] = 100
                    execution['status'] = 'completed'
                    
                    # Ajouter un message de succès final s'il n'y en a pas déjà un
                    success_msg_exists = any(msg.get('type') == 'success' for msg in execution['messages'][-3:])
                    if not success_msg_exists:
                        execution['messages'].append({
                            'time': time.time(),
                            'message': f'Chargement terminé avec succès: {etl_result.get("records_processed", 0)} enregistrements traités',
                            'type': 'success'
                        })
                else:
                    execution['status'] = 'error'
                    execution['messages'].append({
                        'time': time.time(),
                        'message': f'Erreur: {etl_result.get("error", "Erreur inconnue")}',
                        'type': 'error'
                    })
            else:
                execution['messages'].append({
                    'time': time.time(),
                    'message': f'Module {module_name} non trouvé, fonctionnement en mode simulation',
                    'type': 'warning'
                })
                # Finalisation simulée (100%) si le module n'existe pas
                execution['progress'] = 100
                execution['status'] = 'completed'
                execution['messages'].append({
                    'time': time.time(),
                    'message': f'Chargement simulé terminé pour {table_data.display_name}',
                    'type': 'success'
                })
        except Exception as module_err:
            execution['messages'].append({
                'time': time.time(),
                'message': f'Erreur lors du chargement du module: {str(module_err)}',
                'type': 'error'
            })
            # En cas d'erreur avec le module, on termine quand même le processus
            execution['progress'] = 100
            execution['status'] = 'error'
    
    except Exception as e:
        # Gestion des erreurs
        current_app.logger.error(f"Erreur lors de l'exécution ETL: {str(e)}")
        execution['status'] = 'error'
        execution['messages'].append({
            'time': time.time(),
            'message': f'Erreur lors du traitement: {str(e)}',
            'type': 'error'
        })
    
    # Dans un environnement réel, vous pourriez enregistrer les résultats dans une table d'historique ETL
    # Pour cet exemple, nous les gardons en mémoire temporairement 