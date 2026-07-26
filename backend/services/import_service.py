"""
Service principal d'import de fichiers
Orchestration du processus complet d'import avec gestion asynchrone
"""

import os
import uuid
import shutil
from datetime import datetime, timedelta
from typing import Dict, List, Any, Optional, Tuple
import logging
import asyncio
import threading
from contextlib import contextmanager
import psycopg2
import psycopg2.extras
import json

from config.database import get_db_connection
from services.file_processors import FileProcessorFactory, BaseFileProcessor
from utils.validators import validate_file_size, validate_file_format

logger = logging.getLogger(__name__)


class ImportService:
    """
    Service principal pour gérer les imports de fichiers
    """
    
    def __init__(self, upload_folder: str = "uploads"):
        self.upload_folder = upload_folder
        self.max_file_size = 50 * 1024 * 1024  # 50MB
        self.allowed_formats = ['csv', 'xlsx', 'xls']
        self.processing_jobs = {}  # Stockage des jobs en cours
        
        # Créer le dossier upload s'il n'existe pas
        os.makedirs(upload_folder, exist_ok=True)
    
    def get_file_type_config(self, file_type: str) -> Optional[Dict[str, Any]]:
        """
        Récupère la configuration d'un type de fichier depuis la base
        
        Args:
            file_type: Type de fichier (customers, products, orders)
            
        Returns:
            Configuration ou None si non trouvée
        """
        try:
            with get_db_connection() as conn:
                cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
                cursor.execute("""
                    SELECT * FROM file_type_configs 
                    WHERE type_name = %s AND is_active = true
                """, (file_type,))
                
                config = cursor.fetchone()
                if config:
                    config_dict = dict(config)
                    
                    # Extraire le schéma et la table depuis target_table (format: schema.table)
                    target_table = config_dict.get('target_table', '')
                    if '.' in target_table:
                        schema, table = target_table.split('.', 1)
                        config_dict['target_schema'] = schema
                        config_dict['target_table'] = table
                    else:
                        config_dict['target_schema'] = 'public'
                    
                    return config_dict
                return None
                
        except Exception as e:
            logger.error(f"Erreur récupération config {file_type}: {e}")
            return None
    
    def create_import_job(self, user_id: int, file_name: str, file_path: str, 
                         file_size: int, file_type: str, file_format: str) -> str:
        """
        Crée un nouveau job d'import dans la base de données
        
        Returns:
            UUID du job créé
        """
        job_uuid = str(uuid.uuid4())
        
        try:
            with get_db_connection() as conn:
                cursor = conn.cursor()
                cursor.execute("""
                    INSERT INTO import_jobs (
                        job_uuid, user_id, file_name, file_path, file_size,
                        file_type, file_format, status, created_at
                    ) VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s)
                    RETURNING id
                """, (
                    job_uuid, user_id, file_name, file_path, file_size,
                    file_type, file_format, 'pending', datetime.now()
                ))
                
                job_id = cursor.fetchone()[0]
                conn.commit()
                
                logger.info(f"Job d'import créé: {job_uuid} (ID: {job_id})")
                return job_uuid
                
        except Exception as e:
            logger.error(f"Erreur création job d'import: {e}")
            raise
    
    def update_job_status(self, job_uuid: str, status: str, 
                         error_message: str = None, **kwargs):
        """
        Met à jour le statut d'un job d'import
        """
        try:
            with get_db_connection() as conn:
                cursor = conn.cursor()
                
                # Construire la requête de mise à jour dynamiquement
                set_clauses = ["status = %s", "updated_at = %s"]
                params = [status, datetime.now()]
                
                if error_message:
                    set_clauses.append("error_message = %s")
                    params.append(error_message)
                
                if status == 'processing' and 'started_at' not in kwargs:
                    set_clauses.append("started_at = %s")
                    params.append(datetime.now())
                
                if status in ['completed', 'completed_with_errors', 'failed']:
                    set_clauses.append("completed_at = %s")
                    params.append(datetime.now())
                
                # Ajouter les kwargs
                for key, value in kwargs.items():
                    set_clauses.append(f"{key} = %s")
                    params.append(value)
                
                params.append(job_uuid)
                
                query = f"""
                    UPDATE import_jobs 
                    SET {', '.join(set_clauses)}
                    WHERE job_uuid = %s
                """
                
                cursor.execute(query, params)
                conn.commit()
                
        except Exception as e:
            logger.error(f"Erreur mise à jour job {job_uuid}: {e}")
    
    def log_import_event(self, import_job_id: int, level: str, message: str, 
                        details: Dict = None, **kwargs):
        """
        Enregistre un événement de log pour un import
        """
        try:
            with get_db_connection() as conn:
                cursor = conn.cursor()
                cursor.execute("""
                    INSERT INTO import_logs (
                        import_job_id, log_level, message, details, 
                        module, function_name, execution_time_ms, created_at
                    ) VALUES (%s, %s, %s, %s, %s, %s, %s, %s)
                """, (
                    import_job_id, level, message, 
                    json.dumps(details) if details else None,
                    kwargs.get('module'), kwargs.get('function_name'),
                    kwargs.get('execution_time_ms'), datetime.now()
                ))
                conn.commit()
                
        except Exception as e:
            logger.error(f"Erreur log import {import_job_id}: {e}")
    
    def save_import_details(self, import_job_id: int, results: List[Dict[str, Any]]):
        """
        Sauvegarde les détails de traitement ligne par ligne
        """
        try:
            with get_db_connection() as conn:
                cursor = conn.cursor()
                
                for result in results:
                    cursor.execute("""
                        INSERT INTO import_details (
                            import_job_id, row_number, status, original_data,
                            transformed_data, error_message, validation_errors,
                            processed_at, created_at
                        ) VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s)
                    """, (
                        import_job_id,
                        result['row_number'],
                        result['status'],
                        json.dumps(result['original_data']),
                        json.dumps(result['transformed_data']) if result['transformed_data'] else None,
                        '; '.join(result['validation_errors'] + result['business_errors']) if result['validation_errors'] or result['business_errors'] else None,
                        json.dumps(result['validation_errors'] + result['business_errors']) if result['validation_errors'] or result['business_errors'] else None,
                        datetime.now(),
                        datetime.now()
                    ))
                
                conn.commit()
                logger.info(f"Détails sauvegardés pour job {import_job_id}: {len(results)} lignes")
                
        except Exception as e:
            logger.error(f"Erreur sauvegarde détails job {import_job_id}: {e}")
            raise
    
    def insert_successful_records(self, target_table: str, target_schema: str, 
                                 successful_records: List[Dict[str, Any]]) -> int:
        """
        Insère les enregistrements validés dans la table cible
        
        Returns:
            Nombre d'enregistrements insérés
        """
        if not successful_records:
            return 0
        
        try:
            with get_db_connection() as conn:
                cursor = conn.cursor()
                
                # Obtenir les colonnes de la première ligne
                columns = list(successful_records[0].keys())
                
                # Construire la requête d'insertion
                placeholders = ', '.join(['%s'] * len(columns))
                columns_str = ', '.join(columns)
                
                query = f"""
                    INSERT INTO {target_schema}.{target_table} ({columns_str})
                    VALUES ({placeholders})
                """
                
                # Préparer les données
                data_rows = []
                for record in successful_records:
                    row = [record.get(col) for col in columns]
                    data_rows.append(row)
                
                # Insertion en lot
                cursor.executemany(query, data_rows)
                inserted_count = cursor.rowcount
                conn.commit()
                
                logger.info(f"Insérés {inserted_count} enregistrements dans {target_schema}.{target_table}")
                return inserted_count
                
        except Exception as e:
            logger.error(f"Erreur insertion dans {target_table}: {e}")
            raise
    
    def save_statistics(self, import_job_id: int, stats: Dict[str, Any]):
        """
        Sauvegarde les statistiques de performance
        """
        try:
            with get_db_connection() as conn:
                cursor = conn.cursor()
                
                # Métriques de base
                metrics = [
                    ('total_rows', stats.get('total_rows', 0), 'count', 'business'),
                    ('success_rows', stats.get('success_rows', 0), 'count', 'quality'),
                    ('error_rows', stats.get('error_rows', 0), 'count', 'quality'),
                    ('processing_time', stats.get('processing_time', 0), 'seconds', 'performance'),
                ]
                
                # Calcul du taux de succès
                if stats.get('total_rows', 0) > 0:
                    success_rate = (stats.get('success_rows', 0) / stats['total_rows']) * 100
                    metrics.append(('success_rate', success_rate, 'percent', 'quality'))
                
                # Calcul de la vitesse de traitement
                if stats.get('processing_time', 0) > 0:
                    processing_speed = stats.get('total_rows', 0) / stats['processing_time']
                    metrics.append(('processing_speed', processing_speed, 'rows/sec', 'performance'))
                
                for metric_name, value, unit, metric_type in metrics:
                    cursor.execute("""
                        INSERT INTO import_statistics (
                            import_job_id, metric_name, metric_value, 
                            metric_unit, metric_type, measurement_time
                        ) VALUES (%s, %s, %s, %s, %s, %s)
                    """, (import_job_id, metric_name, value, unit, metric_type, datetime.now()))
                
                conn.commit()
                
        except Exception as e:
            logger.error(f"Erreur sauvegarde statistiques job {import_job_id}: {e}")
    
    async def process_import_file(self, job_uuid: str, file_path: str, 
                                file_type: str, file_format: str, user_id: int):
        """
        Traite un fichier d'import de manière asynchrone
        """
        start_time = datetime.now()
        
        try:
            # Récupérer l'ID du job
            job_id = self._get_job_id_from_uuid(job_uuid)
            if not job_id:
                raise ValueError(f"Job non trouvé: {job_uuid}")
            
            # Mettre à jour le statut à "processing"
            self.update_job_status(job_uuid, 'processing')
            self.log_import_event(job_id, 'INFO', 'Début du traitement du fichier')
            
            # Récupérer la configuration du type de fichier
            config = self.get_file_type_config(file_type)
            if not config:
                raise ValueError(f"Configuration non trouvée pour le type: {file_type}")
            
            # Créer le processeur approprié
            processor_class = config.get('processor_class', file_type)
            try:
                # Essayer d'abord par nom de classe
                processor = FileProcessorFactory.create_processor_by_class_name(processor_class, config)
            except ValueError:
                # Fallback sur l'ancien système par type
                processor = FileProcessorFactory.create_processor(file_type, config)
            
            # Lire le fichier
            self.log_import_event(job_id, 'INFO', f'Lecture du fichier: {os.path.basename(file_path)}')
            df = processor.read_file(file_path, file_format)
            
            # Valider les colonnes
            column_errors = processor.validate_columns(df)
            if column_errors:
                error_msg = '; '.join(column_errors)
                self.update_job_status(job_uuid, 'failed', error_msg)
                self.log_import_event(job_id, 'ERROR', f'Erreurs de colonnes: {error_msg}')
                return
            
            # Traiter le DataFrame
            self.log_import_event(job_id, 'INFO', f'Traitement de {len(df)} lignes')
            results = processor.process_dataframe(df)
            
            # Sauvegarder les détails de traitement
            await asyncio.to_thread(self.save_import_details, job_id, results)
            
            # Séparer les enregistrements réussis des échecs
            successful_records = [
                r['transformed_data'] for r in results 
                if r['status'] == 'success' and r['transformed_data']
            ]
            
            # Insérer les enregistrements réussis
            inserted_count = 0
            if successful_records:
                self.log_import_event(job_id, 'INFO', f'Insertion de {len(successful_records)} enregistrements')
                inserted_count = await asyncio.to_thread(
                    self.insert_successful_records,
                    config['target_table'],
                    config['target_schema'],
                    successful_records
                )
            
            # Calculer les statistiques finales
            processing_time = (datetime.now() - start_time).total_seconds()
            stats = {
                **processor.stats,
                'processing_time': processing_time,
                'inserted_count': inserted_count
            }
            
            # Sauvegarder les statistiques
            await asyncio.to_thread(self.save_statistics, job_id, stats)
            
            # Déterminer le statut final
            if stats['error_rows'] > 0:
                final_status = 'completed_with_errors'
                status_msg = f"Traitement terminé avec {stats['error_rows']} erreurs"
            else:
                final_status = 'completed'
                status_msg = "Traitement terminé avec succès"
            
            # Mettre à jour le statut final
            self.update_job_status(
                job_uuid, 
                final_status,
                total_rows=stats['total_rows'],
                processed_rows=stats['processed_rows'],
                success_rows=stats['success_rows'],
                error_rows=stats['error_rows'],
                progress_percent=100.0
            )
            
            self.log_import_event(job_id, 'INFO', status_msg, {
                'statistics': stats,
                'processing_time_seconds': processing_time
            })
            
            logger.info(f"Import {job_uuid} terminé: {stats['success_rows']}/{stats['total_rows']} réussis")
            
        except Exception as e:
            # En cas d'erreur, mettre à jour le statut
            error_msg = str(e)
            self.update_job_status(job_uuid, 'failed', error_msg)
            
            if 'job_id' in locals():
                self.log_import_event(job_id, 'ERROR', f'Erreur de traitement: {error_msg}')
            
            logger.error(f"Erreur traitement import {job_uuid}: {e}")
            raise
        
        finally:
            # Nettoyer le fichier temporaire
            try:
                if os.path.exists(file_path):
                    os.remove(file_path)
                    logger.info(f"Fichier temporaire supprimé: {file_path}")
            except Exception as e:
                logger.warning(f"Impossible de supprimer le fichier {file_path}: {e}")
    
    def _get_job_id_from_uuid(self, job_uuid: str) -> Optional[int]:
        """
        Récupère l'ID numérique d'un job depuis son UUID
        """
        try:
            with get_db_connection() as conn:
                cursor = conn.cursor()
                cursor.execute("SELECT id FROM import_jobs WHERE job_uuid = %s", (job_uuid,))
                result = cursor.fetchone()
                return result[0] if result else None
        except Exception as e:
            logger.error(f"Erreur récupération job ID pour {job_uuid}: {e}")
            return None
    
    def start_import(self, user_id: int, file_name: str, file_content: bytes, 
                    file_type: str) -> str:
        """
        Démarre un nouveau processus d'import
        
        Args:
            user_id: ID de l'utilisateur qui lance l'import
            file_name: Nom du fichier
            file_content: Contenu binaire du fichier
            file_type: Type de fichier (customers, products, orders)
            
        Returns:
            UUID du job créé
        """
        # Validation du fichier
        file_format = file_name.split('.')[-1].lower()
        file_size = len(file_content)
        
        if not validate_file_format(file_format, self.allowed_formats):
            raise ValueError(f"Format de fichier non supporté: {file_format}")
        
        if not validate_file_size(file_size, self.max_file_size):
            raise ValueError(f"Fichier trop volumineux: {file_size} bytes (max: {self.max_file_size})")
        
        # Vérifier que le type de fichier est supporté
        if not self.get_file_type_config(file_type):
            raise ValueError(f"Type de fichier non supporté: {file_type}")
        
        # Sauvegarder le fichier temporaire
        file_uuid = str(uuid.uuid4())
        temp_filename = f"{file_uuid}.{file_format}"
        temp_path = os.path.join(self.upload_folder, temp_filename)
        
        try:
            with open(temp_path, 'wb') as f:
                f.write(file_content)
            
            # Créer le job d'import
            job_uuid = self.create_import_job(
                user_id, file_name, temp_path, file_size, file_type, file_format
            )
            
            # Lancer le traitement asynchrone
            asyncio.create_task(self.process_import_file(
                job_uuid, temp_path, file_type, file_format, user_id
            ))
            
            logger.info(f"Import démarré: {job_uuid} pour fichier {file_name}")
            return job_uuid
            
        except Exception as e:
            # Nettoyer le fichier en cas d'erreur
            if os.path.exists(temp_path):
                os.remove(temp_path)
            raise
    
    def get_import_status(self, job_uuid: str) -> Optional[Dict[str, Any]]:
        """
        Récupère le statut d'un import
        """
        try:
            with get_db_connection() as conn:
                cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
                cursor.execute("""
                    SELECT 
                        job_uuid, file_name, file_type, status, 
                        total_rows, processed_rows, success_rows, error_rows,
                        progress_percent, created_at, started_at, completed_at,
                        error_message
                    FROM import_jobs 
                    WHERE job_uuid = %s
                """, (job_uuid,))
                
                job = cursor.fetchone()
                if job:
                    return dict(job)
                return None
                
        except Exception as e:
            logger.error(f"Erreur récupération statut {job_uuid}: {e}")
            return None
    
    def cancel_import(self, job_uuid: str) -> bool:
        """
        Annule un import en cours
        """
        try:
            # Récupérer le statut actuel
            status_info = self.get_import_status(job_uuid)
            if not status_info:
                return False
            
            if status_info['status'] not in ['pending', 'processing']:
                return False  # Ne peut pas annuler un job terminé
            
            # Mettre à jour le statut
            self.update_job_status(job_uuid, 'cancelled')
            
            # Log de l'annulation
            job_id = self._get_job_id_from_uuid(job_uuid)
            if job_id:
                self.log_import_event(job_id, 'INFO', 'Import annulé par l\'utilisateur')
            
            logger.info(f"Import annulé: {job_uuid}")
            return True
            
        except Exception as e:
            logger.error(f"Erreur annulation import {job_uuid}: {e}")
            return False
    
    def get_import_history(self, user_id: int = None, limit: int = 50) -> List[Dict[str, Any]]:
        """
        Récupère l'historique des imports
        """
        try:
            with get_db_connection() as conn:
                cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
                
                query = """
                    SELECT 
                        job_uuid, file_name, file_type, status, 
                        total_rows, success_rows, error_rows,
                        created_at, completed_at, user_id
                    FROM import_jobs 
                """
                params = []
                
                if user_id:
                    query += " WHERE user_id = %s"
                    params.append(user_id)
                
                query += " ORDER BY created_at DESC LIMIT %s"
                params.append(limit)
                
                cursor.execute(query, params)
                jobs = cursor.fetchall()
                
                return [dict(job) for job in jobs]
                
        except Exception as e:
            logger.error(f"Erreur récupération historique: {e}")
            return [] 