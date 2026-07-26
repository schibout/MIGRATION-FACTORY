import io
import csv
import re
from datetime import datetime, date
import time
from typing import List, Dict, Any, Optional, Tuple, Generator

import pandas as pd
from flask import current_app, Response, abort
from sqlalchemy import create_engine, text, MetaData, Table, inspect, select, column
from sqlalchemy.engine import Connection
from sqlalchemy.exc import SQLAlchemyError

from models import db
from utils.validators import validate_table_name, validate_fields, sanitize_filter_value

class DataService:
    """Service de gestion des données PostgreSQL avec optimisations"""
    
    def __init__(self):
        # pool_pre_ping : vérifie la connexion avant usage (évite les
        # "SSL SYSCALL error: EOF detected" sur connexion coupée côté serveur).
        # pool_recycle : recycle les connexions au bout de 30 min.
        self.engine = create_engine(
            current_app.config['SQLALCHEMY_DATABASE_URI'],
            pool_pre_ping=True,
            pool_recycle=1800,
        )
        self.metadata = MetaData()
        self.inspector = inspect(self.engine)
        self.export_chunk_size = current_app.config.get('EXPORT_CHUNK_SIZE', 5000)
        self.max_export_rows = current_app.config.get('MAX_EXPORT_ROWS', 1000000)
        self._table_schema_cache = {}  # Cache des schémas de tables
    
    def _normalize_table_name(self, table_name: str) -> str:
        """Normalise le nom de table pour PostgreSQL (convertit en minuscule)"""
        return table_name.lower()
    
    def _format_dates_in_data(self, data: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
        """
        Formate toutes les dates au format DD-MM-YYYY dans les données
        
        Args:
            data: Liste de dictionnaires contenant les données
            
        Returns:
            Liste de dictionnaires avec les dates formatées
        """
        formatted_data = []
        for row in data:
            formatted_row = {}
            for key, value in row.items():
                # Vérifier si c'est une date
                if isinstance(value, (datetime, date, pd.Timestamp)):
                    formatted_row[key] = value.strftime('%d-%m-%Y')
                elif value is not None and isinstance(value, str):
                    # Essayer de parser si c'est une chaîne qui ressemble à une date
                    try:
                        parsed_date = pd.to_datetime(value)
                        formatted_row[key] = parsed_date.strftime('%d-%m-%Y')
                    except:
                        formatted_row[key] = value
                else:
                    formatted_row[key] = value
            formatted_data.append(formatted_row)
        return formatted_data
    
    def get_sap_tables(self, page: int = 1, limit: int = 20, search: str = '') -> Dict[str, Any]:
        """Récupère la liste des tables SAP selon les spécifications"""
        try:
            offset = (page - 1) * limit
            search_pattern = f"%{search}%" if search else "%"
            
            with self.engine.connect() as connection:
                # Requête pour compter le total
                count_query = text("""
                    SELECT COUNT(*) 
                    FROM public.sap_table_properties
                    WHERE table_name ILIKE :search
                """)
                
                total = connection.execute(count_query, {"search": search_pattern}).scalar()
                
                # Requête principale avec pagination
                query = text("""
                    SELECT table_name, table_class 
                    FROM public.sap_table_properties
                    WHERE table_name ILIKE :search
                    ORDER BY table_name ASC
                    LIMIT :limit OFFSET :offset
                """)
                
                result = connection.execute(query, {
                    "search": search_pattern,
                    "limit": limit,
                    "offset": offset
                })
                
                tables = []
                for row in result:
                    tables.append({
                        "name": row.table_name,
                        "class": row.table_class
                    })
                
                return {
                    "total": total,
                    "page": page,
                    "limit": limit,
                    "pages": (total // limit) + (1 if total % limit > 0 else 0),
                    "tables": tables
                }
                
        except SQLAlchemyError as e:
            current_app.logger.error(f"Erreur SQL lors de la récupération des tables SAP: {str(e)}")
            raise
    
    def get_tables(self) -> List[Dict[str, Any]]:
        """Récupère la liste des tables disponibles avec les statistiques"""
        try:
            with self.engine.connect() as connection:
                # Requête pour obtenir les tables avec leur nombre de lignes
                query = text("""
                    SELECT 
                        t.table_name, 
                        pg_catalog.obj_description(pgc.oid, 'pg_class') as description,
                        (SELECT reltuples::bigint FROM pg_class WHERE relname = t.table_name) as row_count
                    FROM information_schema.tables t
                    JOIN pg_catalog.pg_class pgc ON t.table_name = pgc.relname
                    WHERE t.table_schema = 'raw_data'
                    AND t.table_type = 'BASE TABLE'
                    ORDER BY t.table_name
                """)
                
                result = connection.execute(query)
                tables = []
                
                for row in result:
                    tables.append({
                        "name": row.table_name,
                        "description": row.description or f"Table {row.table_name}",
                        "row_count": int(row.row_count)
                    })
                
                return tables
                
        except SQLAlchemyError as e:
            current_app.logger.error(f"Erreur lors de la récupération des tables: {str(e)}")
            raise
    
    def get_table_fields(self, table_name: str) -> List[Dict[str, str]]:
        """Récupère les champs d'une table avec leur description"""
        # Validation du nom de table pour éviter SQL injection
        if not validate_table_name(table_name):
            abort(400, description="Nom de table invalide")
            
        try:
            # Normalisation du nom de table pour PostgreSQL
            normalized_table = self._normalize_table_name(table_name)
            
            if (normalized_table in self._table_schema_cache):
                return self._table_schema_cache[normalized_table]
                
            with self.engine.connect() as connection:
                query = text(f"""
                    SELECT 
                        column_name, 
                        data_type,
                        pg_catalog.col_description(
                            (SELECT oid FROM pg_catalog.pg_class WHERE relname = :table_name), 
                            ordinal_position
                        ) as description
                    FROM information_schema.columns
                    WHERE table_schema = 'raw_data'
                    AND table_name = :table_name
                    ORDER BY ordinal_position
                """)
                
                result = connection.execute(query, {"table_name": normalized_table})
                fields = []
                
                for row in result:
                    fields.append({
                        "name": row.column_name,
                        "type": row.data_type,
                        "description": row.description or row.column_name
                    })
                
                # Mise en cache du schéma
                self._table_schema_cache[normalized_table] = fields
                return fields
                
        except SQLAlchemyError as e:
            current_app.logger.error(f"Erreur lors de la récupération des champs de {table_name}: {str(e)}")
            raise
    
    def get_preview_data(self, table_name: str, fields: List[str] = None, limit: int = 5) -> Dict[str, Any]:
        """Récupère un aperçu des données pour prévisualisation"""
        # Validation du nom de table et des champs
        if not validate_table_name(table_name):
            abort(400, description="Nom de table invalide")
        
        if fields and not validate_fields(fields):
            abort(400, description="Liste de champs invalide")
            
        try:
            # Normalisation du nom de table pour PostgreSQL
            normalized_table = self._normalize_table_name(table_name)
            
            with self.engine.connect() as connection:
                # Détermination des champs à récupérer
                all_fields = self.get_table_fields(table_name)
                all_field_names = [f["name"] for f in all_fields]
                
                # Si des champs sont spécifiés, les valider
                selected_fields = fields if fields else all_field_names
                if not all(f in all_field_names for f in selected_fields):
                    abort(400, description="Certains champs demandés n'existent pas dans la table")
                    
                fields_str = ", ".join([f'"{f}"' for f in selected_fields])
                query = text(f'SELECT {fields_str} FROM raw_data."{normalized_table}" LIMIT :limit')
                
                result = connection.execute(query, {"limit": limit})
                
                return {
                    "columns": selected_fields,
                    "data": [dict(zip(selected_fields, row)) for row in result]
                }
                
        except SQLAlchemyError as e:
            current_app.logger.error(f"Erreur lors de la récupération de l'aperçu pour {table_name}: {str(e)}")
            raise
    
    def _build_filter_query(self, table_name: str, filters: List[Dict[str, Any]], 
                           conjunction: str = 'AND') -> Tuple[str, Dict[str, Any]]:
        """Construit la clause WHERE à partir des filtres"""
        if not filters:
            return "", {}
            
        where_clauses = []
        params = {}
        
        for i, filter_item in enumerate(filters):
            field = filter_item.get('field')
            operator = filter_item.get('operator', '=')
            value = filter_item.get('value')
            
            # Validation
            if not field or not validate_fields([field]):
                abort(400, description=f"Champ invalide dans le filtre: {field}")
                
            # Mapping des opérateurs
            sql_operators = {
                '=': '=', 
                '!=': '<>', 
                '>': '>', 
                '<': '<', 
                '>=': '>=', 
                '<=': '<=',
                'LIKE': 'LIKE', 
                'NOT LIKE': 'NOT LIKE',
                'IN': 'IN',
                'NOT IN': 'NOT IN',
                'IS NULL': 'IS NULL',
                'IS NOT NULL': 'IS NOT NULL'
            }
            
            if operator not in sql_operators:
                abort(400, description=f"Opérateur invalide: {operator}")
                
            param_name = f"param_{i}"
            
            # Traitement spécial pour les opérateurs qui n'ont pas besoin de valeur
            if operator in ('IS NULL', 'IS NOT NULL'):
                where_clauses.append(f'"{field}" {sql_operators[operator]}')
            # Traitement pour les opérateurs IN/NOT IN
            elif operator in ('IN', 'NOT IN') and isinstance(value, list):
                params.update({f"{param_name}_{j}": sanitize_filter_value(v) for j, v in enumerate(value)})
                placeholders = [f":{param_name}_{j}" for j in range(len(value))]
                where_clauses.append(f'"{field}" {sql_operators[operator]} ({", ".join(placeholders)})')
            # Cas standard
            else:
                params[param_name] = sanitize_filter_value(value)
                where_clauses.append(f'"{field}" {sql_operators[operator]} :{param_name}')
                
        # Construction de la clause WHERE complète
        return f"WHERE {f' {conjunction} '.join(where_clauses)}", params
    
    def filter_data(self, table_name: str, filters: List[Dict[str, Any]], 
                  fields: List[str] = None, conjunction: str = 'AND', 
                  page: int = 1, page_size: int = 20) -> Dict[str, Any]:
        """Filtre les données selon les critères spécifiés"""
        # Validation des entrées
        if not validate_table_name(table_name):
            abort(400, description="Nom de table invalide")
            
        if fields and not validate_fields(fields):
            abort(400, description="Liste de champs invalide")
            
        if conjunction not in ('AND', 'OR'):
            abort(400, description="Conjonction invalide, doit être AND ou OR")
            
        try:
            # Normalisation du nom de table pour PostgreSQL
            normalized_table = self._normalize_table_name(table_name)
            
            with self.engine.connect() as connection:
                # Détermination des champs à récupérer
                all_fields = self.get_table_fields(table_name)
                all_field_names = [f["name"] for f in all_fields]
                
                # Si des champs sont spécifiés, les valider
                selected_fields = fields if fields else all_field_names
                if not all(f in all_field_names for f in selected_fields):
                    abort(400, description="Certains champs demandés n'existent pas dans la table")
                    
                # Construction de la clause WHERE
                where_clause, params = self._build_filter_query(table_name, filters, conjunction)
                
                # Requête pour compter le nombre total de résultats
                count_query = text(f'SELECT COUNT(*) FROM raw_data."{normalized_table}" {where_clause}')
                count_result = connection.execute(count_query, params).scalar()
                
                # Calcul de la pagination
                offset = (page - 1) * page_size
                
                # Requête pour récupérer les données paginées
                fields_str = ", ".join([f'"{f}"' for f in selected_fields])
                data_query = text(
                    f'SELECT {fields_str} FROM raw_data."{normalized_table}" {where_clause} '
                    f'LIMIT :limit OFFSET :offset'
                )
                
                params.update({"limit": page_size, "offset": offset})
                result = connection.execute(data_query, params)
                
                # Formatage des résultats
                data = [dict(zip(selected_fields, row)) for row in result]
                
                return {
                    "total": count_result,
                    "page": page,
                    "page_size": page_size,
                    "pages": (count_result // page_size) + (1 if count_result % page_size > 0 else 0),
                    "columns": selected_fields,
                    "data": data
                }
                
        except SQLAlchemyError as e:
            current_app.logger.error(f"Erreur lors du filtrage des données pour {table_name}: {str(e)}")
            raise
    
    def _get_data_generator(self, connection: Connection, table_name: str, 
                           fields: List[str], where_clause: str, params: Dict[str, Any]) -> Generator:
        """Générateur streaming pour l'extraction de données par lots"""
        # Normalisation du nom de table pour PostgreSQL
        normalized_table = self._normalize_table_name(table_name)
        
        fields_str = ", ".join([f'"{f}"' for f in fields])
        offset = 0
        chunk_size = self.export_chunk_size
        total_rows = 0
        
        while True:
            # Requête pour récupérer un lot de données
            query = text(
                f'SELECT {fields_str} FROM raw_data."{normalized_table}" {where_clause} '
                f'LIMIT :limit OFFSET :offset'
            )
            
            batch_params = params.copy()
            batch_params.update({"limit": chunk_size, "offset": offset})
            
            result = connection.execute(query, batch_params)
            rows = result.fetchall()
            
            # Si plus de données à récupérer, on arrête
            if not rows:
                break
                
            # Vérification de la limite maximale
            total_rows += len(rows)
            if total_rows > self.max_export_rows:
                current_app.logger.warning(
                    f"Export tronqué pour {table_name}: limite de {self.max_export_rows} lignes atteinte"
                )
                yield [dict(zip(fields, row)) for row in rows[:self.max_export_rows - (total_rows - len(rows))]]
                break
                
            # Yield du lot courant
            yield [dict(zip(fields, row)) for row in rows]
            
            # Préparation pour le prochain lot
            offset += chunk_size
            
            # Pause courte pour éviter de surcharger la BD
            time.sleep(0.01)
    
    def export_csv(self, table_name: str, fields: List[str], filters: List[Dict[str, Any]], 
                 options: Dict[str, Any] = None) -> Response:
        """Exporte les données filtrées au format CSV avec streaming"""
        # Validation des entrées
        if not validate_table_name(table_name):
            abort(400, description="Nom de table invalide")
            
        if not fields or not validate_fields(fields):
            abort(400, description="Liste de champs invalide")
              # Options par défaut
        options = options or {}
        delimiter = options.get('delimiter', ';')
        encoding = options.get('encoding', 'utf-8')
        include_headers = options.get('includeHeaders', True)
        use_column_names = options.get('useColumnNames', False)  # Nouvelle option
        conjunction = options.get('conjunction', 'AND')
        
        try:
            with self.engine.connect() as connection:
                # Vérification que les champs existent
                all_fields = self.get_table_fields(table_name)
                all_field_names = [f["name"] for f in all_fields]
                
                if not all(f in all_field_names for f in fields):
                    abort(400, description="Certains champs demandés n'existent pas dans la table")
                
                # Construction de la clause WHERE
                where_clause, params = self._build_filter_query(table_name, filters, conjunction)
                
                # Création d'un générateur de données streaming
                def generate_csv():                    # En-têtes CSV si nécessaire
                    if include_headers:
                        if use_column_names:
                            # Utiliser les noms des colonnes directement
                            headers = fields
                        else:
                            # Récupérer les descriptions des champs
                            field_descriptions = {f["name"]: f["description"] for f in all_fields}
                            headers = [field_descriptions.get(f, f) for f in fields]
                        yield delimiter.join(headers) + '\n'
                    
                    # Parcours des lots de données
                    for batch in self._get_data_generator(connection, table_name, fields, where_clause, params):
                        # Formater les dates au format DD-MM-YYYY
                        formatted_batch = self._format_dates_in_data(batch)
                        # Conversion en CSV
                        output = io.StringIO()
                        writer = csv.DictWriter(output, fieldnames=fields, delimiter=delimiter)
                        writer.writerows(formatted_batch)
                        yield output.getvalue()
                
                # Nom du fichier
                filename = options.get('filename', f"{table_name}_export_{datetime.now().strftime('%Y%m%d_%H%M%S')}.csv")
                
                # Journalisation
                current_app.logger.info(f"Export CSV de {table_name} démarré")
                
                # Création de la réponse streaming
                return Response(
                    generate_csv(),
                    mimetype=f'text/csv; charset={encoding}',
                    headers={
                        'Content-Disposition': f'attachment; filename="{filename}"',
                        'X-Content-Type-Options': 'nosniff',
                        'X-Download-Options': 'noopen',
                        'Cache-Control': 'no-cache, no-store, must-revalidate',
                        'Pragma': 'no-cache',
                        'Expires': '0',
                        'Access-Control-Allow-Origin': '*'
                    }
                )
                
        except SQLAlchemyError as e:
            current_app.logger.error(f"Erreur lors de l'export CSV pour {table_name}: {str(e)}")
            raise
    
    def export_excel(self, table_name: str, fields: List[str], filters: List[Dict[str, Any]], 
                   options: Dict[str, Any] = None) -> Response:
        """Exporte les données filtrées au format Excel avec streaming"""
        # Validation des entrées
        if not validate_table_name(table_name):
            abort(400, description="Nom de table invalide")
            
        if not fields or not validate_fields(fields):
            abort(400, description="Liste de champs invalide")
              # Options par défaut
        options = options or {}
        include_headers = options.get('includeHeaders', True)
        use_column_names = options.get('useColumnNames', False)  # Nouvelle option
        conjunction = options.get('conjunction', 'AND')
        sheet_name = options.get('sheetName', table_name[:31])  # Excel a une limite de 31 caractères
        
        try:
            with self.engine.connect() as connection:
                # Vérification que les champs existent
                all_fields = self.get_table_fields(table_name)
                all_field_names = [f["name"] for f in all_fields]
                field_descriptions = {f["name"]: f["description"] for f in all_fields}
                
                if not all(f in all_field_names for f in fields):
                    abort(400, description="Certains champs demandés n'existent pas dans la table")
                
                # Construction de la clause WHERE
                where_clause, params = self._build_filter_query(table_name, filters, conjunction)
                
                # Création du DataFrame en préparation pour l'Excel
                all_data = []
                for batch in self._get_data_generator(connection, table_name, fields, where_clause, params):
                    # Formater les dates au format DD-MM-YYYY
                    formatted_batch = self._format_dates_in_data(batch)
                    all_data.extend(formatted_batch)
                
                if not all_data:
                    # Cas où aucune donnée n'est trouvée
                    df = pd.DataFrame(columns=fields)
                else:
                    df = pd.DataFrame(all_data)
                  # Renommage des colonnes si nécessaire
                if include_headers:
                    if use_column_names:
                        # Utiliser les noms des colonnes
                        df.columns = fields
                    else:
                        # Utiliser les descriptions des colonnes
                        df.columns = [field_descriptions.get(f, f) for f in fields]
                
                # Création du fichier Excel en mémoire
                output = io.BytesIO()
                with pd.ExcelWriter(output, engine='openpyxl') as writer:
                    df.to_excel(writer, sheet_name=sheet_name, index=False)
                
                # Préparation de la réponse
                output.seek(0)
                
                # Nom du fichier
                filename = options.get('filename', f"{table_name}_export_{datetime.now().strftime('%Y%m%d_%H%M%S')}.xlsx")
                
                # Journalisation
                current_app.logger.info(f"Export Excel de {table_name} terminé: {len(all_data)} lignes")
                
                return Response(
                    output.getvalue(),
                    mimetype='application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
                    headers={
                        'Content-Disposition': f'attachment; filename="{filename}"',
                        'X-Content-Type-Options': 'nosniff',
                        'X-Download-Options': 'noopen',
                        'Cache-Control': 'no-cache, no-store, must-revalidate',
                        'Pragma': 'no-cache',
                        'Expires': '0',
                        'Access-Control-Allow-Origin': '*'
                    }
                )
                
        except SQLAlchemyError as e:
            current_app.logger.error(f"Erreur lors de l'export Excel pour {table_name}: {str(e)}")
            raise

# Remplacer l'initialisation directe par une fonction factory
data_service = None

def get_data_service():
    """Factory pour récupérer ou créer l'instance de DataService dans un contexte Flask approprié"""
    global data_service
    if data_service is None:
        data_service = DataService()
    return data_service