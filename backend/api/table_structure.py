from flask import Blueprint, request, jsonify, current_app
from flask_jwt_extended import jwt_required, get_jwt_identity, verify_jwt_in_request
from werkzeug.utils import secure_filename
import pandas as pd
import os
from datetime import datetime
from config.database import get_db_connection
import psycopg2.extras

table_structure_blueprint = Blueprint('table_structure', __name__)

ALLOWED_EXTENSIONS = {'xls', 'xlsx'}

# Utiliser un chemin absolu basé sur le répertoire de l'application
def get_upload_folder():
    """Retourne le chemin absolu du dossier d'upload"""
    base_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    upload_folder = os.path.join(base_dir, 'uploads', 'table_structures')
    os.makedirs(upload_folder, exist_ok=True, mode=0o755)
    return upload_folder

def allowed_file(filename):
    return '.' in filename and filename.rsplit('.', 1)[1].lower() in ALLOWED_EXTENSIONS

@table_structure_blueprint.route('/summary', methods=['GET'])
# @jwt_required()
def get_table_summary():
    """Récupère le résumé des tables (nombre de colonnes, clés, etc.)"""
    try:
        with get_db_connection() as conn:
            cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
            
            cursor.execute("""
                SELECT 
                    table_name,
                    job_name,
                    COUNT(*) as column_count,
                    SUM(CASE WHEN is_key THEN 1 ELSE 0 END) as key_count,
                    SUM(CASE WHEN is_mandatory THEN 1 ELSE 0 END) as mandatory_count,
                    MAX(imported_at) as imported_at
                FROM public.table_structure_metadata
                GROUP BY table_name, job_name
                ORDER BY imported_at DESC, table_name
            """)
            
            summaries = cursor.fetchall()
            
            return jsonify({
                'success': True,
                'data': summaries,
                'total': len(summaries)
            }), 200
            
    except Exception as e:
        current_app.logger.error(f"❌ Erreur récupération résumé: {e}")
        return jsonify({
            'success': False,
            'error': 'Erreur lors de la récupération du résumé',
            'message': str(e)
        }), 500

@table_structure_blueprint.route('', methods=['GET'])
# @jwt_required()
def get_table_structures():
    """Récupère la liste des structures de tables"""
    try:
        page = request.args.get('page', 1, type=int)
        per_page = request.args.get('per_page', 25, type=int)
        search = request.args.get('search', '', type=str)
        
        with get_db_connection() as conn:
            cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
            
            # Construire la requête de base
            base_query = """
                FROM public.table_structure_metadata
                WHERE 1=1
            """
            params = []
            
            # Filtre par table et job
            table_filter = request.args.get('table_name', '', type=str)
            job_filter = request.args.get('job_name', '', type=str)
            
            if table_filter:
                base_query += " AND table_name = %s"
                params.append(table_filter)
            
            if job_filter:
                base_query += " AND job_name = %s"
                params.append(job_filter)
            
            # Filtre de recherche
            if search:
                base_query += """
                    AND (
                        LOWER(table_name) LIKE LOWER(%s)
                        OR LOWER(column_name) LIKE LOWER(%s)
                        OR LOWER(job_name) LIKE LOWER(%s)
                    )
                """
                search_pattern = f'%{search}%'
                params.extend([search_pattern, search_pattern, search_pattern])
            
            # Compter le total
            count_query = f"SELECT COUNT(*) as total {base_query}"
            cursor.execute(count_query, params)
            total = cursor.fetchone()['total']
            
            # Récupérer les données paginées
            offset = (page - 1) * per_page
            data_query = f"""
                SELECT *
                {base_query}
                ORDER BY table_name, column_name
                LIMIT %s OFFSET %s
            """
            params.extend([per_page, offset])
            cursor.execute(data_query, params)
            structures = cursor.fetchall()
            
            current_app.logger.info(f"✅ {len(structures)} structures récupérées")
            
            return jsonify({
                'success': True,
                'data': structures,
                'total': total,
                'page': page,
                'per_page': per_page
            }), 200
            
    except Exception as e:
        current_app.logger.error(f"❌ Erreur récupération structures: {e}")
        return jsonify({
            'success': False,
            'error': 'Erreur lors de la récupération des structures',
            'message': str(e)
        }), 500

@table_structure_blueprint.route('/upload', methods=['POST'])
# @jwt_required()
def upload_table_structure():
    """Importe une structure de table depuis un fichier Excel"""
    try:
        # Vérifier la présence du fichier
        if 'file' not in request.files:
            return jsonify({
                'success': False,
                'message': 'Aucun fichier fourni'
            }), 400
        
        file = request.files['file']
        job_name = request.form.get('job_name', '')
        table_name = request.form.get('table_name', '')
        schema_name = request.form.get('schema_name', 'clean_data')
        
        if file.filename == '':
            return jsonify({
                'success': False,
                'message': 'Aucun fichier sélectionné'
            }), 400
        
        if not job_name:
            return jsonify({
                'success': False,
                'message': 'Nom du job manquant'
            }), 400
        
        if not table_name:
            return jsonify({
                'success': False,
                'message': 'Nom de la table manquant'
            }), 400
        
        # Valider le schéma
        allowed_schemas = ['raw_data', 'public', 'clean_data']
        if schema_name not in allowed_schemas:
            return jsonify({
                'success': False,
                'message': f'Schéma invalide. Doit être l\'un de: {", ".join(allowed_schemas)}'
            }), 400
        
        if file and allowed_file(file.filename):
            filename = secure_filename(file.filename)
            
            try:
                # Lire le fichier Excel directement depuis la mémoire (évite les problèmes de permissions)
                df = pd.read_excel(file.stream)
                
                current_app.logger.info(f"📊 Fichier Excel lu: {len(df)} lignes")
                current_app.logger.info(f"Colonnes détectées: {df.columns.tolist()}")
                
                current_app.logger.info(f"Table: {schema_name}.{table_name}, Job: {job_name}")
                
                imported_count = 0
                errors = []
                skipped_count = 0
                
                with get_db_connection() as conn:
                    cursor = conn.cursor()
                    
                    for index, row in df.iterrows():
                        try:
                            # Extraire Column Name - essayer différentes variations
                            column_name = None
                            for col_name in ['Column Name', 'column name', 'COLUMN NAME', 'ColumnName', 'columnname']:
                                if col_name in row and pd.notna(row[col_name]):
                                    column_name = str(row[col_name]).strip()
                                    break
                            
                            # Si toujours None, essayer avec l'index de la colonne
                            if not column_name:
                                # Chercher la colonne qui contient "Column Name" dans son nom
                                for col in df.columns:
                                    if 'column' in str(col).lower() and 'name' in str(col).lower():
                                        if pd.notna(row[col]):
                                            column_name = str(row[col]).strip()
                                            break
                            
                            if not column_name or column_name == '' or column_name.lower() == 'nan':
                                skipped_count += 1
                                if skipped_count <= 3:  # Logger les 3 premières lignes ignorées
                                    current_app.logger.warning(f"Ligne {index + 2}: pas de nom de colonne valide. Colonnes disponibles: {df.columns.tolist()}")
                                continue
                            
                            # Logger les 3 premières lignes pour debug
                            if index < 3:
                                current_app.logger.info(f"Ligne {index + 2}: column_name={column_name}, flags={row.get('Flags')}, data_type={row.get('Data Type')}")
                            
                            # Extraire les données
                            description = str(row.get('Description', '')).strip() if pd.notna(row.get('Description')) else None
                            flags = str(row.get('Flags', '')).strip() if pd.notna(row.get('Flags')) else None
                            data_type = str(row.get('Data Type', '')).strip() if pd.notna(row.get('Data Type')) else None
                            
                            # Length
                            length = None
                            if pd.notna(row.get('Length')):
                                try:
                                    length = int(float(row.get('Length')))
                                except:
                                    pass
                            
                            # Decimal Length
                            decimal_length = None
                            if pd.notna(row.get('Decimal Length')):
                                try:
                                    decimal_length = int(float(row.get('Decimal Length')))
                                except:
                                    pass
                            
                            # Default Value
                            default_value = str(row.get('Default Value', '')).strip() if pd.notna(row.get('Default Value')) else None
                            
                            # Change Defaults - Convertir en booléen ou laisser None
                            change_defaults_raw = str(row.get('Change Defaults', '')).strip() if pd.notna(row.get('Change Defaults')) else None
                            change_defaults = None
                            if change_defaults_raw:
                                # Interpréter comme booléen
                                if change_defaults_raw.upper() in ['TRUE', 'YES', '1', 'Y', 'OUI']:
                                    change_defaults = True
                                elif change_defaults_raw.upper() in ['FALSE', 'NO', '0', 'N', 'NON']:
                                    change_defaults = False
                                # Sinon laisser None
                            
                            # Autres colonnes
                            amount_denominator = str(row.get('Amount Denominator', '')).strip() if pd.notna(row.get('Amount Denominator')) else None
                            default_where = str(row.get('Default Where', '')).strip() if pd.notna(row.get('Default Where')) else None
                            pad_char_right = str(row.get('Pad Char Right', '')).strip() if pd.notna(row.get('Pad Char Right')) else None
                            pad_char_left = str(row.get('Pad Char Left', '')).strip() if pd.notna(row.get('Pad Char Left')) else None
                            
                            # Attr Seq
                            attr_seq = None
                            if pd.notna(row.get('Attr Seq')):
                                try:
                                    attr_seq = int(float(row.get('Attr Seq')))
                                except:
                                    pass
                            
                            note_text = str(row.get('Note Text', '')).strip() if pd.notna(row.get('Note Text')) else None
                            conversion_list = str(row.get('Conversion List', '')).strip() if pd.notna(row.get('Conversion List')) else None
                            ext_attr = str(row.get('Ext Attr', '')).strip() if pd.notna(row.get('Ext Attr')) else None
                            
                            # Extraire les flags individuels
                            is_key = 'K' in (flags or '')
                            is_mandatory = 'M' in (flags or '')
                            is_updatable = 'U' in (flags or '')
                            is_insertable = 'I' in (flags or '')
                            
                            # Récupérer l'utilisateur (sans erreur si JWT non présent)
                            imported_by = 'anonymous'
                            try:
                                verify_jwt_in_request(optional=True)
                                imported_by = get_jwt_identity() or 'anonymous'
                            except:
                                pass
                            
                            # Logger les 3 premières requêtes SQL pour debug
                            if index < 3:
                                current_app.logger.info(f"""
                                    Ligne {index + 2} - Valeurs à insérer:
                                    - job_name: {job_name}
                                    - table_name: {table_name}
                                    - column_name: {column_name}
                                    - description: {description}
                                    - flags: {flags}
                                    - data_type: {data_type}
                                    - length: {length}
                                    - decimal_length: {decimal_length}
                                    - default_value: {default_value}
                                    - change_defaults: {change_defaults} (type: {type(change_defaults)})
                                    - is_key: {is_key}
                                    - is_mandatory: {is_mandatory}
                                    - is_updatable: {is_updatable}
                                    - is_insertable: {is_insertable}
                                """)
                            
                            # Insérer dans la base
                            cursor.execute("""
                                INSERT INTO public.table_structure_metadata (
                                    job_name, table_name, column_name, description,
                                    flags, data_type, length, decimal_length, default_value,
                                    change_defaults, is_key, is_mandatory, is_updatable, is_insertable,
                                    amount_denominator, default_where, pad_char_right, pad_char_left,
                                    attr_seq, note_text, conversion_list, ext_attr,
                                    source_file, imported_by
                                )
                                VALUES (
                                    %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s,
                                    %s, %s, %s, %s, %s, %s, %s, %s, %s, %s
                                )
                                ON CONFLICT (table_name, column_name, job_name)
                                DO UPDATE SET
                                    description = EXCLUDED.description,
                                    flags = EXCLUDED.flags,
                                    data_type = EXCLUDED.data_type,
                                    length = EXCLUDED.length,
                                    decimal_length = EXCLUDED.decimal_length,
                                    default_value = EXCLUDED.default_value,
                                    change_defaults = EXCLUDED.change_defaults,
                                    is_key = EXCLUDED.is_key,
                                    is_mandatory = EXCLUDED.is_mandatory,
                                    is_updatable = EXCLUDED.is_updatable,
                                    is_insertable = EXCLUDED.is_insertable,
                                    amount_denominator = EXCLUDED.amount_denominator,
                                    default_where = EXCLUDED.default_where,
                                    pad_char_right = EXCLUDED.pad_char_right,
                                    pad_char_left = EXCLUDED.pad_char_left,
                                    attr_seq = EXCLUDED.attr_seq,
                                    note_text = EXCLUDED.note_text,
                                    conversion_list = EXCLUDED.conversion_list,
                                    ext_attr = EXCLUDED.ext_attr,
                                    updated_at = CURRENT_TIMESTAMP
                            """, (
                                job_name, table_name, column_name, description,
                                flags, data_type, length, decimal_length, default_value,
                                change_defaults, is_key, is_mandatory, is_updatable, is_insertable,
                                amount_denominator, default_where, pad_char_right, pad_char_left,
                                attr_seq, note_text, conversion_list, ext_attr,
                                filename, imported_by
                            ))
                            
                            imported_count += 1
                            
                            if imported_count <= 3:  # Logger les 3 premières insertions pour debug
                                current_app.logger.info(f"✅ Ligne {index + 2} insérée: {column_name} (flags: {flags})")
                            
                        except Exception as e:
                            error_msg = f"Ligne {index + 2}: {str(e)}"
                            errors.append(error_msg)
                            current_app.logger.error(f"❌ {error_msg}")
                            import traceback
                            current_app.logger.error(traceback.format_exc())
                            # Rollback de la transaction en cas d'erreur
                            conn.rollback()
                            # Recommencer une nouvelle transaction
                            cursor = conn.cursor()
                    
                    # Créer la table dans le schéma spécifié
                    if imported_count > 0:
                        try:
                            current_app.logger.info(f"🔨 Création/Recréation de la table {schema_name}.{table_name}...")
                            
                            # Créer le schéma s'il n'existe pas
                            cursor.execute(f"CREATE SCHEMA IF NOT EXISTS {schema_name}")
                            
                            # Supprimer la table si elle existe déjà (pour la recréer)
                            cursor.execute(f"DROP TABLE IF EXISTS {schema_name}.{table_name} CASCADE")
                            current_app.logger.info(f"Table {schema_name}.{table_name} supprimée (si elle existait)")
                            
                            # Récupérer toutes les colonnes pour cette table
                            cursor.execute("""
                                SELECT column_name, data_type, length, decimal_length, is_mandatory, default_value, is_key
                                FROM public.table_structure_metadata
                                WHERE job_name = %s AND table_name = %s
                                ORDER BY attr_seq NULLS LAST, column_name
                            """, (job_name, table_name))
                            
                            columns = cursor.fetchall()
                            
                            if not columns:
                                current_app.logger.warning(f"Aucune colonne trouvée pour {table_name}")
                            else:
                                # Construire la requête CREATE TABLE
                                create_table_parts = []
                                
                                # Identifier les clés primaires (en minuscules)
                                primary_keys = [col[0].lower() for col in columns if col[6]]  # is_key
                                
                                for col in columns:
                                    col_name = col[0]
                                    col_type = col[1] or 'VARCHAR'
                                    col_length = col[2]
                                    col_decimal = col[3]
                                    is_mandatory = col[4]
                                    default_val = col[5]
                                    
                                    # Convertir le nom de colonne en minuscules (insensible à la casse)
                                    col_name_lower = col_name.lower()
                                    
                                    # Pas besoin d'échapper avec des guillemets si en minuscules
                                    col_name_escaped = col_name_lower
                                    
                                    # Construire le type de données
                                    if col_type.upper() in ['VARCHAR', 'VARCHAR2', 'CHAR']:
                                        if col_length:
                                            type_def = f"VARCHAR({col_length})"
                                        else:
                                            type_def = "VARCHAR(255)"
                                    elif col_type.upper() in ['NUMBER', 'NUMERIC', 'DECIMAL']:
                                        if col_decimal:
                                            type_def = f"NUMERIC({col_length or 10},{col_decimal})"
                                        elif col_length:
                                            type_def = f"NUMERIC({col_length})"
                                        else:
                                            type_def = "NUMERIC"
                                    elif col_type.upper() in ['DATE', 'TIMESTAMP']:
                                        type_def = "TIMESTAMP"
                                    elif col_type.upper() in ['INTEGER', 'INT']:
                                        type_def = "INTEGER"
                                    elif col_type.upper() in ['BOOLEAN', 'BOOL']:
                                        type_def = "BOOLEAN"
                                    else:
                                        type_def = "TEXT"
                                    
                                    # Construire la définition de colonne
                                    col_def = f"{col_name_escaped} {type_def}"
                                    
                                    # Ajouter NOT NULL si obligatoire
                                    if is_mandatory:
                                        col_def += " NOT NULL"
                                    
                                    # Ajouter DEFAULT si présent
                                    if default_val and default_val.strip() and default_val.upper() != 'NULL':
                                        # Échapper les valeurs par défaut
                                        if col_type.upper() in ['VARCHAR', 'VARCHAR2', 'CHAR', 'TEXT']:
                                            escaped_val = default_val.replace("'", "''")
                                            col_def += f" DEFAULT '{escaped_val}'"
                                        else:
                                            col_def += f" DEFAULT {default_val}"
                                    
                                    create_table_parts.append(col_def)
                                
                                # Construire la requête complète
                                create_table_query = f"CREATE TABLE {schema_name}.{table_name} (\n    "
                                create_table_query += ",\n    ".join(create_table_parts)
                                
                                # Ajouter la contrainte de clé primaire si des clés existent
                                if primary_keys:
                                    pk_cols = ', '.join(primary_keys)  # Déjà en minuscules
                                    create_table_query += f",\n    PRIMARY KEY ({pk_cols})"
                                
                                create_table_query += "\n);"
                                
                                # Exécuter la création de la table
                                cursor.execute(create_table_query)
                                conn.commit()
                                
                                current_app.logger.info(f"✅ Table {schema_name}.{table_name} créée avec succès ({len(columns)} colonnes)")
                            
                        except Exception as e:
                            current_app.logger.error(f"❌ Erreur lors de la création de la table: {e}")
                            import traceback
                            current_app.logger.error(traceback.format_exc())
                            errors.append(f"Erreur création table: {str(e)}")
                    
                    conn.commit()
                
                current_app.logger.info(f"✅ Import terminé: {imported_count} colonnes importées, {skipped_count} lignes ignorées, {len(errors)} erreurs")
                
                return jsonify({
                    'success': True,
                    'message': f'{imported_count} colonnes importées avec succès',
                    'imported_count': imported_count,
                    'errors': errors
                }), 200
                
            except Exception as e:
                current_app.logger.error(f"❌ Erreur traitement fichier: {e}")
                import traceback
                current_app.logger.error(traceback.format_exc())
                
                return jsonify({
                    'success': False,
                    'message': f'Erreur lors du traitement du fichier: {str(e)}'
                }), 500
        
        return jsonify({
            'success': False,
            'message': 'Type de fichier non autorisé'
        }), 400
        
    except Exception as e:
        current_app.logger.error(f"❌ Erreur upload: {e}")
        return jsonify({
            'success': False,
            'error': 'Erreur lors de l\'upload',
            'message': str(e)
        }), 500

