"""
API Blueprint pour l'import générique de données
Permet d'importer des fichiers CSV/Excel vers n'importe quelle table
"""

from flask import Blueprint, request, jsonify, current_app
from flask_jwt_extended import jwt_required, get_jwt_identity
from werkzeug.utils import secure_filename
import pandas as pd
import io
import json
import uuid
import os
import tempfile
import pickle
from datetime import datetime
from typing import Dict, Any, List, Optional
from difflib import SequenceMatcher
import psycopg2.extras

from config.database import get_db_connection
from services.data_service import get_data_service
from services.import_mapping_service import get_mapping_service

# Créer le blueprint
import_generic_blueprint = Blueprint('import_generic', __name__)

# Stockage temporaire des fichiers analysés.
# IMPORTANT : sur DISQUE (pas en mémoire) pour être PARTAGÉ entre les workers gunicorn.
# Un dict en mémoire n'est pas partagé (chaque worker a sa copie) -> un file_id créé
# par un worker est introuvable par un autre -> erreur "Fichier non trouvé ou expiré".
# Cette classe se comporte comme un dict (in / [] / del) mais persiste chaque entrée
# dans un fichier pickle du répertoire temp du conteneur (commun aux workers).
class _DiskFileStore:
    def __init__(self, base_dir: str):
        self._dir = base_dir
        os.makedirs(base_dir, exist_ok=True)

    def _path(self, key: str) -> str:
        return os.path.join(self._dir, f'{key}.pkl')

    def __contains__(self, key: str) -> bool:
        return os.path.exists(self._path(key))

    def __getitem__(self, key: str):
        path = self._path(key)
        if not os.path.exists(path):
            raise KeyError(key)
        with open(path, 'rb') as f:
            return pickle.load(f)

    def __setitem__(self, key: str, value) -> None:
        with open(self._path(key), 'wb') as f:
            pickle.dump(value, f)

    def __delitem__(self, key: str) -> None:
        path = self._path(key)
        if os.path.exists(path):
            os.remove(path)


temp_file_storage = _DiskFileStore(os.path.join(tempfile.gettempdir(), 'import_generic_store'))


def calculate_similarity(a: str, b: str) -> float:
    """Calcule la similarité entre deux chaînes (0 à 1)"""
    a_lower = a.lower().replace('_', '').replace('-', '')
    b_lower = b.lower().replace('_', '').replace('-', '')
    return SequenceMatcher(None, a_lower, b_lower).ratio()


def suggest_mapping(source_columns: List[Dict], target_columns: List[Dict]) -> List[Dict]:
    """
    Propose un mapping automatique entre colonnes source et cible
    Uses the ImportMappingService for intelligent matching.
    """
    mapping_service = get_mapping_service()
    return mapping_service.suggest_mapping(source_columns, target_columns)


def are_types_compatible(source_type: str, target_type: str) -> bool:
    """Vérifie si les types source et cible sont compatibles"""
    mapping_service = get_mapping_service()
    return mapping_service.are_types_compatible(source_type, target_type)


def detect_column_type(values: List[Any]) -> str:
    """Détecte le type d'une colonne à partir de ses valeurs"""
    mapping_service = get_mapping_service()
    return mapping_service.detect_column_type(values)


@import_generic_blueprint.route('/analyze-file', methods=['POST'])
# @jwt_required()
def analyze_file():
    """
    Analyse un fichier uploadé et retourne les colonnes détectées avec des échantillons
    """
    try:
        if 'file' not in request.files:
            return jsonify({'error': 'Aucun fichier fourni'}), 400
        
        file = request.files['file']
        if file.filename == '':
            return jsonify({'error': 'Nom de fichier vide'}), 400
        
        filename = secure_filename(file.filename)
        extension = filename.rsplit('.', 1)[-1].lower() if '.' in filename else ''
        
        if extension not in ['csv', 'xlsx', 'xls']:
            return jsonify({'error': f'Format non supporté: {extension}'}), 400
        
        # Lire le fichier
        file_content = file.read()
        file_size = len(file_content)
        
        try:
            if extension == 'csv':
                sample = file_content[:10000].decode('utf-8', errors='replace')
                delimiter = ';' if sample.count(';') > sample.count(',') else ','
                
                detected_encoding = 'utf-8'
                for enc in ['utf-8', 'latin-1', 'cp1252', 'iso-8859-1']:
                    try:
                        file_content.decode(enc)
                        detected_encoding = enc
                        break
                    except (UnicodeDecodeError, LookupError):
                        continue
                
                df = pd.read_csv(
                    io.BytesIO(file_content),
                    delimiter=delimiter,
                    encoding=detected_encoding,
                    on_bad_lines='skip'
                )
            else:
                df = pd.read_excel(
                    io.BytesIO(file_content)
                    # Pas de limite nrows - lire tout le fichier
                )
        except Exception as e:
            current_app.logger.error(f"Erreur lecture fichier: {e}")
            return jsonify({'error': f'Erreur lors de la lecture du fichier: {str(e)}'}), 400
        
        # Analyser les colonnes
        columns = []
        for col in df.columns:
            sample_values = df[col].dropna().head(5).tolist()
            sample_values = [str(v) if not pd.isna(v) else None for v in sample_values]
            
            detected_type = detect_column_type(df[col].tolist())
            
            columns.append({
                'name': str(col),
                'detectedType': detected_type,
                'sampleValues': sample_values,
                'nullCount': int(df[col].isna().sum()),
                'uniqueCount': int(df[col].nunique())
            })
        
        # Générer un ID unique pour ce fichier
        file_id = str(uuid.uuid4())
        
        # Stocker temporairement les données
        temp_file_storage[file_id] = {
            'filename': filename,
            'content': file_content,
            'dataframe': df,
            'columns': columns,
            'row_count': len(df),
            'created_at': datetime.now()
        }
        
        current_app.logger.info(f"Fichier analysé: {filename}, {len(columns)} colonnes, {len(df)} lignes")
        
        return jsonify({
            'success': True,
            'fileId': file_id,
            'filename': filename,
            'fileSize': file_size,
            'columns': columns,
            'rowCount': len(df),
            'encoding': detected_encoding if extension == 'csv' else None,
            'delimiter': delimiter if extension == 'csv' else None
        }), 200
        
    except Exception as e:
        current_app.logger.error(f"Erreur analyse fichier: {e}")
        return jsonify({'error': f'Erreur lors de l\'analyse: {str(e)}'}), 500


@import_generic_blueprint.route('/schemas', methods=['GET'])
# @jwt_required()
def get_available_schemas():
    """
    Retourne la liste des schémas disponibles dans la base
    """
    try:
        with get_db_connection() as conn:
            cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
            
            cursor.execute("""
                SELECT schema_name,
                       (SELECT COUNT(*) FROM information_schema.tables t 
                        WHERE t.table_schema = s.schema_name AND t.table_type = 'BASE TABLE') as table_count
                FROM information_schema.schemata s
                WHERE schema_name NOT IN ('pg_catalog', 'information_schema', 'pg_toast')
                ORDER BY 
                    CASE WHEN schema_name = 'raw_data' THEN 0 
                         WHEN schema_name = 'clean_data' THEN 1
                         WHEN schema_name = 'public' THEN 2 
                         ELSE 3 END,
                    schema_name
            """)
            
            schemas = cursor.fetchall()
            
            return jsonify({
                'success': True,
                'schemas': schemas,
                'count': len(schemas)
            }), 200
            
    except Exception as e:
        current_app.logger.error(f"Erreur récupération schémas: {e}")
        return jsonify({'error': str(e)}), 500


@import_generic_blueprint.route('/tables', methods=['GET'])
# @jwt_required()
def get_available_tables():
    """
    Retourne la liste des tables disponibles pour l'import
    """
    try:
        schema = request.args.get('schema', 'raw_data')
        search = request.args.get('search', '')
        
        with get_db_connection() as conn:
            cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
            
            query = """
                SELECT 
                    t.table_name,
                    t.table_schema,
                    pg_catalog.obj_description(pgc.oid, 'pg_class') as description,
                    (SELECT COUNT(*) FROM information_schema.columns c 
                     WHERE c.table_schema = t.table_schema AND c.table_name = t.table_name) as column_count,
                    pgc.reltuples::bigint as row_count
                FROM information_schema.tables t
                LEFT JOIN pg_catalog.pg_namespace pgn ON pgn.nspname = t.table_schema
                LEFT JOIN pg_catalog.pg_class pgc ON pgc.relname = t.table_name 
                                                  AND pgc.relnamespace = pgn.oid
                WHERE t.table_schema = %s
                AND t.table_type = 'BASE TABLE'
            """
            params = [schema]
            
            if search:
                query += " AND t.table_name ILIKE %s"
                params.append(f'%{search}%')
            
            query += " ORDER BY t.table_name"
            
            cursor.execute(query, params)
            tables = cursor.fetchall()
            
            return jsonify({
                'success': True,
                'tables': tables,
                'count': len(tables),
                'schema': schema
            }), 200
            
    except Exception as e:
        current_app.logger.error(f"Erreur récupération tables: {e}")
        return jsonify({'error': str(e)}), 500


@import_generic_blueprint.route('/tables/<table_name>/columns', methods=['GET'])
# @jwt_required()
def get_table_columns(table_name: str):
    """
    Retourne les colonnes d'une table avec leurs métadonnées
    """
    try:
        schema = request.args.get('schema', 'raw_data')
        
        with get_db_connection() as conn:
            cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
            
            # Récupérer les colonnes avec description (jointure correcte sur schema)
            cursor.execute("""
                SELECT 
                    c.column_name as name,
                    c.data_type,
                    c.is_nullable,
                    c.column_default,
                    c.character_maximum_length,
                    c.numeric_precision,
                    c.ordinal_position,
                    pg_catalog.col_description(pgc.oid, c.ordinal_position) as description
                FROM information_schema.columns c
                LEFT JOIN pg_catalog.pg_namespace pgn ON pgn.nspname = c.table_schema
                LEFT JOIN pg_catalog.pg_class pgc ON pgc.relname = c.table_name 
                                                  AND pgc.relnamespace = pgn.oid
                WHERE c.table_schema = %s
                AND c.table_name = %s
                ORDER BY c.ordinal_position
            """, (schema, table_name))
            
            columns = cursor.fetchall()
            
            if not columns:
                return jsonify({
                    'success': True,
                    'tableName': table_name,
                    'schema': schema,
                    'columns': [],
                    'count': 0,
                    'message': f'Table {schema}.{table_name} non trouvée ou sans colonnes'
                }), 200
            
            # Enrichir avec infos sur les contraintes
            cursor.execute("""
                SELECT 
                    kcu.column_name,
                    tc.constraint_type
                FROM information_schema.table_constraints tc
                JOIN information_schema.key_column_usage kcu 
                    ON tc.constraint_name = kcu.constraint_name
                    AND tc.table_schema = kcu.table_schema
                WHERE tc.table_schema = %s AND tc.table_name = %s
            """, (schema, table_name))
            
            constraints = {}
            for row in cursor.fetchall():
                col_name = row['column_name']
                if col_name not in constraints:
                    constraints[col_name] = []
                constraints[col_name].append(row['constraint_type'])
            
            for col in columns:
                col['constraints'] = constraints.get(col['name'], [])
                col['isPrimaryKey'] = 'PRIMARY KEY' in col['constraints']
                col['isRequired'] = col['is_nullable'] == 'NO' and col['column_default'] is None
            
            return jsonify({
                'success': True,
                'tableName': table_name,
                'schema': schema,
                'columns': columns,
                'count': len(columns)
            }), 200
            
    except Exception as e:
        current_app.logger.error(f"Erreur récupération colonnes {table_name}: {e}", exc_info=True)
        return jsonify({'error': str(e)}), 500


@import_generic_blueprint.route('/suggest-mapping', methods=['POST'])
# @jwt_required()
def get_mapping_suggestion():
    """
    Suggère un mapping entre les colonnes du fichier et celles de la table cible
    """
    try:
        data = request.get_json()
        file_id = data.get('fileId')
        target_table = data.get('targetTable')
        schema = data.get('schema', 'raw_data')
        
        if not file_id or not target_table:
            return jsonify({'error': 'fileId et targetTable requis'}), 400
        
        # Récupérer les données du fichier
        if file_id not in temp_file_storage:
            return jsonify({'error': 'Fichier non trouvé ou expiré'}), 404
        
        file_data = temp_file_storage[file_id]
        source_columns = file_data['columns']
        
        # Récupérer les colonnes de la table cible
        with get_db_connection() as conn:
            cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
            
            cursor.execute("""
                SELECT 
                    column_name as name,
                    data_type,
                    is_nullable,
                    column_default
                FROM information_schema.columns
                WHERE table_schema = %s AND table_name = %s
                ORDER BY ordinal_position
            """, (schema, target_table))
            
            target_columns = cursor.fetchall()
        
        if not target_columns:
            return jsonify({'error': f'Table {target_table} non trouvée'}), 404
        
        # Générer le mapping
        mappings = suggest_mapping(source_columns, target_columns)
        
        # Identifier les colonnes cibles non mappées
        mapped_targets = {m['target'] for m in mappings if m['target']}
        unmapped_targets = [col for col in target_columns if col['name'] not in mapped_targets]
        
        # Identifier les colonnes requises non mappées
        required_unmapped = [
            col['name'] for col in target_columns 
            if col['is_nullable'] == 'NO' 
            and col['column_default'] is None 
            and col['name'] not in mapped_targets
        ]
        
        return jsonify({
            'success': True,
            'mappings': mappings,
            'targetColumns': target_columns,
            'unmappedTargets': unmapped_targets,
            'requiredUnmapped': required_unmapped,
            'autoMappedCount': sum(1 for m in mappings if m['autoMapped']),
            'totalSourceColumns': len(source_columns),
            'totalTargetColumns': len(target_columns)
        }), 200
        
    except Exception as e:
        current_app.logger.error(f"Erreur suggestion mapping: {e}")
        return jsonify({'error': str(e)}), 500


@import_generic_blueprint.route('/validate-mapping', methods=['POST'])
# @jwt_required()
def validate_mapping():
    """
    Valide le mapping et prévisualise les données transformées
    """
    try:
        data = request.get_json()
        file_id = data.get('fileId')
        target_table = data.get('targetTable')
        mappings = data.get('mappings', [])
        schema = data.get('schema', 'raw_data')
        preview_rows = data.get('previewRows', 10)
        
        if not file_id or not target_table or not mappings:
            return jsonify({'error': 'fileId, targetTable et mappings requis'}), 400
        
        if file_id not in temp_file_storage:
            return jsonify({'error': 'Fichier non trouvé ou expiré'}), 404
        
        file_data = temp_file_storage[file_id]
        df = file_data['dataframe']
        
        errors = []
        warnings = []
        
        # Récupérer les infos des colonnes cibles
        with get_db_connection() as conn:
            cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
            cursor.execute("""
                SELECT column_name, data_type, is_nullable, character_maximum_length
                FROM information_schema.columns
                WHERE table_schema = %s AND table_name = %s
            """, (schema, target_table))
            target_cols_info = {row['column_name']: row for row in cursor.fetchall()}
        
        # Valider chaque mapping
        active_mappings = [m for m in mappings if m.get('target') and not m.get('ignored')]
        
        for mapping in active_mappings:
            source = mapping['source']
            target = mapping['target']
            target_info = target_cols_info.get(target, {})
            
            if source not in df.columns:
                errors.append({
                    'type': 'missing_source',
                    'source': source,
                    'message': f'Colonne source "{source}" non trouvée dans le fichier'
                })
                continue
            
            col_data = df[source]
            
            # Vérifier les valeurs nulles pour colonnes requises
            null_count = col_data.isna().sum()
            if target_info.get('is_nullable') == 'NO' and null_count > 0:
                errors.append({
                    'type': 'null_required',
                    'source': source,
                    'target': target,
                    'count': int(null_count),
                    'message': f'{null_count} valeurs nulles pour la colonne requise "{target}"'
                })
            
            # Vérifier la longueur max pour les chaînes
            max_length = target_info.get('character_maximum_length')
            if max_length:
                too_long = col_data.dropna().apply(lambda x: len(str(x)) > max_length).sum()
                if too_long > 0:
                    warnings.append({
                        'type': 'string_too_long',
                        'source': source,
                        'target': target,
                        'count': int(too_long),
                        'maxLength': max_length,
                        'message': f'{too_long} valeurs dépassent la longueur max ({max_length}) pour "{target}"'
                    })
        
        # Vérifier les colonnes requises non mappées
        mapped_targets = {m['target'] for m in active_mappings}
        for col_name, col_info in target_cols_info.items():
            if col_info['is_nullable'] == 'NO' and col_name not in mapped_targets:
                # Ignorer les colonnes avec valeur par défaut ou auto-générées
                if col_name not in ['id', 'created_at', 'updated_at']:
                    warnings.append({
                        'type': 'required_unmapped',
                        'target': col_name,
                        'message': f'Colonne requise "{col_name}" non mappée'
                    })
        
        # Générer un aperçu des données transformées
        preview_data = []
        for idx, row in df.head(preview_rows).iterrows():
            transformed_row = {}
            row_errors = []
            
            for mapping in active_mappings:
                source = mapping['source']
                target = mapping['target']
                
                if source in row:
                    value = row[source]
                    if pd.isna(value):
                        transformed_row[target] = None
                    else:
                        transformed_row[target] = str(value)
            
            preview_data.append({
                'rowNumber': int(idx) + 1,
                'data': transformed_row,
                'errors': row_errors
            })
        
        valid = len(errors) == 0
        
        return jsonify({
            'success': True,
            'valid': valid,
            'errors': errors,
            'warnings': warnings,
            'previewData': preview_data,
            'stats': {
                'totalRows': len(df),
                'mappedColumns': len(active_mappings),
                'errorCount': len(errors),
                'warningCount': len(warnings)
            }
        }), 200
        
    except Exception as e:
        current_app.logger.error(f"Erreur validation mapping: {e}")
        return jsonify({'error': str(e)}), 500


@import_generic_blueprint.route('/execute', methods=['POST'])
# @jwt_required()
def execute_import():
    """
    Exécute l'import des données avec support upsert
    
    Options:
    - mode: 'insert' (défaut), 'upsert', 'update_only'
    - conflictColumns: colonnes pour détecter les conflits (clé primaire ou unique)
    - updateColumns: colonnes à mettre à jour en cas de conflit (défaut: toutes sauf conflictColumns)
    - commitOnSuccess: commit seulement si aucune erreur (défaut: True)
    - commitPartial: commit même avec erreurs (défaut: False)
    """
    try:
        data = request.get_json()
        file_id = data.get('fileId')
        target_table = data.get('targetTable')
        mappings = data.get('mappings', [])
        schema = data.get('schema', 'raw_data')
        options = data.get('options', {})
        
        if not file_id or not target_table or not mappings:
            return jsonify({'error': 'fileId, targetTable et mappings requis'}), 400
        
        if file_id not in temp_file_storage:
            return jsonify({'error': 'Fichier non trouvé ou expiré'}), 404
        
        file_data = temp_file_storage[file_id]
        df = file_data['dataframe']
        
        # Filtrer les mappings actifs
        active_mappings = [m for m in mappings if m.get('target') and not m.get('ignored')]
        
        if not active_mappings:
            return jsonify({'error': 'Aucun mapping actif'}), 400
        
        # Préparer les données pour l'insertion
        source_cols = [m['source'] for m in active_mappings]
        target_cols = [m['target'] for m in active_mappings]
        
        # Options d'import
        import_mode = options.get('mode', 'insert')  # 'insert', 'upsert', 'update_only'
        conflict_columns = options.get('conflictColumns', [])
        update_columns = options.get('updateColumns', [])
        
        success_count = 0
        updated_count = 0
        inserted_count = 0
        error_count = 0
        errors_detail = []
        
        with get_db_connection() as conn:
            cursor = conn.cursor()
            
            # Identifiant SQL quoté + '%' échappé en '%%'.
            # La requête est passée à psycopg2 avec des paramètres (%s) : psycopg2
            # interprète TOUS les '%' de la chaîne. Un nom de colonne comme
            # "% Complété" casse alors l'exécution ("unsupported format character")
            # tant que le '%' n'est pas doublé. Les placeholders %s restent littéraux.
            def _q(ident):
                return '"' + str(ident).replace('"', '""').replace('%', '%%') + '"'

            # Construire la requête selon le mode
            cols_str = ', '.join(_q(col) for col in target_cols)
            placeholders = ', '.join(['%s'] * len(target_cols))
            table_ref = f'{_q(schema)}.{_q(target_table)}'

            if import_mode == 'upsert' and conflict_columns:
                # Mode UPSERT: INSERT ... ON CONFLICT DO UPDATE
                conflict_str = ', '.join(_q(col) for col in conflict_columns)

                # Colonnes à mettre à jour (toutes sauf les colonnes de conflit)
                if not update_columns:
                    update_columns = [col for col in target_cols if col not in conflict_columns]

                if update_columns:
                    update_str = ', '.join(f'{_q(col)} = EXCLUDED.{_q(col)}' for col in update_columns)
                    query = f'''
                        INSERT INTO {table_ref} ({cols_str})
                        VALUES ({placeholders})
                        ON CONFLICT ({conflict_str}) DO UPDATE SET {update_str}
                    '''
                else:
                    # Si pas de colonnes à updater, on ignore les conflits
                    query = f'''
                        INSERT INTO {table_ref} ({cols_str})
                        VALUES ({placeholders})
                        ON CONFLICT ({conflict_str}) DO NOTHING
                    '''
            elif import_mode == 'update_only' and conflict_columns:
                # Mode UPDATE ONLY: ne fait que des updates
                conflict_str = ' AND '.join(f'{_q(col)} = %s' for col in conflict_columns)
                if not update_columns:
                    update_columns = [col for col in target_cols if col not in conflict_columns]
                update_str = ', '.join(f'{_q(col)} = %s' for col in update_columns)
                query = f'UPDATE {table_ref} SET {update_str} WHERE {conflict_str}'
            else:
                # Mode INSERT standard
                query = f'INSERT INTO {table_ref} ({cols_str}) VALUES ({placeholders})'
            
            current_app.logger.info(f"Mode import: {import_mode}, Query: {query[:200]}...")
            
            # Récupérer les types des colonnes cibles pour conversion appropriée
            cursor.execute("""
                SELECT column_name, data_type 
                FROM information_schema.columns 
                WHERE table_schema = %s AND table_name = %s
            """, (schema, target_table))
            target_types = {row[0]: row[1] for row in cursor.fetchall()}
            
            for idx, row in df.iterrows():
                # SAVEPOINT par ligne : une ligne en erreur n'abandonne pas
                # toute la transaction (évite la cascade "current transaction is aborted")
                cursor.execute("SAVEPOINT row_sp")
                try:
                    values = []
                    for i, source_col in enumerate(source_cols):
                        value = row.get(source_col)
                        target_col = target_cols[i]
                        target_type = target_types.get(target_col, 'text')
                        
                        if pd.isna(value):
                            values.append(None)
                        else:
                            # Conversion selon le type cible
                            if target_type in ('bigint', 'integer', 'smallint'):
                                # Convertir en entier (enlever les .0)
                                try:
                                    values.append(int(float(value)))
                                except (ValueError, TypeError):
                                    raise ValueError(
                                        f'Valeur "{value}" invalide pour la colonne entière '
                                        f'"{target_col}" (type {target_type})'
                                    )
                            elif target_type in ('numeric', 'decimal', 'real', 'double precision'):
                                try:
                                    values.append(float(value))
                                except (ValueError, TypeError):
                                    raise ValueError(
                                        f'Valeur "{value}" invalide pour la colonne numérique '
                                        f'"{target_col}" (type {target_type})'
                                    )
                            elif target_type == 'boolean':
                                values.append(bool(value))
                            else:
                                values.append(str(value))
                    
                    if import_mode == 'update_only' and conflict_columns:
                        # Pour UPDATE ONLY, réorganiser les valeurs
                        conflict_values = [values[target_cols.index(col)] for col in conflict_columns]
                        update_values = [values[target_cols.index(col)] for col in update_columns]
                        cursor.execute(query, update_values + conflict_values)
                        if cursor.rowcount > 0:
                            updated_count += 1
                            success_count += 1
                    else:
                        cursor.execute(query, values)
                        success_count += 1
                        if import_mode == 'upsert':
                            # PostgreSQL ne permet pas facilement de savoir si c'était insert ou update
                            inserted_count += 1
                        else:
                            inserted_count += 1

                    cursor.execute("RELEASE SAVEPOINT row_sp")

                except Exception as e:
                    # Annuler uniquement cette ligne, la transaction reste valide
                    cursor.execute("ROLLBACK TO SAVEPOINT row_sp")
                    error_count += 1
                    if len(errors_detail) < 100:
                        errors_detail.append({
                            'row': int(idx) + 1,
                            'error': str(e)
                        })
            
            if options.get('commitOnSuccess', True) and error_count == 0:
                conn.commit()
            elif options.get('commitPartial', False):
                conn.commit()
            else:
                if error_count > 0 and not options.get('commitPartial', False):
                    conn.rollback()
                    return jsonify({
                        'success': False,
                        'message': 'Import annulé en raison d\'erreurs',
                        'successCount': 0,
                        'errorCount': error_count,
                        'errors': errors_detail
                    }), 400
                conn.commit()
        
        # Nettoyer le fichier temporaire
        del temp_file_storage[file_id]
        
        message = f'Import terminé: {success_count} lignes traitées'
        if import_mode == 'upsert':
            message = f'Import terminé: {success_count} lignes (insert/update)'
        elif import_mode == 'update_only':
            message = f'Import terminé: {updated_count} lignes mises à jour'
        
        current_app.logger.info(f"Import terminé: {success_count} succès, {error_count} erreurs, mode={import_mode}")
        
        return jsonify({
            'success': True,
            'message': message,
            'successCount': success_count,
            'insertedCount': inserted_count,
            'updatedCount': updated_count,
            'errorCount': error_count,
            'errors': errors_detail,
            'targetTable': target_table,
            'mode': import_mode
        }), 200
        
    except Exception as e:
        current_app.logger.error(f"Erreur exécution import: {e}")
        return jsonify({'error': str(e)}), 500


@import_generic_blueprint.route('/cleanup/<file_id>', methods=['DELETE'])
def cleanup_file(file_id: str):
    """Nettoie un fichier temporaire"""
    if file_id in temp_file_storage:
        del temp_file_storage[file_id]
    return jsonify({'success': True}), 200
