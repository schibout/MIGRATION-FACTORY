import logging
import re
from typing import Dict, List, Any, Tuple
import pandas as pd
import io
import csv
import zipfile
from datetime import datetime, date
import os
from sqlalchemy import create_engine, text
from dotenv import load_dotenv

# Chargement des variables d'environnement
load_dotenv()

logger = logging.getLogger(__name__)

# Identifiant SQL sûr : lettre/underscore puis alphanumérique/underscore.
# Sert de garde anti-injection sur les schema/table/colonnes interpolés.
_SQL_IDENT_RE = re.compile(r'^[A-Za-z_][A-Za-z0-9_]*$')


def _safe_ident(name: str) -> str:
    """Valide un identifiant SQL (schema/table/colonne) et le renvoie tel quel.
    Lève ValueError si le nom n'est pas un identifiant simple (anti-injection)."""
    if not name or not _SQL_IDENT_RE.match(name):
        raise ValueError(f"Identifiant SQL invalide : {name!r}")
    return name

class ExportService:
    """Service pour gérer les exports de données - Version dynamique avec column_list"""
    
    def __init__(self):
        # Cache pour les requêtes et catégories (chargées depuis la DB)
        self.table_categories = {}
        self.table_schemas = {}
        self.table_columns = {}
        self.table_display_names = {}
        self._cache_loaded = False
        
        # Configuration de connexion PostgreSQL (même méthode que les modules ETL)
        self.pg_host = os.environ.get("PG_HOST", "localhost")
        self.pg_port = os.environ.get("PG_PORT", "5432")
        self.pg_database = os.environ.get("PG_DATABASE", "sap_migration_db")
        self.pg_user = os.environ.get("PG_USER", "postgres")
        self.pg_password = os.environ.get("PG_PASSWORD", "trimet2025")
        
        # Log des paramètres de connexion (sans le mot de passe)
        logger.info(f"🔧 Configuration de connexion: {self.pg_user}@{self.pg_host}:{self.pg_port}/{self.pg_database}")
        
        # Construction de la chaîne de connexion PostgreSQL
        self.postgres_connection_string = f"postgresql://{self.pg_user}:{self.pg_password}@{self.pg_host}:{self.pg_port}/{self.pg_database}"
        
        # Création du moteur avec des paramètres optimisés pour Docker
        try:
            self.engine = create_engine(
                self.postgres_connection_string,
                pool_size=5,
                max_overflow=10,
                pool_pre_ping=True,  # Vérification des connexions avant utilisation
                pool_recycle=3600,   # Recyclage des connexions après 1h
                connect_args={
                    "connect_timeout": 30,  # Timeout de connexion
                    "application_name": "export_service"
                }
            )
            logger.info("✅ Moteur PostgreSQL créé avec succès")
        except Exception as e:
            logger.error(f"❌ Erreur lors de la création du moteur PostgreSQL: {str(e)}")
            raise
        
        # ❌ DÉSACTIVÉ: Ne pas charger les requêtes au démarrage pour éviter les problèmes de connexion
        # Test initial de la connexion et chargement des requêtes
        # self.test_connection()
        # self.load_queries_from_db()
        # ✅ Les requêtes seront chargées automatiquement via ensure_queries_loaded() quand nécessaire
    
    def test_connection(self) -> bool:
        """Test la connexion à la base de données"""
        try:
            logger.info("🔍 Test de connexion à la base de données...")
            with self.engine.connect() as conn:
                result = conn.execute(text("SELECT 1"))
                test_result = result.scalar()
                if test_result == 1:
                    logger.info("✅ Connexion à la base de données réussie")
                    return True
                else:
                    logger.error("❌ Test de connexion échoué - résultat inattendu")
                    raise Exception("Test de connexion échoué - résultat inattendu")
        except Exception as e:
            logger.error(f"❌ Erreur lors du test de connexion: {str(e)}")
            raise Exception(f"Impossible de se connecter à la base de données: {str(e)}")
    
    def normalize_table_name(self, table_name: str) -> str:
        """Normalise le nom de table en minuscules pour compatibilité PostgreSQL"""
        return table_name.lower()
    
    def _get_existing_columns(self, table_schema: str, table_name: str) -> set:
        """Retourne l'ensemble des colonnes (en minuscules) qui existent réellement
        dans la table, en utilisant la connexion SQLAlchemy déjà configurée."""
        try:
            engine = create_engine(self.postgres_connection_string)
            with engine.connect() as conn:
                rows = conn.execute(text(
                    "SELECT lower(column_name) AS col "
                    "FROM information_schema.columns "
                    "WHERE table_schema = :s AND table_name = :t"
                ), {'s': table_schema, 't': table_name}).fetchall()
                return {r[0] for r in rows}
        except Exception as e:
            logger.warning(f"Impossible de lire les colonnes de {table_schema}.{table_name}: {e}")
            return set()

    def build_dynamic_query(self, table_name: str, table_schema: str, column_list: str) -> str:
        """
        Construit dynamiquement une requête SQL à partir des métadonnées.

        Si une colonne déclarée dans column_list n'existe pas dans la table,
        elle est remplacée par `NULL AS <col>` pour que l'export produise
        quand même un CSV au format cible (utile pour exposer un schéma IFS
        complet même si toutes les colonnes ne sont pas encore alimentées).
        """
        columns = [col.strip() for col in column_list.split(',') if col.strip()]
        if not columns:
            raise ValueError(f"Liste de colonnes vide pour la table {table_name}")

        # Valider schema/table comme identifiants simples (anti-injection).
        safe_schema = _safe_ident(table_schema)
        safe_table = _safe_ident(table_name)

        # Noms normalisés en minuscules (PostgreSQL identifiants insensibles à la casse)
        normalized = [col.lower() for col in columns]
        existing = self._get_existing_columns(table_schema, table_name)

        select_exprs = []
        missing = []
        for col in normalized:
            # Rejeter tout nom de colonne non conforme (protège le `NULL AS "{col}"`)
            _safe_ident(col)
            if col in existing:
                select_exprs.append(f'"{col}"')
            else:
                # Colonne absente -> NULL avec l'alias attendu
                select_exprs.append(f'NULL AS "{col}"')
                missing.append(col)

        if missing:
            logger.info(
                f"📋 Export {table_schema}.{table_name}: {len(missing)} colonne(s) inexistante(s) "
                f"remplacée(s) par NULL ({', '.join(missing[:10])}{'...' if len(missing) > 10 else ''})"
            )

        query = f"SELECT {', '.join(select_exprs)} FROM {safe_schema}.{safe_table}"
        logger.debug(f"🔧 Requête générée pour {table_name}: {query}")
        return query

    def load_queries_from_db(self, category_filter: str = None) -> None:
        """
        Charge les métadonnées d'export depuis la table etl_export_queries
        Construit dynamiquement les requêtes à partir de column_list
        
        Args:
            category_filter: Filtre par catégorie (optionnel) - str (une catégorie)
                ou list/tuple (plusieurs catégories chargées en un seul appel).
        """
        try:
            filter_msg = f" pour la catégorie '{category_filter}'" if category_filter else ""
            logger.info(f"🔄 Chargement des métadonnées d'export depuis la table etl_export_queries{filter_msg}...")
            
            with self.engine.connect() as conn:
                # Charger toutes les requêtes actives avec les nouvelles colonnes
                base_query = """
                    SELECT table_name, table_schema, display_name, column_list, 
                           category, description, is_active
                    FROM etl_export_queries 
                    WHERE is_active = true
                """
                
                query_params = {}
                if category_filter:
                    # Accepte une categorie unique (str) ou plusieurs (list/tuple)
                    if isinstance(category_filter, (list, tuple)):
                        base_query += " AND category = ANY(:category_filter)"
                        query_params['category_filter'] = list(category_filter)
                    else:
                        base_query += " AND category = :category_filter"
                        query_params['category_filter'] = category_filter

                base_query += " ORDER BY category, table_name"

                query = text(base_query)
                result = conn.execute(query, query_params)
                
                # Convertir en DataFrame pour compatibilité
                data = []
                for row in result:
                    data.append({
                        'table_name': row.table_name,
                        'table_schema': row.table_schema,
                        'display_name': row.display_name,
                        'column_list': row.column_list,
                        'category': row.category,
                        'description': row.description,
                        'is_active': row.is_active
                    })
                
                if not data:
                    raise Exception("Aucune requête active trouvée dans la table etl_export_queries")
                
                df = pd.DataFrame(data)
                logger.info(f"📊 Trouvé {len(df)} requêtes actives dans la base de données")
                
                # Remplir les caches avec les nouvelles métadonnées
                self.table_categories.clear()
                self.table_schemas.clear()
                self.table_columns.clear()
                self.table_display_names.clear()
                
                for _, row in df.iterrows():
                    table_name = self.normalize_table_name(row['table_name'])
                    
                    # Stocker les métadonnées pour génération dynamique
                    self.table_categories[table_name] = row['category']
                    self.table_schemas[table_name] = row['table_schema']
                    self.table_columns[table_name] = row['column_list']
                    self.table_display_names[table_name] = row['display_name']
                    
                    logger.debug(f"✅ Chargé: {table_name} -> {row['category']} ({row['table_schema']})")
                
                self._cache_loaded = True
                logger.info(f"✅ {len(self.table_categories)} tables configurées pour l'export")
                logger.info(f"📋 Tables disponibles: {list(self.table_categories.keys())}")
                
                # Afficher les schémas utilisés
                schemas = set(self.table_schemas.values())
                logger.info(f"📂 Schémas utilisés: {list(schemas)}")
                
        except Exception as e:
            logger.error(f"❌ Erreur fatale lors du chargement des métadonnées: {str(e)}")
            raise Exception(f"Impossible de charger les métadonnées d'export depuis la base de données: {str(e)}")

    def ensure_queries_loaded(self) -> None:
        """
        S'assure que les métadonnées sont chargées
        """
        if not self._cache_loaded:
            self.load_queries_from_db()
        
        logger.info(f"🔍 Cache état: loaded={self._cache_loaded}, tables={len(self.table_categories)}")
        logger.info(f"📋 Tables disponibles: {list(self.table_categories.keys())}")

    def execute_query(self, table_name: str, custom_query: str = None) -> Tuple[List[Dict[str, Any]], str]:
        """
        Exécute une requête SQL et retourne les résultats
        Génère dynamiquement la requête si aucune requête personnalisée n'est fournie
        
        Args:
            table_name: Nom de la table
            custom_query: Requête SQL personnalisée (optionnel)
            
        Returns:
            Tuple[List[Dict], str]: (données, message d'erreur si applicable)
        """
        try:
            logger.info(f"🔍 Exécution de la requête pour la table: {table_name}")
            
            # S'assurer que les métadonnées sont chargées
            self.ensure_queries_loaded()
            
            # Normaliser le nom de la table
            normalized_table_name = self.normalize_table_name(table_name)
            
            # Générer la requête SQL ou utiliser la requête personnalisée
            if custom_query is None:
                if normalized_table_name not in self.table_categories:
                    error_msg = f"Table {normalized_table_name} non configurée pour l'export"
                    logger.error(f"❌ {error_msg}")
                    return [], error_msg
                
                # Construire la requête dynamiquement
                table_schema = self.table_schemas[normalized_table_name]
                column_list = self.table_columns[normalized_table_name]
                
                try:
                    query = self.build_dynamic_query(normalized_table_name, table_schema, column_list)
                except ValueError as ve:
                    error_msg = f"Erreur de configuration pour {normalized_table_name}: {str(ve)}"
                    logger.error(f"❌ {error_msg}")
                    return [], error_msg
            else:
                query = custom_query
            
            # Exécuter la requête
            with self.engine.connect() as conn:
                result = conn.execute(text(query))
                
                # Convertir en liste de dictionnaires
                data = []
                for row in result:
                    data.append(dict(row._mapping))
                
                display_name = self.table_display_names.get(normalized_table_name, normalized_table_name)
                logger.info(f"✅ Requête réussie pour {display_name}: {len(data)} lignes récupérées")
                return data, None
                
        except Exception as e:
            error_msg = f"Erreur lors de l'exécution de la requête pour {table_name}: {str(e)}"
            logger.error(f"❌ {error_msg}")
            return [], error_msg

    def get_table_info(self, table_name: str) -> Dict[str, Any]:
        """
        Retourne les informations complètes d'une table
        
        Args:
            table_name: Nom de la table
            
        Returns:
            Dictionnaire avec les métadonnées de la table
        """
        normalized_name = self.normalize_table_name(table_name)
        
        if normalized_name not in self.table_categories:
            return {}
        
        return {
            'table_name': normalized_name,
            'display_name': self.table_display_names.get(normalized_name, normalized_name),
            'category': self.table_categories.get(normalized_name),
            'schema': self.table_schemas.get(normalized_name),
            'columns': self.table_columns.get(normalized_name),
            'column_count': len(self.table_columns.get(normalized_name, '').split(','))
        }

    def export_supplier_data(self, config: Dict[str, Any]) -> Dict[str, Any]:
        """
        Exporte les données selon la configuration
        
        Args:
            config: Configuration de l'export
            
        Returns:
            Dict contenant les résultats et erreurs
        """
        selected_tables = config.get('selectedTables', [])
        include_inactive = config.get('includeInactive', False)
        
        logger.info(f"🚀 Début de l'export dynamique - Tables: {len(selected_tables)}")
        logger.info(f"📋 Tables demandées: {selected_tables}")
        
        # Charger spécifiquement les tables avec catégorie 'supplier'
        self.load_queries_from_db('supplier')
        
        results = {}
        errors = {}
        metadata = {}
        total_rows = 0
        
        for table_name in selected_tables:
            # Vérifier que la table est configurée
            normalized_name = self.normalize_table_name(table_name)
            if normalized_name not in self.table_categories:
                error_msg = f"Table {table_name} non configurée pour l'export"
                errors[table_name] = error_msg
                logger.warning(f"⚠️ {error_msg}")
                continue
            
            # Récupérer les informations de la table
            table_info = self.get_table_info(table_name)
            metadata[table_name] = table_info
            
            # Exécuter la requête dynamique
            data, error = self.execute_query(table_name)
            
            if error:
                errors[table_name] = error
            else:
                results[table_name] = data
                total_rows += len(data)
                logger.info(f"📊 {table_info['display_name']}: {len(data)} lignes exportées")
        
        logger.info(f"✅ Export terminé - {len(results)} tables réussies, {len(errors)} échecs, {total_rows} lignes au total")
        
        return {
            'results': results,
            'errors': errors,
            'metadata': metadata,
            'summary': {
                'total_tables': len(selected_tables),
                'successful_tables': len(results),
                'failed_tables': len(errors),
                'total_rows': total_rows
            }
        }

    def export_articles_data(self, config: Dict[str, Any]) -> Dict[str, Any]:
        """
        Exporte les données des articles selon la configuration
        
        Args:
            config: Configuration de l'export
            
        Returns:
            Dict contenant les résultats et erreurs
        """
        selected_tables = config.get('selectedTables', [])
        include_inactive = config.get('includeInactive', False)
        
        logger.info(f"🚀 Début de l'export des articles - Tables: {len(selected_tables)}")
        logger.info(f"📋 Tables demandées: {selected_tables}")
        
        # Charger spécifiquement les tables avec catégorie 'inventory'
        self.load_queries_from_db('inventory')
        
        results = {}
        errors = {}
        metadata = {}
        total_rows = 0
        
        for table_name in selected_tables:
            # Vérifier que la table est configurée
            normalized_name = self.normalize_table_name(table_name)
            if normalized_name not in self.table_categories:
                error_msg = f"Table {table_name} non configurée pour l'export"
                errors[table_name] = error_msg
                logger.warning(f"⚠️ {error_msg}")
                continue
            
            # Vérifier que la table appartient à la catégorie inventory
            if self.table_categories[normalized_name] != 'inventory':
                error_msg = f"Table {table_name} n'appartient pas à la catégorie inventory"
                errors[table_name] = error_msg
                logger.warning(f"⚠️ {error_msg}")
                continue
            
            # Récupérer les informations de la table
            table_info = self.get_table_info(table_name)
            metadata[table_name] = table_info
            
            # Exécuter la requête dynamique
            data, error = self.execute_query(table_name)
            
            if error:
                errors[table_name] = error
            else:
                results[table_name] = data
                total_rows += len(data)
                logger.info(f"📊 {table_info['display_name']}: {len(data)} lignes exportées")
        
        logger.info(f"✅ Export articles terminé - {len(results)} tables réussies, {len(errors)} échecs, {total_rows} lignes au total")
        
        return {
            'results': results,
            'errors': errors,
            'metadata': metadata,
            'summary': {
                'total_tables': len(selected_tables),
                'successful_tables': len(results),
                'failed_tables': len(errors),
                'total_rows': total_rows
            }
        }

    def export_maintenance_data(self, config: Dict[str, Any]) -> Dict[str, Any]:
        """
        Exporte les données de maintenance (ressources) depuis PostgreSQL
        
        Args:
            config: Configuration de l'export
            
        Returns:
            Dict contenant les résultats, erreurs et métadonnées
        """
        selected_tables = config.get('selectedTables', [])
        
        logger.info(f"🚀 Début de l'export maintenance - Tables: {len(selected_tables)}")
        logger.info(f"📋 Tables demandées: {selected_tables}")
        
        maintenance_categories = ('maintenance', 'Structure Maintenance', 'PM Action', 'Operation')
        # IMPORTANT : load_queries_from_db vide le cache a chaque appel. Charger les
        # categories en UN SEUL appel (sinon le 2e ecraserait le 1er -> tables perdues).
        self.load_queries_from_db(list(maintenance_categories))
        
        results = {}
        errors = {}
        metadata = {}
        total_rows = 0
        
        for table_name in selected_tables:
            normalized_name = self.normalize_table_name(table_name)
            if normalized_name not in self.table_categories:
                error_msg = f"Table {table_name} non configurée pour l'export"
                errors[table_name] = error_msg
                logger.warning(f"⚠️ {error_msg}")
                continue
            
            if self.table_categories[normalized_name] not in maintenance_categories:
                error_msg = f"Table {table_name} n'appartient pas à la catégorie maintenance"
                errors[table_name] = error_msg
                logger.warning(f"⚠️ {error_msg}")
                continue
            
            # Récupérer les informations de la table
            table_info = self.get_table_info(table_name)
            metadata[table_name] = table_info
            
            # Exécuter la requête dynamique
            data, error = self.execute_query(table_name)
            
            if error:
                errors[table_name] = error
            else:
                results[table_name] = data
                total_rows += len(data)
                logger.info(f"📊 {table_info['display_name']}: {len(data)} lignes exportées")
        
        logger.info(f"✅ Export maintenance terminé - {len(results)} tables réussies, {len(errors)} échecs, {total_rows} lignes au total")
        
        return {
            'results': results,
            'errors': errors,
            'metadata': metadata,
            'summary': {
                'total_tables': len(selected_tables),
                'successful_tables': len(results),
                'failed_tables': len(errors),
                'total_rows': total_rows
            }
        }

    def export_projects_data(self, config: Dict[str, Any]) -> Dict[str, Any]:
        """
        Exporte les données des projets depuis PostgreSQL
        
        Args:
            config: Configuration de l'export
            
        Returns:
            Dict contenant les résultats, erreurs et métadonnées
        """
        selected_tables = config.get('selectedTables', [])
        
        logger.info(f"🚀 Début de l'export projets - Tables: {len(selected_tables)}")
        logger.info(f"📋 Tables demandées: {selected_tables}")
        
        # Charger spécifiquement les tables avec catégorie 'project'
        self.load_queries_from_db('project')
        
        results = {}
        errors = {}
        metadata = {}
        total_rows = 0
        
        for table_name in selected_tables:
            # Vérifier que la table est configurée
            normalized_name = self.normalize_table_name(table_name)
            if normalized_name not in self.table_categories:
                error_msg = f"Table {table_name} non configurée pour l'export"
                errors[table_name] = error_msg
                logger.warning(f"⚠️ {error_msg}")
                continue
            
            # Vérifier que la table appartient à la catégorie project
            if self.table_categories[normalized_name] != 'project':
                error_msg = f"Table {table_name} n'appartient pas à la catégorie project"
                errors[table_name] = error_msg
                logger.warning(f"⚠️ {error_msg}")
                continue
            
            # Récupérer les informations de la table
            table_info = self.get_table_info(table_name)
            metadata[table_name] = table_info
            
            # Exécuter la requête dynamique
            data, error = self.execute_query(table_name)
            
            if error:
                errors[table_name] = error
            else:
                results[table_name] = data
                total_rows += len(data)
                logger.info(f"📊 {table_info['display_name']}: {len(data)} lignes exportées")
        
        logger.info(f"✅ Export projets terminé - {len(results)} tables réussies, {len(errors)} échecs, {total_rows} lignes au total")
        
        return {
            'results': results,
            'errors': errors,
            'metadata': metadata,
            'summary': {
                'total_tables': len(selected_tables),
                'successful_tables': len(results),
                'failed_tables': len(errors),
                'total_rows': total_rows
            }
        }

    def export_clients_data(self, config: Dict[str, Any]) -> Dict[str, Any]:
        """
        Exporte les données des clients depuis PostgreSQL
        
        Args:
            config: Configuration de l'export
            
        Returns:
            Dict contenant les résultats, erreurs et métadonnées
        """
        logger.info("🚀 Début de l'export des clients")
        
        # Charger spécifiquement les tables avec catégorie 'customer'
        self.load_queries_from_db('customer')
        
        selected_tables = config.get('selectedTables', [])
        results = {}
        errors = {}
        metadata = {}
        total_rows = 0
        
        if not selected_tables:
            logger.warning("⚠️ Aucune table sélectionnée pour l'export")
            return {
                'results': {},
                'errors': {'general': 'Aucune table sélectionnée'},
                'metadata': {},
                'summary': {
                    'total_tables': 0,
                    'successful_tables': 0,
                    'failed_tables': 0,
                    'total_rows': 0
                }
            }
        
        # Traiter chaque table sélectionnée
        for table_name in selected_tables:
            # Vérifier que la table est configurée
            normalized_name = self.normalize_table_name(table_name)
            if normalized_name not in self.table_categories:
                error_msg = f"Table {table_name} non configurée pour l'export"
                errors[table_name] = error_msg
                logger.warning(f"⚠️ {error_msg}")
                continue
            
            # Vérifier que la table appartient à la catégorie customer
            if self.table_categories[normalized_name] != 'customer':
                error_msg = f"Table {table_name} n'appartient pas à la catégorie customer"
                errors[table_name] = error_msg
                logger.warning(f"⚠️ {error_msg}")
                continue
            
            # Récupérer les informations de la table
            table_info = self.get_table_info(table_name)
            metadata[table_name] = table_info
            
            # Exécuter la requête dynamique
            data, error = self.execute_query(table_name)
            
            if error:
                errors[table_name] = error
            else:
                results[table_name] = data
                total_rows += len(data)
                logger.info(f"📊 {table_info['display_name']}: {len(data)} lignes exportées")
        
        logger.info(f"✅ Export clients terminé - {len(results)} tables réussies, {len(errors)} échecs, {total_rows} lignes au total")
        
        return {
            'results': results,
            'errors': errors,
            'metadata': metadata,
            'summary': {
                'total_tables': len(selected_tables),
                'successful_tables': len(results),
                'failed_tables': len(errors),
                'total_rows': total_rows
            }
        }

    def convert_to_csv(self, data: List[Dict[str, Any]], include_headers: bool = True, separator: str = ';') -> str:
        """
        Convertit les données en format CSV
        
        Args:
            data: Données à convertir
            include_headers: Inclure les en-têtes
            separator: Séparateur de colonnes (par défaut: ';')
            
        Returns:
            Chaîne CSV
        """
        if not data:
            return ""
        
        # Log pour debug du séparateur utilisé - FORCE INFO LEVEL
        logger.info(f"💾 convert_to_csv utilise le séparateur: '{separator}' (type: {type(separator)})")
        
        output = io.StringIO()
        columns = list(data[0].keys())
        
        # Log avant création du writer
        logger.info(f"🔧 Création du csv.DictWriter avec delimiter='{separator}'")
        
        # SOLUTION ALTERNATIVE: Force l'utilisation du bon séparateur
        if separator == '\t':
            # Pour la tabulation, utiliser le dialect tab
            writer = csv.DictWriter(output, fieldnames=columns, dialect='excel-tab')
        else:
            # Pour autres séparateurs, créer un dialect personnalisé
            class CustomDialect(csv.excel):
                delimiter = separator
            
            writer = csv.DictWriter(output, fieldnames=columns, dialect=CustomDialect)
        
        # Test pour vérifier le délimiteur utilisé
        if hasattr(writer, 'dialect') and hasattr(writer.dialect, 'delimiter'):
            logger.info(f"📝 Writer créé - dialect.delimiter: '{writer.dialect.delimiter}'")
        else:
            logger.info(f"📝 Writer créé - utilise le séparateur: '{separator}'")
        
        if include_headers:
            writer.writeheader()
        
        # Convertir les valeurs booléennes en majuscules (TRUE/FALSE) et formater les dates
        processed_data = []
        boolean_conversions = 0
        date_conversions = 0
        
        for row in data:
            processed_row = {}
            for key, value in row.items():
                if isinstance(value, bool):
                    processed_row[key] = str(value).upper()  # True -> TRUE, False -> FALSE
                    boolean_conversions += 1
                elif self._is_date_value(value):
                    # Formater les dates au format DD-MM-YYYY
                    formatted_date = self._format_date_for_export(value)
                    processed_row[key] = formatted_date
                    if formatted_date != str(value):  # Compter seulement si formatage effectué
                        date_conversions += 1
                else:
                    processed_row[key] = value
            processed_data.append(processed_row)
        
        if boolean_conversions > 0:
            logger.info(f"🔄 Converti {boolean_conversions} valeurs booléennes en majuscules")
        if date_conversions > 0:
            logger.info(f"📅 Formaté {date_conversions} dates au format DD-MM-YYYY")
        
        writer.writerows(processed_data)
        
        return output.getvalue()

    def get_primary_category(self, selected_tables: List[str]) -> str:
        """
        Détermine la catégorie principale à partir des tables sélectionnées
        
        Args:
            selected_tables: Liste des tables sélectionnées
            
        Returns:
            Nom de la catégorie principale
        """
        # S'assurer que les requêtes sont chargées
        self.ensure_queries_loaded()
        
        categories = {}
        
        # Compter les tables par catégorie
        for table_name in selected_tables:
            # ✅ CORRECTION: Normaliser le nom de la table
            normalized_name = self.normalize_table_name(table_name)
            category = self.table_categories.get(normalized_name, 'unknown')
            categories[category] = categories.get(category, 0) + 1
            logger.debug(f"📊 Table {table_name} -> {normalized_name} -> catégorie {category}")
        
        # Retourner la catégorie la plus représentée
        if not categories:
            logger.warning("⚠️ Aucune catégorie trouvée, utilisation de 'export' par défaut")
            return 'export'
        
        primary_category = max(categories.keys(), key=lambda k: categories[k])
        logger.info(f"📂 Catégorie principale détectée: {primary_category} (répartition: {categories})")
        
        # Si plusieurs catégories, utiliser un nom générique
        if len(categories) > 1 and categories[primary_category] < len(selected_tables) * 0.6:
            logger.info("📂 Plusieurs catégories détectées, utilisation de 'multi_categories'")
            return 'multi_categories'
        
        return primary_category

    def generate_export_file(self, config: Dict[str, Any]) -> Tuple[bytes, str, Dict[str, Any]]:
        """
        Génère un fichier ZIP contenant un CSV par table
        
        Args:
            config: Configuration de l'export
            
        Returns:
            Tuple[bytes, str, Dict]: (contenu_zip, type_mime, metadata)
        """
        selected_tables = config.get('selectedTables', [])
        include_headers = config.get('includeHeaders', True)
        csv_separator = config.get('csvSeparator', ';')  # Nouveau paramètre configurable
        
        # Log pour debug du séparateur
        logger.info(f"🔧 Séparateur CSV configuré: '{csv_separator}' (type: {type(csv_separator)})")
        
        # Déterminer la catégorie principale pour nommer le ZIP
        primary_category = self.get_primary_category(selected_tables)
        
        # Utiliser la méthode d'export appropriée selon la catégorie
        if primary_category == 'customer':
            export_result = self.export_clients_data(config)
        elif primary_category == 'inventory':
            export_result = self.export_articles_data(config)
        elif primary_category in ('maintenance', 'Structure Maintenance', 'PM Action', 'Operation'):
            export_result = self.export_maintenance_data(config)
        elif primary_category == 'project':
            export_result = self.export_projects_data(config)
        else:
            # Par défaut, utiliser l'export supplier (pour 'supplier' et autres)
            export_result = self.export_supplier_data(config)
        
        # Créer le fichier ZIP en mémoire
        zip_buffer = io.BytesIO()
        
        with zipfile.ZipFile(zip_buffer, 'w', zipfile.ZIP_DEFLATED) as zip_file:
            
            # Ajouter un fichier CSV pour chaque table
            for table_name in selected_tables:
                table_data = export_result['results'].get(table_name, [])
                
                if table_data:
                    # Convertir en CSV avec le séparateur configuré
                    csv_content = self.convert_to_csv(table_data, include_headers, csv_separator)
                    
                    # Ajouter le fichier CSV au ZIP
                    csv_filename = f"{table_name}.csv"
                    zip_file.writestr(csv_filename, csv_content.encode('utf-8'))
                    
                    logger.info(f"✅ Fichier ajouté au ZIP: {csv_filename} ({len(table_data)} lignes)")
                
                elif table_name in export_result['errors']:
                    # Créer un fichier d'erreur
                    error_content = f"ERREUR lors de l'export de {table_name}:\n{export_result['errors'][table_name]}\n"
                    error_filename = f"{table_name}_ERROR.txt"
                    zip_file.writestr(error_filename, error_content.encode('utf-8'))
                    
                    logger.warning(f"⚠️ Fichier d'erreur ajouté: {error_filename}")
                
                else:
                    # Créer un fichier vide avec message
                    empty_content = f"Aucune donnée trouvée pour la table {table_name}\n"
                    empty_filename = f"{table_name}_EMPTY.txt"
                    zip_file.writestr(empty_filename, empty_content.encode('utf-8'))
                    
                    logger.info(f"ℹ️ Fichier vide ajouté: {empty_filename}")
            
            # Ajouter un fichier de résumé
            timestamp = datetime.now().strftime('%Y-%m-%d %H:%M:%S')
            summary_content = f"""Export Summary - {timestamp}
====================================

Primary Category: {primary_category}
Total Tables Requested: {export_result['summary']['total_tables']}
Successful Tables: {export_result['summary']['successful_tables']}
Failed Tables: {export_result['summary']['failed_tables']}
Total Rows Exported: {export_result['summary']['total_rows']}

Tables Exported:
"""
            
            for table_name in selected_tables:
                if table_name in export_result['results']:
                    row_count = len(export_result['results'][table_name])
                    summary_content += f"  ✅ {table_name}: {row_count} rows\n"
                elif table_name in export_result['errors']:
                    summary_content += f"  ❌ {table_name}: ERROR - {export_result['errors'][table_name]}\n"
                else:
                    summary_content += f"  ⚠️ {table_name}: No data\n"
            
            zip_file.writestr("_EXPORT_SUMMARY.txt", summary_content.encode('utf-8'))
        
        # Récupérer le contenu du ZIP
        zip_content = zip_buffer.getvalue()
        
        # Métadonnées
        metadata = {
            'summary': export_result['summary'],
            'errors': export_result['errors'],
            'format': 'zip',
            'include_headers': include_headers,
            'primary_category': primary_category,
            'zip_size_bytes': len(zip_content)
        }
        
        logger.info(f"✅ ZIP généré: {len(zip_content)} bytes, catégorie: {primary_category}")
        
        return zip_content, 'application/zip', metadata
    
    def _is_date_value(self, value) -> bool:
        """
        Vérifie si une valeur est une date/datetime
        
        Args:
            value: Valeur à vérifier
            
        Returns:
            bool: True si c'est une date
        """
        if value is None:
            return False
            
        # Types de dates Python
        if isinstance(value, (datetime, date, pd.Timestamp)):
            return True
            
        # Chaînes qui ressemblent à des dates
        if isinstance(value, str):
            # Patterns de dates courants
            date_patterns = [
                '%Y-%m-%d',           # 2023-12-25
                '%Y-%m-%d %H:%M:%S',  # 2023-12-25 14:30:00
                '%d/%m/%Y',           # 25/12/2023
                '%d-%m-%Y',           # 25-12-2023
            ]
            
            for pattern in date_patterns:
                try:
                    datetime.strptime(str(value), pattern)
                    return True
                except ValueError:
                    continue
                    
        return False
    
    def _format_date_for_export(self, value) -> str:
        """
        Formate une date au format DD-MM-YYYY pour l'export
        
        Args:
            value: Valeur de date à formater
            
        Returns:
            str: Date formatée ou valeur originale si échec
        """
        if value is None:
            return ''
            
        try:
            # Si c'est déjà un objet datetime/date/Timestamp
            if isinstance(value, (datetime, date, pd.Timestamp)):
                return value.strftime('%d-%m-%Y')
            
            # Si c'est une chaîne, essayer de la parser
            if isinstance(value, str):
                # Essayer différents formats d'entrée
                date_patterns = [
                    '%Y-%m-%d',           # 2023-12-25
                    '%Y-%m-%d %H:%M:%S',  # 2023-12-25 14:30:00
                    '%d/%m/%Y',           # 25/12/2023
                    '%d-%m-%Y',           # 25-12-2023
                    '%Y/%m/%d',           # 2023/12/25
                ]
                
                for pattern in date_patterns:
                    try:
                        parsed_date = datetime.strptime(str(value), pattern)
                        return parsed_date.strftime('%d-%m-%Y')
                    except ValueError:
                        continue
            
            # Si aucun format ne fonctionne, retourner la valeur originale
            return str(value)
            
        except Exception as e:
            logger.warning(f"Erreur lors du formatage de la date '{value}': {e}")
            return str(value) 